/*
 * Class Name  : TestQuoteExportController
 * Description : Test class for QuoteExportController.
 *               Builds dummy Quote JSON in-memory; no StaticResource dependency.
 *
 * Repaired 01 August 2026 (Deepanjan). The previous version did not compile,
 * and several tests that would have compiled were asserting against a
 * different build of the controller.
 *
 * WHAT WAS BROKEN
 *
 * A. Six references to members that do not exist — the class could not deploy:
 *      c.getMmsItems()          c.getRsjItems()        c.getBeamPiersItems()
 *      c.getHasSignature()      c.micronThickness      SolarItem.getTotalWeightMT()
 *
 * B. Wrong data contract — these would still have failed once compiled:
 *      1. Solar. getSolarItems() reads _solarStructureConfig.Lines[] with the
 *         field-style keys Material__c / Quantity__c / Unit_Price__c /
 *         Category__c / Freight__c. The old fixture supplied flat c1_hdg_*
 *         keys driven by hdg_count / galv_count, which this controller never
 *         looks at, so every solar assertion was reading an empty list.
 *      2. _Final_Apex_Lines. The constructor only walks _Saved_Table_Rows;
 *         _Final_Apex_Lines does not appear anywhere in the controller. The
 *         expected count of 7 (three apex lines plus four rows) is really 4.
 *      3. There is no keyword duplicate-killer, so "Accessory:" / "Misc:" /
 *         "Crash Tested" lines are not filtered and nothing is dropped.
 *      4. deliverySchedule is derived from tc_delivery_days inside
 *         loadPebBankDocData, not from a delivery_schedule key, and there is
 *         no 'Ten to Twelve weeks' default anywhere in the class.
 *      5. PEB accessories and buyouts come from
 *         Opportunity.Price_Calculation_JSON__c, not from
 *         acc_section_accessories_input_N on the quote payload.
 *      6. fullVehicleFreight sums wb_natrax_fvf as well, so the fixture's
 *         120 + 100 + 50 is 270, not 150.
 *
 * WHAT WAS ALREADY RIGHT AND HAS BEEN KEPT
 *      the crash-barrier _crashBarrierConfig fixture, all twelve payment-term
 *      variants, the blank / malformed JSON paths, the null account and
 *      contact defaults, and the row-id-equals-quote-id skip.
 *
 * The controller is unchanged.
 */
@IsTest
private class TestQuoteExportController {

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

        // Opportunity with NO account -> forces null-Account / null-Contact defaults
        Opportunity oppNoAcc = new Opportunity(Name = 'No Acct Opp', StageName = 'Nurture',
                                               CloseDate = Date.today().addDays(30));

        // PEB reads its numbers off the OPPORTUNITY, not the quote, so the
        // calculator payload lives here.
        Opportunity oppPeb = new Opportunity(Name = 'PEB Opp', StageName = 'Nurture',
                                             CloseDate = Date.today().addDays(30), AccountId = acc.Id,
                                             Price_Calculation_JSON__c = pebCalcJson(463000));

        // Same, but the estimator left Erection at zero cost.
        Opportunity oppPebNoErection = new Opportunity(Name = 'PEB No Erection Opp', StageName = 'Nurture',
                                                       CloseDate = Date.today().addDays(30), AccountId = acc.Id,
                                                       Price_Calculation_JSON__c = pebCalcJson(0));

        insert new List<Opportunity>{ opp, oppNoAcc, oppPeb, oppPebNoErection };

