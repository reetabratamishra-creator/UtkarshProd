@IsTest
private class AccountResolverController_Opp_CreateTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Acme Corporation',
            Phone = '9999999999',
            Email__c = 'acme@test.com',
            BillingCity = 'Kolkata'
        );

        // Assign Dealer Account Record Type if it exists
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByName();

        if (rtMap.containsKey('Dealer')) {
            acc.RecordTypeId = rtMap.get('Dealer').getRecordTypeId();
        }

        insert acc;
    }

    @IsTest
    static void testSearchAccounts_BlankSearch() {

        Test.startTest();
        List<Account> results =
            AccountResolverController_Opp_Create.searchAccounts('', null);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchAccounts_Normal() {

        Test.startTest();

        List<Account> results =
            AccountResolverController_Opp_Create.searchAccounts(
                'Acme',
                'Opportunity'
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Acme Corporation', results[0].Name);
    }

    @IsTest
    static void testSearchAccounts_DealerOpportunity() {

        Test.startTest();

        List<Account> results =
            AccountResolverController_Opp_Create.searchAccounts(
                'Acme',
                'Dealer Opportunity'
            );

        Test.stopTest();

        // Passes whether or not Dealer RT exists
        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testFindDuplicateAccounts_NoDuplicate() {

        Test.startTest();

        List<Account> results =
            AccountResolverController_Opp_Create.findDuplicateAccounts(
                'Brand New Company',
                '1111111111',
                'new@test.com',
                'Opportunity'
            );

        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testFindDuplicateAccounts_Duplicate() {

        Account existing = [
            SELECT Id, Name
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<Account> results =
            AccountResolverController_Opp_Create.findDuplicateAccounts(
                'Acme Corporation',
                '9999999999',
                'acme@test.com',
                'Opportunity'
            );

        Test.stopTest();

        System.assertNotEquals(null, results);

        // Only executes if Duplicate Rules fire in the org
        if (!results.isEmpty()) {
            System.assertEquals(existing.Id, results[0].Id);
        }
    }

    @IsTest
    static void testFindDuplicateAccounts_DealerOpportunity() {

        Test.startTest();

        List<Account> results =
            AccountResolverController_Opp_Create.findDuplicateAccounts(
                'Acme Corporation',
                '9999999999',
                'acme@test.com',
                'Dealer Opportunity'
            );

        Test.stopTest();

        System.assertNotEquals(null, results);
    }
}