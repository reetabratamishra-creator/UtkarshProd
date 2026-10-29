@IsTest
private class BWM_CampaignFilterCtrlTest {
    @TestSetup
    static void setupData() {
        insert as system new List<Lead>{
            new Lead(
                LastName = 'Filter Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
                Company = 'Filter Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
                Status = 'Prospect',
                Department_Name__c = 'Crash Barrier',
                Country__c = 'India',
                State__c = 'West Bengal'
            )
        };

        Account accountRecord = new Account(
            Name = 'Filter Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Phone = '9876543210',
            Email__c = 'filter.account@example.com',
            Department_Name__c = 'Crash Barrier',
            Country__c = 'India',
            State__c = 'Maharashtra'
        );
        insert as system accountRecord;

        insert as system new Contact(
            LastName = 'Filter Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AccountId = accountRecord.Id,
            Email = 'filter.contact+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
            Phone = '9876543211',
            Country__c = 'India',
            State__c = 'Karnataka'
        );

        insert as system new Opportunity(
            Name = 'Filter Opportunity ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Department_Name__c = 'Crash Barrier',
            Country__c = 'India',
            State__c = 'Delhi'
        );

        insert as system new Offline_Campaign__c(
            Name = 'Filter Offline Campaign ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Phone__c = '9876543212',
            Email__c = 'filter.offline@example.com',
            Department__c = 'Crash Barrier',
            Group_List__c = 'North Region List',
            Active__c = true
        );
    }

    @IsTest
    static void picklistOptionsLoad() {
        Test.startTest();
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadCustomerCategoryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadCountryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadStateOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityCustomerCategoryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityCountryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityStateOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountCountryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountStateOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getContactCountryOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getContactStateOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadDepartmentOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityDepartmentOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountDepartmentOptions());
        System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOfflineCampaignDepartmentOptions());
        Test.stopTest();
    }

    @IsTest
    static void searchLeadsIncludesQualifiedStage() {
        insert as system new Lead(
            LastName = 'Qualified Filter Lead',
            Company = 'Qualified Co',
            Status = 'Qualified',
            Department_Name__c = 'Crash Barrier'
        );

        Test.startTest();
        List<Lead> leads = BWM_CampaignFilterCtrl.searchLeads(
            'Qualified Filter',
            new List<String>{ 'Qualified' },
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(1, leads.size());
        System.assertEquals('Qualified', leads[0].Status);
    }

    @IsTest
    static void searchMethodsApplyFilters() {
        Test.startTest();
        List<Lead> leads = BWM_CampaignFilterCtrl.searchLeads(
            'Filter',
            new List<String>{ 'Prospect' },
            new List<String>{ 'Crash Barrier' },
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            null,
            'India',
            new List<String>{ 'West Bengal' }
        );
        List<DealerOpportunityManagementController.OpportunityListItem> opportunities =
            BWM_CampaignFilterCtrl.searchDealerOpportunities(
                'Filter',
                null,
                new List<String>{ 'Nurture' },
                new List<String>{ 'Crash Barrier' },
                null,
                Date.today().addDays(-1),
                Date.today().addDays(1),
                null,
                'India',
                new List<String>{ 'Delhi' }
            );
        List<Account> accounts = BWM_CampaignFilterCtrl.searchAccounts(
            'Filter',
            '9876',
            'filter.account',
            new List<String>{ 'Crash Barrier' },
            'India',
            new List<String>{ 'Maharashtra' }
        );
        List<Contact> contacts = BWM_CampaignFilterCtrl.searchContacts(
            'Filter',
            '9876',
            'filter.contact',
            'India',
            new List<String>{ 'Karnataka' }
        );
        List<Offline_Campaign__c> offlineCampaigns = BWM_CampaignFilterCtrl.searchOfflineCampaigns(
            'Filter Offline',
            '9876',
            'filter.offline',
            new List<String>{ 'Crash Barrier' },
            'North Region List'
        );
        Test.stopTest();

        System.assertEquals(1, leads.size());
        System.assertEquals(1, opportunities.size());
        System.assertEquals(1, accounts.size());
        System.assertEquals(1, contacts.size());
        System.assertEquals(1, offlineCampaigns.size());
    }

    @IsTest
    static void searchOfflineCampaignsUsesExactGroupListMatch() {
        insert as system new Offline_Campaign__c(
            Name = 'Exact Group Match ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Group_List__c = 'test 1',
            Active__c = true
        );

        Test.startTest();
        List<Offline_Campaign__c> exactMatches = BWM_CampaignFilterCtrl.searchOfflineCampaigns(
            null,
            null,
            null,
            null,
            'test'
        );
        List<Offline_Campaign__c> partialNameMatches = BWM_CampaignFilterCtrl.searchOfflineCampaigns(
            null,
            null,
            null,
            null,
            'test 1'
        );
        Test.stopTest();

        System.assertEquals(0, exactMatches.size(), 'Exact test should not include test 1 group');
        System.assertEquals(1, partialNameMatches.size(), 'test 1 should match only its group');
        System.assertEquals('test 1', partialNameMatches[0].Group_List__c);
    }
}