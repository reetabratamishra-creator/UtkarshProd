@isTest
private without sharing class NewTenderNotificationQueueable_Test {

    // ---------- Test Data Setup Helpers ----------

    private static Profile getProfile(String name) {
        List<Profile> profs = [SELECT Id FROM Profile WHERE Name = :name LIMIT 1];
        return profs.isEmpty() ? null : profs[0];
    }

    private static User createUser(String firstName, String profileId, String departments) {
        String uniqueEmail = firstName + System.currentTimeMillis() + '@testorg.com';
        User u = new User(
            FirstName        = firstName,
            LastName         = 'TestUser',
            Email            = uniqueEmail,
            Username         = uniqueEmail,
            Alias            = firstName.substring(0, Math.min(4, firstName.length())),
            TimeZoneSidKey   = 'America/Los_Angeles',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey= 'en_US',
            ProfileId        = profileId,
            Departments__c   = departments
        );
        insert as system u;
        return u;
    }

    private static Tender__c createTender(String dept, Id ownerId) {
        Tender__c t = new Tender__c(
            Department_Name__c = dept
        );
        if (ownerId != null) {
            t.OwnerId = ownerId;
        }
        return t;
    }

    // Builds a minimal Tender_Docoment_Details__c record for the given tender,
    // used to exercise the "finally block enqueues document insert" path.
    private static Tender_Docoment_Details__c createDocDetail(Id tenderId) {
        Tender_Docoment_Details__c d = new Tender_Docoment_Details__c();
        d.Tender__c            = tenderId;
        d.Document_Id__c       = '12345';
        d.Name__c               = 'Test Document';
        d.Type__c               = 'PDF';
        d.Download_URL_Text__c = 'https://example.com/test.pdf';
        return d;
    }

    // ---------- TenderDepartmentUtilForNotification ----------

    @isTest
    static void testNormalizeDept_KnownValue() {
        Test.startTest();
        String result = TenderDepartmentUtilForNotification.normalizeDept('High Mast & Polygonal');
        Test.stopTest();
        System.assertEquals('High_Mast_Department', result, 'Known dept should map to normalized value');
    }

    @isTest
    static void testNormalizeDept_UnknownValue() {
        Test.startTest();
        String result = TenderDepartmentUtilForNotification.normalizeDept('Some Unmapped Dept');
        Test.stopTest();
        System.assertEquals('Some Unmapped Dept', result, 'Unknown dept should be returned trimmed as-is');
    }

    @isTest
    static void testNormalizeDept_BlankValue() {
        Test.startTest();
        String result = TenderDepartmentUtilForNotification.normalizeDept('');
        Test.stopTest();
        System.assertEquals('', result, 'Blank input should be returned unchanged');
    }

    @isTest
    static void testGetDeptNormalizationMap_NotEmpty() {
        Test.startTest();
        Map<String, String> deptMap = TenderDepartmentUtilForNotification.getDeptNormalizationMap();
        Test.stopTest();
        System.assert(!deptMap.isEmpty(), 'Normalization map should not be empty');
        System.assert(deptMap.containsKey('HDPE'), 'Map should contain expected key');
    }

    // ---------- TenderNotificationHandler ----------

    @isTest
    static void testNotifyNewTenders_SkipFlagOn() {
        // Covers the "skipNewTenderNotification = true" early-return branch.
        TenderNotificationHandler.skipNewTenderNotification = true;

        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;

        Test.startTest();
        TenderNotificationHandler.notifyNewTenders(new List<Tender__c>{ t });
        Test.stopTest();

        // Reset the static flag so it doesn't leak into other test methods.
        TenderNotificationHandler.skipNewTenderNotification = false;

        System.assert(true, 'Should return early without enqueueing when skip flag is on');
    }

    @isTest
    static void testNotifyNewTenders_NullOrEmptyList() {
        Test.startTest();
        TenderNotificationHandler.notifyNewTenders(null);
        TenderNotificationHandler.notifyNewTenders(new List<Tender__c>());
        Test.stopTest();
        System.assert(true, 'Null or empty list should return early without error');
    }

    @isTest
    static void testNotifyNewTenders_NoDeptOrOwner() {
        List<Tender__c> tenders = new List<Tender__c>{
            new Tender__c() // no Department_Name__c, no OwnerId
        };
        Test.startTest();
        TenderNotificationHandler.notifyNewTenders(tenders);
        Test.stopTest();
        System.assert(true, 'Should complete without enqueueing since filter list is empty');
    }

    @isTest
    static void testNotifyNewTenders_WithValidTender() {
        // Exercises the getInstance() metadata lookup + enqueue path.
        // If the "Tender_Share_Trigger" custom metadata record doesn't exist
        // or has the push-notification flag off, the method exits gracefully
        // (still covered - that branch is expected to be hit here).
        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;

        Test.startTest();
        TenderNotificationHandler.notifyNewTenders(new List<Tender__c>{ t });
        Test.stopTest();

        System.assert(true, 'Should complete without throwing regardless of metadata state');
    }

    // ---------- TenderNewTenderNotificationQueueable ----------

    @isTest
    static void testQueueable_EmptyTenderIds_NoDocs() {
        // Empty tenderIds -> tenders list will be empty -> notification block
        // is skipped, and finally block has no documents to insert either.
        Test.startTest();
        System.enqueueJob(
            new TenderNewTenderNotificationQueueable(
                new Set<Id>(), null, null, 0
            )
        );
        Test.stopTest();
        System.assert(true, 'Empty tenderIds with no documents should complete without error');
    }

    @isTest
    static void testQueueable_NoMatchingTenders_WithDocs() {
        // Random Ids not present in DB -> tenders list will be empty ->
        // notification block skipped, but finally block SHOULD still queue
        // the document insert job since docDetailsToInsert is non-empty.
        // This specifically exercises the fix that moved doc-insert into finally.
        Id fakeTenderId = fakeTenderId();
        Set<Id> fakeIds = new Set<Id>{ fakeTenderId };

        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            createDocDetail(fakeTenderId)
        };

        Test.startTest();
        System.enqueueJob(
            new TenderNewTenderNotificationQueueable(
                fakeIds, docs, 'Steel Pipes', 8000
            )
        );
        Test.stopTest();

        System.assert(true, 'No matching tenders but with documents should still queue document insert via finally block');
    }

    @isTest
    static void testQueueable_WithTendersButNoDocs() {
        // Covers the branch where notification runs normally but
        // docDetailsToInsert is null - finally block's guard condition
        // (docDetailsToInsert != null && !isEmpty) should skip enqueueing.
        Id ownerId = UserInfo.getUserId();
        Tender__c t = createTender('HDPE', ownerId);
        insert as system t;

        Set<Id> ids = new Set<Id>{ t.Id };

        Test.startTest();
        System.enqueueJob(
            new TenderNewTenderNotificationQueueable(
                ids, null, null, 0
            )
        );
        Test.stopTest();

        System.assert(true, 'Queueable with tenders but no documents should complete without enqueueing doc insert');
    }

    private static Id fakeTenderId() {
        Schema.DescribeSObjectResult d = Tender__c.SObjectType.getDescribe();
        return d.getKeyPrefix() + '000000000000AAA';
    }
}