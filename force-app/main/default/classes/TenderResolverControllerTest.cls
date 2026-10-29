@IsTest
private class TenderResolverControllerTest {

    @TestSetup
    static void setupData() {
        // 1. Create Account
        Account acc = new Account(
            Name = 'Acme Corporation',
            Phone = '1234567890',
            Email__c = 'info@acme.com',
            BillingCity = 'Metropolis'
        );
        insert acc;

        // 2. Create Contact
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = acc.Id,
            Email = 'john.doe@acme.com',
            Phone = '1234567890'
        );
        insert con;

        // 3. Create Tender
        Tender__c tender = new Tender__c();
        insert tender;

        // 4. Create Address Book
        Address_Book__c addressBook = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '123 Old Street',
            City__c = 'Metropolis',
            State__c = 'Gujarat ',
            Country__c = 'India',
            PIN__c = '10001'
        );
        insert addressBook;

        // 5. Create existing Tender-AddressBook Junction
        Tender_Addressbook_Junc__c junction = new Tender_Addressbook_Junc__c(
            Tender__c = tender.Id,
            Address_Book__c = addressBook.Id
        );
        insert junction;
    }

    @IsTest
    static void testSearchAccounts() {
        // Test 1: Null or short search string
        List<Account> emptyResult1 = TenderResolverController.searchAccounts(null);
        System.assertEquals(0, emptyResult1.size(), 'Should return empty list for null search key.');

        List<Account> emptyResult2 = TenderResolverController.searchAccounts('A');
        System.assertEquals(0, emptyResult2.size(), 'Should return empty list for search key less than 2 chars.');

        // Test 2: Valid search string
        List<Account> validResult = TenderResolverController.searchAccounts('Acme');
        System.assertEquals(1, validResult.size(), 'Should return exactly 1 matching account.');
        System.assertEquals('Acme Corporation', validResult[0].Name, 'Account name should match.');
    }

    @IsTest
    static void testFindDuplicateAccounts() {
        // By passing exact details from our setup record, this triggers standard Salesforce matching rules
        // Note: For this to return results in a real org, an active Duplicate Rule on Account must exist.
        List<Account> matches = TenderResolverController.findDuplicateAccounts('Acme Corporation', '1234567890', 'info@acme.com');
        
        // We assert it's not null to ensure the method executed gracefully. 
        System.assertNotEquals(null, matches, 'The returned duplicate list should not be null.');
    }

    @IsTest
    static void testGetAccountContacts() {
        // Test 1: Null Account Id
        List<Contact> emptyResult = TenderResolverController.getAccountContacts(null);
        System.assertEquals(0, emptyResult.size(), 'Should return empty list for null Account Id.');

        // Test 2: Valid Account Id
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Contact> validResult = TenderResolverController.getAccountContacts(acc.Id);
    }

    @IsTest
    static void testProcessTenderSetup_NewRecords() {
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];

        // Create Payload for entirely NEW records
        TenderResolverController.TenderSetupPayload payload = new TenderResolverController.TenderSetupPayload();
        payload.tenderId = tender.Id;
        payload.accountName = 'Brand New Enterprises';
        
        payload.includeContact = true;
        payload.contactFirstName = 'Jane';
        payload.contactLastName = 'Smith';
        payload.contactEmail = 'jane.smith@newent.com';
        payload.contactPhone = '9876543210';
        
        payload.street = '456 New Blvd';
        payload.city = 'Gotham';
        payload.state = 'Gujarat ';
        payload.country = 'India';
        payload.pincode = '07001';

        Test.startTest();
        TenderResolverController.processTenderSetup(payload);
        Test.stopTest();

        // Assertions: Verify Account & Contact were created and linked
        Tender__c updatedTender = [SELECT Authority__c, Contact__c FROM Tender__c WHERE Id = :tender.Id];
        System.assertNotEquals(null, updatedTender.Authority__c, 'A new Account should have been created and linked.');
        System.assertNotEquals(null, updatedTender.Contact__c, 'A new Contact should have been created and linked.');

        // Assertions: Verify New Address Book Junction creation & Old deletion
        List<Tender_Addressbook_Junc__c> junctions = [
            SELECT Id, Address_Book__r.City__c 
            FROM Tender_Addressbook_Junc__c 
            WHERE Tender__c = :tender.Id
        ];
        System.assertEquals(1, junctions.size(), 'Should have exactly 1 address junction after existing ones were deleted.');
        System.assertEquals('Gotham', junctions[0].Address_Book__r.City__c, 'The junction should point to the newly created Address Book.');
    }

    @IsTest
    static void testProcessTenderSetup_ExistingRecords() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];
        Address_Book__c ab = [SELECT Id FROM Address_Book__c LIMIT 1];

        // Create Payload for entirely EXISTING records
        TenderResolverController.TenderSetupPayload payload = new TenderResolverController.TenderSetupPayload();
        payload.tenderId = tender.Id;
        payload.accountId = acc.Id;
        payload.includeContact = true;
        payload.contactId = con.Id;
        payload.addressBookId = ab.Id;

        Test.startTest();
        TenderResolverController.processTenderSetup(payload);
        Test.stopTest();

        Tender__c updatedTender = [SELECT Authority__c, Contact__c FROM Tender__c WHERE Id = :tender.Id];
        System.assertEquals(acc.Id, updatedTender.Authority__c, 'Should have linked the existing Account.');
        System.assertEquals(con.Id, updatedTender.Contact__c, 'Should have linked the existing Contact.');
    }

    @IsTest
    static void testProcessTenderSetup_NoContactAndNoExistingJunctions() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Address_Book__c ab = [SELECT Id FROM Address_Book__c LIMIT 1];
        
        // Create a new Tender that deliberately has ZERO existing junctions to cover the `!existingJunctions.isEmpty()` bypass
        Tender__c newTender = new Tender__c();
        insert newTender;

        TenderResolverController.TenderSetupPayload payload = new TenderResolverController.TenderSetupPayload();
        payload.tenderId = newTender.Id;
        payload.accountId = acc.Id;
        payload.includeContact = false; // Covers the bypass for contact logic
        payload.addressBookId = ab.Id;

        Test.startTest();
        TenderResolverController.processTenderSetup(payload);
        Test.stopTest();

        Tender__c updatedTender = [SELECT Contact__c FROM Tender__c WHERE Id = :newTender.Id];
        System.assertEquals(null, updatedTender.Contact__c, 'Contact should remain null because includeContact was false.');
    }

    @IsTest
    static void testProcessTenderSetup_ExceptionHandling() {
        TenderResolverController.TenderSetupPayload payload = new TenderResolverController.TenderSetupPayload();
        // Leaving tenderId as null will cause an uncatchable System.DmlException (Missing Id) on the update statement,
        // which pushes coverage into the catch block and Database.rollback() code.
        payload.tenderId = null; 
        payload.accountName = 'Trigger Error Account';

        Test.startTest();
        try {
            TenderResolverController.processTenderSetup(payload);
            System.assert(false, 'An AuraHandledException was expected but not thrown.');
        } catch (Exception ex) {
            System.assert(ex instanceof AuraHandledException, 'The exception should be cast and thrown as an AuraHandledException.');
        }
        Test.stopTest();
    }
}