@isTest
public class QuoteExportControllerForSTP_Test {

    @testSetup
    static void setupTestData() {
        System.debug('>>> LOG-START: Commencing @testSetup Data Initialization');
        
        // 1. Create a mock Account
        Account acc = new Account(Name = 'Utkarsh Customer Account', Phone = '1234567890');
        insert acc;
        System.debug('>>> LOG-DATA: Account successfully inserted with ID: ' + acc.Id);

        // 2. Create a mock Contact (Phone field completely omitted)
        Contact con = new Contact(
            LastName = 'Khatri', 
            FirstName = 'Shubhas', 
            Email = 'test@testemail.com',
            AccountId = acc.Id
        );
        insert con;
        System.debug('>>> LOG-DATA: Contact successfully inserted with ID: ' + con.Id);

        // 3. Create a mock Opportunity linked to the Account
        Opportunity opp = new Opportunity(
            Name = 'Steel Tubular Poles Opportunity', 
            StageName = 'Prospecting', 
            CloseDate = Date.today().addDays(15), 
            AccountId = acc.Id
        );
        insert opp;
        System.debug('>>> LOG-DATA: Opportunity successfully inserted with ID: ' + opp.Id);

        // 4. Generate JSON strings simulating the Quote_Value__c fields
        System.debug('>>> LOG-DATA: Constructing mock JSON payloads for Quote_Value__c');
        String standardPoleJson = createMockJson('Standard Pole');
        String customPoleJson = createMockJson('Customized Pole');

        // 5. Create Quotes to be picked up by the Standard Controller
        List<Quote> quotesToInsert = new List<Quote>();
        
        quotesToInsert.add(new Quote(
            Name = 'Standard Pole Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            ContactId = con.Id,
            Quote_Value__c = standardPoleJson
        ));

        quotesToInsert.add(new Quote(
            Name = 'Custom Pole Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            ContactId = con.Id,
            Quote_Value__c = customPoleJson
        ));

        System.debug('>>> LOG-DATA: Attempting to insert Quote collection records...');
        try {
            insert quotesToInsert;
            System.debug('>>> LOG-DATA: Quotes successfully inserted. Count: ' + quotesToInsert.size());
        } catch (Exception e) {
            System.debug('>>> LOG-ERROR: DML Failure within @testSetup execution block: ' + e.getMessage());
            throw e;
        }
        
        System.debug('>>> LOG-END: Finished @testSetup Data Processing Routine');
    }

    @isTest
    static void testStandardPoleScenario() {
        System.debug('>>> LOG-TEST: Running testStandardPoleScenario');
        
        Quote q = [SELECT Id, Name, Quote_Value__c FROM Quote WHERE Name = 'Standard Pole Test Quote' LIMIT 1];
        System.debug('>>> LOG-TEST: Target Quote ID retrieved: ' + q.Id + ' | Payload Size: ' + (q.Quote_Value__c != null ? q.Quote_Value__c.length() : 0));
        
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(q);
        System.debug('>>> LOG-TEST: StandardController initiated. About to invoke QuoteExportControllerForSTP extension constructor...');
        
        QuoteExportControllerForSTP controller = new QuoteExportControllerForSTP(stdController);
        Test.stopTest();

        System.debug('>>> LOG-ASSERTION: Verifying Standard Controller outputs...');
        System.debug('>>> LOG-RESULT: Table count instantiated: ' + (controller.tables != null ? String.valueOf(controller.tables.size()) : 'NULL'));
        System.debug('>>> LOG-RESULT: Grand Total calculated: ' + controller.totalAmount);

        System.assertNotEquals(null, controller.tables, 'The structured tables collection should be initialized.');
        System.assert(controller.tables.size() > 0, 'Tables should be populated from the JSON data framework.');
        System.assertNotEquals(0.00, controller.totalAmount, 'Grand summary total should be mathematically aggregated.');
    }

