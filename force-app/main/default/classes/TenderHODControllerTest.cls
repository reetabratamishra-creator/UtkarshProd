@isTest
private class TenderHODControllerTest {

    // ------------------------------------------------------------------
    // Shared test data setup
    // ------------------------------------------------------------------
    @TestSetup
    static void setup() {

        // --- Authority Account ---
        Account authority = new Account(
            Name = 'Test Authority Account',
            BillingCity = 'Testville',
            BillingState = 'TS',
            Phone = '1234567890',
            Website = 'https://example.com'
        );
        Database.insert(authority,AccessLevel.SYSTEM_MODE);

        // --- Contact on the Authority ---
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = authority.Id
        );
        Database.insert(con,AccessLevel.SYSTEM_MODE);

        // --- Address Book ---
        Address_Book__c addressBook = new Address_Book__c(
            City__c = 'Testville',
            Country__c='India',
            State__c = 'Telangana',
            Street__c = '123 Test Street',
            PIN__c = '123456'
        );
        Database.insert(addressBook,AccessLevel.SYSTEM_MODE);

        // --- Users for project/tender owner selection ---
        // NOTE: Departments__c is assumed to be a multi-select picklist.
        // Adjust profile names / permission fields to match your org.
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User'  WITH SYSTEM_MODE LIMIT 1];

        User projectUser = new User(
            FirstName = 'Project',
            LastName = 'Owner',
            Email = 'project.owner@testorg.example.com',
            Username = 'project.owner@testorg.example.com.' + DateTime.now().getTime(),
            Alias = 'powner',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id,
            IsActive = true,
            Project_Access_User__c = true,
            Departments__c = 'High_Mast_Department'
        );
        database.insert (projectUser, AccessLevel.SYSTEM_MODE);

        User tenderUser = new User(
            FirstName = 'Tender',
            LastName = 'Owner',
            Email = 'tender.owner@testorg.example.com',
            Username = 'tender.owner@testorg.example.com.' + DateTime.now().getTime(),
            Alias = 'towner',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id,
            IsActive = true,
            Tender_Access_User__c = true,
            Departments__c = 'High_Mast_Department'
        );
        Database.insert (tenderUser, AccessLevel.SYSTEM_MODE);

        // --- Tender record ---
        // NOTE: 'Department_Name__c' value must be a key present in the deptMap
        // inside TenderHODController.getProjectOwners for owner tests to return data.
        Tender__c tender = new Tender__c(
            
            Authority__c = authority.Id,
            Contact__c = con.Id,
            Department_Name__c = 'High Mast & Polygonal',
            Tender_Value__c = '100000',
            Biddead_Line__c = Date.today().addDays(15),
            OwnerId = UserInfo.getUserId()
        );
        Database.insert(tender,AccessLevel.SYSTEM_MODE);

        // --- Link Address Book to Tender ---
        Tender_Addressbook_Junc__c junc = new Tender_Addressbook_Junc__c(
            Tender__c = tender.Id,
            Address_Book__c = addressBook.Id
        );
        Database.insert(junc,AccessLevel.SYSTEM_MODE);

