public class SteelPipesQuoteController {

    public Quote                      quoteRecord          { get; set; }
    public Map<String, Object>        jsonData             { get; set; }
    
    public List<Map<String, Object>>  standardLineItems    { get; set; }
    public List<Map<String, Object>>  specialLineItems     { get; set; }
    public List<Map<String, Object>>  coreLineItems        { get; set; } 
    public List<String>               specialHeaderCols    { get; set; }
    
    public Decimal                    totalAmount          { get; set; }
    public Decimal                    standardTotalAmount  { get; set; }
    public Decimal                    standardTotalGst     { get; set; }
    public Decimal                    standardTotalFinal   { get; set; }
    
    public Decimal                    coreTotalAmount      { get; set; } 
    public Decimal                    coreTotalGst         { get; set; }
    public Decimal                    coreTotalFinal       { get; set; }
    
    public Decimal                    totalGstAmount       { get; set; }
    public Decimal                    totalFinalAmount     { get; set; }
    public Boolean                    isExport             { get; set; }
    public Boolean                    isNewTcFormat        { get; set; } 
    public Boolean                    showRateInDocDomestic { get; set; }
    public Boolean                    isCoreOnly           { get; set; }
    public Boolean                    isRegularOnly        { get; set; }
    public Boolean hasStandardPipes {
        get {
            if (standardLineItems == null || standardLineItems.isEmpty()) return false;
            for (Map<String, Object> r : standardLineItems) {
                String desig = r.get('designation') != null ? String.valueOf(r.get('designation')) : '';
                String uom   = r.get('uom') != null ? String.valueOf(r.get('uom')) : '';
                String name  = r.get('name') != null ? String.valueOf(r.get('name')) : '';
                String iName = r.get('itemName') != null ? String.valueOf(r.get('itemName')) : '';
                if (!desig.containsIgnoreCase('Lump Sum') && !desig.containsIgnoreCase('Transit Insurance') 
                    && !name.containsIgnoreCase('Lump Sum') && !name.containsIgnoreCase('Transit Insurance') 
                    && !iName.containsIgnoreCase('Lump Sum') && !iName.containsIgnoreCase('Transit Insurance') 
                    && uom != 'Lump Sum') {
                    return true;
                }
            }
            return false;
        }
    }
    public String                     exportCurrency       { get; set; }
    public Decimal                    totalExportFobFc     { get; set; }
    public Decimal                    totalExportFobInr    { get; set; }
    public Decimal                    totalExportCfr       { get; set; }
    public String                     todayDate            { get; set; }
    public String                     quoteNotes           { get; set; }
    public String                     contactEmail         { get; set; }
    public String                     logoBase64           { get; set; }

    public String offerNumber    { get; set; }
    public String companyAddress { get; set; }

    // ── Freight & Loading Properties
    public Boolean                    showLumpSumFreight   { get; set; }
    public Decimal                    lumpSumFreightAmount { get; set; }
    public Boolean                    showPricePerKgFreight   { get; set; }
    public Decimal                    pricePerKgFreightAmount { get; set; }
    
    public Boolean                    showLumpsumLoading   { get; set; }
    public Decimal                    lumpsumLoadingAmount { get; set; }
    public Boolean                    showPerMtLoading     { get; set; }
    public Decimal                    perMtLoadingAmount   { get; set; }

    // ── Payment Terms Properties
    public String  paymentTerms           { get; set; }
    public String  paymentTermsNote       { get; set; }
    public String  otherDetail            { get; set; }
    public String  lcReflectSeparately    { get; set; }
    public Boolean showUsanceColumn       { get; set; }
    public Decimal usanceBuyerDays        { get; set; }
    public Decimal usanceSellerDays       { get; set; }
    public Decimal usancePct              { get; set; }
    public Decimal pdcDays                { get; set; }
    public Decimal pdcInterestPct         { get; set; }
    public Decimal openCreditDays         { get; set; }
    public Decimal openCreditInterestPct  { get; set; }
    public Boolean isAgainstLC            { get; set; }
    public Boolean isAgainstPDC           { get; set; }
    public Boolean isAgainstOpenCredit    { get; set; }

    // ── T&C Integration Properties
    public String  yourRef                { get; set; }
    public String  enquiryDate            { get; set; }
    public String  subjectLine            { get; set; }
    public String  deliverySchedule       { get; set; }
    public String  deliveryScheduleUnit   { get; set; } 
    public Decimal warrantyStart          { get; set; }
    public Decimal warrantyEnd            { get; set; }
    public Decimal offerValidity          { get; set; }
    
    public String  loadingCharges            { get; set; }
    public Decimal loadingChargesPerMt       { get; set; }
    public Decimal loadingChargesLumpsum     { get; set; }
    public Boolean isLoadingPerMtIncluded    { get; set; }
    public Boolean isLoadingPerMtExcluded    { get; set; }
    public Boolean isLoadingLumpsumIncluded  { get; set; }
    public Boolean isLoadingLumpsumExcluded  { get; set; }

    public String clause3  { get; set; }
    public String clause5  { get; set; }
    public String clause7PerMtExcluded    { get; set; }
    public String clause7LumpsumExcluded  { get; set; }
    public String clause7PerMtIncluded    { get; set; }
    public String clause7LumpsumIncluded  { get; set; }
    public String clause8  { get; set; }
    public String clause9  { get; set; }
    public String clause12 { get; set; }
    public String clause13 { get; set; }
    public String clause15 { get; set; }
    public String clause16 { get; set; }
    public String clause20 { get; set; }
    public String point26Label { get; set; }
    public String point26Text  { get; set; }
    public Boolean hasPoint26  { get; set; }

