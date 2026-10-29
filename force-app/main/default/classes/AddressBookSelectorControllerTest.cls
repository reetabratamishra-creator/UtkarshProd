@IsTest
private class AddressBookSelectorControllerTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Address_Book__c addressBook = new Address_Book__c(
            Account__c = acc.Id
        );

        insert addressBook;
    }


    @IsTest
    static void testGetAddressBooks_NullAccountId() {

        Test.startTest();

        List<Address_Book__c> results =
            AddressBookSelectorController.getAddressBooks(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'The method should return an empty list.'
        );

        System.assertEquals(
            0,
            results.size(),
            'Null Account Id should return an empty list.'
        );
    }


    @IsTest
    static void testGetAddressBooks_ValidAccountId() {

        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account'
            LIMIT 1
        ];

        Test.startTest();

        List<Address_Book__c> results =
            AddressBookSelectorController.getAddressBooks(acc.Id);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'The method should return a list.'
        );

        System.assertEquals(
            1,
            results.size(),
            'The Account should have one Address Book record.'
        );

        System.assertEquals(
            acc.Id,
            results[0].Account__c,
            'The returned Address Book should belong to the requested Account.'
        );
    }


    @IsTest
    static void testGetAddressBooks_NoAddressBooks() {

        Account acc = new Account(
            Name = 'Account Without Address Book'
        );
        insert acc;

        Test.startTest();

        List<Address_Book__c> results =
            AddressBookSelectorController.getAddressBooks(acc.Id);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'The method should return an empty list.'
        );

        System.assertEquals(
            0,
            results.size(),
            'An Account without Address Books should return an empty list.'
        );
    }
}