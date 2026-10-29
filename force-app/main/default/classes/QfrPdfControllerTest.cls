@isTest
private class QfrPdfControllerTest {
    
    // ── Test Data Factory ──────────────────────────────────────────────────
    
    private static Account createAccount() {
        Account acc = new Account(Name = 'Test QFR Account');
        insert acc;
        return acc;
    }
    
    private static Opportunity createOpportunity(Id accId) {
        Opportunity opp = new Opportunity(
            Name = 'Test QFR Opp',
            AccountId = accId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }
    
    private static Quote createQuote(Id oppId, String reference, String quoteValue) {
        Quote q = new Quote(
            Name = 'Test QFR Quote',
            OpportunityId = oppId,
            Quote_Reference__c = reference,
            Quote_Value__c = quoteValue
        );
        insert q;
        return q;
    }

    // ── Test Methods ───────────────────────────────────────────────────────

    @isTest
    static void testDataViaUrlParameter() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id, 'ENQ-2026-001', null);
        
        // Block 2 expects a raw JSON list
        List<Map<String, Object>> mockUrlData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'slNo' => 1,
                'description' => 'Test Item',
                'specification' => '100mm',
                'requirement' => 'Urgent'
            },
            new Map<String, Object>{
                'id' => 'special_notes',
                'specialNotes' => 'This is a special note from URL.'
            }
        };
        
        String jsonString = JSON.serialize(mockUrlData);
        String encodedJson = EncodingUtil.urlEncode(jsonString, 'UTF-8');
        
        PageReference pageRef = Page.GenerateQfrDoc;
        pageRef.getParameters().put('data', encodedJson);
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QfrPdfController ctrl = new QfrPdfController(sc);
        Test.stopTest();
        
        System.assertEquals('ENQ-2026-001', ctrl.enquiryNumber, 'Enquiry number should map to Quote Reference');
        System.assertEquals(1, ctrl.tableData.size(), 'One standard row should be parsed');
        System.assertEquals('Test Item', ctrl.tableData[0].get('description'), 'Description should match');
        System.assertEquals('This is a special note from URL.', ctrl.specialNotes, 'Special notes should be parsed from the payload');
    }

    @isTest
    static void testUrlParameterException() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id, 'ENQ-2026-002', null);
        
        PageReference pageRef = Page.GenerateQfrDoc;
        // Inject malformed JSON to trigger the catch block
        pageRef.getParameters().put('data', 'MALFORMED { JSON [');
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QfrPdfController ctrl = new QfrPdfController(sc);
        Test.stopTest();
        
        System.assertEquals(0, ctrl.tableData.size(), 'Table data should be empty on exception');
        System.assertEquals('', ctrl.specialNotes, 'Special notes should remain blank');
    }

    @isTest
    static void testFallbackToQuoteValue() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        
        // Block 3 expects a Map containing the _pebQFRData key
        Map<String, Object> fallbackData = new Map<String, Object>{
            '_pebQFRData' => new List<Object>{
                new Map<String, Object>{
                    'slNo' => '2',
                    'description' => 'Fallback Item',
                    'specification' => '200mm',
                    'requirement' => 'Standard'
                },
                new Map<String, Object>{
                    'id' => 'special_notes',
                    'specialNotes' => 'Notes from Quote Value'
                }
            }
        };
        
        Quote q = createQuote(opp.Id, 'ENQ-2026-003', JSON.serialize(fallbackData));
        
        // Do NOT set the 'data' parameter to force the fallback block
        Test.setCurrentPage(new PageReference('/apex/GenerateQfrDoc'));
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QfrPdfController ctrl = new QfrPdfController(sc);
        Test.stopTest();
        
        System.assertEquals(1, ctrl.tableData.size(), 'Fallback data should insert one row');
        System.assertEquals('Fallback Item', ctrl.tableData[0].get('description'), 'Fallback description should match');
        System.assertEquals('Notes from Quote Value', ctrl.specialNotes, 'Fallback notes should match');
    }

    @isTest
    static void testNullFieldHandling() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        // Leave Quote_Reference__c blank
        Quote q = createQuote(opp.Id, null, null);
        
        // Provide empty JSON keys to test null ternary checks
        List<Map<String, Object>> mockUrlData = new List<Map<String, Object>>{
            new Map<String, Object>{} // Missing all expected keys
        };
        
        PageReference pageRef = Page.GenerateQfrDoc;
        pageRef.getParameters().put('data', EncodingUtil.urlEncode(JSON.serialize(mockUrlData), 'UTF-8'));
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QfrPdfController ctrl = new QfrPdfController(sc);
        Test.stopTest();
        
        System.assertEquals('', ctrl.enquiryNumber, 'Blank Quote Reference should yield blank Enquiry Number');
        System.assertEquals(1, ctrl.tableData.size(), 'Row should be added even if fields are empty');
        System.assertEquals('', ctrl.tableData[0].get('description'), 'Null description should safely convert to blank string');
    }

    @isTest
    static void testNoQuoteIdProvided() {
        Test.setCurrentPage(new PageReference('/apex/GenerateQfrDoc'));
        
        Test.startTest();
        // Instantiate without an inserted Quote (simulate no ID parameter in URL)
        ApexPages.StandardController sc = new ApexPages.StandardController(new Quote());
        QfrPdfController ctrl = new QfrPdfController(sc);
        Test.stopTest();
        
        System.assertEquals('', ctrl.enquiryNumber, 'Enquiry number is blank when no ID is provided');
        System.assertEquals(0, ctrl.tableData.size(), 'Table data is empty when no Quote ID or URL data is provided');
    }
}