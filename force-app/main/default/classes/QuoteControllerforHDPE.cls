public class QuoteControllerforHDPE {
    // SObject & Parsing Data
    public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
    public List<TableWrapper> tables { get; set; }
    
    // Header Info
    public Decimal totalAmount { get; set; }
    public String totalAmountInWords { get; set; }
    public String todayDate { get; set; }
    public String accountName { get; set; }
    public String contactName { get; set; }
    public String contactNumber { get; set; }
    public String contactEmail { get; set; }
    public String referenceNum { get; set; }
    public String accAdd { get; set; }
    public String subjectLine { get; set; }
    
    // Dynamic Terms and Conditions
    public String itemOffered { get; set; }
    public String freightBasis { get; set; }
    public String packingForwarding { get; set; }
    public String inspectionTerms { get; set; }
    public String loadingCharges { get; set; }
    public Decimal gstPercentage { get; set; }
    public Decimal tcsPercentage { get; set; }
    public String paymentTerms { get; set; }
    public Decimal delayInterestPercentage { get; set; }
    public Integer groundRentDays { get; set; }
    public Decimal groundRentPercentage { get; set; }
    public String validityTerms { get; set; }
    public String deliveryPeriod { get; set; }
    public String warrantyMonths { get; set; }
    public String warrantyEndMonth { get; set; }
    public String priceVariationClause { get; set; }
    public String testCertificate { get; set; }
    public String insuranceTerms { get; set; }

    // User Session Metadata
    public String loggedInUser { get; set; }
    public String loggedInUserPhone { get; set; }
    public String loggedInUserTitle { get; set; }
    public String loggedInUserEmail { get; set; }
    
    // Assets (Images/PDF Backdrops)
    public String frontPageBase64 { get; set; }
    public String logoBase64 { get; set; }
    public String lastPageBase64 { get; set; }
    
    // Table Specific Control Variables & Component Backing Arrays
    public String standard { get; set; }
    public Boolean showPipeTable { get; set; }
    public Boolean showDuctTable { get; set; }
    public Boolean hasAccessories { get; set; }
    
    // NEW BLOCK B UNIFIED TRACKING
    public List<ImprovisedRow> unifiedRows { get; set; }
    public Decimal blockBBasicTotal { get; set; }
    public Decimal blockBGstAmount { get; set; }
    public Decimal blockBFinalAmount { get; set; }
    public Decimal blockBGstPercent { get; set; }
    public Decimal blockBTransportationCharge { get; set; }
    public String blockBTableName { get; set; }
    
    public String destinationLocation { get; set; }
    public String plbDuctTransportText { get; set; }
    public String pipeDuctDuctTransportText { get; set; }
    public String pipeDuctPipeTransportText { get; set; }
    public String is4984TransportText { get; set; }
    public String mdpeTransportText { get; set; }

    public class ImprovisedRow {
        public Integer slNo { get; set; }
        public String particular { get; set; }
        public String uom { get; set; }
        public Decimal qty { get; set; }
        public Decimal rate { get; set; }
        public Decimal basic { get; set; }
    }

    public class TableWrapper {
        public String tableName { get; set; }
        public List<Map<String, Object>> lineItems { get; set; }
        public Decimal tableGrossTotal { get; set; }
        public Decimal tableSubTotal { get; set; }
        public Decimal gst { get; set; }
        public Decimal gstAmount { get; set; }
        public Decimal transportationCharge { get; set; }
        
        public TableWrapper(String name) {
            this.tableName = name;
            this.lineItems = new List<Map<String, Object>>();
            this.tableGrossTotal = 0.00;
            this.tableSubTotal = 0.00;
            this.gst = 18.00; 
            this.gstAmount = 0.00;
            this.transportationCharge = 0.00;
        }
    }
    
    public QuoteControllerforHDPE(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.tables = new List<TableWrapper>();
        this.todayDate = Date.today().format();
        this.totalAmount = 0.00;
        this.hasAccessories = false;
        Decimal maxPipeLength = 0;

        frontPageBase64 = getBase64FromStaticResource('HDPE_front_Page_DOC');
        logoBase64 = getBase64FromStaticResource('UtkarshLogo');
        lastPageBase64 = getBase64FromStaticResource('SteelTubularPoleDepartmentLastPageDoc');

        quoteRecord = [SELECT Id, Name, QuoteNumber, Quote_Value__c, 
                              Account.Name, Account.BillingStreet, Account.BillingCity, 
                              Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                              Contact.Name, Contact.Phone, Contact.Email 
                       FROM Quote WHERE Id = :quoteId LIMIT 1];
                       
        User currentUser = [SELECT Id, Name, Email, MobilePhone, Title FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        loggedInUser = currentUser.Name;
        loggedInUserPhone = String.isNotBlank(currentUser.MobilePhone) ? currentUser.MobilePhone : '+91 8767567895';
        loggedInUserTitle = String.isNotBlank(currentUser.Title) ? currentUser.Title : 'AGM – Project Sales (Polymer)';
        loggedInUserEmail = String.isNotBlank(currentUser.Email) ? currentUser.Email : 'testEmail@temail.com';
        
        if (quoteRecord.Contact != null) {
            contactName = String.isNotBlank(quoteRecord.Contact.Name) ? quoteRecord.Contact.Name : 'Test Name Shubhas Khatri';
            contactNumber = String.isNotBlank(quoteRecord.Contact.Phone) ? quoteRecord.Contact.Phone : 'Contact - +91 87XXXXXXXX';
            contactEmail = String.isNotBlank(quoteRecord.Contact.Email) ? quoteRecord.Contact.Email : 'Email - test@testemail.com'; 
        } else {
            contactName = 'Test Name Shubhas Khatri';
            contactNumber = 'Contact - +91 87XXXXXXXX';
            contactEmail = 'Email - test@testemail.com';
        }
        
        List<String> addressParts = new List<String>();
        if (quoteRecord.Account != null) {
            if (String.isNotBlank(quoteRecord.Account.BillingStreet)) addressParts.add(quoteRecord.Account.BillingStreet);
            if (String.isNotBlank(quoteRecord.Account.BillingCity)) addressParts.add(quoteRecord.Account.BillingCity);
            if (String.isNotBlank(quoteRecord.Account.BillingState)) addressParts.add(quoteRecord.Account.BillingState);
            if (String.isNotBlank(quoteRecord.Account.BillingPostalCode)) addressParts.add(quoteRecord.Account.BillingPostalCode);
            if (String.isNotBlank(quoteRecord.Account.BillingCountry)) addressParts.add(quoteRecord.Account.BillingCountry);
            accountName = quoteRecord.Account.Name;
        } else {
            accountName = 'Test Account Record';
        }
        accAdd = addressParts.isEmpty() ? 'Not Available' : String.join(addressParts, ', ');
        referenceNum = quoteRecord.QuoteNumber != null ? quoteRecord.QuoteNumber : 'Test UIL/STPD/26-27/1';
        
        if (String.isBlank(quoteRecord.Quote_Value__c)) return;

        jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
        this.standard = castToString(jsonData.get('Standard'));
        
        if (this.standard != null && this.standard.contains('IS 4984')) {
            this.standard = 'IS 4984';
        }
        this.destinationLocation = jsonData.containsKey('tc_destination_location') ? castToString(jsonData.get('tc_destination_location')) : '';
        
        // Pre-scan for accessories presence globally
        for (Integer j = 1; j <= 10; j++) {
            if (String.isNotBlank(castToString(jsonData.get('item_name_input' + j))) || String.isNotBlank(castToString(jsonData.get('product_category_input' + j)))) {
                this.hasAccessories = true;
                break;
            }
        }

        // Setup the localized/dynamic naming rules
        String resolvedDynamicName = 'HDPE Pipe';
        if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
            resolvedDynamicName = 'PLB Duct';
        } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
            resolvedDynamicName = 'MDPE Pipe';
        } else if (standard == 'Pipe & Duct') {
            resolvedDynamicName = 'HDPE Pipe & Duct';
        }
        
        if (this.hasAccessories) {
            resolvedDynamicName += ' and Fittings';
        }

        // Apply naming convention uniformly to the business artifacts
        this.itemOffered = resolvedDynamicName;
        this.subjectLine = 'Offer for Supply of ' + this.itemOffered;

        // =========================================================================
        // BLOCK A: Standard Layout Rule Parsing (When standard != 'Pipe & Duct')
        // =========================================================================
        if (standard != 'Pipe & Duct') {
            try {
                TableWrapper unifiedTable = new TableWrapper(resolvedDynamicName);
                Integer absoluteSlNo = 1;
                
                String prefix = 'c';
                String suffix = '_is_';
                if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
                    suffix = '_';
                } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                    suffix = '_mdpe_';
                }
                
                Decimal pipeCount = 0;
                if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                    pipeCount = jsonData.containsKey('mdpe_pipe_count') ? castToDecimal(jsonData.get('mdpe_pipe_count')) : 0;
                } else {
                    pipeCount = jsonData.containsKey('pipe_count') ? castToDecimal(jsonData.get('pipe_count')) : castToDecimal(jsonData.get('is_pipe_count'));
                }
                
                Integer maxPipes = Integer.valueOf(pipeCount);
                for (Integer i = 1; i <= maxPipes; i++) {
                    String s = String.valueOf(i);
                    
                    String dia = '';
                    String grade = '';
                    String rating = '';
                    
                    if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                        dia = castToString(jsonData.get(prefix + s + suffix + 'Nominal_Dia'));
                        grade = jsonData.containsKey(prefix + s + suffix + 'SDR_Grade_select') ? castToString(jsonData.get(prefix + s + suffix + 'SDR_Grade_select')) : '';
                    } else {
                        dia = castToString(jsonData.get(prefix + s + suffix + 'Diameter_Size'));
                        grade = jsonData.containsKey(prefix + s + suffix + 'PE_Grade_select') ? castToString(jsonData.get(prefix + s + suffix + 'PE_Grade_select')) : '';
                        rating = jsonData.containsKey(prefix + s + suffix + 'Pressure_rating_select') ? castToString(jsonData.get(prefix + s + suffix + 'Pressure_rating_select')) : '';
                    }
                    
                    if (String.isBlank(dia)) continue;

                    String lengthKey = prefix + s + suffix + 'len_of_coil_pipe';
                    String lenCoil = '';
                    if (jsonData.containsKey(lengthKey)) {
                        Decimal currentLength = castToDecimal(jsonData.get(lengthKey));
                        lenCoil = String.valueOf(currentLength.setScale(0));
                        if (currentLength > maxPipeLength) maxPipeLength = currentLength;
                    }
                    
                    // Dynamically check for type of pipe (coil or straight)
                    String typeOfPipeKey = prefix + s + suffix + 'type_of_pipe';
                    String pipeType = jsonData.containsKey(typeOfPipeKey) ? castToString(jsonData.get(typeOfPipeKey)) : 'straight';
                    String dynamicLenSuffix = (String.isNotBlank(pipeType) && pipeType.equalsIgnoreCase('coil')) ? 'coil length' : 'straight length';
                    
                    String description = '';
                    if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
                        Boolean pullingRopeSuffix = jsonData.containsKey(prefix + s + suffix + 'Fittings_Charges') && !String.isBlank(String.valueOf(jsonData.get(prefix + s + suffix + 'Fittings_Charges')));
                        if (String.isNotBlank(dia) && dia.contains('40/33 TEC Spec')) {
                            description = '40/33 mm HDPE PLB DUCT as per TEC Spec ';
                        } else {
                            description = dia + ' mm HDPE PLB DUCT ';
                        }
                        description += pullingRopeSuffix ? 'With Pulling Rope (' + lenCoil + ' mtr coil length)' : '(' + lenCoil + ' mtr coil length)';
                        
                    } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                        description = dia + ' mm MDPE ' + grade + ' (' + lenCoil + ' mtr ' + dynamicLenSuffix + ')';
                    } else {
                        description = dia + ' mm HDPE PIPE ' + grade + ' ' + rating + ' ' + (String.isNotBlank(standard) ? standard : 'IS 4984') + ' (' + lenCoil + ' mtr ' + dynamicLenSuffix + ')';
                    }
                    
                    String uompre = castToString(jsonData.get(prefix + s + suffix + 'unit_of_messurment'));
                    Decimal boqQty = castToDecimal(jsonData.get(prefix + s + suffix + 'BOQ_Quantity'));                  
                    
                    Decimal calculatedQty = (String.isNotBlank(uompre) && uompre.equalsIgnoreCase('Km')) ? boqQty * 1000 : boqQty;
                    String finalUom = (String.isNotBlank(uompre) && uompre.equalsIgnoreCase('Km')) ? 'MTR' : (String.isNotBlank(uompre) ? uompre.toUpperCase() : 'MTR');
                    Decimal rateFOR = castToDecimal(jsonData.get(prefix + s + suffix + 'FOR_Price'));
                    Decimal total = (calculatedQty * rateFOR).setScale(2);
                    unifiedTable.lineItems.add(new Map<String, Object>{
                        'SlNo' => absoluteSlNo++, 'description' => description, 'uom' => finalUom, 
                        'quantity' => calculatedQty, 'rate' => rateFOR, 'total_price' => total
                    });
                    unifiedTable.tableGrossTotal += total;
                }
                
                // Process Accessories directly into the Main Table
                for (Integer j = 1; j <= 10; j++) {
                    String itemName = castToString(jsonData.get('item_name_input' + j));
                    if (String.isNotBlank(itemName)) {
                        String fUom = castToString(jsonData.get('uom_input' + j));
                        Decimal fQty = castToDecimal(jsonData.get('quantity_input' + j));
                        Decimal fRate = castToDecimal(jsonData.get('rate_input' + j));
                        String fSize = castToString(jsonData.get('acc_Diameter_Size_input' + j));
                        
                        List<String> descParts = new List<String>();
                        
                        if (String.isNotBlank(fSize)) {
                            if (fSize.contains('40/33 TEC Spec')) {
                                descParts.add('40/33 mm ');
                            } else {
                                descParts.add(fSize + ' mm ');
                            }
                        }
                        
                        descParts.add(itemName);
                        String detailedDescription = String.join(descParts, ' ');
                        Decimal fTotal = (fQty * fRate).setScale(2);
                        String finalAccUom = String.isNotBlank(fUom) ? fUom.toUpperCase() : 'PCS';
                        unifiedTable.lineItems.add(new Map<String, Object>{
                            'SlNo' => absoluteSlNo++, 'description' => detailedDescription, 'uom' => finalAccUom, 
                            'quantity' => fQty, 'rate' => fRate, 'total_price' => fTotal
                        });
                        unifiedTable.tableGrossTotal += fTotal;
                    }
                }
                
                if (!unifiedTable.lineItems.isEmpty()) {
                    Decimal dynamicGst = castToDecimal(jsonData.get('c1_GST'));
                    if (dynamicGst == 0) dynamicGst = castToDecimal(jsonData.get('c1_is_GST'));
                    if (dynamicGst == 0) dynamicGst = castToDecimal(jsonData.get('c1_mdpe_GST'));
                    if (dynamicGst == 0) dynamicGst = 18.00;
                    
                    unifiedTable.gst = dynamicGst;
                    unifiedTable.tableSubTotal = (unifiedTable.tableGrossTotal).setScale(2);
                    unifiedTable.gstAmount = ((unifiedTable.tableSubTotal * unifiedTable.gst) / 100).setScale(2);
                    
                    if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
                        if (castToString(jsonData.get('Type_of_transportation')) == 'F.O.R (Freight on Road)' && castToString(jsonData.get('Type_of_FOR')) == 'Lump Sum') {
                            unifiedTable.transportationCharge = castToDecimal(jsonData.get('LumpSum_Amount'));
                        }
                    } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                        if (castToString(jsonData.get('mdpe_Type_of_transportation')) == 'F.O.R (Freight on Road)' && castToString(jsonData.get('mdpe_Type_of_FOR')) == 'Lump Sum') {
                            unifiedTable.transportationCharge = castToDecimal(jsonData.get('mdpe_LumpSum_Amount'));
                        }
                    } else {
                        if (castToString(jsonData.get('is_Type_of_transportation')) == 'F.O.R (Freight on Road)' && castToString(jsonData.get('is_Type_of_FOR')) == 'Lump Sum') {
                            unifiedTable.transportationCharge = castToDecimal(jsonData.get('is_LumpSum_Amount'));
                        }
                    }
                    
                    this.totalAmount = unifiedTable.tableSubTotal + unifiedTable.gstAmount + unifiedTable.transportationCharge;
                    this.tables.add(unifiedTable);
                }
                
                if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
                    String plbTrans = castToString(jsonData.get('Type_of_transportation'));
                    String freightIncoterms = castToString(jsonData.get('freight_incoterms_hdpe'));
                    String selectedPlbTrans = String.isNotBlank(plbTrans) ? plbTrans : String.isNotBlank(freightIncoterms) ? freightIncoterms : 'Ex-works';
                    this.plbDuctTransportText = selectedPlbTrans.equalsIgnoreCase('Ex-works') ? 'Ex-works' : selectedPlbTrans.containsIgnoreCase('F.O.R') ? 'Delivery included upto ' + this.destinationLocation + ' Destination' : selectedPlbTrans;
                
                } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
                    String mdpeTrans = castToString(jsonData.get('mdpe_Type_of_transportation'));
                    String freightIncoterms = castToString(jsonData.get('freight_incoterms_hdpe'));
                    String selectedMdpeTrans = String.isNotBlank(mdpeTrans) ? mdpeTrans : String.isNotBlank(freightIncoterms) ? freightIncoterms : 'Ex-works';
                    this.mdpeTransportText = selectedMdpeTrans.equalsIgnoreCase('Ex-works') ? 'Ex-works' : selectedMdpeTrans.containsIgnoreCase('F.O.R') ? 'Delivery included upto ' + this.destinationLocation + ' Destination' : selectedMdpeTrans;
                    
                } else if (String.isNotBlank(standard) && standard.containsIgnoreCase('IS 4984')) {
                    String isTrans = castToString(jsonData.get('is_Type_of_transportation'));
                    String freightIncoterms = castToString(jsonData.get('freight_incoterms_hdpe'));
                    String selectedIsTrans = String.isNotBlank(isTrans) ? isTrans : String.isNotBlank(freightIncoterms) ? freightIncoterms : 'Ex-works';
                    this.is4984TransportText = selectedIsTrans.equalsIgnoreCase('Ex-works') ? 'Ex-works' : selectedIsTrans.containsIgnoreCase('F.O.R') ? 'Delivery included upto ' + this.destinationLocation + ' Destination' : selectedIsTrans;
                }
            } catch (Exception e) {
                System.debug('»»» ERROR: ' + e.getMessage());
            }
        }
        
        // =========================================================================
        // BLOCK B: Single Consolidated Table System (When standard == 'Pipe & Duct')
        // =========================================================================
        this.unifiedRows = new List<ImprovisedRow>();
        this.blockBBasicTotal = 0.0;
        this.blockBGstAmount = 0.0;
        this.blockBFinalAmount = 0.0;
        this.blockBTransportationCharge = 0.0;
        this.blockBTableName = resolvedDynamicName;
        
        if (standard == 'Pipe & Duct') {
            this.showPipeTable = jsonData.containsKey('p_selected') ? (Boolean)jsonData.get('p_selected') : false;
            this.showDuctTable = jsonData.containsKey('d_selected') ? (Boolean)jsonData.get('d_selected') : false;
            
            this.blockBGstPercent = jsonData.containsKey('c1_p_GST') ? castToDecimal(jsonData.get('c1_p_GST')) : 18.0;
            if(this.blockBGstPercent == 0) this.blockBGstPercent = jsonData.containsKey('c1_d_GST') ? castToDecimal(jsonData.get('c1_d_GST')) : 18.0;
            if(this.blockBGstPercent == 0) this.blockBGstPercent = 18.0;
            
            Integer globalSerialNo = 1;

            // --- 1. CONSOLIDATE HDPE PIPE ROWS ---
            if (this.showPipeTable) {
                for (Integer i = 1; i <= 10; i++) {
                    String prefix = 'c' + i + '_';
                    String gradeKey = prefix + 'p_PE_Grade_select';
                    
                    if (jsonData.containsKey(gradeKey) && String.isNotBlank(castToString(jsonData.get(gradeKey)))) {
                        String dia = castToString(jsonData.get(prefix + 'p_Diameter_Size'));
                        String grade = castToString(jsonData.get(gradeKey));
                        String rating = castToString(jsonData.get(prefix + 'p_Pressure_rating_select'));
                        String lenCoil = castToString(jsonData.get(prefix + 'p_len_of_coil_pipe'));
                        String rawUom = castToString(jsonData.get(prefix + 'p_unit_of_messurment'));
                        Decimal rawQty = castToDecimal(jsonData.get(prefix + 'p_BOQ_Quantity'));
                        Decimal unitRate = castToDecimal(jsonData.get(prefix + 'p_FOR_Price'));
                        if (jsonData.containsKey(prefix + 'p_len_of_coil_pipe')) {
                            Decimal currentLength = castToDecimal(jsonData.get(prefix + 'p_len_of_coil_pipe'));
                            if (currentLength > maxPipeLength) maxPipeLength = currentLength;
                        }
                        
                        String typeOfPipeKey = prefix + 'p_type_of_pipe';
                        String pipeType = jsonData.containsKey(typeOfPipeKey) ? castToString(jsonData.get(typeOfPipeKey)) : 'straight';
                        String dynamicLenSuffix = (String.isNotBlank(pipeType) && pipeType.equalsIgnoreCase('coil')) ? 'coil length' : 'straight length';
                        
                        Decimal convertedQty = (String.isNotBlank(rawUom) && rawUom.equalsIgnoreCase('Km')) ? rawQty * 1000 : rawQty;
                        String targetUom = (String.isNotBlank(rawUom) && rawUom.equalsIgnoreCase('Km')) ? 'mtr' : (String.isNotBlank(rawUom) ? rawUom : 'mtr');
                        Decimal calculatedBasic = (convertedQty * unitRate).setScale(2, RoundingMode.HALF_UP);
                        
                        ImprovisedRow row = new ImprovisedRow();
                        row.slNo = globalSerialNo++;
                        row.particular = dia + ' mm HDPE PIPE ' + grade + ' ' + rating + ' IS 4984 (' + lenCoil + 'mtr ' + dynamicLenSuffix + ')';
                        row.uom = targetUom.toUpperCase();
                        row.qty = convertedQty;
                        row.rate = unitRate;
                        row.basic = calculatedBasic;
                        
                        this.unifiedRows.add(row);
                        this.blockBBasicTotal += calculatedBasic;
                    }
                }
            }
            
            // --- 2. CONSOLIDATE HDPE DUCT ROWS ---
            if (this.showDuctTable) {
                for (Integer i = 1; i <= 10; i++) {
                    String prefix = 'c' + i + '_';
                    String diaKey = prefix + 'd_Diameter_Size';
                    
                    if (jsonData.containsKey(diaKey) && String.isNotBlank(castToString(jsonData.get(diaKey)))) {
                        String dia = castToString(jsonData.get(diaKey));
                        String lenCoil = castToString(jsonData.get(prefix + 'd_len_of_coil_pipe'));
                        String rawUom = castToString(jsonData.get(prefix + 'd_unit_of_messurment'));
                        Decimal rawQty = castToDecimal(jsonData.get(prefix + 'd_BOQ_Quantity'));
                        Decimal unitRate = castToDecimal(jsonData.get(prefix + 'd_FOR_Price'));
                        
                        if (jsonData.containsKey(prefix + 'd_len_of_coil_pipe')) {
                            Decimal currentLength = castToDecimal(jsonData.get(prefix + 'd_len_of_coil_pipe'));
                            if (currentLength > maxPipeLength) maxPipeLength = currentLength;
                        }

                        Decimal convertedQty = (String.isNotBlank(rawUom) && rawUom.equalsIgnoreCase('Km')) ? rawQty * 1000 : rawQty;
                        String targetUom = (String.isNotBlank(rawUom) && rawUom.equalsIgnoreCase('Km')) ? 'mtr' : (String.isNotBlank(rawUom) ? rawUom : 'mtr');
                        Decimal calculatedBasic = (convertedQty * unitRate).setScale(2, RoundingMode.HALF_UP);
                        
                       	ImprovisedRow row = new ImprovisedRow();
                        row.slNo = globalSerialNo++;
                        String description = '';
                        Boolean pullingRopeSuffix = jsonData.containsKey(prefix + 'd_Fittings_Charges') && !String.isBlank(String.valueOf(jsonData.get(prefix + 'd_Fittings_Charges')));
                        if (String.isNotBlank(dia) && dia.contains('40/33 TEC Spec')) {
                            description = '40/33 mm HDPE PLB DUCT as per TEC Spec ';
                        } else {
                            description = dia + ' mm HDPE PLB DUCT ';
                        }
                        description += pullingRopeSuffix ? 'With Pulling Rope (' + lenCoil + ' mtr coil length)' : '(' + lenCoil + ' mtr coil length)';
                        row.particular = description;
                        
                        row.uom = targetUom.toUpperCase();
                        row.qty = convertedQty;
                        row.rate = unitRate;
                        row.basic = calculatedBasic;
                        
                        this.unifiedRows.add(row);
                        this.blockBBasicTotal += calculatedBasic;
                    }
                }
            }
            
            // --- 3. CONSOLIDATE IN-LINE ACCESSORIES ROWS ---
            for (Integer k = 1; k <= 10; k++) {
                String catKey = castToString(jsonData.get('product_category_input' + k));
                if (String.isNotBlank(catKey)) {
                    Decimal accQty = castToDecimal(jsonData.get('quantity_input' + k));
                    Decimal accRate = castToDecimal(jsonData.get('rate_input' + k));
                    Decimal accBasic = (accQty * accRate).setScale(2, RoundingMode.HALF_UP);
                    
                    String itemName = castToString(jsonData.get('item_name_input' + k));
                    String fSize = castToString(jsonData.get('acc_Diameter_Size_input' + k));
                    String detailedDescription = '';
                    
                    if (String.isNotBlank(fSize)) {
                        if (fSize.contains('40/33 TEC Spec')) {
                            detailedDescription += '40/33 mm ';
                        } else {
                            detailedDescription += fSize + ' mm ';
                        }
                    }
                    
                    detailedDescription += itemName;
                    ImprovisedRow accRow = new ImprovisedRow();
                    accRow.slNo = globalSerialNo++;
                    accRow.particular = detailedDescription;
                    accRow.uom = jsonData.containsKey('uom_input' + k) ? castToString(jsonData.get('uom_input' + k)).toUpperCase() : 'PCS';
                    accRow.qty = accQty;
                    accRow.rate = accRate;
                    accRow.basic = accBasic;
                    this.unifiedRows.add(accRow);
                    this.blockBBasicTotal += accBasic;
                }
            }
            
            // --- 4. CALCULATE CUMULATIVE SUMMARY FIGURES FOR BLOCK B ---
            this.blockBGstAmount = (this.blockBBasicTotal * (this.blockBGstPercent / 100.0)).setScale(2, RoundingMode.HALF_UP);
            
            String fallbackTrans = castToString(jsonData.get('freight_incoterms_hdpe'));
            
            String rawPTrans = castToString(jsonData.get('p_Type_of_transportation'));
            String pTrans = String.isNotBlank(rawPTrans) ? rawPTrans : String.isNotBlank(fallbackTrans) ? fallbackTrans : 'Ex-works';
            
            if (this.showPipeTable && pTrans == 'F.O.R (Freight on Road)' && castToString(jsonData.get('p_Type_of_FOR')) == 'Lump Sum') {
                this.blockBTransportationCharge += castToDecimal(jsonData.get('p_LumpSum_Amount'));
            }
            
            this.pipeDuctPipeTransportText = pTrans.equalsIgnoreCase('Ex-works') ? 'Ex-works' : pTrans.containsIgnoreCase('F.O.R') ? 'Delivery included upto ' + this.destinationLocation + ' Destination' : pTrans;
            
            String rawDTrans = castToString(jsonData.get('d_Type_of_transportation'));
            String dTrans = String.isNotBlank(rawDTrans) ? rawDTrans : String.isNotBlank(fallbackTrans) ? fallbackTrans : 'Ex-works';
            
            if (this.showDuctTable && dTrans == 'F.O.R (Freight on Road)' && castToString(jsonData.get('d_Type_of_FOR')) == 'Lump Sum') {
                this.blockBTransportationCharge += castToDecimal(jsonData.get('d_LumpSum_Amount'));
            }
            
            this.pipeDuctDuctTransportText = dTrans.equalsIgnoreCase('Ex-works') ? 'Ex-works' : dTrans.containsIgnoreCase('F.O.R') ? 'Delivery included upto ' + this.destinationLocation + ' Destination' : dTrans;
            
            this.blockBFinalAmount = (this.blockBBasicTotal + this.blockBGstAmount + this.blockBTransportationCharge).setScale(2, RoundingMode.HALF_UP);
            this.totalAmount = this.blockBFinalAmount;
        }
        
        // =========================================================================
        // GLOBAL REGION: Shared terms mapping execution scope
        // =========================================================================
        String parsedFreight = '';

        if (standard == 'Pipe & Duct') {
            String pTrans = castToString(jsonData.get('p_Type_of_transportation'));
            String dTrans = castToString(jsonData.get('d_Type_of_transportation'));
            String fallbackTrans = castToString(jsonData.get('freight_incoterms_hdpe'));
        
            String pipeVal = String.isNotBlank(pTrans) ? pTrans 
                           : String.isNotBlank(fallbackTrans) ? fallbackTrans 
                           : 'Ex-works';
        
            String ductVal = String.isNotBlank(dTrans) ? dTrans 
                           : String.isNotBlank(fallbackTrans) ? fallbackTrans 
                           : 'Ex-works';
        
            parsedFreight = 'Pipe: ' + pipeVal + ' | Duct: ' + ductVal;
        
        } else if (standard == 'PLB Duct') {
            String plbTrans = castToString(jsonData.get('Type_of_transportation'));
            String fallbackTrans = castToString(jsonData.get('freight_incoterms_hdpe'));
        
            parsedFreight = String.isNotBlank(plbTrans) ? plbTrans 
                          : String.isNotBlank(fallbackTrans) ? fallbackTrans 
                          : 'Ex-works';
                          
        } else if (standard == 'MDPE Pipe') {
            String mdpeTrans = castToString(jsonData.get('mdpe_Type_of_transportation'));
            String fallbackTrans = castToString(jsonData.get('freight_incoterms_hdpe'));
        
            parsedFreight = String.isNotBlank(mdpeTrans) ? mdpeTrans 
                          : String.isNotBlank(fallbackTrans) ? fallbackTrans 
                          : 'Ex-works';
                          
        } else { // IS 4984 and other standards
            String isTrans = castToString(jsonData.get('is_Type_of_transportation'));
            String fallbackTrans = castToString(jsonData.get('freight_incoterms_hdpe'));
        
            parsedFreight = String.isNotBlank(isTrans) ? isTrans 
                          : String.isNotBlank(fallbackTrans) ? fallbackTrans 
                          : 'Ex-works';
        }
        
        // Format the final freight basis message
        if (String.isNotBlank(parsedFreight)) {
            this.freightBasis = 'Prices are on ' + parsedFreight + ' Basis.';
        } else {
            this.freightBasis = castToString(jsonData.get('freight_incoterms_hdpe'));
            if (String.isBlank(this.freightBasis)) {
                this.freightBasis = 'Prices are on Ex-works Basis.';
            }
        }
        
        String packingBase = castToString(jsonData.get('tc_packing_forwarding_charges'));
        if (String.isBlank(packingBase)) packingBase = 'Inclusive';
        if (maxPipeLength == 0) maxPipeLength = 12;
        this.packingForwarding = packingBase;
        
        Boolean hasInspectionCommission = false;
        for (String key : new List<String>{'is_Inspection_Commission','Inspection_Commission','p_Inspection_Commission','d_Inspection_Commission', 'mdpe_Inspection_Commission'}) {
            if (jsonData.containsKey(key) && String.isNotBlank(String.valueOf(jsonData.get(key)))) { 
                hasInspectionCommission = true;
                break;
            }
        }

        this.inspectionTerms = hasInspectionCommission ?
            'Material shall be inspected at our works before dispatch and third party inspection charges are included.\nNo rejection acceptable at your site.': 
            'Material shall be inspected at our works before dispatch and third party inspection charges are extra.\nNo rejection acceptable at your site.';
        this.loadingCharges = 'Loading to be borne by us & unloading to be arrange by you.';
        
        Decimal configGst = castToDecimal(jsonData.get('c1_GST'));
        if(configGst == 0) configGst = castToDecimal(jsonData.get('c1_is_GST'));
        if(configGst == 0) configGst = castToDecimal(jsonData.get('c1_p_GST'));
        if(configGst == 0) configGst = castToDecimal(jsonData.get('c1_mdpe_GST'));
        this.gstPercentage = (configGst != 0) ? configGst : 18.00;
        
        this.tcsPercentage = 0.10;
        this.paymentTerms = castToString(jsonData.get('tc_payment_term'));
        
        if (String.isNotBlank(standard) && standard.equalsIgnoreCase('PLB Duct')) {
            this.delayInterestPercentage = castToDecimal(jsonData.get('c1_Interest_Charges_on_Payment'));
        } else if (String.isNotBlank(standard) && standard.equalsIgnoreCase('MDPE Pipe')) {
            this.delayInterestPercentage = castToDecimal(jsonData.get('mdpe_Interest_Charges_on_Payment'));
        } else {
            this.delayInterestPercentage = castToDecimal(jsonData.get('c1_is_Interest_Charges_on_Payment'));
        }
        
        if(this.delayInterestPercentage == 0 && jsonData.containsKey('c1_p_Interest_Charges_on_Payment')) {
            this.delayInterestPercentage = castToDecimal(jsonData.get('c1_p_Interest_Charges_on_Payment'));
        }

        this.groundRentDays = 2;
        this.groundRentPercentage = 5.00;
        this.validityTerms = castToString(jsonData.get('tc_validity'));
        this.deliveryPeriod = 'Confirm after the acceptance of order.';
        
        Decimal startVal = castToDecimal(jsonData.get('tc_warranty_start'));
        Decimal endVal = castToDecimal(jsonData.get('tc_warranty_end'));
        this.warrantyMonths = String.valueOf(startVal.setScale(0)) + ' (' + CurrencyInWords.convertNumberOnly(startVal).toLowerCase() + ') ';
        this.warrantyEndMonth = String.valueOf(endVal.setScale(0)) + ' (' + CurrencyInWords.convertNumberOnly(endVal).toLowerCase() + ') ';
        this.priceVariationClause = 'The quoted prices are based on current basic Virgin HDPE Granule. The variation will be calculated on the basis of the formula mentioned below. P2 = P1 + [(R2-R1) x M], where P2 = Revised Price in Rs./Meter, P1 = Quoted Price in Rs./Meter, R2 = New price of resin per Kg, R1 = Price of resin on the date of offer per Kg, and M = Weight of Pipe in Kg/Meter. Price variation will be effective from the date of issue of Manufacturing Clearance. The resin price prevailing in the week prior to the inspection date will be considered for the purpose of price variation.';
        String testCertStatus = castToString(jsonData.get('tc_test_certificate'));
        if (String.isNotBlank(testCertStatus) && testCertStatus.equalsIgnoreCase('Included')) {
            this.testCertificate = 'Company will provide the 3rd Party T.C.';
        } else if (String.isNotBlank(testCertStatus) && testCertStatus.equalsIgnoreCase('Excluded')) {
            this.testCertificate = 'Company will not provide the 3rd Party T.C.';
        } else {
            this.testCertificate = testCertStatus;
        }
        
        this.insuranceTerms = castToString(jsonData.get('tc_Insurance'));
        if (String.isBlank(this.insuranceTerms)) {
            this.insuranceTerms = 'To be borne & arrange by you.';
        }

        if (String.isBlank(this.paymentTerms)) this.paymentTerms = 'Advance payment against proforma invoice.';
        if (String.isBlank(this.validityTerms)) this.validityTerms = 'Valid till revision in Price of Raw Material.';
        totalAmountInWords = CurrencyInWords.convertToIndianRupees(totalAmount);
    }

    private static Decimal castToDecimal(Object obj) {
        if (obj == null) return 0.0;
        if (obj instanceof Decimal) return (Decimal)obj;
        if (obj instanceof Integer) return Decimal.valueOf((Integer)obj);
        String str = String.valueOf(obj).trim();
        return str == '' ? 0.0 : Decimal.valueOf(str);
    }

    private static String castToString(Object obj) {
        return obj == null ? '' : String.valueOf(obj);
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