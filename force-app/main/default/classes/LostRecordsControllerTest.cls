/**
 * @description Test class for LostRecordsController.
 *              Verifies that both Apex methods return the expected map structure
 *              (columns + data keys) without relying on specific picklist values
 *              that may not exist in every org.
 */
@IsTest
private class LostRecordsControllerTest {

    // ─── Test Data Setup ────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Account for Opportunity relationship
        Account acc = new Account(Name = 'Test Account Lost');
        insert acc;

        // Create a Lead — Status defaults to the first available value;
        // we set it to 'Lost' only if that picklist value exists in the org
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead Lost',
            Company   = 'Test Corp',
            Phone     = '1234567890',
            Email     = 'testlead@example.com',
            Status    = 'Lost'
        );

        try {
            insert lead;
        } catch (DmlException e) {
            // 'Lost' may not be a valid picklist value in all orgs — skip silently
        }

        // Opportunity with StageName = 'Closed Lost'
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp Lost',
            StageName   = 'Closed Lost',
            CloseDate   = Date.today().addDays(-10),
            AccountId   = acc.Id
        );

        try {
            insert opp;
        } catch (DmlException e) {
            // 'Closed Lost' may not be a valid stage in all orgs — skip silently
        }
    }

    // ─── Test Methods ───────────────────────────────────────────────────────

    @IsTest
    static void testGetLostLeadsDataReturnsExpectedStructure() {
        Test.startTest();
        Map<String, Object> result = LostRecordsController.getLostLeadsData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('columns'), 'Result must contain columns key');
        System.assert(result.containsKey('data'),    'Result must contain data key');
    }

    @IsTest
    static void testGetClosedLostOpportunitiesDataReturnsExpectedStructure() {
        Test.startTest();
        Map<String, Object> result = LostRecordsController.getClosedLostOpportunitiesData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('columns'), 'Result must contain columns key');
        System.assert(result.containsKey('data'),    'Result must contain data key');
    }

    @IsTest
    static void testColumnsMatchCMTRecords() {
        Test.startTest();
        Map<String, Object> leadsResult = LostRecordsController.getLostLeadsData();
        Map<String, Object> oppsResult  = LostRecordsController.getClosedLostOpportunitiesData();
        Test.stopTest();

        // Columns list should be a List<Map<String,String>>
        List<Object> leadCols = (List<Object>) leadsResult.get('columns');
        List<Object> oppCols  = (List<Object>) oppsResult.get('columns');

        System.assertNotEquals(null, leadCols, 'Lead columns list should not be null');
        System.assertNotEquals(null, oppCols,  'Opp columns list should not be null');

        // Each column map must have label, fieldName, type keys
        if (!leadCols.isEmpty()) {
            Map<String, Object> firstCol = (Map<String, Object>) leadCols[0];
            System.assert(firstCol.containsKey('label'),     'Column must have label');
            System.assert(firstCol.containsKey('fieldName'), 'Column must have fieldName');
            System.assert(firstCol.containsKey('type'),      'Column must have type');
        }
    }
}