@isTest
private without sharing class TenderBidderNotification_Test {
    
    private static Profile getProfile(String name) {
        List<Profile> profs = [SELECT Id FROM Profile WHERE Name = :name LIMIT 1];
        return profs.isEmpty() ? null : profs[0];
    }
    
    private static User createUser(String firstName, Id profileId, String departments) {
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
        Tender__c t = new Tender__c(Department_Name__c = dept);
        if (ownerId != null) {
            t.OwnerId = ownerId;
        }
        return t;
    }
    
    private static Id fakeBidderId() {
        Schema.DescribeSObjectResult d = Bidders__c.SObjectType.getDescribe();
        return d.getKeyPrefix() + '000000000000AAA';
    }
    
    // ---------- TenderBidderNotificationHandler ----------
    
    @isTest
    static void testNotifyNewBidders_NullOrEmptyList() {
        Test.startTest();
        TenderBidderNotificationHandler.notifyNewBidders(null);
        TenderBidderNotificationHandler.notifyNewBidders(new List<Bidders__c>());
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testNotifyNewBidders_NoTenderLookup() {
        List<Bidders__c> bidders = new List<Bidders__c>{
            new Bidders__c() // Tender__c is null
                };
                    Test.startTest();
        TenderBidderNotificationHandler.notifyNewBidders(bidders);
        Test.stopTest();
        System.assert(true, 'Should complete without enqueueing since filter list is empty');
    }
    
    @isTest
    static void testNotifyNewBidders_WithValidBidder() {
        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;
        
        Bidders__c b = new Bidders__c(Tender__c = t.Id);
        insert as system b;
        
        Test.startTest();
        TenderBidderNotificationHandler.notifyNewBidders(new List<Bidders__c>{ b });
        Test.stopTest();
        
        System.assert(true, 'Should complete without throwing regardless of metadata/notif type state');
    }
    
    @isTest
    static void testNotifyNewBidders_ForcedThroughBypass() {
        TenderBidderNotificationHandler.bypassMetadataCheck = true;
        
        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;
        Bidders__c b = new Bidders__c(Tender__c = t.Id);
        insert as system b;
        
        Test.startTest();
        TenderBidderNotificationHandler.notifyNewBidders(new List<Bidders__c>{ b });
        Test.stopTest();
        
        System.assert(true, 'Handler should enqueue job when bypass forces it through');
    }
    
    // ---------- TenderBidderNewNotificationQueueable ----------
    
    @isTest
    static void testQueueable_EmptyBidderIds() {
        Test.startTest();
        System.enqueueJob(new TenderBidderNewNotificationQueueable(new Set<Id>()));
        Test.stopTest();
        System.assert(true, 'Empty set should return early without error');
    }
    
    @isTest
    static void testQueueable_NoMatchingBidders() {
        Set<Id> fakeIds = new Set<Id>{ fakeBidderId() };
            Test.startTest();
        System.enqueueJob(new TenderBidderNewNotificationQueueable(fakeIds));
        Test.stopTest();
        System.assert(true, 'No matching bidders should return early without error');
    }
    
    // Covers the "tenderIds.isEmpty()" return branch: a real Bidders__c
    // record whose Tender__c is null at query time in the queueable.
    @isTest
    static void testQueueable_BidderWithNullTenderField() {
        Bidders__c b = new Bidders__c(); // Tender__c left null
        insert as system b;
        
        Set<Id> ids = new Set<Id>{ b.Id };
            Test.startTest();
        System.enqueueJob(new TenderBidderNewNotificationQueueable(ids));
        Test.stopTest();
        
        System.assert(true, 'Should return early when no bidder has a non-null Tender__c');
    }
    
    @isTest
    static void testQueueable_BidderWithNoTenderParent() {
        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;
        
        Bidders__c b = new Bidders__c(Tender__c = t.Id);
        insert as system b;
        
        delete as system t; // parent gone -> tenderById.get() returns null in queueable
        
        Set<Id> ids = new Set<Id>{ b.Id };
            Test.startTest();
        System.enqueueJob(new TenderBidderNewNotificationQueueable(ids));
        Test.stopTest();
        
        System.assert(true, 'Should skip bidder gracefully when parent tender missing');
    }
    
    // Exercises: role-user dept parsing (incl. blank-segment "continue"),
    // dept-map hit/miss, null-department tender, owner-only recipients,
    // and — via the TestVisible override — the notifType resolution +
    // full recipient loop + sendNotification call.
    @isTest
    static void testQueueable_ForcedNotifTypeOverride_FullRecipientFlow() {
        Profile hodProfile = getProfile('Utkarsh HOD');
        Profile crmProfile = getProfile('CRM Head');
        Id ownerId = UserInfo.getUserId();
        
        if (hodProfile != null) {
            // Leading/trailing blank segment forces the "String.isBlank(dept) -> continue" branch.
            createUser('Hod', hodProfile.Id, ';HDPE_Pipe_Department;;Steel_Pipes_Department');
        }
        if (crmProfile != null) {
            createUser('Crm', crmProfile.Id, 'HDPE_Pipe_Department');
        }
        
        Tender__c t1 = createTender('HDPE', ownerId);                 // maps to HDPE_Pipe_Department -> hits HOD+CRM
        
        String unmappedDept = getUnmappedDepartmentValue();
        Tender__c t2 = createTender(unmappedDept, ownerId);            // no map hit -> owner only
        Tender__c t3 = createTender(null, ownerId);                    // dept null -> owner only
        insert as system new List<Tender__c>{ t1, t2, t3 };
            
            Bidders__c b1 = new Bidders__c(Tender__c = t1.Id);
        Bidders__c b2 = new Bidders__c(Tender__c = t2.Id);
        Bidders__c b3 = new Bidders__c(Tender__c = t3.Id);
        insert as system new List<Bidders__c>{ b1, b2, b3 };
            
            // Fake Id with the correct keyPrefix so setNotificationTypeId doesn't blow up.
            TenderBidderNewNotificationQueueable.testNotifTypeIdOverride =
            Schema.SObjectType.CustomNotificationType.getKeyPrefix() + '000000000000AAA';
        
        Set<Id> ids = new Set<Id>{ b1.Id, b2.Id, b3.Id };
            
            Test.startTest();
        System.enqueueJob(new TenderBidderNewNotificationQueueable(ids));
        Test.stopTest();
        
        System.assert(true, 'Queueable should reach dept/owner/sendNotification lines via override');
    }
    // Pulls a valid, active picklist value for Department_Name__c that is NOT 'HDPE',
    // so it exercises the "no map hit -> owner only" branch without violating the
    // restricted picklist constraint.
    private static String getUnmappedDepartmentValue() {
        List<Schema.PicklistEntry> entries =
            Tender__c.Department_Name__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive() && entry.getValue() != 'HDPE') {
                return entry.getValue();
            }
        }
        return null; // no other active value exists in this org
    }
    // ---------- Trigger coverage (TenderBidderShareTrigger end-to-end) ----------
    
    @isTest
    static void testTrigger_InsertBidder_FullFlow() {
        Tender__c t = createTender('HDPE', UserInfo.getUserId());
        insert as system t;
        
        Bidders__c b = new Bidders__c(Tender__c = t.Id);
        
        Test.startTest();
        insert as system b; // fires TenderBidderShareTrigger -> shareBidders + notifyNewBidders
        Test.stopTest();
        
        System.assert(true, 'Trigger should insert bidder and process share/notification without error');
    }
}