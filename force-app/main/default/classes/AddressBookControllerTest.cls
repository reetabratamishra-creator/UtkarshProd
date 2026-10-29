@IsTest
private class AddressBookControllerTest {

    @TestSetup
    static void setupData() {

        // Create Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpportunity;

        // Create Address Book records
        // Name is an Auto Number field, so it is NOT populated here.
        Address_Book__c addressBook1 = new Address_Book__c(
            Account__c = testAccount.Id,
            Country__c = 'India',
            State__c = 'West Bengal',
            City__c = 'Kolkata',
            Street__c = 'Test Street 1',
            PIN__c = '700001',
            Zone__c = 'East'
        );

        Address_Book__c addressBook2 = new Address_Book__c(
            Account__c = testAccount.Id,
            Country__c = 'India',
            State__c = 'Maharashtra',
            City__c = 'Mumbai',
            Street__c = 'Test Street 2',
            PIN__c = '400001',
            Zone__c = 'West'
        );

        insert new List<Address_Book__c>{
            addressBook1,
            addressBook2
        };

        // Create Opportunity → Address Book junction records
        Opportunity_Address_Junc__c junction1 =
            new Opportunity_Address_Junc__c(
                Opportunity__c = testOpportunity.Id,
                Address_Book__c = addressBook1.Id
            );

        Opportunity_Address_Junc__c junction2 =
            new Opportunity_Address_Junc__c(
                Opportunity__c = testOpportunity.Id,
                Address_Book__c = addressBook2.Id
            );

        insert new List<Opportunity_Address_Junc__c>{
            junction1,
            junction2
        };
    }


    @IsTest
    static void testGetAddressBooks_ValidOpportunity() {

        Opportunity testOpportunity = [
            SELECT Id
            FROM Opportunity
            WHERE Name = 'Test Opportunity'
            LIMIT 1
        ];

        // Get the Address Books created by @TestSetup
        Set<Id> expectedAddressBookIds = new Map<Id, Address_Book__c>(
            [
                SELECT Id
                FROM Address_Book__c
                WHERE Account__c IN (
                    SELECT Id
                    FROM Account
                    WHERE Name = 'Test Account'
                )
            ]
        ).keySet();

        Test.startTest();

        List<Address_Book__c> result =
            AddressBookController.getAddressBooks(testOpportunity.Id);

        Test.stopTest();

        // Verify result is not null
        System.assertNotEquals(
            null,
            result,
            'Result should not be null.'
        );

        // Verify number of records
        System.assertEquals(
            2,
            result.size(),
            'The Opportunity should return two Address Book records.'
        );

        // Verify returned records belong to the expected Address Books
        Set<Id> returnedAddressBookIds = new Set<Id>();

        for (Address_Book__c addressBook : result) {
            returnedAddressBookIds.add(addressBook.Id);

            System.assertNotEquals(
                null,
                addressBook.Name,
                'Auto Number Name should be populated automatically.'
            );

            System.assertEquals(
                'India',
                addressBook.Country__c,
                'Country should be returned correctly.'
            );

            System.assertNotEquals(
                null,
                addressBook.Account__c,
                'Account should be populated.'
            );
        }

        System.assertEquals(
            expectedAddressBookIds,
            returnedAddressBookIds,
            'The returned Address Books should match the Address Books related to the Opportunity.'
        );
    }


    @IsTest
    static void testGetAddressBooks_NoAddressBooks() {

        Account testAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account'
            LIMIT 1
        ];

        // Create an Opportunity with no Address Book junction records
        Opportunity opportunityWithoutAddressBooks =
            new Opportunity(
                Name = 'Opportunity Without Address Books',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );

        insert opportunityWithoutAddressBooks;

        Test.startTest();

        List<Address_Book__c> result =
            AddressBookController.getAddressBooks(
                opportunityWithoutAddressBooks.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'Result should not be null.'
        );

        System.assertEquals(
            0,
            result.size(),
            'An Opportunity without Address Book junctions should return an empty list.'
        );
    }


    @IsTest
    static void testGetAddressBooks_NullRecordId() {

        Test.startTest();

        List<Address_Book__c> result =
            AddressBookController.getAddressBooks(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'Result should not be null.'
        );

        System.assertEquals(
            0,
            result.size(),
            'A null recordId should return an empty list.'
        );
    }
}