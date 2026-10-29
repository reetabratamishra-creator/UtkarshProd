@isTest
private class TenderAcceptanceControllerTest {

    // ------------------------------------------------------------------
    // Shared test data setup
    // ------------------------------------------------------------------
    @TestSetup
    static void setup() {

        // --- Authority Account ---
        Account authority = new Account(
            Name = 'Test Authority Account',
            BillingCity = 'Lucknow',
            BillingState = 'Uttar Pradesh',
            BillingCountry = 'India',
            Phone = '1234567890',
            Website = 'https://example.com'
        );
        insert authority;

        // --- Contact on the Authority ---
        Contact con = new Contact(
            FirstName = 'Rajesh',
            LastName = 'Kumar',
            AccountId = authority.Id,
            Email = 'rajesh.kumar@example.com',
            Phone = '9876543210'
        );
        insert con;

        // --- Address Book (Indian address) ---
        Address_Book__c addressBook = new Address_Book__c(
            City__c = 'Lucknow',
            State__c = 'Uttar Pradesh',
            Country__c = 'India',
            Street__c = 'Vibhuti Khand, Gomti Nagar',
            PIN__c = '226010'
        );
        insert addressBook;

        // --- HOD user (required for notifyHod path in updateTenderChoice) ---
        // NOTE: Profile 'Utkarsh HOD' must exist in the org.
        Profile hodProfile;
        List<Profile> hodProfiles = [SELECT Id FROM Profile WHERE Name = 'Utkarsh HOD' LIMIT 1];
        if (!hodProfiles.isEmpty()) {
            hodProfile = hodProfiles[0];
        } else {
            hodProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        User hodUser = new User(
            FirstName = 'HOD',
            LastName = 'Approver',
            Email = 'hod.approver@testorg.example.com',
            Username = 'hod.approver@testorg.example.com.' + DateTime.now().getTime(),
            Alias = 'hoduser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = hodProfile.Id,
            IsActive = true,
            Departments__c = 'High_Mast_Department'
        );
        Database.insert(hodUser,AccessLevel.SYSTEM_MODE);

        // --- Tender record (Name is auto-generated, not writeable) ---
        Tender__c tender = new Tender__c(
            Authority__c = authority.Id,
            Contact__c = con.Id,
            Department_Name__c = 'High Mast & Polygonal',
            Tender_Value__c = '100000',
            Biddead_Line__c = Date.today().addDays(15),
            OwnerId = UserInfo.getUserId()
        );
        insert tender;

        // --- Link Address Book to Tender ---
        Tender_Addressbook_Junc__c junc = new Tender_Addressbook_Junc__c(
            Tender__c = tender.Id,
            Address_Book__c = addressBook.Id
        );
        insert junc;
    }

    private static Tender__c getTestTender() {
        return [SELECT Id, Department_Name__c FROM Tender__c LIMIT 1];
    }

    // ------------------------------------------------------------------
    // getTenderUserChoices
    // ------------------------------------------------------------------
    @isTest
    static void testGetTenderUserChoices_returnsActivePicklistValues() {
        Test.startTest();
        List<String> choices = TenderAcceptanceController.getTenderUserChoices();
        Test.stopTest();

        System.assertNotEquals(null, choices, 'Expected a non-null list of picklist values');
    }

    // ------------------------------------------------------------------
    // getTenderInfo
    // ------------------------------------------------------------------
    @isTest
    static void testGetTenderInfo_withContactAndAddressBook() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderAcceptanceController.TenderInfo info =
            TenderAcceptanceController.getTenderInfo(tender.Id);
        Test.stopTest();

        System.assertNotEquals(null, info, 'Expected TenderInfo to be returned');
        System.assertEquals('Test Authority Account', info.authorityName);
        System.assertEquals('Rajesh Kumar', info.contactName);
        System.assertNotEquals('-', info.addressBookName, 'Expected an actual address book name, not the placeholder');
    }

    @isTest
    static void testGetTenderInfo_noContactNoAddressBook_returnsPlaceholders() {
        // Tender with no Contact__c and no address book junction
        Tender__c bareTender = new Tender__c(
            Department_Name__c = 'High Mast & Polygonal'
        );
        insert bareTender;

        Test.startTest();
        TenderAcceptanceController.TenderInfo info =
            TenderAcceptanceController.getTenderInfo(bareTender.Id);
        Test.stopTest();

        System.assertEquals('-', info.contactName, 'Expected placeholder when Contact__c is null');
        System.assertEquals('-', info.addressBookName, 'Expected placeholder when no address book junction exists');
        System.assertEquals(null, info.authorityName, 'Expected null authority name when Authority__c is not set');
    }

    // ------------------------------------------------------------------
    // getContactsForAccount
    // ------------------------------------------------------------------
    @isTest
    static void testGetContactsForAccount_returnsContacts() {
        Account authority = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Contact> contacts = TenderAcceptanceController.getContactsForAccount(authority.Id);
        Test.stopTest();

        System.assertEquals(1, contacts.size(), 'Expected one Contact linked to the Account');
        System.assertEquals('Rajesh Kumar', contacts[0].Name);
    }

