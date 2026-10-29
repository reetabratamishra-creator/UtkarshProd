public class CrashBarrierQuoteController {

    // ─── Crash Barrier Fields ─────────────────────────────────
    public Quote                      quoteRecord         { get; set; }
    public Map<String, Object>        jsonData            { get; set; }
    public List<Map<String, Object>>  lineItems           { get; set; }
    public Decimal                    totalAmount         { get; set; }
    public String                     todayDate           { get; set; }
    public String                     accountName         { get; set; }
    public String                     contactName         { get; set; }
    public String                     contactNumber       { get; set; }
    public String                     contactEmail        { get; set; }
    public String                     quoteNotes          { get; set; }
    public String                     dynamicPaymentTerms { get; set; }
    public String                     dynamicFreightTerm  { get; set; }
    public Decimal                    totalFreightCharges { get; set; }
    public String                     validityDays        { get; set; }
    public Decimal                    totalAccessoriesAmount { get; set; }
    public Decimal                    totalMiscAmount        { get; set; }
    public Decimal                    totalAddlMiscAmount    { get; set; }
    public Decimal                    absoluteGrandTotal { get; set; }
    public Decimal                    globalTotalCharges { get; set; }
    public Decimal                    intrestfactor       { get; set; }
    public Boolean                    showSeperateInterest{ get; set; } // Flag exposed to Visualforce

    public CrashBarrierQuoteController(ApexPages.StandardController stdController) {
        System.debug('=== CrashBarrierQuoteController Constructor Started ===');
        System.debug('Record Id passed: ' + stdController.getId());

        if (!Test.isRunningTest() && ApexPages.currentPage() != null) {
            stdController.addFields(new List<String>{
                'QuoteNumber', 'Opportunity.Name', 'BillingStreet', 
                'BillingCity', 'BillingState', 'BillingPostalCode', 'CreatedDate'
            });
        }

        try {
            quoteRecord = [
                SELECT Id, Name, QuoteNumber, Quote_Value__c, CreatedDate,
                       Account.Name, Contact.Name, Contact.Phone, Contact.Email,Quote_Reference__c,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, Opportunity.Name
                FROM   Quote
                WHERE  Id = :stdController.getId()
                LIMIT  1
            ];
            System.debug('SOQL Success. Quote Record retrieved: ' + quoteRecord.QuoteNumber);
        } catch (Exception e) {
            System.debug('ERROR: SOQL Query for Quote Failed: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        }

        // ─── Initialize Contact & Account Data ─────────────────
        if (quoteRecord != null && quoteRecord.Contact != null) {
            contactName   = quoteRecord.Contact.Name;
            contactNumber = String.isNotBlank(quoteRecord.Contact.Phone) ? quoteRecord.Contact.Phone : 'N/A';
            contactEmail  = String.isNotBlank(quoteRecord.Contact.Email) ? quoteRecord.Contact.Email : 'N/A';
        } else {
            contactName   = 'N/A';
            contactNumber = 'N/A';
            contactEmail  = 'N/A';
        }

        accountName = (quoteRecord != null && quoteRecord.Account != null) ? quoteRecord.Account.Name : 'Account Name Not Found';
        totalAmount = 0.00;
        lineItems   = new List<Map<String, Object>>();
        todayDate   = Date.today().format();
        jsonData    = new Map<String, Object>();

        // ─── Parse JSON configuration ──────────────────────────
        if (quoteRecord != null && String.isNotBlank(quoteRecord.Quote_Value__c)) {
            System.debug('Quote_Value__c JSON is present. Starting deserialization...');
            try {
                jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
                System.debug('JSON deserialized successfully. Total root keys: ' + jsonData.keySet().size());

                // --- SAFEGUARD UI KEYS FOR VISUALFORCE ---
                Boolean showOriginal = false;
                if (jsonData.get('rlw_show_original') != null) {
                    showOriginal = Boolean.valueOf(String.valueOf(jsonData.get('rlw_show_original')));
                }
                
                // Graded Thickness Logic
                if (showOriginal && jsonData.get('rlw_graded_section_beam_thickness_input') != null) {
                    jsonData.put('print_graded_thickness', String.valueOf(jsonData.get('rlw_graded_section_beam_thickness_input')));
                } else {
                    jsonData.put('print_graded_thickness', '2');
                }
                
                // Non-Graded Thickness Logic
                if (showOriginal && jsonData.get('rlw_non_graded_section_beam_thickness_input') != null) {
                    jsonData.put('print_nongraded_thickness', String.valueOf(jsonData.get('rlw_non_graded_section_beam_thickness_input')));
                } else {
                    jsonData.put('print_nongraded_thickness', '2');
                }

                // ─── Check tc_show_seperate Flag ──────────────────
                showSeperateInterest = false;
                /*if (jsonData.containsKey('tc_show_seperate') && jsonData.get('tc_show_seperate') != null) {
                    showSeperateInterest = Boolean.valueOf(String.valueOf(jsonData.get('tc_show_seperate')));
                }*/

                // ─── Interest Factor Logic ──────────────────────
                intrestfactor = 1.00;
                String paymentTermType = String.valueOf(jsonData.get('tc_payment_terms_picklist'));
                System.debug('Payment Terms Picklist Value: ' + paymentTermType);

                if(paymentTermType == 'Against LC' || paymentTermType == 'Against BG' || paymentTermType == 'Against Open Credit'){
                    try {
                        Decimal freeDays = Decimal.valueOf(String.valueOf(jsonData.get('tc_no_of_days_interest_free_credit')));
                        Decimal interestRate = Decimal.valueOf(String.valueOf(jsonData.get('tc_rate_of_interest')));
                        intrestfactor = ((((freeDays / 365) * interestRate) / 100) + 1);
                        System.debug('Calculated Interest Factor: ' + intrestfactor + ' (Days: ' + freeDays + ', Rate: ' + interestRate + '%)');
                    } catch (Exception e) {
                        System.debug('ERROR calculating Interest Factor, defaulting to 1.00: ' + e.getMessage());
                        intrestfactor = 1.00;
                    }
                } else {
                    System.debug('No Interest Terms matched. Defaulting Interest Factor to: ' + intrestfactor);
                }

                // Determine effective factor for line item unit prices
                Decimal effectiveFactor = showSeperateInterest ? 1.00 : intrestfactor;

                // Initialize Freight Keys for VF Page
                String[] freightKeys = new String[]{
                    'tb_natrax_fvf', 'wb_natrax_fvf', 'tb_alka_fvf', 'wb_alka_fvf', 
                    'tb_trans_fvf', 'wb_trans_fvf', 'misc_section_fvf',
                    'PGR_full_vehicle_freight', 'a_s_fvf', 'r_s_fvf',
                    'ns_w_beam_section_full_Vehicle_freight', 'ns_thrie_beam_section_full_Vehicle_freight',
                    'w_SSSB_w_beam_full_Vehicle_freight', 'w_SSDB_w_beam_full_Vehicle_freight',
                    'w_DSSB_w_beam_full_Vehicle_freight', 'w_DSDB_w_beam_full_Vehicle_freight',
                    'Thrie_SSSB_full_Vehicle_freight', 'Thrie_SSDB_full_Vehicle_freight',
                    'Thrie_DSSB_full_Vehicle_freight', 'Thrie_DSDB_full_Vehicle_freight',
                    'acc_section_fvf', 'add_misc_fvf',
                    'rlw_non_graded_full_Vehicle_freight', 'rlw_full_Vehicle_freight'
                };

                totalFreightCharges = 0;
                for (String key : freightKeys) {
                    Object val = jsonData.get(key);
                    Decimal freight = 0;
                    if (val == null || String.valueOf(val).trim() == '') {
                        jsonData.put(key, 0.0);
                    } else {
                        try { 
                            freight = Math.ceil((Decimal.valueOf(String.valueOf(val)) * effectiveFactor)/5.0)*5;
                            jsonData.put(key, freight);
                        } catch (Exception e) { 
                            System.debug('ERROR parsing freight key [' + key + ']: ' + e.getMessage());
                            jsonData.put(key, 0.0);
                        }
                    }
                    totalFreightCharges += freight;
                }
                System.debug('Total Freight Charges Calculated: ' + totalFreightCharges);

                // ─── SAFE PARSE FOR BACKGROUND LINES ──────────────────────────
                if (jsonData.containsKey('_Final_Apex_Lines')) {
                    List<Object> rawLines = (List<Object>) jsonData.get('_Final_Apex_Lines');
                    System.debug('Processing _Final_Apex_Lines. Row count: ' + rawLines.size());
                    lineItems = new List<Map<String, Object>>();
                    
                    String[] safeNumericKeys = new String[]{'expenses', 'netPrice', 'unitPrice', 'unitCost', 'quantity', 'weight', 'per_price', 'per_price_total'};
                    String[] safeStringKeys  = new String[]{'uom', 'name', 'itemName', 'sectionName'};

                    Integer accessoryIndex = 1;
                    Integer miscIndex = 1;
                    Integer addMiscIndex = 1;
                    
                    for (Object obj : rawLines) {
                        Map<String, Object> lineMap = (Map<String, Object>) obj;
                        String lineName = String.valueOf(lineMap.get('name'));
                        String itemName = lineName.toUpperCase();
                        Boolean isMain = !(itemName.startsWith('ACCESSORY:') || itemName.startsWith('MISC:') || itemName.startsWith('ADD'));
                        lineMap.put('isMainProduct', isMain);

                        if (lineName.startsWith('Accessory:')) {
                            String suffix = accessoryIndex == 1 ? '' : String.valueOf(accessoryIndex);
                            Object uomObj = jsonData.get('acc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('acc_section_quantity_no_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('acc_section_quantity_in_one_set_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            lineMap.put('quantity', finalQty);

                            Object weightObj = jsonData.get('acc_section_weight_input' + suffix);
                            Decimal weight = (weightObj != null && String.valueOf(weightObj).trim() != '') ? Decimal.valueOf(String.valueOf(weightObj)) : 0;

                            Object rateObj = jsonData.get('acc_section_rate_input' + suffix);
                            Decimal rate = (rateObj != null && String.valueOf(rateObj).trim() != '') ? Decimal.valueOf(String.valueOf(rateObj)) : 0;

                            Decimal origUnitPrice = weight * rate;
                            Decimal perPrice = Math.ceil((origUnitPrice * effectiveFactor) / 5.0) * 5;

                            Object accInputObj = jsonData.get('acc_section_w_t_beam_input' + suffix);
                            String accInput = (accInputObj != null) ? String.valueOf(accInputObj).trim() : '';
                            String beamType = 'Accessory: ' + accInput + ' ';
                            String configName = String.isNotBlank(lineName) ? lineName.replace('Accessory: ', beamType) : '';

                            System.debug('[_Final_Apex_Lines] Accessory Unit Price | Item: ' + configName + ' | Original: ' + origUnitPrice + ' | Updated: ' + perPrice);

                            lineMap.put('name', configName);
                            lineMap.put('unitPrice', perPrice);
                            lineMap.put('unitCost', perPrice);
                            lineMap.put('unitListPrice', perPrice);
                            lineMap.put('per_price', perPrice);
                            lineMap.put('per_price_total', Math.ceil((perPrice * finalQty) / 5.0) * 5);
                            lineMap.put('netPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);
                            lineMap.put('listPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);

                            accessoryIndex++;
                        }
                        else if (lineName.startsWith('Misc:')) {
                            String suffix = String.valueOf(miscIndex);
                            Object uomObj = jsonData.get('misc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('misc_section_quantityNo_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('misc_section_quantityIOS_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            lineMap.put('quantity', finalQty);

                            Object weightObj = jsonData.get('misc_section_weight_input' + suffix);
                            Decimal weight = (weightObj != null && String.valueOf(weightObj).trim() != '') ? Decimal.valueOf(String.valueOf(weightObj)) : 0;

                            Object rateObj = jsonData.get('misc_section_rate_input' + suffix);
                            Decimal rate = (rateObj != null && String.valueOf(rateObj).trim() != '') ? Decimal.valueOf(String.valueOf(rateObj)) : 0;

                            Decimal origUnitPrice = weight * rate;
                            Decimal perPrice = Math.ceil((origUnitPrice * effectiveFactor) / 5.0) * 5;

                            System.debug('[_Final_Apex_Lines] Misc Unit Price | Item: ' + lineName + ' | Original: ' + origUnitPrice + ' | Updated: ' + perPrice);

                            lineMap.put('unitPrice', perPrice);
                            lineMap.put('unitCost', perPrice);
                            lineMap.put('unitListPrice', perPrice);
                            lineMap.put('per_price', perPrice);
                            lineMap.put('per_price_total', Math.ceil((perPrice * finalQty) / 5.0) * 5);
                            lineMap.put('netPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);
                            lineMap.put('listPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);

                            miscIndex++;
                        }
                        else if (lineName.startsWith('Additional Miscellaneous:')) {
                            String suffix = addMiscIndex == 1 ? '' : String.valueOf(addMiscIndex);
                            Object uomObj = jsonData.get('add_misc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('add_misc_section_quantity_no_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('add_misc_section_quantity_in_one_set_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            lineMap.put('quantity', finalQty);

                            Object upObj = lineMap.get('unitPrice');
                            Decimal rawUnitPrice = (upObj != null && String.valueOf(upObj).trim() != '') ? Decimal.valueOf(String.valueOf(upObj)) : 0;
                            Decimal unitPrice = Math.ceil((rawUnitPrice * effectiveFactor) / 5.0) * 5;

                            Object ucObj = lineMap.get('unitCost');
                            Decimal rawUnitCost = (ucObj != null && String.valueOf(ucObj).trim() != '') ? Decimal.valueOf(String.valueOf(ucObj)) : 0;
                            Decimal unitCost = Math.ceil((rawUnitCost * effectiveFactor) / 5.0) * 5;

                            Object ulpObj = lineMap.get('unitListPrice');
                            Decimal rawUnitListPrice = (ulpObj != null && String.valueOf(ulpObj).trim() != '') ? Decimal.valueOf(String.valueOf(ulpObj)) : 0;
                            Decimal unitListPrice = Math.ceil((rawUnitListPrice * effectiveFactor) / 5.0) * 5;

                            System.debug('[_Final_Apex_Lines] Additional Misc Unit Price | Item: ' + lineName + ' | Original: ' + rawUnitPrice + ' | Updated: ' + unitPrice);

                            lineMap.put('unitPrice', unitPrice);
                            lineMap.put('unitCost', unitCost);
                            lineMap.put('unitListPrice', unitListPrice);
                            lineMap.put('netPrice', Math.ceil((finalQty * unitPrice) / 5.0) * 5);
                            lineMap.put('cost', Math.ceil((finalQty * unitCost) / 5.0) * 5);
                            lineMap.put('listPrice', Math.ceil((finalQty * unitListPrice) / 5.0) * 5);

                            addMiscIndex++;
                        } else {
                            // --- MAIN PRODUCT LINES IN BACKGROUND LINES ---
                            if (lineMap.containsKey('unitPrice') && lineMap.get('unitPrice') != null && String.valueOf(lineMap.get('unitPrice')).trim() != '') {
                                Decimal origUp = Decimal.valueOf(String.valueOf(lineMap.get('unitPrice')));
                                Decimal up = Math.ceil((origUp * effectiveFactor) / 5.0) * 5;
                                System.debug('[_Final_Apex_Lines] Main Product Unit Price | Item: ' + lineName + ' | Original: ' + origUp + ' | Updated: ' + up);
                                lineMap.put('unitPrice', up);
                            }
                            if (lineMap.containsKey('unitCost') && lineMap.get('unitCost') != null && String.valueOf(lineMap.get('unitCost')).trim() != '') {
                                Decimal origUc = Decimal.valueOf(String.valueOf(lineMap.get('unitCost')));
                                Decimal uc = Math.ceil((origUc * effectiveFactor) / 5.0) * 5;
                                System.debug('[_Final_Apex_Lines] Main Product Unit Cost | Item: ' + lineName + ' | Original: ' + origUc + ' | Updated: ' + uc);
                                lineMap.put('unitCost', uc);
                            }
                        }

                        // Safeguard remaining numeric fields
                        for (String key : safeNumericKeys) {
                            Object val = lineMap.get(key);
                            if (val == null || String.valueOf(val).trim() == '') {
                                lineMap.put(key, 0.0);
                            } else {
                                try { lineMap.put(key, Decimal.valueOf(String.valueOf(val))); } 
                                catch (Exception e) { 
                                    lineMap.put(key, 0.0); 
                                }
                            }
                        }

                        // Safeguard strings
                        for (String key : safeStringKeys) {
                            if (!lineMap.containsKey(key) || lineMap.get(key) == null) {
                                lineMap.put(key, '');
                            }
                        }
                        
                        if (String.valueOf(lineMap.get('uom')).trim() == '') lineMap.put('uom', 'EA');
                        
                        Decimal nPrice = (Decimal)lineMap.get('netPrice');
                        if (nPrice == 0.0) {
                            Decimal qty = (Decimal)lineMap.get('quantity');
                            Decimal uPrice = (Decimal)lineMap.get('unitPrice');
                            lineMap.put('netPrice', Math.ceil((qty * uPrice) / 5.0) * 5);
                        }
                        
                        Decimal pPrice = (Decimal)lineMap.get('per_price');
                        if (pPrice == 0.0) {
                            lineMap.put('per_price', (Decimal)lineMap.get('unitPrice'));
                            lineMap.put('per_price_total', (Decimal)lineMap.get('netPrice'));
                        }

                        lineItems.add(lineMap);
                    }
                }

                if (jsonData.containsKey('Note') && jsonData.get('Note') != null) quoteNotes = String.valueOf(jsonData.get('Note'));
                else if (jsonData.containsKey('notes') && jsonData.get('notes') != null) quoteNotes = String.valueOf(jsonData.get('notes'));
                else if (jsonData.containsKey('Notes__c') && jsonData.get('Notes__c') != null) quoteNotes = String.valueOf(jsonData.get('Notes__c'));
                else quoteNotes = '';

                // ─── SAFE PARSE FOR UI ROWS ──────────────────────────
                if (jsonData.containsKey('_Saved_Table_Rows')) {
                    List<Object> rawRows = (List<Object>) jsonData.get('_Saved_Table_Rows');
                    System.debug('Processing _Saved_Table_Rows. Row count: ' + rawRows.size());
                    Integer slNo = 1;
                    Integer accessoryIndex = 1;
                    Integer miscIndex = 1;
                    Integer addMiscIndex = 1;
                    
                    for (Object rowObj : rawRows) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;
                        String rowName = String.valueOf(row.get('name'));
                        String upRowName = rowName.toUpperCase();
                        Boolean isMainRow = !(upRowName.startsWith('ACCESSORY:') || upRowName.startsWith('MISC:') || upRowName.startsWith('ADD'));
                        row.put('isMainProduct', isMainRow);

                        // The three branches below already multiply this row by
                        // effectiveFactor. The generic "Table Row Rate" block further
                        // down is NOT an else of that chain - it runs for every row -
                        // so an Accessory:/Misc: row was being factored TWICE
                        // (debug: Accessory 9000 -> 12555 -> 17514.23). Main lines and
                        // 'Add Misc:' rows never enter a branch, so they were correct.
                        // This flag lets the generic block skip re-factoring the rows
                        // that are already done, without changing anything else it does
                        // (SlNo, per_price, totals still run for every row).
                        // Deepanjan (31st July 2026)
                        Boolean rowAlreadyFactored = false;

                        if (rowName.startsWith('Accessory:')) {
                            String suffix = accessoryIndex == 1 ? '' : String.valueOf(accessoryIndex);
                            Object uomObj = jsonData.get('acc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('acc_section_quantity_no_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('acc_section_quantity_in_one_set_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            row.put('quantity', finalQty);

                            Object weightObj = jsonData.get('acc_section_weight_input' + suffix);
                            Decimal weight = (weightObj != null && String.valueOf(weightObj).trim() != '') ? Decimal.valueOf(String.valueOf(weightObj)) : 0;

                            Object rateObj = jsonData.get('acc_section_rate_input' + suffix);
                            Decimal rate = (rateObj != null && String.valueOf(rateObj).trim() != '') ? Decimal.valueOf(String.valueOf(rateObj)) : 0;

                            Decimal origUnitPrice = weight * rate;
                            Decimal perPrice = Math.ceil((origUnitPrice * effectiveFactor) / 5.0) * 5;

                            Object accInputObj = jsonData.get('acc_section_w_t_beam_input' + suffix);
                            String accInput = (accInputObj != null) ? String.valueOf(accInputObj).trim() : '';
                            String beamType = 'Accessory: ' + accInput + ' ';
                            String configName = String.isNotBlank(rowName) ? rowName.replace('Accessory: ', beamType) : '';

                            System.debug('[_Saved_Table_Rows] Accessory Unit Price | Item: ' + configName + ' | Original: ' + origUnitPrice + ' | Updated: ' + perPrice);

                            row.put('name', configName);
                            row.put('unitPrice', perPrice);
                            row.put('unitCost', perPrice);
                            row.put('unitListPrice', perPrice);
                            row.put('per_price', perPrice);
                            row.put('per_price_total', Math.ceil((perPrice * finalQty) / 5.0) * 5);
                            row.put('netPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);
                            row.put('listPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);
                            
                            rowAlreadyFactored = true;
                            accessoryIndex++;
                        }
                        else if (rowName.startsWith('Misc:')) {
                            String suffix = String.valueOf(miscIndex);
                            Object uomObj = jsonData.get('misc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('misc_section_quantityNo_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('misc_section_quantityIOS_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            row.put('quantity', finalQty);

                            Object weightObj = jsonData.get('misc_section_weight_input' + suffix);
                            Decimal weight = (weightObj != null && String.valueOf(weightObj).trim() != '') ? Decimal.valueOf(String.valueOf(weightObj)) : 0;

                            Object rateObj = jsonData.get('misc_section_rate_input' + suffix);
                            Decimal rate = (rateObj != null && String.valueOf(rateObj).trim() != '') ? Decimal.valueOf(String.valueOf(rateObj)) : 0;

                            Decimal origUnitPrice = weight * rate;
                            Decimal perPrice = Math.ceil((origUnitPrice * effectiveFactor) / 5.0) * 5;

                            System.debug('[_Saved_Table_Rows] Misc Unit Price | Item: ' + rowName + ' | Original: ' + origUnitPrice + ' | Updated: ' + perPrice);

                            row.put('unitPrice', perPrice);
                            row.put('unitCost', perPrice);
                            row.put('unitListPrice', perPrice);
                            row.put('per_price', perPrice);
                            row.put('per_price_total', Math.ceil((perPrice * finalQty) / 5.0) * 5);
                            row.put('netPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);
                            row.put('listPrice', Math.ceil((finalQty * perPrice) / 5.0) * 5);

                            rowAlreadyFactored = true;
                            miscIndex++;
                        }
                        else if (rowName.startsWith('Additional Miscellaneous:')) {
                            String suffix = addMiscIndex == 1 ? '' : String.valueOf(addMiscIndex);
                            Object uomObj = jsonData.get('add_misc_section_uom_input' + suffix);
                            String uom = uomObj != null ? String.valueOf(uomObj).trim().toUpperCase() : '';

                            Object qtyNoObj = jsonData.get('add_misc_section_quantity_no_input' + suffix);
                            Decimal qtyNo = (qtyNoObj != null && String.valueOf(qtyNoObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtyNoObj)) : 0;

                            Object qtySetObj = jsonData.get('add_misc_section_quantity_in_one_set_input' + suffix);
                            Decimal qtyInSet = (qtySetObj != null && String.valueOf(qtySetObj).trim() != '') ? Decimal.valueOf(String.valueOf(qtySetObj)) : 1;

                            Decimal finalQty = (uom == 'PCS' || uom == 'EA' || uom == 'NOS') ? (qtyNo * qtyInSet) : qtyNo;
                            row.put('quantity', finalQty);

                            Object upObj = row.get('unitPrice');
                            Decimal rawUnitPrice = (upObj != null && String.valueOf(upObj).trim() != '') ? Decimal.valueOf(String.valueOf(upObj)) : 0;
                            Decimal unitPrice = Math.ceil((rawUnitPrice * effectiveFactor) / 5.0) * 5;

                            Object ucObj = row.get('unitCost');
                            Decimal rawUnitCost = (ucObj != null && String.valueOf(ucObj).trim() != '') ? Decimal.valueOf(String.valueOf(ucObj)) : 0;
                            Decimal unitCost = Math.ceil((rawUnitCost * effectiveFactor) / 5.0) * 5;

                            Object ulpObj = row.get('unitListPrice');
                            Decimal rawUnitListPrice = (ulpObj != null && String.valueOf(ulpObj).trim() != '') ? Decimal.valueOf(String.valueOf(ulpObj)) : 0;
                            Decimal unitListPrice = Math.ceil((rawUnitListPrice * effectiveFactor) / 5.0) * 5;

                            System.debug('[_Saved_Table_Rows] Additional Misc Unit Price | Item: ' + rowName + ' | Original: ' + rawUnitPrice + ' | Updated: ' + unitPrice);

                            row.put('unitPrice', unitPrice);
                            row.put('unitCost', unitCost);
                            row.put('unitListPrice', unitListPrice);
                            row.put('netPrice', Math.ceil((finalQty * unitPrice) / 5.0) * 5);
                            row.put('cost', Math.ceil((finalQty * unitCost) / 5.0) * 5);
                            row.put('listPrice', Math.ceil((finalQty * unitListPrice) / 5.0) * 5);

                            rowAlreadyFactored = true;
                            addMiscIndex++;
                        }

                        // Safeguard row id check and totalAmount
                        if (String.valueOf(row.get('id')) != String.valueOf(quoteRecord.Id)) {
                            row.put('SlNo', slNo++);
                            
                            Object wObj = row.get('weight');
                            Decimal rowWeight = (wObj != null && String.valueOf(wObj).trim() != '') ? Decimal.valueOf(String.valueOf(wObj)) : 0.00;
                            row.put('weight', rowWeight);
                            
                            Object qObj = row.get('quantity');
                            Decimal qty = (qObj != null && String.valueOf(qObj).trim() != '') ? Decimal.valueOf(String.valueOf(qObj)) : 1;
                            
                            Object rObj = row.get('rate');
                            Object upObj2 = row.get('unitPrice');
                            Decimal origRate = (rObj != null && String.valueOf(rObj).trim() != '') ? Decimal.valueOf(String.valueOf(rObj)) : ((upObj2 != null && String.valueOf(upObj2).trim() != '') ? Decimal.valueOf(String.valueOf(upObj2)) : 0);
                            // 1.00 for rows a branch already factored; unchanged for the rest
                            Decimal rowFactor = rowAlreadyFactored ? 1.00 : effectiveFactor;
                            Decimal rate = Math.ceil((origRate * rowFactor) / 5.0) * 5;

                            System.debug('[_Saved_Table_Rows] Table Row Rate | Item: ' + rowName + ' | Original: ' + origRate + ' | Updated: ' + rate);
                            
                            Object ppObj = row.get('price_per_uom');
                            Object npObj = row.get('netPrice');
                            Decimal origPricePerUom = (ppObj != null && String.valueOf(ppObj).trim() != '') ? Decimal.valueOf(String.valueOf(ppObj)) : ((npObj != null && String.valueOf(npObj).trim() != '') ? Decimal.valueOf(String.valueOf(npObj)) : origRate);
                            Decimal pricePerUom = Math.ceil((origPricePerUom * rowFactor) / 5.0) * 5;
                            
                            Object tpObj = row.get('total_price');
                            Decimal lineTotal = (tpObj != null && String.valueOf(tpObj).trim() != '') ? Math.ceil((Decimal.valueOf(String.valueOf(tpObj)) * rowFactor) / 5.0) * 5 : Math.ceil((qty * pricePerUom) / 5.0) * 5;
                            
                            row.put('rate', rate);
                            row.put('unitPrice', rate);
                            row.put('unitCost', rate);
                            row.put('price_per_uom', pricePerUom);
                            row.put('total_price', lineTotal);
                            row.put('per_price', rate);
                            row.put('per_price_total', Math.ceil((rate * qty) / 5.0) * 5);

                            totalAmount += lineTotal;
                            lineItems.add(row);
                        }
                    }
                }

                // ─── Remove Duplicates ──────────────────────────────────────────────
                List<Map<String, Object>> cleanMainLines = new List<Map<String, Object>>();
                for (Map<String, Object> item : lineItems) {
                    String itemName = (String) item.get('name');
                    if (itemName == null) itemName = '';
                    String upName = itemName.toUpperCase();
                    
                    if ((upName.startsWith('ACCESSORY:') || upName.startsWith('MISC:') || upName.startsWith('ADD') ||
                         upName.contains('CONVENTIONAL') || upName.contains('NATRAX') || upName.contains('ALKA') ||
                         upName.contains('TRANSPOLIS') || upName.contains('RAILWAY') || upName.contains('NON-SPACER') || 
                         upName.contains('NOISE BARRIER') || upName.contains('PEDESTRIAN GUARD RAIL'))
                         && !item.containsKey('id')) {
                        continue;
                    }
                    cleanMainLines.add(item);
                }
                
                lineItems = cleanMainLines;

                // Calculate exact totals
                totalAccessoriesAmount = 0.00;
                totalMiscAmount = 0.00;
                totalAddlMiscAmount = 0.00;
                absoluteGrandTotal = 0.00;

                for (Map<String, Object> item : lineItems) {
                    String itemNameStr = (String) item.get('name');
                    if (itemNameStr == null) continue;
                    String upName = itemNameStr.toUpperCase();

                    Boolean isMainProduct = !(upName.startsWith('ACCESSORY:') || upName.startsWith('MISC:') || upName.startsWith('ADD'));
                    
                    if (isMainProduct) {
                        Decimal mainItemTotal = 0.00;
                        Decimal qty = item.get('quantity') != null ? Decimal.valueOf(String.valueOf(item.get('quantity'))) : 1;
                        if (item.get('unitCost') != null) {
                            mainItemTotal = Decimal.valueOf(String.valueOf(item.get('unitCost'))) * qty;
                        } else if (item.get('unitPrice') != null) {
                            mainItemTotal = Decimal.valueOf(String.valueOf(item.get('unitPrice'))) * qty;
                        }
                        absoluteGrandTotal += mainItemTotal;
                    } else {
                        Decimal expenses = 0.00;
                        if (item.get('expenses') != null && String.valueOf(item.get('expenses')).trim() != '') {
                            expenses = Decimal.valueOf(String.valueOf(item.get('expenses')));
                        }
                        
                        Decimal perPriceTotal = 0.00;
                        if (item.get('per_price_total') != null && String.valueOf(item.get('per_price_total')).trim() != '') {
                            perPriceTotal = Decimal.valueOf(String.valueOf(item.get('per_price_total')));
                        }
                        
                        Decimal amountToAdd = expenses > 0 ? expenses : perPriceTotal;
                        absoluteGrandTotal += amountToAdd;
                        
                        if (upName.startsWith('ACCESSORY:')) {
                            totalAccessoriesAmount += amountToAdd;
                        } else if (upName.startsWith('MISC:') && !upName.startsWith('ADD')) {
                            totalMiscAmount += amountToAdd;
                        } else if (upName.startsWith('ADD MISC:') || upName.startsWith('ADDL MISC:')) {
                            totalAddlMiscAmount += amountToAdd;
                        }
                    }
                }

                // Calculate the Global Accessories/Misc Sub-Total
                globalTotalCharges = totalAccessoriesAmount + totalMiscAmount + totalAddlMiscAmount;

                // Safely add Transportation/FVF charges to BOTH totals
                Object accFvf = jsonData.get('acc_section_fvf');
                if (accFvf != null && String.isNotBlank(String.valueOf(accFvf))) {
                    Decimal val = Decimal.valueOf(String.valueOf(accFvf));
                    globalTotalCharges += val;
                    absoluteGrandTotal += val;
                }
                
                Object miscFvf = jsonData.get('misc_section_fvf');
                if (miscFvf != null && String.isNotBlank(String.valueOf(miscFvf))) {
                    Decimal val = Decimal.valueOf(String.valueOf(miscFvf));
                    globalTotalCharges += val;
                    absoluteGrandTotal += val;
                }
                
                Object addMiscFvf = jsonData.get('add_misc_fvf');
                if (addMiscFvf != null && String.isNotBlank(String.valueOf(addMiscFvf))) {
                    Decimal val = Decimal.valueOf(String.valueOf(addMiscFvf));
                    globalTotalCharges += val;
                    absoluteGrandTotal += val;
                }

                Object pgrFvf = jsonData.get('PGR_full_vehicle_freight');
                if (pgrFvf != null && String.isNotBlank(String.valueOf(pgrFvf))) {
                    Decimal val = Decimal.valueOf(String.valueOf(pgrFvf));
                    absoluteGrandTotal += val;
                }

                if (totalFreightCharges != null) {
                    absoluteGrandTotal += totalFreightCharges;
                }

                System.debug('=== FINAL TOTALS SUMMARY ===');
                System.debug('Show Separate Interest: ' + showSeperateInterest);
                System.debug('Calculated Interest Factor: ' + intrestfactor);
                System.debug('Effective Item Factor: ' + effectiveFactor);
                System.debug('Absolute Grand Total: ' + absoluteGrandTotal);
                
            } catch (Exception e) {
                System.debug('CRITICAL JSON PARSE ERROR: ' + e.getMessage() + ' | Stack Trace: ' + e.getStackTraceString() + ' | At Line: ' + e.getLineNumber());
            }
        } else {
            System.debug('WARNING: Quote_Value__c was null or empty on Quote record.');
        }
        
        // ─── Crash Barrier Specific Terms & Conditions ─────────
        if (jsonData != null) {
            String termType = jsonData.get('tc_payment_terms_picklist') != null ? String.valueOf(jsonData.get('tc_payment_terms_picklist')).trim() : '';
            String interestFreeDays = jsonData.get('tc_no_of_days_interest_free_credit') != null ? String.valueOf(jsonData.get('tc_no_of_days_interest_free_credit')).trim() : '0';
            
            if (termType.equalsIgnoreCase('Against Open credit')) dynamicPaymentTerms = 'Against Open credit ' + interestFreeDays + ' days.';
            else if (termType.equalsIgnoreCase('Against BG')) dynamicPaymentTerms = 'Against BG ' + interestFreeDays + ' days.';
            else if (termType.equalsIgnoreCase('Against LC')) {
                String usancePer = jsonData.get('tc_usance_period') != '' ? String.valueOf(jsonData.get('tc_usance_period')).trim() : '0';
                if(usancePer == '0'){
                    dynamicPaymentTerms = 'Against LC ' + interestFreeDays +' days.';
                }else{
                    dynamicPaymentTerms = 'Against ' + usancePer + ' days Usance LC (' + interestFreeDays + ' days IFC).';
                }
            }
            else if (termType.equalsIgnoreCase('Advance')) dynamicPaymentTerms = '100% Advance before dispatch';
            else if (String.isNotBlank(termType)) dynamicPaymentTerms = termType;
            else dynamicPaymentTerms = '100% advance along with PI.';
            
            String freightIncoterms = jsonData.get('freight_incoterms') != null ? String.valueOf(jsonData.get('freight_incoterms')) : '';
            // 1. Determine address prefix
            Boolean useShipping = jsonData.get('has_transportation_address') == true;
            String prefix = useShipping ? 'sa_' : 'ba_';
            
            // 2. Build destination address dynamically
            String destination = '';
            List<String> addressParts = new List<String>();
            List<String> fieldSuffixes = new List<String>{'street', 'city', 'state', 'zip_code', 'country'};
            
            for (String suffix : fieldSuffixes) {
                Object valObj = jsonData.get(prefix + suffix);
                if (valObj != null) {
                    String val = String.valueOf(valObj).trim();
                    if (String.isNotBlank(val) && !val.equalsIgnoreCase('Not Found') && !val.equalsIgnoreCase('null')) {
                        addressParts.add(val);
                    }
                }
            }
            destination = String.join(addressParts, ', ');
            
            // 3. Dynamic sentence construction
            String tType = freightIncoterms.containsIgnoreCase('F.O.R') ? 'F.O.R.' 
                        : freightIncoterms.containsIgnoreCase('Ex-Work') ? 'Ex-Work' 
                        : null;
            
            if (tType != null) {
                // Appends destination if one was successfully generated (works for both shipping or billing address)
                dynamicFreightTerm = 'The rates quoted are on ' + tType + ' basis' + 
                    (String.isNotBlank(destination) ? ' at destination ' + destination + '.' : '.');
            } else {
                // Default fallback
                dynamicFreightTerm = 'The rates quoted are on Ex-Work basis.';
            }
        } else {
            dynamicPaymentTerms = '100% advance along with PI.';
            dynamicFreightTerm  = 'The rates are on Ex - works basis.';
        }
        
        if (jsonData != null && jsonData.containsKey('tc_validity_days') && jsonData.get('tc_validity_days') != null) {
            validityDays = String.valueOf(jsonData.get('tc_validity_days'));
        } else {
            validityDays = '';
        }

        System.debug('=== CrashBarrierQuoteController Constructor Completed Successfully ===');
    }
}