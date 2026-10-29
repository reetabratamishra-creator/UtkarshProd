/**
 * @description Test class for DealerDashboardController.
 *              Verifies that the Apex method returns the expected map structure
 *              (columns + data keys) and retrieves refer to dealer opportunities.
 */
@IsTest
private class DealerDashboardControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Dealer Account', Phone = '1234567890');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Dealer Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            AccountId = acc.Id,
            Customer_Journey__c = 'Refer to Dealer'
        );
        insert opp;
    }

    @IsTest
    static void testGetDealerOpportunitiesDataReturnsExpectedStructure() {
        Test.startTest();
        Map<String, Object> result = DealerDashboardController.getDealerOpportunitiesData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('columns'), 'Result must contain columns key');
        System.assert(result.containsKey('data'),    'Result must contain data key');
    }

    @IsTest
    static void testGetDealerOpportunitiesDataRetrievesData() {
        Test.startTest();
        Map<String, Object> result = DealerDashboardController.getDealerOpportunitiesData();
        Test.stopTest();

        List<Object> data = (List<Object>) result.get('data');
        System.assertNotEquals(null, data, 'Data list should not be null');
        System.assert(data.size() > 0, 'Should return at least one opportunity');
        
        Map<String, Object> firstRow = (Map<String, Object>) data[0];
        System.assert(firstRow.containsKey('recordLink'), 'Each row must contain recordLink');
        System.assertEquals('Test Dealer Opp', firstRow.get('Name'), 'Opportunity name should match');
        System.assertEquals('Test Dealer Account', firstRow.get('Account_Name'), 'Account Name should be flattened and match');
    }
}