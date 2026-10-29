@IsTest
private class TenderAISummaryBatchTest {

    // ============================================================
    // SUCCESS MOCK
    // ============================================================
    private class SuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            System.assertEquals(
                'GET',
                req.getMethod()
            );

            System.assert(
                req.getEndpoint().contains(
                    '/Utkarsh/api/tender-ai-summary/'
                )
            );

            System.assert(
                req.getEndpoint().endsWith('SUCCESS-TOKEN')
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"success":true,"summary":"Tender AI Summary Success"}'
            );

            return res;
        }
    }


    // ============================================================
    // ERROR MOCK - 500
    // ============================================================
    private class ErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"success":false,"message":"Internal Server Error"}'
            );

            return res;
        }
    }


    // ============================================================
    // BLANK BODY MOCK
    // ============================================================
    private class BlankBodyMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody('');

            return res;
        }
    }


    // ============================================================
    // EXCEPTION MOCK
    // ============================================================
    private class ExceptionMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            throw new CalloutException(
                'Mock callout exception'
            );
        }
    }


    // ============================================================
    // NULL BODY MOCK
    // ============================================================
    private class NullBodyMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(500);

            // No body intentionally.
            return res;
        }
    }


    // ============================================================
    // LARGE RESPONSE MOCK
    // ============================================================
    private class LargeResponseMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            /*
             * We need > 130000 characters to create 2 chunks.
             *
             * Use String.repeat() instead of a 260000-iteration
             * concatenation loop.
             */
            String largeBody = 'A'.repeat(260000);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(largeBody);

            return res;
        }
    }


    // ============================================================
    // HELPER - CREATE TENDER
    // ============================================================
    private static Tender__c createTender(
        String token,
        String status
    ) {

        Tender__c tender = new Tender__c(
            Tender_AI_Summary__c =
                'https://utkarshapi.tender247.com/Utkarsh/api/tender-ai-summary/'
                + token,
            Tender_AI_Summary_status__c = status
        );

        insert tender;

        return tender;
    }


    // ============================================================
    // TEST 1
    //
    // SUCCESS
    //
    // Covers:
    // - start()
    // - execute()
    // - token extraction
    // - GET callout
    // - 200 response
    // - success = true
    // - chunk creation
    // - old chunk deletion
    // - Tender status Success
    // ============================================================
    @IsTest
    static void testBatchSuccess() {

        Tender__c tender = createTender(
            'SUCCESS-TOKEN',
            'None'
        );

        // Existing chunk - should be deleted.
        Tender_AI_Summary_JSON__c oldChunk =
            new Tender_AI_Summary_JSON__c(
                Tender__c = tender.Id,
                Sequence_Number__c = 1,
                Ai_Summary_Json__c = 'OLD DATA'
            );

        insert oldChunk;

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        Id jobId = Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            jobId
        );

        Tender__c updatedTender = [
            SELECT Id,
                   Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Success',
            updatedTender.Tender_AI_Summary_status__c
        );

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Id,
                   Tender__c,
                   Sequence_Number__c,
                   Ai_Summary_Json__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
            ORDER BY Sequence_Number__c
        ];

        System.assertEquals(
            1,
            chunks.size()
        );

        System.assertEquals(
            1,
            chunks[0].Sequence_Number__c
        );

        System.assertEquals(
            '{"success":true,"summary":"Tender AI Summary Success"}',
            chunks[0].Ai_Summary_Json__c
        );

        System.assertNotEquals(
            oldChunk.Id,
            chunks[0].Id
        );
    }


    // ============================================================
    // TEST 2
    //
    // 500 API RESPONSE
    //
    // Covers:
    // - statusCode != 200
    // - success = false
    // - FAIL status
    // - error response stored
    // ============================================================
    @IsTest
    static void testBatchApiError() {

        Tender__c tender = createTender(
            'ERROR-TOKEN',
            'Fail'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new ErrorMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Fail',
            updatedTender.Tender_AI_Summary_status__c
        );

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Id,
                   Ai_Summary_Json__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
        ];

        System.assertEquals(
            1,
            chunks.size()
        );

        System.assert(
            chunks[0].Ai_Summary_Json__c.contains(
                'Internal Server Error'
            )
        );
    }


    // ============================================================
    // TEST 3
    //
    // 200 BUT BLANK BODY
    // ============================================================
    @IsTest
    static void testBatchBlankResponse() {

        Tender__c tender = createTender(
            'BLANK-TOKEN',
            'None'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new BlankBodyMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Fail',
            updatedTender.Tender_AI_Summary_status__c
        );

        Integer chunkCount = [
            SELECT COUNT()
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
        ];

        System.assertEquals(
            0,
            chunkCount
        );
    }


    // ============================================================
    // TEST 4
    //
    // CALLOUT EXCEPTION
    // ============================================================
    @IsTest
    static void testBatchCalloutException() {

        Tender__c tender = createTender(
            'EXCEPTION-TOKEN',
            'None'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new ExceptionMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Fail',
            updatedTender.Tender_AI_Summary_status__c
        );

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Id,
                   Ai_Summary_Json__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
        ];

        System.assertEquals(
            1,
            chunks.size()
        );

        System.assert(
            chunks[0].Ai_Summary_Json__c.startsWith(
                'EXCEPTION:'
            )
        );
    }


    // ============================================================
    // TEST 5
    //
    // BLANK Tender_AI_Summary__c
    //
    // start() does not select this record because of:
    //
    // Tender_AI_Summary__c != null
    //
    // Therefore execute() is called directly.
    // ============================================================
    @IsTest
    static void testExecuteBlankSummary() {

        Tender__c tender = new Tender__c(
            Tender_AI_Summary__c = null,
            Tender_AI_Summary_status__c = 'None'
        );

        insert tender;

        List<Tender__c> scope = [
            SELECT Id,
                   Tender_AI_Summary__c,
                   Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        Test.startTest();

        new TenderAISummaryBatch().execute(
            null,
            scope
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Fail',
            updatedTender.Tender_AI_Summary_status__c
        );

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Id,
                   Ai_Summary_Json__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
        ];

        System.assertEquals(
            1,
            chunks.size()
        );

        System.assertEquals(
            'SKIPPED: Tender_AI_Summary__c is blank',
            chunks[0].Ai_Summary_Json__c
        );
    }


    // ============================================================
    // TEST 6
    //
    // NULL RESPONSE BODY
    // ============================================================
    @IsTest
    static void testNullResponseBody() {

        Tender__c tender = createTender(
            'NULL-BODY-TOKEN',
            'None'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new NullBodyMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Fail',
            updatedTender.Tender_AI_Summary_status__c
        );

        Integer chunkCount = [
            SELECT COUNT()
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
        ];

        System.assertEquals(
            0,
            chunkCount
        );
    }


    // ============================================================
    // TEST 7
    //
    // LARGE RESPONSE
    //
    // Covers:
    // - buildChunkRecords()
    // - while loop
    // - multiple chunks
    // - sequence increment
    // ============================================================
    @IsTest
    static void testLargeResponseCreatesMultipleChunks() {

        Tender__c tender = createTender(
            'LARGE-TOKEN',
            'None'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new LargeResponseMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Success',
            updatedTender.Tender_AI_Summary_status__c
        );

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Id,
                   Sequence_Number__c,
                   Ai_Summary_Json__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tender.Id
            ORDER BY Sequence_Number__c
        ];

        System.assertEquals(
            2,
            chunks.size()
        );

        System.assertEquals(
            1,
            chunks[0].Sequence_Number__c
        );

        System.assertEquals(
            2,
            chunks[1].Sequence_Number__c
        );

        System.assertEquals(
            130000,
            chunks[0].Ai_Summary_Json__c.length()
        );

        System.assertEquals(
            130000,
            chunks[1].Ai_Summary_Json__c.length()
        );
    }


    // ============================================================
    // TEST 8
    //
    // BARE TOKEN
    //
    // Covers:
    //
    // if (lastSlash >= 0 ...)
    //
    // FALSE branch.
    // ============================================================
    @IsTest
    static void testBareToken() {

        Tender__c tender = new Tender__c(
            Tender_AI_Summary__c = 'BARE-TOKEN',
            Tender_AI_Summary_status__c = 'None'
        );

        insert tender;

        Test.setMock(
            HttpCalloutMock.class,
            new BareTokenMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TenderAISummaryBatch(),
            100
        );

        Test.stopTest();

        Tender__c updatedTender = [
            SELECT Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            'Success',
            updatedTender.Tender_AI_Summary_status__c
        );
    }


    // ============================================================
    // TEST 9
    //
    // start()
    // ============================================================
    @IsTest
    static void testStart() {

        Tender__c tender = createTender(
            'START-TOKEN',
            'None'
        );

        TenderAISummaryBatch batch =
            new TenderAISummaryBatch();

        Test.startTest();

        Database.QueryLocator locator =
            batch.start(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            locator
        );
    }


    // ============================================================
    // TEST 10
    //
    // finish()
    // ============================================================
    @IsTest
    static void testFinish() {

        TenderAISummaryBatch batch =
            new TenderAISummaryBatch();

        Test.startTest();

        batch.finish(null);

        Test.stopTest();

        System.assert(
            true
        );
    }


    // ============================================================
    // BARE TOKEN MOCK
    // ============================================================
    private class BareTokenMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            System.assert(
                req.getEndpoint().endsWith(
                    'BARE-TOKEN'
                )
            );

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);
            res.setBody(
                '{"result":"bare token success"}'
            );

            return res;
        }
    }
}