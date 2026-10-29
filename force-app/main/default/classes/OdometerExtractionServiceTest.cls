@isTest
private class OdometerExtractionServiceTest {

    @isTest
    static void testExtractOdometerReading_HandlesFailure() {
        String fakeImage = 'data:image/jpeg;base64,' + EncodingUtil.base64Encode(Blob.valueOf('fake-odometer'));

        Boolean threw = false;
        Test.startTest();
        try {
            OdometerExtractionService.extractOdometerReading(fakeImage);
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
        System.assert(threw, 'Prompt Builder is unavailable in tests; method should throw AuraHandledException');
    }

    @isTest
    static void testExtractOdometerFromFlow_FailurePath() {
        OdometerExtractionService.OdometerRequest req = new OdometerExtractionService.OdometerRequest();
        req.base64Image = EncodingUtil.base64Encode(Blob.valueOf('flow-image'));

        Test.startTest();
        List<OdometerExtractionService.OdometerResult> results =
            OdometerExtractionService.extractOdometerFromFlow(
                new List<OdometerExtractionService.OdometerRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assertNotEquals(null, results[0].message);
    }

    @isTest
    static void testParseOdometerReadingVariants() {
        Test.startTest();
        System.assertEquals(12345, OdometerExtractionService.parseOdometerReading('12345'));
        System.assertEquals(12345, OdometerExtractionService.parseOdometerReading('The odometer reading is 12345'));
        System.assertEquals(98765, OdometerExtractionService.parseOdometerReading('{"reading":98765,"confidence":"high"}'));
        System.assertEquals(42, OdometerExtractionService.convertToDecimal(42));
        System.assertEquals(42, OdometerExtractionService.convertToDecimal('42'));
        System.assertEquals(null, OdometerExtractionService.convertToDecimal(true));
        Test.stopTest();
    }
}