    @isTest
    static void testCustomizedPoleScenario() {
        System.debug('>>> LOG-TEST: Running testCustomizedPoleScenario');
        
        Quote q = [SELECT Id, Name, Quote_Value__c FROM Quote WHERE Name = 'Custom Pole Test Quote' LIMIT 1];
        System.debug('>>> LOG-TEST: Target Custom Quote ID retrieved: ' + q.Id);
        
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(q);
        System.debug('>>> LOG-TEST: StandardController initiated. About to invoke QuoteExportControllerForSTP extension constructor...');
        
        QuoteExportControllerForSTP controller = new QuoteExportControllerForSTP(stdController);
        Test.stopTest();

        System.debug('>>> LOG-ASSERTION: Verifying Custom Controller outputs...');
        System.debug('>>> LOG-RESULT: Table count instantiated: ' + (controller.tables != null ? String.valueOf(controller.tables.size()) : 'NULL'));
        System.debug('>>> LOG-RESULT: Grand Total calculated: ' + controller.totalAmount);

        System.assertNotEquals(null, controller.tables, 'The customized tables matrix collection should be initialized.');
        System.assertNotEquals(0.00, controller.totalAmount, 'Grand summary total should cleanly compute custom lines items.');
    }

    @isTest
    static void testExceptionGracefulHandling() {
        System.debug('>>> LOG-TEST: Running testExceptionGracefulHandling');
        
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Standard Pole Test Quote' LIMIT 1];
        // Forcing a structural fault inside JSON layout to test controller's catch statement block 
        q.Quote_Value__c = '{"type_of_pole": "Standard Pole", "tc_payment_terms_pct": "MALFORMED_VALUE_TRIGGERS_EXCEPTION_CATCH"'; 
        update q;
        System.debug('>>> LOG-TEST: Intentionally corrupted Quote payload saved to DB to trigger runtime exception simulation.');

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(q);
        QuoteExportControllerForSTP controller = new QuoteExportControllerForSTP(stdController);
        Test.stopTest();

        System.debug('>>> LOG-ASSERTION: Evaluating safe-state conditions inside controller post-exception catch routine.');
        System.assertNotEquals(null, controller.tables, 'The tables property must still present an empty array list context gracefully.');
    }

    private static String createMockJson(String poleType) {
        Map<String, Object> jsonMap = new Map<String, Object>();
        
        jsonMap.put('type_of_pole', poleType);
        jsonMap.put('tc_payment_terms_pct', '40');
        jsonMap.put('tc_gst', '18% Extra');
        jsonMap.put('tc_validity_days', '30');
        jsonMap.put('tc_payment_terms_picklist', 'Against LC Before Dispatch');
        jsonMap.put('tc_lc_buyer_interest_days', '90');
        jsonMap.put('tc_lc_interest_days', '120');
        jsonMap.put('tc_consignment_start', 10);
        jsonMap.put('tc_consignment_end', 20);

        if (poleType == 'Customized Pole') {
            jsonMap.put('c1_ms_gi', 'MS');
            jsonMap.put('c1_sections', 3);
            jsonMap.put('c1_bot_dia', '220');
            jsonMap.put('c1_bot_thk', '5');
            jsonMap.put('c1_bot_len', '4.5');
            jsonMap.put('c1_mid2_dia', '190');
            jsonMap.put('c1_mid2_thk', '4.5');
            jsonMap.put('c1_mid2_len', '3.5');
            jsonMap.put('c1_top_dia', '160');
            jsonMap.put('c1_top_thk', '4');
            jsonMap.put('c1_top_len', '3.0');
            jsonMap.put('c1_swan', true);
            jsonMap.put('c1_base_length', 11.0);
            jsonMap.put('c1_quantity', 5);
            jsonMap.put('c1_rate', 15000);
            jsonMap.put('c1_pole_total_amount', 75000);
            
            setupComponentFields(jsonMap, 'c1_');
        } else {
            jsonMap.put('ms_gi_1', 'GI');
            jsonMap.put('d1_designation', '410 SP 57');
            jsonMap.put('d1_base_length', 12.0);
            jsonMap.put('d1_quantity', 10);
            jsonMap.put('d1_rate', 22000);
            jsonMap.put('d1_pole_total_amount', 220000);
            
            setupComponentFields(jsonMap, 'd1_');
        }

        return JSON.serialize(jsonMap);
    }

