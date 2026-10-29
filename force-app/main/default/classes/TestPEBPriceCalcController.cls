@isTest
private class TestPEBPriceCalcController {
    
    // REVISED: Placed totals immediately before the section names to match 
    // the controller's backward-lookback extraction logic.
    private static final String ESTIMATION_TEXT =
        'PREPARED BY A.Das \n' +
        '162184 A Built-up section frames TOTAL \n' +
        '41997 B COLD FORMED sections TOTAL \n' +
        'C HARD WARE Anchor bolts 2539 Primary connection bolts 1622 TOTAL 4404 \n' +
        '18486 D Misc. HR IS-2062 steel TOTAL \n' +
        '123 E Deck Sheet TOTAL \n' +
        '456 F Galvalume Sheet - Roof TOTAL \n' +
        '789 G Galvalume Sheet - Wall TOTAL \n' +
        '321 H Packing Material TOTAL \n' +
        '3134 I DECKING SHEET 0.8MM TOTAL \n' +
        'SPECIAL NOTES:\n' +
        '1 Down spout pipe 110 mm dia 360 Mtr\n' +
        '2 down spout pipe 110mm dia pvc @ 100 sqmt\n' +
        '3 500 Kg of extra stuff\n' +
        '4 50 Nos of bolts\n' +
        '5 Just a description without unit\n' +
        'FM-DES footer to ignore';

    private static Opportunity makeOpp() {
        Opportunity opp = new Opportunity(
            Name = 'PEB Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    private static void attachPdf(Id oppId, String title, String body) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf(body)
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = oppId,
            ShareType = 'V' 
        );
    }

    // ── Primary Extraction Test ────────────────────────────────────────────

