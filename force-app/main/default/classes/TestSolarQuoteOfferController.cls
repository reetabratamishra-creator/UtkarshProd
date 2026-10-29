/**
 * TestSolarQuoteOfferController
 * ─────────────────────────────────────────────────────────────────
 * Covers every branch of SolarQuoteOfferController:
 *   - constructor: valid / blank / malformed Quote_Value__c, missing Account,
 *     missing Contact, ensureKey defaults, unit-of-measurement fallback
 *   - micronThickness: Effective_Micron__c, Micron_Thickness__c fallback,
 *     the '-' guard, empty Lines and a missing _configuredSolarStructure
 *   - buildDynamicPaymentTerms: all six branches plus every blank-day default
 *     and the non-numeric advance percentage
 *   - getSolarItems: unit weight above and at zero, quantity zero, null jsonData
 *   - getDynamicSubjectHeader / Body / SupplyOfText: RSJ, H-Beam family,
 *     the default and a null material
 *   - getHasSignature
 *
 * Deepanjan (17th August 2026)
 */
@IsTest
private class TestSolarQuoteOfferController {

    /* ============================ TEST DATA ============================ */

    @TestSetup
    static void makeData() {

        Account acc = new Account(Name = 'Solar Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Roy', FirstName = 'Amit');
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Solar Opp', StageName = 'Nurture',
            CloseDate = Date.today().addDays(30), AccountId = acc.Id
        );
        insert opp;

        // No account on this one, so Quote.Account resolves to null
        Opportunity oppNoAcc = new Opportunity(
            Name = 'Solar Opp No Account', StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert as system oppNoAcc;

        insert as system new List<Quote>{
            newQuote('Full',      opp.Id,      con.Id, JSON.serialize(fullPayload())),
            newQuote('Blank',     opp.Id,      con.Id, ''),
            newQuote('BadJson',   opp.Id,      con.Id, '{ not valid json '),
            newQuote('NoAcctCon', oppNoAcc.Id, null,   JSON.serialize(minimalPayload()))
        };
    }

    private static Quote newQuote(String name, Id oppId, Id conId, String val) {
        return new Quote(Name = name, OpportunityId = oppId, Status = 'Draft',
                         ContactId = conId, Quote_Value__c = val,
                         Has_Quote_Value__c = String.isNotBlank(val));
    }

    private static Quote quoteNamed(String name) {
        return [SELECT Id FROM Quote WHERE Name = :name LIMIT 1];
    }

    private static SolarQuoteOfferController controllerFor(Quote q) {
        return new SolarQuoteOfferController(new ApexPages.StandardController(q));
    }

    /** Builds a controller over a quote whose Quote_Value__c is replaced first. */
    private static SolarQuoteOfferController controllerWith(Map<String, Object> payload) {
        Quote q = quoteNamed('Full');
        q.Quote_Value__c = JSON.serialize(payload);
        update as system q;
        
        return controllerFor(q);
    }

    /* ---------------------------- payloads ---------------------------- */

    private static Map<String, Object> line(String material, Object effMicron, Object micron,
                                            Object unitWeight, Object qty, Object unitPrice) {
        return new Map<String, Object>{
            'Material__c'         => material,
            'Material_Grade__c'   => 'E250',
            'Thickness__c'        => '2.5',
            'Effective_Micron__c' => effMicron,
            'Micron_Thickness__c' => micron,
            'Total_Weight__c'     => '1250.50',
            'Unit_Weight__c'      => unitWeight,
            'Quantity__c'         => qty,
            'Unit_Price__c'       => unitPrice
        };
    }

    private static Map<String, Object> structure(List<Object> lines) {
        return new Map<String, Object>{ 'Lines' => lines };
    }

