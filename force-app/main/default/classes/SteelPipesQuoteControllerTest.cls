@isTest
private class SteelPipesQuoteControllerTest {

    // ── Test Data Factory ──────────────────────────────────────────────────

    private static Account makeAccount() {
        Account acc = new Account(
            Name             = 'Test Steel Pipes Account',
            BillingStreet    = '95A Elliot Road',
            BillingCity      = 'Kolkata',
            BillingState     = 'West Bengal',
            BillingPostalCode= '700016',
            Phone            = '9999999999'
        );
        insert acc;
        return acc;
    }

    private static Contact makeContact(Id accountId) {
        Contact con = new Contact(
            FirstName  = 'Test',
            LastName   = 'Contact',
            AccountId  = accountId,
            Phone      = '8888888888',
            Email      = 'test.contact@example.com'
        );
        insert con;
        return con;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name        = 'Test Steel Pipes Opportunity',
            AccountId   = accountId,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    private static Quote makeQuote(Id accountId, Id contactId, Id oppId, String quoteValueJson) {
        Quote q = new Quote(
            Name          = 'Test Steel Pipes Quote',
            ContactId     = contactId,
            OpportunityId = oppId,
            Quote_Value__c = quoteValueJson
        );
        insert q;
        return q;
    }

    private static String minimalJson() {
        return JSON.serialize(new Map<String, Object>{
            'market_type'              => 'Domestic',
            'tc_offer_validity'        => '7 days',
            'tc_delivery_period'       => '4-6 weeks',
            'tc_price_variation'       => 'Yes',
            'tc_payment_terms'         => '30% advance',
            'tc_vehicle_load'          => '+/- 0.5%',
            'tc_qty_tolerance'         => '+/- 5%',
            'tc_tolerance'             => 'As per IS',
            'tc_inspection'            => 'Extra',
            'tc_pre_dispatch_inspection'=> 'At plant',
            'tc_work_address'          => 'Kolkata',
            'tc_gst_tin_number'        => '19AAACX0000X1ZX',
            'freight_steel_pipes'      => 'Included'
        });
    }

    private static String domesticWithLinesJson() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'designation'          => 'Black Steel',
                'standard_spec_grade'  => 'IS 1239',
                'pipe_class'           => 'Medium',
                'shape'                => 'SCH-40',
                'size_nb'              => '50mm',
                'end_finish'           => 'Plain End',
                'quantity'             => 100,
                'rate'                 => 50.0,
                'price_per_uom'        => 48.0,
                'gst'                  => 8.64,
                'quoted_price'         => 48.0,
                'total_price'          => 5664.0,
                'uom'                  => 'METER',
                'reflect_in_offer_doc' => 'Yes'
            },
            new Map<String, Object>{
                'designation'          => 'GI Pipe',
                'standard_spec_grade'  => 'IS 1239',
                'pipe_class'           => 'Heavy',
                'size_nb'              => '25mm',
                'end_finish'           => 'Screwed & Socket',
                'quantity'             => 200,
                'rate'                 => 60.0,
                'price_per_uom'        => 58.0,
                'gst'                  => 10.44,
                'quoted_price'         => 58.0,
                'total_price'          => 13688.0,
                'uom'                  => 'METER',
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        return JSON.serialize(new Map<String, Object>{
            'market_type'             => 'Domestic',
            'tc_offer_validity'       => '7 days',
            'tc_delivery_period'      => '4-6 weeks',
            'tc_price_variation'      => 'Yes',
            'tc_payment_terms'        => '30% advance',
            'tc_vehicle_load'         => '+/- 0.5%',
            'tc_qty_tolerance'        => '+/- 5%',
            'tc_tolerance'            => 'As per IS',
            'tc_inspection'           => 'Extra',
            'tc_pre_dispatch_inspection' => 'At plant',
            'tc_work_address'         => 'Kolkata',
            'tc_gst_tin_number'       => '19AAACX0000X1ZX',
            'freight_steel_pipes'     => 'Included',
            '_Saved_Table_Rows'       => rows
        });
    }

