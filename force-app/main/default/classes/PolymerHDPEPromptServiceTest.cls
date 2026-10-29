@IsTest
private class PolymerHDPEPromptServiceTest {

    @TestSetup
    static void setupData() {
        Tender__c tender = new Tender__c(
            External_Tender_Id__c = '21323',
            Tender_Description__c = 'HDPE pipe procurement'
        );
        insert tender;

        List<Tender_AI_Summary_JSON__c> summaries = new List<Tender_AI_Summary_JSON__c>();
        summaries.add(
            new Tender_AI_Summary_JSON__c(
                Tender__c = tender.Id,
                Sequence_Number__c = 1,
                Ai_Summary_Json__c = '{"department":"HDPE"}'
            )
        );
        insert summaries;
    }

    private static PolymerHDPEKeywordService.KeywordConfig buildCfg(String positiveKeywords) {
        PolymerHDPEKeywordService.KeywordConfig cfg = new PolymerHDPEKeywordService.KeywordConfig();
        cfg.positiveKeywords = positiveKeywords;
        return cfg;
    }

    // ========================================================
    // mergeAiSummary()
    // ========================================================

    @IsTest
    static void testMergeAiSummary() {
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];

        Test.startTest();
        PolymerHDPEPromptService.MergedSummaryResult result =
            PolymerHDPEPromptService.mergeAiSummary(tender.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.mergedText);
        System.assertEquals(false, result.wasTruncated);
    }

    @IsTest
    static void testMergeAiSummary_NoSummaryRecords() {
        Tender__c tender = new Tender__c(External_Tender_Id__c = '11234');
        insert tender;

        Test.startTest();
        PolymerHDPEPromptService.MergedSummaryResult result =
            PolymerHDPEPromptService.mergeAiSummary(tender.Id);
        Test.stopTest();

        System.assertEquals(null, result.mergedText);
        System.assertEquals(false, result.wasTruncated);
    }

    @IsTest
    static void testMergeAiSummary_AllChunksBlank() {
        Tender__c tender = new Tender__c(External_Tender_Id__c = '99887');
        insert tender;

        insert new Tender_AI_Summary_JSON__c(
            Tender__c = tender.Id,
            Sequence_Number__c = 1,
            Ai_Summary_Json__c = null
        );

        Test.startTest();
        PolymerHDPEPromptService.MergedSummaryResult result =
            PolymerHDPEPromptService.mergeAiSummary(tender.Id);
        Test.stopTest();

        System.assertEquals(null, result.mergedText);
    }

    @IsTest
    static void testMergeAiSummary_Truncated() {
        Tender__c tender = new Tender__c(External_Tender_Id__c = '77665');
        insert tender;

        // Build a chunk comfortably over the 45,000 char safe limit.
        String bigChunk = ''.rightPad(46000, 'X');

        insert new Tender_AI_Summary_JSON__c(
            Tender__c = tender.Id,
            Sequence_Number__c = 1,
            Ai_Summary_Json__c = bigChunk
        );

        Test.startTest();
        PolymerHDPEPromptService.MergedSummaryResult result =
            PolymerHDPEPromptService.mergeAiSummary(tender.Id);
        Test.stopTest();

        System.assertEquals(true, result.wasTruncated);
        System.assertEquals(45000, result.mergedText.length());
    }

    // ========================================================
    // checkDepartment() - not fired
    // ========================================================

    @IsTest
    static void testCheckDepartment_NoInputs() {
        Tender__c tender = new Tender__c(External_Tender_Id__c = '1234567');
        insert tender;

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result =
            PolymerHDPEPromptService.checkDepartment(tender, null, false, null, null);
        Test.stopTest();

        System.assertEquals(false, result.fired);
        System.assertEquals(null, result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - fired, matched
    // ========================================================

    @IsTest
    static void testCheckDepartment_MatchedPolymer() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"Polymer","reasoning":"Polymer keyword found in summary"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, '{"summary":"polymer resin tender"}', false,
            buildCfg('polymer,resin'), buildCfg('hdpe,pipe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(false, result.hadError);
        System.assertEquals(false, result.parseFailed);
        System.assertEquals('Polymer', result.matchedDepartment);
        System.assertEquals('Polymer keyword found in summary', result.reasoning);
    }

    @IsTest
    static void testCheckDepartment_MatchedHDPE_MarkdownFenced() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        // Model wraps its JSON in markdown fences - checkDepartment must strip them.
        PolymerHDPEPromptService.testOverrideResponse =
            '```json\n{"department":"HDPE","reasoning":"HDPE pipe keyword found"}\n```';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe,pipe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals('HDPE', result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - fired, no match
    // ========================================================

    @IsTest
    static void testCheckDepartment_NoMatch() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"No Match","reasoning":"Neither keyword set matched"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(false, result.hadError);
        System.assertEquals(false, result.parseFailed);
        System.assertEquals(null, result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - fired, parse failure
    // ========================================================

    @IsTest
    static void testCheckDepartment_ParseFailed() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse = 'This is not JSON at all.';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(true, result.parseFailed);
        System.assertEquals(false, result.hadError);
        System.assertEquals(null, result.matchedDepartment);
        System.assertNotEquals(null, result.rawResponse);
    }

    // ========================================================
    // checkDepartment() - fired, empty response
    // ========================================================

    @IsTest
    static void testCheckDepartment_EmptyResponse() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse = null;

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(true, result.hadError);
        System.assertEquals('Prompt Builder returned an empty response.', result.errorMessage);
    }

    // ========================================================
    // checkDepartment() - fired, callout exception
    // ========================================================

    @IsTest
    static void testCheckDepartment_ThrowsException() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testShouldThrow = true;

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(true, result.hadError);
        System.assert(result.errorMessage.contains('Simulated Prompt Template failure'));

        // Reset so this static flag doesn't leak into other test methods.
        PolymerHDPEPromptService.testShouldThrow = false;
    }

    // ========================================================
    // checkDepartment() - fired with description only, null keyword configs
    // ========================================================

    @IsTest
    static void testCheckDepartment_DescriptionOnly_NullConfigs() {
        Tender__c tender = new Tender__c(
            External_Tender_Id__c = '55443',
            Tender_Description__c = 'HDPE pipe procurement only'
        );
        insert tender;

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"HDPE","reasoning":"matched from description"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, null, null
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals('HDPE', result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - Summary present, Description missing
    // ========================================================
    @IsTest
    static void testCheckDepartment_SummaryOnly_NoDescription() {
        Tender__c tender = new Tender__c(External_Tender_Id__c = '33221');
        insert tender; // no Tender_Description__c set

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"Polymer","reasoning":"matched from summary only"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, '{"summary":"polymer resin"}', false,
            buildCfg('polymer,resin'), buildCfg('hdpe,pipe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals('Polymer', result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - both Summary and Description present, truncated
    // ========================================================
    @IsTest
    static void testCheckDepartment_BothInputs_Truncated() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"HDPE","reasoning":"matched from combined inputs"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, '{"summary":"long summary text"}', true,
            buildCfg('polymer'), buildCfg('hdpe,pipe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals('HDPE', result.matchedDepartment);
    }

    // ========================================================
    // checkDepartment() - department value present but not "Polymer"/"HDPE"
    // (e.g. an unexpected string) - matchedDepartment must stay null
    // ========================================================
    @IsTest
    static void testCheckDepartment_UnexpectedDepartmentValue() {
        Tender__c tender = [SELECT Id, Name, Tender_Description__c FROM Tender__c LIMIT 1];

        PolymerHDPEPromptService.testOverrideResponse =
            '{"department":"Something Else","reasoning":"model returned unexpected value"}';

        Test.startTest();
        PolymerHDPEPromptService.PromptResult result = PolymerHDPEPromptService.checkDepartment(
            tender, null, false, buildCfg('polymer'), buildCfg('hdpe')
        );
        Test.stopTest();

        System.assertEquals(true, result.fired);
        System.assertEquals(null, result.matchedDepartment);
        System.assertEquals(false, result.hadError);
        System.assertEquals(false, result.parseFailed);
    }
}