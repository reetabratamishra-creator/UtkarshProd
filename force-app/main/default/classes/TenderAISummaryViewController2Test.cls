@IsTest
private class TenderAISummaryViewController2Test {

    // ============================================================
    // TEST DATA
    // ============================================================

    @TestSetup
    static void setup() {

        Tender__c tender = new Tender__c();

        insert tender;
    }


    // ============================================================
    // HELPER - SET CURRENT PAGE PARAMETER
    // ============================================================

    private static void setPageId(String recordId) {

        PageReference pageRef = new PageReference(
            '/apex/TenderAISummaryView2'
        );

        if (recordId != null) {
            pageRef.getParameters().put('id', recordId);
        }

        Test.setCurrentPage(pageRef);
    }


    // ============================================================
    // HELPER - GET TEST TENDER
    // ============================================================

    private static Tender__c getTestTender() {

        return [
            SELECT
                Id,
                Name,
                External_Tender_Id__c,
                Tender_AI_Summary_status__c
            FROM Tender__c
            LIMIT 1
        ];
    }


    // ============================================================
    // HELPER - GET AVAILABLE METADATA KEYS
    // ============================================================

 private static List<Tender_Keys__mdt> getMetadataKeys() {

    List<Tender_Keys__mdt> allKeys = [
        SELECT
            Key_Api_name__c,
            Key_Name__c,
            Serial_Number__c
        FROM Tender_Keys__mdt
        ORDER BY Serial_Number__c ASC NULLS LAST,
                 Key_Name__c ASC
    ];

    List<Tender_Keys__mdt> validKeys =
        new List<Tender_Keys__mdt>();

    for (Tender_Keys__mdt keyRec : allKeys) {

        if (!String.isBlank(keyRec.Key_Api_name__c)) {
            validKeys.add(keyRec);
        }
    }

    return validKeys;
}


    // ============================================================
    // 1. MISSING TENDER ID
    // ============================================================

    @IsTest
    static void testConstructor_MissingTenderId() {

        setPageId(null);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            true,
            controller.parseFailed,
            'Controller should fail when Tender Id is missing.'
        );

        System.assertEquals(
            'Missing Tender Id.',
            controller.parseErrorMessage
        );

        System.assertNotEquals(
            null,
            controller.rows
        );

        System.assertEquals(
            0,
            controller.rows.size()
        );

