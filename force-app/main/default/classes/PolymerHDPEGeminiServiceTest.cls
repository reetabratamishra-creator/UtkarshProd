@IsTest
private class PolymerHDPEGeminiServiceTest {

    // ------------------------------------------------------------
    // Mock HTTP response
    // ------------------------------------------------------------
    private class GeminiMock implements HttpCalloutMock {

        private Integer statusCode;
        private String responseBody;

        GeminiMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }
    }

    // ------------------------------------------------------------
    // Mock that throws an exception
    // ------------------------------------------------------------
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Test callout exception');
        }
    }

    // ------------------------------------------------------------
    // Helper method to create KeywordConfig
    // ------------------------------------------------------------
    private static PolymerHDPEKeywordService.KeywordConfig createConfig(
        String label,
        String positiveKeywords,
        String negativeKeywords,
        String schemaPrompt
    ) {
        PolymerHDPEKeywordService.KeywordConfig config =
            new PolymerHDPEKeywordService.KeywordConfig();

        config.label = label;
        config.positiveKeywords = positiveKeywords;
        config.negativeKeywords = negativeKeywords;
        config.schemaPrompt = schemaPrompt;
        config.isRelevant = false;

        return config;
    }

    // A fake-but-well-formed Id to exercise the tenderId/logging path
    // without requiring an actual Tender__c record to exist.
    private static Id fakeTenderId() {
        return (Id) '001000000000001AAA';
    }

    // ------------------------------------------------------------
    // SUCCESS - Polymer matched
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFilePolymerMatched() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"Polymer\\",\\"reasoning\\":\\"Polymer keyword found\\"}"}]}}]}';

        PolymerHDPEKeywordService.KeywordConfig polymerCfg =
            createConfig('Polymer - Relevant', 'Polymer, PVC', '', 'Check polymer products.');

        PolymerHDPEKeywordService.KeywordConfig hdpeCfg =
            createConfig('HDPE - Relevant', 'HDPE, High Density Polyethylene', '', 'Check HDPE products.');

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test tender document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                polymerCfg,
                hdpeCfg
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.hadError);
        System.assertEquals('Polymer', result.matchedDepartment);
        System.assertEquals('Polymer keyword found', result.reasoning);
        System.assertEquals('', result.errorMessage);
    }

    // ------------------------------------------------------------
    // SUCCESS - HDPE matched
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileHdpeMatched() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"HDPE\\",\\"reasoning\\":\\"HDPE keyword found\\"}"}]}}]}';

        PolymerHDPEKeywordService.KeywordConfig polymerCfg =
            createConfig('Polymer - Relevant', 'Polymer', '', '');

        PolymerHDPEKeywordService.KeywordConfig hdpeCfg =
            createConfig('HDPE - Relevant', 'HDPE', '', 'HDPE related tender.');

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'text/plain',
                'Tender.txt',
                fakeTenderId(),
                polymerCfg,
                hdpeCfg
            );

        Test.stopTest();

        System.assertEquals(false, result.hadError);
        System.assertEquals('HDPE', result.matchedDepartment);
        System.assertEquals('HDPE keyword found', result.reasoning);
    }

    // ------------------------------------------------------------
    // SUCCESS - neither matched ("None"), null configs, null tenderId
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileNoneMatched() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"None\\",\\"reasoning\\":\\"No matching keyword found\\"}"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'text/html',
                'Tender.html',
                null,
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(false, result.hadError);
        System.assertEquals(null, result.matchedDepartment);
        System.assertEquals('No matching keyword found', result.reasoning);
    }

    // ------------------------------------------------------------
    // SUCCESS - fields missing from JSON entirely
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileMissingFields() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{}"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(false, result.hadError);
        System.assertEquals(null, result.matchedDepartment);
        System.assertEquals('', result.reasoning);
    }

    // ------------------------------------------------------------
    // SUCCESS - Gemini returns an unrecognized department value
    // (e.g. "Other") -> treated as no match
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileUnrecognizedDepartment() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"Other\\",\\"reasoning\\":\\"Not applicable\\"}"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(false, result.hadError);
        System.assertEquals(null, result.matchedDepartment);
        System.assertEquals('Not applicable', result.reasoning);
    }

    // ------------------------------------------------------------
    // ERROR - Gemini returns non-200
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileNon200Response() {

        String responseBody = '{"error":{"message":"Gemini API error"}}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(400, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(true, result.hadError);
        System.assert(result.errorMessage.contains('Status: 400'));
    }

    // ------------------------------------------------------------
    // ERROR - Empty Gemini response (no candidates)
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileEmptyResponse() {

        String responseBody = '{"candidates":[]}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(true, result.hadError);
        System.assert(result.errorMessage.contains('Empty/unreadable Gemini response'));
    }

    // ------------------------------------------------------------
    // ERROR - Invalid JSON returned by Gemini
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileInvalidJson() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"INVALID JSON"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(true, result.hadError);
        System.assert(result.errorMessage.contains('Could not parse Gemini JSON'));
    }

    // ------------------------------------------------------------
    // ERROR - Callout exception
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileCalloutException() {

        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(true, result.hadError);
        System.assert(result.errorMessage.contains('Exception in checkFile'));
    }

    // ------------------------------------------------------------
    // SUCCESS - configs present but with blank keyword strings,
    // to exercise the "(No ... keyword configuration available)"
    // branches in buildPrompt without a null config.
    // ------------------------------------------------------------
    @IsTest
    static void testCheckFileBlankKeywordConfigs() {

        String responseBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"None\\",\\"reasoning\\":\\"No keywords configured\\"}"}]}}]}';

        PolymerHDPEKeywordService.KeywordConfig polymerCfg =
            createConfig('Polymer - Relevant', '', '', '');

        PolymerHDPEKeywordService.KeywordConfig hdpeCfg =
            createConfig('HDPE - Relevant', '', '', '');

        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, responseBody));

        Test.startTest();

        PolymerHDPEGeminiService.MatchResult result =
            PolymerHDPEGeminiService.checkFile(
                Blob.valueOf('Test document'),
                'application/pdf',
                'Tender.pdf',
                fakeTenderId(),
                polymerCfg,
                hdpeCfg
            );

        Test.stopTest();

        System.assertEquals(false, result.hadError);
        System.assertEquals(null, result.matchedDepartment);
        System.assertEquals('No keywords configured', result.reasoning);
    }
}