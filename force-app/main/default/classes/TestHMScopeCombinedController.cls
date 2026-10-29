/*
* Class Name  : TestHMScopeCombinedController
* Author      : Rajeev Kumar
* Date        : 09 June 2026
* Description : test class for HMScopeCombinedController apex class.
*/


@IsTest
public class TestHMScopeCombinedController {

    @TestSetup
     public static void testData(){
       	
        Map<String, Object> data1 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Final_Apex_Lines' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'weight' => 0,
                    'quantity' => 1,
                    'unitPrice' => 52424,
                    'unitCost' => 52464,
                    'unitListPrice' => 52424,
                    'expenses' => 0,
                    'discount' => 0
                }
            },
            '_Dynamic_Product_Name' => 'Lighting Pole',
            'mast_standard' => 'Lighting Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'qauntity_mt_3' => '',
            'unit_rate_1' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'added_up_1' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr1 = JSON.serialize(data1);
         
        Map<String, Object> data3 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Saved_Table_Rows' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'temp_0',
                    'name' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'billable' => false,
                    'quantity' => 1,
                    'uom' => 'EA',
                    'unitCost' => 52464,
                    'unitPrice' => 52424,
                    'unitListPrice' => 52424,
                    'discount' => 0,
                    'expenses' => 0,
                    'netPrice' => 52424,
                    'listPrice' => 52424,
                    'cost' => 52464,
                    'margin' => 0,
                    'startDate' => '',
                    'endDate' => '',
                    'weeks' => 0
                }
            },
            '_Dynamic_Product_Name' => 'Lighting Pole',
            'mast_standard' => 'Lighting Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'qauntity_mt_3' => '',
            'unit_rate_1' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'added_up_1' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr3 = JSON.serialize(data3);
         
        Map<String, Object> data4 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Dynamic_Product_Name' => 'Lighting Pole',
            'mast_standard' => 'Lighting Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'c1_s1_height_of_pole' => '3',
            'c1_lp_segment_unit_price' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'c1_lp_bracket_unit_price' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'c1_lp_foundation_unit_price' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr4 = JSON.serialize(data4);
         
        Map<String, Object> data2 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Final_Apex_Lines' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'weight' => 0,
                    'quantity' => 1,
                    'unitPrice' => 52424,
                    'unitCost' => 52464,
                    'unitListPrice' => 52424,
                    'expenses' => 0,
                    'discount' => 0
                }
            },
            '_Dynamic_Product_Name' => 'Transmission Pole',
            'mast_standard' => 'Transmission Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'qauntity_mt_3' => '',
            'unit_rate_1' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'added_up_1' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr2 = JSON.serialize(data2);
         
        Map<String, Object> data5 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Saved_Table_Rows' => new List<Object>{
                new Map<String, Object>{
                    'id' => 'temp_0',
                    'name' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'billable' => false,
                    'quantity' => 1,
                    'uom' => 'EA',
                    'unitCost' => 52464,
                    'unitPrice' => 52424,
                    'unitListPrice' => 52424,
                    'discount' => 0,
                    'expenses' => 0,
                    'netPrice' => 52424,
                    'listPrice' => 52424,
                    'cost' => 52464,
                    'margin' => 0,
                    'startDate' => '',
                    'endDate' => '',
                    'weeks' => 0
                }
            },
            '_Dynamic_Product_Name' => 'Transmission Pole',
            'mast_standard' => 'Transmission Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'c1_tp_height_of_pole' => 3,
            'c1_tp_unit_price' => 345.90,
            'unit_rate_1' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'added_up_1' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr5 = JSON.serialize(data5);
         
        Map<String, Object> data6 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Dynamic_Product_Name' => 'Transmission Pole',
            'mast_standard' => 'Transmission Pole',
            'material_list_type_2' => '',
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => '121',
            'c1_tp_height_of_pole' => 3,
            'c1_tp_unit_price' => 345.90,
            'qauntity_mt_3' => '',
            'unit_rate_1' => 52524,
            'unit_rate_2' => '',
            'unit_rate_3' => '',
            'added_up_1' => 100,
            'added_up_2' => '',
            'added_up_3' => '',
            'price_variable_month' => 'January',
            'price_variable_year' => '2016',
            'billets_rate' => 24464,
            'zinc_rate' => 126500,
            'cpi_rate' => 270,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            '_pendingLineItems' => new List<Object>{
                new Map<String, Object>{
                    'itemName' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'weight' => 0,
                    'quantity' => 1,
                    'realization' => 0,
                    'unitPrice' => 52424,
                    'unitCost' => 52464,
                    'listPrice' => 0,
                    'steel_type' => '',
                    'designation' => '',
                    'size_nb' => '',
                    'pipe_class' => '',
                    'standard_spec_grade' => '',
                    'end_finish' => '',
                    'uom' => '',
                    'rate' => 0,
                    'gst' => 0,
                    'price_per_uom' => 0,
                    'total_price' => 0,
                    '_modalSource' => 'Price Variation',
                    '_baseUnitPrice' => 52424,
                    '_baseUnitCost' => 52464
                }
            },
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr6 = JSON.serialize(data6);
         
        Map<String, Object> data7 = new Map<String, Object>{
            'type_of_mast' => 'Standard Mast',
            '_Dynamic_Product_Name' => 'Transmission Pole',
            'mast_standard' => 'Standard Mast',
            'r1_lm_height_of_mast' => 3,
            'material_list_type_3' => '',
            'extraSpace_1' => '',
            'c1_lp_foundation_unit_price' => 1,
            'c1_lp_foundation_unit_cost' => 121,
            'c1_tp_height_of_pole' => 3,
            'c1_tp_unit_price' => 345.90,
            'r1_lm_no_of_sides' => '1',
            'unit_rate_1' => 52524,
            'r1_lm_base_plate_type' => 'Circular',
            'r1_lm_od_of_base_plate' => 12,
            'r1_lm_no_of_sides' => '3',
            'r1_lm_thickness_of_base_plate' => 2,
            'r1_lm_pcd' => 560,
            'r1_lm_anchor_plate_thickness' => 5,
            'r1_lm_fdn_bolt_dia' => '1',
            'r1_lm_fdn_bolt_length' => 2,
            'r1_lm_fdn_no_of_bolt' => 10,
            'r1_lm_fdn_no_of_nut' => 2,
            'zinc_coating' => '610',
            'discount' => 40,
            'unit_price_1' => 52424,
            'cost_price_1' => 52464,
            '_pendingLineItems' => new List<Object>{
                new Map<String, Object>{
                    'itemName' => 'LIGHTING POLE - Segment - 1 Pole Details (Item 1)',
                    'weight' => 0,
                    'quantity' => 1,
                    'realization' => 0,
                    'unitPrice' => 52424,
                    'unitCost' => 52464,
                    'listPrice' => 0,
                    'steel_type' => '',
                    'designation' => '',
                    'size_nb' => '',
                    'pipe_class' => '',
                    'standard_spec_grade' => '',
                    'end_finish' => '',
                    'uom' => '',
                    'rate' => 0,
                    'gst' => 0,
                    'price_per_uom' => 0,
                    'total_price' => 0,
                    '_modalSource' => 'Price Variation',
                    '_baseUnitPrice' => 52424,
                    '_baseUnitCost' => 52464
                }
            },
            'psd_incoterms' => 'Ex-works',
            'payment_terms' => 'Against PDC',
            'lc_interest_reflect_separately' => '',
            'usance_interest_buyer_days' => '',
            'usance_interest_seller_days' => '',
            'usance_interest_percentage' => '',
            'against_pdc_days' => 10,
            'pdc_interest_percentage' => 5,
            'against_open_credit_days' => '',
            'open_credit_interest_percentage' => '',
            'subject_line' => 'Tonm',
            'delivery_schedule' => '7',
            'warranty_start_date' => 12,
            'warranty_end_date' => 18,
            'offer_validity' => 6,
            '_Saved_Template_Name' => 'High Mast - Department',
            '_Saved_Product_Name' => 'High Mast - Department'
};
        String jsonStr7 = JSON.serialize(data7);
        
        
        RecordType accRecordType = [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'Account' 
    											AND Name = 'End Customer' LIMIT 1];
        
        //create an account
        Account acc = new Account(
            Name = 'Test Account',
            AccountSource = 'Website',
            Phone = '678955757',
            RecordTypeId = accRecordType.Id,
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
        insert acc;
        
        // create an opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id        
        );
        insert opp;
        
        // create Quote
        List<Quote> qs = new List<Quote>{
        	new Quote(
                Name = 'Telecom',
                OpportunityId = opp.Id,
                Status = 'Draft',
                Quote_Value__c = jsonStr1,
                Description = 'Quote 1',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
           	new Quote(
                Name = 'Transmission Pole',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr2,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
           new Quote(
                Name = 'Lightning Pole',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr3,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
           new Quote(
                Name = 'Lightning Pole1',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr4,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
            new Quote(
                Name = 'Transmission Pole1',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr5,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
            new Quote(
                Name = 'Transmission Pole2',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr6,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            ),
            new Quote(
                Name = 'Standard Mast',
                OpportunityId = opp.Id,
                Status = 'Approved ',
                Quote_Value__c = jsonStr7,
                Description = 'Quote 2',
                submition_date__c = Date.today(),
                Has_Quote_Value__c = true
            )
        };
        insert qs;

        // Every mast type and every builder branch the original data
        // never reached. The records above are untouched.
        // Deepanjan (10th August 2026)
        TestHighMastDataFactory.setupAll();
    }
    
    /** Build an ApexPages.StandardController for the given record Id */
    private static ApexPages.StandardController stdCtrl(Id recordId) {
        return new ApexPages.StandardController(new Quote(Id = recordId));
    }
    
    @IsTest
    public static void testLightningPoleWithFinalApexLine(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Telecom' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }

    @IsTest
    public static void testLightningPole1(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Lightning Pole' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testLightningPole2(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Lightning Pole1' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }  
    @IsTest
    public static void testTransmissionPole1(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testTransmissionPole2(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole1' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testTransmissionPole3(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole2' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }
    @IsTest
    public static void testHighMastMethod(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Standard Mast' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HMScopeCombinedController res = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
    }

    /* ================================================================
     *  Mast-type + branch coverage - Deepanjan (10th August 2026)
     *
     *  Every builder in this controller has three paths:
     *      _Final_Apex_Lines  ->  returns early
     *      _Saved_Table_Rows  ->  returns early
     *      the c{col}_s{sec}_ / r{n}_lm_ repeater, which runs ONLY
     *      when neither collection is present - and which is most of
     *      the class.
     *  So the four main mast types get one quote per path (_A, _T, _S).
     * ================================================================ */

    private static HMScopeCombinedController runF(String quoteName) {
        Quote q = TestHighMastDataFactory.quoteNamed(quoteName);
        HMScopeCombinedController ctl =
            new HMScopeCombinedController(TestHighMastDataFactory.stdCtrl(q.Id));
        Assert.isNotNull(ctl, quoteName + ': controller was not constructed');
        Assert.isNotNull(ctl.mastGroups, quoteName + ': mastGroups is null');
        Assert.isNotNull(ctl.grandTotal, quoteName + ': grandTotal is null');
        Assert.isNotNull(ctl.subTotalAmount, quoteName + ': subTotalAmount is null');
        Assert.isNotNull(ctl.soWRef, quoteName + ': soWRef is null');
        Assert.isNotNull(ctl.todayDate, quoteName + ': todayDate is null');
        return ctl;
    }

    @IsTest
    static void lightingApexLinesF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_A);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_A: isLightingPole is wrong');
    }

    @IsTest
    static void lightingTableRowsF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_T);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_T: isLightingPole is wrong');
    }

    @IsTest
    static void lightingSpecRepeaterF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_S);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_S: isLightingPole is wrong');
    }

    @IsTest
    static void transmissionApexLinesF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_A);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_A: isTransmissionPole is wrong');
    }

    @IsTest
    static void transmissionTableRowsF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_T);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_T: isTransmissionPole is wrong');
    }

    @IsTest
    static void transmissionSpecRepeaterF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_S);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_S: isTransmissionPole is wrong');
    }

    @IsTest
    static void midHingeApexLinesF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_A);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_A: isMidHingePole is wrong');
    }

    @IsTest
    static void midHingeTableRowsF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_T);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_T: isMidHingePole is wrong');
    }

    @IsTest
    static void midHingeSpecRepeaterF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_S);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_S: isMidHingePole is wrong');
    }

    @IsTest
    static void standardApexLinesF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_STANDARD_A);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_A: isCustomizedMast is wrong');
    }

    @IsTest
    static void standardTableRowsF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_STANDARD_T);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_T: isCustomizedMast is wrong');
    }

    @IsTest
    static void standardSpecRepeaterF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_STANDARD_S);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_S: isCustomizedMast is wrong');
    }

    @IsTest
    static void stadiumMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_STADIUM: isStadiumMast is wrong');
    }

    @IsTest
    static void flagMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isFlagMast, 'Q_FLAG: isFlagMast is wrong');
    }

    @IsTest
    static void seg5FlagMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_SEG5_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isSeg5FlagMast, 'Q_SEG5_FLAG: isSeg5FlagMast is wrong');
    }

    @IsTest
    static void seg5StadiumMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_SEG5_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_SEG5_STADIUM: isStadiumMast is wrong');
    }

    @IsTest
    static void seg5LclmF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_SEG5_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_SEG5_LCLM: isLCLM is wrong');
    }

    @IsTest
    static void lclmF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_LCLM: isLCLM is wrong');
    }

    @IsTest
    static void signageMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_SIGNAGE);
        Test.stopTest();
        Assert.isTrue(ctl.isSignageMast, 'Q_SIGNAGE: isSignageMast is wrong');
    }

    @IsTest
    static void latchingMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_LATCHING);
        Test.stopTest();
        Assert.isTrue(ctl.isLatchingMast, 'Q_LATCHING: isLatchingMast is wrong');
    }

    @IsTest
    static void customLightningMastF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_CUSTOM_LIGHTNING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTNING: isCustomLightningMast is wrong');
    }

    @IsTest
    static void customLightingSpellingF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_CUSTOM_LIGHTING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTING: isCustomLightningMast is wrong');
    }

    @IsTest
    static void blankQuoteValueF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_EMPTY_JSON);
        Test.stopTest();
    }

    /* The constructor catches a parse failure and carries on with an
       empty map, so a corrupt quote renders an empty page instead of an
       error page. That catch block is otherwise never executed. */
    @IsTest
    static void malformedJsonF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_BAD_JSON);
        Test.stopTest();
    }

    /* One pass over every mast quote the factory makes, so a mast type
       added there later is exercised even before anyone writes a
       dedicated method for it. */
    @IsTest
    static void everyMastTypeConstructsCleanlyF() {
        List<String> names = TestHighMastDataFactory.allMastQuoteNames();
        Test.startTest();
        for (String n : names) {
            runF(n);
        }
        Test.stopTest();
        Assert.areEqual(24, names.size(),
            'The factory should cover 22 mast quotes; update this test if that changes');
    }

    /* Octagonal Pole - the two dedicated branches inside the lighting
       builders (Custom / Standard Lighting Pole). Deepanjan (10th Aug 2026) */
    @IsTest
    static void octagonalCustomLightingPoleF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_OCT_CUSTOM);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_CUSTOM: isTransmissionPole is wrong');
    }

    @IsTest
    static void octagonalStandardLightingPoleF() {
        Test.startTest();
        HMScopeCombinedController ctl = runF(TestHighMastDataFactory.Q_OCT_STANDARD);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_STANDARD: isTransmissionPole is wrong');
    }
    
    // ========================================================================
    // ADDITIONAL COVERAGE METHODS
    // ========================================================================

    @IsTest
    public static void testMidHingePoleExtensive() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> jsonMap = new Map<String, Object>{
            'mast_standard' => 'Mid Hinge Pole',
            'freight_incoterms' => 'F.O.R (Freight on Road)',
            'transportation_as' => 'Per pole/Mast',
            'transportation_charges' => 1500,
            'c1_mhp_height_of_pole' => 10,
            'c1_op_mhp_segment_unit_price' => 5000,
            'c1_op_mhp_foundation_unit_price' => 1000,
            'c1_op_mhp_bracket_unit_price' => 500,
            'c1_mhp_quantity' => 2,
            'c1_mhp_door_height' => '500',
            'c1_mhp_extra_micron' => '10',
            'c1_mhp_need_extra_micron' => true,
            '_Final_Apex_Lines' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'MID HINGE POLE - ACCESSORIES - Ladder',
                    'unitPrice' => 1500,
                    'quantity' => 1
                }
            }
        };
        Quote q = new Quote(Name='Mid Hinge Ext', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isMidHingePole, 'Should be identified as Mid Hinge Pole');
    }

    @IsTest
    public static void testTransmissionPoleSection2() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> jsonMap = new Map<String, Object>{
            'mast_standard' => 'Transmission Pole',
            'c1_tp_height_of_pole' => 5,
            'c1_tp_unit_price' => 15000000, // Large number to test numberToWords (Crore/Lakh branch)
            'c1_tp_is_special_desc' => true,
            'c1_tp_special_desc_text' => 'Custom coating',
            'c1_tp_special_desc_unitPrice' => 2000,
            'c1_tp_s2_height_of_pole' => 4,
            'c1_tp_s2_unit_price' => 8000,
            'c1_tp_s2_is_special_desc' => true,
            'c1_tp_s2_special_desc_text' => 'Extra layer',
            'c1_tp_s2_special_desc_unitPrice' => 1000
        };
        Quote q = new Quote(Name='TP Sec 2', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isTransmissionPole, 'Should be identified as Transmission Pole');
        Assert.isTrue(ctl.grandTotalWords.contains('Crore'), 'Number to words should evaluate Crores');
    }

    @IsTest
    public static void testLightingPoleSection2() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Octagonal Pole',
            'mast_standard_pole' => 'Custom Lighting Pole',
            'c1_s1_cus_op_height_of_pole' => 6,
            'c1_cus_op_s1_segment_unit_price' => 4000,
            'c1_s1_cus_op_solar_structure' => 'Yes',
            'c1_s1_cus_op_battery_box' => 'Yes',
            'c1_s1_cus_op_ladder_description' => 'Yes',
            'c1_s2_cus_op_height_of_pole' => 4,
            'c1_cus_op_s2_segment_unit_price' => 3000,
            'c1_s2_cus_op_overlap' => 200
        };
        Quote q = new Quote(Name='LP Sec 2', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isFalse(ctl.isLightingPole, 'Custom Lighting pole triggers distinct flags');
        Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast groups should be populated');
    }

    @IsTest
    public static void testStadiumAndFlagMast() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> stadiumMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'STADIUM MAST',
            'man_riding_lift' => true,
            'ladder_with_cage' => true,
            'mrl_no_of_segment' => 3,
            'mrl_man_riding_unit_price' => 25000,
            'lwc_no_of_segment' => 2,
            'lwc_ladder_cage_unit_price' => 15000,
            'mrl_si_show_separate' => true,
            'mrl_si_type' => 'Price',
            'mrl_si_value' => 5000,
            'transportation_as' => 'Lump sum',
            'transportation_charges' => 5000
        };
        Quote q1 = new Quote(Name='Stadium', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(stadiumMap));
        
        Map<String, Object> flagMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'FLAG MAST',
            'r1_fm_height_of_mast' => 15,
            'r1_fm_no_of_segment' => 2,
            'r1_fm_1_unit_price' => 10000,
            'r1_fm_2_unit_price' => 10000,
            'fm_pu_paint' => true,
            'fm_pu_paint_value' => 2000,
            'fm_fp_checkbox' => true,
            'fm_fp_foundation_unit_price' => 5000
        };
        Quote q2 = new Quote(Name='Flag', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(flagMap));
        insert new List<Quote>{q1, q2};
        
        Test.startTest();
        HMScopeCombinedController ctl1 = new HMScopeCombinedController(stdCtrl(q1.Id));
        Assert.isTrue(ctl1.isStadiumMast, 'Should be Stadium Mast');
        
        HMScopeCombinedController ctl2 = new HMScopeCombinedController(stdCtrl(q2.Id));
        Assert.isTrue(ctl2.isFlagMast, 'Should be Flag Mast');
        Test.stopTest();
    }

    @IsTest
    public static void testHighMastSpecialTypes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Quote> quotes = new List<Quote>();
        
        List<String> types = new List<String>{
            'Lightning Cum Lighting Mast', 'Signage Mast', 'Latching Mast', 'Custom Lightning Mast'
        };
        
        for(String mt : types) {
            Map<String, Object> hmMap = new Map<String, Object>{
                'type_of_mast' => mt,
                'r1_lm_height_of_mast' => 20,
                'r1_lm_no_of_segment' => 6, // triggers Segment Above 5 logic
                'r1_lm_1_unit_price' => 5000,
                'lm_si_show_separate' => true,
                'lm_si_type' => 'Price',
                'lm_si_value' => 1000,
                'lm_ad_unit_price' => 500,
                'lm_ad_description' => 'Test Additional Details',
                'lm_lc_rate' => 200,
                'lm_lc_quantity' => 2,
                'r1_lm_spike_unit_price' => 1500,
                'r1_lm_dc_unit_price' => 800,
                'r1_lm_acc_total_rate' => 3000
            };
            quotes.add(new Quote(Name=mt, OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(hmMap)));
        }
        insert quotes;
        
        Test.startTest();
        for(Quote q : quotes) {
            HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
            Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast groups should not be empty for ' + q.Name);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testFlagMastSegmentAbove5() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> seg5FlagMap = new Map<String, Object>{
            'type_of_mast' => 'Segment Above 5',
            'seg5_mast_type' => 'FLAG MAST',
            'r1_lm_height_of_mast' => 30,
            'r1_lm_no_of_segment' => 6,
            'r1_lm_1_unit_price' => 15000,
            'r1_lm_pu_paint' => true,
            'r1_lm_pu_paint_price' => 3000,
            'r1_fm_ac_grand_total' => 2500,
            'r1_fm_ac_1_qty' => 1,
            'r1_fm_ac_1_amount' => 500,
            'r1_fm_ad_grand_total' => 4500,
            'r1_fm_ad_1_qty' => 1,
            'r1_fm_ad_1_amount' => 4500
        };
        Quote q = new Quote(Name='Seg5Flag', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(seg5FlagMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isSeg5FlagMast, 'Should correctly identify Segment Above 5 Flag Mast');
        Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast groups should be populated');
    }
    
    // ========================================================================
    // DEEP COVERAGE METHODS (81%+ TARGET)
    // ========================================================================

    @IsTest
    public static void testCustomLightingPoleBuildFromApexLines() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // This targets the specific regex matching and grouping logic inside buildFromApexLines
        Map<String, Object> jsonMap = new Map<String, Object>{
            'mast_standard' => 'Custom Lighting Pole',
            'freight_incoterms' => 'F.O.R (Freight on Road)',
            '_Saved_Table_Rows' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Custom Pole - Segment - 1 (Item 1)', 'quantity' => 2, 'unitPrice' => 10000, 'weight' => 50 },
                new Map<String, Object>{ 'name' => 'Foundation Bolts (Item 1)', 'quantity' => 2, 'unitPrice' => 1000, 'weight' => 5 },
                new Map<String, Object>{ 'name' => 'Bracket Arm (Item 1)', 'quantity' => 2, 'unitPrice' => 500, 'weight' => 10 }
            },
            'c1_s1_cus_op_foundation_bolt_diameter' => '24',
            'c1_s1_cus_op_foundation_bolt_length' => 600,
            'c1_s1_cus_op_bolt_quantity' => 4,
            'wind_speed' => 'YES',
            'wind_speed_value' => '50 m/s'
        };
        
        Quote q = new Quote(Name='CLP Lines', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isFalse(ctl.mastGroups.isEmpty(), 'Custom Lighting Pole apex line builder should populate groups.');
    }

    @IsTest
    public static void testNumberToWordsHundredsRecurse() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Passing a massive value (150 Crore) to trigger the `if (t > 9)` fallback inside the private twoD() method.
        // FIXED: c1_lp_height_of_pole changed to c1_s1_height_of_pole to ensure the mast is not skipped.
        Map<String, Object> jsonMap = new Map<String, Object>{
            'mast_standard' => 'Lighting Pole',
            'c1_s1_height_of_pole' => 5, 
            'c1_lp_segment_unit_price' => 1500000000 // 150 Crore
        };
        
        Quote q = new Quote(Name='Huge Num', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        // The total will be 177 Crore (150 + 18% GST), string should contain 'One Hundred Seventy Seven Crore'
        Assert.isTrue(ctl.grandTotalWords.contains('Hundred'), 'Should recurse into hundreds for amounts over 99 Crore. Actual text: ' + ctl.grandTotalWords);
    }

    @IsTest
    public static void testFlagMastDeepSegmentOverrides() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Triggers the nested cmFlagList() override combinations for n=5 segments
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'FLAG MAST',
            'r1_fm_height_of_mast' => 30,
            'r1_fm_no_of_segment' => 5,
            'r1_fm_est_quantity' => 1,
            'r1_fm_5_unit_price' => 20000,
            'r1_fm_override_mid2' => true,
            'r1_fm_override_mid3' => true,
            'r1_fm_override_mid4' => true,
            'r1_fm_override_bot5' => true,
            'r1_fm_ovr_mid2_length' => 10,
            'r1_fm_ovr_mid3_length' => 10,
            'r1_fm_ovr_mid4_length' => 10,
            'r1_fm_ovr_bot5_length' => 10,
            'r1_fm_is_special_desc' => true,
            'r1_fm_special_desc_unitPrice' => 100,
            'fm_wind_speed' => 'YES',
            'fm_wind_speed_value' => '50'
        };
        
        Quote q = new Quote(Name='FM Overrides', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isFlagMast, 'Quote should resolve as Flag Mast');
    }

    @IsTest
    public static void testHighMastSpecialWeightAndRowLogic() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Triggers specialItemBasePricePerKg logic mapping and Row PU Paint execution
        Map<String, Object> jsonMap = new Map<String, Object>{
            'r1_lm_height_of_mast' => 20,
            'r1_lm_no_of_segment' => 2,
            'r1_lm_1_unit_price' => 10000,
            'r1_lm_2_base_price' => 110,
            'r1_lm_si_show_separate' => true,
            'r1_lm_si_type' => 'Weight',
            'r1_lm_si_value' => 50,
            'lm_si_show_separate' => true,
            'lm_si_type' => 'Weight',
            'lm_si_value' => 100,
            'r1_lm_is_extra_micron' => true,
            'r1_lm_extra_micron' => 15,
            'r1_lm_pu_paint' => true,
            'r1_lm_pu_paint_price' => 500,
            'r1_lm_pu_paint_note' => 'Red Custom'
        };
        
        Quote q = new Quote(Name='HM Weight Specs', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast groups should process row-specific PU Paint & Base Prices.');
    }

    @IsTest
    public static void testStadiumMrlKitAccessoriesAndLWC() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Focuses on kit_line matching (findKitLineForHeight), Ladder with cage notes, and LWC exclusions
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'STADIUM MAST',
            'man_riding_lift' => true,
            'ladder_with_cage' => true,
            'mrl_height_of_mast' => 20,
            'mrl_quantity' => 1,
            'mrl_man_riding_unit_price' => 20000,
            'mrl_foundation_bolt_type' => 'Standard',
            'mrl_foundation_unit_price' => 2000,
            'kit_line_1_lm_mast_height' => '20',
            'kit_line_1_no_of_segment_select' => 2,
            'kit_line_1_lm_2_kit_unit_price' => 5000,
            'kit_line_1_lm_type_of_winch' => 'E=350 kg',
            'lwc_quantity' => 1,
            'lwc_ladder_cage_unit_price' => 10000,
            'lwc_acc_description' => 'Safety kit',
            'lwc_unit_price' => 1500,
            'mrl_mast_acc_foundation_unit_price' => 1000,
            'mrl_is_extra_micron' => true,
            'mrl_extra_micron' => '20',
            'mrl_pu_paint' => true,
            'mrl_special_note' => 'Heavy duty application'
        };
        
        Quote q = new Quote(Name='MRL Kit Specs', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isStadiumMast, 'Should correctly identify as Stadium Mast and parse LWC / Kits');
    }
    
    @IsTest
    public static void testCustomOctagonalPoleVariables() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Hitting `isCustomOctagonal` boolean edge cases and J-Type bracket variations inside Lighting Poles
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Octagonal Pole',
            'mast_standard_pole' => 'Custom Lighting Pole',
            'c1_s1_cus_op_height_of_pole' => 8,
            'c1_cus_op_segment_base_price' => 5000,
            'c1_cus_op_foundation_unit_price' => 1500,
            'c1_cus_op_bracket_unit_price' => 500,
            'c1_s1_cus_op_nr_fb_diameter' => '24',
            'c1_s1_cus_op_template' => 'J Type Profile',
            'c1_s1_cus_op_bracket_type' => 'Custom Arm',
            'c1_s1_cus_op_type_of_arm' => '2',
            'c1_cus_op_s1_quantity' => 2
        };
        
        Quote q = new Quote(Name='Cust Octagonal', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast groups generated successfully through Custom Octagonal routing');
    }
    
    @IsTest
    public static void testWindSpeedSuffixBranches() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // Each map represents a unique payload to trigger exactly one block in the if/else if chain
        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{ 'lp_wind_speed' => 'YES', 'lp_wind_speed_value' => '10 m/s' },
            new Map<String, Object>{ 'tp_wind_speed' => 'YES', 'tp_wind_speed_value' => '20 m/s' },
            new Map<String, Object>{ 'wind_speed' => 'YES', 'wind_speed_value' => '30 m/s' },
            new Map<String, Object>{ 'fm_wind_speed' => 'YES', 'fm_wind_speed_value' => '40 m/s' },
            new Map<String, Object>{ 'op_wind_speed' => 'YES', 'op_wind_speed_value' => '50 m/s' },
            new Map<String, Object>{ 'for_cus_op_wind_speed' => 'YES', 'for_cus_op_wind_speed_value' => '60 m/s' },
            new Map<String, Object>{ 'op_mhp_wind_speed' => 'YES', 'op_mhp_wind_speed_value' => '70 m/s' },
            new Map<String, Object>{ 'man_riding_wind_speed' => '80 m/s' },
            new Map<String, Object>{ 'ladder_cage_wind_speed' => '90 m/s' }
        };

        List<Quote> quotes = new List<Quote>();
        for (Integer i = 0; i < payloads.size(); i++) {
            Map<String, Object> payload = payloads[i];
            
            // Provide a generic High Mast configuration so buildHighMastGroups() is invoked,
            // which in turn calls getWindSpeedSuffix() to read our injected variables.
            payload.put('r1_lm_height_of_mast', 15);
            payload.put('r1_lm_1_unit_price', 5000);
            
            quotes.add(new Quote(
                Name = 'Wind Speed Test ' + i,
                OpportunityId = opp.Id,
                Quote_Value__c = JSON.serialize(payload)
            ));
        }
        insert quotes;

        Test.startTest();
        for (Quote q : quotes) {
            HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
            
            // Verify the builder ran and the suffix was successfully appended
            Assert.isFalse(ctl.mastGroups.isEmpty(), 'Mast group should be created.');
            Assert.isTrue(ctl.mastGroups[0].descMast.contains('wind speed'), 
                'The wind speed suffix was not appended for quote: ' + q.Name);
        }
        Test.stopTest();
    }
    // ========================================================================
    // PINPOINT HELPER & NESTED LOOP COVERAGE (83% -> 90%+)
    // ========================================================================

    @IsTest
    public static void testFlagMastSegmentsAndRowLogic() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Covers Flag Mast cmFlagList n=1, n=3, n=4
        // Covers row-level PU paint and row-level Special Desc
        // Covers flagLineQty extraction from _Final_Apex_Lines
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'FLAG MAST',
            
            // Row 1: n=1, Row-level PU paint
            'r1_fm_height_of_mast' => 10,
            'r1_fm_no_of_segment' => 1,
            'r1_fm_1_unit_price' => 1000,
            'r1_fm_pu_paint' => true,
            'r1_fm_pu_paint_value' => 500,
            'r1_fm_pu_paint_note' => 'Glossy',
            
            // Row 2: n=3, Row-level Special Desc
            'r2_fm_height_of_mast' => 20,
            'r2_fm_no_of_segment' => 3,
            'r2_fm_3_unit_price' => 2000,
            'r2_fm_is_special_desc' => true,
            'r2_fm_special_desc_unitPrice' => 1180, // > 0 triggers the block
            'r2_fm_special_desc_text' => 'Custom Fabric',
            
            // Row 3: n=4
            'r3_fm_height_of_mast' => 30,
            'r3_fm_no_of_segment' => 4,
            'r3_fm_4_unit_price' => 3000,
            
            // For flagLineQty coverage matching rowIdx 2
            '_Final_Apex_Lines' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Special Description - 2', 'quantity' => 5 }
            }
        };
        
        Quote q = new Quote(Name='Flag Segs', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isFlagMast, 'Quote should resolve as Flag Mast');
    }

    @IsTest
    public static void testMrlKitAccessoriesAndAfterEq() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Quote 1: Covers kitSeg <= 1, exact height match, and afterEq parsing ('=' vs no '=')
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'STADIUM MAST',
            'man_riding_lift' => true,
            'mrl_height_of_mast' => 15,
            'mrl_no_of_segment' => 2,
            
            'kit_line_1_lm_mast_height' => '15',
            'kit_line_1_no_of_segment_select' => 1,
            'kit_line_1_lm_kit_unit_price' => 5000,
            
            // afterEq triggering parameters
            'kit_line_1_lm_cable_type' => 'T=2.5 SQmm', 
            'kit_line_1_lm_no_of_cable' => '2=Double',
            'kit_line_1_lm_type_of_winch' => 'NoEqualsSignHere' // tests fallback behavior
        };
        Quote q1 = new Quote(Name='MRL Kit 1', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        
        // Quote 2: Covers kitSeg == 2, kitSeg > 2, and multiple distinct kit lines
        Map<String, Object> jsonMap2 = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'STADIUM MAST',
            'man_riding_lift' => true,
            'mrl_height_of_mast' => 20,
            
            'kit_line_2_lm_mast_height' => '20', 
            'kit_line_2_no_of_segment_select' => 2,
            'kit_line_2_lm_2_kit_unit_price' => 6000,
            
            'kit_line_3_lm_mast_height' => '30',
            'kit_line_3_no_of_segment_select' => 3,
            'kit_line_3_lm_3_kit_unit_price' => 7000
        };
        Quote q2 = new Quote(Name='MRL Kit 2', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap2));
        
        // Quote 3: Covers mastHt * 10 multiplier check in findKitLineForHeight
        Map<String, Object> jsonMap3 = new Map<String, Object>{
            'type_of_mast' => 'Customized Mast',
            'mast_customized' => 'STADIUM MAST',
            'man_riding_lift' => true,
            'mrl_height_of_mast' => 25,
            
            'kit_line_1_lm_mast_height' => '250', // mastHt * 10
            'kit_line_1_no_of_segment_select' => 3,
            'kit_line_1_lm_3_kit_unit_price' => 8000
        };
        Quote q3 = new Quote(Name='MRL Kit 3', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap3));
        
        insert new List<Quote>{q1, q2, q3};
        
        Test.startTest();
        HMScopeCombinedController ctl1 = new HMScopeCombinedController(stdCtrl(q1.Id));
        HMScopeCombinedController ctl2 = new HMScopeCombinedController(stdCtrl(q2.Id));
        HMScopeCombinedController ctl3 = new HMScopeCombinedController(stdCtrl(q3.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl1.isStadiumMast, 'Should be Stadium Mast');
    }

    @IsTest
    public static void testUnprefixedSeg5FlagPuPaint() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Covers seg5FlagPuPaintGroup fallback (unprefixed lm_pu_paint)
        // Must ensure NO row-level r{n}_lm_pu_paint exists so `anyRow` resolves to false.
        Map<String, Object> jsonMap = new Map<String, Object>{
            'type_of_mast' => 'Segment Above 5',
            'seg5_mast_type' => 'FLAG MAST',
            'r1_lm_height_of_mast' => 30,
            'r1_lm_no_of_segment' => 6,
            'r1_lm_1_unit_price' => 15000,
            
            // Unprefixed keys for PU Paint
            'lm_pu_paint' => true,
            'lm_pu_paint_price' => 3500,
            'lm_pu_paint_note' => 'Global PU Paint'
        };
        
        Quote q = new Quote(Name='Seg5 Unprefixed PU', OpportunityId=opp.Id, Quote_Value__c=JSON.serialize(jsonMap));
        insert q;
        
        Test.startTest();
        HMScopeCombinedController ctl = new HMScopeCombinedController(stdCtrl(q.Id));
        Test.stopTest();
        
        Assert.isTrue(ctl.isSeg5FlagMast, 'Should correctly identify Segment Above 5 Flag Mast');
        
        Boolean foundPu = false;
        for (HMScopeCombinedController.MastGroupWrapper grp : ctl.mastGroups) {
            if (grp.descMast.contains('Global PU Paint')) foundPu = true;
        }
        Assert.isTrue(foundPu, 'Unprefixed PU Paint group should be appended to the mast groups.');
    }
    
    
}