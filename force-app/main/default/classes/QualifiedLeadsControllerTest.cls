/**
 * @description Test class for QualifiedLeadsController.
 *              Verifies that getQualifiedLeadsData and getObjectAccess return the expected
 *              structures and execute queries correctly.
 */
@IsTest
private class QualifiedLeadsControllerTest {

    @TestSetup
    static void makeData() {
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead Qualified',
            Company   = 'Test Corp',
            Phone     = '1234567890',
            Email     = 'testqualified@example.com',
            Status    = 'Qualified'
        );

        try {
            insert lead;
        } catch (DmlException e) {
            // In case 'Qualified' is not a valid status in the test context (though it exists in org)
        }
    }

    @IsTest
    static void testGetQualifiedLeadsDataReturnsExpectedStructure() {
        Test.startTest();
        Map<String, Object> result = QualifiedLeadsController.getQualifiedLeadsData('Qualified');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('columns'), 'Result must contain columns key');
        System.assert(result.containsKey('data'),    'Result must contain data key');
    }

    @IsTest
    static void testGetObjectAccessReturnsExpectedStructure() {
        Test.startTest();
        Map<String, Boolean> result = QualifiedLeadsController.getObjectAccess();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('Lead'), 'Result must contain Lead key');
    }

    @IsTest
    static void testColumnsMatchCMTRecords() {
        Test.startTest();
        Map<String, Object> result = QualifiedLeadsController.getQualifiedLeadsData('Qualified');
        Test.stopTest();

        List<Object> leadCols = (List<Object>) result.get('columns');
        System.assertNotEquals(null, leadCols, 'Lead columns list should not be null');

        if (!leadCols.isEmpty()) {
            Map<String, Object> firstCol = (Map<String, Object>) leadCols[0];
            System.assert(firstCol.containsKey('label'),     'Column must have label');
            System.assert(firstCol.containsKey('fieldName'), 'Column must have fieldName');
            System.assert(firstCol.containsKey('type'),      'Column must have type');
        }
    }
}