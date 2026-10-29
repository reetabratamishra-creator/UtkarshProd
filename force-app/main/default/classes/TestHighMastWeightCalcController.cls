/*
* Class Name  : TestHighMastWeightCalcController
* Author      : Rajeev Kumar
* Date        : 09 June 2026
* Description : test class for HighMastWeightCalcController apex class.
*/


@IsTest
public class TestHighMastWeightCalcController {
	
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
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testLightningPoleWithSavedTableRow(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Lightning Pole' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testLightningPole(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Lightning Pole1' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testTransmissionPoleWithFinalApexLines(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testTransmissionPoleWithSavedTableRow(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole1' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testTransmissionPole(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Transmission Pole2' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
        Test.stopTest();
    }
    
    @IsTest
    public static void testHighMastMethod(){
        Quote q = [SELECT Id, Quote_Value__c, Name FROM Quote WHERE Name = 'Standard Mast' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.debug('Quote value' + q.Quote_Value__c);
        
        Test.startTest();
        HighMastWeightCalcController res = new HighMastWeightCalcController(stdCtrl(q.Id));
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

    private static HighMastWeightCalcController runF(String quoteName) {
        Quote q = TestHighMastDataFactory.quoteNamed(quoteName);
        HighMastWeightCalcController ctl =
            new HighMastWeightCalcController(TestHighMastDataFactory.stdCtrl(q.Id));
        Assert.isNotNull(ctl, quoteName + ': controller was not constructed');
        Assert.isNotNull(ctl.rowDataList, quoteName + ': rowDataList is null');
        Assert.isNotNull(ctl.lpRowList, quoteName + ': lpRowList is null');
        Assert.isNotNull(ctl.tpRowList, quoteName + ': tpRowList is null');
        Assert.isNotNull(ctl.mhpRowList, quoteName + ': mhpRowList is null');
        Assert.isNotNull(ctl.soWRef, quoteName + ': soWRef is null');
        Assert.isNotNull(ctl.todayDate, quoteName + ': todayDate is null');
        return ctl;
    }

    @IsTest
    static void lightingApexLinesF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_A);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_A: isLightingPole is wrong');
    }

    @IsTest
    static void lightingTableRowsF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_T);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_T: isLightingPole is wrong');
    }

    @IsTest
    static void lightingSpecRepeaterF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_LIGHTING_S);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_S: isLightingPole is wrong');
    }

    @IsTest
    static void transmissionApexLinesF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_A);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_A: isTransmissionPole is wrong');
    }

    @IsTest
    static void transmissionTableRowsF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_T);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_T: isTransmissionPole is wrong');
    }

    @IsTest
    static void transmissionSpecRepeaterF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_TRANSMISSION_S);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_S: isTransmissionPole is wrong');
    }

    @IsTest
    static void midHingeApexLinesF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_A);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_A: isMidHingePole is wrong');
    }

    @IsTest
    static void midHingeTableRowsF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_T);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_T: isMidHingePole is wrong');
    }

    @IsTest
    static void midHingeSpecRepeaterF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_MID_HINGE_S);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_S: isMidHingePole is wrong');
    }

    @IsTest
    static void standardApexLinesF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_STANDARD_A);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_A: isCustomizedMast is wrong');
    }

    @IsTest
    static void standardTableRowsF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_STANDARD_T);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_T: isCustomizedMast is wrong');
    }

    @IsTest
    static void standardSpecRepeaterF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_STANDARD_S);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_S: isCustomizedMast is wrong');
    }

    @IsTest
    static void stadiumMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_STADIUM: isStadiumMast is wrong');
    }

    @IsTest
    static void flagMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isFlagMast, 'Q_FLAG: isFlagMast is wrong');
    }

    @IsTest
    static void seg5FlagMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_SEG5_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isSeg5FlagMast, 'Q_SEG5_FLAG: isSeg5FlagMast is wrong');
    }

    @IsTest
    static void seg5StadiumMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_SEG5_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_SEG5_STADIUM: isStadiumMast is wrong');
    }

    @IsTest
    static void seg5LclmF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_SEG5_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_SEG5_LCLM: isLCLM is wrong');
    }

    @IsTest
    static void lclmF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_LCLM: isLCLM is wrong');
    }

    @IsTest
    static void signageMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_SIGNAGE);
        Test.stopTest();
        Assert.isTrue(ctl.isSignageMast, 'Q_SIGNAGE: isSignageMast is wrong');
    }

    @IsTest
    static void latchingMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_LATCHING);
        Test.stopTest();
        Assert.isTrue(ctl.isLatchingMast, 'Q_LATCHING: isLatchingMast is wrong');
    }

    @IsTest
    static void customLightningMastF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_CUSTOM_LIGHTNING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTNING: isCustomLightningMast is wrong');
    }

    @IsTest
    static void customLightingSpellingF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_CUSTOM_LIGHTING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTING: isCustomLightningMast is wrong');
    }

    @IsTest
    static void blankQuoteValueF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_EMPTY_JSON);
        Test.stopTest();
        Assert.isTrue(ctl.rowDataList.isEmpty(), 'A blank Quote_Value__c must produce nothing');
    }

    /* The constructor catches a parse failure and carries on with an
       empty map, so a corrupt quote renders an empty page instead of an
       error page. That catch block is otherwise never executed. */
    @IsTest
    static void malformedJsonF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_BAD_JSON);
        Test.stopTest();
        Assert.isTrue(ctl.rowDataList.isEmpty(), 'Unparseable JSON must produce nothing');
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
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_OCT_CUSTOM);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_CUSTOM: isTransmissionPole is wrong');
    }

    @IsTest
    static void octagonalStandardLightingPoleF() {
        Test.startTest();
        HighMastWeightCalcController ctl = runF(TestHighMastDataFactory.Q_OCT_STANDARD);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_STANDARD: isTransmissionPole is wrong');
    }
}