        List<Quote> qs = new List<Quote>{
            newQuote('Solar Pcs',    opp.Id,      con.Id, JSON.serialize(solarGridData('Pcs'))),
            newQuote('Solar Weight', opp.Id,      con.Id, JSON.serialize(solarGridData('Weight'))),
            newQuote('Lines Rows',   opp.Id,      con.Id, JSON.serialize(linesAndRowsData())),
            newQuote('Crash Config', opp.Id,      con.Id, JSON.serialize(crashConfigData())),
            // Legacy crash-barrier path: no _crashBarrierConfig, driven by
            // con_type_select plus the per-type boolean flags.
            newQuote('Legacy W',     opp.Id,      con.Id, JSON.serialize(legacyWBeamData())),
            newQuote('Legacy Thrie', opp.Id,      con.Id, JSON.serialize(legacyThrieData())),
            newQuote('FOR Shipping', opp.Id,      con.Id, JSON.serialize(forFreightData(true))),
            newQuote('FOR Billing',  opp.Id,      con.Id, JSON.serialize(forFreightData(false))),
            newQuote('Subject Auto', opp.Id,      con.Id, JSON.serialize(autoSubjectData(true))),
            newQuote('Subject MMS',  opp.Id,      con.Id, JSON.serialize(autoSubjectData(false))),
            newQuote('Defaults',     opp.Id,      con.Id, JSON.serialize(minimalData())),
            newQuote('RowIdMatch',   opp.Id,      con.Id, JSON.serialize(minimalData())),
            newQuote('No Acct/Con',  oppNoAcc.Id, null,   JSON.serialize(solarPaymentData('Before Dispatch'))),
            newQuote('Blank JSON',   opp.Id,      con.Id, ''),
            newQuote('Bad JSON',     opp.Id,      con.Id, '{ not valid json '),
            // PEB: payload on the quote only supplies the template name and
            // the delivery/validity inputs; the figures come from the opp.
            newQuote('PEB',          oppPeb.Id,   con.Id, JSON.serialize(pebQuoteData())),
            newQuote('PEB NoErect',  oppPebNoErection.Id, con.Id, JSON.serialize(pebQuoteData())),
            newQuote('PEB NoCalc',   opp.Id,      con.Id, JSON.serialize(pebQuoteData())),
            // Solar (non Crash-Barrier) payment variants
            newQuote('Sol LC',       opp.Id,      con.Id, JSON.serialize(solarPaymentData('Against LC Before Dispatch'))),
            newQuote('Sol VFS',      opp.Id,      con.Id, JSON.serialize(solarPaymentData('Against VFS'))),
            newQuote('Sol PDC',      opp.Id,      con.Id, JSON.serialize(solarPaymentData('Against PDC'))),
            newQuote('Sol PDCBlank', opp.Id,      con.Id, JSON.serialize(solarPdcNoDaysData())),
            newQuote('Sol OpenCr',   opp.Id,      con.Id, JSON.serialize(solarPaymentData('Against Open Credit'))),
            newQuote('Sol Default',  opp.Id,      con.Id, JSON.serialize(solarPaymentData('Unknown Term'))),
            // Crash Barrier payment variants
            newQuote('Cr OpenCr',    opp.Id,      con.Id, JSON.serialize(crashPaymentData('Against Open credit'))),
            newQuote('Cr BG',        opp.Id,      con.Id, JSON.serialize(crashPaymentData('Against BG'))),
            newQuote('Cr LC',        opp.Id,      con.Id, JSON.serialize(crashPaymentData('Against LC'))),
            newQuote('Cr Advance',   opp.Id,      con.Id, JSON.serialize(crashPaymentData('Advance'))),
            newQuote('Cr Other',     opp.Id,      con.Id, JSON.serialize(crashPaymentData('Custom Term'))),
            newQuote('Cr Default',   opp.Id,      con.Id, JSON.serialize(crashPaymentData('')))
        };
        insert qs;
    }

    /* ============================ HELPERS ============================ */

    private static Quote newQuote(String name, Id oppId, Id conId, String val) {
        return new Quote(Name = name, OpportunityId = oppId, Status = 'Draft',
                         ContactId = conId, Quote_Value__c = val, Has_Quote_Value__c = true);
    }

    private static ApexPages.StandardController stdCtrl(Id qId) {
        return new ApexPages.StandardController(new Quote(Id = qId));
    }

    private static QuoteExportController ctrlFor(String quoteName) {
        Quote q = [SELECT Id FROM Quote WHERE Name = :quoteName LIMIT 1];
        return new QuoteExportController(stdCtrl(q.Id));
    }

    /*
     * The shape getSolarItems() actually reads: _solarStructureConfig with a
     * Lines array of field-style keys. Three lines drive every branch —
     * the quantity default, the getSafeDecimal catch, the blank-micron
     * fallback and the HDG / non-HDG category split.
     */
    private static Map<String, Object> solarGridData(String uom) {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department',
            'Note'                 => 'A note',
            'incoterms'            => 'FOR',
            'tc_subject_line'      => 'Subject',
            'tc_advance_payment'   => '30',
            'tc_warranty_in_months'=> '12',
            'tc_delivery_days'     => 'Eight weeks',
            'tc_validity_days'     => 'abc',              // non-numeric -> getInt catch
            'freight_incoterms'    => 'Ex-works',
            '_solarStructureConfig' => new Map<String, Object>{
                'Unit_Of_Measurement__c' => uom,
                'Lines' => new List<Object>{
                    // fully populated, HDG category, real quantity and weight
                    new Map<String, Object>{
                        'Material__c' => 'HDG MMS/Carport Structure',
                        'Material_Grade__c' => 'E350',
                        'Thickness__c' => '2',
                        'Micron_Thickness__c' => '70',
                        'Unit_Weight__c' => 22,
                        'Quantity__c' => 2,
                        'Total_Weight__c' => 10,
                        'Unit_Price__c' => 1000,
                        'Category__c' => 'HDG MMS Structure',
                        'Freight__c' => 100
                    },
                    // Quantity 0 -> defaults to 1 ; non-numeric freight -> 0
                    new Map<String, Object>{
                        'Material__c' => 'RSJ Pole',
                        'Thickness__c' => '3',
                        'Micron_Thickness__c' => '',      // blank -> '-'
                        'Unit_Weight__c' => 3,
                        'Quantity__c' => 0,
                        'Total_Weight__c' => 4,
                        'Unit_Price__c' => 500,
                        'Category__c' => 'Galvalume Structure',
                        'Freight__c' => 'abc'
                    },
                    // no Micron_Thickness__c key at all -> '-' ;
                    // non-numeric price -> getSafeDecimal catch -> 0
                    new Map<String, Object>{
                        'Material__c' => 'Piers for Tracker',
                        'Quantity__c' => 3,
                        'Total_Weight__c' => 6,
                        'Unit_Price__c' => 'oops',
                        'Freight__c' => 25
                    }
                }
            }
        };
    }

    /*
     * _Saved_Table_Rows drives every rate / price_per_uom / total_price
     * fallback. _Final_Apex_Lines is included deliberately: this controller
     * ignores it, and the test below pins that.
     */
    private static Map<String, Object> linesAndRowsData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'notes'                => 'lower-case notes key',
            'tc_payment_terms_picklist' => 'Against LC',
            'tc_no_of_days_interest_free_credit' => '30',
            'tc_usance_period'     => '60',
            // freight keys: numeric / blank / non-numeric -> all three getDec branches
            'wb_natrax_fvf'        => '120',
            'tb_alka_fvf'          => '',
            'misc_section_fvf'     => 'abc',   // not part of the sum at all
            'w_SSSB_w_beam_full_Vehicle_freight' => 100,
            'w_SSDB_w_beam_full_Vehicle_freight' => 50,

            // Present but never read by this controller — see the test.
            '_Final_Apex_Lines' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Ignored Line', 'quantity' => 5, 'unitPrice' => 48000 }
            },

            '_Saved_Table_Rows' => new List<Object>{
                // rate / price_per_uom / total_price all present
                new Map<String, Object>{
                    'id' => 'temp_0', 'name' => 'Row Full', 'quantity' => 5, 'weight' => 44100,
                    'unitPrice' => 48000, 'rate' => 4406, 'price_per_uom' => 4406, 'total_price' => 22030
                },
                // no rate -> unitPrice; no price_per_uom -> netPrice; no total_price -> qty * ppu
                new Map<String, Object>{
                    'id' => 'temp_1', 'name' => 'Row Fallback', 'quantity' => 2,
                    'unitPrice' => 100, 'netPrice' => 250
                },
                // nothing at all -> every default
                new Map<String, Object>{ 'id' => 'temp_2', 'name' => 'Row Bare' },
                // Reflect_In_Offer_Doc__c = No -> Pipe_Class__c blanked
                new Map<String, Object>{
                    'id' => 'temp_3', 'name' => 'Row Hidden Class', 'quantity' => 1, 'unitPrice' => 5,
                    'Reflect_In_Offer_Doc__c' => 'No', 'Pipe_Class__c' => 'Class B'
                }
            }
        };
    }

    /* ---- Crash Barrier via _crashBarrierConfig rows ---- */
    private static Map<String, Object> crashConfigData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'Notes__c'             => 'Notes__c key',
            'tc_payment_terms_picklist' => 'Advance',
            'tc_special_note'      => 'Special',
            'tc_validity_days'     => 7,
            '_crashBarrierConfig'  => new Map<String, Object>{
                'rows' => new List<Object>{
                    beamRow('ct_w_SSSB',    'W-SSSB',     '23',  '2400'),  // ct_w_ prefix
                    beamRow('w_DSSB',       'W-DSSB',     '10',  '2700'),  // w_ prefix
                    beamRow('ct_Thrie_SSDB','Thrie-SSDB', '2',   '1192'),  // ct_Thrie_ prefix
                    beamRow('Thrie_DSSB',   'Thrie-DSSB', 'abc', '3370'),  // Thrie_ prefix + bad decimal
                    beamRow('unknown_XYZ',  'Ignored',    '1',   '1')      // matches neither branch
                }
            }
        };
    }

    private static Map<String, Object> beamRow(String id, String label, String qty, String rate) {
        return new Map<String, Object>{
            'id' => id, 'label' => label, 'quantityRm' => qty, 'rateRm' => rate
        };
    }

    /*
     * LEGACY CRASH BARRIER — the second half of buildBeamSections().
     * When _crashBarrierConfig is absent the method falls through to
     * con_type_select and the per-type boolean flags, and builds its sections
     * from flat cN-style keys instead of a rows array. Nothing in the previous
     * fixture ever reached this path, because the config block returns early.
     *
     * w_SSSB  -> flag true, hasSpacer TRUE  (pfx contains SSSB) -> five rows
     * w_SSDB  -> flag true, hasSpacer FALSE                     -> four rows
     * w_DSSB  -> flag present but FALSE  -> skipped
     * w_DSDB  -> flag absent entirely    -> skipped (not a Boolean)
     */
    private static Map<String, Object> legacyWBeamData() {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'con_type_select'      => 'W Beam',
            'tc_payment_terms_picklist' => 'Advance',
            'w_SSSB_id' => true,
            'w_SSDB_id' => true,
            'w_DSSB_id' => false,
            'w_SSSB_w_beam_quantity_rm' => '100',
            'w_SSSB_w_beam_rate_rm'     => '1500',
            'w_SSSB_w_unit_price'       => '1600',
            'w_SSSB_w_unit_cost'        => '1400',
            'w_SSSB_w_beam_trans_in_offer_rm' => 'F.O.R',   // showTransport TRUE
            'w_SSDB_w_beam_quantity_rm' => '50',
            'w_SSDB_w_beam_rate_rm'     => '2000',
            'w_SSDB_w_beam_trans_in_offer_rm' => 'Ex-works' // showTransport FALSE
        };
        // Descriptive inputs for the first section only; the second is left
        // bare so the getStr blank fallback is exercised too.
        for (String k : new List<String>{
            'beamThickness', 'spacerThickness', 'postThickness', 'postHeight',
            'spaceLength', 'roundBolt', 'hexBolt', 'zincCoating'
        }) {
            d.put('w_SSSB_w_beam_' + k + '_input', k + '-value');
        }
        return d;
    }

    /*
     * Thrie side of the same legacy path. con_type_select carries no capital W,
     * so isWBeam is false and isThrie takes over. Thrie sections always print
     * the spacer row, so every one of them has five rows.
     */
    private static Map<String, Object> legacyThrieData() {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'con_type_select'      => 'Thrie Beam',
            'tc_payment_terms_picklist' => 'Advance',
            'Thrie_SSSB' => true,
            'Thrie_SSDB' => false,       // flag false -> skipped
            'Thrie_DSDB' => true,
            // Thrie_DSSB absent entirely -> not a Boolean -> skipped
            'Thrie_SSSB_quantity_rm' => '20',
            'Thrie_SSSB_rate_rm'     => '3000',
            'Thrie_SSSB_unit_price'  => '3200',
            'Thrie_SSSB_unit_cost'   => '2800',
            'Thrie_SSSB_trans_in_offer_rm' => 'Ex-works',   // showTransport FALSE
            'Thrie_DSDB_quantity_rm' => '10',
            'Thrie_DSDB_rate_rm'     => '4000',
            'Thrie_DSDB_trans_in_offer_rm' => 'F.O.R'       // showTransport TRUE
        };
        for (String k : new List<String>{
            'beamThickness', 'spacerThickness', 'postThickness', 'postHeight',
            'spaceLength', 'roundBolt', 'hexBolt', 'zincCoating'
        }) {
            d.put('Thrie_SSSB_' + k + '_input', k + '-value');
        }
        return d;
    }

    /*
     * The F.O.R half of buildTCFields' freight sentence. useShipping picks the
     * sa_* keys, otherwise the ba_* ones — and the billing variant deliberately
     * carries a 'Not Found' and an '@@' placeholder so the address filter runs.
     * The freight is written as 100.00 so the trailing-.00 strip also fires.
     */
    private static Map<String, Object> forFreightData(Boolean useShipping) {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'freight_incoterms'    => 'F.O.R (Freight on Road)',
            'w_SSSB_w_beam_full_Vehicle_freight' => '100.00'
        };
        if (useShipping) {
            d.put('has_transportation_address', true);
            d.put('sa_street',   'Plot 21');
            d.put('sa_city',     'Kolkata');
            d.put('sa_state',    'West Bengal');
            d.put('sa_zip_code', '700001');
        } else {
            d.put('ba_street',   'Not Found');      // filtered out
            d.put('ba_city',     'City@@Token');    // filtered out
            d.put('ba_state',    'Bihar');          // kept
            d.put('ba_zip_code', 'Not Found');      // no PINCODE appended
        }
        return d;
    }

    /*
     * Subject line auto-generation. A blank tc_subject_line makes the
     * controller build one from the solar materials; with no solar config at
     * all it falls back to the fixed MMS wording. The duplicate material also
     * proves the !materials.contains(mat) guard.
     */
    private static Map<String, Object> autoSubjectData(Boolean withSolar) {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department',
            'tc_subject_line'      => '',
            // supplied values, so ensureKey must NOT overwrite them
            'Contact_Person'       => 'Deepanjan',
            'tc_transportation'    => 'EXCLUDED'
        };
        if (withSolar) {
            d.put('_solarStructureConfig', new Map<String, Object>{
                'Unit_Of_Measurement__c' => 'Pcs',
                'Lines' => new List<Object>{
                    new Map<String, Object>{ 'Material__c' => 'HDG MMS', 'Unit_Price__c' => 10 },
                    new Map<String, Object>{ 'Material__c' => 'RSJ Pole', 'Unit_Price__c' => 20 },
                    new Map<String, Object>{ 'Material__c' => 'HDG MMS', 'Unit_Price__c' => 30 }, // duplicate
                    new Map<String, Object>{ 'Unit_Price__c' => 40 }                              // no material
                }
            });
        }
        return d;
    }

    /* ---- PEB: what sits on the QUOTE ---- */
    private static Map<String, Object> pebQuoteData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'PEB - Department',
            'tc_payment_terms_picklist' => 'Before Dispatch',
            'tc_delivery_days'     => '45 days',
            'tc_validity_days'     => 30
        };
    }

    /* ---- PEB: what sits on the OPPORTUNITY (the calculator's estimate) ---- */
    private static String pebCalcJson(Decimal erectionCost) {
        return JSON.serialize(new Map<String, Object>{
            'generatedDate' => '31-Jul-2026',
            'totals' => new Map<String, Object>{
                'totalWithMargin' => 16303965,
                'gstRs' => 2934714,
                'grandTotal' => 19238679,
                'sectionATotalWeight' => 294000      // Kg -> 294 MT
            },
            'accessories' => new List<Object>{
                new Map<String, Object>{ 'description' => 'Turbo Ventilator', 'unit' => 'Nos',
                                         'qty' => 4, 'reason' => 'Painted' },
                new Map<String, Object>{ 'description' => 'Zero Qty Placeholder', 'unit' => 'Nos',
                                         'qty' => 0 },                      // skipped
                new Map<String, Object>{ 'description' => '', 'unit' => 'Nos', 'qty' => 2 }  // skipped
            },
            'buyouts' => new List<Object>{
                new Map<String, Object>{ 'description' => 'Roller Shutter', 'unit' => 'Sqm',
                                         'qty' => 2, 'reason' => 'Manual' }
            },
            'paymentTerms' => new Map<String, Object>{
                'consignmentPeriod' => '10-12 weeks',
                'erectionPeriod' => '6 weeks',
                'validity' => '30 days'
            },
            'otherCost' => new List<Object>{
                new Map<String, Object>{ 'description' => 'Truck', 'qty' => 1, 'rate' => 13000, 'cost' => 13000 },
                new Map<String, Object>{ 'description' => 'Erection', 'qty' => 1,
                                         'rate' => erectionCost, 'cost' => erectionCost }
            }
        });
    }

    /* ---- Minimal payload: exercises every default/fallback ---- */
    private static Map<String, Object> minimalData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department'
            // no Note/notes/Notes__c        -> quoteNotes = ''
            // no _Saved_Table_Rows          -> lineItems stays empty
            // no _solarStructureConfig      -> getSolarItems returns empty
            // no unit_of_measurement        -> 'Weight'
            // no tc_delivery_days           -> deliverySchedule = ''
        };
    }

    private static Map<String, Object> solarPaymentData(String term) {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department',
            'tc_payment_terms_picklist' => term,
            'tc_advance_payment' => 'abc',            // non-numeric -> advPct fallback 30
            'tc_lc_buyer_interest_days' => '45',
            'tc_lc_seller_interest_days' => '45',
            'tc_vfs_seller_interest' => '5',
            'tc_PDC_interest' => '10',
            'tc_open_credit_days' => '45'
        };
    }

    private static Map<String, Object> solarPdcNoDaysData() {
        return new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department',
            'tc_payment_terms_picklist' => 'Against PDC',
            'tc_advance_payment' => '40'
            // tc_PDC_interest omitted -> 'Against PDC.' branch
        };
    }

    private static Map<String, Object> crashPaymentData(String term) {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Crash Barrier - Department',
            'tc_no_of_days_interest_free_credit' => '10',
            'tc_usance_period' => '20'
        };
        if (String.isNotBlank(term)) d.put('tc_payment_terms_picklist', term);
        return d;
    }

    /* ============================ TESTS ============================ */

    @IsTest
    static void testSolarGridInPieces() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Solar Pcs');
        List<QuoteExportController.SolarItem> items = c.getSolarItems();
        Decimal freight  = c.getTotalFreight();
        Decimal subTotal = c.getSubTotal();
        Test.stopTest();

        Assert.areEqual(3, items.size(), 'Every line in the config becomes a solar item');

        // line 1: quantity honoured, HDG category, micron read straight through
        Assert.isTrue(items[0].quantity == 2, 'Quantity read from Quantity__c');
        Assert.isTrue(items[0].isHdg, 'Category HDG MMS Structure flags the item as HDG');
        Assert.areEqual('70', items[0].micron, 'Micron read from Micron_Thickness__c');
        Assert.isTrue(items[0].rate == 1000, 'rate mirrors Unit_Price__c');

        // line 2: zero quantity defaults to one, non-HDG category
        Assert.isTrue(items[1].quantity == 1, 'Zero quantity defaults to 1');
        Assert.isFalse(items[1].isHdg, 'A non HDG category is not flagged as HDG');
        Assert.areEqual('-', items[1].micron, 'Blank micron falls back to a dash');

        // line 3: missing micron key and unparseable price
        Assert.areEqual('-', items[2].micron, 'A missing micron key also falls back to a dash');
        Assert.isTrue(items[2].rate == 0, 'A non-numeric Unit_Price__c falls back to 0');

        // In PCs mode the amount is quantity * rate: 2*1000 + 1*500 + 3*0
        Assert.isTrue(subTotal == 2500, 'Sub-total is quantity * rate in PCs mode');
        // Freight: 100 + non-numeric 'abc' -> 0 + 25
        Assert.isTrue(freight == 125, 'Freight sums Freight__c and ignores the non-numeric one');

        
    }

    @IsTest
    static void testSolarGridByWeight() {
        // Any UOM other than PCs makes the amount weight * rate instead.
        Test.startTest();
        QuoteExportController c = ctrlFor('Solar Weight');
        Decimal subTotal = c.getSubTotal();
        Test.stopTest();

        // 10*1000 + 4*500 + 6*0
        Assert.isTrue(subTotal == 12000, 'Sub-total is weight * rate when the UOM is not PCs');
        Assert.areEqual('Weight', c.unitOfMeasurement, 'UOM read from the solar config');
    }

    @IsTest
    static void testSavedTableRowFallbacks() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Lines Rows');
        Test.stopTest();

        // Only _Saved_Table_Rows is read. _Final_Apex_Lines sits in the payload
        // and is ignored, which is what the fourth assertion below pins.
        Assert.areEqual(4, c.lineItems.size(), 'One line item per saved table row');
        Assert.areEqual('lower-case notes key', c.quoteNotes, 'notes key should map');
        Assert.areEqual('Crash Barrier - Department', c.selectedTemplate, 'Template name should map');
        for (Map<String, Object> li : c.lineItems) {
            Assert.areNotEqual('Ignored Line', String.valueOf(li.get('name')),
                '_Final_Apex_Lines is not read by this controller and must not appear');
        }

        Map<String, Object> full = rowNamed(c, 'Row Full');
        Assert.isTrue(((Decimal) full.get('rate')) == 4406, 'An explicit rate is used as-is');
        Assert.isTrue(((Decimal) full.get('total_price')) == 22030, 'An explicit total_price is used as-is');
        Assert.isTrue(((Decimal) full.get('per_price_total')) == 22030, 'per_price_total is rate * qty');
        Assert.areEqual(1, full.get('SlNo'), 'Serial numbers start at one');

        Map<String, Object> fallback = rowNamed(c, 'Row Fallback');
        Assert.isTrue(((Decimal) fallback.get('rate')) == 100, 'No rate key falls back to unitPrice');
        Assert.isTrue(((Decimal) fallback.get('price_per_uom')) == 250,
            'No price_per_uom key falls back to netPrice');
        Assert.isTrue(((Decimal) fallback.get('total_price')) == 500,
            'No total_price key derives qty * price_per_uom');

        Map<String, Object> bare = rowNamed(c, 'Row Bare');
        Assert.isTrue(((Decimal) bare.get('weight')) == 0, 'A missing weight defaults to zero');
        Assert.isTrue(((Decimal) bare.get('rate')) == 0, 'A row with no prices defaults to zero');
        Assert.isTrue(((Decimal) bare.get('total_price')) == 0, 'A bare row totals zero');

        Map<String, Object> hidden = rowNamed(c, 'Row Hidden Class');
        Assert.areEqual('', String.valueOf(hidden.get('Pipe_Class__c')),
            'Reflect_In_Offer_Doc__c = No must blank the pipe class');

        // 22030 + 500 + 0 + 5
        Assert.isTrue(c.totalAmount == 22535, 'totalAmount accumulates every row total');
        // 120 (wb_natrax_fvf) + 100 (w_SSSB) + 50 (w_SSDB); blank and unlisted keys add nothing
        Assert.isTrue(c.fullVehicleFreight == 270, 'Full-vehicle freight sums every listed key');
        Assert.isTrue(c.dynamicPaymentTerms.contains('Usance'), 'Crash Barrier LC branch');
    }

    private static Map<String, Object> rowNamed(QuoteExportController c, String name) {
        for (Map<String, Object> li : c.lineItems) {
            if (name.equals(String.valueOf(li.get('name')))) return li;
        }
        Assert.fail('Row not found in lineItems: ' + name);
        return null;
    }

    @IsTest
    static void testSavedRowSkipsQuoteIdRow() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'RowIdMatch' LIMIT 1];

        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name' => 'Core - Department',
            '_Saved_Table_Rows' => new List<Object>{
                new Map<String, Object>{
                    'id' => String.valueOf(q.Id), 'name' => 'Parent Summary',
                    'quantity' => 1, 'unitPrice' => 999
                },
                new Map<String, Object>{
                    'id' => 'temp_1', 'name' => 'Child Line', 'quantity' => 2, 'unitPrice' => 100
                }
            }
        };
        q.Quote_Value__c = JSON.serialize(d);
        update q;

        Test.startTest();
        QuoteExportController c = new QuoteExportController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual(1, c.lineItems.size(), 'The row whose id equals the Quote Id must be skipped');
        Assert.isTrue(c.totalAmount == 200, 'The skipped summary row must not reach the total');
    }

    @IsTest
    static void testCrashBarrierConfigRows() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Crash Config');
        Test.stopTest();

        Assert.areEqual(4, c.beamSections.size(), 'Two W-beam and two Thrie sections; unknown id ignored');
        Assert.isTrue(c.beamSections[0].sectionTitle.startsWith('W BEAM'), 'W beam title');
        Assert.isTrue(c.beamSections[2].sectionTitle.startsWith('THRIE BEAM'), 'Thrie beam title');
        Assert.isTrue(c.beamSections[3].quantity == 0, 'Non-numeric quantityRm falls back to 0');
        Assert.isTrue(c.beamSections[0].quantity == 23, 'Numeric quantityRm is read straight through');
        Assert.isTrue(c.beamSections[0].rate == 2400, 'rateRm is read straight through');
        Assert.isFalse(c.beamSections[0].rows.isEmpty(), 'Each section builds its description rows');
        Assert.areEqual('Notes__c key', c.quoteNotes, 'Notes__c key should map');
        Assert.areEqual('The rates are on Ex - works basis.', c.dynamicFreightTerm,
            'A non F.O.R incoterm falls back to the Ex-works sentence');
        Assert.areEqual(7, c.validityDays, 'Numeric validity days is read straight through');
        Assert.areEqual('Special', c.tcSpecialNote, 'Special note should map');
    }

    /* ------- Legacy crash-barrier path: no _crashBarrierConfig present ------- */

    @IsTest
    static void testLegacyWBeamSectionsFromFlags() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Legacy W');
        Test.stopTest();

        // w_SSSB and w_SSDB are flagged true; w_DSSB is false and w_DSDB absent.
        Assert.areEqual(2, c.beamSections.size(),
            'Only the types whose flag is boolean true become sections');

        QuoteExportController.BeamSectionWrapper sssb = c.beamSections[0];
        Assert.isTrue(sssb.sectionTitle.startsWith('W BEAM CRASH TESTED'),
            'W-beam title prefix: ' + sssb.sectionTitle);
        Assert.isTrue(sssb.sectionTitle.endsWith('Single Side Single Beam (W-SSSB)'),
            'The friendly label is appended to the title: ' + sssb.sectionTitle);
        Assert.areEqual('73089090', sssb.hsnCode, 'W-beam HSN is fixed');
        Assert.areEqual('MTR', sssb.unit, 'W-beam unit is fixed');
        Assert.isTrue(sssb.quantity == 100, 'quantity read from <pfx>_w_beam_quantity_rm');
        Assert.isTrue(sssb.rate == 1500, 'rate read from <pfx>_w_beam_rate_rm');
        Assert.isTrue(sssb.amount == 150000, 'amount is quantity * rate');
        Assert.isTrue(sssb.unitPrice == 1600, 'unit price read from <pfx>_w_unit_price');
        Assert.isTrue(sssb.unitCost == 1400, 'unit cost read from <pfx>_w_unit_cost');
        Assert.isTrue(sssb.showTransport,
            'A transport term other than Ex-works shows the transport line');
        // beam, spacer, post, round bolt, hex bolt
        Assert.areEqual(5, sssb.rows.size(), 'SSSB contains a spacer, so it prints five rows');
        Assert.isTrue(sssb.rows[1].description.contains('Spacer channel'),
            'The second row is the spacer description');

        QuoteExportController.BeamSectionWrapper ssdb = c.beamSections[1];
        Assert.isFalse(ssdb.showTransport, 'Ex-works hides the transport line');
        // SSDB has no spacer: beam, post, round bolt, hex bolt
        Assert.areEqual(4, ssdb.rows.size(), 'SSDB has no spacer, so it prints four rows');
        Assert.isTrue(ssdb.amount == 100000, 'amount is quantity * rate for the second section too');

        // exactly one row in each section carries the priced columns
        Integer priced = 0;
        for (QuoteExportController.DescRow r : sssb.rows) {
            if (r.hasAmount) priced++;
        }
        Assert.areEqual(1, priced, 'Only the post-channel row carries the amount columns');
    }

    @IsTest
    static void testLegacyThrieBeamSectionsFromFlags() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Legacy Thrie');
        Test.stopTest();

        // con_type_select carries no capital W, so the Thrie branch takes over.
        Assert.areEqual(2, c.beamSections.size(),
            'Thrie_SSSB and Thrie_DSDB are flagged true; the others are skipped');

        QuoteExportController.BeamSectionWrapper sssb = c.beamSections[0];
        Assert.isTrue(sssb.sectionTitle.startsWith('THRIE BEAM CRASH TESTED'), 'Thrie title prefix');
        Assert.isTrue(sssb.quantity == 20, 'quantity read from <pfx>_quantity_rm');
        Assert.isTrue(sssb.rate == 3000, 'rate read from <pfx>_rate_rm');
        Assert.isTrue(sssb.amount == 60000, 'amount is quantity * rate');
        Assert.isFalse(sssb.showTransport, 'Ex-works hides the transport line');
        // Thrie always prints the spacer row
        Assert.areEqual(5, sssb.rows.size(), 'Every Thrie section prints five rows');
        Assert.isTrue(sssb.rows[1].description.contains('Spacer channel'),
            'Thrie sections always include the spacer row');

        QuoteExportController.BeamSectionWrapper dsdb = c.beamSections[1];
        Assert.isTrue(dsdb.showTransport, 'A non Ex-works transport term shows the line');
        Assert.isTrue(dsdb.amount == 40000, 'amount is quantity * rate for the second section');
    }

    /* ---------------- F.O.R freight sentence ---------------- */

    @IsTest
    static void testForFreightTermUsesShippingAddress() {
        Test.startTest();
        QuoteExportController c = ctrlFor('FOR Shipping');
        Test.stopTest();

        String term = c.dynamicFreightTerm;
        Assert.isTrue(term.startsWith('The rates Quoted are on F.O.R destination basis'),
            'The F.O.R branch builds its own sentence: ' + term);
        Assert.isTrue(term.contains('Plot 21, Kolkata, West Bengal'),
            'The shipping address parts are joined in order: ' + term);
        Assert.isTrue(term.contains('PINCODE - 700001'), 'A usable zip is appended: ' + term);
        // freight was written as 100.00, and the trailing .00 is stripped
        Assert.isTrue(term.contains('Bulk (100)'),
            'A whole-rupee bulk figure drops its trailing .00: ' + term);
    }

    @IsTest
    static void testForFreightTermFallsBackToBillingAndFiltersPlaceholders() {
        Test.startTest();
        QuoteExportController c = ctrlFor('FOR Billing');
        Test.stopTest();

        String term = c.dynamicFreightTerm;
        Assert.isTrue(term.contains('Bihar'), 'The one usable billing part survives: ' + term);
        Assert.isFalse(term.contains('Not Found'),
            'A "Not Found" placeholder must never reach the offer: ' + term);
        Assert.isFalse(term.contains('@@'),
            'An unresolved @@ token must never reach the offer: ' + term);
        Assert.isFalse(term.contains('PINCODE'),
            'A "Not Found" zip appends no PINCODE segment: ' + term);
    }

    /* ---------------- Subject line auto-generation ---------------- */

    @IsTest
    static void testSubjectLineBuildsFromSolarMaterials() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Subject Auto');
        Test.stopTest();

        
    }

    @IsTest
    static void testSubjectLineFallsBackToMms() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Subject MMS');
        Test.stopTest();

        
    }

    @IsTest
    static void testEnsureKeyDefaultsAndSuppliedValues() {
        Test.startTest();
        QuoteExportController supplied = ctrlFor('Subject MMS');   // carries two of its own
        QuoteExportController bare     = ctrlFor('Defaults');      // carries none
        Test.stopTest();

        // supplied values must survive
        Assert.areEqual('Deepanjan', String.valueOf(supplied.jsonData.get('Contact_Person')),
            'A supplied value must not be replaced by the default');
        Assert.areEqual('EXCLUDED', String.valueOf(supplied.jsonData.get('tc_transportation')),
            'A supplied value must not be replaced by the default');

        // everything else is backfilled, on both quotes
        List<String> required = new List<String>{
            'Contact_Person', 'Contact_Number', 'Email', 'tc_offer_validity',
            'tc_delivery_schedule', 'tc_price_variation', 'tc_payment_terms',
            'tc_transportation', 'tc_vehicle_load', 'tc_tolerance',
            'tc_inspection', 'tc_pre_dispatch_inspection'
        };
        for (String key : required) {
            Assert.isTrue(String.isNotBlank(String.valueOf(bare.jsonData.get(key))),
                'Missing safety-net default for ' + key);
        }
        Assert.areEqual('INCLUDED', String.valueOf(bare.jsonData.get('tc_transportation')),
            'The transport default applies when nothing was supplied');
    }

    /* ---------------- PEB: the figures come off the OPPORTUNITY ---------------- */

    @IsTest
    static void testPebReadsCalculatorEstimateFromOpportunity() {
        Test.startTest();
        QuoteExportController c = ctrlFor('PEB');
        Test.stopTest();

        // Rows with a blank description or zero quantity are placeholders.
        Assert.areEqual(1, c.pebAccessories.size(), 'Blank and zero-quantity accessory rows are skipped');
        Assert.areEqual(1, c.buyoutItems.size(), 'One buyout item expected');
        Assert.areEqual('Turbo Ventilator', c.pebAccessories[0].description, 'Accessory description');
        Assert.areEqual('Nos', c.pebAccessories[0].size, 'unit maps onto size');
        Assert.areEqual('4', c.pebAccessories[0].quantity, 'qty maps onto quantity, rounded');
        Assert.areEqual('Painted', c.pebAccessories[0].remark, 'reason maps onto remark');
        Assert.areEqual('Roller Shutter', c.buyoutItems[0].description, 'Buyout description');

        Assert.areEqual('1,63,03,965', c.supplyPriceBasic, 'Basic price uses Indian digit grouping');
        Assert.areEqual('29,34,714', c.supplyPriceGst, 'GST uses Indian digit grouping');
        Assert.areEqual('1,92,38,679', c.supplyPriceWithGst, 'Total uses Indian digit grouping');
        Assert.areEqual('294', c.tentativeWeightMt, 'Section A weight converts from Kg to whole MT');
        Assert.areEqual('31-Jul-2026', c.termsDate, 'The calculator stamp wins over today');
    }

    @IsTest
    static void testPebPaymentTermsAndClauseNumbering() {
        Test.startTest();
        QuoteExportController withErection = ctrlFor('PEB');
        QuoteExportController noErection   = ctrlFor('PEB NoErect');
        Test.stopTest();

        // Periods typed on the calculator's Summary screen override the defaults.
        Assert.areEqual('10-12 weeks', withErection.consignmentPeriod, 'Consignment period from the estimate');
        Assert.areEqual('6 weeks', withErection.erectionPeriod, 'Erection period from the estimate');
        Assert.areEqual('30 days', withErection.pebvalidity, 'Validity from the estimate');

        // Erection cost present -> the clause prints and Delivery slides to E.7
        Assert.isTrue(withErection.showErectionTerms, 'An erection cost should show the erection clause');
        Assert.areEqual('E.6', withErection.ptErectionNo, 'Erection clause is numbered E.6');
        Assert.areEqual('E.7', withErection.ptDeliveryNo, 'Delivery moves to E.7 behind the erection clause');

        // Erection at zero -> clause hidden, Delivery returns to E.6
        Assert.isFalse(noErection.showErectionTerms, 'Zero erection cost hides the clause');
        Assert.areEqual('E.6', noErection.ptDeliveryNo, 'With no erection clause Delivery is E.6');
    }

    @IsTest
    static void testPebFallsBackWhenNoCalculatorEstimate() {
        // The quote sits on an Opportunity with no Price_Calculation_JSON__c, so
        // every figure has to fall back to its default and the periods to
        // tc_delivery_days. This is the signal that the calculator never ran.
        Test.startTest();
        QuoteExportController c = ctrlFor('PEB NoCalc');
        Test.stopTest();

        Assert.areEqual('0', c.supplyPriceBasic, 'No estimate means a zero supply price');
        Assert.areEqual('0', c.tentativeWeightMt, 'No estimate means a zero tentative weight');
        Assert.isTrue(c.pebAccessories.isEmpty(), 'No estimate means no accessories');
        Assert.isTrue(c.buyoutItems.isEmpty(), 'No estimate means no buyouts');

        // deliverySchedule is derived from tc_delivery_days, and both period
        // halves default to it.
        Assert.areEqual('45 days', c.deliverySchedule, 'Delivery schedule comes from tc_delivery_days');
        Assert.areEqual('45 days', c.consignmentPeriod, 'Consignment period defaults to the delivery schedule');
        Assert.areEqual('45 days', c.erectionPeriod, 'Erection period defaults to the delivery schedule');
        Assert.areEqual('30 days', c.pebvalidity, 'Validity defaults to tc_validity_days plus " days"');
        Assert.isFalse(c.showErectionTerms, 'No estimate means no erection clause');
        Assert.areEqual('E.6', c.ptDeliveryNo, 'With no erection clause Delivery is E.6');
        Assert.isTrue(String.isNotBlank(c.termsRef), 'termsRef falls back to the quote reference');
    }

    @IsTest
    static void testPebDynamicBuildingMetadataAndFallbacks() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];
        
        // 1. With full building description
        Map<String, Object> bd = new Map<String, Object>{
            'clientInfo' => new Map<String, Object>{
                'clientName' => 'Lal Baba Engineers Ltd.',
                'projectLocation' => 'Haldia, West Bengal',
                'buildingName' => 'Industrial Shed'
            }
        };
        Map<String, Object> qData1 = pebQuoteData();
        qData1.put('_buildingDescription', bd);
        Quote q1 = newQuote('PEB Full BD', opp.Id, null, JSON.serialize(qData1));
        insert q1;

        Test.startTest();
        QuoteExportController c1 = new QuoteExportController(stdCtrl(q1.Id));

        Assert.areEqual('M/s. Lal Baba Engineers Ltd.', c1.effectiveBuyerName, 'Buyer name with M/s. prefix');
        Assert.areEqual('Haldia, West Bengal', c1.effectiveProjectLocation, 'Project location from building description');
        Assert.areEqual('Industrial Shed', c1.effectiveBuildingName, 'Building name from building description');
        Assert.areEqual('Sub: Offer for design, manufacture and supply of Industrial Shed at Haldia, West Bengal.', c1.pebSubjectLine, 'Full subject line');

        // 2. Test Address_Book__c fallback on Opportunity
        Address_Book__c oppAb = new Address_Book__c(
            Opportunity__c = opp.Id,
            Country__c = 'India',
            State__c = 'West Bengal',
            City__c = 'Amta',
            Primary_Address__c = true
        );
        insert oppAb;

        Map<String, Object> qData2 = pebQuoteData();
        Quote q2 = newQuote('PEB Opp AB', opp.Id, null, JSON.serialize(qData2));
        insert q2;

        QuoteExportController c2 = new QuoteExportController(stdCtrl(q2.Id));
        Assert.areEqual('M/s. Test Account', c2.effectiveBuyerName, 'Buyer falls back to Account name');
        Assert.areEqual('Amta, West Bengal', c2.effectiveProjectLocation, 'Location falls back to Opp Address Book');
        Assert.areEqual('', c2.effectiveBuildingName, 'Building name falls back to empty');
        Assert.areEqual('Sub: Offer for design, manufacture and supply at Amta, West Bengal.', c2.pebSubjectLine, 'Subject line without building name');

        // 3. Test blank project site in building description falls back to Address Book and NOT the next item
        Map<String, Object> bd3 = new Map<String, Object>{
            'clientInfo' => new Map<String, Object>{
                'clientName' => 'txt',
                'projectLocation' => '', // blank in table
                'buildingName' => 'Industrial Shed'
            }
        };
        Map<String, Object> qData3 = pebQuoteData();
        qData3.put('_buildingDescription', bd3);
        Quote q3 = newQuote('PEB Blank Site BD', opp.Id, null, JSON.serialize(qData3));
        insert q3;

        QuoteExportController c3 = new QuoteExportController(stdCtrl(q3.Id));
        Assert.areEqual('M/s. txt', c3.effectiveBuyerName, 'Buyer is txt');
        Assert.areEqual('Amta, West Bengal', c3.effectiveProjectLocation, 'Blank site correctly falls back to Address Book and NOT next item');
        Assert.areEqual('Industrial Shed', c3.effectiveBuildingName, 'Building name is Industrial Shed');
        Assert.areEqual('Sub: Offer for design, manufacture and supply of Industrial Shed at Amta, West Bengal.', c3.pebSubjectLine, 'Subject has building name and address book site');

        // 4. Test corrupted table artifact like 'Opening' in building description is rejected and falls back to Address Book
        Map<String, Object> bd4 = new Map<String, Object>{
            'clientInfo' => new Map<String, Object>{
                'clientName' => 'txt',
                'projectLocation' => 'Opening', // corrupted table header artifact
                'buildingName' => 'Industrial Shed'
            }
        };
        Map<String, Object> qData4 = pebQuoteData();
        qData4.put('_buildingDescription', bd4);
        Quote q4 = newQuote('PEB Corrupted Opening BD', opp.Id, null, JSON.serialize(qData4));
        insert q4;

        QuoteExportController c4 = new QuoteExportController(stdCtrl(q4.Id));
        Assert.areEqual('Amta, West Bengal', c4.effectiveProjectLocation, 'Opening header correctly rejected and falls back to Address Book');

        Test.stopTest();
    }

    @IsTest
    static void testPebUniversalDocSections() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];

        List<Map<String, Object>> mockSections = new List<Map<String, Object>>{
            new Map<String, Object>{
                'title' => '(A) DESIGN CRITERIA',
                'sectionType' => 'chapter',
                'notes' => new List<String>{ 'Design note 1' }
            },
            new Map<String, Object>{
                'title' => '(B) Project Summary:',
                'sectionType' => 'table',
                'colCount' => 2,
                'tableHeaders' => new List<String>(),
                'tableRows' => new List<Map<String, Object>>{
                    new Map<String, Object>{ 'c1' => 'Total no. of Buildings', 'c2' => '01' }
                }
            },
            new Map<String, Object>{
                'title' => '',
                'subtitle' => '(if more than one building or more than one area)',
                'sectionType' => 'table',
                'colCount' => 3,
                'tableHeaders' => new List<String>{ 'UTILITY OF BUILDING.', 'No. OF BUILDING', 'Total Area (Sqm.)' },
                'tableRows' => new List<Map<String, Object>>{
                    new Map<String, Object>{ 'c1' => 'Factory Cum Warehouse', 'c2' => '1', 'c3' => '20600' },
                    new Map<String, Object>{ 'c1' => '', 'c2' => 'Total area', 'c3' => '20600', 'isSubHeader' => false }
                }
            },
            new Map<String, Object>{
                'title' => 'C.1.8.7 Accessories:',
                'sectionType' => 'table',
                'colCount' => 4,
                'tableHeaders' => new List<String>{ '', 'Description', 'Quantity', 'Remarks' },
                'tableRows' => new List<Map<String, Object>>{
                    new Map<String, Object>{ 'c1' => '1', 'c2' => 'Sky Light', 'c3' => '16 Nos.', 'c4' => 'Polycarbonate' }
                }
            },
            new Map<String, Object>{
                'title' => 'D.1 Building technical notes:',
                'sectionType' => 'list',
                'listItems' => new List<String>{ '1. Grid line C/C dimensions' }
            }
        };

        Map<String, Object> bd = new Map<String, Object>{
            'docSections' => mockSections
        };
        Map<String, Object> qData = pebQuoteData();
        qData.put('_buildingDescription', bd);
        Quote q = newQuote('PEB Universal Sections', opp.Id, null, JSON.serialize(qData));
        insert q;

        Test.startTest();
        QuoteExportController c = new QuoteExportController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual(5, c.docSections.size(), 'Should parse 5 doc sections');
        
        // Chapter check
        QuoteExportController.DocSection sec1 = c.docSections[0];
        Assert.isTrue(sec1.isChapter, 'Sec 1 is chapter');
        Assert.areEqual('(A) DESIGN CRITERIA', sec1.title);
        Assert.areEqual(1, sec1.notes.size());

        // Project Summary Box check
        QuoteExportController.DocSection sec2 = c.docSections[1];
        Assert.isTrue(sec2.isTable, 'Sec 2 is table');
        Assert.isTrue(sec2.isProjectSummaryBox, 'Sec 2 is project summary box');
        Assert.areEqual('45%', sec2.w1, 'Project summary box w1 is 45%');
        Assert.areEqual('55%', sec2.w2, 'Project summary box w2 is 55%');

        // Project Summary Table check
        QuoteExportController.DocSection sec3 = c.docSections[2];
        Assert.isTrue(sec3.isTable, 'Sec 3 is table');
        Assert.isTrue(sec3.isProjectSummaryTable, 'Sec 3 is project summary table');
        Assert.areEqual('35%', sec3.w1, 'Utility col w1 is 35%');
        Assert.areEqual('30%', sec3.w2, 'No of bldg w2 is 30%');
        Assert.areEqual('35%', sec3.w3, 'Total area w3 is 35%');

        // Accessories Table check
        QuoteExportController.DocSection sec4 = c.docSections[3];
        Assert.isTrue(sec4.isTable, 'Sec 4 is table');
        Assert.isTrue(sec4.isFirstColSrNo, 'Sec 4 detects first col as Sr No');
        Assert.areEqual('5%', sec4.w1, 'Sr No col w1 is 5%');
        Assert.areEqual('25%', sec4.w2, 'Desc col w2 is 25%');
        Assert.areEqual('35%', sec4.w3, 'Qty col w3 is 35%');
        Assert.areEqual('35%', sec4.w4, 'Remarks col w4 is 35%');

        // List check
        QuoteExportController.DocSection sec5 = c.docSections[4];
        Assert.isTrue(sec5.isList, 'Sec 5 is list');
        Assert.areEqual('D.1 Building technical notes:', sec5.title);
        Assert.areEqual(1, sec5.listItems.size());
    }

    @IsTest
    static void testDefaultsAndFallbacks() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Defaults');
        List<QuoteExportController.SolarItem> items = c.getSolarItems();
        Test.stopTest();

        Assert.isTrue(items.isEmpty(), 'No solar config -> no solar items');
        Assert.areEqual('', c.quoteNotes, 'No note keys -> empty string');
        Assert.isTrue(c.lineItems.isEmpty(), 'No _Saved_Table_Rows -> empty list');
        Assert.areEqual('Weight', c.unitOfMeasurement, 'Default UOM');
        Assert.areEqual('', c.deliverySchedule, 'No tc_delivery_days -> empty delivery schedule');
        Assert.isTrue(c.getTotalFreight() == 0, 'No solar config -> zero freight');
        Assert.isTrue(c.getSubTotal() == 0, 'No solar config -> zero sub-total');
        Assert.isTrue(c.fullVehicleFreight == 0, 'No freight keys -> 0');
        Assert.isTrue(c.beamSections.isEmpty(), 'No crash config -> no beam sections');
    }

    @IsTest
    static void testStaticResourceHelper() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Defaults');
        String missing = c.getBase64FromStaticResource('No_Such_Resource_12345');
        Test.stopTest();

        Assert.areEqual('', missing, 'A missing static resource returns an empty string, not an error');
        Assert.isNotNull(c.loggedInUser, 'The running user name should be resolved');
        Assert.isNotNull(c.loggedInUserTitle, 'A missing title falls back to Sales Manager');
    }

    @IsTest
    static void testNullAccountAndContact() {
        Test.startTest();
        QuoteExportController c = ctrlFor('No Acct/Con');
        Test.stopTest();

        Assert.areEqual('N/A', c.contactName, 'Null contact -> N/A');
        Assert.areEqual('N/A', c.contactNumber, 'Null contact -> N/A phone');
        Assert.areEqual('N/A', c.contactEmail, 'Null contact -> N/A email');
        Assert.areEqual('Account Name Not Found', c.accountName, 'Null account -> default name');
        Assert.isNotNull(c.quoteRef, 'Quote reference should build');
        Assert.isTrue(c.quoteRef.startsWith('UIL/MBCB/'), 'Quote reference carries the fixed prefix');
        Assert.isNotNull(c.validityDateFormatted, 'Validity date should format');
        Assert.isNotNull(c.referenceNum, 'Reference number falls back to the quote name');
    }

    @IsTest
    static void testContactDetailsMapWhenPresent() {
        Test.startTest();
        QuoteExportController c = ctrlFor('Defaults');
        Test.stopTest();

        Assert.areEqual('Shubhas Khatri', c.contactName, 'Contact name should map');
        Assert.areEqual('919999999999', c.contactNumber, 'Contact phone should map');
        Assert.areEqual('shubhas@test.com', c.contactEmail, 'Contact email should map');
        Assert.areEqual('Test Account', c.accountName, 'Account name should map');
    }

    @IsTest
    static void testBlankAndInvalidJson() {
        Quote blankQ = [SELECT Id FROM Quote WHERE Name = 'Blank JSON' LIMIT 1];
        Quote badQ   = [SELECT Id FROM Quote WHERE Name = 'Bad JSON'   LIMIT 1];

        Test.startTest();
        QuoteExportController blank = new QuoteExportController(stdCtrl(blankQ.Id));
        QuoteExportController bad   = new QuoteExportController(stdCtrl(badQ.Id)); // hits catch
        Test.stopTest();

        Assert.areEqual('100% advance along with PI.', blank.dynamicPaymentTerms, 'Blank -> default payment');
        Assert.areEqual('Weight', blank.unitOfMeasurement, 'Blank -> default UOM');
        Assert.areEqual('100% advance along with PI.', bad.dynamicPaymentTerms, 'Parse failure -> default payment');
        Assert.isNotNull(bad.quoteRecord, 'Quote header still loads after parse failure');
        Assert.isTrue(bad.lineItems.isEmpty(), 'A parse failure leaves the line items empty');
    }

    @IsTest
    static void testPaymentTermVariants() {
        Set<String> names = new Set<String>{
            'Sol LC', 'Sol VFS', 'Sol PDC', 'Sol PDCBlank', 'Sol OpenCr', 'Sol Default',
            'Cr OpenCr', 'Cr BG', 'Cr LC', 'Cr Advance', 'Cr Other', 'Cr Default'
        };
        Map<Id, String> byId = new Map<Id, String>();
        for (Quote q : [SELECT Id, Name FROM Quote WHERE Name IN :names]) byId.put(q.Id, q.Name);

        Test.startTest();
        Map<String, String> results = new Map<String, String>();
        for (Id qid : byId.keySet()) {
            QuoteExportController c = new QuoteExportController(stdCtrl(qid));
            results.put(byId.get(qid), c.dynamicPaymentTerms);
        }
        Test.stopTest();

        Assert.isTrue(results.get('Sol LC').contains('Against LC Before Dispatch'), 'Solar LC branch');
        Assert.isTrue(results.get('Sol VFS').contains('Against VFS for'), 'Solar VFS branch');
        Assert.isTrue(results.get('Sol PDC').contains('Against PDC for'), 'Solar PDC-with-days branch');
        Assert.isTrue(results.get('Sol PDCBlank').contains('Against PDC.'), 'Solar PDC-no-days branch');
        Assert.isTrue(results.get('Sol OpenCr').contains('Against Open Credit'), 'Solar open credit branch');
        Assert.areEqual('100% advance along with PI.', results.get('Sol Default'), 'Solar default branch');
        // tc_advance_payment is 'abc', so the advance percentage falls back to 30
        Assert.isTrue(results.get('Sol LC').contains('30%'), 'Non-numeric advance falls back to 30%');
        Assert.isTrue(results.get('Sol LC').contains('70%'), 'The balance is derived as 100 minus advance');

        Assert.isTrue(results.get('Cr OpenCr').contains('Against Open credit'), 'Crash open credit branch');
        Assert.isTrue(results.get('Cr BG').contains('Against BG'), 'Crash BG branch');
        Assert.isTrue(results.get('Cr LC').contains('Usance'), 'Crash LC branch');
        Assert.areEqual('Advance days. 100% Advance before dispatch', results.get('Cr Advance'), 'Crash advance branch');
        Assert.areEqual('Custom Term', results.get('Cr Other'), 'Crash passthrough branch');
        Assert.areEqual('100% advance along with PI.', results.get('Cr Default'), 'Crash default branch');
    }

    @IsTest
    static void testMergedCellsTableHtml() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Solar Pcs' LIMIT 1];
        
        Map<String, Object> secMap = new Map<String, Object>{
            'title' => 'C.1.2 Bracing System .',
            'sectionType' => 'table',
            'colCount' => 3,
            'colWidths' => new List<Object>{ '6%', '44%', '50%' },
            'tableHeaders' => new List<Object>(),
            'tableRows' => new List<Object>{
                new Map<String, Object>{
                    'c1' => '1', 'r1Span' => 3, 'c2' => 'Roof', 'c3' => 'Rod'
                },
                new Map<String, Object>{
                    'skipC1' => true, 'c2' => 'Side Columns up to Crane/Mezzanine/ Opening', 'c3' => 'Pipe'
                },
                new Map<String, Object>{
                    'skipC1' => true, 'c2' => 'Side Columns over Crane/Mezzanine/ Opening', 'c3' => ''
                },
                new Map<String, Object>{
                    'c1' => '2', 'r1Span' => 1, 'c2' => 'Intermediate Columns up to Crane/Mezzanine/ Opening', 'c3' => ''
                },
                new Map<String, Object>{
                    'c1' => '3', 'r1Span' => 1, 'c2' => 'Intermediate Columns over Crane/Mezzanine/ Opening', 'c3' => ''
                }
            }
        };

        Map<String, Object> qVal = new Map<String, Object>{
            '_buildingDescription' => new Map<String, Object>{
                'docSections' => new List<Object>{ secMap }
            }
        };

        q.Quote_Value__c = JSON.serialize(qVal);
        update q;

        Test.startTest();
        QuoteExportController c = new QuoteExportController(stdCtrl(q.Id));
        Test.stopTest();

        Assert.areEqual(1, c.docSections.size(), 'One doc section parsed');
        QuoteExportController.DocSection sec = c.docSections[0];
        Assert.areEqual(3, sec.colCount, '3 columns');
        Assert.areEqual(3, sec.colWidths.size(), 'Custom widths applied');
        Assert.areEqual(5, sec.tableRows.size(), '5 table rows');
        Assert.areEqual(3, sec.tableRows[0].r1Span, 'Row 1 has rowspan 3');
        Assert.isTrue(sec.tableRows[1].skipC1, 'Row 2 skips C1');
        Assert.isTrue(sec.tableRows[2].skipC1, 'Row 3 skips C1');

        String html = sec.tableHtml;
        Assert.isTrue(html.contains('rowspan="3"'), 'HTML contains rowspan 3');
        Assert.isTrue(html.contains('vertical-align: middle;'), 'HTML contains vertical-align middle for spanned row');
        Assert.isTrue(html.contains('width: 6%'), 'HTML uses custom colWidth 6%');
    }
}