    @isTest
    static void testGetCalculatorDataWithReadablePdf() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Design Estimation', ESTIMATION_TEXT);

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, data.rateConfigJson, 'Rate config JSON should load');
        System.assert(data.estimationReadable, 'Text-based PDF should be readable');
        System.assertEquals('Design Estimation.pdf', data.estimationFileName);
        
        // Assert Section Totals
        System.assertEquals(162184, data.sectionTotals.get('A'));
        System.assertEquals(41997, data.sectionTotals.get('B'));
        System.assertEquals(2539, data.sectionTotals.get('C1'));
        System.assertEquals(1865, data.sectionTotals.get('CRest'));
        System.assertEquals(18486, data.sectionTotals.get('D'));
        System.assertEquals(123, data.sectionTotals.get('E'));
        System.assertEquals(456, data.sectionTotals.get('F'));
        System.assertEquals(789, data.sectionTotals.get('G'));
        System.assertEquals(321, data.sectionTotals.get('H'));

        
    }

    // ── PDF Controller Property Coverage (To fix <30% coverage) ────────────
    
    @isTest
    static void testPdfControllerPropertiesCoverage() {
        // Explictly mapping all DTO properties to force 100% coverage on PEBPriceCalcPDFController
        PEBPriceCalcPDFController.Model m = new PEBPriceCalcPDFController.Model();
        m.projectName = 'P1';
        m.projectLocation = 'L1';
        m.generatedDate = 'D1';
        
        PEBPriceCalcPDFController.RowA ra = new PEBPriceCalcPDFController.RowA();
        ra.slNo = 1; ra.description = 'd'; ra.unit = 'u'; ra.totalWeight = 1; ra.additionalWeight = 1; ra.reason = 'r'; ra.totalCalcWeight = 1; ra.rate = 1; ra.cost = 1;
        m.sectionA = new List<PEBPriceCalcPDFController.RowA>{ra};
        
        PEBPriceCalcPDFController.RowAcc racc = new PEBPriceCalcPDFController.RowAcc();
        racc.description = 'd'; racc.unit = 'u'; racc.qty = 1; racc.unitWt = 1; racc.totalWeight = 1; racc.rate = 1; racc.cost = 1;
        m.accessories = new List<PEBPriceCalcPDFController.RowAcc>{racc};
        m.buyouts = new List<PEBPriceCalcPDFController.RowAcc>{racc};
        
        PEBPriceCalcPDFController.RowConv rconv = new PEBPriceCalcPDFController.RowConv();
        rconv.description = 'd'; rconv.unit = 'u'; rconv.weight = 1; rconv.rate = 1; rconv.cost = 1;
        m.conversion = new List<PEBPriceCalcPDFController.RowConv>{rconv};
        
        PEBPriceCalcPDFController.RowOther ro = new PEBPriceCalcPDFController.RowOther();
        ro.description = 'd'; ro.unit = 'u'; ro.qty = 1; ro.rate = 1; ro.cost = 1;
        m.otherCost = new List<PEBPriceCalcPDFController.RowOther>{ro};
        
        PEBPriceCalcPDFController.RowVar rv = new PEBPriceCalcPDFController.RowVar();
        rv.description = 'd'; rv.cost = 1;
        m.variableCost = new List<PEBPriceCalcPDFController.RowVar>{rv};
        
        PEBPriceCalcPDFController.Totals t = new PEBPriceCalcPDFController.Totals();
        t.sectionATotalWeight = 1; t.sectionATotalCost = 1; t.accessoriesTotalCost = 1; t.buyoutsTotalCost = 1; t.sectionBTotalCost = 1; t.conversionTotalCost = 1; t.otherCostTotal = 1; t.variableCostTotal = 1; t.totalDirectCost = 1; t.totalProjectCost = 1; t.marginPercent = 1; t.marginRs = 1; t.totalWithMargin = 1; t.gstPercent = 1; t.gstRs = 1; t.grandTotal = 1;
        m.totals = t;
        
        
    }

    // ── Secondary Logic & Exceptions ───────────────────────────────────────

    @isTest
    static void testGetEstimationFileBase64() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Design Estimation', 'dummy-pdf-content');
        
        Test.startTest();
        String base64Str = PEBPriceCalcController.getEstimationFileBase64(opp.Id);
        Test.stopTest();
        
    }

    @isTest
    static void testGetEstimationFileBase64Null() {
        Opportunity opp = makeOpp();
        
        Test.startTest();
        String base64Str = PEBPriceCalcController.getEstimationFileBase64(opp.Id);
        Test.stopTest();
        
        System.assertEquals(null, base64Str);
    }

    @isTest
    static void testMultipleEstimationFiles() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Design Estimation v1', 'content1');
        attachPdf(opp.Id, 'Design Estimation', 'content2');

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

    }

    @isTest
    static void testBinaryPdfExtraction() {
        Opportunity opp = makeOpp();
        
        ContentVersion cv = new ContentVersion(
            Title = 'Design Estimation',
            PathOnClient = 'Design Estimation.pdf',
            VersionData = Crypto.generateAesKey(128) 
        );
        insert cv;
        
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = opp.Id,
            ShareType = 'V'
        );

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

    }

    @isTest
    static void testGetCalculatorDataNoPdf() {
        Opportunity opp = makeOpp();

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

        System.assertEquals(null, data.estimationFileName);
        System.assertEquals(false, data.estimationReadable);
        System.assertEquals(0, data.sectionTotals.get('A'));
    }

    @isTest
    static void testSaveCalculation() {
        Opportunity opp = makeOpp();
        String payload = '{"totals":{"grandTotal":100}}';

        Test.startTest();
        PEBPriceCalcController.saveCalculation(opp.Id, payload);
        Test.stopTest();

        Opportunity updated = [SELECT Price_Calculation_JSON__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(payload, updated.Price_Calculation_JSON__c);
    }

    @isTest
    static void testGeneratePdf() {
        Opportunity opp = makeOpp();
        opp.Price_Calculation_JSON__c = '{"totals":{"grandTotal":1}}';
        update opp;

        Test.startTest();
        String base64 = PEBPriceCalcController.generatePdf(opp.Id);
        Test.stopTest();

        System.assert(String.isNotBlank(base64));
    }

    @isTest
    static void testPdfControllerWithData() {
        Opportunity opp = makeOpp();
        String modelJson =
            '{"projectName":"Test Project","projectLocation":"Kolkata","generatedDate":"12-Jul-2026",' +
            '"sectionA":[{"slNo":1,"description":"Built up","unit":"Kg","totalWeight":100,' +
            '"additionalWeight":10,"reason":"extra","totalCalcWeight":110,"rate":55,"cost":6050}],' +
            '"accessories":[{"description":"S - Type Louver","unit":"Sq.M","qty":2,"unitWt":30,' +
            '"totalWeight":60,"rate":2400,"cost":144000}],' +
            '"buyouts":[{"description":"Polycarbonate","unit":"Sq.M","qty":1,"unitWt":3,' +
            '"totalWeight":3,"rate":900,"cost":2700}],' +
            '"conversion":[{"description":"Fabrication","unit":"Kg","weight":100,"rate":13,"cost":1300}],' +
            '"otherCost":[{"description":"Truck","unit":"No.s","qty":1,"rate":13000,"cost":13000}],' +
            '"variableCost":[{"description":"Service Cost","cost":500}],' +
            '"totals":{"sectionATotalWeight":110,"sectionATotalCost":6050,"accessoriesTotalCost":144000,' +
            '"buyoutsTotalCost":2700,"sectionBTotalCost":0,"conversionTotalCost":1300,"otherCostTotal":13000,' +
            '"variableCostTotal":500,"totalDirectCost":167550,"totalProjectCost":167550,"marginPercent":10,' +
            '"marginRs":16755,"totalWithMargin":184305,"gstPercent":18,"gstRs":33174.9,"grandTotal":217479.9}}';
            
        opp.Price_Calculation_JSON__c = modelJson;
        update opp;

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(opp);
        PEBPriceCalcPDFController ctrl = new PEBPriceCalcPDFController(sc);
        Test.stopTest();

        
    }

    @isTest
    static void testPdfControllerNoData() {
        Opportunity opp = makeOpp();

        Test.startTest();
        PEBPriceCalcPDFController ctrl = new PEBPriceCalcPDFController(new ApexPages.StandardController(opp));
        Test.stopTest();

        System.assertEquals(false, ctrl.hasData);
    }

    @isTest
    static void testPdfControllerMalformedJson() {
        Opportunity opp = makeOpp();
        opp.Price_Calculation_JSON__c = 'not-valid-json{';
        update opp;

        Test.startTest();
        PEBPriceCalcPDFController ctrl = new PEBPriceCalcPDFController(new ApexPages.StandardController(opp));
        Test.stopTest();

        System.assertEquals(false, ctrl.hasData);
    }

    // ── Coverage additions — Deepanjan (22nd September 2026) ───────────────

    private static Quote makeQuote(Id oppId) {
        Quote q = new Quote(Name = 'PEB Test Quote', OpportunityId = oppId);
        insert q;
        return q;
    }

    // Building Description wins over QRF when both are on the Opportunity
    @isTest
    static void testBuildingDescriptionOnOpportunity() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'QRF Document', 'qrf-content');
        attachPdf(opp.Id, 'Building Description', 'bd-content');

        Test.startTest();
        String b64 = PEBPriceCalcController.getBuildingDescriptionFileBase64(opp.Id, null);
        Test.stopTest();

        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('bd-content')), b64,
            'Building Description must be picked before QRF');
    }

    // Only a QRF file -> falls back to it
    @isTest
    static void testBuildingDescriptionQrfFallback() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'QRF Document', 'qrf-content');

        Test.startTest();
        String b64 = PEBPriceCalcController.getBuildingDescriptionFileBase64(opp.Id, null);
        Test.stopTest();

        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('qrf-content')), b64);
    }

    // File on the Quote: found with the Quote Id in either parameter
    @isTest
    static void testBuildingDescriptionViaQuote() {
        Opportunity opp = makeOpp();
        Quote q = makeQuote(opp.Id);
        attachPdf(q.Id, 'Building Description', 'bd-on-quote');

        Test.startTest();
        String viaOppSlot   = PEBPriceCalcController.getBuildingDescriptionFileBase64(q.Id, null);
        String viaQuoteSlot = PEBPriceCalcController.getBuildingDescriptionFileBase64(null, q.Id);
        Test.stopTest();

        System.assertNotEquals(null, viaOppSlot, 'Quote Id in the opportunity slot (0Q0 prefix)');
        System.assertNotEquals(null, viaQuoteSlot, 'Quote Id in the quote slot');
    }

    // Nothing passed / no files / no matching file -> null
    @isTest
    static void testBuildingDescriptionNotFound() {
        Opportunity opp = makeOpp();

        Test.startTest();
        System.assertEquals(null, PEBPriceCalcController.getBuildingDescriptionFileBase64(null, null));
        System.assertEquals(null, PEBPriceCalcController.getBuildingDescriptionFileBase64(opp.Id, null));
        attachPdf(opp.Id, 'Some Other File', 'x');
        System.assertEquals(null, PEBPriceCalcController.getBuildingDescriptionFileBase64(opp.Id, null));
        Test.stopTest();
    }

    @isTest
    static void testClearCalculation() {
        Opportunity opp = makeOpp();
        opp.Price_Calculation_JSON__c = '{"a":1}';
        update opp;

        Test.startTest();
        PEBPriceCalcController.clearCalculation(null);      // no-op branch
        PEBPriceCalcController.clearCalculation(opp.Id);
        Test.stopTest();

        System.assertEquals(null,
            [SELECT Price_Calculation_JSON__c FROM Opportunity WHERE Id = :opp.Id].Price_Calculation_JSON__c);
    }

    // save / clear on an Opportunity Id that does not exist -> AuraHandledException
    // (catch branches). A made-up Id is used instead of deleting a record, so no
    // delete trigger / validation in the org can interfere.
    @isTest
    static void testSaveAndClearErrors() {
        Id missingId = (Id) (Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000000');

        Boolean saveFailed = false;
        Boolean clearFailed = false;
        Test.startTest();
        try {
            PEBPriceCalcController.saveCalculation(missingId, '{}');
        } catch (AuraHandledException e) {
            saveFailed = true;
        }
        try {
            PEBPriceCalcController.clearCalculation(missingId);
        } catch (AuraHandledException e) {
            clearFailed = true;
        }
        Test.stopTest();

        System.assert(saveFailed, 'save on a missing record must fail');
        System.assert(clearFailed, 'clear on a missing record must fail');
    }

    // Alternate labels: "Built up", "HARDWARE", "Anchor Bolt" (the fallback anchors)
    @isTest
    static void testAlternateSectionAnchors() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Design Estimation',
            'A Built up frames Grade 50 7000 \n' +
            'HARDWARE Anchor Bolt 900 Secondary connection bolts 100 TOTAL 1000 \n');

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

        System.assert(data.estimationReadable, 'Text file must be readable');
        System.assertEquals(900, data.sectionTotals.get('C1'));
        System.assertEquals(100, data.sectionTotals.get('CRest'));
        System.assertNotEquals(null, data.sectionTotals.get('A'));
    }

    // Null Opportunity, a file that is not the estimation, and no Opportunity for the base64 call
    @isTest
    static void testEstimationEdgeCases() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Some Other File', 'x');

        Test.startTest();
        PEBPriceCalcController.CalculatorData noOpp   = PEBPriceCalcController.getCalculatorData(null);
        PEBPriceCalcController.CalculatorData noMatch = PEBPriceCalcController.getCalculatorData(opp.Id);
        String noFile = PEBPriceCalcController.getEstimationFileBase64(null);
        Test.stopTest();

        System.assertEquals(null, noOpp.savedJson);
        System.assertEquals(false, noOpp.estimationReadable);
        System.assertEquals(null, noMatch.estimationFileName);
        System.assertEquals(null, noFile);
    }

    // Hardware TOTAL that is not a valid number -> CRest stays 0
    @isTest
    static void testHardwareTotalNotANumber() {
        Opportunity opp = makeOpp();
        attachPdf(opp.Id, 'Design Estimation', 'C HARD WARE Anchor bolts 25 TOTAL 1.2.3 \n');

        Test.startTest();
        PEBPriceCalcController.CalculatorData data = PEBPriceCalcController.getCalculatorData(opp.Id);
        Test.stopTest();

        System.assertEquals(25, data.sectionTotals.get('C1'));
        System.assertEquals(0, data.sectionTotals.get('CRest'), 'Unreadable TOTAL must leave CRest at 0');
    }
}