    private static Map<String, Object> fullPayload() {
        Map<String, Object> p = new Map<String, Object>{
            'unit_of_measurement'         => 'PCS',
            'incoterms'                   => 'FOR Site',
            'tc_offer_validity'           => '15 Days',
            'tc_subject_line'             => 'Solar structure supply',
            'tc_advance_payment'          => '40',
            'tc_warranty_in_months'       => '18',
            'tc_delivery_days'            => '45',
            'tc_payment_terms_picklist'   => 'Against LC Before Dispatch',
            'tc_lc_buyer_interest_days'   => '60',
            'tc_lc_seller_interest_days'  => '90'
        };
        p.put('_configuredSolarStructure', structure(new List<Object>{
            line('MMS RSJ POLE', '90', '70', '25.5', '4', '2500'),
            line('H BEAM PIER',  null, '85', '0',    '0', '1800')
        }));
        return p;
    }

    private static Map<String, Object> minimalPayload() {
        return new Map<String, Object>{ 'tc_payment_terms_picklist' => 'Something Unmapped' };
    }

    /* ======================= CONSTRUCTOR / PARSING ======================= */

    @IsTest
    static void testFullPayload() {
        Test.startTest();
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('Full'));
        Test.stopTest();

        System.assertEquals('Solar Test Account', ctrl.accountName, 'Account name should come from the quote');
        System.assertEquals('Amit Roy', ctrl.contactName, 'Contact name should come from the quote');
        System.assertEquals('PCS', ctrl.unitOfMeasurement, 'unit_of_measurement should be taken as saved');
        System.assertEquals('90', ctrl.micronThickness, 'Effective_Micron__c of the first line wins');
        System.assertEquals('Solar structure supply', ctrl.tcSubjectLine);
        System.assertEquals(40, ctrl.tcAdvancePayment);
        System.assertEquals(18, ctrl.tcWarrantyMonths);
        System.assertEquals('45', ctrl.tcDeliveryDays);

        // ensureKey must NOT overwrite a value that is already present
        System.assertEquals('FOR Site', String.valueOf(ctrl.jsonData.get('incoterms')));
        System.assertEquals('15 Days', String.valueOf(ctrl.jsonData.get('tc_offer_validity')));

