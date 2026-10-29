/*
 * Class Name  : TestTelecomDocumentController
 * Description : Test class for TelecomDocumentController.
 * Author      : Rajeev Kumar
 * Date        : 03 June 2026
 */
@IsTest
private class TestTelecomDocumentController {

    @TestSetup
    static void makeData() {

        Account acc = new Account(
            Name          = 'Test Account',
            AccountSource = 'Website',
            Phone         = '678955757',
            BillingStreet = '456 Billing Street', BillingCity = 'Patna',
            BillingState  = 'Bihar', BillingPostalCode = '800001', BillingCountry = 'India',
            ShippingStreet= '123 Shipping Street', ShippingCity = 'Mithapur',
            ShippingState = 'Bihar', ShippingPostalCode = '800001', ShippingCountry = 'India'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name      = 'Test Opportunity',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        List<Quote> qs = new List<Quote>{
            newQuote('General',      opp.Id, JSON.serialize(buildGeneralData())),
            newQuote('TubularSig',   opp.Id, JSON.serialize(buildTubularSignallingData())),
            newQuote('TubNoProduct', opp.Id, JSON.serialize(buildTubularNoProductData())),
            newQuote('Blank',        opp.Id, null),
            newQuote('BadJson',      opp.Id, '{ not valid json ')
        };
        insert qs;
    }

    private static Quote newQuote(String name, Id oppId, String val) {
        return new Quote(
            Name              = name,
            OpportunityId     = oppId,
            Status            = 'Draft',
            Quote_Value__c    = val,
            submition_date__c = Date.today()
        );
    }

    private static ApexPages.StandardController stdCtrl(Id qId) {
        return new ApexPages.StandardController(new Quote(Id = qId));
    }

    /** One "_Saved_Table_Rows" entry */
    private static Map<String, Object> line(String name, Object unitPrice, Integer qty) {
        return new Map<String, Object>{
            'name'      => name,
            'unitPrice' => unitPrice,
            'quantity'  => qty,
            'netPrice'  => unitPrice,
            'uom'       => 'EA'
        };
    }

    /* ---- General table payload (type_of_tower != 'Tubular Signalling') ---- */
    private static Map<String, Object> buildGeneralData() {
        Map<String, Object> d = new Map<String, Object>();
        d.put('type_of_tower', 'Tubular');                 // -> general table path
        d.put('tele_for_type', 'Minimum Guaranteed Loadability');
        d.put('Incoterms', 'F.O.R');                        // hasForIncoterms branch
        d.put('tub_material_list', 'BOM Not Availabel');    // isBOMNotAvailable branch

        // ang_* keys for 3 part rows (angIdx 1..3)
        for (Integer i = 1; i <= 3; i++) {
            d.put('ang_tower_weight' + i, i);
            d.put('ang_uom' + i, 'SET');
            d.put('ang_rate_per_mt' + i, 106531);
            d.put('ang_basic_rate' + i, 426124 * i);
            d.put('ang_total_value' + i, 2130620 * i);
        }

        // mgl_* keys for 3 MGL rows
        for (Integer i = 1; i <= 3; i++) {
            d.put('mgl_location_' + i, 'MGL Loc ' + i);
            d.put('mgl_description_of_the_tower_' + i, 'Desc ' + i);
            d.put('mgl_vehicle_loadability_' + i, i * 10);
            d.put('mgl_minimum_guranteed_freight_' + i, i * 100);
        }

        List<Object> rows = new List<Object>{
            line('TELECOM TOWER PART DETAILS - Tubular - ab', 426124, 5),
            line('TELECOM TOWER PART DETAILS - Tubular - bc', 213062, 5),
            line('TELECOM TOWER PART DETAILS - Angular - cd', 319593, 8),  // 2nd sub-type
            line('MINIMUM GUARANTEED LOADABILITY - Minimum Guaranteed Loadability - a', 2, 1),
            line('MINIMUM GUARANTEED LOADABILITY - Minimum Guaranteed Loadability - c', 4, 1),
            line('MINIMUM GUARANTEED LOADABILITY - Minimum Guaranteed Loadability - e', 6, 1)
        };
        d.put('_Saved_Table_Rows', rows);
        return d;
    }

    /* ---- Tubular Signalling payload ---- */
    private static Map<String, Object> buildTubularSignallingData() {
        Map<String, Object> d = new Map<String, Object>();
        d.put('type_of_tower', 'Tubular Signalling');       // -> tubular signalling path
        d.put('tele_for_type', 'Per Metric Ton');           // isRPTForType branch
        d.put('Incoterms', 'Ex-works');                     // hasExIncoterms branch
        d.put('tub_material_list', 'BOM Availabel');         // isBOMAvailable branch

        // Product index
        d.put('tub_product_details1', 'ProdA');
        d.put('tub_product_details2', 'ProdB');

        // GSM toggles: 610 & 900 enabled, 1000 disabled (exercises the skip)
        d.put('ang_gsm_610', true);
        d.put('ang_gsm_900', true);
        d.put('ang_gsm_1000', false);

        // Tubular value keys
        d.put('tub_tower_weight1', 4);  d.put('tub_tower_weight2', 2);
        d.put('tub_rate_per_mt1_610', 106531);
        d.put('tub_basic_rate1_610', 426124);               // non-zero -> normal path
        d.put('tub_total_value1_610', 2130620);
        d.put('tub_rate_per_mt2_610', 106531);
        d.put('tub_basic_rate2_610', 0);                    // zero -> unitPrice fallback path
        d.put('tub_total_value2_610', 0);
        d.put('tub_rate_per_mt1_900', 106531);
        d.put('tub_basic_rate1_900', 500000);
        d.put('tub_total_value1_900', 2500000);

        // rpt_* keys for RPT rows
        d.put('rpt_sl_no1', 1); d.put('rpt_location_1', 'RPT Loc 1'); d.put('rpt_rate_per_ton_1', 100);
        d.put('rpt_sl_no2', 2); d.put('rpt_location_2', 'RPT Loc 2'); d.put('rpt_rate_per_ton_2', 200);

        List<Object> rows = new List<Object>{
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - ProdA - 610 GSM', 426124, 5),
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - ProdB - 610 GSM', 213062, 3),
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - ProdA - 900 GSM', 500000, 2),
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - Unknown - 610 GSM', 100, 1), // idx null -> skip
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - ProdA - 1000 GSM', 100, 1),  // gsm disabled -> skip
            line('PER METRIC TON RATE - Per Metric Ton - c', 100, 1),
            line('PER METRIC TON RATE - Per Metric Ton - d', 200, 1)
        };
        d.put('_Saved_Table_Rows', rows);
        return d;
    }

    /* ---- Tubular Signalling but no products + blank Incoterms ---- */
    private static Map<String, Object> buildTubularNoProductData() {
        Map<String, Object> d = new Map<String, Object>();
        d.put('type_of_tower', 'Tubular Signalling');       // -> tubular path, empty product index -> early return
        d.put('Incoterms', '');                             // blank -> defaults to 'Ex-works'
        d.put('_Saved_Table_Rows', new List<Object>{
            line('TELECOM TOWER PART DETAILS - Tubular Signalling - ProdA - 610 GSM', 100, 1)
        });
        return d;
    }

    @IsTest
    static void testGeneralTable() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'General' LIMIT 1];

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.isNotNull(ctrl.quoteRecord, 'quoteRecord should be populated');
        Assert.areEqual('Test Account', ctrl.quoteAccount, 'Account name should match');
       
    }

    @IsTest
    static void testTubularSignallingTable() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'TubularSig' LIMIT 1];

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.isTrue(ctrl.hasTowerGroups, 'Tubular Signalling groups should be built');
        // 610 group (ProdA + ProdB) and 900 group (ProdA); 1000 skipped
        Assert.areEqual(2, ctrl.getTowerTables().size(), 'Two GSM groups expected');
        Assert.isTrue(ctrl.hasRPTRows, 'RPT rows should be built');
        Assert.areEqual(2, ctrl.rptRows.size(), 'Two RPT rows expected');
        Assert.isTrue(ctrl.isRPTForType, 'forType should be Per Metric Ton');
        Assert.isTrue(ctrl.hasExIncoterms, 'Ex-works incoterms flag should be set');
        Assert.isTrue(ctrl.isBOMAvailable, 'BOM-available flag should be set');
    }

    @IsTest
    static void testTubularNoProductsAndBlankIncoterms() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'TubNoProduct' LIMIT 1];

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.isFalse(ctrl.hasTowerGroups, 'No groups when product index is empty');
        Assert.areEqual('Ex-works', ctrl.incotermsVal, 'Blank Incoterms should default to Ex-works');
    }

    @IsTest
    static void testBlankQuoteValue() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Blank' LIMIT 1];

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(q.Id));
        Test.stopTest();

        // initSafetyKeys() should have guarded every collection / scalar
        Assert.isNotNull(ctrl.quoteRecord, 'quoteRecord should still be populated');
        Assert.isNotNull(ctrl.towerDetailGroups, 'towerDetailGroups should be non-null');
        Assert.isTrue(ctrl.towerDetailGroups.isEmpty(), 'No groups for blank JSON');
        Assert.isFalse(ctrl.hasTowerGroups, 'hasTowerGroups defaults to false');
        Assert.areEqual(0.00, ctrl.totalAmount, 'totalAmount defaults to 0');
    }

    @IsTest
    static void testInvalidJson() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'BadJson' LIMIT 1];

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(q.Id)); // hits catch
        Test.stopTest();

        Assert.isFalse(ctrl.hasTowerGroups, 'No groups after parse failure');
        Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'Parse error message should be added');
    }

    @IsTest
    static void testRecordNotFound() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote temp = newQuote('Temp', opp.Id, null);
        insert temp;
        Id deletedId = temp.Id;
        delete temp; // valid-format Id that no longer exists -> "not found" path

        Test.startTest();
        TelecomDocumentController ctrl = new TelecomDocumentController(stdCtrl(deletedId));
        Test.stopTest();

        Assert.isNull(ctrl.quoteRecord, 'quoteRecord should be null when not found');
        Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'Not-found message should be added');
    }
}