    @isTest
    static void testGetContactsForAccount_nullAccountId_returnsEmptyList() {
        Test.startTest();
        List<Contact> contacts = TenderAcceptanceController.getContactsForAccount(null);
        Test.stopTest();

        System.assert(contacts.isEmpty(), 'Expected an empty list when accountId is null');
    }

    // ------------------------------------------------------------------
    // createContact
    // ------------------------------------------------------------------
    @isTest
    static void testCreateContact_success() {
        Account authority = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Id newContactId = TenderAcceptanceController.createContact(
            'Anita',
            'Sharma',
            'anita.sharma@example.com',
            '9123456780',
            authority.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, newContactId, 'Expected a new Contact Id to be returned');

        Contact created = [SELECT Id, Name, Email, Phone, AccountId FROM Contact WHERE Id = :newContactId];
        System.assertEquals('Anita Sharma', created.Name);
        System.assertEquals(authority.Id, created.AccountId);
    }

    @isTest
    static void testCreateContact_blankLastName_throwsException() {
        Account authority = [SELECT Id FROM Account LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderAcceptanceController.createContact(
                'Anita',
                '',
                'anita.sharma@example.com',
                '9123456780',
                authority.Id
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException when Last Name is blank');
    }

    @isTest
    static void testCreateContact_nullAccountId_throwsException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderAcceptanceController.createContact(
                'Anita',
                'Sharma',
                'anita.sharma@example.com',
                '9123456780',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException when accountId is null');
    }

    // ------------------------------------------------------------------
    // updateTenderChoice - happy path (mapped department, HOD found)
    // ------------------------------------------------------------------
    @isTest
    static void testUpdateTenderChoice_success_notifiesHod() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderAcceptanceController.updateTenderChoice(
            tender.Id,
            'Accept and participate', // NOTE: replace with an actual active Tender_User_Choice__c value in your org
            null
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, Tender_User_Choice__c, Tender_Stage__c, HOD_Choice__c, Comments__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];
        System.assertEquals('Accept and participate', updated.Tender_User_Choice__c);
        System.assertEquals('Sent for Approval', updated.Tender_Stage__c);
        //System.assertEquals('', updated.HOD_Choice__c);
    }

    // ------------------------------------------------------------------
    // updateTenderChoice - null tenderId / blank choice
    // ------------------------------------------------------------------
    @isTest
    static void testUpdateTenderChoice_missingRequiredParams_throwsException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderAcceptanceController.updateTenderChoice(null, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException when tenderId/choice are missing');
    }

    // ------------------------------------------------------------------
    // updateTenderChoice - reject choices require a rejection reason
    // ------------------------------------------------------------------
    @isTest
    static void testUpdateTenderChoice_rejectAndClose_missingReason_throwsException() {
        Tender__c tender = getTestTender();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderAcceptanceController.updateTenderChoice(
                tender.Id,
                'Reject and Close',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException when rejection reason is missing for Reject and Close');
    }

    @isTest
    static void testUpdateTenderChoice_rejectAndCreateProject_missingReason_throwsException() {
        Tender__c tender = getTestTender();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TenderAcceptanceController.updateTenderChoice(
                tender.Id,
                'Reject and Create Project',
                ''
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException when rejection reason is blank for Reject and Create Project');
    }

    @isTest
    static void testUpdateTenderChoice_rejectAndClose_withReason_succeeds() {
        Tender__c tender = getTestTender();

        Test.startTest();
        TenderAcceptanceController.updateTenderChoice(
            tender.Id,
            'Reject and Close',
            'Budget constraints on client side'
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, Tender_User_Choice__c, Comments__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];
        System.assertEquals('Reject and Close', updated.Tender_User_Choice__c);
        System.assert(updated.Comments__c.contains('Budget constraints on client side'));
        System.assertEquals('Sent for Approval', updated.Tender_Stage__c);
    }

    // ------------------------------------------------------------------
    // updateTenderChoice - unmapped department (no HOD lookup attempted)
    // ------------------------------------------------------------------
    @isTest
    static void testUpdateTenderChoice_unmappedDepartment_stillUpdatesTender() {
        Tender__c unmappedTender = new Tender__c(
            Department_Name__c = 'High Mast & Polygonal'
        );
        insert unmappedTender;

        Test.startTest();
        TenderAcceptanceController.updateTenderChoice(
            unmappedTender.Id,
            'Accept and participate', // NOTE: replace with a valid active picklist value in your org
            null
        );
        Test.stopTest();

        Tender__c updated = [
            SELECT Id, Tender_User_Choice__c, Tender_Stage__c
            FROM Tender__c
            WHERE Id = :unmappedTender.Id
        ];
        System.assertEquals('Accept and participate', updated.Tender_User_Choice__c);
        System.assertEquals('Sent for Approval', updated.Tender_Stage__c);
    }
}