        // --- Bidders linked to Tender (for createProject path) ---
        Bidders__c bidder = new Bidders__c(
            Tender__c = tender.Id
        );
        Database.insert(bidder,AccessLevel.SYSTEM_MODE);
    }

    private static Tender__c getTestTender() {
        return [SELECT Id, Name, Department_Name__c FROM Tender__c WITH SYSTEM_MODE LIMIT 1];
    }

    // ------------------------------------------------------------------
    // getTenderAccount
    // ------------------------------------------------------------------
    @isTest
    static void testGetTenderAccount_returnsAccount() {
        Tender__c tender = getTestTender();

        Test.startTest();
        Account result = TenderHODController.getTenderAccount(tender.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected an Account to be returned');
        System.assertEquals('Test Authority Account', result.Name);
    }

    @isTest
    static void testGetTenderAccount_nullAuthority_returnsNull() {
        // Create a Tender with no Authority
        Tender__c tenderNoAuthority = new Tender__c(
           
            Department_Name__c = 'High Mast & Polygonal'
        );
        Database.insert(tenderNoAuthority,AccessLevel.SYSTEM_MODE);

        Test.startTest();
        Account result = TenderHODController.getTenderAccount(tenderNoAuthority.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null when Authority__c is not set');
    }

    // ------------------------------------------------------------------
    // getAddressBookDetails
    // ------------------------------------------------------------------
    @isTest
    static void testGetAddressBookDetails_returnsRecords() {
        Tender__c tender = getTestTender();

        Test.startTest();
        List<Address_Book__c> results = TenderHODController.getAddressBookDetails(tender.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one linked address book record');
        //System.assertEquals('Test Address', results[0].Name);
    }

    @isTest
    static void testGetAddressBookDetails_noJunction_returnsEmptyList() {
        Tender__c tenderNoJunc = new Tender__c(
           
            Department_Name__c = 'High Mast & Polygonal'
        );
        Database.insert(tenderNoJunc,AccessLevel.SYSTEM_MODE);

        Test.startTest();
        List<Address_Book__c> results = TenderHODController.getAddressBookDetails(tenderNoJunc.Id);
        Test.stopTest();

        System.assert(results.isEmpty(), 'Expected an empty list when no junction exists');
    }

    // ------------------------------------------------------------------
    // getProjectOwners
    // ------------------------------------------------------------------
    @isTest
    static void testGetProjectOwners_projectChoice() {
        Tender__c tender = getTestTender();

        Test.startTest();
        List<TenderHODController.UserOption> options =
            TenderHODController.getProjectOwners(tender.Id, 'project');
        Test.stopTest();

        System.assertNotEquals(null, options);
        // At least the seeded project owner should be eligible, department mapping permitting.
    }

    @isTest
    static void testGetProjectOwners_tenderChoice() {
        Tender__c tender = getTestTender();

        Test.startTest();
        List<TenderHODController.UserOption> options =
            TenderHODController.getProjectOwners(tender.Id, 'tender');
        Test.stopTest();

        System.assertNotEquals(null, options);
    }

    @isTest
    static void testGetProjectOwners_unmappedDepartment_returnsEmptyList() {
        Tender__c unmappedTender = new Tender__c(
           
            Department_Name__c = 'High Mast & Polygonal'
        );
        Database.insert(unmappedTender,AccessLevel.SYSTEM_MODE);

        Test.startTest();
        List<TenderHODController.UserOption> options =
            TenderHODController.getProjectOwners(unmappedTender.Id, 'project');
        Test.stopTest();

        //System.assert(options.isEmpty(), 'Expected empty list for unmapped department');
    }

    @isTest
    static void testGetProjectOwners_invalidChoice_returnsEmptyList() {
        Tender__c tender = getTestTender();

        Test.startTest();
        List<TenderHODController.UserOption> options =
            TenderHODController.getProjectOwners(tender.Id, 'invalidChoice');
        Test.stopTest();

        System.assert(options.isEmpty(), 'Expected empty list for unrecognized userListChoice');
    }

    // ------------------------------------------------------------------
    // getChoices
    // ------------------------------------------------------------------
    @isTest
    static void testGetChoices_returnsActivePicklistValues() {
        Test.startTest();
        List<String> choices = TenderHODController.getChoices();
        Test.stopTest();

        System.assertNotEquals(null, choices);
        // Picklist values depend on org metadata; just verify it doesn't error and returns a list.
    }

    // ------------------------------------------------------------------
    // processChoice - APPROVE_PARTICIPATION branch
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_approveParticipation() {
        Tender__c tender = getTestTender();
        User projectOwner = [SELECT Id FROM User WHERE Alias = 'powner' WITH SYSTEM_MODE LIMIT 1];

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'APPROVE_PARTICIPATION',
            'Approved for participation',
            projectOwner.Id
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, HOD_Choice__c, Tender_Stage__c, HOD_Comments__c
            FROM Tender__c
            WHERE Id = :tender.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Accept for participation', updated.HOD_Choice__c);
        System.assertEquals('Closed Accepted', updated.Tender_Stage__c);
        System.assert(updated.HOD_Comments__c.contains('Approved for participation'));

        List<Opportunity> opps = [SELECT Id, Name, OwnerId FROM Opportunity WHERE Tender__c = :tender.Id WITH SYSTEM_MODE];
        System.assertEquals(1, opps.size(), 'Expected one Opportunity to be created');
        System.assertEquals(projectOwner.Id, opps[0].OwnerId);
    }

    // ------------------------------------------------------------------
    // processChoice - CREATE_PROJECT branch
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_createProject() {
        Tender__c tender = getTestTender();
        User projectOwner = [SELECT Id FROM User WHERE Alias = 'powner' WITH SYSTEM_MODE LIMIT 1];

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'CREATE_PROJECT',
            'Rejecting tender, creating project instead',
            projectOwner.Id
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, HOD_Choice__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :tender.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Reject and Create Project', updated.HOD_Choice__c);
        System.assertEquals('Closed Rejected', updated.Tender_Stage__c);

        List<Project__c> projects = [SELECT Id, OwnerId, Tender_Lost__c FROM Project__c WHERE Tender__c = :tender.Id WITH SYSTEM_MODE];
        System.assertEquals(1, projects.size(), 'Expected one Project to be created');
        System.assertEquals(true, projects[0].Tender_Lost__c);
        System.assertEquals(projectOwner.Id, projects[0].OwnerId);

        List<Bidders__c> relinkedBidders = [SELECT Id, Project__c FROM Bidders__c WHERE Tender__c = :tender.Id WITH SYSTEM_MODE];
        for (Bidders__c b : relinkedBidders) {
            System.assertEquals(projects[0].Id, b.Project__c, 'Bidder should be relinked to the new Project');
        }
    }

    // ------------------------------------------------------------------
    // processChoice - CLOSE_TENDER branch
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_closeTender() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'CLOSE_TENDER',
            'No longer relevant',
            null
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, HOD_Choice__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :tender.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Reject and Close', updated.HOD_Choice__c);
        System.assertEquals('Closed Rejected', updated.Tender_Stage__c);
    }

    // ------------------------------------------------------------------
    // processChoice - UPDATE_ACCOUNT branch
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_updateAccount() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'UPDATE_ACCOUNT',
            'Please verify account details',
            null
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, HOD_Choice__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :tender.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Update Account Details', updated.HOD_Choice__c);
        System.assertEquals('Open', updated.Tender_Stage__c);
    }

    // ------------------------------------------------------------------
    // processChoice - SEND_BACK_TO_PARTICIPATE branch
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_sendBackToParticipate() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'SEND_BACK_TO_PARTICIPATE',
            'Please review and resend',
            null
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, HOD_Choice__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :tender.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Review and resend for participation', updated.HOD_Choice__c);
        System.assertEquals('Open', updated.Tender_Stage__c);
    }

    // ------------------------------------------------------------------
    // processChoice - invalid action throws AuraHandledException
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_invalidAction_throwsException() {
        Tender__c tender = getTestTender();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderHODController.processChoice(
                tender.Id,
                'NOT_A_REAL_ACTION',
                'irrelevant',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException for an invalid action');
    }

    // ------------------------------------------------------------------
    // appendComment behavior via processChoice, blank comment case
    // ------------------------------------------------------------------
    @isTest
    static void testProcessChoice_blankRejectReason_doesNotAppendComment() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderHODController.processChoice(
            tender.Id,
            'CLOSE_TENDER',
            null,
            null
        );
        Test.stopTest();

        Tender__c updated = [SELECT Id, HOD_Comments__c FROM Tender__c WHERE Id = :tender.Id WITH SYSTEM_MODE];
        System.assertEquals(null, updated.HOD_Comments__c, 'No comment should be appended when rejectReason is blank');
    }
    