    private static String exportJson() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'designation'          => 'ERW Black Pipe',
                'standard_spec_grade'  => 'ASTM A53',
                'pipe_class'           => 'SCH-40',
                'shape'                => 'SCH-40',
                'size_nb'              => '100mm',
                'mapped_od'            => '114.3',
                'end_finish'           => 'Beveled End',
                'quantity'             => 50,
                'rate'                 => 0.0,
                'total_price'          => 0.0,
                'uom'                  => 'MT',
                'od'                   => 114.3,
                'wall_thickness'       => 6.02,
                'pipe_length'          => 6.0,
                'kg_per_meter'         => 16.07,
                'total_pieces'         => 50,
                'total_meters'         => 300.0,
                'total_weight'         => 4.821,
                'price_input_type'     => 'Per MT',
                'currency_code'        => 'USD',
                'price_fc'             => 800.0,
                'total_fob_fc'         => 3856.8,
                'total_fob_inr'        => 321566.4,
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        return JSON.serialize(new Map<String, Object>{
            'market_type'              => 'Export',
            'tc_offer_validity'        => '15 days',
            'tc_delivery_period'       => '8-10 weeks',
            'tc_price_variation'       => 'Yes',
            'tc_payment_terms'         => 'LC at sight',
            'tc_vehicle_load'          => '+/- 0.5%',
            'tc_qty_tolerance'         => '+/- 5%',
            'tc_tolerance'             => 'As per ASTM',
            'tc_inspection'            => 'Extra',
            'tc_pre_dispatch_inspection'=> 'At plant',
            'tc_work_address'          => 'Kolkata',
            'tc_gst_tin_number'        => '19AAACX0000X1ZX',
            'freight_steel_pipes'      => 'FOB',
            '_Saved_Table_Rows'        => rows
        });
    }

    private static ApexPages.StandardController makeStdCtrl(Id quoteId) {
        return new ApexPages.StandardController(new Quote(Id = quoteId));
    }

    // ── Original & Fixed Tests ───────────────────────────────────────────

    @isTest
    static void testBlankQuoteValue() {
        Account acc  = makeAccount();
        Contact con  = makeContact(acc.Id);
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, con.Id, opp.Id, null);

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(0, ctrl.totalAmount, 'Total should be 0 with no JSON');
        System.assertEquals(0, ctrl.standardLineItems.size(), 'No standard items expected');
        System.assertEquals(false, ctrl.isExport, 'Should not be export');
    }

    @isTest
    static void testMinimalJsonNoRows() {
        Account acc  = makeAccount();
        Contact con  = makeContact(acc.Id);
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, con.Id, opp.Id, minimalJson());

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(0, ctrl.standardLineItems.size(), 'No rows → no standard items');
        System.assertNotEquals(null, ctrl.offerNumber, 'Offer number should be generated');
        System.assert(ctrl.offerNumber.startsWith('UIL/STEEL/'), 'Offer number prefix');
    }

    @isTest
    static void testDomesticStandardLineItems() {
        Account acc  = makeAccount();
        Contact con  = makeContact(acc.Id);
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, con.Id, opp.Id, domesticWithLinesJson());

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(2, ctrl.standardLineItems.size(), 'Should have 2 standard line items');
        System.assert(ctrl.totalAmount > 0, 'Total amount should be positive');
        System.assertEquals(false, ctrl.isExport, 'Domestic quote → not export');

        Map<String, Object> row1 = ctrl.standardLineItems[0];
        String sizeNb = String.valueOf(ctrl.standardLineItems[0].get('size_nb'));
        System.assert(sizeNb.contains('(NB)'), 'IS 1239 size should contain (NB): ' + sizeNb);
    }

    @isTest
    static void testLumpSumFreightFixed() {
        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'         => 'Domestic',
            'tc_offer_validity'   => '7 days',
            'freight_steel_pipes' => 'Freight',
            'for_value'           => 'Lump sum (Excluded Price)',
            'lumpsum_charges'     => 5000,
            '_Saved_Table_Rows'   => new List<Object>()
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.showLumpSumFreight, 'Lump sum freight flag should be true');
        System.assertEquals(5000, ctrl.lumpSumFreightAmount, 'Lump sum amount = 5000');
        System.assertEquals(5000 + (5000 * 0.18), ctrl.standardTotalFinal, 'Standard total = freight + 18% GST');
    }

    @isTest
    static void testPricePerKgFreightFixed() {
        List<Object> configPipes = new List<Object>{
            new Map<String, Object>{ 'name' => 'Pipe 1', 'totalWeight' => '10000.0' }, // 10 MT
            new Map<String, Object>{ 'name' => 'Pipe 2', 'totalWeight' => '5000.0'  }  // 5 MT
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'              => 'Domestic',
            'freight_steel_pipes'      => 'Freight',
            'for_value'                => 'Per mt (Excluded Price)',
            'transportation_charges'   => '2.5',
            '_Final_Apex_Lines'        => configPipes,
            '_Saved_Table_Rows'        => new List<Object>()
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.showPricePerKgFreight, 'Price-per-kg freight flag should be true');
        System.assertEquals(37.5, ctrl.pricePerKgFreightAmount, 'Freight = 15MT × 2.5 = 37.5');
    }

    @isTest
    static void testExportLineItemsFixed() {
        Account acc  = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, exportJson());

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.isExport, 'Export quote flag');
        System.assertEquals('USD', ctrl.exportCurrency, 'Currency = USD');

        Map<String, Object> row = ctrl.standardLineItems[0];
        String sizeNb = String.valueOf(row.get('size_nb'));
        
        System.assertEquals('100', sizeNb, 'Export sizes bypass OD mapping and schedule appending');
        System.assert(Decimal.valueOf(String.valueOf(row.get('total_fob_fc'))) > 0, 'FOB FC on row');
    }

    // ── New Coverage Tests ───────────────────────────────────────────────

    @isTest
    static void testSpecialExpensesHandling() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'name'                 => 'Transit Insurance Extra',
                'rate'                 => 1500.0,
                'reflect_in_offer_doc' => 'Yes'
            },
            new Map<String, Object>{
                'name'                 => 'Lump Sum Charges',
                'expenses'             => 2500.0,
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(2, ctrl.standardLineItems.size(), 'Two items parsed');
        Map<String, Object> insuranceRow = ctrl.standardLineItems[0];
        System.assertEquals('Lump Sum', String.valueOf(insuranceRow.get('uom')), 'UOM forced to Lump Sum');
        System.assertEquals('Transit Insurance', String.valueOf(insuranceRow.get('special_description')), 'Description updated');
        
        Map<String, Object> lumpSumRow = ctrl.standardLineItems[1];
        System.assertEquals('Lump Sum Addition', String.valueOf(lumpSumRow.get('special_description')), 'Lump sum desc updated');
        System.assertEquals(2500.0, Decimal.valueOf(String.valueOf(lumpSumRow.get('unitCost'))), 'Unit cost falls back to expenses');
    }

    @isTest
    static void testDiscountCalculation() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'designation'          => 'Discounted Pipe',
                'quantity'             => 10,
                'rate'                 => 100.0,
                'discount'             => 10.0, // 10% discount
                'gst'                  => 18.0,
                'total_price'          => 900.0,
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        Map<String, Object> row = ctrl.standardLineItems[0];
        System.assertEquals(90.0, Decimal.valueOf(String.valueOf(row.get('pdf_rate'))), '10% discount applied to rate 100');
    }

    @isTest
    static void testCustomThickness() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'standard_spec_grade'  => 'ASTM A53',
                'custom_thickness'     => '5.5',
                'quantity'             => 10,
                'rate'                 => 100.0,
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        Map<String, Object> row = ctrl.standardLineItems[0];
        System.assertEquals('5.5', String.valueOf(row.get('display_class_thickness')), 'Custom thickness mapped correctly for non-IS 1239');
    }

