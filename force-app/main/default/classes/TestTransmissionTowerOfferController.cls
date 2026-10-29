/*
 * Class Name  : TestTransmissionTowerOfferController
 * Description : Test class for TransmissionTowerOfferController & CostingExportController.
 * Author      : Rajeev Kumar
 * Date        : 03 June 2026             
 * 
 */

@IsTest
private class TestTransmissionTowerOfferController {

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

        // Costing variant with empty price-modules (hits the default "Blooms & Billets" branch)
        Map<String, Object> emptyModule = baseData('Substation', '', false, false);
        emptyModule.put('pvt_price_module', '');
        emptyModule.put('pvs_price_module', '');

        List<Quote> qs = new List<Quote>{
            newQuote('Tower PMT',    opp.Id, JSON.serialize(baseData('Tower',      'Per Metric Ton',                 true,  false))),
            newQuote('Tower MGL',    opp.Id, JSON.serialize(baseData('Tower',      'Minimum Guaranteed Loadability', false, true))),
            newQuote('Substation',   opp.Id, JSON.serialize(baseData('Substation', '',                               false, false))),
            newQuote('Costing',      opp.Id, JSON.serialize(baseData('Substation', '',                               false, false))),
            newQuote('CostingEmpty', opp.Id, JSON.serialize(emptyModule)),
            newQuote('Blank',        opp.Id, null),
            newQuote('BadJson',      opp.Id, '{ this is not valid json ')
        };
        insert qs;
    }

    private static Quote newQuote(String name, Id oppId, String val) {
        return new Quote(
            Name           = name,
            OpportunityId  = oppId,
            Status         = 'Draft',
            Quote_Value__c = val,
            submition_date__c = Date.today()
        );
    }

    private static ApexPages.StandardController stdCtrl(Id qId) {
        return new ApexPages.StandardController(new Quote(Id = qId));
    }

    /** One "_Saved_Table_Rows" entry */
    private static Map<String, Object> line(String name, Object unitPrice, Object qty) {
        return new Map<String, Object>{
            'name'      => name,
            'unitPrice' => unitPrice,
            'quantity'  => qty,
            'netPrice'  => unitPrice,
            'uom'       => 'EA'
        };
    }

    /**
     * Builds a complete dummy JSON payload covering both controllers.
     * @param productType  'Tower' | 'Substation'
     * @param projectType  'Per Metric Ton' | 'Minimum Guaranteed Loadability' | ''
     */
    private static Map<String, Object> baseData(String productType, String projectType,
                                                Boolean includeRpt, Boolean includeMgl) {
        Map<String, Object> d = new Map<String, Object>();

        d.put('type_of_product', productType);
        // '' -> controller falls back to 'Ex-works'; non-empty keeps value
        d.put('Incoterms', productType == 'Tower' ? '' : 'F.O.R (Freight on Road)');
        d.put('tower_project_for_type', projectType);
        d.put('tower_project_for_transportation_addition', includeRpt ? 'YES' : 'NO');

        // Pricing type
        d.put('pvt_price_basics', 'Price Variation');            // Tower -> PV
        if (productType == 'Substation') d.put('pvs_price_model', 'Firm'); // Substation -> Firm

        // Proto assembly (PV for tower, Firm for substation)
        d.put('pvt_pv_pat', true);   d.put('pvt_pv_pat_price', '10000');
        d.put('pvs_firm_pat', true); d.put('pvs_firm_pat_price', '7000');

        // Nuts & bolts + structure flags
        for (String k : new List<String>{
                'pvt_type_5_6','pvt_type_6_8','pvt_type_8_8',
                'pvt_foundation_bolt_checkbox','pvt_ms_template_without_galvanization_checkbox',
                'pvs_type_5_6','pvs_type_6_8','pvs_type_8_8',
                'pvs_foundation_bolt_checkbox','pvs_ms_template_without_galvanization_checkbox',
                'pvs_gantry_structure','pvs_equipment_structure','pvs_composite_structure' }) {
            d.put(k, true);
        }

        // Module display names (PGCIL -> Blooms, IEEMA -> Blooms & Billets)
        d.put('pvt_price_module', 'PGCIL');
        d.put('pvs_price_module', 'IEEMA');

        // MS-template price keys – Tower
        d.put('pvs_N28', 72098.649); d.put('pvs_N44', 72098.649); d.put('pvs_N59', 72098.649);
        d.put('pvs_U28', 94247);     d.put('pvs_U44', 94247);     d.put('pvs_U59', 94247);

        // MS-template price keys – Substation (one negative to exercise the sign path)
        d.put('pvs_AH35', 112409.065); d.put('pvs_AH92', -5000);     d.put('pvs_AH149', 59173.097);
        d.put('pvs_AP35', 77936.132);  d.put('pvs_AP92', 62323.097); d.put('pvs_AP149', 16000);

        // Costing value keys – Tower PV
        d.put('pvt_pv_billets', 38520); d.put('pvt_pv_avg_of_blooms', 38225);
        d.put('pvt_pv_convergence_to_angles', 8500);
        d.put('pvt_pv_zinc_value_610', 10692); d.put('pvt_pv_zinc_value_900', 15692); d.put('pvt_pv_zinc_value_1000', 16692);
        d.put('pvt_pv_scrap', 1.5); d.put('pvt_pv_scrap_value', 700.60);   // .60 -> trailing-zero strip
        d.put('pvt_pv_interest_component_on_product_cycle', 2000);
        d.put('pvt_pv_cost_of_production', 9000); d.put('pvt_pv_margin', 5);
        d.put('pvt_pv_additional_pricing', 3500);
        d.put('pvt_pv_bank_interest', 500); d.put('pvt_pv_no_of_days', 2);

        // Tower FIRM
        d.put('pvt_firm_angles', 58000);
        d.put('pvt_firm_zinc_value_610', 15300); d.put('pvt_firm_zinc_value_900', 19300); d.put('pvt_firm_zinc_value_1000', 21300);
        d.put('pvt_firm_scrap', 1.5); d.put('pvt_firm_scrap_value', 870);   // >0 -> pctSuffix non-empty
        d.put('pvt_firm_cost_of_production', 9000);
        d.put('pvt_firm_interest_component_on_product_cycle', 2000);
        d.put('pvt_firm_margin', 5);
        d.put('pvt_firm_bank_interest', 600); d.put('pvt_firm_no_of_days', 2);

        // Substation PV
        d.put('pvs_pv_billets', 45054); d.put('pvs_pv_avg_of_blooms', 44369.5);
        d.put('pvs_pv_conversion_to_angle', 8500);
        d.put('pvs_pv_zinc_value_610', 10701); d.put('pvs_pv_zinc_value_900', 15701); d.put('pvs_pv_zinc_value_1000', 0);
        d.put('pvs_pv_scrap', 1.5); d.put('pvs_pv_scrap_value', 793.04);    // .04 -> zero-pad branch
        d.put('pvs_pv_cost_of_production', 13000);
        d.put('pvs_pv_interest_component_on_product_cycle', 2000);
        d.put('pvs_pv_margin', 5);
        d.put('pvs_BJ34', 32); d.put('pvs_pv_no_of_days', 2);

        // Substation FIRM  (pvs_firm_scrap intentionally omitted -> pctSuffix empty branch)
        d.put('pvs_firm_angles', 58000);
        d.put('pvs_firm_zinc_value_610', 15300); d.put('pvs_firm_zinc_value_900', 0); d.put('pvs_firm_zinc_value_1000', 0);
        d.put('pvs_firm_scrap_value', 870);
        d.put('pvs_firm_cost_of_production', 13000);
        d.put('pvs_firm_interest_component_on_product_cycle', 2000);
        d.put('pvs_firm_margin', 5);
        d.put('pvs_BT29', 36); d.put('pvs_firm_no_of_days', 2);

        // MS-template detail keys used by CostingExportController.getMsTemplatePriceForStructure
        d.put('pvs_detail_ms_template_price_pv_gantry', 72098.649);
        d.put('pvs_detail_ms_template_price_pv_equipment', 72098.649);
        d.put('pvs_detail_ms_template_price_pv_composite', -5000);          // sign path
        d.put('pvs_detail_ms_template_price_pv_tower', 72098.649);
        d.put('pvs_detail_ms_template_price_firm_gantry', 0);
        d.put('pvs_detail_ms_template_price_firm_equipment', 0);
        d.put('pvs_detail_ms_template_price_firm_composite', 0);

        // ---- Saved table rows ----
        List<Object> rows = new List<Object>();

        // Tower: MS/HT + full nuts set for PV & FIRM across all GSM
        for (String pc : new List<String>{ 'PV', 'FIRM' }) {
            for (String gsm : new List<String>{ '610', '900', '1000' }) {
                rows.add(line('PRICE MODEL - TOWER - ' + pc + '-MS-' + gsm + ' GSM', 80000, 10));
                rows.add(line('PRICE MODEL - TOWER - ' + pc + '-HT-' + gsm + ' GSM', 84000, 12));
                rows.add(line('Nuts & Bolts - GRADE - 5.6 [Tower | ' + pc + '-' + gsm + ' GSM]', 110048, 1));
                rows.add(line('Nuts & Bolts - GRADE - 6.8 [Tower | ' + pc + '-' + gsm + ' GSM]', 124000, 1));
                rows.add(line('Nuts & Bolts - GRADE - 8.8 [Tower | ' + pc + '-' + gsm + ' GSM]', 130000, 1));
                rows.add(line('Nuts & Bolts - FOUNDATION BOLT [Tower | ' + pc + '-' + gsm + ' GSM]', 102645, 1));
                rows.add(line('Nuts & Bolts - MS TEMPLATE (' + pc + ') [Tower | ' + pc + '-' + gsm + ' GSM]', 56023, 1));
            }
        }

        // Substation: one structure per GSM so every structure branch is exercised
        Map<String, String> gsmStruct = new Map<String, String>{
            '610' => 'Gantry', '900' => 'Equipment', '1000' => 'Composite' };
        for (String pc : new List<String>{ 'PV', 'FIRM' }) {
            for (String gsm : new List<String>{ '610', '900', '1000' }) {
                String st = gsmStruct.get(gsm);
                rows.add(line('PRICE MODEL - SUBSTATION - ' + pc + '-' + st + ' Structure-MS-' + gsm + ' GSM', 79000, 1));
                rows.add(line('PRICE MODEL - SUBSTATION - ' + pc + '-' + st + ' Structure-HT-' + gsm + ' GSM', 82000, 1));
                rows.add(line('Nuts & Bolts - GRADE - 5.6 [' + st + ' | ' + pc + '-' + gsm + ' GSM]', 110048, 1));
                rows.add(line('Nuts & Bolts - GRADE - 6.8 [' + st + ' | ' + pc + '-' + gsm + ' GSM]', 124000, 1));
                rows.add(line('Nuts & Bolts - GRADE - 8.8 [' + st + ' | ' + pc + '-' + gsm + ' GSM]', 130000, 1));
                rows.add(line('Nuts & Bolts - FOUNDATION BOLT [' + st + ' | ' + pc + '-' + gsm + ' GSM]', 102645, 1));
            }
        }
        d.put('_Saved_Table_Rows', rows);

        // Per Metric Ton freight rows
        if (includeRpt) {
            for (Integer i = 1; i <= 3; i++) {
                d.put('rpt_location_' + i, 'Location ' + i);
                d.put('rpt_rate_per_ton_' + i, String.valueOf(20 + i));
            }
        }

        // Minimum Guaranteed Loadability rows
        if (includeMgl) {
            for (Integer i = 1; i <= 3; i++) {
                d.put('mgl_location_' + i, 'MGL Location ' + i);
                d.put('mgl_description_of_the_tower_' + i, 'Tower Description ' + i);
                d.put('mgl_vehicle_loadability_' + i, String.valueOf(25 + i));
                d.put('mgl_minimum_guranteed_freight_' + i, String.valueOf(1000 + i));
            }
        }

        return d;
    }

    @IsTest
    static void testTowerOffer_PerMetricTon() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Tower PMT' LIMIT 1];

        Test.startTest();
        TransmissionTowerOfferController ctrl = new TransmissionTowerOfferController(stdCtrl(q.Id));
        List<TransmissionTowerOfferController.TowerPriceTable>      towers  = ctrl.getTowerTables();
        List<TransmissionTowerOfferController.SubstationPriceTable> subs    = ctrl.getSubstationTables();
        List<TransmissionTowerOfferController.FreightRow>           freight = ctrl.getFreightRows();
        List<TransmissionTowerOfferController.LoadabilityRow>       load    = ctrl.getLoadabilityRows();
        Test.stopTest();

        Assert.isFalse(towers.isEmpty(),  'Tower tables should be built');
        Assert.isFalse(subs.isEmpty(),    'Substation tables should be built');
        Assert.areEqual(3, freight.size(),'Three freight rows expected');
        Assert.isTrue(load.isEmpty(),     'No loadability rows for Per Metric Ton');
        Assert.areEqual('Ex-works', ctrl.hasIncoterms, 'Blank Incoterms should default to Ex-works');
        Assert.isTrue(ctrl.hasProtoAssembly, 'PV proto assembly flag should be set');
        Assert.areEqual('10000', ctrl.protoAssembly, 'Proto price should be read from JSON');
    }

    @IsTest
    static void testTowerOffer_MinimumGuaranteedLoadability() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Tower MGL' LIMIT 1];

        Test.startTest();
        TransmissionTowerOfferController ctrl = new TransmissionTowerOfferController(stdCtrl(q.Id));
        List<TransmissionTowerOfferController.LoadabilityRow> load    = ctrl.getLoadabilityRows();
        List<TransmissionTowerOfferController.FreightRow>     freight = ctrl.getFreightRows();
        Test.stopTest();

        Assert.areEqual(3, load.size(), 'Three loadability rows expected');
        Assert.isTrue(freight.isEmpty(),'No freight rows for MGL project type');
    }

    @IsTest
    static void testSubstationOffer() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Substation' LIMIT 1];

        Test.startTest();
        TransmissionTowerOfferController ctrl = new TransmissionTowerOfferController(stdCtrl(q.Id));
        List<TransmissionTowerOfferController.TowerPriceTable>      towers = ctrl.getTowerTables();
        List<TransmissionTowerOfferController.SubstationPriceTable> subs   = ctrl.getSubstationTables();
        Test.stopTest();

        Assert.isFalse(subs.isEmpty(),   'Substation tables should be built');
        Assert.isFalse(towers.isEmpty(), 'Tower tables should still parse');
        Assert.areEqual('F.O.R (Freight on Road)', ctrl.hasIncoterms, 'Incoterms should be preserved');
        Assert.isTrue(ctrl.hasProtoAssembly, 'Firm proto assembly flag should be set');
    }

    @IsTest
    static void testCostingExport() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Costing' LIMIT 1];

        Test.startTest();
        CostingExportController ctrl = new CostingExportController(stdCtrl(q.Id));
        List<CostingExportController.PriceTable> tables = ctrl.getPriceTables();
        Test.stopTest();

        Assert.isFalse(tables.isEmpty(), 'Costing price tables should be built');
        Assert.isTrue(ctrl.totalAmount > 0, 'Total amount should accumulate from netPrice');
        Assert.isTrue(tables[tables.size() - 1].isLast, 'Last table should be flagged');
    }

    @IsTest
    static void testCostingExport_DefaultModule() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'CostingEmpty' LIMIT 1];

        Test.startTest();
        CostingExportController ctrl = new CostingExportController(stdCtrl(q.Id));
        List<CostingExportController.PriceTable> tables = ctrl.getPriceTables();
        Test.stopTest();

        Assert.isFalse(tables.isEmpty(), 'Tables should build with default module label');
    }

    @IsTest
    static void testBlankQuoteValue() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Blank' LIMIT 1];

        Test.startTest();
        TransmissionTowerOfferController t = new TransmissionTowerOfferController(stdCtrl(q.Id));
        CostingExportController c = new CostingExportController(stdCtrl(q.Id)); // constructor-only (no rows to iterate)
        Test.stopTest();

        Assert.isTrue(t.getTowerTables().isEmpty(),       'No tower tables for blank JSON');
        Assert.isTrue(t.getSubstationTables().isEmpty(),  'No substation tables for blank JSON');
        Assert.isTrue(t.getFreightRows().isEmpty(),       'No freight rows for blank JSON');
        Assert.isTrue(t.getLoadabilityRows().isEmpty(),   'No loadability rows for blank JSON');
        Assert.isNotNull(c, 'Costing controller should still construct');
    }

    @IsTest
    static void testInvalidJson() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'BadJson' LIMIT 1];

        Test.startTest();
        TransmissionTowerOfferController t = new TransmissionTowerOfferController(stdCtrl(q.Id)); // hits catch
        CostingExportController c = new CostingExportController(stdCtrl(q.Id));                    // hits catch
        Test.stopTest();

        Assert.isTrue(t.getTowerTables().isEmpty(), 'Invalid JSON yields no tables');
        Assert.isNotNull(c, 'Costing controller should still construct after parse failure');
    }

    @IsTest
    static void testRecordNotFound() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote temp = newQuote('Temp', opp.Id, null);
        insert temp;
        Id deletedId = temp.Id;
        delete temp; // Id is now valid-format but not present -> "not found" path

        Test.startTest();
        TransmissionTowerOfferController t = new TransmissionTowerOfferController(stdCtrl(deletedId));
        CostingExportController c = new CostingExportController(stdCtrl(deletedId));
        Test.stopTest();

        Assert.isNull(t.quoteRecord, 'quoteRecord should be null when not found');
        Assert.isNull(c.quoteRecord, 'quoteRecord should be null when not found');
        Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error page message should be added');
    }
}