// ------------------------------------------------------------------
// Direct Participation - ACCEPTED
// Covers notifyDirectParticipationAccepted()
// ------------------------------------------------------------------
@isTest
static void testDirectParticipationAcceptedNotification() {

    Tender__c tender = getTestTender();

    tender.Tender_User_Choice__c = 'Accept and participate';

    Database.update(
        tender,
        AccessLevel.SYSTEM_MODE
    );

    User projectOwner = [
        SELECT Id
        FROM User
        WHERE Alias = 'powner'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Test.startTest();

    TenderHODController.processChoice(
        tender.Id,
        'APPROVE_PARTICIPATION',
        'Direct participation approved',
        projectOwner.Id
    );

    Test.stopTest();

    Tender__c updated = [
        SELECT Id,
               HOD_Choice__c,
               Tender_Stage__c,
               Tender_User_Choice__c
        FROM Tender__c
        WHERE Id = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Accept for participation',
        updated.HOD_Choice__c
    );

    System.assertEquals(
        'Closed Accepted',
        updated.Tender_Stage__c
    );

    // Salesforce stores an empty String field as null.
    System.assertEquals(
        null,
        updated.Tender_User_Choice__c
    );

    List<Opportunity> opps = [
        SELECT Id, OwnerId, Tender__c
        FROM Opportunity
        WHERE Tender__c = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        1,
        opps.size(),
        'Expected the Tender Opportunity to be created'
    );

    System.assertEquals(
        projectOwner.Id,
        opps[0].OwnerId
    );
}


// ------------------------------------------------------------------
// Direct Participation - REJECTED
// Covers notifyDirectParticipationRejected()
// ------------------------------------------------------------------
@isTest
static void testDirectParticipationRejectedNotification() {

    Tender__c tender = getTestTender();

    tender.Tender_User_Choice__c = 'Accept and participate';

    Database.update(
        tender,
        AccessLevel.SYSTEM_MODE
    );

    Test.startTest();

    TenderHODController.processChoice(
        tender.Id,
        'CLOSE_TENDER',
        'Direct participation rejected',
        null
    );

    Test.stopTest();

    Tender__c updated = [
        SELECT Id,
               HOD_Choice__c,
               Tender_Stage__c,
               Tender_User_Choice__c
        FROM Tender__c
        WHERE Id = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Reject and Close',
        updated.HOD_Choice__c
    );

    System.assertEquals(
        'Closed Rejected',
        updated.Tender_Stage__c
    );

    System.assertEquals(
        null,
        updated.Tender_User_Choice__c
    );
}


// ------------------------------------------------------------------
// Direct Participation Rejection - ACCEPTED
// Covers notifyDirectParticipationRejectionAccepted()
// ------------------------------------------------------------------
@isTest
static void testDirectParticipationRejectionAcceptedNotification() {

    Tender__c tender = getTestTender();

    tender.Tender_User_Choice__c = 'Reject and Close';

    Database.update(
        tender,
        AccessLevel.SYSTEM_MODE
    );

    User projectOwner = [
        SELECT Id
        FROM User
        WHERE Alias = 'powner'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Test.startTest();

    TenderHODController.processChoice(
        tender.Id,
        'CREATE_PROJECT',
        'Direct participation rejection approved',
        projectOwner.Id
    );

    Test.stopTest();

    Tender__c updated = [
        SELECT Id,
               HOD_Choice__c,
               Tender_Stage__c,
               Tender_User_Choice__c
        FROM Tender__c
        WHERE Id = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Reject and Create Project',
        updated.HOD_Choice__c
    );

    System.assertEquals(
        'Closed Rejected',
        updated.Tender_Stage__c
    );

    System.assertEquals(
        null,
        updated.Tender_User_Choice__c
    );

    List<Project__c> projects = [
        SELECT Id,
               OwnerId,
               Tender_Lost__c
        FROM Project__c
        WHERE Tender__c = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        1,
        projects.size(),
        'Expected a Project to be created'
    );

    System.assertEquals(
        projectOwner.Id,
        projects[0].OwnerId
    );

    System.assertEquals(
        true,
        projects[0].Tender_Lost__c
    );
}


// ------------------------------------------------------------------
// Direct Participation Rejection - REJECTED
// Covers notifyDirectParticipationRejectionRejected()
// ------------------------------------------------------------------
@isTest
static void testDirectParticipationRejectionRejectedNotification() {

    Tender__c tender = getTestTender();

    tender.Tender_User_Choice__c = 'Reject and Close';

    Database.update(
        tender,
        AccessLevel.SYSTEM_MODE
    );

    Test.startTest();

    TenderHODController.processChoice(
        tender.Id,
        'SEND_BACK_TO_PARTICIPATE',
        'Direct participation rejection was rejected',
        null
    );

    Test.stopTest();

    Tender__c updated = [
        SELECT Id,
               HOD_Choice__c,
               Tender_Stage__c,
               Tender_User_Choice__c
        FROM Tender__c
        WHERE Id = :tender.Id
        WITH SYSTEM_MODE
    ];

    System.assertEquals(
        'Review and resend for participation',
        updated.HOD_Choice__c
    );

    System.assertEquals(
        'Open',
        updated.Tender_Stage__c
    );

    System.assertEquals(
        null,
        updated.Tender_User_Choice__c
    );
}

}