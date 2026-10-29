public class QuoteExportControllerForSTP {
    public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
    // CHANGE: Replaced flat lineItems list with a structured list of tables
    public List<TableWrapper> tables { get; set; } 
    public Decimal totalAmount { get; set; }
    public String totalAmountInWords { get; set; }
    public String todayDate { get; set; }
    public String accountName { get; set; }
    public String contactName { get; set; }
    public String contactNumber { get; set; }
    public String contactEmail { get; set; }
    public String quoteNotes { get; set; }
    public String referenceNum { get; set; }
    public String designation { get; set; }
    
    // Terms and Condition
    public String remaining_payment_per { get; set; }
    public Integer payment_per { get; set; }
    public String gst {get; set;} 
    public String validityDays {get; set;} 
    public String consignmentStart {get; set;}
    public String consignmentEnd {get; set;}
    public String priceVariation {get; set;}
    public String paymentTermsPicklist {get; set;} 
    public String lcBuyerInterestDays {get; set;}
    public String lcSellerInterestDays {get; set;}
    public String lcInterestDays {get; set;}
    public String vfsSellerinterest {get; set;}
    public String vfsInterestDays {get; set;}
    public String openCreditDays {get; set;}
    public String transportMode { get; set; }
	public String forMode       { get; set; }
	public String lumpSumValue  { get; set; }
    public Boolean isBudgetary { get; set; }

    public String loggedInUser {get; set;}
    public String loggedInUserPhone {get; set;}
    public String loggedInUserEmail {get; set;}
    
    public String frontPageBase64 { get; set; }
    public String logoBase64 { get; set; }
    public String lastPageBase64 { get; set; }
    
    public String priceVariationYear { get; set; }
    public String priceVariationMonthName { get; set; }
    
    // CHANGE: Added Inner Wrapper Class to hold each Table's specific data
    public class TableWrapper {
        public String tableName { get; set; }
        public List<Map<String, Object>> lineItems { get; set; }
        public Decimal tableSubTotal { get; set; }
        public String additionalNote { get; set; }

        public TableWrapper(String name) {
            this.tableName = name;
            this.lineItems = new List<Map<String, Object>>();
            this.tableSubTotal = 0.00;
        }
    }
    
    public QuoteExportControllerForSTP(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        
        frontPageBase64 = getBase64FromStaticResource('SteelTubularPoleDepartmentFrontPageDoc');
        logoBase64 = getBase64FromStaticResource('UtkarshLogo');
        lastPageBase64 = getBase64FromStaticResource('SteelTubularPoleDepartmentLastPageDoc');
        
        System.debug('»»» INITIALIZING QuoteExportControllerForSTP for Record ID: ' + quoteId);
        
        quoteRecord = [SELECT Id, Name, QuoteNumber, Quote_Value__c, 
                              Account.Name, 
                              Contact.Name, Contact.Phone, Contact.Email, Opportunity.Account.Name, Opportunity.Account.Phone,
                       			Opportunity.Account.Email__c , Quote_Reference__c 
                       FROM Quote WHERE Id = :quoteId];
        
        User currentUser =  [SELECT Id, Name, Phone, Email, Department, Title, ManagerId, IsActive 
                            FROM User 
                            WHERE Id = :UserInfo.getUserId()
                            LIMIT 1 ];

        loggedInUser = currentUser.Name;
        loggedInUserPhone = currentUser.Phone;
        loggedInUserEmail = currentUser.Email;        
        
        if (quoteRecord.Account != null) {
            contactName = String.isNotBlank(quoteRecord.Opportunity.Account.Name) ? quoteRecord.Opportunity.Account.Name : 'Name - Test Name Shubhas Khatri';
            contactNumber = String.isNotBlank(quoteRecord.Opportunity.Account.Phone) ? quoteRecord.Opportunity.Account.Phone : 'Contact - +91 87XXXXXXXX';
            contactEmail = String.isNotBlank(quoteRecord.Opportunity.Account.Email__c) ? quoteRecord.Opportunity.Account.Email__c : 'Email - test@testemail.com';  
        } else {
            contactName = 'Name - Test Name Shubhas Khatri';
            contactNumber = 'Contact - +91 87XXXXXXXX';
            contactEmail = 'Email - test@testemail.com';
        }

        accountName = quoteRecord.Account != null ? quoteRecord.Account.Name : 'Test Account Record';
        totalAmount = 0.00;
        referenceNum = quoteRecord.Quote_Reference__c  != null ? quoteRecord.Quote_Reference__c  : '';
        
        // CHANGE: Initialize the master tables collection
        this.tables = new List<TableWrapper>();
        todayDate = Date.today().format();
        jsonData = new Map<String, Object>();
        
        Date priceVariationRefDate = Date.today().addMonths(1);
        priceVariationYear = String.valueOf(priceVariationRefDate.year());
        priceVariationMonthName = Datetime.newInstance(priceVariationRefDate.year(), priceVariationRefDate.month(), 1).format('MMMM');
        
        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);

                if (jsonData.containsKey('tc_payment_terms_pct') && jsonData.get('tc_payment_terms_pct') != null) {
                    payment_per = Integer.valueOf(String.valueOf(jsonData.get('tc_payment_terms_pct')));
                    remaining_payment_per = String.valueOf(100 - payment_per);
                }
                
                if (jsonData.containsKey('tc_gst') && jsonData.get('tc_gst') != null) {
                    gst = castToString(jsonData.get('tc_gst'));
                }
                
                if (jsonData.containsKey('tc_validity_days') && jsonData.get('tc_validity_days') != null) {
                    validityDays = castToString(jsonData.get('tc_validity_days'));
                }
                
                if (jsonData.containsKey('tc_payment_terms_picklist') && jsonData.get('tc_payment_terms_picklist') != null) {
                    paymentTermsPicklist = castToString(jsonData.get('tc_payment_terms_picklist'));
                    if(paymentTermsPicklist == 'Against LC Before Dispatch'){
                        paymentTermsPicklist = paymentTermsPicklist + ' Usance Interest in Buyer\'s scope - '+ castToString(jsonData.get('tc_lc_buyer_interest_days'))+' Days ( No. of LC Interest days - ' +castToString(jsonData.get('tc_lc_interest_days'))+'%)' ;
                    }
                    if(paymentTermsPicklist == 'Against VFS'){
                        paymentTermsPicklist = paymentTermsPicklist + ' Usance Interest in Seller\'s scope - ' + castToString(jsonData.get('tc_vfs_seller_interest')) + '% in ' + castToString(jsonData.get('tc_vfs_interest_days')) + ' Days';
                    }
                    if(paymentTermsPicklist == 'Against Open Credit'){
                        paymentTermsPicklist = paymentTermsPicklist+ ' '+ castToString(jsonData.get('tc_open_credit_days'))  + ' Days'; 
                    }
                }
                
                if (jsonData.containsKey('tc_consignment_start') && jsonData.get('tc_consignment_start') != null) {
                    consignmentStart = CurrencyInWords.convertNumberOnly(castToDecimal(jsonData.get('tc_consignment_start')));
                }
                
                if (jsonData.containsKey('tc_consignment_end') && jsonData.get('tc_consignment_end') != null) {
                    consignmentEnd = CurrencyInWords.convertNumberOnly(castToDecimal(jsonData.get('tc_consignment_end')));
                }
                
                if (jsonData.containsKey('incoterms') && jsonData.get('incoterms') != null) {
                    transportMode = castToString(jsonData.get('incoterms')).trim();
                }
                
                if (jsonData.containsKey('final_for') && jsonData.get('final_for') != null) {
                    forMode = castToString(jsonData.get('final_for')).trim();
                }
                
                if (jsonData.containsKey('lumpsum') && jsonData.get('lumpsum') != null) {
                    lumpSumValue = castToString(jsonData.get('lumpsum')).trim();
                }
                
               
                String typeOfPole = jsonData.containsKey('type_of_pole') ? castToString(jsonData.get('type_of_pole')) : 'Standard Pole';
                // check budgetary
                isBudgetary = jsonData.containsKey('type_of_pole') ? castToBoolean(jsonData.get('tc_budgetary')) : false;
                
                List<String> operationalKeys;
                Map<String, String> designatorPrefixMap = new Map<String, String>();

                if (typeOfPole == 'Customized Pole') {
                    operationalKeys = new List<String>{'c1_ms_gi', 'c2_ms_gi', 'c3_ms_gi'};
                    designatorPrefixMap.put('c1_ms_gi', 'c1_');
                    designatorPrefixMap.put('c2_ms_gi', 'c2_');
                    designatorPrefixMap.put('c3_ms_gi', 'c3_');
                } else {
                    operationalKeys = new List<String>{'ms_gi_1', 'ms_gi_2', 'ms_gi_3'};
                    designatorPrefixMap.put('ms_gi_1', 'd1_');
                    designatorPrefixMap.put('ms_gi_2', 'd2_');
                    designatorPrefixMap.put('ms_gi_3', 'd3_');
                }
                
                Map<String, Pole_Specifications__mdt> metadataMap = new Map<String, Pole_Specifications__mdt>();
                if (typeOfPole != 'Customized Pole') {
                    Set<String> designationsToQuery = new Set<String>();
                    for (String key : operationalKeys) {
                        String prefix = designatorPrefixMap.get(key);
                        String designText = castToString(jsonData.get(prefix + 'designation'));
                        if (String.isNotBlank(designText)) {
                            designationsToQuery.add(designText);
                        }
                    }
                    if (!designationsToQuery.isEmpty()) {
                        for (Pole_Specifications__mdt spec : [SELECT Designation__c, Top_Specs__c, Middle_Specs__c, Bottom_Specs__c 
                                                              FROM Pole_Specifications__mdt 
                                                              WHERE Designation__c IN :designationsToQuery]) {
                            metadataMap.put(spec.Designation__c, spec);
                        }
                    }
                }
				// CHANGE: Counter to dynamically name sequential Custom Pole tables
                Integer customTableCount = 1;
                
                // 2. Core Matrix Line-Item Loop
                for (String materialPresenceKey : operationalKeys) {
                    Object materialPresenceVal = jsonData.get(materialPresenceKey);
                    
                    if (materialPresenceVal != null && castToString(materialPresenceVal) != '') {
                        
                        String prefix = designatorPrefixMap.get(materialPresenceKey);
                        String materialLabel = castToString(materialPresenceVal);
                        String designText = castToString(jsonData.get(prefix + 'designation'));
                        String poleDesc = '';
                        
                        // CHANGE: Dynamically determine the exact string for the table names
                        String computedTableName = '';
                        if (typeOfPole == 'Customized Pole') {
                            computedTableName = 'Custom - ' + customTableCount;
                            customTableCount++; // Increment index map only when tracking a custom table instance
                        } else {
                            computedTableName = 'Designation - ' + designText;
                        }

                        TableWrapper currentTable = new TableWrapper(computedTableName);
                        
                        Integer slNo = 1; // CHANGE: Reset serial counter so every table starts fresh at 1
                        
                        if (prefix.startsWith('d')) {
                            if (metadataMap.containsKey(designText)) {
                                Pole_Specifications__mdt poleSpecs = metadataMap.get(designText);
                                String topSectionDetails    = String.isNotBlank(poleSpecs.Top_Specs__c) ? poleSpecs.Top_Specs__c : '-';
                                String middleSectionDetails = String.isNotBlank(poleSpecs.Middle_Specs__c) ? poleSpecs.Middle_Specs__c : '-';
                                String bottomSectionDetails = String.isNotBlank(poleSpecs.Bottom_Specs__c) ? poleSpecs.Bottom_Specs__c : '-';
                                
                                poleDesc = designText + ' (' + materialLabel + ') Steel Tubular Pole with and having pipe dimensions :- \n' +
                                           'Bottom :- ' + bottomSectionDetails + '\n' + ' Middle :- ' + middleSectionDetails + '\n' + ' Top :- ' + topSectionDetails;
                            }
                        }
                        
                        if (prefix.startsWith('c')) {
                            Integer sectionsForDes = Integer.valueOf(castToDecimal(jsonData.get(prefix + 'sections')));
                            List<String> sectionDescriptions = new List<String>();
                            
                            if (sectionsForDes >= 2) {
                                sectionDescriptions.add('Bottom :- ' + castToString(jsonData.get(prefix + 'bot_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'bot_thk')) + ' mm thk x ' + castToString(jsonData.get(prefix + 'bot_len')) + ' mtr long');
                            }
                            if (sectionsForDes >= 3) {
                                sectionDescriptions.add('Middle 2 :- ' + castToString(jsonData.get(prefix + 'mid2_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'mid2_thk')) + ' mm thk x ' + castToString(jsonData.get(prefix + 'mid2_len')) + ' mtr long');
                            }
                            if (sectionsForDes >= 4) {
                                sectionDescriptions.add('Middle 3 :- ' + castToString(jsonData.get(prefix + 'mid3_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'mid3_thk')) + ' mm thk x ' + castToString(jsonData.get(prefix + 'mid3_len')) + ' mtr long');
                            }
                            if (sectionsForDes >= 5) {
                                sectionDescriptions.add('Middle 4 :- ' + castToString(jsonData.get(prefix + 'mid4_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'mid4_thk')) + ' mm thk x ' + castToString(jsonData.get(prefix + 'mid4_len')) + ' mtr long');
                            }
                            // Optimized: Dynamic prefix handling to avoid repeating the long dimensions string
                            String labelPrefix = (sectionsForDes == 1) ? 'Pole Dimension :- ' : 'Top :- ';
                            sectionDescriptions.add(labelPrefix + castToString(jsonData.get(prefix + 'top_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'top_thk')) + ' mm thk x ' + castToString(jsonData.get(prefix + 'top_len')) + ' mtr long');
                            
                            poleDesc = materialLabel + ' Steel Tubular Pole with and having pipe dimensions :- ' + String.join(sectionDescriptions, '\n');
                            
                            // Reused utility method logic to append (Swan) cleanly
                            if (castToBoolean(jsonData.get(prefix + 'swan'))) {
                                poleDesc += ' (Swan)';
                            }
                        }
                        
                        // check additional Note
                        currentTable.additionalNote = castToString(jsonData.get(prefix + 'ad_add_note'));
                        if(String.isBlank(currentTable.additionalNote)) currentTable.additionalNote = null;

                        Decimal poleLength = castToDecimal(jsonData.get(prefix + 'base_length'));
                        if (poleLength == 0.0 && jsonData.containsKey('cp_height_' + prefix.substring(1,2))) {
                            poleLength = castToDecimal(jsonData.get('cp_height_' + prefix.substring(1,2)));
                        }

                        Decimal poleQty = castToDecimal(jsonData.get(prefix + 'quantity'));
                        Decimal poleRate = Math.Round(castToDecimal(jsonData.get(prefix + 'rate')));
                        Decimal poleTotal = castToDecimal(jsonData.get(prefix + 'final_total_amount'));
                        
                        if (poleTotal == 0.0 && typeOfPole == 'Customized Pole') {
                            poleTotal = castToDecimal(jsonData.get(prefix + 'final_total_amount'));
                        }
                        system.debug('Final total amount' + poleTotal + ' ' + castToDecimal(jsonData.get('d1_final_total_amount')));
                        
                        // Base Plate Component
                        Decimal bpLengthMtr = castToDecimal(jsonData.get(prefix + 'bp_ms_gi_length'));
                        Decimal bpWidthMtr  = castToDecimal(jsonData.get(prefix + 'bp_ms_gi_width'));
                        Decimal bpThkMm     = castToDecimal(jsonData.get(prefix + 'bp_ms_gi_thickness'));
                            
                        Decimal bpLengthMm = bpLengthMtr * 1000;
                        Decimal bpWidthMm  = bpWidthMtr * 1000;
                        String bpDesc = 'Base Plate - ' + bpLengthMm + ' mm x ' + bpWidthMm + ' mm x ' + bpThkMm + ' mm';
                        
                        Boolean bpCheck = castToBoolean(jsonData.get(prefix + 'bp_ms_gi'));
                        Boolean bpReflectBool = castToBoolean(jsonData.get(prefix + 'bp_ms_gi_reflect'));
                        String bpReflectStr = castToString(jsonData.get(prefix + 'bp_ms_gi_reflect'));

                        if (bpCheck && bpReflectStr == 'NO') {
                            poleDesc += '\n' + bpDesc;
                            poleRate += ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ms_gi_rate')));
                        }
                        
                        // Sister Plate Component
                        Decimal spLengthMtr = castToDecimal(jsonData.get(prefix + 'bp_sp_length'));
                        Decimal spWidthMtr  = castToDecimal(jsonData.get(prefix + 'bp_sp_width'));
                        Decimal spThkMm     = castToDecimal(jsonData.get(prefix + 'bp_sp_thickness'));
                            
                        Decimal spLengthMm = spLengthMtr * 1000;
                        Decimal spWidthMm  = spWidthMtr * 1000;
                        String spDesc = 'Sister Plate - ' + spLengthMm + ' mm x ' + spWidthMm + ' mm x ' + spThkMm + ' mm';
                        
                        Boolean spCheck = castToBoolean(jsonData.get(prefix + 'bp_sister_plate'));
                        Boolean spReflectBool = castToBoolean(jsonData.get(prefix + 'bp_sp_reflect'));
                        String spReflectStr = castToString(jsonData.get(prefix + 'bp_sp_reflect'));

                        if (spCheck && spReflectStr == 'NO') {
                            poleDesc += '\n' + spDesc;
                            poleRate += ceilFx(castToDecimal(jsonData.get(prefix + 'bp_sp_rate')));
                        }
                        
                        // Cast Iron IS Component — compute description + flags up front
                        String ciIsDesc = 'Cast Iron (IS) - ' + castToString(jsonData.get(prefix + 'bp_ci_is_dia')) + ' OD (inches)';
                        Boolean ciIsCheck = castToBoolean(jsonData.get(prefix + 'bp_cast_iron_is'));
                        Boolean ciIsReflectBool = castToBoolean(jsonData.get(prefix + 'bp_ci_is_reflect'));
                        String ciIsReflectStr = castToString(jsonData.get(prefix + 'bp_ci_is_reflect'));

                        if (ciIsCheck && ciIsReflectStr == 'NO') {
                            poleDesc += '\n' + ciIsDesc;
                            poleRate += ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_is_rate')));
                        }

                        // Cast Iron Commercial Component — compute description + flags up front
                        String ciCommDesc = 'Cast Iron (Commercial) - ' + castToString(jsonData.get(prefix + 'bp_ci_comm_dia')) + ' OD (inches)';
                        Boolean ciCommCheck = castToBoolean(jsonData.get(prefix + 'bp_cast_iron_comm'));
                        Boolean ciCommReflectBool = castToBoolean(jsonData.get(prefix + 'bp_ci_comm_reflect'));
                        String ciCommReflectStr = castToString(jsonData.get(prefix + 'bp_ci_comm_reflect'));

                        if (ciCommCheck && ciCommReflectStr == 'NO') {
                            poleDesc += '\n' + ciCommDesc;
                            poleRate += ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_comm_rate')));
                        }
                        
                        System.debug('******line 240 '+ ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_comm_rate'))) + ' ' + ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_is_rate'))) + ' ' + ceilFx(castToDecimal(jsonData.get(prefix + 'bp_sp_rate'))) + ' ' + ceilFx(castToDecimal(jsonData.get(prefix + 'bp_sp_rate'))));
                        
                        // handle swarn when reflect No
                        List<String> swanReflectSuffixes = new List<String>{'ss_reflect', 'ds_reflect', 'ts_reflect'};
                        List<String> swanCheckSuffixes   = new List<String>{'swan_single', 'swan_double', 'swan_triple'};
                        List<String> swanDescLabels      = new List<String>{'Single arm (Swan neck type)', 'Double arm (Swan neck type)', 'Triple arm (Swan neck type)'};
                        List<String> swShorts = new List<String>{'s', 'd', 't'};
                        
                        for (Integer idx = 0; idx < swanCheckSuffixes.size(); idx++) {
                            Boolean swanDescCheck     = castToBoolean(jsonData.get(prefix + swanCheckSuffixes[idx]));
                            String  swanDescReflectStr = castToString(jsonData.get(prefix + swanReflectSuffixes[idx]));
                        
                            if (swanDescCheck && swanDescReflectStr == 'NO') {
                                String swanDescLen = castToString(jsonData.get(prefix + 'swan_length'));
                                String swanDesc = castToString(jsonData.get(prefix + 'swan_ms_gs')) + ' ' + swanDescLabels[idx] + ' - '
                                                 + castToString(jsonData.get(prefix + 'swan_dia')) + ' OD x '
                                                 + castToString(jsonData.get(prefix + 'swan_thickness')) + ' mm thk x '
                                                 + swanDescLen + ' mtr long';
                                poleDesc += '\n' + swanDesc;
                                poleRate += ceilFx(castToDecimal(jsonData.get(prefix + 'swan_' + swShorts[idx] + '_rate')));
                            }
                        }
                        
                        // CHANGE: Pass table wrapper context down to track specific subtotal
                        addRowToSpecificTable(currentTable, slNo++, poleDesc, poleLength > 0 ? poleLength + ' mtr long' : '-', poleQty, ceilFx(poleRate), poleTotal);

                        if (castToBoolean(jsonData.get(prefix + 'bp_ms_gi')) && castToBoolean(jsonData.get(prefix + 'bp_ms_gi_reflect'))) {
                            Decimal bpQty = castToDecimal(jsonData.get(prefix + 'bp_ms_gi_quantity'));
                            Decimal bpRate = ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ms_gi_rate')));
                            Decimal bpTotal = castToDecimal(jsonData.get(prefix + 'bp_ms_total_amount'));
                        
                            addRowToSpecificTable(currentTable, slNo++, bpDesc, bpLengthMtr > 0 ? bpLengthMtr + ' mtr long' : '-', bpQty, bpRate, bpTotal);
                        }

                        if (castToBoolean(jsonData.get(prefix + 'bp_sister_plate')) && castToBoolean(jsonData.get(prefix + 'bp_sp_reflect'))) {
                            Decimal spQty   = castToDecimal(jsonData.get(prefix + 'bp_sp_quantity'));
                            Decimal spRate  = ceilFx(castToDecimal(jsonData.get(prefix + 'bp_sp_rate')));
                            Decimal spTotal = castToDecimal(jsonData.get(prefix + 'sp_total_amount'));
                        
                            addRowToSpecificTable(currentTable, slNo++, spDesc, spLengthMtr > 0 ? spLengthMtr + ' mtr long' : '-', spQty, spRate, spTotal);
                        }

                        // Cast Iron IS Component
                        if (castToBoolean(jsonData.get(prefix + 'bp_cast_iron_is')) && castToBoolean(jsonData.get(prefix + 'bp_ci_is_reflect'))) {
                            addRowToSpecificTable(currentTable, slNo++, ciISDesc, '-', castToDecimal(jsonData.get(prefix + 'bp_ci_is_quantity')), ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_is_rate'))), castToDecimal(jsonData.get(prefix + 'cast_iron_total_amount')));
                        }

                        // Cast Iron Commercial Component
                        if (castToBoolean(jsonData.get(prefix + 'bp_cast_iron_comm')) && castToBoolean(jsonData.get(prefix + 'bp_ci_comm_reflect'))) {
                            addRowToSpecificTable(currentTable, slNo++, ciCommDesc, '-', castToDecimal(jsonData.get(prefix + 'bp_ci_comm_quantity')), ceilFx(castToDecimal(jsonData.get(prefix + 'bp_ci_comm_rate'))), castToDecimal(jsonData.get(prefix + 'cast_iron_comm_total_amount')));
                        }
                      
                        // Standard Arm Brackets Engine
                        if(castToString(jsonData.get(prefix + 'br_ms_gs')) != ''){
                            List<String> brKeys = new List<String>{'single_arm', 'double_arm', 'triple_arm', 'four_arm', 'ring_arm'};
                            List<String> brLabels = new List<String>{'single arm bracket', 'Double arm bracket', 'Triple arm bracket', 'Four arm bracket', 'ring arm bracket'};
                            List<String> brShorts = new List<String>{'sa', 'da', 'ta', 'fa', 'ra'};
                            
                            for (Integer i = 0; i < brKeys.size(); i++) {
                                if (castToBoolean(jsonData.get(prefix + 'br_' + brKeys[i]))) {
                                    String len = castToString(jsonData.get(prefix + 'br_length'));
                                    String descrip = castToString(jsonData.get(prefix + 'br_ms_gs'))+' ' + brLabels[i] + ' ' + castToString(jsonData.get(prefix + 'br_dia')) + ' OD x ' + castToString(jsonData.get(prefix + 'br_thickness')) + ' mm thk x ' + len + ' mtr long';
                                    addRowToSpecificTable(currentTable, slNo++, descrip, String.isNotBlank(len) ? len + ' mtr long' : '-', castToDecimal(jsonData.get(prefix + 'br_' + brShorts[i] + '_quantity')), ceilFx(castToDecimal(jsonData.get(prefix + 'br_' + brShorts[i] + '_rate'))), castToDecimal(jsonData.get(prefix + 'br_' + brShorts[i] + '_total_amount')));
                                }
                            }
                        }
                                                
                        // Swan Arm Brackets Engine
                        if(castToString(jsonData.get(prefix + 'swan_ms_gs')) != ''){
                            List<String> swKeys = new List<String>{'single', 'double', 'triple'};
                            List<String> swLabels = new List<String>{'Single arm (Swan)', 'Double arm (Swan)', 'Triple arm (Swan)'};
                            //List<String> swShorts = new List<String>{'s', 'd', 't'};
                            List<String> swReflectSuffixes = new List<String>{'ss_reflect', 'ds_reflect', 'ts_reflect'}; // ADDED
                            
                            for (Integer i = 0; i < swKeys.size(); i++) {
                                if (castToBoolean(jsonData.get(prefix + 'swan_' + swKeys[i]))) {
                                    
                                    String swReflectStr = castToString(jsonData.get(prefix + swReflectSuffixes[i]));
                                    if (swReflectStr == 'NO') {
                                        continue;
                                    }
                                    String len = castToString(jsonData.get(prefix + 'swan_length'));
                                    String descrip = castToString(jsonData.get(prefix + 'swan_ms_gs'))+ ' ' + swLabels[i] + ' - '+ castToString(jsonData.get(prefix + 'swan_dia')) + ' OD x ' + castToString(jsonData.get(prefix + 'swan_thickness')) + ' mm thk x ' + len + ' mtr long';
                                    addRowToSpecificTable(currentTable, slNo++, descrip, String.isNotBlank(len) ? len + ' mtr long' : '-', castToDecimal(jsonData.get(prefix + 'swan_' + swShorts[i] + '_qty')), ceilFx(castToDecimal(jsonData.get(prefix + 'swan_' + swShorts[i] + '_rate'))), castToDecimal(jsonData.get(prefix + 'swan_' + swShorts[i] + 'a_total_amount')));
                                }
                            }
                        }
                        
                        // Foundation Bolts
                        if (castToBoolean(jsonData.get(prefix + 'fb_check'))) {
                            Decimal fbLen = castToDecimal(jsonData.get(prefix + 'fb_length'));
                            Decimal fbLenInMtr = castToDecimal(fbLen/1000);
                            addRowToSpecificTable(currentTable, slNo++, 'Foundation Bolts - M' + castToString(jsonData.get(prefix + 'fb_dia')) + ' x ' + fbLen + ' ('+ castToString(jsonData.get(prefix + 'fb_qty')) +' Nos. in one set)', fbLenInMtr + ' mtr long', castToDecimal(jsonData.get(prefix + 'fb_quantity')), ceilFx(castToDecimal(jsonData.get(prefix + 'fb_rate'))), castToDecimal(jsonData.get(prefix + 'foundation_total_amount')));
                        }

                        // Cable Entry Pipe
                        if (castToBoolean(jsonData.get(prefix + 'ad_cep_check'))) {
                            String cepLen = castToString(jsonData.get(prefix + 'ad_cep_length'));
                            String cepDesc = 'Cable entry pipe - ' + castToString(jsonData.get(prefix + 'ad_cep_dia')) + ' mm OD x ' + castToString(jsonData.get(prefix + 'ad_cep_thickness')) + ' mm thk x ' + cepLen + ' mtr long ( '+ castToString(jsonData.get(prefix + 'ad_cep_qty')) +' Nos. in one set)';
                            addRowToSpecificTable(currentTable, slNo++, cepDesc, String.isNotBlank(cepLen) ? cepLen + ' mtr long' : '-', castToDecimal(jsonData.get(prefix + 'fb_ad_cep_quantity')), ceilFx(castToDecimal(jsonData.get(prefix + 'ad_cep_rate'))), castToDecimal(jsonData.get(prefix + 'addi_total_amount')));
                        }
                        
                        // Transportation Lump Sum Row (added last, after all components)
                        if (transportMode == 'Freight' && forMode == 'Lump sum' && String.isNotBlank(lumpSumValue)) {
                            Decimal lumpAmount = castToDecimal(lumpSumValue);
                            addRowToSpecificTable(
                                currentTable,
                                slNo++,
                                'Transportation Charges (Lump Sum)',
                                '-',
                                1,
                                lumpAmount,
                                lumpAmount
                            );
                        }


                        // CHANGE: Append the populated table package to our collection
                        if (!currentTable.lineItems.isEmpty()) {
                            this.tables.add(currentTable);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('»»» FATAL RUNTIME ERROR: ' + e.getMessage() + ' At Line: ' + e.getLineNumber());
            }
        }
        
        totalAmountInWords = CurrencyInWords.convertToIndianRupees(totalAmount);
        
        Map<String, String> staticDefaults = new Map<String, String>{
            'Contact_Person' => 'Balindra Kushwaha', 'ba_phone' => '8001611112',
            'ba_email' => 'balindra.ssml@shyamsteel.industries', 'ba_website' => 'shaymsteelsindustries.com',
            'tc_validity_days' => '2', 'tc_payment_terms_pct' => '30',
            'tc_price_variation' => 'Rates offered are variable.\nWe will try to complete the delivery within offered time.',
            'tc_payment_terms_picklist' => '30% advance against P.O. & remaining on readiness of materials.'
        };
        for(String key : staticDefaults.keySet()){
            ensureKey(key, staticDefaults.get(key));
        }
    }

    // CHANGE: Modified helper signature to handle table packages contextually
    private void addRowToSpecificTable(TableWrapper targetTable, Integer slNo, String descrip, String lengthVal, Decimal qty, Decimal rate, Decimal total) {
        Decimal clearTotal = (total != null) ? total : 0.00;
        
        // Accumulate context totals
        targetTable.tableSubTotal += clearTotal; // Local Subtotal
        this.totalAmount += clearTotal;          // Global Grand Total
        
        targetTable.lineItems.add(new Map<String, Object>{
            'SlNo' => slNo, 'description' => descrip, 'length' => lengthVal,
            'quantity' => qty, 'rate' => rate, 'total_price' => clearTotal
        });
    }

    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key) || jsonData.get(key) == null || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }

    private static Decimal castToDecimal(Object obj) {
        if (obj == null) return 0.0;
        if (obj instanceof Decimal) return (Decimal)obj;
        if (obj instanceof Integer) return Decimal.valueOf((Integer)obj);
        String str = String.valueOf(obj).trim();
        return str == '' ? 0 : Decimal.valueOf(str);
    }

    private static Boolean castToBoolean(Object obj) {
        if (obj == null) return false;
        if (obj instanceof Boolean) return (Boolean)obj;
        String strVal = String.valueOf(obj).toLowerCase().trim();
        return (strVal == 'true' || strVal == 'yes' || strVal == '1');
    }

    private static String castToString(Object obj) {
        return obj == null ? '' : String.valueOf(obj);
    }
    
    private static Decimal ceilFx(Decimal num) {
        return (Math.ceil(num/10) * 10);
    }
    
    private String getBase64FromStaticResource(String resourceName) {
        try {
            StaticResource sr = [SELECT Body, ContentType FROM StaticResource WHERE Name = :resourceName LIMIT 1];
            return 'data:' + sr.ContentType + ';base64,' + EncodingUtil.base64Encode(sr.Body);
        } catch(Exception e) {
            System.debug('Error loading static resource: ' + e.getMessage());
            return '';
        }
    }
}