    private static void setupComponentFields(Map<String, Object> jsonMap, String prefix) {
        jsonMap.put(prefix + 'bp_ms_gi', true);
        jsonMap.put(prefix + 'bp_ms_gi_reflect', true);
        jsonMap.put(prefix + 'bp_ms_gi_length', 0.4);
        jsonMap.put(prefix + 'bp_ms_gi_width', 0.4);
        jsonMap.put(prefix + 'bp_ms_gi_thickness', 16);
        jsonMap.put(prefix + 'bp_ms_gi_quantity', 10);
        jsonMap.put(prefix + 'bp_ms_gi_rate', 1200);
        jsonMap.put(prefix + 'bp_ms_total_amount', 12000);

        jsonMap.put(prefix + 'bp_sister_plate', true);
        jsonMap.put(prefix + 'bp_sp_reflect', true);
        jsonMap.put(prefix + 'bp_sp_length', 0.3);
        jsonMap.put(prefix + 'bp_sp_width', 0.1);
        jsonMap.put(prefix + 'bp_sp_thickness', 10);
        jsonMap.put(prefix + 'bp_sp_quantity', 20);
        jsonMap.put(prefix + 'bp_sp_rate', 400);
        jsonMap.put(prefix + 'sp_total_amount', 8000);

        jsonMap.put(prefix + 'bp_cast_iron_is', true);
        jsonMap.put(prefix + 'bp_ci_is_reflect', true);
        jsonMap.put(prefix + 'bp_ci_is_dia', '3');
        jsonMap.put(prefix + 'bp_ci_is_quantity', 10);
        jsonMap.put(prefix + 'bp_ci_is_rate', 650);
        jsonMap.put(prefix + 'cast_iron_total_amount', 6500);

        jsonMap.put(prefix + 'br_ms_gs', 'MS');
        jsonMap.put(prefix + 'br_single_arm', true);
        jsonMap.put(prefix + 'br_length', '1.5');
        jsonMap.put(prefix + 'br_dia', '50');
        jsonMap.put(prefix + 'br_thickness', '3.25');
        jsonMap.put(prefix + 'br_sa_quantity', 10);
        jsonMap.put(prefix + 'br_sa_rate', 1500);
        jsonMap.put(prefix + 'br_sa_total_amount', 15000);

        jsonMap.put(prefix + 'swan_ms_gs', 'GI');
        jsonMap.put(prefix + 'swan_single', true);
        jsonMap.put(prefix + 'swan_s_qty', 10);
        jsonMap.put(prefix + 'swan_s_rate', 1800);
        jsonMap.put(prefix + 'swan_s_sa_total_amount', 18000);

        jsonMap.put(prefix + 'fb_check', true);
        jsonMap.put(prefix + 'fb_length', 600);
        jsonMap.put(prefix + 'fb_dia', '24');
        jsonMap.put(prefix + 'fb_qty', 4);
        jsonMap.put(prefix + 'fb_quantity', 40);
        jsonMap.put(prefix + 'fb_rate', 250);
        jsonMap.put(prefix + 'foundation_total_amount', 10000);

        jsonMap.put(prefix + 'ad_cep_check', true);
        jsonMap.put(prefix + 'ad_cep_length', '0.5');
        jsonMap.put(prefix + 'ad_cep_dia', '50');
        jsonMap.put(prefix + 'ad_cep_thickness', '3');
        jsonMap.put(prefix + 'fb_ad_cep_quantity', 10);
        jsonMap.put(prefix + 'ad_cep_rate', 350);
        jsonMap.put(prefix + 'addi_total_amount', 3500);
    }
}