        System.assertEquals(
            null,
            controller.tender
        );
    }


    // ============================================================
    // 2. TENDER NOT FOUND
    // ============================================================

    @IsTest
    static void testConstructor_TenderNotFound() {

        // Valid Salesforce Id format but no matching Tender.
        Id fakeTenderId = 'a00000000000000AAA';

        setPageId(String.valueOf(fakeTenderId));

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            true,
            controller.parseFailed
        );

        System.assertEquals(
            'Tender not found.',
            controller.parseErrorMessage
        );

        System.assertEquals(
            null,
            controller.tender
        );

        System.assertEquals(
            0,
            controller.rows.size()
        );
    }


    // ============================================================
    // 3. AI SUMMARY STATUS = FAIL
    // ============================================================

    @IsTest
    static void testConstructor_AISummaryFailed() {

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Fail';

        update tender;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            true,
            controller.parseFailed,
            'Controller should fail when AI Summary status is Fail.'
        );

        System.assertEquals(
            'AI Summary generation failed.',
            controller.parseErrorMessage
        );

        System.assertNotEquals(
            null,
            controller.tender
        );

        System.assertEquals(
            tender.Id,
            controller.tender.Id
        );

        System.assertEquals(
            0,
            controller.rows.size()
        );
    }


    // ============================================================
    // 4. NO AI SUMMARY RECORDS
    // ============================================================

    @IsTest
    static void testConstructor_NoAISummaryValues() {

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Success';

        update tender;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            true,
            controller.parseFailed,
            'Controller should fail when no AI Summary values exist.'
        );

        System.assertEquals(
            'No AI Summary values found.',
            controller.parseErrorMessage
        );

        System.assertNotEquals(
            null,
            controller.tender
        );

        System.assertEquals(
            0,
            controller.rows.size()
        );
    }


    // ============================================================
    // 5. SUCCESS - STRING VALUE + HTML UNESCAPE
    // ============================================================

    @IsTest
    static void testConstructor_Success_StringAndHtmlValue() {

        List<Tender_Keys__mdt> keys = getMetadataKeys();

        System.assert(
            !keys.isEmpty(),
            'At least one Tender_Keys__mdt record is required ' +
            'for the successful parsing test.'
        );

        Tender_Keys__mdt keyRec = keys[0];

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Success';

        update tender;

        String json =
            '{"' +
            keyRec.Key_Api_name__c +
            '":"A &amp; B"}';

        Tender_AI_Summary_Json__c summary =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c = json
            );

        insert summary;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            false,
            controller.parseFailed,
            'Controller should successfully parse the AI Summary.'
        );

        System.assertEquals(
            null,
            controller.parseErrorMessage
        );

        System.assertNotEquals(
            null,
            controller.tender
        );

        System.assertEquals(
            tender.Id,
            controller.tender.Id
        );

        System.assert(
            controller.rows.size() > 0,
            'Rows should be created from Custom Metadata.'
        );

        Boolean foundExpectedValue = false;

        for (
            TenderAISummaryViewController2.SummaryRow row :
            controller.rows
        ) {

            if (row.label == keyRec.Key_Name__c) {

                System.assertEquals(
                    'A & B',
                    row.value,
                    'HTML entity should be decoded.'
                );

                foundExpectedValue = true;
            }
        }

        System.assert(
            foundExpectedValue,
            'Expected metadata-backed row was not found.'
        );
    }


    // ============================================================
    // 6. SUCCESS - FIRST NON-BLANK VALUE WINS
    // ============================================================

    @IsTest
    static void testConstructor_FirstNonBlankValueWins() {

        List<Tender_Keys__mdt> keys = getMetadataKeys();

        System.assert(
            !keys.isEmpty(),
            'At least one Tender_Keys__mdt record is required.'
        );

        Tender_Keys__mdt keyRec = keys[0];

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Success';

        update tender;

        // First record contains a blank value.
        Tender_AI_Summary_Json__c summary1 =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c =
                    '{"' +
                    keyRec.Key_Api_name__c +
                    '":""}'
            );

        insert summary1;

        // Second record contains the actual value.
        Tender_AI_Summary_Json__c summary2 =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c =
                    '{"' +
                    keyRec.Key_Api_name__c +
                    '":"Actual Value"}'
            );

        insert summary2;

        // Third record contains another value.
        // Because the first non-blank value wins,
        // this value should NOT replace "Actual Value".
        Tender_AI_Summary_Json__c summary3 =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c =
                    '{"' +
                    keyRec.Key_Api_name__c +
                    '":"Later Value"}'
            );

        insert summary3;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            false,
            controller.parseFailed
        );

        Boolean foundExpectedValue = false;

        for (
            TenderAISummaryViewController2.SummaryRow row :
            controller.rows
        ) {

            if (row.label == keyRec.Key_Name__c) {

                System.assertEquals(
                    'Actual Value',
                    row.value,
                    'The first non-blank value should win.'
                );

                foundExpectedValue = true;
            }
        }

        System.assert(
            foundExpectedValue,
            'Expected metadata-backed row was not found.'
        );
    }


    // ============================================================
    // 7. SUCCESS - PRIMITIVE VALUES
    // ============================================================

    @IsTest
    static void testConstructor_PrimitiveValues() {

        List<Tender_Keys__mdt> keys = getMetadataKeys();

        System.assert(
            !keys.isEmpty(),
            'At least one Tender_Keys__mdt record is required.'
        );

        Tender_Keys__mdt keyRec = keys[0];

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Success';

        update tender;

        String json =
            '{"' +
            keyRec.Key_Api_name__c +
            '":123}';

        Tender_AI_Summary_Json__c summary =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c = json
            );

        insert summary;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            false,
            controller.parseFailed
        );

        Boolean foundValue = false;

        for (
            TenderAISummaryViewController2.SummaryRow row :
            controller.rows
        ) {

            if (row.label == keyRec.Key_Name__c) {

                System.assertEquals(
                    '123',
                    row.value,
                    'Primitive numeric value should be parsed.'
                );

                foundValue = true;
            }
        }

        System.assert(
            foundValue,
            'Expected primitive value row was not found.'
        );
    }


    // ============================================================
    // 8. BLANK JSON IS IGNORED
    // ============================================================

    @IsTest
    static void testConstructor_BlankJsonIgnored() {

        List<Tender_Keys__mdt> keys = getMetadataKeys();

        System.assert(
            !keys.isEmpty(),
            'At least one Tender_Keys__mdt record is required.'
        );

        Tender_Keys__mdt keyRec = keys[0];

        Tender__c tender = getTestTender();

        tender.Tender_AI_Summary_status__c = 'Success';

        update tender;

        // Blank JSON should be ignored.
        Tender_AI_Summary_Json__c blankSummary =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c = ''
            );

        insert blankSummary;

        // A valid summary is also inserted so the constructor can
        // continue and build rows.
        Tender_AI_Summary_Json__c validSummary =
            new Tender_AI_Summary_Json__c(
                Tender__c = tender.Id,
                Ai_Summary_Json__c =
                    '{"' +
                    keyRec.Key_Api_name__c +
                    '":"Valid Value"}'
            );

        insert validSummary;

        setPageId(tender.Id);

        Test.startTest();

        TenderAISummaryViewController2 controller =
            new TenderAISummaryViewController2();

        Test.stopTest();

        System.assertEquals(
            false,
            controller.parseFailed
        );

        Boolean foundValue = false;

        for (
            TenderAISummaryViewController2.SummaryRow row :
            controller.rows
        ) {

            if (row.label == keyRec.Key_Name__c) {

                System.assertEquals(
                    'Valid Value',
                    row.value
                );

                foundValue = true;
            }
        }

        System.assert(
            foundValue,
            'Valid JSON should still be processed after blank JSON.'
        );
    }


    // ============================================================
    // 9. SUMMARY ROW BLANK VALUE
    // ============================================================

    @IsTest
    static void testSummaryRow_BlankValue() {

        Test.startTest();

        TenderAISummaryViewController2.SummaryRow row =
            new TenderAISummaryViewController2.SummaryRow(
                'Test Label',
                ''
            );

        Test.stopTest();

        System.assertEquals(
            'Test Label',
            row.label
        );

        System.assertEquals(
            '-',
            row.value,
            'Blank SummaryRow values should become "-".'
        );
    }


    // ============================================================
    // 10. SUMMARY ROW NULL VALUE
    // ============================================================

    @IsTest
    static void testSummaryRow_NullValue() {

        Test.startTest();

        TenderAISummaryViewController2.SummaryRow row =
            new TenderAISummaryViewController2.SummaryRow(
                'Test Label',
                null
            );

        Test.stopTest();

        System.assertEquals(
            'Test Label',
            row.label
        );

        System.assertEquals(
            '-',
            row.value,
            'Null SummaryRow values should become "-".'
        );
    }
    
    @IsTest
static void testFormatValue_ListAndMap() {

    // Create controller instance.
    // Missing Id is fine because we are testing the
    // @TestVisible helper method directly.
    setPageId(null);

    TenderAISummaryViewController2 controller =
        new TenderAISummaryViewController2();

    // ============================================================
    // LIST
    // ============================================================

    List<Object> listValue = new List<Object>{
        'First',
        'Second',
        'Third'
    };

    Test.startTest();

    String listResult = controller.formatValue(listValue);

    Test.stopTest();

    System.assertEquals(
        'First, Second, Third',
        listResult,
        'List values should be joined with comma and space.'
    );


    // ============================================================
    // MAP
    // ============================================================

    Map<String, Object> mapValue =
        new Map<String, Object>{
            'Name' => 'Test Name',
            'Status' => 'Open'
        };

    String mapResult = controller.formatValue(mapValue);

    System.assert(
        mapResult.contains('Name: Test Name'),
        'Map should contain the Name key/value.'
    );

    System.assert(
        mapResult.contains('Status: Open'),
        'Map should contain the Status key/value.'
    );
}
}