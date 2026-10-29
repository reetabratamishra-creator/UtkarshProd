/*
 * Class Name  : TestQuoteControllerforHDPE
 * Description : Test class for QuoteControllerforHDPE.
 * Author      : Rajeev Kumar, Shivendra Pratap Soni
 * Date        : 08 June 2026
*/
@IsTest
private class TestQuoteControllerforHDPE {

    @TestSetup
    static void makeData() {

        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main St', BillingCity = 'Kolkata',
            BillingState = 'West Bengal', BillingPostalCode = '700001',
            BillingCountry = 'India', Phone = '9589927899'
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Khatri', FirstName = 'Shubhas',
            Phone = '919999999999', Email = 'shubhas@test.com'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp', StageName = 'Nurture',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;

        // Opportunity with NO account -> forces Account-null else branch on its quote
        Opportunity oppNoAcc = new Opportunity(
            Name = 'No Acct Opp', StageName = 'Nurture',
            CloseDate = Date.today().addDays(10)
        );
        insert oppNoAcc;

        List<Quote> qs = new List<Quote>{
            newQuote('IS 4984',       opp.Id,      con.Id, JSON.serialize(is4984Data())),
            newQuote('PLB Duct',      opp.Id,      con.Id, JSON.serialize(plbDuctData())),
            newQuote('Pipe & Duct',   opp.Id,      con.Id, JSON.serialize(pipeAndDuctData())),
            newQuote('No Acct/Con',   oppNoAcc.Id, null,   JSON.serialize(is4984Data())),
            newQuote('Missing JSON',  opp.Id,      con.Id, '')
        };
        insert qs;
    }

    private static Quote newQuote(String name, Id oppId, Id conId, String val) {
        return new Quote(
            Name = name, OpportunityId = oppId, Status = 'Draft',
            ContactId = conId, Quote_Value__c = val, Has_Quote_Value__c = true
        );
    }

    private static ApexPages.StandardController stdCtrl(Id qId) {
        return new ApexPages.StandardController(new Quote(Id = qId));
    }

    /* ---- IS 4984: F.O.R Lump Sum, Km conversion, coil, accessory, Excluded TC ---- */
    private static Map<String, Object> is4984Data() {
        return new Map<String, Object>{
            'Standard' => 'IS 4984',
            'is_pipe_count' => 1,
            'c1_is_Diameter_Size' => '110',
            'c1_is_PE_Grade_select' => 'PE 100',
            'c1_is_Pressure_rating_select' => 'PN 6',
            'c1_is_len_of_coil_pipe' => '8',
            'c1_is_type_of_pipe' => 'coil',
            'c1_is_unit_of_messurment' => 'Km',           // -> MTR conversion
            'c1_is_BOQ_Quantity' => '4',
            'c1_is_FOR_Price' => '226.99',
            'c1_is_GST' => 18,                            // integer -> castToDecimal Integer branch
            'c1_is_Interest_Charges_on_Payment' => '3',
            'is_Type_of_transportation' => 'F.O.R (Freight on Road)',
            'is_Type_of_FOR' => 'Lump Sum',
            'is_LumpSum_Amount' => '5000',
            'tc_destination_location' => 'Mumbai',
            'item_name_input1' => '90 Deg Bend',          // accessories -> "and Fittings"
            'product_category_input1' => 'HDPE Pipe IS 4984',
            'uom_input1' => 'PCS', 'quantity_input1' => '12', 'rate_input1' => '200',
            'acc_Diameter_Size_input1' => '110',
            'tc_test_certificate' => 'Excluded',          // Excluded branch
            'tc_warranty_start' => '18', 'tc_warranty_end' => '24',
            'tc_payment_term' => 'Advance', 'tc_validity' => 'valid till revision'
        };
    }

    /* ---- PLB Duct: 40/33 TEC Spec, Lump Sum, accessory 40/33, Included TC ---- */
    private static Map<String, Object> plbDuctData() {
        return new Map<String, Object>{
            'Standard' => 'PLB Duct',
            'pipe_count' => 2,
            'c1_Diameter_Size' => '40/33 TEC Spec',       // TEC Spec description branch
            'c1_PE_Grade_select' => 'PE 63',
            'c1_Pressure_rating_select' => 'PN 3.2',
            'c1_len_of_coil_pipe' => '9', 'c1_type_of_pipe' => 'coil',
            'c1_unit_of_messurment' => 'mtr', 'c1_BOQ_Quantity' => '800', 'c1_FOR_Price' => '191.84',
            'c1_GST' => 18,
            'c2_Diameter_Size' => '110',                  // normal description branch
            'c2_PE_Grade_select' => 'PE 63', 'c2_Pressure_rating_select' => 'PN 4',
            'c2_len_of_coil_pipe' => '8', 'c2_unit_of_messurment' => 'Km',
            'c2_BOQ_Quantity' => '4', 'c2_FOR_Price' => '278.06',
            'Type_of_transportation' => 'F.O.R (Freight on Road)',
            'Type_of_FOR' => 'Lump Sum', 'LumpSum_Amount' => '3000',
            'tc_destination_location' => 'Delhi',
            'product_category_input1' => 'PLB Duct', 'item_name_input1' => 'Coupler',
            'uom_input1' => 'PCS', 'quantity_input1' => '100', 'rate_input1' => '90',
            'acc_Diameter_Size_input1' => '40/33 TEC Spec', // accessory TEC branch
            'tc_test_certificate' => 'Included',
            'tc_warranty_start' => '10', 'tc_warranty_end' => '14'
        };
    }

