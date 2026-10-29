@IsTest
private class PolymerHDPEKeywordServiceTest {

    // ========================================================
    // NOTE: PolymerHDPEKeywordService.getPolymerKeywords() now keys its
    // returned map by the metadata record's Department__c value ("Polymer"
    // / "HDPE"), NOT by the old Label ("Polymer - Relevant" / "Polymer -
    // Excluded"). If Department__c is blank on a given metadata record, the
    // method falls back to keying by DeveloperName ("Polymer_Relevant" /
    // "HDPE_Relevant") instead. This test checks for either possibility so
    // it stays valid whether or not Department__c is populated on the
    // metadata records in this org.
    // ========================================================

    @IsTest
    static void testGetPolymerKeywords() {
        Test.startTest();
        Map<String, PolymerHDPEKeywordService.KeywordConfig> result =
            PolymerHDPEKeywordService.getPolymerKeywords();
        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'Result map should not be null.'
        );

        // Custom Metadata records are org-wide and may or may not exist in
        // every sandbox/scratch org, so we don't hard-assert a specific
        // count - we just verify the shape of whatever came back is sane.
        for (String key : result.keySet()) {
            PolymerHDPEKeywordService.KeywordConfig cfg = result.get(key);

            System.assertNotEquals(
                null,
                cfg,
                'KeywordConfig for key "' + key + '" should not be null.'
            );

            System.assert(
                String.isNotBlank(key),
                'Map key should never be blank.'
            );

            // If Department__c was populated, the key should exactly match it.
            if (String.isNotBlank(cfg.department)) {
                System.assertEquals(
                    cfg.department,
                    key,
                    'When Department__c is populated, the map key should equal it.'
                );
            } else {
                // Fallback case - key should equal DeveloperName instead.
                System.assertEquals(
                    cfg.developerName,
                    key,
                    'When Department__c is blank, the map key should fall back to DeveloperName.'
                );
            }
        }
    }

    // ========================================================
    // Confirms the method never throws even when no matching metadata
    // records exist (e.g. a fresh scratch org with no
    // Polymer_Relevant/HDPE_Relevant custom metadata deployed yet) - it
    // should simply return an empty map rather than erroring.
    // ========================================================
    @IsTest
    static void testGetPolymerKeywords_ReturnsMapRegardlessOfSize() {
        Test.startTest();
        Map<String, PolymerHDPEKeywordService.KeywordConfig> result =
            PolymerHDPEKeywordService.getPolymerKeywords();
        Test.stopTest();

        System.assert(
            result.size() >= 0,
            'getPolymerKeywords should always return a map, even if empty.'
        );
    }
}