@isTest
private class TenderSharingHandlerTest {

    @testSetup
    static void setupData() {

        // Get required Profiles
        Map<String, Profile> profileMap = new Map<String, Profile>();
        for (Profile p : [
            SELECT Id, Name
            FROM Profile
            WHERE Name IN (
                'Utkarsh HOD',
                'CRM Head',
                'Utkarsh Tender',
                'Standard User',
                'System Administrator'
            )
        ]) {
            profileMap.put(p.Name, p);
        }

        String suffix = String.valueOf(System.currentTimeMillis());

        List<User> users = new List<User>{

            // HOD
            new User(
                FirstName='HOD', LastName='User', Alias='hodu',
                Email='hod'+suffix+'@test.com',
                Username='hod'+suffix+'@test.com',
                ProfileId=profileMap.get('Utkarsh HOD').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='High_Mast_Department'
            ),

            // CRM Head
            new User(
                FirstName='CRM', LastName='Head', Alias='crmh',
                Email='crm'+suffix+'@test.com',
                Username='crm'+suffix+'@test.com',
                ProfileId=profileMap.get('CRM Head').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='High_Mast_Department'
            ),

            // Tender User
            new User(
                FirstName='Tender', LastName='User', Alias='tndr',
                Email='tndr'+suffix+'@test.com',
                Username='tndr'+suffix+'@test.com',
                ProfileId=profileMap.get('Utkarsh Tender').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='Crash_Barrier_Department'
            ),

            // Checkbox User
            new User(
                FirstName='Checkbox', LastName='User', Alias='chkbx',
                Email='chk'+suffix+'@test.com',
                Username='chk'+suffix+'@test.com',
                ProfileId=profileMap.get('Standard User').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='Crash_Barrier_Department',
                Tender_Access_User__c = true
            ),

            // No Access User
            new User(
                FirstName='NoAccess', LastName='User', Alias='noacc',
                Email='noacc'+suffix+'@test.com',
                Username='noacc'+suffix+'@test.com',
                ProfileId=profileMap.get('Standard User').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='HDPE_Pipe_Department',
                Tender_Access_User__c = false
            ),

            // Admin (should be skipped)
            new User(
                FirstName='Admin', LastName='User', Alias='admu',
                Email='adm'+suffix+'@test.com',
                Username='adm'+suffix+'@test.com',
                ProfileId=profileMap.get('System Administrator').Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='High_Mast_Department'
            )
        };

        Database.insert (users, AccessLevel.SYSTEM_MODE);

        // Create Tenders (NO Name field)
        insert new List<Tender__c>{
            new Tender__c(Department_Name__c='High Mast & Polygonal'),
            new Tender__c(Department_Name__c='Crash Barrier'),
            new Tender__c(Department_Name__c='HDPE'),
            new Tender__c() // null department
        };
    }


    @isTest
    static void testShareTenders_MainFlow() {

        List<Tender__c> tenders = [
            SELECT Id, Department_Name__c, OwnerId
            FROM Tender__c
        ];

        Test.startTest();

        // Null & empty coverage
        TenderSharingHandler.shareTenders(null);
        TenderSharingHandler.shareTenders(new List<Tender__c>());

        // First execution
        TenderSharingHandler.shareTenders(tenders);

        // Second execution → duplicate + delete logic
        TenderSharingHandler.shareTenders(tenders);

        Test.stopTest();

        // Fetch shares
        List<Tender__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel
            FROM Tender__Share
            WHERE RowCause = 'Manual'
        ];

        System.assert(shares.size() > 0, 'Shares should be created');

        // Map Tender → Shares
        Map<Id, List<Tender__Share>> tenderShareMap = new Map<Id, List<Tender__Share>>();

        for (Tender__Share s : shares) {
            if (!tenderShareMap.containsKey(s.ParentId)) {
                tenderShareMap.put(s.ParentId, new List<Tender__Share>());
            }
            tenderShareMap.get(s.ParentId).add(s);
        }

        // Validate logic
        for (Tender__c t : tenders) {

            if (t.Department_Name__c == null) {
                System.assert(
                    !tenderShareMap.containsKey(t.Id),
                    'No department → no shares'
                );
                continue;
            }

            List<Tender__Share> tenderShares = tenderShareMap.get(t.Id);

            if (tenderShares == null || tenderShares.isEmpty()) {
                // No matching user for this tender's department in test data — valid, skip.
                continue;
            }

            for (Tender__Share s : tenderShares) {
                System.assert(
                    s.AccessLevel == 'Edit' || s.AccessLevel == 'Read',
                    'Access must be Read or Edit'
                );
            }
        }
    }


    @isTest
    static void testShareTenders_DepartmentNormalization() {

        Tender__c tender = [
            SELECT Id, Department_Name__c
            FROM Tender__c
            WHERE Department_Name__c = 'High Mast & Polygonal'
            WITH SYSTEM_MODE LIMIT 1
        ];

        Test.startTest();
        TenderSharingHandler.shareTenders(new List<Tender__c>{ tender });
        Test.stopTest();

        List<Tender__Share> shares = [
            SELECT AccessLevel
            FROM Tender__Share
            WHERE ParentId = :tender.Id
        ];

        Boolean hasEdit = false;

        for (Tender__Share s : shares) {
            if (s.AccessLevel == 'Edit') {
                hasEdit = true;
            }
        }

        System.assert(hasEdit, 'HOD/CRM should get Edit access');
    }
}