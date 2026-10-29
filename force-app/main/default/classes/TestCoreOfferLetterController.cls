/*
* Class Name  : TestCoreOfferLetterController
* Author      : Rajeev Kumar (original, 09 June 2026)
*               Rewritten by Deepanjan (27th July 2026) for the current
*               CoreOfferLetterController: new c{n}_ column format, payment-term
*               interest, loading / F.O.R modes (Per mt & Lump sum, Included &
*               Excluded), special (ss) items, material list + weights at
*               WT_SCALE, Indian digit grouping, dd/MM/yyyy enquiry date,
*               payment_terms_note and the totalNoteSuffix qualifiers.
* Description : Every expected figure below was derived independently first
*               (same rounding rules as the controller) and is asserted
*               exactly - no assert-free smoke tests.
*/
@IsTest
public class TestCoreOfferLetterController {

    // ─────────────────────────────────────────────────────────────────
    // Shared setup: one Account + Opportunity. Each test inserts its own
    // Quote so payloads never leak between tests.
    // ─────────────────────────────────────────────────────────────────
    @TestSetup
    public static void testData() {
        // Record type is org data, not test data: fall back gracefully so the
        // class also runs in orgs without an 'End Customer' account record type.
        List<RecordType> accRts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND Name = 'End Customer'
            LIMIT 1
        ];