@isTest
    static void testIncludedLumpSumDistribution() {
        List<Object> configPipes = new List<Object>{
            new Map<String, Object>{ 'name' => 'Heavy Pipe', 'totalWeight' => '2000.0' }
        };

        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'name'                 => 'Heavy Pipe',
                'quantity'             => 10,
                'rate'                 => 100.0,
                'price_per_uom'        => 100.0, // Prevents reverse-GST calculation
                'gst'                  => 18.0,
                'totalWeight'          => '2000.0', 
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'              => 'Domestic',
            'for_value'                => 'Lump sum (Included Price)',
            'lumpsum_charges'          => 4000, 
            '_Final_Apex_Lines'        => configPipes,
            '_Saved_Table_Rows'        => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        Map<String, Object> row = ctrl.standardLineItems[0];
        // Base price (100.0) + Distributed Lumpsum (4000 / 2000kg * 200kg per item = 400.0)
        System.assertEquals(400.0, Decimal.valueOf(String.valueOf(row.get('pdf_unit_price'))) - 100.0, 'Included lumpsum distributed into unit price');
    }

    @isTest
    static void testSpecificPipeStandards() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'standard_spec_grade'  => 'IS 4270',
                'size_nb'              => '100mm',
                'reflect_in_offer_doc' => 'Yes'
            },
            new Map<String, Object>{
                'standard_spec_grade'  => 'IS 3589',
                'size_nb'              => '200mm',
                'reflect_in_offer_doc' => 'Yes'
            },
            new Map<String, Object>{
                'standard_spec_grade'  => 'IS 1161',
                'size_nb'              => '150mm',
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals('114.3(OD)', String.valueOf(ctrl.standardLineItems[0].get('size_nb')), 'IS 4270 100mm maps to 114.3 OD');
        System.assertEquals('200(NB)', String.valueOf(ctrl.standardLineItems[1].get('size_nb')), 'IS 3589 appends (NB)');
        System.assertEquals('150(NB)', String.valueOf(ctrl.standardLineItems[2].get('size_nb')), 'IS 1161 appends (NB)');
    }

    @isTest
    static void testCamelCaseFallbacks() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'priceInputType'       => 'Export',
                'currencyCode'         => 'EUR',
                'kgPerMeter'           => 12.5,
                'totalFobFc'           => 1500.0,
                'totalFobInr'          => 120000.0,
                'unitCost'             => 95.0,
                'reflect_in_offer_doc' => 'Yes'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Export',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.isExport, 'Camel case priceInputType recognized');
        System.assertEquals('EUR', ctrl.exportCurrency, 'Camel case currencyCode recognized');
        Map<String, Object> row = ctrl.standardLineItems[0];
        System.assertEquals(12.5, Decimal.valueOf(String.valueOf(row.get('kgPerMeter'))), 'Camel case kgPerMeter recognized');
        System.assertEquals(1500.0, Decimal.valueOf(String.valueOf(row.get('totalFobFc'))), 'Camel case totalFobFc recognized');
        System.assertEquals(95.0, Decimal.valueOf(String.valueOf(row.get('unitCost'))), 'Camel case unitCost recognized');
    }

    @isTest
    static void testQ4FiscalYear() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, minimalJson());
        
        // Mocking a February date (Q4 in India FY). 2023 Feb falls in FY 2022-2023 (22-23).
        Test.setCreatedDate(q.Id, Date.newInstance(2023, 2, 15)); 
        
        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();
        
        System.assert(ctrl.offerNumber.contains('22-23'), 'Fiscal year should be 22-23 for Feb 2023. Actual: ' + ctrl.offerNumber);
    }

    @isTest
    static void testCoreOnlyQuotation() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'special_description'  => 'Supply of Galvanized STAY & REGISTER ARM Small Tube(33.7X28.40mm),As per specification ETI/OHE/11(5/89)& ETI/OHE/13(4/84).',
                'pipe_class'           => 'Core',
                'size_nb'              => 'Small Tube 33.7x28.40',
                'quantity'             => 50,
                'rate'                 => 150.0,
                'unitCost'             => 150.0,
                'uom'                  => 'Meters',
                'quote_scope'          => 'core_only'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            'quote_scope'       => 'core_only',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.isCoreOnly, 'Quote should be identified as Core Only');
        System.assertEquals(false, ctrl.hasStandardPipes, 'Standard pipes should be false for Core Only');
        System.assertEquals(0, ctrl.standardLineItems.size(), 'Standard line items should be cleared for Core Only');
        System.assertEquals(1, ctrl.coreLineItems.size(), 'Core line items should have 1 item');
        System.assertEquals('360 GSM', ctrl.coreLineItems[0].get('zincCoating'), 'Zinc coating should default to 360 GSM');
        System.assertEquals(1.9, ctrl.coreLineItems[0].get('kgPerMeter'), 'Kg per meter should default to 1.9 for small tube');
        System.assertEquals('-', ctrl.coreLineItems[0].get('pipeLengthDisplay'), 'Pipe length display should be - when not set');
        System.assert(ctrl.coreTotalAmount > 0, 'Core total amount should be positive');
        System.assertEquals(ctrl.coreTotalAmount, ctrl.totalAmount, 'Total amount should equal core total amount');
        System.assert(ctrl.coreTotalFinal > 0, 'Core total final should be positive');
        System.assertEquals(ctrl.coreTotalFinal, ctrl.totalFinalAmount, 'Total final amount should equal core total final');
    }

    @isTest
    static void testRegularOnlyQuotation() {
        List<Object> rows = new List<Object>{
            new Map<String, Object>{
                'designation'          => 'MS ERW',
                'standard_spec_grade'  => 'IS 1239',
                'pipe_class'           => 'Heavy',
                'size_nb'              => '25mm',
                'end_finish'           => 'Plain End',
                'quantity'             => 100,
                'rate'                 => 60.0,
                'price_per_uom'        => 58.0,
                'gst'                  => 10.44,
                'quoted_price'         => 58.0,
                'total_price'          => 6844.0,
                'uom'                  => 'Meters',
                'reflect_in_offer_doc' => 'Yes',
                'quote_scope'          => 'regular_only'
            }
        };

        Map<String, Object> jsonMap = new Map<String, Object>{
            'market_type'       => 'Domestic',
            'quote_scope'       => 'regular_only',
            '_Saved_Table_Rows' => rows
        };

        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Quote q = makeQuote(acc.Id, null, opp.Id, JSON.serialize(jsonMap));

        Test.startTest();
        SteelPipesQuoteController ctrl = new SteelPipesQuoteController(makeStdCtrl(q.Id));
        Test.stopTest();

        System.assertEquals(true, ctrl.isRegularOnly, 'Quote should be identified as Regular Only');
        System.assertEquals(true, ctrl.hasStandardPipes, 'Standard pipes should be true for Regular Only');
        System.assertEquals(1, ctrl.standardLineItems.size(), 'Standard line items should have 1 item');
        System.assertEquals(0, ctrl.coreLineItems.size(), 'Core line items should be cleared for Regular Only');
    }
}