    public SteelPipesQuoteController(ApexPages.StandardController stdController) {
        
        try {
            if (!Test.isRunningTest()) {
                stdController.addFields(new List<String>{
                    'QuoteNumber', 'Opportunity.Name', 'Quote_Value__c', 'CreatedDate', 'ContactId'
                });
            }
        } catch (Exception e) {
            // Ignored when caller passes SObject into StandardController programmatically
        }

        quoteRecord = [
            SELECT Id, Name, QuoteNumber, Quote_Value__c, CreatedDate,
                Account.Name, Account.BillingStreet, Account.BillingCity,
                Account.BillingState, Account.BillingPostalCode, Account.Phone, Account.Email__c,
                Contact.Name, Contact.Phone, Contact.Email,Quote_Reference__c,
                BillingStreet, BillingCity, BillingState, BillingPostalCode
            FROM   Quote
            WHERE  Id = :stdController.getId()
            LIMIT  1
        ];

        try {
            StaticResource sr = [SELECT Body, ContentType FROM StaticResource WHERE Name = 'UtkarshLogo' LIMIT 1];
            logoBase64 = 'data:' + sr.ContentType + ';base64,' + EncodingUtil.base64Encode(sr.Body);
        } catch(Exception e) {
            logoBase64 = '';
        }

        totalAmount = 0.00;
        totalGstAmount = 0.00;
        totalFinalAmount = 0.00;
        standardTotalAmount = 0.00;
        standardTotalGst = 0.00;
        standardTotalFinal = 0.00;
        coreTotalAmount = 0.00;
        coreTotalGst = 0.00;
        coreTotalFinal = 0.00;
        isExport = false;
        isCoreOnly = false;
        isRegularOnly = false;
        isNewTcFormat = true; 
        exportCurrency = '';
        totalExportFobFc = 0.00;
        totalExportFobInr = 0.00;
        totalExportCfr = 0.00;
        
        showLumpSumFreight = false;
        lumpSumFreightAmount = 0.00;
        showPricePerKgFreight = false;
        pricePerKgFreightAmount = 0.00;
        showLumpsumLoading = false;
        lumpsumLoadingAmount = 0.00;
        showPerMtLoading = false;
        perMtLoadingAmount = 0.00;

        standardLineItems = new List<Map<String, Object>>();
        specialLineItems  = new List<Map<String, Object>>();
        coreLineItems     = new List<Map<String, Object>>(); 
        specialHeaderCols = new List<String>();
        todayDate   = Date.today().format();
        
        if (quoteRecord.Contact != null && String.isNotBlank(quoteRecord.Contact.Email)) {
            contactEmail = quoteRecord.Contact.Email;
        } else if (quoteRecord.Account != null && String.isNotBlank(quoteRecord.Account.Email__c)) {
            contactEmail = quoteRecord.Account.Email__c;
        } else {
            contactEmail = '';
        }

        List<String> addrParts = new List<String>();
        if (quoteRecord.Account != null) {
            if (String.isNotBlank(quoteRecord.Account.BillingStreet))     addrParts.add(quoteRecord.Account.BillingStreet);
            if (String.isNotBlank(quoteRecord.Account.BillingCity))       addrParts.add(quoteRecord.Account.BillingCity);
            if (String.isNotBlank(quoteRecord.Account.BillingState))      addrParts.add(quoteRecord.Account.BillingState);
            if (String.isNotBlank(quoteRecord.Account.BillingPostalCode)) addrParts.add(quoteRecord.Account.BillingPostalCode);
        }
        companyAddress = String.join(addrParts, ', ');

        Date qDate = quoteRecord.CreatedDate != null ? quoteRecord.CreatedDate.date() : Date.today();
        Integer fyStartYear = qDate.month() >= 4 ? qDate.year() : qDate.year() - 1;
        String fyStartStr = String.valueOf(fyStartYear);
        String fyEndStr   = String.valueOf(fyStartYear + 1);
        String fyLabel = fyStartStr.substring(fyStartStr.length() - 2) + '-' + fyEndStr.substring(fyEndStr.length() - 2);
        offerNumber = 'UIL/STEEL/' + quoteRecord.QuoteNumber + '/' + fyLabel;

        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
                
                String oldPt = strVal(jsonData, 'tc_payment_terms');
                Boolean hasLegacyFields = String.isNotBlank(oldPt) && oldPt != '-';
                isNewTcFormat = jsonData.containsKey('payment_terms') || jsonData.containsKey('clause_3') || !hasLegacyFields;
                
                // ── Parse Intro Fields
                yourRef              = strVal(jsonData, 'your_ref');
                enquiryDate          = formatDmy(strVal(jsonData, 'enquiry_date'));
                subjectLine          = strVal(jsonData, 'subject_line');
                deliverySchedule     = strVal(jsonData, 'delivery_schedule');
                deliveryScheduleUnit = strVal(jsonData, 'delivery_schedule_in');
                warrantyStart        = decVal(jsonData, 'warranty_start_date');
                warrantyEnd          = decVal(jsonData, 'warranty_end_date');
                offerValidity        = decVal(jsonData, 'offer_validity');

                // ── Parse Payment Terms 
                paymentTerms          = defaultIfBlank(strVal(jsonData, 'payment_terms'), '30% advance along with PO and remaining before dispatch against Inspection');
                paymentTermsNote      = strVal(jsonData, 'payment_terms_note');
                otherDetail           = strVal(jsonData, 'other_detail');
                lcReflectSeparately   = strVal(jsonData, 'lc_interest_reflect_separately');
                usanceBuyerDays       = decVal(jsonData, 'usance_interest_buyer_days');
                usanceSellerDays      = decVal(jsonData, 'usance_interest_seller_days');
                usancePct             = decVal(jsonData, 'usance_interest_percentage');
                pdcDays               = decVal(jsonData, 'against_pdc_days');
                pdcInterestPct        = decVal(jsonData, 'pdc_interest_percentage');
                openCreditDays        = decVal(jsonData, 'against_open_credit_days');
                openCreditInterestPct = decVal(jsonData, 'open_credit_interest_percentage');

                isAgainstLC         = paymentTerms.equalsIgnoreCase('Against LC');
                showUsanceColumn    = isAgainstLC && lcReflectSeparately.equalsIgnoreCase('Yes');
                isAgainstPDC        = paymentTerms.equalsIgnoreCase('Against PDC');
                isAgainstOpenCredit = (paymentTerms.equalsIgnoreCase('Against Open Credit') || paymentTerms.equalsIgnoreCase('Against Open Credit with PDC'));

                Decimal chargeIntDays = 0;
                Decimal chargeIntPct  = 0;
                if (isAgainstPDC) {
                    chargeIntDays = pdcDays;
                    chargeIntPct  = pdcInterestPct;
                } else if (isAgainstOpenCredit) {
                    chargeIntDays = openCreditDays;
                    chargeIntPct  = openCreditInterestPct;
                } else if (isAgainstLC) {
                    chargeIntDays = usanceSellerDays;
                    chargeIntPct  = usancePct;
                }

                Decimal interestMultiplier = 0;
                if (chargeIntDays > 0 && chargeIntPct > 0) {
                    interestMultiplier = (chargeIntDays * chargeIntPct) / (100.0 * 365.0);
                }

                Decimal quoteTotalWeightKg = 0.0;
                Map<String, Decimal> weightMap = new Map<String, Decimal>();
                if (jsonData.containsKey('_Final_Apex_Lines') && jsonData.get('_Final_Apex_Lines') != null) {
                    List<Object> apexLines = (List<Object>) jsonData.get('_Final_Apex_Lines');
                    for (Object lineObj : apexLines) {
                        Map<String, Object> line = (Map<String, Object>) lineObj;
                        String lName = line.get('name') != null ? String.valueOf(line.get('name')).trim() : '';
                        Decimal lWeight = 0.0;
                        if (line.get('weight') != null) {
                            lWeight = Decimal.valueOf(String.valueOf(line.get('weight')));
                        } else if (line.get('totalWeight') != null) {
                            lWeight = Decimal.valueOf(String.valueOf(line.get('totalWeight')));
                        }
                        if (String.isNotBlank(lName)) {
                            weightMap.put(lName, lWeight);
                            if (!lName.containsIgnoreCase('Transit Insurance') && !lName.containsIgnoreCase('Lump Sum Charges')) {
                                quoteTotalWeightKg += lWeight;
                            }
                        }
                    }
                }

                // ── Parse Loading & Freight Charges 
                loadingCharges          = strVal(jsonData, 'loading_charges');
                loadingChargesPerMt     = decVal(jsonData, 'loading_charges_per_mt');
                loadingChargesLumpsum   = decVal(jsonData, 'loading_charges_lumpsum');
                
                String forValue = strVal(jsonData, 'for_value');
                Decimal transportChargesPerMt = decVal(jsonData, 'transportation_charges');
                Decimal transportChargesLumpsum = decVal(jsonData, 'lumpsum_charges');

                isLoadingPerMtIncluded   = String.isNotBlank(loadingCharges) && loadingCharges.containsIgnoreCase('Per mt (Included Price)');
                isLoadingPerMtExcluded   = String.isNotBlank(loadingCharges) && loadingCharges.containsIgnoreCase('Per mt (Excluded Price)');
                isLoadingLumpsumIncluded = String.isNotBlank(loadingCharges) && loadingCharges.containsIgnoreCase('Lump sum (Included Price)');
                isLoadingLumpsumExcluded = String.isNotBlank(loadingCharges) && loadingCharges.containsIgnoreCase('Lump sum (Excluded Price)');

                showLumpSumFreight = (String.isNotBlank(forValue) && forValue.containsIgnoreCase('Lump sum (Excluded Price)') && transportChargesLumpsum > 0);
                lumpSumFreightAmount = transportChargesLumpsum;
                if (showLumpSumFreight && interestMultiplier > 0) {
                    lumpSumFreightAmount += (lumpSumFreightAmount * interestMultiplier);
                }

                showPricePerKgFreight = (String.isNotBlank(forValue) && forValue.containsIgnoreCase('Per mt (Excluded Price)') && transportChargesPerMt > 0);
                pricePerKgFreightAmount = 0.00; 

                showLumpsumLoading = (isLoadingLumpsumExcluded && loadingChargesLumpsum > 0);
                lumpsumLoadingAmount = loadingChargesLumpsum;
                if (showLumpsumLoading && interestMultiplier > 0) {
                    lumpsumLoadingAmount += (lumpsumLoadingAmount * interestMultiplier);
                }

                showPerMtLoading = (isLoadingPerMtExcluded && loadingChargesPerMt > 0);
                perMtLoadingAmount = 0.00; 

                Decimal includedAdditionsPerKg = 0.0;
                
                if (isLoadingPerMtIncluded && loadingChargesPerMt > 0) {
                    includedAdditionsPerKg += (loadingChargesPerMt / 1000.0);
                }
                
                if (String.isNotBlank(forValue) && forValue.containsIgnoreCase('Per mt (Included Price)') && transportChargesPerMt > 0) {
                    includedAdditionsPerKg += (transportChargesPerMt / 1000.0);
                }

                Decimal totalLumpSumIncluded = 0.0;
                if (isLoadingLumpsumIncluded && loadingChargesLumpsum > 0) {
                    totalLumpSumIncluded += loadingChargesLumpsum;
                }
                
                if (String.isNotBlank(forValue) && forValue.containsIgnoreCase('Lump sum (Included Price)') && transportChargesLumpsum > 0) {
                    totalLumpSumIncluded += transportChargesLumpsum;
                }
                
                if (totalLumpSumIncluded > 0 && quoteTotalWeightKg > 0) {
                    includedAdditionsPerKg += (totalLumpSumIncluded / quoteTotalWeightKg);
                }

                // ── Parse and format T&C Editable Clauses 
                clause3  = defaultIfBlank(strVal(jsonData, 'clause_3'), 'Rates and Taxes: The rates quoted are exclusive of Goods & Service Taxes and therefore the Goods & Service Taxes shall be chargeable extra @18% on the total order value.');
                clause5  = defaultIfBlank(strVal(jsonData, 'clause_5'), 'Delivery Schedule: If the delivery date is not accounted for with any subjective precondition in that event the delivery schedule shall be accounted for from the date of the receipt of the supply order however if an advance payment has to be made with the supply order the date of receipt of such advance payment or the supply order, whichever is later shall be the date from which the delivery date shall be accounted for. The supplier will be responsible for delivering the entire consignment segment-wise, subject to mutual discussion and taking into account the date of receipt of the clear techno commercial order and commercial clearance. However, this is contingent upon normal working conditions.' + (String.isNotBlank(deliverySchedule) ? (' Here, delivery schedule shall be ' + deliverySchedule + ' ' + (deliveryScheduleUnit != null ? deliveryScheduleUnit : '') + ' from the date of clear order & commercial clearance.') : ''));
                clause7PerMtExcluded   = defaultIfBlank(strVal(jsonData, 'clause_7_per_mt_excluded'), 'Loading Charges: Rs. 0 per MT (Basic) will be charged extra at actual.');
                clause7LumpsumExcluded = defaultIfBlank(strVal(jsonData, 'clause_7_lumpsum_excluded'), 'Loading Charges: Rs. 0 (Lump Sum) will be charged extra at actual.');
                clause7PerMtIncluded   = defaultIfBlank(strVal(jsonData, 'clause_7_per_mt_included'), 'Loading Charges: Rs. 0 per MT (Basic) is included in the quoted unit price.');
                clause7LumpsumIncluded = defaultIfBlank(strVal(jsonData, 'clause_7_lumpsum_included'), 'Loading Charges: Rs. 0 (Lump Sum) is included in the quoted unit price.');
                clause8  = defaultIfBlank(strVal(jsonData, 'clause_8'), 'Transportation & Freight: The rates quoted for the materials and/or goods are on FOR basis are exclusive of any transportation and freight charges, therefore be it mentioned here that if the Supplier has to facilitate the process of transportation in that event such freight charges shall become chargeable additionally.');
                clause9  = defaultIfBlank(strVal(jsonData, 'clause_9'), 'Inspection: The Buyer at its own cost shall have to make arrangements for pre-delivery third party inspection of the entire quantity offered, by any recognised inspection agency at the Supplier\'s plant and/or factory or the Buyer may depute its own team at the Supplier\'s plant or factory who shall be deemed to have the requisite competence to carry out such pre-delivery inspection and it is only after the receipt of the inspection clearance certification the materials shall be put under despatch. If for any reason the Buyer fails to depute any third party inspection agency to carry out the pre-delivery inspection in that event the Supplier shall at the cost of the Buyer cause such third party pre-delivery inspection to be carried out at the Supplier\'s plant or factory and such inspection for all practical purposes shall be deemed to have been caused at the behest of the Buyer. Such third party inspection caused prior to delivery or despatch of the materials shall be considered and construed as final for all issues on quality and technical parameters.');
                clause12 = defaultIfBlank(strVal(jsonData, 'clause_12'), 'Warranty: The Supplier\'s products are covered by a mechanical guarantee for a period of ' + (warrantyStart != null && warrantyStart > 0 ? String.valueOf(warrantyStart.intValue()) : '12') + ' months from the date of commissioning or at the latest ' + (warrantyEnd != null && warrantyEnd > 0 ? String.valueOf(warrantyEnd.intValue()) : '18') + ' months from the date of delivery as per the agreed incoterm, unless a longer period has been accepted by the Supplier on case by case basis. The warranty period for a defective material, which has been replaced, shall extend only to the extent of the unexpired term of such warranty from the date of replacement. Repaired or corrected materials shall remain warranted for the balance of the original warranty period.');
                clause13 = defaultIfBlank(strVal(jsonData, 'clause_13'), 'Return of Goods: Be it noted that after obtaining satisfactory inspection clearance certification once the goods are sold and delivered the Buyer will not be entitled to return the same by raising any technical issues or defects.');
                clause15 = defaultIfBlank(strVal(jsonData, 'clause_15'), 'Validity: This offer shall remain valid for a period of ' + (offerValidity != null && offerValidity > 0 ? String.valueOf(offerValidity.intValue()) : '6') + ' days from the date of issuing of the present quotation thereafter with the efflux of time this offer shall deemed become null and void, unless the same is revalidated in writing.');
                clause16 = defaultIfBlank(strVal(jsonData, 'clause_16'), 'Penal interest & Ground Rent: Once the material is inspected and final IC is cleared, then if there is any delay to lift the material for commercial clearance (i.e. Payment / Opening of LC, etc) then both Ground Rent of 1% monthly and Penal interest of 18% per annum shall be charged to the Buyer. Also in the event if the Buyer fails to make payment of the invoices raised within seven days and/or as may be agreed otherwise, from the date of receipt of the same in that event the Supplier shall be entitled to impose penal interest @10% per annum quarterly compoundable.');
                clause20 = defaultIfBlank(strVal(jsonData, 'clause_20'), 'Price variation: PVC will be applicable as per IEEMA circular.');
                
                clause3  = boldClausePrefix(clause3);
                clause5  = boldClausePrefix(clause5);
                clause7PerMtExcluded   = boldClausePrefix(clause7PerMtExcluded);
                clause7LumpsumExcluded = boldClausePrefix(clause7LumpsumExcluded);
                clause7PerMtIncluded   = boldClausePrefix(clause7PerMtIncluded);
                clause7LumpsumIncluded = boldClausePrefix(clause7LumpsumIncluded);
                clause8  = boldClausePrefix(clause8);
                clause9  = boldClausePrefix(clause9);
                clause12 = boldClausePrefix(clause12);
                clause13 = boldClausePrefix(clause13);
                clause15 = boldClausePrefix(clause15);
                clause16 = boldClausePrefix(clause16);
                clause20 = boldClausePrefix(clause20);

                point26Label = defaultIfBlank(strVal(jsonData, 'point_26_label'), 'As new requirement');
                point26Text  = strVal(jsonData, 'point_26_text');
                hasPoint26   = String.isNotBlank(point26Text);
                
                List<String> requiredVfKeys = new List<String>{
                    'market_type', 'tc_offer_validity', 'tc_delivery_period',
                    'tc_price_variation', 'tc_payment_terms',
                    'tc_vehicle_load', 'tc_qty_tolerance', 'tc_tolerance', 'tc_inspection',
                    'tc_pre_dispatch_inspection', 'tc_work_address', 'tc_gst_tin_number'
                };
                for (String key : requiredVfKeys) {
                    if (!jsonData.containsKey(key) || jsonData.get(key) == null) {
                        jsonData.put(key, '-'); 
                    }
                }
                
                if (jsonData.containsKey('Note') && jsonData.get('Note') != null) {
                    quoteNotes = String.valueOf(jsonData.get('Note'));
                }

                showRateInDocDomestic = true;
                if (jsonData.containsKey('_showRateInDocDomestic') && jsonData.get('_showRateInDocDomestic') != null) {
                    showRateInDocDomestic = (Boolean) jsonData.get('_showRateInDocDomestic');
                }

                if (jsonData.containsKey('_Saved_Table_Rows')) {
                    List<Object> rawRows = (List<Object>) jsonData.get('_Saved_Table_Rows');
                    Integer slNo = 1;
                    Integer coreSlNo = 1; 
                    Integer colIndex = 1; 
                    
                    Map<String, String> scheduleMap = new Map<String, String>();
                    Map<String, Decimal> cfrMap = new Map<String, Decimal>();
                    Map<String, Map<String, Object>> coreConfigMap = new Map<String, Map<String, Object>>();
                    
                    if (jsonData.containsKey('_configuredPipesDomestic') && jsonData.get('_configuredPipesDomestic') != null) {
                        try {
                            List<Object> domList = (List<Object>) jsonData.get('_configuredPipesDomestic');
                            for (Object dObj : domList) {
                                if (dObj instanceof Map<String, Object>) {
                                    Map<String, Object> dMap = (Map<String, Object>) dObj;
                                    String dDesc = dMap.get('special_description') != null ? String.valueOf(dMap.get('special_description')).trim() : (dMap.get('Special_Description__c') != null ? String.valueOf(dMap.get('Special_Description__c')).trim() : '');
                                    if (String.isNotBlank(dDesc)) {
                                        coreConfigMap.put(dDesc.toLowerCase(), dMap);
                                    }
                                }
                            }
                        } catch(Exception e) {}
                    }
                    
                    if (jsonData.containsKey('_configuredPipesExport') && jsonData.get('_configuredPipesExport') != null) {
                        List<Object> exportRows = (List<Object>) jsonData.get('_configuredPipesExport');
                        Integer exIdx = 0;
                        for (Object exObj : exportRows) {
                            Map<String, Object> exRow = (Map<String, Object>) exObj;
                            
                            String exSched = exRow.get('schedule') != null ? String.valueOf(exRow.get('schedule')) : '';
                            Decimal exCfr = exRow.get('cfr') != null ? Decimal.valueOf(String.valueOf(exRow.get('cfr'))) : 0.0;
                            
                            scheduleMap.put(String.valueOf(exIdx), exSched);
                            cfrMap.put(String.valueOf(exIdx), exCfr);
                            exIdx++;
                        }
                    }
                    Integer exportRowIndex = 0;
                    
                    for (Object rowObj : rawRows) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;
                        
                        if(row.get('itemName') == null && row.get('name') != null) {
                            row.put('itemName', row.get('name'));
                        }

                        String pit = row.get('price_input_type') != null ? String.valueOf(row.get('price_input_type')) : '';
                        if(String.isBlank(pit) && row.get('priceInputType') != null) {
                            pit = String.valueOf(row.get('priceInputType'));
                        }
                        Boolean isExportRow = String.isNotBlank(pit);
                        
                        String rowNameStr = row.get('name') != null ? String.valueOf(row.get('name')) : '';
                        Boolean isSpecialExpense = rowNameStr.containsIgnoreCase('Transit Insurance') || rowNameStr.containsIgnoreCase('Lump Sum Charges');
                        
                        // Map Schedule, CFR, and Grade specifically for Export Pipes
                        if (isExportRow && !isSpecialExpense) {
                            String sched = '';
                            Decimal mappedCfr = 0.0;
                            
                            if (row.containsKey('schedule') && row.get('schedule') != null) {
                                sched = String.valueOf(row.get('schedule'));
                            } else if (scheduleMap.containsKey(String.valueOf(exportRowIndex))) {
                                sched = scheduleMap.get(String.valueOf(exportRowIndex));
                            }
                            row.put('schedule', sched);
                            
                            if (row.containsKey('cfr') && row.get('cfr') != null) {
                                mappedCfr = Decimal.valueOf(String.valueOf(row.get('cfr')));
                            } else if (cfrMap.containsKey(String.valueOf(exportRowIndex))) {
                                mappedCfr = cfrMap.get(String.valueOf(exportRowIndex));
                            }
                            row.put('cfr', mappedCfr);
                            
                            // 👉 NEW: Clear Grade value if the standard is NOT ASTM
                            String stdForGradeCheck = row.get('standard_spec_grade') != null ? String.valueOf(row.get('standard_spec_grade')) : '';
                            if (!stdForGradeCheck.startsWithIgnoreCase('ASTM')) {
                                row.put('grade', ''); 
                            }
                            
                            exportRowIndex++;
                        }

                        if (specialHeaderCols.isEmpty()) {
                            specialHeaderCols.add('Length (M)');
                            specialHeaderCols.add('Special Description');
                        }

                        if (isSpecialExpense) {
                            row.put('uom', 'Lump Sum');
                            Decimal uCost = row.get('unitCost') != null ? Decimal.valueOf(String.valueOf(row.get('unitCost'))) : 0.0;
                            if (uCost == 0) {
                                Decimal rRate = row.get('rate') != null ? Decimal.valueOf(String.valueOf(row.get('rate'))) : 0.0;
                                Decimal rExp = row.get('expenses') != null ? Decimal.valueOf(String.valueOf(row.get('expenses'))) : 0.0;
                                row.put('unitCost', rRate > 0 ? rRate : rExp);
                            }
                            row.put('designation', rowNameStr);
                            row.put('size_nb', '-');
                            row.put('display_class_thickness', '-');
                            row.put('end_finish', '-');
                            row.put('standard_spec_grade', '-');
                            row.put('special_description_header', '-');
                            row.put('special_description', rowNameStr.containsIgnoreCase('Lump Sum') ? 'Lump Sum Addition' : 'Transit Insurance');
                        } else {
                            row.put('designation', row.get('designation') != null ? String.valueOf(row.get('designation')) : '');
                            row.put('standard_spec_grade', row.get('standard_spec_grade') != null ? String.valueOf(row.get('standard_spec_grade')) : '');
                            
                            String std = row.get('standard_spec_grade') != null ? String.valueOf(row.get('standard_spec_grade')) : '';
                            String pClass = row.get('pipe_class') != null ? String.valueOf(row.get('pipe_class')) : '';
                            String customThk = row.get('custom_thickness') != null ? String.valueOf(row.get('custom_thickness')) : '';
                            String shapeVal = row.get('shape') != null ? String.valueOf(row.get('shape')) : '';
                            
                            if (std.contains('IS 1239') || std.contains('10577')) {
                                row.put('display_class_thickness', String.isNotBlank(shapeVal) ? shapeVal : pClass);
                            } else {
                                Decimal thkVal = 0;
                                if(String.isNotBlank(customThk)){ try { thkVal = Decimal.valueOf(customThk); } catch(Exception e){} }
                                if (thkVal > 0) { row.put('display_class_thickness', customThk); } else { row.put('display_class_thickness', pClass); }
                            }
                            
                            String reflectInDoc = row.get('reflect_in_offer_doc') != null ? String.valueOf(row.get('reflect_in_offer_doc')) : 'Yes';
                            if (!reflectInDoc.equalsIgnoreCase('Yes')) {
                                row.put('display_class_thickness', '-');
                            }
                            row.put('pipe_class', pClass);
                            
                            String sizeVal = row.get('size_nb') != null ? String.valueOf(row.get('size_nb')) : '';
                            if (String.isNotBlank(sizeVal)) {
                                sizeVal = sizeVal.replaceAll('(?i)mm', '').trim();
                                
                                if (!isExportRow) {
                                    if (std.containsIgnoreCase('IS 3589') || std.containsIgnoreCase('IS 1239') || std.containsIgnoreCase('IS 1161')) {
                                        sizeVal += '(NB)';
                                    } else if (!std.containsIgnoreCase('IS 4923') && !pClass.equalsIgnoreCase('Core')) {
                                        String odVal = '';
                                        if (row.get('mapped_od') != null && String.isNotBlank(String.valueOf(row.get('mapped_od')))) {
                                            odVal = String.valueOf(row.get('mapped_od'));
                                        } else if (row.get('od') != null && String.isNotBlank(String.valueOf(row.get('od')))) {
                                            odVal = String.valueOf(row.get('od'));
                                        }
                                        
                                        String num = sizeVal.replaceAll('[^0-9.]', '');
                                        
                                        if (String.isBlank(odVal) || odVal == '0' || odVal == '0.0') {
                                            if (std.containsIgnoreCase('4270')) {
                                                Map<String, String> is4270 = new Map<String, String>{'100'=>'114.3', '125'=>'141.3', '150'=>'168.3', '175'=>'193.7', '200'=>'219.1', '225'=>'244.5', '250'=>'273.1', '300'=>'323.9', '350'=>'355.6', '400'=>'406.4'};
                                                if (is4270.containsKey(num)) odVal = is4270.get(num);
                                            } else if (std.containsIgnoreCase('ASTM')) {
                                                Map<String, String> astm = new Map<String, String>{'15'=>'21.3', '20'=>'26.7', '25'=>'33.4', '32'=>'42.2', '40'=>'48.3', '50'=>'60.3', '65'=>'73.0', '80'=>'88.9', '90'=>'101.6', '100'=>'114.3', '110'=>'127', '125'=>'141.3', '135'=>'152.4', '150'=>'168.3', '175'=>'193.7', '200'=>'219.1', '225'=>'244.5', '250'=>'273.0', '300'=>'323.9', '350'=>'355.6', '400'=>'406.4'};
                                                if (astm.containsKey(num)) odVal = astm.get(num);
                                            }
                                        }
                                        
                                        if (String.isNotBlank(odVal) && odVal != '0' && odVal != '0.0') {
                                            sizeVal = odVal + '(OD)';
                                        } else {
                                            sizeVal += '(OD)';
                                        }
                                        if (std.containsIgnoreCase('ASTM') && String.isNotBlank(shapeVal)) {
                                            sizeVal += ', ' + shapeVal.replace('-', ' ');
                                        }
                                    }
                                }
                            }
                            row.put('size_nb', sizeVal);
                            row.put('end_finish', row.get('end_finish') != null ? String.valueOf(row.get('end_finish')) : '');
                        }

                        Decimal qty = row.get('quantity') != null ? Decimal.valueOf(String.valueOf(row.get('quantity'))) : 0.0;
                        Decimal rate = row.get('rate') != null ? Decimal.valueOf(String.valueOf(row.get('rate'))) : 0.0;
                        Decimal total = row.get('total_price') != null ? Decimal.valueOf(String.valueOf(row.get('total_price'))) : (qty * rate);
                        
                        Decimal exactUnitCost = row.get('unitCost') != null ? Decimal.valueOf(String.valueOf(row.get('unitCost'))) : 0.0;

                        Decimal pdf_rate = 0.0;
                        Decimal pdf_base_total = 0.0;
                        Decimal pdf_gst_amount = 0.0;
                        Decimal pdf_total_price = 0.0;
                        Decimal pdf_gst_percentage = 18.0;
                        Decimal pdf_unit_price = 0.0;
                        Decimal pdf_display_unit_price = 0.0;

                        String specialDescStr = row.get('special_description') != null ? String.valueOf(row.get('special_description')).trim() : '';

                        Decimal commAmt = 0.0;
                        if (row.get('commission_amount') != null) {
                            try { commAmt = Decimal.valueOf(String.valueOf(row.get('commission_amount'))); } catch (Exception e) {}
                        } else if (row.get('commissionAmount') != null) {
                            try { commAmt = Decimal.valueOf(String.valueOf(row.get('commissionAmount'))); } catch (Exception e) {}
                        } else if (row.get('Commission_Amount__c') != null) {
                            try { commAmt = Decimal.valueOf(String.valueOf(row.get('Commission_Amount__c'))); } catch (Exception e) {}
                        } else if (String.isNotBlank(specialDescStr) && coreConfigMap.containsKey(specialDescStr.toLowerCase())) {
                            Map<String, Object> cCfg = coreConfigMap.get(specialDescStr.toLowerCase());
                            if (cCfg.get('commission_amount') != null) {
                                try { commAmt = Decimal.valueOf(String.valueOf(cCfg.get('commission_amount'))); } catch (Exception e) {}
                            } else if (cCfg.get('commissionAmount') != null) {
                                try { commAmt = Decimal.valueOf(String.valueOf(cCfg.get('commissionAmount'))); } catch (Exception e) {}
                            } else if (cCfg.get('Commission_Amount__c') != null) {
                                try { commAmt = Decimal.valueOf(String.valueOf(cCfg.get('Commission_Amount__c'))); } catch (Exception e) {}
                            }
                        }

                        if (row.get('price_per_uom') != null) {
                            pdf_rate = Decimal.valueOf(String.valueOf(row.get('rate')));
                            pdf_display_unit_price = Decimal.valueOf(String.valueOf(row.get('price_per_uom')));
                            Decimal unitGst = row.get('gst') != null ? Decimal.valueOf(String.valueOf(row.get('gst'))) : 0.0;
                            
                            pdf_unit_price = exactUnitCost > 0 ? exactUnitCost : pdf_display_unit_price;

                            if (commAmt > 0 && pdf_unit_price > 0 && unitGst > 0) {
                                Decimal gstWithComm = ((pdf_unit_price + commAmt) * 0.18).setScale(2, RoundingMode.HALF_UP);
                                Decimal gstWithoutComm = (pdf_unit_price * 0.18).setScale(2, RoundingMode.HALF_UP);
                                if (Math.abs(unitGst - gstWithComm) <= 0.05 && Math.abs(unitGst - gstWithoutComm) > 0.05) {
                                    pdf_unit_price += commAmt;
                                    pdf_display_unit_price += commAmt;
                                    pdf_rate += commAmt;
                                }
                            }

                            if (pdf_unit_price > 0) {
                                pdf_gst_percentage = ((unitGst / pdf_unit_price) * 100.0).setScale(0, System.RoundingMode.HALF_UP);
                            }
                        } else {
                            Decimal unitGst = row.get('gst') != null ? Decimal.valueOf(String.valueOf(row.get('gst'))) : 0.0;
                            Decimal gstPercentage = (rate > 0) ? (unitGst / rate) * 100.0 : 0.0;
                            gstPercentage = gstPercentage.setScale(0, System.RoundingMode.HALF_UP);
                            pdf_gst_percentage = gstPercentage;
                            
                            Decimal discountPercent = row.get('discount') != null ? Decimal.valueOf(String.valueOf(row.get('discount'))) : 0.0;
                            Decimal discountedRate = rate * (1 - (discountPercent / 100.0));
                            pdf_rate = discountedRate.setScale(2, System.RoundingMode.HALF_UP);
                            
                            Decimal baseTotal = (gstPercentage > 0) ? total / (1 + (gstPercentage / 100.0)) : total;
                            pdf_unit_price = exactUnitCost > 0 ? exactUnitCost : (qty > 0 ? (baseTotal / qty).setScale(2, System.RoundingMode.HALF_UP) : 0.0);

                            if (commAmt > 0 && pdf_unit_price > 0 && unitGst > 0) {
                                Decimal gstWithComm = ((pdf_unit_price + commAmt) * 0.18).setScale(2, RoundingMode.HALF_UP);
                                Decimal gstWithoutComm = (pdf_unit_price * 0.18).setScale(2, RoundingMode.HALF_UP);
                                if (Math.abs(unitGst - gstWithComm) <= 0.05 && Math.abs(unitGst - gstWithoutComm) > 0.05) {
                                    pdf_unit_price += commAmt;
                                    pdf_rate += commAmt;
                                    pdf_gst_percentage = ((unitGst / pdf_unit_price) * 100.0).setScale(0, System.RoundingMode.HALF_UP);
                                }
                            }

                            pdf_display_unit_price = pdf_unit_price;
                        }

                        Decimal lineTotalWeight = 0.0;
                        if (row.get('totalWeight') != null && Decimal.valueOf(String.valueOf(row.get('totalWeight'))) > 0) {
                            lineTotalWeight = Decimal.valueOf(String.valueOf(row.get('totalWeight')));
                        } else if (row.get('total_weight') != null && Decimal.valueOf(String.valueOf(row.get('total_weight'))) > 0) {
                            lineTotalWeight = Decimal.valueOf(String.valueOf(row.get('total_weight')));
                        } else if (row.get('weight') != null && Decimal.valueOf(String.valueOf(row.get('weight'))) > 0) {
                            lineTotalWeight = Decimal.valueOf(String.valueOf(row.get('weight')));
                        } else {
                            if (weightMap.containsKey(rowNameStr)) {
                                lineTotalWeight = weightMap.get(rowNameStr);
                            }
                        }

                        if (!isSpecialExpense && includedAdditionsPerKg > 0) {
                            Decimal unitAddition = 0.0;
                            if (qty > 0) {
                                unitAddition = (includedAdditionsPerKg * lineTotalWeight) / qty;
                            }
                            pdf_unit_price += unitAddition;
                            pdf_display_unit_price += unitAddition;
                            pdf_rate += includedAdditionsPerKg;
                        }
                        
                        Decimal itemInterest = 0;
                        if (interestMultiplier > 0) { 
                            itemInterest = (pdf_unit_price * interestMultiplier).setScale(2, RoundingMode.HALF_UP);
                        }

                        Decimal finalUnitPriceWithInterest = pdf_unit_price + itemInterest;

                        if (showUsanceColumn) {
                            row.put('usance_interest', itemInterest);
                            row.put('unitCost', pdf_unit_price.setScale(2, RoundingMode.HALF_UP));
                        } else {
                            row.put('usance_interest', null);
                            row.put('unitCost', finalUnitPriceWithInterest.setScale(2, RoundingMode.HALF_UP));
                        }

                        pdf_base_total = (finalUnitPriceWithInterest * qty).setScale(2, System.RoundingMode.HALF_UP);

                        Decimal newUnitGst = ((pdf_base_total / (qty > 0 ? qty : 1)) * (pdf_gst_percentage / 100.0));
                        pdf_gst_amount = (newUnitGst * qty).setScale(2, System.RoundingMode.HALF_UP);
                        pdf_total_price = pdf_base_total + pdf_gst_amount;
                        
                        row.put('pdf_rate', pdf_rate.setScale(2, RoundingMode.HALF_UP));
                        row.put('pdf_unit_price', pdf_unit_price.setScale(2, RoundingMode.HALF_UP));
                        row.put('pdf_display_unit_price', pdf_display_unit_price.setScale(2, RoundingMode.HALF_UP));
                        row.put('pdf_base_total', pdf_base_total); 
                        row.put('pdf_gst_amount', pdf_gst_amount);
                        row.put('pdf_total_price', pdf_total_price);
                        row.put('pdf_gst_percentage', pdf_gst_percentage);
                        
                        row.put('uom', row.get('uom') != null ? String.valueOf(row.get('uom')) : '');
                        row.put('quantity', qty);
                        row.put('rate', rate);
                        row.put('total_price', total);
                        
                        Decimal customOd = row.get('customOD') != null ? Decimal.valueOf(String.valueOf(row.get('customOD'))) : (row.get('custom_od') != null ? Decimal.valueOf(String.valueOf(row.get('custom_od'))) : 0.0);
                        Decimal od = (customOd > 0.0) ? customOd : (row.get('od') != null ? Decimal.valueOf(String.valueOf(row.get('od'))) : 0.0);
                        
                        String cc = row.get('currency_code') != null ? String.valueOf(row.get('currency_code')) : '';
                        if(String.isBlank(cc) && row.get('currencyCode') != null) {
                            cc = String.valueOf(row.get('currencyCode'));
                        }
                        
                        Decimal pfc = row.get('price_fc') != null ? Decimal.valueOf(String.valueOf(row.get('price_fc'))) : 0.0;
                        if(pfc == 0.0 && row.get('priceFc') != null) pfc = Decimal.valueOf(String.valueOf(row.get('priceFc')));

                        Decimal tfc = row.get('total_fob_fc') != null ? Decimal.valueOf(String.valueOf(row.get('total_fob_fc'))) : 0.0;
                        if(tfc == 0.0 && row.get('totalFobFc') != null) tfc = Decimal.valueOf(String.valueOf(row.get('totalFobFc')));

                        Decimal tfinr = row.get('total_fob_inr') != null ? Decimal.valueOf(String.valueOf(row.get('total_fob_inr'))) : 0.0;
                        if(tfinr == 0.0 && row.get('totalFobInr') != null) tfinr = Decimal.valueOf(String.valueOf(row.get('totalFobInr')));
                        
                        Decimal customWt = row.get('customWallThickness') != null ? Decimal.valueOf(String.valueOf(row.get('customWallThickness'))) : (row.get('custom_wall_thickness') != null ? Decimal.valueOf(String.valueOf(row.get('custom_wall_thickness'))) : 0.0);
                        Decimal wt = (customWt > 0.0) ? customWt : (row.get('wall_thickness') != null ? Decimal.valueOf(String.valueOf(row.get('wall_thickness'))) : 0.0);
                        if(wt == 0.0 && row.get('wallThickness') != null) wt = Decimal.valueOf(String.valueOf(row.get('wallThickness')));

                        Decimal pl = 0.0;
                        String plStr = '';
                        if (row.get('pipe_length') != null) {
                            plStr = String.valueOf(row.get('pipe_length')).trim();
                        } else if (row.get('pipeLength') != null) {
                            plStr = String.valueOf(row.get('pipeLength')).trim();
                        }
                        if (String.isNotBlank(plStr) && plStr != 'NA' && plStr != '-') {
                            try { pl = Decimal.valueOf(plStr); } catch (Exception e) {}
                        }

                        Decimal kgm = 0.0;
                        String kgmStr = '';
                        if (row.get('kg_per_meter') != null) {
                            kgmStr = String.valueOf(row.get('kg_per_meter')).trim();
                        } else if (row.get('kgPerMeter') != null) {
                            kgmStr = String.valueOf(row.get('kgPerMeter')).trim();
                        }
                        if (String.isNotBlank(kgmStr) && kgmStr != 'NA' && kgmStr != '-') {
                            try { kgm = Decimal.valueOf(kgmStr); } catch (Exception e) {}
                        }

                        String zc = row.get('zinc_coating') != null ? String.valueOf(row.get('zinc_coating')).trim() : '';
                        if (String.isBlank(zc) && row.get('zincCoating') != null) zc = String.valueOf(row.get('zincCoating')).trim();
                        if (String.isBlank(zc) && row.get('Zinc_Coating__c') != null) zc = String.valueOf(row.get('Zinc_Coating__c')).trim();

                        Decimal zr = 0.0;
                        if (row.get('zinc_rate') != null) {
                            try { zr = Decimal.valueOf(String.valueOf(row.get('zinc_rate')).trim()); } catch (Exception e) {}
                        } else if (row.get('zincRate') != null) {
                            try { zr = Decimal.valueOf(String.valueOf(row.get('zincRate')).trim()); } catch (Exception e) {}
                        } else if (row.get('Zinc_Rate__c') != null) {
                            try { zr = Decimal.valueOf(String.valueOf(row.get('Zinc_Rate__c')).trim()); } catch (Exception e) {}
                        }

                        Decimal tp = row.get('total_pieces') != null ? Decimal.valueOf(String.valueOf(row.get('total_pieces'))) : 0.0;
                        if(tp == 0.0 && row.get('totalPieces') != null) tp = Decimal.valueOf(String.valueOf(row.get('totalPieces')));

                        Decimal tm = row.get('total_meters') != null ? Decimal.valueOf(String.valueOf(row.get('total_meters'))) : 0.0;
                        if(tm == 0.0 && row.get('totalMeters') != null) tm = Decimal.valueOf(String.valueOf(row.get('totalMeters')));

                        Decimal tw = row.get('total_weight') != null ? Decimal.valueOf(String.valueOf(row.get('total_weight'))) : 0.0;
                        if(tw == 0.0 && row.get('totalWeight') != null) tw = Decimal.valueOf(String.valueOf(row.get('totalWeight')));

                        Decimal cfrVal = row.get('cfr') != null ? Decimal.valueOf(String.valueOf(row.get('cfr'))) : 0.0;

                        String endF = row.get('end_finish') != null ? String.valueOf(row.get('end_finish')) : '';
                        if(String.isBlank(endF) && row.get('endFinish') != null) endF = String.valueOf(row.get('endFinish'));

                        row.put('od', od);
                        row.put('wallThickness', wt); 
                        row.put('pipeLength', pl);
                        row.put('endFinish', endF);
                        row.put('kgPerMeter', kgm);
                        row.put('totalPieces', tp);
                        row.put('totalMeters', tm);
                        row.put('totalWeight', tw);
                        row.put('priceFc', pfc);
                        row.put('totalFobFc', tfc);
                        row.put('totalFobInr', tfinr);
                        row.put('cfr', cfrVal); 
                        row.put('priceInputType', pit);
                        row.put('price_per_mt_fc', tw > 0 ? (tfc / tw) : 0);
                        row.put('price_per_piece_fc', tp > 0 ? (tfc / tp) : 0);
                        
                        if (isExportRow) {
                            isExport = true;
                            if (String.isBlank(exportCurrency) && String.isNotBlank(cc)) {
                                exportCurrency = cc;
                            }
                            totalExportFobFc += tfc;
                            totalExportFobInr += tfinr;
                            totalExportCfr += cfrVal; 
                        }
                        
                        String cHeader = jsonData.containsKey('c' + colIndex + '_Header') ? String.valueOf(jsonData.get('c' + colIndex + '_Header')) : '';
                        String cValue  = jsonData.containsKey('c' + colIndex + '_Value')  ? String.valueOf(jsonData.get('c' + colIndex + '_Value')) : '';
                        if (String.isBlank(specialDescStr)) {
                            specialDescStr = row.get('special_description') != null ? String.valueOf(row.get('special_description')).trim() : '';
                        }
                        String pClassStr = row.get('pipe_class') != null ? String.valueOf(row.get('pipe_class')) : '';

                        Boolean isCore = pClassStr.equalsIgnoreCase('Core') 
                            || specialDescStr.containsIgnoreCase('STAY & REGISTER ARM Small Tube')
                            || specialDescStr.containsIgnoreCase('Large Tube (49.00X40.90mm)')
                            || specialDescStr.containsIgnoreCase('BRACKET Standard Tube')
                            || specialDescStr.containsIgnoreCase('GUIDE Counter Weight Tube');

                        if (isCore) {
                            if (coreConfigMap.containsKey(specialDescStr.toLowerCase())) {
                                Map<String, Object> cCfg = coreConfigMap.get(specialDescStr.toLowerCase());
                                if (String.isBlank(zc) || zc == 'N/A') {
                                    if (cCfg.get('zinc_coating') != null) zc = String.valueOf(cCfg.get('zinc_coating')).trim();
                                    else if (cCfg.get('zincCoating') != null) zc = String.valueOf(cCfg.get('zincCoating')).trim();
                                    else if (cCfg.get('Zinc_Coating__c') != null) zc = String.valueOf(cCfg.get('Zinc_Coating__c')).trim();
                                }
                                if (kgm == 0.0) {
                                    Object kObj = cCfg.get('kg_per_meter') != null ? cCfg.get('kg_per_meter') : (cCfg.get('kgPerMeter') != null ? cCfg.get('kgPerMeter') : cCfg.get('Weight_Per_Meter__c'));
                                    if (kObj != null) {
                                        try { kgm = Decimal.valueOf(String.valueOf(kObj)); } catch (Exception e) {}
                                    }
                                }
                                if (String.isBlank(plStr) || plStr == 'NA' || plStr == '-' || plStr == '0' || plStr == '0.0') {
                                    Object lObj = cCfg.get('pipe_length') != null ? cCfg.get('pipe_length') : (cCfg.get('pipeLength') != null ? cCfg.get('pipeLength') : cCfg.get('Length__c'));
                                    if (lObj != null) {
                                        String lStr = String.valueOf(lObj).trim();
                                        if (String.isNotBlank(lStr) && lStr != 'NA' && lStr != '0' && lStr != '0.0') {
                                            plStr = lStr;
                                        }
                                    }
                                }
                            }

                            if (String.isBlank(zc) || zc == 'N/A') {
                                zc = '360 GSM';
                            }
                            if (kgm == 0.0) {
                                if (specialDescStr.containsIgnoreCase('Small Tube')) kgm = 1.9;
                                else if (specialDescStr.containsIgnoreCase('Large Tube')) kgm = 4.0;
                                else if (specialDescStr.containsIgnoreCase('BRACKET')) kgm = 3.1;
                                else if (specialDescStr.containsIgnoreCase('GUIDE')) kgm = 1.9;
                            }
                            String plDisplay = '-';
                            if (String.isNotBlank(plStr) && plStr != 'NA' && plStr != '-' && plStr != '0' && plStr != '0.0') {
                                plDisplay = plStr;
                            } else if (specialDescStr.containsIgnoreCase('GUIDE')) {
                                plDisplay = '5.6';
                            }

                            row.put('zincCoating', zc);
                            row.put('zincRate', zr);
                            row.put('kgPerMeter', kgm);
                            row.put('pipeLengthDisplay', plDisplay);
                            row.put('special_description', specialDescStr);
                            row.put('SlNo', coreSlNo++);
                            totalAmount += pdf_base_total;
                            totalGstAmount += pdf_gst_amount;
                            coreTotalAmount += pdf_base_total;
                            coreTotalGst += pdf_gst_amount;
                            coreLineItems.add(row);
                        } else if (String.isNotBlank(cHeader) && String.isNotBlank(cValue)) {
                            row.put('customHeader', insertZeroWidthSpaces(cHeader));
                            row.put('customValue', insertZeroWidthSpaces(cValue));
                            row.put('SlNo', slNo++);
                            totalAmount += pdf_base_total;
                            totalGstAmount += pdf_gst_amount;
                            specialLineItems.add(row);
                        } else {
                            row.put('SlNo', slNo++);
                            totalAmount += pdf_base_total;
                            totalGstAmount += pdf_gst_amount;
                            standardTotalAmount += pdf_base_total;
                            standardTotalGst += pdf_gst_amount;
                            standardLineItems.add(row);
                        }
                        
                        colIndex++; 
                    }
                    
                    for (Map<String, Object> row : standardLineItems) {
                        List<String> sVals = new List<String>();
                        String lengthVal = row.get('special_description_header') != null ? String.valueOf(row.get('special_description_header')).trim() : '';
                        String descVal   = row.get('special_description') != null ? String.valueOf(row.get('special_description')).trim() : '';
                        
                        sVals.add(String.isNotBlank(lengthVal) ? insertZeroWidthSpaces(lengthVal) : '-');
                        sVals.add(String.isNotBlank(descVal)   ? insertZeroWidthSpaces(descVal)   : '-');
                        
                        row.put('specialValuesList', sVals);
                    }

                    if (quoteTotalWeightKg > 0) {
                        if (showPricePerKgFreight) {
                            pricePerKgFreightAmount = ((quoteTotalWeightKg / 1000.0) * transportChargesPerMt).setScale(2, System.RoundingMode.HALF_UP);
                            if (interestMultiplier > 0) {
                                pricePerKgFreightAmount += (pricePerKgFreightAmount * interestMultiplier);
                            }
                            Decimal perKgGst = (pricePerKgFreightAmount * 0.18).setScale(2, System.RoundingMode.HALF_UP);
                            standardTotalAmount += pricePerKgFreightAmount;
                            standardTotalGst    += perKgGst;
                            totalAmount         += pricePerKgFreightAmount;
                            totalGstAmount      += perKgGst;
                        }
                        if (showPerMtLoading) {
                            perMtLoadingAmount = ((quoteTotalWeightKg / 1000.0) * loadingChargesPerMt).setScale(2, System.RoundingMode.HALF_UP);
                            if (interestMultiplier > 0) {
                                perMtLoadingAmount += (perMtLoadingAmount * interestMultiplier);
                            }
                            Decimal loadingGst = (perMtLoadingAmount * 0.18).setScale(2, System.RoundingMode.HALF_UP);
                            standardTotalAmount += perMtLoadingAmount;
                            standardTotalGst    += loadingGst;
                            totalAmount         += perMtLoadingAmount;
                            totalGstAmount      += loadingGst;
                        }
                    }

                    if (showLumpSumFreight) {
                        Decimal freightGst = (lumpSumFreightAmount * 0.18).setScale(2, System.RoundingMode.HALF_UP);
                        standardTotalAmount += lumpSumFreightAmount;
                        standardTotalGst    += freightGst;
                        totalAmount         += lumpSumFreightAmount;
                        totalGstAmount      += freightGst;
                    }

                    if (showLumpsumLoading) {
                        Decimal loadingGst = (lumpsumLoadingAmount * 0.18).setScale(2, System.RoundingMode.HALF_UP);
                        standardTotalAmount += lumpsumLoadingAmount;
                        standardTotalGst    += loadingGst;
                        totalAmount         += lumpsumLoadingAmount;
                        totalGstAmount      += loadingGst;
                    }
                    
                    // ── Determine Quotation Scope (Both / Core Only / Regular Only)
                    for (Object rObj : rawRows) {
                        if (rObj instanceof Map<String, Object>) {
                            Map<String, Object> rMap = (Map<String, Object>) rObj;
                            String qs = rMap.get('quote_scope') != null ? String.valueOf(rMap.get('quote_scope')) : (rMap.get('quoteScope') != null ? String.valueOf(rMap.get('quoteScope')) : '');
                            if (qs == 'core_only') {
                                isCoreOnly = true;
                                break;
                            } else if (qs == 'regular_only') {
                                isRegularOnly = true;
                                break;
                            }
                        }
                    }

                    if (!isCoreOnly && !isRegularOnly && jsonData.containsKey('_configuredPipesDomestic') && jsonData.get('_configuredPipesDomestic') != null) {
                        List<Object> domPipes = (List<Object>) jsonData.get('_configuredPipesDomestic');
                        for (Object dpObj : domPipes) {
                            if (dpObj instanceof Map<String, Object>) {
                                Map<String, Object> dp = (Map<String, Object>) dpObj;
                                String qs = dp.get('quote_scope') != null ? String.valueOf(dp.get('quote_scope')) : (dp.get('quoteScope') != null ? String.valueOf(dp.get('quoteScope')) : '');
                                if (qs == 'core_only') {
                                    isCoreOnly = true;
                                    break;
                                } else if (qs == 'regular_only') {
                                    isRegularOnly = true;
                                    break;
                                }
                            }
                        }
                    }

                    if (!isCoreOnly && !isRegularOnly) {
                        if (!coreLineItems.isEmpty() && !hasStandardPipes) {
                            isCoreOnly = true;
                        } else if (coreLineItems.isEmpty() && hasStandardPipes) {
                            isRegularOnly = true;
                        }
                    }

                    coreTotalFinal     = coreTotalAmount + coreTotalGst;
                    standardTotalFinal = standardTotalAmount + standardTotalGst;

                    if (isCoreOnly) {
                        standardLineItems.clear();
                        standardTotalAmount = 0.00;
                        standardTotalGst    = 0.00;
                        standardTotalFinal  = 0.00;
                        totalAmount         = coreTotalAmount;
                        totalGstAmount      = coreTotalGst;
                        totalFinalAmount    = coreTotalFinal;
                    } else if (isRegularOnly) {
                        coreLineItems.clear();
                        coreTotalAmount     = 0.00;
                        coreTotalGst        = 0.00;
                        coreTotalFinal      = 0.00;
                        totalAmount         = standardTotalAmount;
                        totalGstAmount      = standardTotalGst;
                        totalFinalAmount    = standardTotalFinal;
                    } else {
                        totalAmount         = standardTotalAmount + coreTotalAmount;
                        totalGstAmount      = standardTotalGst + coreTotalGst;
                        totalFinalAmount    = totalAmount + totalGstAmount;
                    }
                }
            } catch (Exception e) {
                System.debug('Error parsing Steel Pipes JSON: ' + e.getMessage());
            }
        }
    }

    public String getContactNo() {
        if (quoteRecord.Contact != null && String.isNotBlank(quoteRecord.Contact.Phone)) {
            return quoteRecord.Contact.Phone;
        }
        return (quoteRecord.Account != null) ? quoteRecord.Account.Phone : '';
    }
    
    private static String strVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return (v != null && String.valueOf(v).trim() != '') ? String.valueOf(v).trim() : '';
    }
    
    private static String defaultIfBlank(String val, String fallback) {
        return String.isNotBlank(val) ? val : fallback;
    }

    private static String formatDmy(String iso) {
        if (String.isBlank(iso)) return iso;
        String t = iso.trim();
        if (t.length() >= 10 && t.mid(4,1) == '-' && t.mid(7,1) == '-') {
            return t.mid(8,2) + '/' + t.mid(5,2) + '/' + t.left(4);
        }
        return t;
    }

    private static String boldClausePrefix(String t) {
        if (String.isBlank(t)) return t;
        Integer idx = t.indexOf(':');
        if (idx > 0 && idx < 60) {
            return '<b>' + t.substring(0, idx + 1) + '</b>' + t.substring(idx + 1);
        }
        return t;
    }

    private static Decimal decVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        if (v == null) return 0;
        String s = String.valueOf(v).trim();
        if (s == '' || s == 'null') return 0;
        try { return Decimal.valueOf(s); } catch (Exception e) { return 0; }
    }
    
    private String insertZeroWidthSpaces(String input) {
        if (String.isBlank(input)) return input;
        
        String result = '';
        Integer count = 0;
        for (Integer i = 0; i < input.length(); i++) {
            String c = input.substring(i, i+1);
            result += c;
            if (c == ' ' || c == '-' || c == '_') {
                count = 0;
            } else {
                count++;
                if (count >= 10) {
                    result += '<br/>';
                    count = 0;
                }
            }
        }
        return result;
    }
}