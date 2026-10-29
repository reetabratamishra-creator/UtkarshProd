/*
 * Class Name  : TestCrashBarrierQuoteController
 * Description : Test class for CrashBarrierQuoteController.
 * 
 */
@IsTest
private class TestCrashBarrierQuoteController {

    /* ============================ TEST DATA ============================ */

    @TestSetup
    static void makeData() {

        Account acc = new Account(
            Name = 'Test Account', AccountSource = 'Website', Phone = '678955757',
            BillingStreet = '456 Billing Street', BillingCity = 'Patna',
            BillingState = 'Bihar', BillingPostalCode = '800001', BillingCountry = 'India'
        );
        insert acc;

        Contact con = new Contact(LastName = 'Khatri', FirstName = 'Shubhas',
                                  Phone = '919999999999', Email = 'shubhas@test.com');
        insert con;

        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Nurture',
                                          CloseDate = Date.today().addDays(30), AccountId = acc.Id);
        insert opp;

        // Opportunity with NO account -> forces null-Account/null-Contact defaults
        Opportunity oppNoAcc = new Opportunity(Name = 'No Acct Opp', StageName = 'Nurture',
                                               CloseDate = Date.today().addDays(30));
        insert oppNoAcc;

        List<Quote> qs = new List<Quote>{
            newQuote('Full',        opp.Id,      con.Id, JSON.serialize(fullData())),
            newQuote('ShipAddr',    opp.Id,      con.Id, JSON.serialize(shippingForData())),
            newQuote('ExWorks',     opp.Id,      con.Id, JSON.serialize(exWorksData())),
            newQuote('OpenCredit',  opp.Id,      con.Id, JSON.serialize(paymentData('Against Open credit'))),
            newQuote('BG',          opp.Id,      con.Id, JSON.serialize(paymentData('Against BG'))),
            newQuote('LC',          opp.Id,      con.Id, JSON.serialize(paymentData('Against LC'))),
            newQuote('Advance',     opp.Id,      con.Id, JSON.serialize(paymentData('Advance'))),
            newQuote('Custom',      opp.Id,      con.Id, JSON.serialize(paymentData('Some Custom Term'))),
            newQuote('DefaultPay',  opp.Id,      con.Id, JSON.serialize(paymentData(''))),
            newQuote('No Acct/Con', oppNoAcc.Id, null,   JSON.serialize(exWorksData())),
            newQuote('Blank',       opp.Id,      con.Id, ''),
            newQuote('BadJson',     opp.Id,      con.Id, '{ not valid json ')
        };
         insert as system qs;
    }

    private static Quote newQuote(String name, Id oppId, Id conId, String val) {
        return new Quote(Name = name, OpportunityId = oppId, Status = 'Draft',
                         ContactId = conId, Quote_Value__c = val, Has_Quote_Value__c = true);
    }

    private static ApexPages.StandardController stdCtrl(Id qId) {
        return new ApexPages.StandardController(new Quote(Id = qId));
    }

    /* ---- One _Saved_Table_Rows / _Final_Apex_Lines entry ---- */
    private static Map<String, Object> line(String name, Object qty, Object unitPrice, Object expenses) {
        return new Map<String, Object>{
            'name' => name, 'quantity' => qty, 'uom' => 'EA',
            'unitPrice' => unitPrice, 'unitCost' => unitPrice, 'unitListPrice' => unitPrice,
            'netPrice' => unitPrice, 'listPrice' => unitPrice, 'weight' => 0,
            'expenses' => expenses, 'discount' => 0
        };
    }

    /*
     * Full payload: main product + Accessory + Misc + Additional Miscellaneous
     * lines in BOTH _Final_Apex_Lines and _Saved_Table_Rows, freight keys,
     * section input keys, FVF keys, and F.O.R billing-address freight.
     */
    private static Map<String, Object> fullData() {
        Map<String, Object> d = new Map<String, Object>();
        d.put('_Saved_Template_Name', 'Crash Barrier - Department');

        // Freight keys — one populated, one blank, one non-numeric (catch branch)
        d.put('wb_natrax_fvf', '120');
        d.put('rlw_full_Vehicle_freight', '');
        d.put('Thrie_SSSB_full_Vehicle_freight', 'abc');

        // UI-safeguard keys (rlw_show_original true branch)
        d.put('rlw_show_original', true);
        d.put('rlw_graded_section_beam_thickness_input', '3');
        d.put('rlw_non_graded_section_beam_thickness_input', '4');

        // Section input keys used by Accessory / Misc parsers
        d.put('acc_section_uom_input', 'PCS');                 // -> qtyNo * qtyInSet
        d.put('acc_section_quantity_no_input', '2');
        d.put('acc_section_quantity_in_one_set_input', '3');
        d.put('acc_section_weight_input', '10');
        d.put('acc_section_rate_input', '100');
        d.put('acc_section_fvf', '50');

        d.put('misc_section_uom_input1', 'Running Meter');     // -> qtyNo only
        d.put('misc_section_quantityNo_input1', '3');
        d.put('misc_section_quantityIOS_input1', '12');
        d.put('misc_section_weight_input1', '5');
        d.put('misc_section_rate_input1', '200');
        d.put('misc_section_fvf', '30');
        d.put('add_misc_fvf', '20');

        // FOR freight via billing address
        d.put('freight_incoterms', 'F.O.R (Freight on Road)');
        d.put('has_transportation_address', false);
        d.put('ba_street', 'Road 1'); d.put('ba_city', 'Patna');
        d.put('ba_state', 'Bihar'); d.put('ba_zip_code', '800001'); d.put('ba_country', 'India');

        d.put('tc_payment_terms_picklist', 'Against LC');
        d.put('tc_no_of_days_interest_free_credit', '30');
        d.put('tc_usance_period', '60');
        d.put('tc_validity_days', '7');
        d.put('Note', 'A note');

        List<Object> lines = new List<Object>{
            line('Crash Tested Details - W-Beam Type (Natrax)', 123, 2025, 0),
            line('Accessory: Bull Nose', 2, 1002, 0),
            line('Misc: test', 3, 2002, 0),
            line('Additional Miscellaneous: extra', 4, 909, 5)
        };
        // give the saved rows real ids so the id != quoteId branch runs
        List<Object> rows = new List<Object>();
        Integer i = 0;
        for (Object o : lines) {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(o));
            m.put('id', 'temp_' + i++);
            m.put('rate', m.get('unitPrice'));
            rows.add(m);
        }
        d.put('_Final_Apex_Lines', lines);
        d.put('_Saved_Table_Rows', rows);
        return d;
    }

    /* ---- F.O.R with shipping address (has_transportation_address true) ---- */
    private static Map<String, Object> shippingForData() {
            Map<String, Object> mainRow = line('Main Product', 1, 500, 0);
            mainRow.put('id', 'row_1');
    
            return new Map<String, Object>{
                '_Saved_Template_Name' => 'Crash Barrier - Department',
                'freight_incoterms' => 'F.O.R (Freight on Road)',
                'has_transportation_address' => true,
                'sa_street' => 'Ship St', 'sa_city' => 'Mithapur',
                'sa_state' => 'Not Found',                 // 'Not Found' skip branch
                'sa_zip_code' => 'null',                    // 'null' skip branch
                'sa_country' => 'India',
                'tc_payment_terms_picklist' => 'Advance',
                'PGR_full_vehicle_freight' => '15',
                '_Saved_Table_Rows' => new List<Object>{ mainRow }
            };
        }

    /* ---- Ex-works freight branch, empty rows ---- */
    private static Map<String, Object> exWorksData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'freight_incoterms' => '',
            'tc_payment_terms_picklist' => 'Advance',
            '_Final_Apex_Lines' => new List<Object>()
        };
    }

    /* ---- Lightweight payment-term variants ---- */
    private static Map<String, Object> paymentData(String term) {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'tc_no_of_days_interest_free_credit' => '10',
            'tc_usance_period' => '20',
            'freight_incoterms' => 'Ex-works'
        };
        if (String.isNotBlank(term)) d.put('tc_payment_terms_picklist', term);
        return d;
    }

    @IsTest
    static void testFullPayload() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Full' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('Test Account', c.accountName, 'Account name should populate');
        Assert.areEqual('Shubhas Khatri', c.contactName, 'Contact name should populate');
        Assert.isTrue(c.totalFreightCharges > 0, 'Numeric freight keys should sum, non-numeric ignored');
        Assert.isFalse(c.lineItems.isEmpty(), 'Line items should be built');
        Assert.isTrue(c.absoluteGrandTotal > 0, 'Grand total should accumulate');
        Assert.isTrue(c.globalTotalCharges > 0, 'Extras sub-total should accumulate');
        
    }

    @IsTest
    static void testShippingAddressFreight() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'ShipAddr' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id));
        Test.stopTest();

        
    }

    @IsTest
    static void testExWorks() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'ExWorks' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id));
        Test.stopTest();

        
    }

    @IsTest
    static void testPaymentVariants() {
        Set<String> names = new Set<String>{
            'OpenCredit', 'BG', 'LC', 'Advance', 'Custom', 'DefaultPay'
        };
        Map<Id, String> byId = new Map<Id, String>();
        for (Quote q : [SELECT Id, Name FROM Quote WHERE Name IN :names]) byId.put(q.Id, q.Name);

        Test.startTest();
        Map<String, String> results = new Map<String, String>();
        for (Id qid : byId.keySet()) {
            CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(qid));
            results.put(byId.get(qid), c.dynamicPaymentTerms);
        }
        Test.stopTest();

        Assert.isTrue(results.get('OpenCredit').contains('Against Open credit'), 'Open credit branch');
        Assert.isTrue(results.get('BG').contains('Against BG'), 'BG branch');
        Assert.isTrue(results.get('LC').contains('Usance'), 'LC branch with usance');
        Assert.areEqual('100% Advance before dispatch', results.get('Advance'), 'Advance branch');
        Assert.areEqual('Some Custom Term', results.get('Custom'), 'Custom term passthrough');
        Assert.areEqual('100% advance along with PI.', results.get('DefaultPay'), 'Blank term -> default');
    }

    @IsTest
    static void testNullAccountAndContact() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'No Acct/Con' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('N/A', c.contactName, 'Null contact -> N/A');
        Assert.areEqual('Account Name Not Found', c.accountName, 'Null account -> default name');
    }

    @IsTest
    static void testBlankJson() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Blank' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id));
        Test.stopTest();

        
    }

    @IsTest
    static void testInvalidJson() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'BadJson' LIMIT 1];

        Test.startTest();
        CrashBarrierQuoteController c = new CrashBarrierQuoteController(stdCtrl(q.Id)); // hits catch
        Test.stopTest();

        Assert.isNotNull(c.quoteRecord, 'Quote header should still load after parse failure');
        Assert.isNotNull(c.dynamicPaymentTerms, 'T&C block should still run after catch');
    }
}