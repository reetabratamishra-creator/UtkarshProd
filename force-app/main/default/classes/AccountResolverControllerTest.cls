@IsTest
private class AccountResolverControllerTest {

    @TestSetup
    static void setupData() {

        List<Account> accounts = new List<Account>{
            new Account(
                Name = 'Acme Corporation',
                Phone = '9999999999',
                Email__c = 'acme@test.com',
                BillingCity = 'Kolkata'
            ),
            new Account(
                Name = 'Global Technologies',
                Phone = '8888888888',
                Email__c = 'global@test.com',
                BillingCity = 'Delhi'
            )
        };

        insert accounts;
    }

    @IsTest
    static void testSearchAccounts_WithBlankSearch() {

        Test.startTest();
        List<Account> results =
            AccountResolverController.searchAccounts('');
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchAccounts_WithShortSearch() {

        Test.startTest();
        List<Account> results =
            AccountResolverController.searchAccounts('A');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchAccounts_WithValidSearch() {

        Test.startTest();
        List<Account> results =
            AccountResolverController.searchAccounts('Acme');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Acme Corporation', results[0].Name);
        System.assertEquals('9999999999', results[0].Phone);
        System.assertEquals('acme@test.com', results[0].Email__c);
    }

    @IsTest
    static void testFindDuplicateAccounts_NoDuplicates() {

        Test.startTest();

        List<Account> results =
            AccountResolverController.findDuplicateAccounts(
                'Completely New Company',
                '1234567890',
                'new@test.com'
            );

        Test.stopTest();

        System.assertNotEquals(null, results);

        // In a generic test org, no duplicate rules are guaranteed.
        System.assertEquals(0, results.size());
    }
    
    @IsTest
    static void testFindDuplicateAccounts_WithDuplicate() {
        
        // Existing Account
        Account existing = new Account(
            Name = 'Acme Corporation',
            Phone = '9999999999',
            Email__c = 'acme@test.com'
        );
        insert existing;
        
        Test.startTest();
        
        List<Account> results = AccountResolverController.findDuplicateAccounts(
            'Acme Corporation',
            '9999999999',
            'acme@test.com'
        );
        
        Test.stopTest();
        
    }
}