        Account acc = new Account(
            Name = 'Test Account',
            AccountSource = 'Website',
            Phone = '678955757',
            BillingStreet = '456 Billing Street',
            BillingCity = 'Patna',
            BillingState = 'Bihar',
            BillingPostalCode = '800001',
            BillingCountry = 'India',
            ShippingStreet = '123 Shipping Street',
            ShippingCity = 'Mithapur',
            ShippingState = 'Bihar',
            ShippingPostalCode = '800001',
            ShippingCountry = 'India'
        );
        if (!accRts.isEmpty()) acc.RecordTypeId = accRts[0].Id;
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;
    }

    /** StandardController for the given record Id */
    private static ApexPages.StandardController stdCtrl(Id recordId) {
        return new ApexPages.StandardController(new Quote(Id = recordId));
    }

    /** Insert a Quote carrying the given payload and return it */
    private static Quote makeQuote(String name, Map<String, Object> data) {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = new Quote(
            Name = name,
            OpportunityId = opp.Id,
            Status = 'Draft',
            Quote_Value__c = JSON.serialize(data),
            Description = name,
            submition_date__c = Date.today(),
            Has_Quote_Value__c = true
        );
        insert q;
        return q;
    }

    /** One subtype row of the widget's c{n}_subtype_qty JSON (wt = per-unit MT) */
    private static Map<String, Object> sub(String s, Integer qty, Decimal wt) {
        return new Map<String, Object>{ 'subtype' => s, 'qty' => qty, 'wt' => wt };
    }

    /** Find a line item by name */
    private static CoreOfferLetterController.LineItemWrapper line(
            CoreOfferLetterController c, String itemName) {
        for (CoreOfferLetterController.LineItemWrapper w : c.lineItems) {
            if (w.itemName == itemName) return w;
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 1 - New c{n}_ format, Against Open Credit (12 days @ 2%),
    // Loading = Per mt (Excluded) 100, F.O.R = Per mt (Excluded) 100.
    // Mirrors the 27-Jul sandbox quote digit for digit.
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testNewFormatOpenCreditPerMtExcluded() {
        Map<String, Object> data = new Map<String, Object>{
            'Price_Basis'  => 'Price Variation',
            'psd_incoterms' => 'F.O.R (Freight on Road)',
            'zinc_coating' => '610',
            'subject_line' => 'test',
            'delivery_schedule' => '12',
            'delivery_schedule_in' => 'Days',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            'your_ref' => 'fddgdfg',
            'enquiry_date' => '2026-07-28',           // WEM save shape
            'payment_terms' => 'Against Open Credit',
            'against_open_credit_days' => 12,
            'open_credit_interest_percentage' => 2,
            'payment_terms_note' => 'extra payment terms',
            'loading_charges' => 'Per mt (Excluded Price)',
            'loading_charges_per_mt' => 100,
            'for_value' => 'Per mt (Excluded Price)',
            'transportation_charges' => 100,
            'number_of_materials' => 2,
            // column 1 - RSJ / BFB MAST, 3 subtypes
            'c1_material_list_type' => 'RSJ / BFB MAST',
            'c1_quantity_pc' => 6,
            'c1_unit_rate' => 75297,
            'c1_cost_price' => 75297,
            'c1_total_weight_mt' => 6.02306,
            'c1_subtype_qty' => JSON.serialize(new List<Object>{
                sub('S-3', 2, 0.849726), sub('S-5', 2, 1.23788), sub('S-7', 2, 0.923926)
            }),
            // column 2 - B-SERIES MAST, 2 subtypes
            'c2_material_list_type' => 'B-SERIES MAST',
            'c2_quantity_pc' => 6,
            'c2_unit_rate' => 75297,
            'c2_cost_price' => 75297,
            'c2_total_weight_mt' => 3.24648,
            'c2_subtype_qty' => JSON.serialize(new List<Object>{
                sub('B-175', 3, 0.42289), sub('B-250', 3, 0.65927)
            })
        };
        Quote q = makeQuote('Core New Format', data);

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        // dd/MM/yyyy conversion of the stored yyyy-MM-dd
        System.assertEquals('28/07/2026', c.enquiryDate, 'enquiry date must print dd/MM/yyyy');
        System.assertEquals('extra payment terms', c.paymentTermsNote);

        // Mode booleans + columns
        System.assertEquals(true, c.isLoadingPerMtExcluded);
        System.assertEquals(true, c.isFreightPerMtExcluded);
        System.assertEquals(true, c.showLoadingColumn);
        System.assertEquals(true, c.showFreightColumn);

        // Interest folded into the rate: 75297 + 75297*12*2/36500 = 75346.51
        CoreOfferLetterController.LineItemWrapper l1 = line(c, 'RSJ / BFB MAST');
        System.assertNotEquals(null, l1);
        System.assertEquals(75346.51, l1.unitPrice, 'Item Rate = cost + open-credit interest');

        // Quantity (MT) column DISPLAYS the rows-sum weight at WT_SCALE (3dp)
        System.assertEquals(6.023, l1.quantityDisplay, 'display = sum of its rounded material-list rows');
        CoreOfferLetterController.LineItemWrapper l2 = line(c, 'B-SERIES MAST');
        System.assertEquals(3.247, l2.quantityDisplay);
        System.assertEquals(9.270, c.totalQuantityDisplay, 'Annexure TOTAL = sum of displayed cells');

        // Material list: 5 rows at 3dp, TOTAL equals the Annexure figure
        System.assertEquals(true, c.showMaterialList);
        System.assertEquals(5, c.materialListRows.size());
        System.assertEquals(1.699, c.materialListRows[0].totalWeightMt);
        System.assertEquals(2.476, c.materialListRows[1].totalWeightMt);
        System.assertEquals(1.848, c.materialListRows[2].totalWeightMt);
        System.assertEquals('9.270', c.materialListTotalWeight);

        
        System.assert(c.grandTotalWords.contains('Rupees'), 'amount-in-words present');

        // totalNoteSuffix: both charges Excluded -> "charged extra at actual"
        System.assert(c.totalNoteSuffix.contains('Loading Charges (charged extra at actual)'),
                      'loading qualifier: ' + c.totalNoteSuffix);
        System.assert(c.totalNoteSuffix.contains('Transportation or Freight Charges (charged extra at actual)'),
                      'freight qualifier: ' + c.totalNoteSuffix);
        System.assert(!c.totalNoteSuffix.contains('included in the quoted unit price'),
                      'no included-qualifier when both modes are Excluded');

        // clause_8 not saved on the quote -> Apex fallback (the "exclusive" text)
        System.assert(c.clause8.toLowerCase().contains('exclusive'),
                      'clause 8 fallback must be the exclusive wording');
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 2 - Old _1/_2/_3 format, Against PDC (10 days @ 5%), no
    // loading / freight selection. Weight display must FALL BACK to the
    // quantity (old format has no per-column weight).
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testOldFormatPdcFallbacks() {
        Map<String, Object> data = new Map<String, Object>{
            'Price_Basis' => 'Price Variation',
            'psd_incoterms' => 'Ex-works',
            'zinc_coating' => '610',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            'enquiry_date' => '28/07/2026',          // already dd/MM -> must pass through
            'payment_terms' => 'Against PDC',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'discount' => 40,
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'material_list_type_1' => 'RSJ / BFB MAST',
            'quantity_mt_1' => 1,                    // (the June test had a 'qauntity' typo)
            'unit_rate_1' => 52524,
            'added_up_1' => 100,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464
        };
        Quote q = makeQuote('Core Old Format', data);

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        // formatDmy pass-through for a non yyyy-MM-dd value
        System.assertEquals('28/07/2026', c.enquiryDate);

        CoreOfferLetterController.LineItemWrapper l1 = line(c, 'RSJ / BFB MAST');
        System.assertNotEquals(null, l1);
        // 52464 + 52464*10*5/36500 = 52535.87 ; GST on it ; no column charges
        System.assertEquals(52535.87, l1.unitPrice);
        System.assertEquals(9456.46,  l1.gstAmount);
        System.assertEquals(61992.33, l1.unitRateInclGST);
        System.assertEquals(61992.33, l1.totalInclGST);
        System.assertEquals('61,992.33', l1.totalInclGSTFmt);
        // No per-column weight in the old format -> display falls back to qty
        System.assertEquals(1, l1.quantity);
        System.assertEquals(1, l1.quantityDisplay);

        // No loading / freight selected
        System.assertEquals(false, c.showLoadingColumn);
        System.assertEquals(false, c.showFreightColumn);
        System.assert(c.totalNoteSuffix.contains('exclusive of any Transportation or Freight Charges'),
                      'unselected freight stays on the exclusive side');

        // No subtype JSON anywhere -> no material list
        System.assertEquals(false, c.showMaterialList);
        System.assertEquals(0, c.materialListRows.size());
        System.assertEquals('0.000', c.materialListTotalWeight);
        System.assertEquals('61,992.33', c.grandTotalIncGSTFmt);
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 3 - Non-interest payment term, special (ss) item, freight
    // Lump sum (EXCLUDED -> own line item) and loading Lump sum
    // (INCLUDED -> boxed value joining the TOTAL).
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testSpecialAndLumpsumModes() {
        Map<String, Object> data = new Map<String, Object>{
            'Price_Basis' => 'Price Variation',
            'psd_incoterms' => 'F.O.R (Freight on Road)',
            'payment_terms' => 'Before Dispatch',    // not interest-bearing
            'number_of_materials' => 1,
            'c1_material_list_type' => 'RSJ / BFB MAST',
            'c1_quantity_pc' => 1,
            'c1_unit_rate' => 1000,
            'c1_cost_price' => 1000,
            'number_of_special_materials' => 1,
            'c1_ss_material_name' => 'Emergency Mast',
            'c1_ss_quantity_pc' => 2,
            'c1_ss_unit_cost' => 118000,
            'c1_ss_unit_price' => 120000,
            'for_value' => 'Lump sum (Excluded Price)',
            'lumpsum_charges' => 5000,
            'loading_charges' => 'Lump sum (Included Price)',
            'loading_charges_lumpsum' => 2000
        };
        Quote q = makeQuote('Core Lumpsum', data);

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        // No interest -> Item Rate equals cost price untouched
        CoreOfferLetterController.LineItemWrapper mat = line(c, 'RSJ / BFB MAST');
        System.assertEquals(1000.00, mat.unitPrice);
        System.assertEquals(1180.00, mat.totalInclGST);

        // Special item keeps its own price and quantity
        CoreOfferLetterController.LineItemWrapper sp = line(c, 'Emergency Mast');
        System.assertNotEquals(null, sp);
        System.assertEquals('special', sp.itemType);
        System.assertEquals(120000.00, sp.unitPrice);
        System.assertEquals(2, sp.quantity);
        System.assertEquals(283200.00, sp.totalInclGST);
        // No weight anywhere on a special line -> display falls back to qty
        System.assertEquals(2, sp.quantityDisplay);

        // Freight Lump sum EXCLUDED -> its own line item with 18% GST
        CoreOfferLetterController.LineItemWrapper fr = line(c, 'Transportation Charges (Lump Sum)');
        System.assertNotEquals(null, fr, 'excluded lump-sum freight must be a line item');
        System.assertEquals('transportation', fr.itemType);
        System.assertEquals(5000.00, fr.unitPrice);
        System.assertEquals(5900.00, fr.totalInclGST);

        // Loading Lump sum INCLUDED -> boxed value, not a line item
        System.assertEquals(null, line(c, 'Loading Charges (Lump Sum)'),
                            'included lump-sum loading must NOT be a line item');
        System.assertEquals(2000.00, c.lumpIncBase);
        System.assertEquals(360.00,  c.lumpIncGst);
        System.assertEquals(2360.00, c.lumpIncTotal);

        // Grand total: 1180 + 283200 + 5900 + 2360
        System.assertEquals(292640.00, c.grandTotalIncGST);
        System.assertEquals('2,92,640.00', c.grandTotalIncGSTFmt);

        // Suffix: freight Excluded, loading Included
        System.assert(c.totalNoteSuffix.contains('Loading Charges (included in the quoted unit price)'),
                      'loading qualifier: ' + c.totalNoteSuffix);
        System.assert(c.totalNoteSuffix.contains('Transportation or Freight Charges (charged extra at actual)'),
                      'freight qualifier: ' + c.totalNoteSuffix);
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 4 - Blank Quote_Value__c: the constructor must survive with
    // empty collections and no exception.
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testBlankQuoteValue() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = new Quote(
            Name = 'Core Blank',
            OpportunityId = opp.Id,
            Status = 'Draft',
            Description = 'no payload',
            submition_date__c = Date.today()
        );
        insert q;

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        System.assertNotEquals(null, c.lineItems);
        System.assertEquals(0, c.lineItems.size());
        System.assertEquals(0, c.grandTotalIncGST);
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 5 - The FOLD block: loading AND freight both Per mt
    // (INCLUDED) fold their per-MT amounts into every non-transportation
    // line's unit price, retotal it, and raise the included-note flags.
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testPerMtIncludedFold() {
        Map<String, Object> data = new Map<String, Object>{
            'Price_Basis' => 'Price Variation',
            'psd_incoterms' => 'F.O.R (Freight on Road)',
            'payment_terms' => 'Before Dispatch',    // no interest: fold maths stays clean
            'number_of_materials' => 1,
            'c1_material_list_type' => 'RSJ / BFB MAST',
            'c1_quantity_pc' => 2,
            'c1_unit_rate' => 1000,
            'c1_cost_price' => 1000,
            'loading_charges' => 'Per mt (Included Price)',
            'loading_charges_per_mt' => 100,
            'for_value' => 'Per mt (Included Price)',
            'transportation_charges' => 120
        };
        Quote q = makeQuote('Core Fold', data);

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        // Both notes on; Included modes never render their own columns
        System.assertEquals(true,  c.loadingIncludedNote);
        System.assertEquals(true,  c.freightIncludedNote);
        System.assertEquals(false, c.showLoadingColumn);
        System.assertEquals(false, c.showFreightColumn);

        // 1000 + (100 + 120) folded = 1220; GST and totals recomputed on it
        CoreOfferLetterController.LineItemWrapper mat = line(c, 'RSJ / BFB MAST');
        System.assertEquals(1220.00, mat.unitPrice,  'per-MT included charges fold into the rate');
        System.assertEquals(219.60,  mat.gstAmount);
        System.assertEquals(1439.60, mat.unitRateInclGST);
        System.assertEquals(2879.20, mat.totalInclGST, 'retotalled at qty 2');
        System.assertEquals(2879.20, c.grandTotalIncGST, 'grand total swapped old for new, not doubled');
        System.assertEquals('2,879.20', c.grandTotalIncGSTFmt);

        // Suffix: both folded -> "included in the quoted unit price"
        System.assert(c.totalNoteSuffix.contains('Loading Charges (included in the quoted unit price)'),
                      c.totalNoteSuffix);
        System.assert(c.totalNoteSuffix.contains('Transportation or Freight Charges (included in the quoted unit price)'),
                      c.totalNoteSuffix);
    }

    // ─────────────────────────────────────────────────────────────────
    // TEST 6 - Loading Lump sum (EXCLUDED -> its own line item), freight
    // Lump sum (INCLUDED -> boxed into TOTAL) and Transit Insurance
    // Charges (own line item with 18% GST).
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    public static void testLoadingLumpsumExcludedAndInsurance() {
        Map<String, Object> data = new Map<String, Object>{
            'Price_Basis' => 'Price Variation',
            'psd_incoterms' => 'F.O.R (Freight on Road)',
            'payment_terms' => 'Before Dispatch',
            'number_of_materials' => 1,
            'c1_material_list_type' => 'RSJ / BFB MAST',
            'c1_quantity_pc' => 1,
            'c1_unit_rate' => 1000,
            'c1_cost_price' => 1000,
            'loading_charges' => 'Lump sum (Excluded Price)',
            'loading_charges_lumpsum' => 2000,
            'for_value' => 'Lump sum (Included Price)',
            'lumpsum_charges' => 5000,
            'transit_insurance_charges' => 1500
        };
        Quote q = makeQuote('Core LS Excl + Insurance', data);

        Test.startTest();
        CoreOfferLetterController c = new CoreOfferLetterController(stdCtrl(q.Id));
        Test.stopTest();

        // Loading Lump sum EXCLUDED -> its own line item with 18% GST
        CoreOfferLetterController.LineItemWrapper lo = line(c, 'Loading Charges (Lump Sum)');
        System.assertNotEquals(null, lo, 'excluded lump-sum loading must be a line item');
        System.assertEquals('transportation', lo.itemType);
        System.assertEquals(2000.00, lo.unitPrice);
        System.assertEquals(2360.00, lo.totalInclGST);

        // Freight Lump sum INCLUDED -> boxed figures joining the TOTAL, no line
        System.assertEquals(null, line(c, 'Transportation Charges (Lump Sum)'),
                            'included lump-sum freight must NOT be a line item');
        System.assertEquals(5000.00, c.freightLumpIncBase);
        System.assertEquals(900.00,  c.freightLumpIncGst);
        System.assertEquals(5900.00, c.freightLumpIncTotal);

        // Transit insurance -> its own line item, GST applied
        CoreOfferLetterController.LineItemWrapper ins = line(c, 'Transit Insurance Charges');
        System.assertNotEquals(null, ins, 'insurance must be a line item when > 0');
        System.assertEquals('transportation', ins.itemType);
        System.assertEquals(1500.00, ins.unitPrice);
        System.assertEquals(270.00,  ins.gstAmount);
        System.assertEquals(1770.00, ins.totalInclGST);

        // Grand: 1180 (material) + 2360 (loading) + 5900 (freight box) + 1770 (insurance)
        System.assertEquals(11210.00, c.grandTotalIncGST);
        System.assertEquals('11,210.00', c.grandTotalIncGSTFmt);

        // Suffix: insurance joins the inclusive list; loading extra, freight in-rate
        System.assert(c.totalNoteSuffix.contains('Loading Charges (charged extra at actual)'), c.totalNoteSuffix);
        System.assert(c.totalNoteSuffix.contains('Transportation or Freight Charges (included in the quoted unit price)'), c.totalNoteSuffix);
        System.assert(c.totalNoteSuffix.contains('Transit Insurance Charges'), c.totalNoteSuffix);
    }
}