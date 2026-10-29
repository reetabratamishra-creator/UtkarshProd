public class QuoteExportController {

    // ─── Existing Fields (unchanged) ──────────────────────────────────────
    public Quote                      quoteRecord      { get; set; }
    public Map<String, Object>        jsonData         { get; set; }
    public List<Map<String, Object>>  lineItems        { get; set; }
    public Decimal                    totalAmount      { get; set; }
    public String                     todayDate        { get; set; }
    public String                     accountName      { get; set; }
    public String                     contactName      { get; set; }
    public String                     contactNumber    { get; set; }
    public String                     contactEmail     { get; set; }
    public String                     selectedTemplate { get; set; }
    public String                     quoteNotes       { get; set; }

    // ─── NEW: Crash Barrier Fields ────────────────────────────────────────
    public String                     quoteRef           { get; set; }
    // ── NEW: Word document helpers ──
    public String                     logoBase64         { get; set; }
    public String                     logoSmallBase64    { get; set; } // smaller logo for Excel/tables
    public String                     referenceNum       { get; set; }
    public String                     loggedInUser       { get; set; }
    public String                     loggedInUserTitle  { get; set; }
    public String                     loggedInUserPhone  { get; set; }
    public List<BeamSectionWrapper>   beamSections       { get; set; }
    public String                     freightIncoterms   { get; set; }
    public Decimal                    fullVehicleFreight { get; set; }
    public Integer                    validityDays       { get; set; }
    public String                     paymentTerms       { get; set; }
    public Integer                    noOfDaysIFC        { get; set; }
    public Integer                    usancePeriod       { get; set; }
    public String                     tcSpecialNote      { get; set; }

    // ──────────────────────────────────────────────────────────────────────

    public String dynamicPaymentTerms { get; set; }
    public String unitOfMeasurement { get; set; }
    public String dynamicFreightTerm  { get; set; }

      // ── NEW: Solar T&C fields mapped from JSON ────────────────────────────
   
    public String incoterms           { get; set; }
    public String tcSubjectLine       { get; set; }
    public Integer tcAdvancePayment   { get; set; }
    public Integer tcWarrantyMonths   { get; set; }
    public String tcDeliveryDays      { get; set; }
    public String validityDateFormatted { get; set; }
    public String micronThickness     { get; set; }

    // ── PEB Module / GenerateBankDoc.page (30th July 2026) ──────────────
    // That page binds these ten names. None of them existed, and Visualforce
    // validates every {! } expression at SAVE time, so the page could not
    // compile - which is why both the deploy from VS Code and the document
    // generation failed with "Unknown property". Deepanjan (30th July 2026)
    public String        termsRef           { get; set; }
    public String        termsDate          { get; set; }
    public List<PebRow>  pebAccessories     { get; set; }
    public List<PebRow>  buyoutItems        { get; set; }
    public String        supplyPriceBasic   { get; set; }
    public String        supplyPriceGst     { get; set; }
    public String        supplyPriceWithGst { get; set; }
    public String        tentativeWeightMt  { get; set; }
    public String        deliverySchedule   { get; set; }
    public String        pebvalidity        { get; set; }
    // PEB PAYMENT TERMS - Deepanjan (31st July 2026). The two halves of the
    // Delivery Schedule sentence used to share one merge field; they are now
    // separate. showErectionTerms / ptErectionNo / ptDeliveryNo drive the
    // conditional Erection Payment Terms clause and keep the E. numbering
    // gap-free either way.
    public String        consignmentPeriod  { get; set; }
    public String        erectionPeriod     { get; set; }
    public Boolean       showErectionTerms  { get; set; }
    public String        ptErectionNo       { get; set; }
    public String        ptDeliveryNo       { get; set; }

    // ── PEB Building Description Fields ──
    public Map<String, Object> buildingGeometry      { get; set; }
    public Map<String, Object> buildingRoof          { get; set; }
    public Map<String, Object> buildingWall          { get; set; }
    public List<String>        buildingTechNotes     { get; set; }
    public List<String>        buildingMaterialSpecs    { get; set; }
    public String              buildingClientName       { get; set; }
    public String              buildingProjectLocation  { get; set; }
    public String              buildingName             { get; set; }
    public String              effectiveBuyerName       { get; set; }
    public String              effectiveProjectLocation { get; set; }
    public String              effectiveBuildingName    { get; set; }
    public String              pebSubjectLine           { get; set; }

    // Direct typed properties for reliable Visualforce EL rendering
    public String buildingFrameType        { get; set; }
    public String buildingWidth            { get; set; }
    public String buildingLength           { get; set; }
    public String buildingHeight           { get; set; }
    public String buildingSlope            { get; set; }
    public String buildingBaySpacing       { get; set; }
    public String buildingRoofProfile      { get; set; }
    public String buildingRoofThickness    { get; set; }
    public String buildingRoofMaterial     { get; set; }
    public String buildingRoofEave         { get; set; }
    public String buildingWallProfile      { get; set; }
    public String buildingWallThickness    { get; set; }
    public String buildingWallMaterial     { get; set; }
    public String buildingWallDownspouts   { get; set; }
    public String buildingWallBrickHeight  { get; set; }

    // Project Summary areas
    public String buildingMainArea         { get; set; }
    public String buildingCanopyArea       { get; set; }
    public String buildingMezzanineArea    { get; set; }
    public String buildingGrossArea        { get; set; }

    // Geometry extras
    public String buildingFrameTypeRemark  { get; set; }
    public String buildingWidthModule      { get; set; }
    public String buildingEndWallBay       { get; set; }
    public String buildingBracingRoof      { get; set; }
    public String buildingBracingWall      { get; set; }
    public String buildingSurfacePrepPrimary { get; set; }
    public String buildingSurfacePrepSecondary { get; set; }

    // Codes & Loads
    public String buildingDesignCode       { get; set; }
    public String buildingWindSpeed        { get; set; }
    public String buildingSeismicZone      { get; set; }
    public String buildingLiveLoad         { get; set; }
    public String buildingDeadLoad         { get; set; }

    // Additions
    public Boolean hasCanopy               { get; set; }
    public String buildingCanopyDesc       { get; set; }
    public Boolean hasCrane                { get; set; }
    public String buildingCraneDesc        { get; set; }
    public Boolean hasMezzanine            { get; set; }
    public String buildingMezzanineDesc    { get; set; }
    public String buildingRoofMonitorDesc  { get; set; }
    public Boolean showRoofMonitorSection  { get; set; }
    public List<ParamTableRow> paramTableRows { get; set; }
    public List<DocSection>    docSections    { get; set; }



    public QuoteExportController(ApexPages.StandardController stdController) {
        
        try {
            if (!Test.isRunningTest()) {
                stdController.addFields(new List<String>{
                    'QuoteNumber', 
                    'Opportunity.Name', 
                    'BillingStreet', 
                    'BillingCity', 
                    'BillingState', 
                    'BillingPostalCode',
                    'CreatedDate'
                });
            }
        } catch (Exception e) {
            // Guard against SObjectException in testing or anonymous execution
        }

        // ── Single merged query with ALL fields needed by every PDF page ──
        quoteRecord = [
            SELECT Id, Name, QuoteNumber, Quote_Value__c, CreatedDate,
                   OpportunityId, AccountId,
                   Account.Name, Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                   Contact.Name, Contact.Phone, Contact.Email,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode,
                   Opportunity.Name, Opportunity.Price_Calculation_JSON__c
            FROM   Quote
            WHERE  Id = :stdController.getId()
            LIMIT  1
        ];

        // ── NEW: Calculate Validity Date (CreatedDate + 6 Months) ──
        DateTime calcDate = DateTime.newInstance(quoteRecord.CreatedDate.date().addMonths(6), Time.newInstance(0, 0, 0, 0));
        validityDateFormatted = calcDate.format('dd.MM.yyyy');

        // ── Existing: Contact / Account setup ─────────────────────────────
        if (quoteRecord.Contact != null) {
            contactName   = quoteRecord.Contact.Name;
            contactNumber = String.isNotBlank(quoteRecord.Contact.Phone)
                          ? quoteRecord.Contact.Phone : 'N/A';
            contactEmail  = String.isNotBlank(quoteRecord.Contact.Email)
                          ? quoteRecord.Contact.Email : 'N/A';
        } else {
            contactName   = 'N/A';
            contactNumber = 'N/A';
            contactEmail  = 'N/A';
        }

        accountName = quoteRecord.Account != null
                    ? quoteRecord.Account.Name : 'Account Name Not Found';
        totalAmount = 0.00;
        lineItems   = new List<Map<String, Object>>();
        todayDate   = Date.today().format();
        jsonData    = new Map<String, Object>();

        // ── Quote reference string ─────────────────────────────────────────
        quoteRef = 'UIL/MBCB/'
                 + String.valueOf(Date.today().year()).substring(2)
                 + '-'
                 + String.valueOf(Date.today().year() + 1).substring(2)
                 + '/' + quoteRecord.Name;

        // ── NEW: Word document helpers ─────────────────────────────────────
        referenceNum = String.isNotBlank(quoteRecord.QuoteNumber)
                     ? quoteRecord.QuoteNumber : quoteRecord.Name;
        logoBase64      = getBase64FromStaticResource('UtkarshHeader');
        logoSmallBase64 = getBase64FromStaticResource('UtkarshLogo');
        User wu = [SELECT Name, Title, MobilePhone, Phone FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        loggedInUser = wu.Name;
        loggedInUserTitle = wu.Title != null ? wu.Title : 'Sales Manager';
        loggedInUserPhone = wu.MobilePhone != null ? wu.MobilePhone : (wu.Phone != null ? wu.Phone : '');

        // ── Existing: JSON parsing ─────────────────────────────────────────
        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jsonData = (Map<String, Object>)
                           JSON.deserializeUntyped(quoteRecord.Quote_Value__c);

                // Template name
                if (jsonData.containsKey('_Saved_Template_Name')
                        && jsonData.get('_Saved_Template_Name') != null) {
                    selectedTemplate = String.valueOf(jsonData.get('_Saved_Template_Name'));
                }

                // Notes (multi-key fallback — unchanged)
                if (jsonData.containsKey('Note') && jsonData.get('Note') != null) {
                    quoteNotes = String.valueOf(jsonData.get('Note'));
                } else if (jsonData.containsKey('notes') && jsonData.get('notes') != null) {
                    quoteNotes = String.valueOf(jsonData.get('notes'));
                } else if (jsonData.containsKey('Notes__c') && jsonData.get('Notes__c') != null) {
                    quoteNotes = String.valueOf(jsonData.get('Notes__c'));
                } else {
                    quoteNotes = '';
                }

                // Line items (unchanged)
                if (jsonData.containsKey('_Saved_Table_Rows')) {
                    List<Object> rawRows =
                        (List<Object>) jsonData.get('_Saved_Table_Rows');
                    Integer slNo = 1;

                    Integer accCounter = 1;
                    Integer miscCounter = 1;
                    Integer addlMiscCounter = 1;

                    for (Object rowObj : rawRows) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;

                        if (String.valueOf(row.get('id'))
                                != String.valueOf(quoteRecord.Id)) {
                            row.put('SlNo', slNo++);
                            Decimal rowWeight = row.get('weight') != null ? Decimal.valueOf(String.valueOf(row.get('weight'))) : 0.00;
                            row.put('weight', rowWeight);

                            Decimal qty = row.get('quantity') != null
                                ? Decimal.valueOf(String.valueOf(row.get('quantity'))) : 1;
                            Decimal rate = row.get('rate') != null
                                ? Decimal.valueOf(String.valueOf(row.get('rate')))
                                : (row.get('unitPrice') != null
                                    ? Decimal.valueOf(String.valueOf(row.get('unitPrice'))) : 0);
                            Decimal pricePerUom = row.get('price_per_uom') != null
                                ? Decimal.valueOf(String.valueOf(row.get('price_per_uom')))
                                : (row.get('netPrice') != null
                                    ? Decimal.valueOf(String.valueOf(row.get('netPrice'))) : rate);
                            Decimal lineTotal = row.get('total_price') != null
                                ? Decimal.valueOf(String.valueOf(row.get('total_price')))
                                : (qty * pricePerUom);

                            row.put('rate',          rate);
                            row.put('price_per_uom', pricePerUom);
                            row.put('total_price',   lineTotal);

                            // The LWC engine now pre-calculates rate, unitPrice, and total_price for Accessories and Misc
                            // No need to scrape legacy fields anymore!
                            row.put('per_price', rate);
                            row.put('per_price_total', (rate * qty).setScale(2));

                            // Handle Reflect in Offer Doc for Wall Thickness
                            if (row.containsKey('Reflect_In_Offer_Doc__c') && String.valueOf(row.get('Reflect_In_Offer_Doc__c')) == 'No') {
                                row.put('Pipe_Class__c', '');
                            }

                            totalAmount += lineTotal;
                            lineItems.add(row);
                        }
                    }
                }

                // ── NEW: Crash barrier beam sections ──────────────────────
                buildBeamSections();
                buildTCFields();

            } catch (Exception e) {
                System.debug('JSON Parse Error: ' + e.getMessage());
            }
        }
        // ==========================================
        // DYNAMIC PAYMENT TERMS LOGIC (UNIFIED)
        // ==========================================
        if (jsonData != null) {
            String templateName = jsonData.get('_Saved_Template_Name') != null ? String.valueOf(jsonData.get('_Saved_Template_Name')) : '';
            String termType = jsonData.get('tc_payment_terms_picklist') != null ? String.valueOf(jsonData.get('tc_payment_terms_picklist')).trim() : '';

            // ─── 1. CRASH BARRIER LOGIC ───────────────────────────────────────────
            if (templateName.containsIgnoreCase('Crash Barrier')) {
                
                String interestFreeDays = jsonData.get('tc_no_of_days_interest_free_credit') != null ? String.valueOf(jsonData.get('tc_no_of_days_interest_free_credit')).trim() : '0';
                
                if (termType.equalsIgnoreCase('Against Open credit')) {
                    dynamicPaymentTerms = 'Against Open credit ' + interestFreeDays + ' days.';
                } 
                else if (termType.equalsIgnoreCase('Against BG')) {
                    dynamicPaymentTerms = 'Against BG ' + interestFreeDays + ' days.';
                } 
                else if (termType.equalsIgnoreCase('Against LC')) {
                    String usancePeriod = jsonData.get('tc_usance_period') != null ? String.valueOf(jsonData.get('tc_usance_period')).trim() : '0';
                    dynamicPaymentTerms = 'Against LC ' + interestFreeDays + ' days (Usance ' + usancePeriod + ' days IFC).';
                }
                else if (termType.equalsIgnoreCase('Advance')) {
                    dynamicPaymentTerms = 'Advance days. 100% Advance before dispatch';
                }
                else if (String.isNotBlank(termType)) {
                    dynamicPaymentTerms = termType; 
                } 
                else {
                    dynamicPaymentTerms = '100% advance along with PI.'; 
                }
            }
            
            // ─── 2. SOLAR LOGIC ───────────────────────────────────────────────────
            // ─── 2. SOLAR LOGIC ───────────────────────────────────────────────────
            else {
                // 👉 THE FIX: Changed to look for 'tc_advance_payment'
                String advPctStr = jsonData.get('tc_advance_payment') != null ? 
                                   String.valueOf(jsonData.get('tc_advance_payment')).trim() : '30';
                
                Integer advPct = advPctStr.isNumeric() ? Integer.valueOf(advPctStr) : 30;
                Integer balPct = 100 - advPct; // 👉 Calculates the exact remaining balance!
                
                // 👉 ADDED <b> TAGS to make the percentages bold like your screenshot!
                String baseTerm = '<b>' + advPct + '%</b> Advance after issuance of Purchase order and Balance <b>' + balPct + '%</b> ';
                
                if (termType.equalsIgnoreCase('Against LC Before Dispatch')) {
                    String buyerDays = jsonData.get('tc_lc_buyer_interest_days') != null ? 
                                       String.valueOf(jsonData.get('tc_lc_buyer_interest_days')).trim() : '0';
                    String sellerDays = jsonData.get('tc_lc_seller_interest_days') != null ? String.valueOf(jsonData.get('tc_lc_seller_interest_days')).trim() : '0';
                    
                    dynamicPaymentTerms = baseTerm + 'Against LC Before Dispatch, Usance interest at Buyer\'s scope- ' + buyerDays + ' Days and Seller\'s scope- ' + sellerDays + ' Days.';
                } 
                else if (termType.equalsIgnoreCase('Before Dispatch')) {
                    dynamicPaymentTerms = baseTerm + 'Before Dispatch.';
                }
                else if (termType.equalsIgnoreCase('Against VFS')) {
                    String vfsDays = jsonData.get('tc_vfs_seller_interest') != null ? 
                                     String.valueOf(jsonData.get('tc_vfs_seller_interest')).trim() : '0';
                    dynamicPaymentTerms = baseTerm + 'Against VFS for - ' + vfsDays + ' Days.';
                } 
                else if (termType.equalsIgnoreCase('Against PDC')) {
                    String pdcDays = jsonData.get('tc_PDC_interest') != null ? 
                                     String.valueOf(jsonData.get('tc_PDC_interest')).trim() : '';
                                     
                    if (String.isNotBlank(pdcDays)) {
                        dynamicPaymentTerms = baseTerm + 'Against PDC for - ' + pdcDays + ' Days.';
                    } else {
                        dynamicPaymentTerms = baseTerm + 'Against PDC.';
                    }
                } 
                else if (termType.equalsIgnoreCase('Against Open Credit')) {
                    String openCreditDays = jsonData.get('tc_open_credit_days') != null ? 
                                            String.valueOf(jsonData.get('tc_open_credit_days')).trim() : '0';
                    dynamicPaymentTerms = baseTerm + 'Against Open Credit ' + openCreditDays + ' Days.';
                } 
                else {
                    dynamicPaymentTerms = '100% advance along with PI.'; // Default Fallback
                }
            }
        } else {
            dynamicPaymentTerms = '100% advance along with PI.';
        }
        if (jsonData != null) {
            Object solarConfigObj = jsonData.get('_solarStructureConfig');
            if (solarConfigObj != null) {
                Map<String, Object> solarConfig = (Map<String, Object>) solarConfigObj;
                unitOfMeasurement = String.valueOf(solarConfig.get('Unit_Of_Measurement__c'));
            } else {
                unitOfMeasurement = String.valueOf(jsonData.get('unit_of_measurement'));
            }
            if (String.isBlank(unitOfMeasurement) || unitOfMeasurement == 'null') {
                unitOfMeasurement = 'Weight'; // Default fallback
            }
            incoterms       = getStr('incoterms');
            tcSubjectLine   = getStr('tc_subject_line');
            tcAdvancePayment = getInt('tc_advance_payment');
            tcWarrantyMonths = getInt('tc_warranty_in_months');
            tcDeliveryDays  = getStr('tc_delivery_days');

            // Generate Subject Line Dynamically based on Solar Grid Materials
            if (String.isBlank(tcSubjectLine) || tcSubjectLine == 'Not Found') {
                List<String> materials = new List<String>();
                if (solarConfigObj != null) {
                    Map<String, Object> solarConfig = (Map<String, Object>) solarConfigObj;
                    List<Object> linesObj = (List<Object>) solarConfig.get('Lines');
                    if (linesObj != null) {
                        for (Object lineObj : linesObj) {
                            Map<String, Object> line = (Map<String, Object>) lineObj;
                            String mat = String.valueOf(line.get('Material__c'));
                            if (String.isNotBlank(mat) && !materials.contains(mat)) {
                                materials.add(mat);
                            }
                        }
                    }
                }
                if (!materials.isEmpty()) {
                    tcSubjectLine = 'RFQ for Supply of ' + String.join(materials, ', ');
                } else {
                    tcSubjectLine = 'RFQ for Supply of MMS';
                }
            }
        }
		// ==========================================
        // SOLAR SPECIFIC DATA EXTRACTION
        // ==========================================
        if (jsonData != null) {
            unitOfMeasurement = getStr('unit_of_measurement');
            if (String.isBlank(unitOfMeasurement) || unitOfMeasurement == 'null') {
                unitOfMeasurement = 'Weight';
            }
            
            micronThickness = getStr('c1_hdg_micron_thickness');
            if (String.isBlank(micronThickness) || micronThickness == 'null') {
                micronThickness = '85';
            }
            
            incoterms       = getStr('incoterms');
            tcSubjectLine   = getStr('tc_subject_line');
            tcAdvancePayment = getInt('tc_advance_payment');
            tcWarrantyMonths = getInt('tc_warranty_in_months');
            tcDeliveryDays  = getStr('tc_delivery_days');
        }

        // ── Existing: Safety net defaults (unchanged) ─────────────────────
        ensureKey('Contact_Person',           'Balindra Kushwaha');
        ensureKey('Contact_Number',           '8001611112');
        ensureKey('Email',                    'balindra.ssml@shyamsteel.industries');
        ensureKey('tc_offer_validity',        '2 days from the date of offer and further revalidation is subjected to our prior written confirmation.');
        ensureKey('tc_delivery_schedule',     'READY STOCK');
        ensureKey('tc_price_variation',       'Rates offered are variable.\nWe will try to complete the delivery within offered time.');
        ensureKey('tc_payment_terms',         '30% advance against P.O. & remaining on readiness of materials.');
        ensureKey('tc_transportation',        'INCLUDED');
        ensureKey('tc_vehicle_load',          '(+/-) 0.5% weight tolerance may be there in total vehicle load.');
        ensureKey('tc_tolerance',             'All dimensional tolerance like OD & Wall Thickness (+/-) shall be as per applicable IS specification.');
        ensureKey('tc_inspection',            'Inspection Charges & Expenses: Extra.');
        ensureKey('tc_pre_dispatch_inspection','Pre Dispatch Inspection at our plant');

        // PEB bank doc: runs last so quoteRef, todayDate, tcDeliveryDays and
        // validityDays are already resolved by the time it reads them.
        loadPebBankDocData();
        loadPebBuildingDescriptionData();
    }

    

    // ──────────────────────────────────────────────────────────────────────
    // NEW: Beam Section Builder
    // ──────────────────────────────────────────────────────────────────────
    private void buildBeamSections() {
        beamSections = new List<BeamSectionWrapper>();
        if (jsonData == null) return;

        Object crashConfigObj = jsonData.get('_crashBarrierConfig');
        if (crashConfigObj != null) {
            Map<String, Object> crashConfig = (Map<String, Object>) crashConfigObj;
            List<Object> rowsObj = (List<Object>) crashConfig.get('rows');
            if (rowsObj != null) {
                for (Object rObj : rowsObj) {
                    Map<String, Object> row = (Map<String, Object>) rObj;
                    String id = String.valueOf(row.get('id'));
                    if (id.startsWith('ct_w_') || id.startsWith('w_')) {
                        beamSections.add(buildWBeamSectionFromRow(row));
                    } else if (id.startsWith('ct_Thrie_') || id.startsWith('Thrie_')) {
                        beamSections.add(buildThrieBeamSectionFromRow(row));
                    }
                }
            }
            return;
        }

        String conType     = getStr('con_type_select');
        Boolean isWBeam    = conType != null && conType.contains('W');
        Boolean isThrie    = conType != null && conType.contains('Thrie');

        if (isWBeam) {
            List<String[]> types = new List<String[]>{
                new String[]{ 'w_SSSB', 'Single Side Single Beam (W-SSSB)' },
                new String[]{ 'w_SSDB', 'Single Side Double Beam (W-SSDB)'  },
                new String[]{ 'w_DSSB', 'Double Side Single Beam (W-DSSB)'  },
                new String[]{ 'w_DSDB', 'Double Side Double Beam (W-DSDB)'  }
            };
            for (String[] t : types) {
                Object flag = jsonData.get(t[0] + '_id');
                if (flag instanceof Boolean && (Boolean) flag) {
                    beamSections.add(buildWBeamSection(t[0], t[1]));
                }
            }
        } else if (isThrie) {
            List<String[]> types = new List<String[]>{
                new String[]{ 'Thrie_SSSB', 'Thrie Beam Single Side Single Beam' },
                new String[]{ 'Thrie_SSDB', 'Thrie Beam Single Side Double Beam' },
                new String[]{ 'Thrie_DSSB', 'Thrie Beam Double Side Single Beam' },
                new String[]{ 'Thrie_DSDB', 'Thrie Beam Double Side Double Beam' }
            };
            for (String[] t : types) {
                Object flag = jsonData.get(t[0]);
                if (flag instanceof Boolean && (Boolean) flag) {
                    beamSections.add(buildThrieBeamSection(t[0], t[1]));
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    private BeamSectionWrapper buildWBeamSection(String pfx, String beamLabel) {
        BeamSectionWrapper s = new BeamSectionWrapper();
        s.sectionTitle  = 'W BEAM CRASH TESTED — ' + beamLabel;
        s.hsnCode       = '73089090';
        s.unit          = 'MTR';

        String beamThk    = getStr(pfx + '_w_beam_beamThickness_input');
        String spacerThk  = getStr(pfx + '_w_beam_spacerThickness_input');
        String postThk    = getStr(pfx + '_w_beam_postThickness_input');
        String postHgt    = getStr(pfx + '_w_beam_postHeight_input');
        String spcLen     = getStr(pfx + '_w_beam_spaceLength_input');
        String roundBolt  = getStr(pfx + '_w_beam_roundBolt_input');
        String hexBolt    = getStr(pfx + '_w_beam_hexBolt_input');
        String zincCoat   = getStr(pfx + '_w_beam_zincCoating_input');
        String transOffer = getStr(pfx + '_w_beam_trans_in_offer_rm');

        s.quantity      = getDec(pfx + '_w_beam_quantity_rm');
        s.rate          = getDec(pfx + '_w_beam_rate_rm');
        s.amount        = (s.quantity * s.rate).setScale(2);
        s.unitPrice     = getDec(pfx + '_w_unit_price');
        s.unitCost      = getDec(pfx + '_w_unit_cost');
        s.transInOffer  = transOffer;
        s.showTransport = (String.isNotBlank(transOffer) && transOffer != 'Ex-works');

        Boolean hasSpacer = pfx.contains('SSSB') || pfx.contains('DSSB');

        s.rows = new List<DescRow>();
        Integer sl = 1;

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            '"Utkarsh" make <b>W Beam</b> Metal Crash Barrier <b>' + beamLabel + '</b> '
          + 'guard rail comprising of <b>' + beamThk + ' MM</b> having width of '
          + '<b>312 MM</b> and depth <b>83 MM</b> with hot dip galvanized '
          + '(' + zincCoat + ') having total length <b>4.318 MTR.</b> '
          + '(Effective length <b>4.0 MTR</b>).'
        ));

        if (hasSpacer) {
            s.rows.add(buildRow(sl++, false, null, null, null, null, null,
                'Spacer channel made of <b>"C" Section</b> having hot dip galvanized '
              + 'having size of <b>75 MM x 150 MM x 75 MM x '
              + spacerThk + ' MM</b> thick x <b>' + spcLen + ' MM</b> long.'
            ));
        }

        s.rows.add(buildRow(sl++, true, s.hsnCode, s.unit, s.quantity, s.rate, s.amount,
            'Post channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + postThk + ' MM</b> thick x <b>' + postHgt + ' MM</b> long '
          + 'with <b>2.0 MTR</b> center to center Post spacing.'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + roundBolt + ')</b> Button Type for fixing as per IS: 1367'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + hexBolt + ')</b> Hexagonal Type for fixing as per IS: 1367'
        ));

        return s;
    }

    // ──────────────────────────────────────────────────────────────────────
    private BeamSectionWrapper buildThrieBeamSection(String pfx, String beamLabel) {
        BeamSectionWrapper s = new BeamSectionWrapper();
        s.sectionTitle  = 'THRIE BEAM CRASH TESTED — ' + beamLabel;
        s.hsnCode       = '73089090';
        s.unit          = 'MTR';

        String beamThk    = getStr(pfx + '_beamThickness_input');
        String spacerThk  = getStr(pfx + '_spacerThickness_input');
        String postThk    = getStr(pfx + '_postThickness_input');
        String postHgt    = getStr(pfx + '_postHeight_input');
        String spcLen     = getStr(pfx + '_spaceLength_input');
        String roundBolt  = getStr(pfx + '_roundBolt_input');
        String hexBolt    = getStr(pfx + '_hexBolt_input');
        String zincCoat   = getStr(pfx + '_zincCoating_input');
        String transOffer = getStr(pfx + '_trans_in_offer_rm');

        s.quantity      = getDec(pfx + '_quantity_rm');
        s.rate          = getDec(pfx + '_rate_rm');
        s.amount        = (s.quantity * s.rate).setScale(2);
        s.unitPrice     = getDec(pfx + '_unit_price');
        s.unitCost      = getDec(pfx + '_unit_cost');
        s.transInOffer  = transOffer;
        s.showTransport = (String.isNotBlank(transOffer) && transOffer != 'Ex-works');

        s.rows = new List<DescRow>();
        Integer sl = 1;

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            '"Utkarsh" make <b>Thrie Beam</b> Metal Crash Barrier <b>' + beamLabel + '</b> '
          + 'guard rail comprising of <b>' + beamThk + ' MM</b> having width of '
          + '<b>425 MM</b> and depth <b>83 MM</b> with hot dip galvanized '
          + '(' + zincCoat + ') having total length <b>4.318 MTR.</b> '
          + '(Effective length <b>4.0 MTR</b>).'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Spacer channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + spacerThk + ' MM</b> thick x <b>' + spcLen + ' MM</b> long.'
        ));

        s.rows.add(buildRow(sl++, true, s.hsnCode, s.unit, s.quantity, s.rate, s.amount,
            'Post channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + postThk + ' MM</b> thick x <b>' + postHgt + ' MM</b> long '
          + 'with <b>2.0 MTR</b> center to center Post spacing.'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + roundBolt + ')</b> Button Type for fixing as per IS: 1367'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + hexBolt + ')</b> Hexagonal Type for fixing as per IS: 1367'
        ));

        return s;
    }

    // ──────────────────────────────────────────────────────────────────────
    private BeamSectionWrapper buildWBeamSectionFromRow(Map<String, Object> row) {
        BeamSectionWrapper s = new BeamSectionWrapper();
        s.sectionTitle  = 'W BEAM CRASH TESTED — ' + String.valueOf(row.get('label'));
        s.hsnCode       = '73089090';
        s.unit          = 'MTR';

        String beamThk    = String.valueOf(row.get('beamThickness'));
        String spacerThk  = String.valueOf(row.get('spacerThickness'));
        String postThk    = String.valueOf(row.get('postThickness'));
        String postHgt    = String.valueOf(row.get('postHeight'));
        String spcLen     = String.valueOf(row.get('spaceLength'));
        String roundBolt  = String.valueOf(row.get('roundBolt'));
        String hexBolt    = String.valueOf(row.get('hexBolt'));
        String zincCoat   = String.valueOf(row.get('zincCoating'));
        String transOffer = String.valueOf(row.get('transInOffer'));

        s.quantity      = getSafeDecimal(row.get('quantityRm'));
        s.rate          = getSafeDecimal(row.get('rateRm'));
        s.amount        = (s.quantity * s.rate).setScale(2);
        s.unitPrice     = getSafeDecimal(row.get('unitPrice'));
        s.unitCost      = getSafeDecimal(row.get('unitCost'));
        s.transInOffer  = transOffer;
        s.showTransport = (String.isNotBlank(transOffer) && transOffer != 'Ex-works');

        Boolean hasSpacer = String.valueOf(row.get('id')).contains('SSSB') || String.valueOf(row.get('id')).contains('DSSB');

        s.rows = new List<DescRow>();
        Integer sl = 1;

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            '"Utkarsh" make <b>W Beam</b> Metal Crash Barrier <b>' + s.sectionTitle.replace('W BEAM CRASH TESTED — ', '') + '</b> '
          + 'guard rail comprising of <b>' + beamThk + ' MM</b> having width of '
          + '<b>312 MM</b> and depth <b>83 MM</b> with hot dip galvanized '
          + '(' + zincCoat + ') having total length <b>4.318 MTR.</b> '
          + '(Effective length <b>4.0 MTR</b>).'
        ));

        if (hasSpacer) {
            s.rows.add(buildRow(sl++, false, null, null, null, null, null,
                'Spacer channel made of <b>"C" Section</b> having hot dip galvanized '
              + 'having size of <b>75 MM x 150 MM x 75 MM x '
              + spacerThk + ' MM</b> thick x <b>' + spcLen + ' MM</b> long.'
            ));
        }

        s.rows.add(buildRow(sl++, true, s.hsnCode, s.unit, s.quantity, s.rate, s.amount,
            'Post channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + postThk + ' MM</b> thick x <b>' + postHgt + ' MM</b> long '
          + 'with <b>2.0 MTR</b> center to center Post spacing.'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + roundBolt + ')</b> Button Type for fixing as per IS: 1367'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + hexBolt + ')</b> Hexagonal Type for fixing as per IS: 1367'
        ));

        return s;
    }

    private BeamSectionWrapper buildThrieBeamSectionFromRow(Map<String, Object> row) {
        BeamSectionWrapper s = new BeamSectionWrapper();
        s.sectionTitle  = 'THRIE BEAM CRASH TESTED — ' + String.valueOf(row.get('label'));
        s.hsnCode       = '73089090';
        s.unit          = 'MTR';

        String beamThk    = String.valueOf(row.get('beamThickness'));
        String spacerThk  = String.valueOf(row.get('spacerThickness'));
        String postThk    = String.valueOf(row.get('postThickness'));
        String postHgt    = String.valueOf(row.get('postHeight'));
        String spcLen     = String.valueOf(row.get('spaceLength'));
        String roundBolt  = String.valueOf(row.get('roundBolt'));
        String hexBolt    = String.valueOf(row.get('hexBolt'));
        String zincCoat   = String.valueOf(row.get('zincCoating'));
        String transOffer = String.valueOf(row.get('transInOffer'));

        s.quantity      = getSafeDecimal(row.get('quantityRm'));
        s.rate          = getSafeDecimal(row.get('rateRm'));
        s.amount        = (s.quantity * s.rate).setScale(2);
        s.unitPrice     = getSafeDecimal(row.get('unitPrice'));
        s.unitCost      = getSafeDecimal(row.get('unitCost'));
        s.transInOffer  = transOffer;
        s.showTransport = (String.isNotBlank(transOffer) && transOffer != 'Ex-works');

        s.rows = new List<DescRow>();
        Integer sl = 1;

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            '"Utkarsh" make <b>Thrie Beam</b> Metal Crash Barrier <b>' + s.sectionTitle.replace('THRIE BEAM CRASH TESTED — ', '') + '</b> '
          + 'guard rail comprising of <b>' + beamThk + ' MM</b> having width of '
          + '<b>425 MM</b> and depth <b>83 MM</b> with hot dip galvanized '
          + '(' + zincCoat + ') having total length <b>4.318 MTR.</b> '
          + '(Effective length <b>4.0 MTR</b>).'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Spacer channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + spacerThk + ' MM</b> thick x <b>' + spcLen + ' MM</b> long.'
        ));

        s.rows.add(buildRow(sl++, true, s.hsnCode, s.unit, s.quantity, s.rate, s.amount,
            'Post channel made of <b>"C" Section</b> having hot dip galvanized '
          + 'having size of <b>75 MM x 150 MM x 75 MM x '
          + postThk + ' MM</b> thick x <b>' + postHgt + ' MM</b> long '
          + 'with <b>2.0 MTR</b> center to center Post spacing.'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + roundBolt + ')</b> Button Type for fixing as per IS: 1367'
        ));

        s.rows.add(buildRow(sl++, false, null, null, null, null, null,
            'Required Fasteners <b>(' + hexBolt + ')</b> Hexagonal Type for fixing as per IS: 1367'
        ));

        return s;
    }

    // ──────────────────────────────────────────────────────────────────────
    private DescRow buildRow(Integer sl, Boolean hasAmt,
                              String hsn, String unit,
                              Decimal qty, Decimal rate, Decimal amt,
                              String itemDesc) {
        DescRow r     = new DescRow();
        r.slNo        = String.valueOf(sl);
        r.description = itemDesc;
        r.hasAmount   = hasAmt;
        r.hsnCode     = hsn;
        r.unit        = unit;
        r.qty         = qty;
        r.rate        = rate;
        r.amount      = amt;
        return r;
    }

    // ──────────────────────────────────────────────────────────────────────
    // NEW: T&C Fields for Crash Barrier
    // ──────────────────────────────────────────────────────────────────────
    private void buildTCFields() {
        freightIncoterms   = getStr('freight_incoterms');
        validityDays       = getInt('tc_validity_days');
        paymentTerms       = getStr('tc_payment_terms_picklist');
        noOfDaysIFC        = getInt('tc_no_of_days_interest_free_credit');
        usancePeriod       = getInt('tc_usance_period');
        tcSpecialNote      = getStr('tc_special_note');

        // 👉 CALCULATE TOTAL BULK FREIGHT FOR THE VF PAGE
        fullVehicleFreight = getDec('w_SSSB_w_beam_full_Vehicle_freight')
                           + getDec('w_SSDB_w_beam_full_Vehicle_freight')
                           + getDec('w_DSSB_w_beam_full_Vehicle_freight')
                           + getDec('w_DSDB_w_beam_full_Vehicle_freight')
                           + getDec('Thrie_SSSB_full_Vehicle_freight')
                           + getDec('tb_alka_fvf')
                           + getDec('tb_natrax_fvf')
                           + getDec('wb_trans_fvf')
                           + getDec('wb_alka_fvf')
                           + getDec('wb_natrax_fvf')
                           + getDec('ns_thrie_beam_section_full_Vehicle_freight')
                           + getDec('ns_w_beam_section_full_Vehicle_freight')
                           + getDec('rlw_non_graded_full_Vehicle_freight')
                           + getDec('rlw_full_Vehicle_freight');

        // ==========================================
        // DYNAMIC FREIGHT TERM LOGIC
        // ==========================================
        if (freightIncoterms != null && freightIncoterms.equalsIgnoreCase('F.O.R (Freight on Road)')) {
            // Check if the Shipping Address checkbox is checked
            Boolean hasShipping = jsonData.get('has_transportation_address') != null 
                                  && Boolean.valueOf(jsonData.get('has_transportation_address'));
            
            // Grab the correct fields (Shipping vs Billing)
            String street = hasShipping ? getStr('sa_street')   : getStr('ba_street');
            String city   = hasShipping ? getStr('sa_city')     : getStr('ba_city');
            String state  = hasShipping ? getStr('sa_state')    : getStr('ba_state');
            String zip    = hasShipping ? getStr('sa_zip_code') : getStr('ba_zip_code');

            // Build the address cleanly (skipping empty fields or "Not Found" defaults)
            List<String> addrParts = new List<String>();
            if (String.isNotBlank(street) && street != 'Not Found' && !street.contains('@@')) addrParts.add(street);
            if (String.isNotBlank(city) && city != 'Not Found' && !city.contains('@@')) addrParts.add(city);
            if (String.isNotBlank(state) && state != 'Not Found' && !state.contains('@@')) addrParts.add(state);
            
            String fullAddress = String.join(addrParts, ', ');
            if (String.isNotBlank(zip) && zip != 'Not Found' && !zip.contains('@@')) {
                fullAddress += ', PINCODE - ' + zip;
            }
            
            // Format it cleanly for the sentence (removes .00 if it's a flat number)
            String bulkString = String.valueOf(fullVehicleFreight);
            if (bulkString.endsWith('.00')) {
                bulkString = bulkString.replace('.00', '');
            }
            
            // Set the final dynamic sentence
            dynamicFreightTerm = 'The rates Quoted are on F.O.R destination basis with transportation Bulk (' + bulkString + ') and are inclusive of any transportation and freight charges till ' + fullAddress + '.';
        } else {
            // Fallback for Ex-works
            dynamicFreightTerm = 'The rates are on Ex - works basis.';
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Existing: ensureKey (unchanged)
    // ──────────────────────────────────────────────────────────────────────
    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key)
                || jsonData.get(key) == null
                || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }
    // ==========================================
    // SOLAR STRUCTURE PDF LOGIC
    // ==========================================
    
    // Safely extracts data from the JSON grid to build the PDF Table
    public List<SolarItem> getSolarItems() {
        List<SolarItem> items = new List<SolarItem>();
        if (jsonData == null) return items;

        Object solarConfigObj = jsonData.get('_solarStructureConfig');
        if (solarConfigObj == null) return items;

        Map<String, Object> solarConfig = (Map<String, Object>) solarConfigObj;
        List<Object> linesObj = (List<Object>) solarConfig.get('Lines');
        if (linesObj == null) return items;

        String uom = String.valueOf(solarConfig.get('Unit_Of_Measurement__c'));
        Boolean isPCs = (uom == 'PCs' || uom == 'pcs' || uom == 'Pcs');

        for (Object lineObj : linesObj) {
            Map<String, Object> line = (Map<String, Object>) lineObj;
            
            SolarItem item = new SolarItem();
            item.material = String.valueOf(line.get('Material__c'));
            item.grade = String.valueOf(line.get('Material_Grade__c'));
            item.thickness = String.valueOf(line.get('Thickness__c'));
            item.micron = String.valueOf(line.get('Micron_Thickness__c'));
            if (String.isBlank(item.micron) || item.micron == 'null') item.micron = '-';
            
            item.unitWeight = getSafeDecimal(line.get('Unit_Weight__c'));
            
            Decimal qty = getSafeDecimal(line.get('Quantity__c'));
            item.quantity = qty > 0 ? qty : 1; 
            
            item.weight = getSafeDecimal(line.get('Total_Weight__c'));
            item.unitCost = getSafeDecimal(line.get('Unit_Price__c'));
            item.rate = item.unitCost;
            
            String category = String.valueOf(line.get('Category__c'));
            item.isHdg = (category == 'HDG MMS Structure');
            
            // Recalculate amount dynamically
            if (isPCs) {
                item.amount = item.quantity * item.rate;
            } else {
                item.amount = item.weight * item.rate;
            }
            
            items.add(item);
        }
        
        return items;
    }

    // Calculates the Subtotal directly from the valid items
    public Decimal getSubTotal() {
        Decimal total = 0;
        for (SolarItem item : getSolarItems()) {
            total += (item.amount != null ? item.amount : 0);
        }
        return total;
    }

    // Sums up all the freight charges across both grids
    public Decimal getTotalFreight() {
        Decimal totalF = 0;
        if (jsonData == null) return 0;
        
        Object solarConfigObj = jsonData.get('_solarStructureConfig');
        if (solarConfigObj != null) {
            Map<String, Object> solarConfig = (Map<String, Object>) solarConfigObj;
            List<Object> linesObj = (List<Object>) solarConfig.get('Lines');
            if (linesObj != null) {
                for (Object lineObj : linesObj) {
                    Map<String, Object> line = (Map<String, Object>) lineObj;
                    totalF += getSafeDecimal(line.get('Freight__c'));
                }
            }
        }
        
        return totalF;
    }

    // Helper Method to prevent Null Pointer Exceptions on empty grid boxes
    private Decimal getSafeDecimal(Object val) {
        if (val == null || String.valueOf(val) == '') return 0;
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return 0;
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // NEW: JSON helper methods (operate on the shared jsonData map)
    // ──────────────────────────────────────────────────────────────────────
    private String getStr(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        return v != null ? String.valueOf(v) : '';
    }

    private Decimal getDec(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        if (v == null || String.valueOf(v).trim() == '') return 0;
        try { return Decimal.valueOf(String.valueOf(v)); }
        catch (Exception e) { return 0; }
    }

    private Integer getInt(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        if (v == null || String.valueOf(v).trim() == '') return 0;
        try { return Integer.valueOf(String.valueOf(v)); }
        catch (Exception e) { return 0; }
    }

    // ──────────────────────────────────────────────────────────────────────
    // NEW: Wrapper Classes
    // ──────────────────────────────────────────────────────────────────────
    public class BeamSectionWrapper {
        public String        sectionTitle  { get; set; }
        public String        hsnCode       { get; set; }
        public String        unit          { get; set; }
        public Decimal       quantity      { get; set; }
        public Decimal       rate          { get; set; }
        public Decimal       amount        { get; set; }
        public Decimal       unitPrice     { get; set; }
        public Decimal       unitCost      { get; set; }
        public String        transInOffer  { get; set; }
        public Boolean       showTransport { get; set; }
        public List<DescRow> rows          { get; set; }
    }

    public class DescRow {
        public String  slNo        { get; set; }
        public String  description { get; set; }
        public Boolean hasAmount   { get; set; }
        public String  hsnCode     { get; set; }
        public String  unit        { get; set; }
        public Decimal qty         { get; set; }
        public Decimal rate        { get; set; }
        public Decimal amount      { get; set; }
    }
    public class SolarItem {
        public String  material    { get; set; }
        public String  grade       { get; set; }
        public String  thickness   { get; set; }
        public String  micron      { get; set; }
        public String  description { get; set; } // cN_hdg/galv_material_description
        public Boolean isHdg       { get; set; } // true = HDG, false = Galvalume/Black
        public Decimal weight      { get; set; }
        public Decimal rate        { get; set; }
        public Decimal amount      { get; set; }
        public Decimal quantity    { get; set; }
        public Decimal unitWeight  { get; set; }
        public Decimal unitCost    { get; set; } // 👉 ADDED THIS
    }

    // ── NEW: Embed static resource as base64 data URI (needed for Word) ──
    public String getBase64FromStaticResource(String resourceName) {
        try {
            StaticResource sr = [SELECT Body, ContentType
                                 FROM   StaticResource
                                 WHERE  Name = :resourceName
                                 LIMIT  1];
            return 'data:' + sr.ContentType + ';base64,'
                   + EncodingUtil.base64Encode(sr.Body);
        } catch (Exception e) {
            System.debug('Static resource not found: ' + resourceName);
            return '';
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PEB MODULE — data behind GenerateBankDoc.page (30th July 2026)
    // Supply price, tentative weight, accessories and buyout items all come
    // from the PEB Price Calculator's saved estimate on
    // Opportunity.Price_Calculation_JSON__c. Every value is defaulted FIRST,
    // so a quote with no saved calculation still renders the whole offer -
    // showing 0/- and the "no accessories selected" fallback, which is the
    // signal that the calculator was never run. Purely additive: no existing
    // property, query field or method was changed.
    // Deepanjan (30th July 2026)
    // ══════════════════════════════════════════════════════════════════════
    private void loadPebBankDocData() {
        pebAccessories     = new List<PebRow>();
        buyoutItems        = new List<PebRow>();
        supplyPriceBasic   = '0';
        supplyPriceGst     = '0';
        supplyPriceWithGst = '0';
        tentativeWeightMt  = '0';
        termsRef           = String.isNotBlank(quoteRef)  ? quoteRef  : '';
        termsDate          = String.isNotBlank(todayDate) ? todayDate : Date.today().format();
        deliverySchedule   = String.isNotBlank(tcDeliveryDays) ? tcDeliveryDays : '';
        pebvalidity        = (validityDays != null && validityDays > 0)
                           ? String.valueOf(validityDays) + ' days'
                           : '';
        // Both halves of the Delivery Schedule sentence default to the value
        // that single merge field used to supply, so a quote saved before this
        // change prints exactly what it printed yesterday.
        consignmentPeriod  = deliverySchedule;
        erectionPeriod     = deliverySchedule;
        showErectionTerms  = false;
        setPebClauseNumbers();

        // The PEB payload moved out of Opportunity.Price_Calculation_JSON__c into the
        // quote's own JSON, nested one level down under _pebPayload. jsonData is the
        // already-parsed Quote_Value__c from the constructor, so nothing new is queried.
        // The Opportunity field stays as a fallback so quotes saved before the move
        // still print. Deepanjan (5th August 2026)
        String calcJson;
        if (jsonData != null && jsonData.get('_pebPayload') instanceof Map<String, Object>) {
            calcJson = JSON.serialize(jsonData.get('_pebPayload'));
        }
        if (String.isBlank(calcJson) && quoteRecord != null && quoteRecord.Opportunity != null) {
            calcJson = quoteRecord.Opportunity.Price_Calculation_JSON__c;
        }
        if (String.isBlank(calcJson)) return;

        try {
            Map<String, Object> calc =
                (Map<String, Object>) JSON.deserializeUntyped(calcJson);

            // E. SUPPLY PRICE + the Note's tentative weight
            if (calc.get('totals') instanceof Map<String, Object>) {
                Map<String, Object> t = (Map<String, Object>) calc.get('totals');
                supplyPriceBasic   = fmtSupply(pebDec(t.get('totalWithMargin')));
                supplyPriceGst     = fmtSupply(pebDec(t.get('gstRs')));
                supplyPriceWithGst = fmtSupply(pebDec(t.get('grandTotal')));
                // sectionATotalWeight is stored in Kg; the Note quotes whole MT
                tentativeWeightMt  = String.valueOf(
                    (pebDec(t.get('sectionATotalWeight')) / 1000)
                        .setScale(0, RoundingMode.HALF_UP));
            }

            // the letterhead date prefers the calculator's own stamp
            if (calc.get('generatedDate') != null
                && String.isNotBlank(String.valueOf(calc.get('generatedDate')))) {
                termsDate = String.valueOf(calc.get('generatedDate'));
            }

            pebAccessories = buildPebRows(calc.get('accessories'));
            buyoutItems    = buildPebRows(calc.get('buyouts'));

            // Periods typed on the calculator's Summary screen. Each one
            // overrides its default ONLY when the user actually typed
            // something, so a blank box never wipes the old wording.
            if (calc.get('paymentTerms') instanceof Map<String, Object>) {
                Map<String, Object> pt =
                    (Map<String, Object>) calc.get('paymentTerms');
                String cp = pebStr(pt.get('consignmentPeriod'));
                String ep = pebStr(pt.get('erectionPeriod'));
                String vl = pebStr(pt.get('validity'));
                if (String.isNotBlank(cp)) consignmentPeriod = cp;
                if (String.isNotBlank(ep)) erectionPeriod    = ep;
                if (String.isNotBlank(vl)) pebvalidity       = vl;
            }

            // The Erection Payment Terms clause prints only when the estimate
            // actually carries an erection cost under D. Other Cost.
            showErectionTerms = hasErectionCost(calc.get('otherCost'));
            setPebClauseNumbers();

        } catch (Exception e) {
            System.debug('PEB bank-doc JSON parse error: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PEB Dynamic Building Description Parser Integration
    // Reads _buildingDescription from Quote_Value__c (or nested in _pebPayload)
    // to dynamically populate geometry, roof/wall specs, accessories, buyouts,
    // and technical notes on GenerateBankDoc.page without modifying existing calculations.
    // ══════════════════════════════════════════════════════════════════════
    private void loadPebBuildingDescriptionData() {
        buildingGeometry        = new Map<String, Object>();
        buildingRoof            = new Map<String, Object>();
        buildingWall            = new Map<String, Object>();
        buildingTechNotes       = new List<String>();
        buildingMaterialSpecs   = new List<String>();
        buildingClientName       = '';
        buildingProjectLocation  = '';
        buildingName             = '';
        effectiveBuyerName       = '';
        effectiveProjectLocation = '';
        effectiveBuildingName    = '';
        pebSubjectLine           = '';

        // Default specifications (used if no Building Description uploaded)
        buildingFrameType       = 'Utkarsh Multi Span – 1';
        buildingWidth           = '38.230';
        buildingLength          = '127.646';
        buildingHeight          = '10.0';
        buildingSlope           = '1: 10';
        buildingBaySpacing      = '1 @ 7.711, 1 @ 7.5, 2 @ 7.479, 1 @ 7.437, 12 @ 7.5';

        buildingRoofProfile     = 'UIL Trapezoidal Profiled Screw-down Sheeting';
        buildingRoofThickness   = '0.47 mm';
        buildingRoofMaterial    = 'Bare Galvalume – AZ-150 (Make-TBSL)';
        buildingRoofEave        = 'UIL Standard Eave Gutter';

        buildingWallProfile     = 'UIL Trapezoidal Profiled Screw-down Sheeting';
        buildingWallThickness   = '0.50 mm';
        buildingWallMaterial    = 'Color Coated Galvalume';
        buildingWallDownspouts  = 'uPVC Down-spouts of Utkarsh Make';
        buildingWallBrickHeight = '3.0 m brick wall all around';

        // Summary defaults
        buildingMainArea           = '4915';
        buildingCanopyArea         = '160';
        buildingMezzanineArea      = '770';
        buildingGrossArea          = '5845';

        // Geometry extras defaults
        buildingFrameTypeRemark    = 'Rigid Frame';
        buildingWidthModule        = '19.115, 19.115';
        buildingEndWallBay         = '6 @ 6.371';
        buildingBracingRoof        = 'Cross bracing (Rod)';
        buildingBracingWall        = 'Cross bracing (TUBE/PIPE)';
        buildingSurfacePrepPrimary = 'Shot Blasting + 1 coat of Epoxy Primer + 2 coats of Epoxy Paint, Total DFT – 90-100 micron + Touch up at site. Make – Asian Paints / Berger. Colour – Light Smoke Grey.';
        buildingSurfacePrepSecondary = '120 GSM';

        // Codes & Loads defaults
        buildingDesignCode         = 'AISC 2010 / MBMA';
        buildingWindSpeed          = '47';
        buildingSeismicZone        = 'III';
        buildingLiveLoad           = '0.57';
        buildingDeadLoad           = '0.15';

        // Additions defaults
        hasCanopy                  = true;
        buildingCanopyDesc         = '3.0 m (w) x 14.958 m (l) x 7.0 m Clear Height (FSW) & 3.0 m x 38.230 m (REW)';
        hasCrane                   = true;
        buildingCraneDesc          = '10 T @ 2 Nos. & 5 T @ 1 No. E.O.T. Pendant Operated, Top of Bracket 7.0 m';
        hasMezzanine               = true;
        buildingMezzanineDesc      = '14.911 m (w) x 25.485 m (l), Area: 385 sq mtr per floor, DL: 300 kg/sqm, LL: 500 kg/sqm, 0.8 mm GI Deck Sheet';
        buildingRoofMonitorDesc    = '1.2 m Throat Width x 1.0 m Height x 105.0 m Length';
        showRoofMonitorSection     = true;
        paramTableRows             = new List<ParamTableRow>();
        docSections                = new List<DocSection>();

        try {
    Map<String, Object> bd = null;

    // 1. PRIMARY SOURCE: Read from the Quote's own saved snapshot (Quote_Value__c / jsonData)
    // This ensures that new document uploads or recalculations on the Opportunity
    // never alter an existing, historical Quote document.
    if (jsonData != null) {
        if (jsonData.containsKey('_buildingDescription') && jsonData.get('_buildingDescription') instanceof Map<String, Object>) {
            bd = (Map<String, Object>) jsonData.get('_buildingDescription');
        } else if (jsonData.containsKey('_pebPayload') && jsonData.get('_pebPayload') instanceof Map<String, Object>) {
            Map<String, Object> p = (Map<String, Object>) jsonData.get('_pebPayload');
            if (p.containsKey('_buildingDescription') && p.get('_buildingDescription') instanceof Map<String, Object>) {
                bd = (Map<String, Object>) p.get('_buildingDescription');
            }
        }
    }

    // 2. FALLBACK: If not saved on the Quote yet, read from the Opportunity's JSON
    if (bd == null && quoteRecord != null && quoteRecord.Opportunity != null) {
        String oppJson = quoteRecord.Opportunity.Price_Calculation_JSON__c; 
        if (String.isNotBlank(oppJson)) {
            try {
                Map<String, Object> oppData = (Map<String, Object>) JSON.deserializeUntyped(oppJson);
                if (oppData.containsKey('_buildingDescription') && oppData.get('_buildingDescription') instanceof Map<String, Object>) {
                    bd = (Map<String, Object>) oppData.get('_buildingDescription');
                }
            } catch (Exception e) {
                System.debug('Error parsing Building Description from Opportunity JSON: ' + e.getMessage());
            }
        }
    }

    // 3. MAP THE DATA (Whether it came from the Opp or the Quote)
    if (bd != null) {
        if (bd.get('geometry') instanceof Map<String, Object>) {
            buildingGeometry = (Map<String, Object>) bd.get('geometry');
            if (String.isNotBlank(pebStr(buildingGeometry.get('frameType')))) {
                buildingFrameType = pebStr(buildingGeometry.get('frameType'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('width')))) {
                buildingWidth = pebStr(buildingGeometry.get('width'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('length')))) {
                buildingLength = pebStr(buildingGeometry.get('length'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('height')))) {
                buildingHeight = pebStr(buildingGeometry.get('height'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('slope')))) {
                buildingSlope = pebStr(buildingGeometry.get('slope'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('baySpacing')))) {
                buildingBaySpacing = pebStr(buildingGeometry.get('baySpacing'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('widthModule')))) {
                buildingWidthModule = pebStr(buildingGeometry.get('widthModule'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('endWallBaySpacing')))) {
                buildingEndWallBay = pebStr(buildingGeometry.get('endWallBaySpacing'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('bracingRoof')))) {
                buildingBracingRoof = pebStr(buildingGeometry.get('bracingRoof'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('bracingWall')))) {
                buildingBracingWall = pebStr(buildingGeometry.get('bracingWall'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('surfacePrepPrimary')))) {
                buildingSurfacePrepPrimary = pebStr(buildingGeometry.get('surfacePrepPrimary'));
            }
            if (String.isNotBlank(pebStr(buildingGeometry.get('surfacePrepSecondary')))) {
                buildingSurfacePrepSecondary = pebStr(buildingGeometry.get('surfacePrepSecondary'));
            }
        }
        if (bd.get('roofSystem') instanceof Map<String, Object>) {
            buildingRoof = (Map<String, Object>) bd.get('roofSystem');
            if (String.isNotBlank(pebStr(buildingRoof.get('sheetingProfile')))) {
                buildingRoofProfile = pebStr(buildingRoof.get('sheetingProfile'));
            }
            if (String.isNotBlank(pebStr(buildingRoof.get('thickness')))) {
                buildingRoofThickness = pebStr(buildingRoof.get('thickness'));
            }
            if (String.isNotBlank(pebStr(buildingRoof.get('material')))) {
                buildingRoofMaterial = pebStr(buildingRoof.get('material'));
            }
            if (String.isNotBlank(pebStr(buildingRoof.get('eaveCondition')))) {
                buildingRoofEave = pebStr(buildingRoof.get('eaveCondition'));
            }
        }
        if (bd.get('wallSystem') instanceof Map<String, Object>) {
            buildingWall = (Map<String, Object>) bd.get('wallSystem');
            if (String.isNotBlank(pebStr(buildingWall.get('claddingProfile')))) {
                buildingWallProfile = pebStr(buildingWall.get('claddingProfile'));
            }
            if (String.isNotBlank(pebStr(buildingWall.get('thickness')))) {
                buildingWallThickness = pebStr(buildingWall.get('thickness'));
            }
            if (String.isNotBlank(pebStr(buildingWall.get('material')))) {
                buildingWallMaterial = pebStr(buildingWall.get('material'));
            }
            if (String.isNotBlank(pebStr(buildingWall.get('downspouts')))) {
                buildingWallDownspouts = pebStr(buildingWall.get('downspouts'));
            }
            if (String.isNotBlank(pebStr(buildingWall.get('brickWallHeight')))) {
                buildingWallBrickHeight = pebStr(buildingWall.get('brickWallHeight'));
            }
        }
        if (bd.get('clientInfo') instanceof Map<String, Object>) {
            Map<String, Object> ci = (Map<String, Object>) bd.get('clientInfo');
            if (String.isNotBlank(pebStr(ci.get('clientName')))) {
                buildingClientName = pebStr(ci.get('clientName'));
            } else if (String.isNotBlank(pebStr(ci.get('Client')))) {
                buildingClientName = pebStr(ci.get('Client'));
            }
            if (String.isNotBlank(pebStr(ci.get('projectLocation')))) {
                buildingProjectLocation = pebStr(ci.get('projectLocation'));
            } else if (String.isNotBlank(pebStr(ci.get('projectSite')))) {
                buildingProjectLocation = pebStr(ci.get('projectSite'));
            } else if (String.isNotBlank(pebStr(ci.get('Project Site')))) {
                buildingProjectLocation = pebStr(ci.get('Project Site'));
            } else if (String.isNotBlank(pebStr(ci.get('location')))) {
                buildingProjectLocation = pebStr(ci.get('location'));
            } else if (String.isNotBlank(pebStr(ci.get('site')))) {
                buildingProjectLocation = pebStr(ci.get('site'));
            }
            if (String.isNotBlank(pebStr(ci.get('buildingName')))) {
                buildingName = pebStr(ci.get('buildingName'));
            } else if (String.isNotBlank(pebStr(ci.get('Building Name')))) {
                buildingName = pebStr(ci.get('Building Name'));
            } else if (String.isNotBlank(pebStr(ci.get('buildingType')))) {
                buildingName = pebStr(ci.get('buildingType'));
            }
        }
        if (String.isBlank(buildingClientName) && bd.containsKey('Client')) {
            buildingClientName = pebStr(bd.get('Client'));
        }
        if (String.isBlank(buildingProjectLocation)) {
            if (bd.containsKey('Project Site')) {
                buildingProjectLocation = pebStr(bd.get('Project Site'));
            } else if (bd.containsKey('projectSite')) {
                buildingProjectLocation = pebStr(bd.get('projectSite'));
            } else if (bd.containsKey('projectLocation')) {
                buildingProjectLocation = pebStr(bd.get('projectLocation'));
            }
        }
        if (String.isBlank(buildingName)) {
            if (bd.containsKey('Building Name')) {
                buildingName = pebStr(bd.get('Building Name'));
            } else if (bd.containsKey('buildingName')) {
                buildingName = pebStr(bd.get('buildingName'));
            }
        }
        if (bd.get('technicalNotes') instanceof List<Object>) {
            for (Object no : (List<Object>) bd.get('technicalNotes')) {
                if (no != null && String.isNotBlank(String.valueOf(no))) {
                    buildingTechNotes.add(String.valueOf(no).trim());
                }
            }
        }
        if (bd.get('materialSpecs') instanceof List<Object>) {
            for (Object so : (List<Object>) bd.get('materialSpecs')) {
                if (so != null && String.isNotBlank(String.valueOf(so))) {
                    buildingMaterialSpecs.add(String.valueOf(so).trim());
                }
            }
        }
        if (bd.get('summary') instanceof Map<String, Object>) {
            Map<String, Object> sm = (Map<String, Object>) bd.get('summary');
            if (String.isNotBlank(pebStr(sm.get('mainBuildingArea')))) buildingMainArea = pebStr(sm.get('mainBuildingArea'));
            if (String.isNotBlank(pebStr(sm.get('canopyArea')))) buildingCanopyArea = pebStr(sm.get('canopyArea'));
            if (String.isNotBlank(pebStr(sm.get('mezzanineArea')))) buildingMezzanineArea = pebStr(sm.get('mezzanineArea'));
            if (String.isNotBlank(pebStr(sm.get('grossArea')))) buildingGrossArea = pebStr(sm.get('grossArea'));
        }
        if (bd.get('designCriteria') instanceof Map<String, Object>) {
            Map<String, Object> dc = (Map<String, Object>) bd.get('designCriteria');
            if (String.isNotBlank(pebStr(dc.get('designCode')))) buildingDesignCode = pebStr(dc.get('designCode'));
            if (String.isNotBlank(pebStr(dc.get('windSpeed')))) buildingWindSpeed = pebStr(dc.get('windSpeed'));
            if (String.isNotBlank(pebStr(dc.get('seismicZone')))) buildingSeismicZone = pebStr(dc.get('seismicZone'));
            if (String.isNotBlank(pebStr(dc.get('liveLoad')))) buildingLiveLoad = pebStr(dc.get('liveLoad'));
            if (String.isNotBlank(pebStr(dc.get('deadLoad')))) buildingDeadLoad = pebStr(dc.get('deadLoad'));
        }
        if (bd.get('additions') instanceof Map<String, Object>) {
            Map<String, Object> ad = (Map<String, Object>) bd.get('additions');
            if (ad.get('hasCanopy') != null) hasCanopy = Boolean.valueOf(ad.get('hasCanopy'));
            if (String.isNotBlank(pebStr(ad.get('canopyDesc')))) buildingCanopyDesc = pebStr(ad.get('canopyDesc'));
            if (ad.get('hasCrane') != null) hasCrane = Boolean.valueOf(ad.get('hasCrane'));
            if (String.isNotBlank(pebStr(ad.get('craneDesc')))) buildingCraneDesc = pebStr(ad.get('craneDesc'));
            if (ad.get('hasMezzanine') != null) hasMezzanine = Boolean.valueOf(ad.get('hasMezzanine'));
            if (String.isNotBlank(pebStr(ad.get('mezzanineDesc')))) buildingMezzanineDesc = pebStr(ad.get('mezzanineDesc'));
            if (String.isNotBlank(pebStr(ad.get('roofMonitorDesc')))) buildingRoofMonitorDesc = pebStr(ad.get('roofMonitorDesc'));
        }
        
        // C.1.5.5 Accessories & C.1.5.6 Buyout Items:
        // Building Description takes precedence over Price Calculation!
        List<PebRow> parsedAcc = buildPebRowsFromParsed(bd.get('accessories'));
        if (!parsedAcc.isEmpty()) {
            pebAccessories = parsedAcc;
        }
        List<PebRow> parsedBuy = buildPebRowsFromParsed(bd.get('buyouts'));
        if (!parsedBuy.isEmpty()) {
            buyoutItems = parsedBuy;
        }
        
        // ── paramTable: QRF Building Parameter table rows ──
        if (bd.get('paramTable') instanceof List<Object>) {
            List<Object> rawRows = (List<Object>) bd.get('paramTable');
            List<ParamTableRow> rows = new List<ParamTableRow>();
            for (Object o : rawRows) {
                if (!(o instanceof Map<String, Object>)) continue;
                Map<String, Object> m = (Map<String, Object>) o;
                ParamTableRow pr = new ParamTableRow();
                pr.slNo      = pebStr(m.get('slNo'));
                pr.parameter = pebStr(m.get('parameter'));
                pr.unit      = pebStr(m.get('unit'));
                pr.value     = pebStr(m.get('value'));
                pr.dataFrom  = pebStr(m.get('dataFrom'));
                pr.remark    = pebStr(m.get('remark'));
                pr.isHeader  = (m.get('isHeader') == true);
                rows.add(pr);
            }
            if (!rows.isEmpty()) paramTableRows = rows;
        }

        // ── docSections: Dynamic Building Description sections from (A) DESIGN CRITERIA to end ──
        if (bd.get('docSections') instanceof List<Object>) {
            List<DocSection> secs = buildDocSectionsFromParsed(bd.get('docSections'));
            if (!secs.isEmpty()) docSections = secs;
        } else if (bd.get('docSections') instanceof Map<String, Object>) {
            Map<String, Object> innerMap = (Map<String, Object>) bd.get('docSections');
            if (innerMap.get('docSections') instanceof List<Object>) {
                List<DocSection> secs = buildDocSectionsFromParsed(innerMap.get('docSections'));
                if (!secs.isEmpty()) docSections = secs;
            }
        }
        
            showRoofMonitorSection = String.isNotBlank(buildingRoofMonitorDesc);
            if (pebAccessories != null) {
                for (PebRow r : pebAccessories) {
                    if (r.description != null && r.description.containsIgnoreCase('Roof Monitor')) {
                        showRoofMonitorSection = false;
                        break;
                    }
                }
            }
        }

        // Secondary fallback to paramTableRows if any field is still blank
        if (paramTableRows != null && (String.isBlank(buildingClientName) || String.isBlank(buildingProjectLocation) || String.isBlank(buildingName))) {
            for (ParamTableRow ptr : paramTableRows) {
                if (ptr.parameter != null && String.isNotBlank(ptr.value)) {
                    String pLower = ptr.parameter.trim().toLowerCase();
                    String vLower = ptr.value.trim().toLowerCase();
                    if (String.isBlank(buildingClientName) && pLower == 'client' && !vLower.startsWith('project') && !vLower.startsWith('building')) {
                        buildingClientName = ptr.value.trim();
                    } else if (String.isBlank(buildingProjectLocation) && (pLower == 'project site' || pLower == 'project location') && !vLower.startsWith('building') && !vLower.startsWith('client')) {
                        buildingProjectLocation = ptr.value.trim();
                    } else if (String.isBlank(buildingName) && (pLower == 'building name' || pLower == 'building type') && !vLower.startsWith('client') && !vLower.startsWith('project')) {
                        buildingName = ptr.value.trim();
                    }
                }
            }
        }

        // ── RESOLVE CLIENT, LOCATION & BUILDING NAME DYNAMICS ──
        // 1. Client / Buyer: Primary is buildingClientName; fallback is quoteRecord.Account.Name
        if (String.isNotBlank(buildingClientName)) {
            String cLower = buildingClientName.trim().toLowerCase();
            if (cLower.startsWith('project') || cLower.startsWith('building') || cLower == 'client') {
                buildingClientName = '';
            }
        }
        String rawBuyer = '';
        if (String.isNotBlank(buildingClientName)) {
            rawBuyer = buildingClientName.trim();
        } else if (quoteRecord != null && quoteRecord.Account != null && String.isNotBlank(quoteRecord.Account.Name)) {
            rawBuyer = quoteRecord.Account.Name.trim();
        }

        if (String.isNotBlank(rawBuyer)) {
            if (rawBuyer.toLowerCase().startsWith('m/s.') || rawBuyer.toLowerCase().startsWith('m/s ') || rawBuyer.toLowerCase().startsWith('m/s')) {
                effectiveBuyerName = rawBuyer;
            } else {
                effectiveBuyerName = 'M/s. ' + rawBuyer;
            }
        } else {
            effectiveBuyerName = '';
        }

        // 2. Project Site / Location: Primary is buildingProjectLocation; fallback 1: Opp Address Book; fallback 2: Account Address Book; fallback 3: empty
        if (String.isNotBlank(buildingProjectLocation)) {
            String locLower = buildingProjectLocation.trim().toLowerCase();
            if (locLower.startsWith('building') || locLower.startsWith('client') || locLower.startsWith('project') 
                || locLower == 'site' || locLower == 'location' 
                || locLower.startsWith('opening') || locLower.startsWith('description') 
                || locLower.startsWith('dimension') || locLower == 'details' 
                || locLower == 'remarks' || locLower == 'soffit' || locLower == 'deck') {
                buildingProjectLocation = '';
            }
        }

        if (String.isNotBlank(buildingProjectLocation)) {
            effectiveProjectLocation = buildingProjectLocation.trim();
        } else {
            effectiveProjectLocation = resolveAddressBookLocation();
        }

        // 3. Building Name: Primary is buildingName; fallback is empty
        if (String.isNotBlank(buildingName)) {
            String bLower = buildingName.trim().toLowerCase();
            if (bLower.startsWith('client') || bLower.startsWith('project') || bLower == 'building name') {
                buildingName = '';
            }
        }
        effectiveBuildingName = String.isNotBlank(buildingName) ? buildingName.trim() : '';

        // 4. Clean Subject Line (taking zero space/gaps if empty)
        String subj = 'Sub: Offer for design, manufacture and supply';
        if (String.isNotBlank(effectiveBuildingName)) {
            subj += ' of ' + effectiveBuildingName;
        }
        if (String.isNotBlank(effectiveProjectLocation)) {
            subj += ' at ' + effectiveProjectLocation;
        }
        subj += '.';
        pebSubjectLine = subj;
    } catch (Exception e) {
        System.debug('PEB bank-doc building description parse error: ' + e.getMessage());
    }
    }

    private String resolveAddressBookLocation() {
        if (quoteRecord != null && quoteRecord.OpportunityId != null) {
            List<Address_Book__c> oppBooks = [
                SELECT Id, Street__c, City__c, State__c, PIN__c, Country__c, Primary_Address__c
                FROM Address_Book__c
                WHERE Opportunity__c = :quoteRecord.OpportunityId
                ORDER BY CreatedDate ASC
            ];
            if (!oppBooks.isEmpty()) {
                Address_Book__c bestOpp = pickBestAddressBook(oppBooks);
                String formatted = formatAddressBookRecord(bestOpp);
                if (String.isNotBlank(formatted)) {
                    return formatted;
                }
            }
        }
        if (quoteRecord != null && quoteRecord.AccountId != null) {
            List<Address_Book__c> accBooks = [
                SELECT Id, Street__c, City__c, State__c, PIN__c, Country__c, Primary_Address__c
                FROM Address_Book__c
                WHERE Account__c = :quoteRecord.AccountId
                ORDER BY CreatedDate ASC
            ];
            if (!accBooks.isEmpty()) {
                Address_Book__c bestAcc = pickBestAddressBook(accBooks);
                String formatted = formatAddressBookRecord(bestAcc);
                if (String.isNotBlank(formatted)) {
                    return formatted;
                }
            }
        }
        if (quoteRecord != null) {
            List<String> bParts = new List<String>();
            if (String.isNotBlank(quoteRecord.BillingStreet)) bParts.add(quoteRecord.BillingStreet.replaceAll('\\r\\n|\\r|\\n', ', ').trim());
            if (String.isNotBlank(quoteRecord.BillingCity)) bParts.add(quoteRecord.BillingCity.trim());
            if (String.isNotBlank(quoteRecord.BillingState)) bParts.add(quoteRecord.BillingState.trim());
            if (String.isNotBlank(quoteRecord.BillingPostalCode)) bParts.add(quoteRecord.BillingPostalCode.trim());
            if (bParts.isEmpty() && quoteRecord.Account != null) {
                if (String.isNotBlank(quoteRecord.Account.BillingStreet)) bParts.add(quoteRecord.Account.BillingStreet.replaceAll('\\r\\n|\\r|\\n', ', ').trim());
                if (String.isNotBlank(quoteRecord.Account.BillingCity)) bParts.add(quoteRecord.Account.BillingCity.trim());
                if (String.isNotBlank(quoteRecord.Account.BillingState)) bParts.add(quoteRecord.Account.BillingState.trim());
                if (String.isNotBlank(quoteRecord.Account.BillingPostalCode)) bParts.add(quoteRecord.Account.BillingPostalCode.trim());
            }
            if (!bParts.isEmpty()) {
                return String.join(bParts, ', ');
            }
        }
        return '';
    }

    private static String formatAddressBookRecord(Address_Book__c ab) {
        if (ab == null) return '';
        List<String> parts = new List<String>();
        if (String.isNotBlank(ab.Street__c)) {
            parts.add(ab.Street__c.replaceAll('\\r\\n|\\r|\\n', ', ').trim());
        }
        if (String.isNotBlank(ab.City__c)) {
            parts.add(ab.City__c.trim());
        }
        if (String.isNotBlank(ab.State__c)) {
            parts.add(ab.State__c.trim());
        }
        if (String.isNotBlank(ab.PIN__c)) {
            parts.add(ab.PIN__c.trim());
        }
        String res = String.join(parts, ', ');
        res = res.replaceAll('(, ){2,}', ', ').trim();
        if (res.endsWith(',')) res = res.removeEnd(',');
        return res;
    }

    private static Address_Book__c pickBestAddressBook(List<Address_Book__c> books) {
        if (books == null || books.isEmpty()) return null;
        Address_Book__c best = null;
        Integer bestFilled   = -1;
        Boolean bestPrimary  = false;
        
        for (Address_Book__c b : books) {
            Boolean isPrimary = (b.Primary_Address__c == true);
            Integer filled    = 0;
            if (String.isNotBlank(b.Street__c))  filled++;
            if (String.isNotBlank(b.City__c))    filled++;
            if (String.isNotBlank(b.State__c))   filled++;
            if (String.isNotBlank(b.PIN__c))     filled++;
            if (String.isNotBlank(b.Country__c)) filled++;
            
            Boolean wins = (best == null)
                || (isPrimary && !bestPrimary)
                || (isPrimary == bestPrimary && filled > bestFilled);
            
            if (wins) {
                best        = b;
                bestFilled  = filled;
                bestPrimary = isPrimary;
            }
        }
        return best;
    }

    private List<DocSection> buildDocSectionsFromParsed(Object raw) {
        List<DocSection> out = new List<DocSection>();
        if (!(raw instanceof List<Object>)) return out;
        for (Object secObj : (List<Object>) raw) {
            if (!(secObj instanceof Map<String, Object>)) continue;
            Map<String, Object> sm = (Map<String, Object>) secObj;
            DocSection s   = new DocSection();
            s.title        = pebStr(sm.get('title'));
            s.subtitle     = pebStr(sm.get('subtitle'));
            s.sectionType  = pebStr(sm.get('sectionType'));
            if (sm.get('colCount') != null) {
                try {
                    s.colCount = Integer.valueOf(String.valueOf(sm.get('colCount')));
                } catch (Exception e) {
                    s.colCount = 2;
                }
            } else {
                s.colCount = 2;
            }

            s.tableHeaders = new List<String>();
            if (sm.get('tableHeaders') instanceof List<Object>) {
                for (Object th : (List<Object>) sm.get('tableHeaders')) {
                    s.tableHeaders.add(pebStr(th));
                }
            }

            s.colWidths = new List<String>();
            if (sm.get('colWidths') instanceof List<Object>) {
                for (Object cw : (List<Object>) sm.get('colWidths')) {
                    s.colWidths.add(pebStr(cw));
                }
            }

            s.tableRows = new List<DocRow>();
            if (sm.get('tableRows') instanceof List<Object>) {
                for (Object ro : (List<Object>) sm.get('tableRows')) {
                    if (!(ro instanceof Map<String, Object>)) continue;
                    Map<String, Object> rm = (Map<String, Object>) ro;
                    DocRow r      = new DocRow();
                    r.c1          = pebStr(rm.get('c1'));
                    r.c2          = pebStr(rm.get('c2'));
                    r.c3          = pebStr(rm.get('c3'));
                    r.c4          = pebStr(rm.get('c4'));
                    r.c5          = pebStr(rm.get('c5'));
                    r.c6          = pebStr(rm.get('c6'));
                    r.c7          = pebStr(rm.get('c7'));
                    r.c8          = pebStr(rm.get('c8'));
                    r.c9          = pebStr(rm.get('c9'));
                    r.c10         = pebStr(rm.get('c10'));
                    r.isSubHeader = (rm.get('isSubHeader') == true);

                    // Rowspans
                    r.r1Span      = pebInt(rm.get('r1Span'));
                    r.r2Span      = pebInt(rm.get('r2Span'));
                    r.r3Span      = pebInt(rm.get('r3Span'));
                    r.r4Span      = pebInt(rm.get('r4Span'));
                    r.r5Span      = pebInt(rm.get('r5Span'));
                    r.r6Span      = pebInt(rm.get('r6Span'));

                    // Colspans
                    r.c1Span      = pebInt(rm.get('c1Span'));
                    r.c2Span      = pebInt(rm.get('c2Span'));
                    r.c3Span      = pebInt(rm.get('c3Span'));
                    r.c4Span      = pebInt(rm.get('c4Span'));
                    r.c5Span      = pebInt(rm.get('c5Span'));
                    r.c6Span      = pebInt(rm.get('c6Span'));

                    // Skips
                    r.skipC1      = (rm.get('skipC1') == true);
                    r.skipC2      = (rm.get('skipC2') == true);
                    r.skipC3      = (rm.get('skipC3') == true);
                    r.skipC4      = (rm.get('skipC4') == true);
                    r.skipC5      = (rm.get('skipC5') == true);
                    r.skipC6      = (rm.get('skipC6') == true);
                    r.skipC7      = (rm.get('skipC7') == true);
                    r.skipC8      = (rm.get('skipC8') == true);
                    r.skipC9      = (rm.get('skipC9') == true);
                    r.skipC10     = (rm.get('skipC10') == true);

                    // Bold
                    r.isC1Bold    = (rm.get('isC1Bold') == true);
                    r.isC2Bold    = (rm.get('isC2Bold') == true);
                    r.isC3Bold    = (rm.get('isC3Bold') == true);
                    r.isC4Bold    = (rm.get('isC4Bold') == true);
                    r.isC5Bold    = (rm.get('isC5Bold') == true);
                    r.isC6Bold    = (rm.get('isC6Bold') == true);
                    r.isC7Bold    = (rm.get('isC7Bold') == true);
                    r.isC8Bold    = (rm.get('isC8Bold') == true);
                    r.isC9Bold    = (rm.get('isC9Bold') == true);
                    r.isC10Bold   = (rm.get('isC10Bold') == true);

                    // Align overrides
                    r.alignC1     = pebStr(rm.get('alignC1'));
                    r.alignC2     = pebStr(rm.get('alignC2'));
                    r.alignC3     = pebStr(rm.get('alignC3'));
                    r.alignC4     = pebStr(rm.get('alignC4'));
                    r.alignC5     = pebStr(rm.get('alignC5'));
                    r.alignC6     = pebStr(rm.get('alignC6'));
                    r.alignC7     = pebStr(rm.get('alignC7'));
                    r.alignC8     = pebStr(rm.get('alignC8'));
                    r.alignC9     = pebStr(rm.get('alignC9'));
                    r.alignC10    = pebStr(rm.get('alignC10'));

                    s.tableRows.add(r);
                }
            }

            s.listItems = new List<String>();
            if (sm.get('listItems') instanceof List<Object>) {
                for (Object li : (List<Object>) sm.get('listItems')) {
                    s.listItems.add(pebStr(li));
                }
            }

            s.notes = new List<String>();
            if (sm.get('notes') instanceof List<Object>) {
                for (Object n : (List<Object>) sm.get('notes')) {
                    s.notes.add(pebStr(n));
                }
            }

            out.add(s);
        }
        return out;
    }

    private List<PebRow> buildPebRowsFromParsed(Object raw) {
        List<PebRow> out = new List<PebRow>();
        if (!(raw instanceof List<Object>)) return out;
        for (Object o : (List<Object>) raw) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> m = (Map<String, Object>) o;
            String descText = pebStr(m.get('description'));
            if (String.isBlank(descText)) continue;
            PebRow r      = new PebRow();
            r.description = descText;
            r.size        = pebStr(m.get('size'));
            r.quantity    = pebStr(m.get('quantity'));
            r.remark      = pebStr(m.get('remark'));
            out.add(r);
        }
        return out;
    }

    // accessories[] and buyouts[] share one shape: description / unit / qty.
    // Rows the estimator left at qty 0 are template placeholders and are skipped
    // so the offer never prints an empty accessory line.
    private List<PebRow> buildPebRows(Object raw) {
        List<PebRow> out = new List<PebRow>();
        if (!(raw instanceof List<Object>)) return out;
        for (Object o : (List<Object>) raw) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> m = (Map<String, Object>) o;
            String descText = m.get('description') != null
                        ? String.valueOf(m.get('description')) : '';
            if (String.isBlank(descText)) continue;
            Decimal q = pebDec(m.get('qty'));
            if (q == 0) continue;
            PebRow r    = new PebRow();
            r.description = descText;
            r.size        = m.get('unit') != null ? String.valueOf(m.get('unit')) : '';
            r.quantity    = String.valueOf(q.setScale(0, RoundingMode.HALF_UP));
            r.remark      = m.get('reason') != null ? String.valueOf(m.get('reason')) : '';
            out.add(r);
        }
        return out;
    }

    // "Erection" under D. Other Cost decides whether the Erection Payment
    // Terms clause appears at all. Only a real cost counts - a row the user
    // never touched sits at qty 0 / rate 0 and yields cost 0.
    private Boolean hasErectionCost(Object raw) {
        if (!(raw instanceof List<Object>)) return false;
        for (Object o : (List<Object>) raw) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> m = (Map<String, Object>) o;
            String d = pebStr(m.get('description'));
            if (String.isNotBlank(d) && d.equalsIgnoreCase('Erection')) {
                return pebDec(m.get('cost')) > 0;
            }
        }
        return false;
    }

    // Keeps the E. clause numbers gap-free and duplicate-free.
    //   Payment Terms          E.5  (static in the page)
    //   Erection Payment Terms E.6  - only when showErectionTerms
    //   Delivery Schedule      E.7 with erection, E.6 without
    private void setPebClauseNumbers() {
        ptErectionNo = 'E.6';
        ptDeliveryNo = (showErectionTerms == true) ? 'E.7' : 'E.6';
    }

    private String cleanPebText(String s) {
        if (String.isBlank(s)) return '';
        s = s.replaceAll('\\bS\\s+teel\\b', 'Steel');
        s = s.replaceAll('\\bs\\s+teel\\b', 'steel');
        s = s.replaceAll('\\bSTEEL\\b', 'STEEL');
        s = s.replaceAll('\\bo\\s+f\\b', 'of');
        s = s.replaceAll('\\bO\\s+f\\b', 'Of');
        s = s.replaceAll('\\bC\\s*/\\s*C\\b', 'C/C');
        s = s.replaceAll('(?i)\\bGalvalum\\s+e\\b', 'Galvalume');
        s = s.replaceAll('(?i)\\bGal\\s+valume\\b', 'Galvalume');
        s = s.replaceAll('(?i)\\bdown\\s+co\\s*mer\\b', 'down comer');
        s = s.replaceAll('(?i)\\bco\\s+mer\\b', 'comer');
        s = s.replaceAll('\\bO\\s+ne\\b', 'One');
        s = s.replaceAll('\\bP\\s+aint\\b', 'Paint');
        s = s.replaceAll('(?i)\\bcoat\\s+s\\b', 'coats');
        s = s.replaceAll('\\b0\\.\\s+(\\d+)\\b', '0.$1');
        s = s.replaceAll('\\b1\\s*:\\s*10\\b', '1:10');
        s = s.replaceAll('(?i)\\bAZ\\s*-\\s*150\\b', 'AZ-150');
        s = s.replaceAll('( ){2,}', ' ');
        return s.trim();
    }

    private String pebStr(Object v) {
        if (v == null) return '';
        return cleanPebText(String.valueOf(v));
    }

    private Decimal pebDec(Object v) {
        if (v == null) return 0;
        try   { return Decimal.valueOf(String.valueOf(v)); }
        catch (Exception e) { return 0; }
    }

    private Integer pebInt(Object v) {
        if (v == null) return null;
        try   { return Integer.valueOf(String.valueOf(v).trim()); }
        catch (Exception e) { return null; }
    }

    // whole rupees, Indian grouping: 16303965 -> 1,63,03,965
    private String fmtSupply(Decimal v) {
        if (v == null) return '0';
        Decimal r  = v.setScale(0, RoundingMode.HALF_UP);
        Boolean ng = r < 0;
        String  s  = String.valueOf(r.abs());
        if (s.length() <= 3) return (ng ? '-' : '') + s;
        String last3 = s.substring(s.length() - 3);
        String rest  = s.substring(0, s.length() - 3);
        String grp   = '';
        while (rest.length() > 2) {
            grp  = ',' + rest.substring(rest.length() - 2) + grp;
            rest = rest.substring(0, rest.length() - 2);
        }
        if (rest.length() > 0) grp = rest + grp;
        return (ng ? '-' : '') + grp + ',' + last3;
    }

    public class PebRow {
        public String description { get; set; }
        public String size        { get; set; }
        public String quantity    { get; set; }
        public String remark      { get; set; }
    }
    public class ParamTableRow {
        public String  slNo      { get; set; }
        public String  parameter { get; set; }
        public String  unit      { get; set; }
        public String  value     { get; set; }
        public String  dataFrom  { get; set; }
        public String  remark    { get; set; }
        public Boolean isHeader  { get; set; }
    }

    public class DocSection {
        public String title        { get; set; }
        public String subtitle     { get; set; }
        public String sectionType  { get; set; }
        public Integer colCount    { get; set; }
        public List<String> tableHeaders { get; set; }
        public List<String> colWidths    { get; set; }
        public List<DocRow> tableRows    { get; set; }
        public List<String> listItems    { get; set; }
        public List<String> notes        { get; set; }

        public Boolean isChapter   { get { return sectionType == 'chapter'; } }
        public Boolean isTable     { get { return sectionType == 'table'; } }
        public Boolean isList      { get { return sectionType == 'list'; } }
        public Boolean hasHeaders  { get { return tableHeaders != null && !tableHeaders.isEmpty(); } }
        public Boolean hasSubtitle { get { return String.isNotBlank(subtitle); } }
        public Boolean hasNotes    { get { return notes != null && !notes.isEmpty(); } }
        public Boolean isSmallTable { get { return tableRows != null && tableRows.size() <= 6; } }

        public Boolean hasCol2     { get { return colCount != null && colCount >= 2; } }
        public Boolean hasCol3     { get { return colCount != null && colCount >= 3; } }
        public Boolean hasCol4     { get { return colCount != null && colCount >= 4; } }
        public Boolean hasCol5     { get { return colCount != null && colCount >= 5; } }
        public Boolean hasCol6     { get { return colCount != null && colCount >= 6; } }
        public String  colSpanStr  { get { return String.valueOf(colCount != null && colCount > 0 ? colCount : 1); } }

        public String h1 { get { return tableHeaders != null && tableHeaders.size() > 0 ? tableHeaders[0] : ''; } }
        public String h2 { get { return tableHeaders != null && tableHeaders.size() > 1 ? tableHeaders[1] : ''; } }
        public String h3 { get { return tableHeaders != null && tableHeaders.size() > 2 ? tableHeaders[2] : ''; } }
        public String h4 { get { return tableHeaders != null && tableHeaders.size() > 3 ? tableHeaders[3] : ''; } }
        public String h5 { get { return tableHeaders != null && tableHeaders.size() > 4 ? tableHeaders[4] : ''; } }
        public String h6 { get { return tableHeaders != null && tableHeaders.size() > 5 ? tableHeaders[5] : ''; } }

        public Boolean isFirstColSrNo {
            get {
                if (String.isNotBlank(h1) && (h1.containsIgnoreCase('Sr') || h1.containsIgnoreCase('Sl') || h1.containsIgnoreCase('No.'))) {
                    return true;
                }
                if (String.isBlank(h1) && colCount != null && colCount >= 3 && tableRows != null && !tableRows.isEmpty()) {
                    String firstVal = tableRows[0].c1;
                    if (String.isNotBlank(firstVal) && Pattern.matches('^\\d+$', firstVal.trim())) {
                        return true;
                    }
                }
                return false;
            }
        }

        public Boolean isProjectSummaryTable {
            get {
                return (String.isNotBlank(h1) && h1.containsIgnoreCase('UTILITY')) ||
                       (tableRows != null && !tableRows.isEmpty() && tableRows[0].c2 == 'Total area');
            }
        }

        public Boolean isProjectSummaryBox {
            get {
                return tableRows != null && !tableRows.isEmpty() && tableRows[0].c1 == 'Total no. of Buildings';
            }
        }

        public String w1 {
            get {
                if (colCount == 2) {
                    if (isProjectSummaryBox) return '45%';
                    return '40%';
                }
                if (colCount == 3) {
                    if (isProjectSummaryTable) return '35%';
                    if (isFirstColSrNo) return '6%';
                    return '33%';
                }
                if (colCount == 4) {
                    if (isFirstColSrNo) return '5%';
                    return '25%';
                }
                if (colCount == 5) {
                    if (isFirstColSrNo) return '5%';
                    return '20%';
                }
                if (colCount == 6) {
                    if (isFirstColSrNo) return '5%';
                    return '16%';
                }
                return 'auto';
            }
        }

        public String w2 {
            get {
                if (colCount == 2) {
                    if (isProjectSummaryBox) return '55%';
                    return '60%';
                }
                if (colCount == 3) {
                    if (isProjectSummaryTable) return '30%';
                    if (isFirstColSrNo) return '35%';
                    return '33%';
                }
                if (colCount == 4) {
                    if (isFirstColSrNo) return '25%';
                    return '25%';
                }
                if (colCount == 5) {
                    if (isFirstColSrNo) return '25%';
                    return '20%';
                }
                if (colCount == 6) {
                    if (isFirstColSrNo) return '25%';
                    return '16%';
                }
                return 'auto';
            }
        }

        public String w3 {
            get {
                if (colCount == 3) {
                    if (isProjectSummaryTable) return '35%';
                    if (isFirstColSrNo) return '59%';
                    return '34%';
                }
                if (colCount == 4) {
                    if (isFirstColSrNo) return '35%';
                    return '25%';
                }
                if (colCount == 5) {
                    if (isFirstColSrNo) return '25%';
                    return '20%';
                }
                if (colCount == 6) {
                    if (isFirstColSrNo) return '20%';
                    return '16%';
                }
                return 'auto';
            }
        }

        public String w4 {
            get {
                if (colCount == 4) {
                    if (isFirstColSrNo) return '35%';
                    return '25%';
                }
                if (colCount == 5) {
                    if (isFirstColSrNo) return '25%';
                    return '20%';
                }
                if (colCount == 6) {
                    if (isFirstColSrNo) return '25%';
                    return '16%';
                }
                return 'auto';
            }
        }

        public String w5 {
            get {
                if (colCount == 5) return '20%';
                if (colCount == 6) {
                    if (isFirstColSrNo) return '12%';
                    return '16%';
                }
                return 'auto';
            }
        }

        public String w6 {
            get {
                if (colCount == 6) {
                    if (isFirstColSrNo) return '13%';
                    return '20%';
                }
                return 'auto';
            }
        }

        public String tableHtml {
            get {
                if (!isTable || tableRows == null || tableRows.isEmpty()) {
                    return '';
                }
                Integer cols = colCount != null && colCount > 0 ? colCount : 2;
                String spanStr = String.valueOf(cols);
                List<String> widths = new List<String>();
                if (colWidths != null && colWidths.size() >= cols) {
                    widths = colWidths;
                } else {
                    widths.add(w1);
                    if (cols >= 2) widths.add(w2);
                    if (cols >= 3) widths.add(w3);
                    if (cols >= 4) widths.add(w4);
                    if (cols >= 5) widths.add(w5);
                    if (cols >= 6) widths.add(w6);
                    for (Integer i = 7; i <= cols; i++) {
                        widths.add('auto');
                    }
                }

                String extraTableStyle = (cols >= 8) ? ' font-size: 8px;' : '';
                String h = '<table class="peb-spec-table"' + (String.isNotBlank(extraTableStyle) ? ' style="' + extraTableStyle + '"' : '') + '>';
                if (hasHeaders) {
                    h += '<thead><tr>';
                    for (Integer c = 0; c < cols; c++) {
                        String hdr = (tableHeaders != null && c < tableHeaders.size()) ? tableHeaders[c] : '';
                        String w = (c < widths.size()) ? widths[c] : 'auto';
                        String align = (cols >= 8) ? 'center' : ((c == 0 && (isProjectSummaryTable || isFirstColSrNo)) ? 'center' : (isProjectSummaryTable ? 'center' : 'left'));
                        String hdrEsc = String.isNotBlank(hdr) ? hdr.escapeHtml4() : '&nbsp;';
                        String thPad = (cols >= 8) ? 'padding: 3px 2px; font-size: 8px;' : '';
                        h += '<th style="width: ' + w + '; text-align: ' + align + ';' + thPad + ' background-color: #f0f0f0; color: #000000; font-weight: bold;">' + hdrEsc + '</th>';
                    }
                    h += '</tr></thead>';
                }
                h += '<tbody>';
                for (DocRow r : tableRows) {
                    if (r.isSubHeader != null && r.isSubHeader) {
                        String subText = String.isNotBlank(r.c1) ? r.c1.escapeHtml4() : '&nbsp;';
                        h += '<tr class="subhead-row"><td colspan="' + spanStr + '" style="background-color: #f5f5f5; font-weight: bold; color: #000000;"><b>' + subText + '</b></td></tr>';
                    } else {
                        h += '<tr>';
                        for (Integer c = 0; c < cols; c++) {
                            Boolean skip = false;
                            if (c == 0 && r.skipC1 == true) skip = true;
                            else if (c == 1 && r.skipC2 == true) skip = true;
                            else if (c == 2 && r.skipC3 == true) skip = true;
                            else if (c == 3 && r.skipC4 == true) skip = true;
                            else if (c == 4 && r.skipC5 == true) skip = true;
                            else if (c == 5 && r.skipC6 == true) skip = true;
                            else if (c == 6 && r.skipC7 == true) skip = true;
                            else if (c == 7 && r.skipC8 == true) skip = true;
                            else if (c == 8 && r.skipC9 == true) skip = true;
                            else if (c == 9 && r.skipC10 == true) skip = true;
                            if (skip) continue;

                            String val = '';
                            Integer rSpan = 1;
                            Integer cSpan = 1;
                            Boolean isBold = false;
                            String alignOvr = '';

                            if (c == 0) {
                                val = r.c1;
                                if (r.r1Span != null && r.r1Span > 1) rSpan = r.r1Span;
                                if (r.c1Span != null && r.c1Span > 1) cSpan = r.c1Span;
                                isBold = (r.isC1Bold == true);
                                alignOvr = r.alignC1;
                            } else if (c == 1) {
                                val = r.c2;
                                if (r.r2Span != null && r.r2Span > 1) rSpan = r.r2Span;
                                if (r.c2Span != null && r.c2Span > 1) cSpan = r.c2Span;
                                isBold = (r.isC2Bold == true);
                                alignOvr = r.alignC2;
                            } else if (c == 2) {
                                val = r.c3;
                                if (r.r3Span != null && r.r3Span > 1) rSpan = r.r3Span;
                                if (r.c3Span != null && r.c3Span > 1) cSpan = r.c3Span;
                                isBold = (r.isC3Bold == true);
                                alignOvr = r.alignC3;
                            } else if (c == 3) {
                                val = r.c4;
                                if (r.r4Span != null && r.r4Span > 1) rSpan = r.r4Span;
                                if (r.c4Span != null && r.c4Span > 1) cSpan = r.c4Span;
                                isBold = (r.isC4Bold == true);
                                alignOvr = r.alignC4;
                            } else if (c == 4) {
                                val = r.c5;
                                if (r.r5Span != null && r.r5Span > 1) rSpan = r.r5Span;
                                if (r.c5Span != null && r.c5Span > 1) cSpan = r.c5Span;
                                isBold = (r.isC5Bold == true);
                                alignOvr = r.alignC5;
                            } else if (c == 5) {
                                val = r.c6;
                                if (r.r6Span != null && r.r6Span > 1) rSpan = r.r6Span;
                                if (r.c6Span != null && r.c6Span > 1) cSpan = r.c6Span;
                                isBold = (r.isC6Bold == true);
                                alignOvr = r.alignC6;
                            } else if (c == 6) {
                                val = r.c7;
                                isBold = (r.isC7Bold == true);
                                alignOvr = r.alignC7;
                            } else if (c == 7) {
                                val = r.c8;
                                isBold = (r.isC8Bold == true);
                                alignOvr = r.alignC8;
                            } else if (c == 8) {
                                val = r.c9;
                                isBold = (r.isC9Bold == true);
                                alignOvr = r.alignC9;
                            } else if (c == 9) {
                                val = r.c10;
                                isBold = (r.isC10Bold == true);
                                alignOvr = r.alignC10;
                            }

                            String w = (cSpan == 1 && c < widths.size()) ? 'width: ' + widths[c] + '; ' : '';
                            String vAlign = (rSpan > 1) ? 'vertical-align: middle; ' : '';
                            String align = (cols >= 8) ? 'center' : 'left';
                            if (c == 0 && (isProjectSummaryTable || isFirstColSrNo)) align = 'center';
                            else if (c == 1 && (isProjectSummaryTable || isProjectSummaryBox)) align = 'center';
                            else if (c == 2 && isProjectSummaryTable) align = 'center';
                            if (String.isNotBlank(alignOvr)) align = alignOvr;

                            String tdAttrs = '';
                            if (rSpan > 1) tdAttrs += ' rowspan="' + String.valueOf(rSpan) + '"';
                            if (cSpan > 1) tdAttrs += ' colspan="' + String.valueOf(cSpan) + '"';

                            String cellEsc = String.isNotBlank(val) ? val.escapeHtml4() : '&nbsp;';
                            if (isBold && String.isNotBlank(val)) {
                                cellEsc = '<b>' + cellEsc + '</b>';
                            }
                            String tdPad = (cols >= 8) ? 'padding: 3px 2px; font-size: 8.5px;' : '';
                            h += '<td' + tdAttrs + ' style="' + w + vAlign + 'text-align: ' + align + ';' + tdPad + '">' + cellEsc + '</td>';
                        }
                        h += '</tr>';
                    }
                }
                h += '</tbody></table>';
                return h;
            }
        }
    }

    public class DocRow {
        public String c1 { get; set; }
        public String c2 { get; set; }
        public String c3 { get; set; }
        public String c4 { get; set; }
        public String c5 { get; set; }
        public String c6 { get; set; }
        public String c7 { get; set; }
        public String c8 { get; set; }
        public String c9 { get; set; }
        public String c10 { get; set; }
        public Boolean isSubHeader { get; set; }

        public Integer r1Span { get; set; }
        public Integer r2Span { get; set; }
        public Integer r3Span { get; set; }
        public Integer r4Span { get; set; }
        public Integer r5Span { get; set; }
        public Integer r6Span { get; set; }

        public Integer c1Span { get; set; }
        public Integer c2Span { get; set; }
        public Integer c3Span { get; set; }
        public Integer c4Span { get; set; }
        public Integer c5Span { get; set; }
        public Integer c6Span { get; set; }

        public Boolean skipC1 { get; set; }
        public Boolean skipC2 { get; set; }
        public Boolean skipC3 { get; set; }
        public Boolean skipC4 { get; set; }
        public Boolean skipC5 { get; set; }
        public Boolean skipC6 { get; set; }
        public Boolean skipC7 { get; set; }
        public Boolean skipC8 { get; set; }
        public Boolean skipC9 { get; set; }
        public Boolean skipC10 { get; set; }

        public Boolean isC1Bold { get; set; }
        public Boolean isC2Bold { get; set; }
        public Boolean isC3Bold { get; set; }
        public Boolean isC4Bold { get; set; }
        public Boolean isC5Bold { get; set; }
        public Boolean isC6Bold { get; set; }
        public Boolean isC7Bold { get; set; }
        public Boolean isC8Bold { get; set; }
        public Boolean isC9Bold { get; set; }
        public Boolean isC10Bold { get; set; }

        public String alignC1 { get; set; }
        public String alignC2 { get; set; }
        public String alignC3 { get; set; }
        public String alignC4 { get; set; }
        public String alignC5 { get; set; }
        public String alignC6 { get; set; }
        public String alignC7 { get; set; }
        public String alignC8 { get; set; }
        public String alignC9 { get; set; }
        public String alignC10 { get; set; }
    }
}