        System.assertNotEquals(null, ctrl.validityDateFormatted, 'Validity date must be formatted');
        System.assertEquals(10, ctrl.validityDateFormatted.length(), 'dd.MM.yyyy is 10 characters');
    }

    @IsTest
    static void testBlankQuoteValueUsesDefaults() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('Blank'));

        System.assertEquals('Ex-Works', String.valueOf(ctrl.jsonData.get('incoterms')),
            'ensureKey should supply the Ex-Works default');
        System.assertEquals('7 Days', String.valueOf(ctrl.jsonData.get('tc_offer_validity')),
            'ensureKey should supply the 7 Days default');
        System.assertEquals('Weight', ctrl.unitOfMeasurement,
            'A blank unit of measurement falls back to Weight');
        System.assertEquals('85', ctrl.micronThickness,
            'With no structure the micron stays at the 85 default');
        System.assertEquals('100% advance along with PI.', ctrl.dynamicPaymentTerms);
        System.assertEquals(0, ctrl.getSolarItems().size(), 'No structure means no line items');
    }

    @IsTest
    static void testMalformedJsonIsSwallowed() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('BadJson'));

        System.assertNotEquals(null, ctrl.jsonData, 'A parse failure must still leave an empty map');
        System.assertEquals('Ex-Works', String.valueOf(ctrl.jsonData.get('incoterms')));
        System.assertEquals('Weight', ctrl.unitOfMeasurement);
    }

    @IsTest
    static void testNullAccountAndContact() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('NoAcctCon'));

        System.assertEquals('Account Name Not Found', ctrl.accountName);
        System.assertEquals('N/A', ctrl.contactName);
    }

    @IsTest
    static void testUnitOfMeasurementLiteralNullString() {
        Map<String, Object> p = new Map<String, Object>{ 'unit_of_measurement' => 'null' };
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('Weight', ctrl.unitOfMeasurement,
            'The literal string null must also fall back to Weight');
    }

    /* ============================ MICRON RULES ============================ */

    @IsTest
    static void testMicronFallsBackToMicronThickness() {
        Map<String, Object> p = new Map<String, Object>();
        p.put('_configuredSolarStructure', structure(new List<Object>{
            line('MMS CHANNEL', '', '70', '10', '2', '900')
        }));
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('70', ctrl.micronThickness,
            'A blank Effective_Micron__c falls back to Micron_Thickness__c');
    }

    @IsTest
    static void testMicronDashIsIgnored() {
        Map<String, Object> p = new Map<String, Object>();
        p.put('_configuredSolarStructure', structure(new List<Object>{
            line('MMS CHANNEL', '-', '-', '10', '2', '900')
        }));
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('85', ctrl.micronThickness,
            'A dash is not a micron value, so the 85 default stands');
    }

    @IsTest
    static void testEmptyLinesKeepsDefaultMicron() {
        Map<String, Object> p = new Map<String, Object>();
        p.put('_configuredSolarStructure', structure(new List<Object>()));
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('85', ctrl.micronThickness);
        System.assertEquals(0, ctrl.getSolarItems().size());
    }

    /* ========================== SOLAR LINE ITEMS ========================== */

    @IsTest
    static void testSolarItemArithmetic() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('Full'));
        List<SolarQuoteOfferController.SolarItem> items = ctrl.getSolarItems();

        System.assertEquals(2, items.size(), 'Both lines should come through');

        SolarQuoteOfferController.SolarItem withWeight = items[0];
        System.assertEquals('MMS RSJ POLE', withWeight.material);
        System.assertEquals('E250', withWeight.grade);
        System.assertEquals('2.5', withWeight.thickness);
        System.assertEquals('90', withWeight.micron, 'Effective micron wins when present');
        System.assertEquals(1250.50, withWeight.weight);
        System.assertEquals(4, withWeight.quantity);
        System.assertEquals(2500, withWeight.rate, 'rate is the raw unit price');
        System.assertEquals(2500 / 25.5, withWeight.unitCost,
            'With a unit weight the unit cost is price divided by weight');

        SolarQuoteOfferController.SolarItem noWeight = items[1];
        System.assertEquals('85', noWeight.micron, 'Null effective micron falls back');
        System.assertEquals(1800, noWeight.unitCost,
            'With no unit weight the unit cost is the price itself');
        System.assertEquals(1, noWeight.quantity, 'A zero quantity is forced to 1');
    }

    @IsTest
    static void testNullJsonDataReturnsNoItems() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('Full'));
        ctrl.jsonData = null;

        System.assertEquals(0, ctrl.getSolarItems().size(),
            'A null jsonData must return an empty list rather than throw');
    }

    /* ========================== SUBJECT HELPERS ========================== */

    @IsTest
    static void testSubjectTextForRsj() {
        Map<String, Object> p = new Map<String, Object>();
        p.put('_configuredSolarStructure', structure(new List<Object>{
            line('RSJ POLE 100x50', '90', '90', '12', '3', '1500')
        }));
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('Supply of RSJ POLE', ctrl.getDynamicSubjectHeader());
        System.assertEquals('RSJ Pole', ctrl.getDynamicSubjectBody());
        System.assertEquals('RSJ Pole', ctrl.getDynamicSupplyOfText());
    }

    @IsTest
    static void testSubjectTextForBeamFamily() {
        for (String material : new List<String>{ 'PIER SECTION', 'H BEAM', 'HBM 120', 'WBM 150' }) {
            Map<String, Object> p = new Map<String, Object>();
            p.put('_configuredSolarStructure', structure(new List<Object>{
                line(material, '90', '90', '12', '3', '1500')
            }));
            SolarQuoteOfferController ctrl = controllerWith(p);

            System.assertEquals('of Piers/C sections', ctrl.getDynamicSubjectHeader(), material);
            System.assertEquals('H Beam/Piers/C sections', ctrl.getDynamicSubjectBody(), material);
            System.assertEquals('H Beam/Piers/C Sections', ctrl.getDynamicSupplyOfText(), material);
        }
    }

    @IsTest
    static void testSubjectTextDefaultAndNullMaterial() {
        Map<String, Object> p = new Map<String, Object>();
        p.put('_configuredSolarStructure', structure(new List<Object>{
            line(null, '90', '90', '12', '3', '1500'),
            line('MMS CHANNEL', '90', '90', '12', '3', '1500')
        }));
        SolarQuoteOfferController ctrl = controllerWith(p);

        System.assertEquals('Supply of MMS STRUCTURE', ctrl.getDynamicSubjectHeader(),
            'Nothing recognised means the MMS default');
        System.assertEquals('Solar MMS Structure', ctrl.getDynamicSubjectBody());
        System.assertEquals('Solar MMS Structure', ctrl.getDynamicSupplyOfText());
    }

    /* =========================== PAYMENT TERMS =========================== */

    private static String termsFor(Map<String, Object> extras) {
        Map<String, Object> p = new Map<String, Object>{ 'tc_advance_payment' => '40' };
        p.putAll(extras);
        return controllerWith(p).dynamicPaymentTerms;
    }

    @IsTest
    static void testPaymentTermsLcWithDays() {
        String t = termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist'  => 'Against LC Before Dispatch',
            'tc_lc_buyer_interest_days'  => '60',
            'tc_lc_seller_interest_days' => '90'
        });
        System.assert(t.contains('<b>40%</b> Advance'), 'Advance percentage should be used: ' + t);
        System.assert(t.contains('<b>60%</b>'), 'Balance should be 100 minus advance: ' + t);
        System.assert(t.contains('60 Days'), t);
        System.assert(t.contains('90 Days'), t);
    }

    @IsTest
    static void testPaymentTermsLcWithoutDays() {
        String t = termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against LC Before Dispatch'
        });
        System.assert(t.contains('Buyer\'s scope- 0 Days'), 'Missing buyer days default to 0: ' + t);
        System.assert(t.contains('Seller\'s scope- 0 Days'), 'Missing seller days default to 0: ' + t);
    }

    @IsTest
    static void testPaymentTermsBeforeDispatch() {
        String t = termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Before Dispatch'
        });
        System.assert(t.endsWith('Before Dispatch.'), t);
    }

    @IsTest
    static void testPaymentTermsVfs() {
        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against VFS',
            'tc_vfs_seller_interest'    => '45'
        }).contains('Against VFS for - 45 Days.'));

        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against VFS'
        }).contains('Against VFS for - 0 Days.'), 'Missing VFS days default to 0');
    }

    @IsTest
    static void testPaymentTermsPdc() {
        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against PDC',
            'tc_PDC_interest'           => '30'
        }).contains('Against PDC for - 30 Days.'));

        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against PDC'
        }).endsWith('Against PDC.'), 'With no days it is just Against PDC');
    }

    @IsTest
    static void testPaymentTermsOpenCredit() {
        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against Open Credit',
            'tc_open_credit_days'       => '75'
        }).contains('Against Open Credit 75 Days.'));

        System.assert(termsFor(new Map<String, Object>{
            'tc_payment_terms_picklist' => 'Against Open Credit'
        }).contains('Against Open Credit 0 Days.'), 'Missing open credit days default to 0');
    }

    @IsTest
    static void testPaymentTermsNonNumericAdvanceFallsBackTo30() {
        Map<String, Object> p = new Map<String, Object>{
            'tc_advance_payment'        => 'thirty',
            'tc_payment_terms_picklist' => 'Before Dispatch'
        };
        String t = controllerWith(p).dynamicPaymentTerms;

        System.assert(t.contains('<b>30%</b> Advance'), 'A non numeric advance falls back to 30: ' + t);
        System.assert(t.contains('<b>70%</b>'), 'Balance follows the fallback: ' + t);
    }

    @IsTest
    static void testPaymentTermsUnmappedFallsBackToPi() {
        System.assertEquals('100% advance along with PI.',
            controllerFor(quoteNamed('NoAcctCon')).dynamicPaymentTerms,
            'An unrecognised term type falls back to the PI sentence');
    }

    /* ============================= SIGNATURE ============================= */

    @IsTest
    static void testHasSignature() {
        SolarQuoteOfferController ctrl = controllerFor(quoteNamed('Full'));

        // No Signature_<alias> static resource exists in a test org, so this is false.
        // The point of the call is that the alias lookup and the count query both run.
        System.assertEquals(false, ctrl.getHasSignature(),
            'Without a matching static resource there is no signature');
    }
}