    /* ---- Pipe & Duct: Ex-works pipe + F.O.R Lump Sum duct, 40/33 duct, accessory, GST fallback ---- */
    private static Map<String, Object> pipeAndDuctData() {
        return new Map<String, Object>{
            'Standard' => 'Pipe & Duct',
            'p_selected' => true, 'd_selected' => true,
            'c1_p_GST' => 0, 'c1_d_GST' => 18,            // forces blockBGstPercent -> c1_d fallback
            'c1_p_PE_Grade_select' => 'PE 100', 'c1_p_Diameter_Size' => '90',
            'c1_p_Pressure_rating_select' => 'PN 10', 'c1_p_len_of_coil_pipe' => '10',
            'c1_p_type_of_pipe' => 'coil', 'c1_p_unit_of_messurment' => 'Km',
            'c1_p_BOQ_Quantity' => '12', 'c1_p_FOR_Price' => '100',
            'c1_p_Interest_Charges_on_Payment' => '3',    // delayInterest c1_p fallback
            'p_Type_of_transportation' => 'Ex-works', 'p_Type_of_FOR' => '',
            'c1_d_Diameter_Size' => '40/33 TEC Spec',     // duct TEC branch
            'c1_d_len_of_coil_pipe' => '6', 'c1_d_unit_of_messurment' => 'mtr',
            'c1_d_BOQ_Quantity' => '10', 'c1_d_FOR_Price' => '50',
            'd_Type_of_transportation' => 'F.O.R (Freight on Road)',
            'd_Type_of_FOR' => 'Lump Sum', 'd_LumpSum_Amount' => '2000',
            'tc_destination_location' => 'Chennai',
            'product_category_input1' => 'PLB Duct', 'item_name_input1' => 'End Cap',
            'uom_input1' => 'PCS', 'quantity_input1' => '50', 'rate_input1' => '100',
            'acc_Diameter_Size_input1' => '40/33 TEC Spec',
            'tc_test_certificate' => 'Included'
        };
    }

    @IsTest
    static void testIS4984_ForLumpSum() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'IS 4984' LIMIT 1];

        Test.startTest();
        QuoteControllerforHDPE c = new QuoteControllerforHDPE(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('IS 4984', c.standard, 'Standard should parse');
        Assert.isFalse(c.tables.isEmpty(), 'Block A table should be built');
        Assert.areEqual(5000, c.tables[0].transportationCharge, 'IS lump-sum charge should be captured');
        Assert.isTrue(c.totalAmount > 0, 'Total should include sub-total, GST and freight');
        Assert.isTrue(c.is4984TransportText.contains('Delivery included'), 'F.O.R transport text expected');
        Assert.isTrue(c.itemOffered.contains('and Fittings'), 'Accessories should append "and Fittings"');
        Assert.areEqual('Company will not provide the 3rd Party T.C.', c.testCertificate, 'Excluded TC branch');
    }

    @IsTest
    static void testPLBDuct_TecSpecAndLumpSum() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'PLB Duct' LIMIT 1];

        Test.startTest();
        QuoteControllerforHDPE c = new QuoteControllerforHDPE(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('PLB Duct', c.standard, 'Standard should parse');
        Assert.isFalse(c.tables.isEmpty(), 'PLB table should be built');
        Assert.areEqual(3000, c.tables[0].transportationCharge, 'PLB lump-sum charge should be captured');
        Assert.isTrue(c.plbDuctTransportText.contains('Delivery included'), 'F.O.R transport text expected');
        Boolean hasTec = false;
        for (Map<String, Object> li : c.tables[0].lineItems) {
            if (String.valueOf(li.get('description')).contains('TEC Spec')) hasTec = true;
        }
        Assert.isTrue(hasTec, 'A 40/33 TEC Spec line should be present');
    }

    @IsTest
    static void testPipeAndDuct_ExWorksAndLumpSum() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Pipe & Duct' LIMIT 1];

        Test.startTest();
        QuoteControllerforHDPE c = new QuoteControllerforHDPE(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('Pipe & Duct', c.standard, 'Standard should parse');
        Assert.isTrue(c.showPipeTable, 'Pipe table should be shown');
        Assert.isTrue(c.showDuctTable, 'Duct table should be shown');
        Assert.isFalse(c.unifiedRows.isEmpty(), 'Block B rows should be built');
        Assert.areEqual(2000, c.blockBTransportationCharge, 'Duct lump-sum charge should be captured');
        Assert.isTrue(c.blockBFinalAmount > 0, 'Block B final amount should be computed');
        Assert.areEqual('Ex-works', c.pipeDuctPipeTransportText, 'Pipe Ex-works text expected');
        Assert.isTrue(c.pipeDuctDuctTransportText.contains('Delivery included'), 'Duct F.O.R text expected');
        Assert.areEqual(18, c.blockBGstPercent, 'GST should fall back to c1_d_GST');
    }

    @IsTest
    static void testNullAccountAndContact() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'No Acct/Con' LIMIT 1];

        Test.startTest();
        QuoteControllerforHDPE c = new QuoteControllerforHDPE(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual('Test Name Shubhas Khatri', c.contactName, 'Null contact should use default name');
        Assert.areEqual('Test Account Record', c.accountName, 'Null account should use default name');
        Assert.areEqual('Not Available', c.accAdd, 'Empty address parts should yield "Not Available"');
    }

    @IsTest
    static void testMissingJson() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Missing JSON' LIMIT 1];

        Test.startTest();
        QuoteControllerforHDPE c = new QuoteControllerforHDPE(stdCtrl(q.Id));
        Test.stopTest();

        Assert.isNull(c.jsonData, 'Blank Quote_Value should early-return before deserialize');
        Assert.isNotNull(c.quoteRecord, 'Quote header should still be loaded');
    }
}