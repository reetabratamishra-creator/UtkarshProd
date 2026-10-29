public class TransmissionTowerOfferController {

    public Quote  quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
    public Decimal totalAmount { get; set; }
    public String todayDate   { get; set; }
    public String productType { get; set; }
    public String quoteAccount { get; set; }
    public String quoteNumber {get; set;}
    
    public String hasIncoterms {get; set;}
    public String activeGsmDisplay { get; set; } 
    public String activeBoltDisplay { get; set; }
    
    public String logoBase64 { get; set; }
    public String currentUser { get; set; }
    public String currentUserPhone { get; set; }
    public String currentUserEmail { get; set; }
    public Boolean hasProtoAssembly { get; set; }
    public String protoAssembly { get; set; }
    public String pricingType { get; set; }
    public Boolean isTransportationToAdd { get; set; }
    
    // Terms/condition details
    public Decimal tcMonthDays { get; set; }
    public Decimal tcOfferValidity { get; set; }
    public Decimal protoInclusive { get; set; }
	public String jobName { get; set; }   
    public String paymentTermsDetails { get; set; }
    public String deliveryDetails { get; set; }
        
    // tower tables
    private List<TowerPriceTable> towerTablesInternal;
    public List<TowerPriceTable> getTowerTables() {
        if (towerTablesInternal == null) towerTablesInternal = buildTowerTables();
        return towerTablesInternal;
    }
    
    // substation tables
    private List<SubstationPriceTable> substationTablesInternal;
    public List<SubstationPriceTable> getSubstationTables() {
        if (substationTablesInternal == null) substationTablesInternal = buildSubstationTables();
        return substationTablesInternal;
    }
    
    // Per Metric Ton table
    private List<FreightRow> freightRowsInternal;
    public List<FreightRow> getFreightRows() {
        if (freightRowsInternal == null) freightRowsInternal = buildFreightRows();
        return freightRowsInternal;
    }
    
    // Minimum Guaranteed Loadability table
    private List<LoadabilityRow> loadabilityRowsInternal;
    public List<LoadabilityRow> getLoadabilityRows() {
        if (loadabilityRowsInternal == null) loadabilityRowsInternal = buildLoadabilityRows();
        return loadabilityRowsInternal;
    }
    
    public class FreightRow {
        public String location   { get; set; }
        public String ratePerTon { get; set; }
        public FreightRow(String location, String ratePerTon) {
            this.location   = location;
            this.ratePerTon = ratePerTon;
        }
    }
    
    public class LoadabilityRow {
        public String location             { get; set; }
        public String description          { get; set; }
        public String vehicleLoadability   { get; set; }
        public String minGuaranteedFreight { get; set; }
        public LoadabilityRow(String location, String description, String vehicleLoadability, String minGuaranteedFreight) {
            this.location             = location;
            this.description          = description;
            this.vehicleLoadability   = vehicleLoadability;
            this.minGuaranteedFreight = minGuaranteedFreight;
        }
    }
    
        public class TowerRow {
            public String  label      { get; set; }
            public String  uom        { get; set; }
            public String  unitPrice  { get; set; }
            public String  quantity   { get; set; }
            public String  totalPrice { get; set; }
            public Boolean isTotal    { get; set; }  
            public Boolean isNuts     { get; set; }
     
            public TowerRow(String label, String uom, String unitPrice, String quantity, String totalPrice, Boolean isTotal, Boolean isNuts) {
                this.label      = label;
                this.uom        = uom;
                this.unitPrice  = unitPrice;
                this.quantity   = quantity;
                this.totalPrice = totalPrice;
                this.isTotal    = isTotal;
                this.isNuts     = isNuts;
            }
    	}
    
        private class LineData {
            public Decimal price    { get; set; }
            public Decimal quantity { get; set; }
            public LineData(Decimal price, Decimal quantity) {
                this.price = price;
                this.quantity = (quantity != null) ? quantity : 0;
            }
        }
    
        public class TowerPriceTable {
            public String title { get; set; }
            public List<TowerRow> rows  { get; set; }
            public TowerPriceTable(String title) {
                this.title = title;
                this.rows  = new List<TowerRow>();
            }
        }
    
        public class SubstationRow {
            public String  label     { get; set; }
            public String  uom       { get; set; }
            public String  unitPrice { get; set; }
            public Boolean isNuts    { get; set; }
     
            public SubstationRow(String label, String uom, String unitPrice, Boolean isNuts) {
                this.label     = label;
                this.uom       = uom;
                this.unitPrice = unitPrice;
                this.isNuts    = isNuts;
            }
        }
    	
    	public class SubstationSection {
            public String sectionTitle { get; set; }  // e.g. "GANTRY STRUCTURE"
            public List<SubstationRow> rows { get; set; }
            public SubstationSection(String sectionTitle) {
                this.sectionTitle = sectionTitle;
                this.rows = new List<SubstationRow>();
            }
        }
    
    	public class SubstationPriceTable {
            public String title    { get; set; }
            public List<SubstationSection> sections { get; set; }
            public SubstationPriceTable(String title) {
                this.title    = title;
                this.sections = new List<SubstationSection>();
            }
        }
    
    public TransmissionTowerOfferController(ApexPages.StandardController stdController) {
        jsonData    = new Map<String, Object>();
        todayDate   = Date.today().format();
        totalAmount = 0;
        productType = '';
        
        List<Quote> quotes = [
            SELECT Id, Name, Quote_Value__c, AccountId, QuoteNumber,Quote_Reference__c
            FROM   Quote
            WHERE  Id = :stdController.getId()
            LIMIT  1
        ];
        User u = [SELECT Id, Name, Phone, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        currentUser = u.Name;
        currentUserPhone = u.Phone;
        currentUserEmail = u.Email;
        

        if (quotes.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Quote record not found.'));
            return;
        }

        quoteRecord = quotes[0];
        quoteNumber = quotes[0].Quote_Reference__c;
        if(!String.isEmpty(quotes[0].AccountId))
           quoteAccount = [SELECT ID, Name FROM Account WHERE Id = :quotes[0].AccountId].Name;
        
        if (String.isBlank(quoteRecord.Quote_Value__c)) return;

        try {
            jsonData = (Map<String, Object>)
                JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
            //check product type
            productType = strVal('type_of_product');
            // check incoterms type
            hasIncoterms = strVal('Incoterms');
            if(String.isEmpty(hasIncoterms)){
                hasIncoterms = 'Ex-works';
            }
            
            // get pricing type if tower type
            if(!String.isEmpty(strVal('pvt_price_basics'))){
                pricingType = strVal('pvt_price_basics');
            }
            
            // check transportation to be added
            isTransportationToAdd = (strVal('tower_project_for_transportation_addition') == 'YES');
            
            // get pricing type if Substaion type
            if(!String.isEmpty(strVal('pvs_price_model'))){
                pricingType = strVal('pvs_price_model');
            }
            
            // get terms/condition details;
            jobName = strVal('tc_payment_terms_job_name');
            protoInclusive = decVal('tc_payment_terms_proto_inclusive');
            tcMonthDays = decVal('tc_payment_terms_month_days');
            paymentTermsDetails = strVal('tc_payment_terms_details');
            deliveryDetails = strVal('tc_payment_terms_delivery');
            tcOfferValidity = decVal('tc_payment_terms_offer_validity');
            
            // updated proto Assembly addition  
            if(productType == 'Tower'){
                String prefix = (pricingType == 'Price Variation') ? 'pvt_pv_' : 'pvt_firm_';
                hasProtoAssembly = boolVal(prefix + 'pat');
                if(hasProtoAssembly){
                    protoAssembly = strVal(prefix + 'pat_price');
                }
            }
            else{
                String prefix = (pricingType == 'Price Variation') ? 'pvs_pv_' : 'pvs_firm_';
                hasProtoAssembly = boolVal(prefix + 'pat');
                if(hasProtoAssembly){
                    protoAssembly = strVal(prefix + 'pat_price');
                }
            }            
            
            computeDisplayFlags();
            
            // convert logo to show in word doc.
            List<StaticResource> sr = [ SELECT Body, ContentType FROM StaticResource WHERE  Name = 'UtkarshHeader' LIMIT  1];
            if (!sr.isEmpty()) {
                // Use the actual ContentType stored on the resource (image/png, image/jpeg, …)
                String mime = String.isNotBlank(sr[0].ContentType)
                              ? sr[0].ContentType
                              : 'image/png';
                logoBase64 = 'data:' + mime + ';base64,'
                           + EncodingUtil.base64Encode(sr[0].Body);
            } else {
                logoBase64 = '';
            }
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Failed to parse Quote JSON: ' + ex.getMessage()));
        }
    }
    
    // Tower Table Builder
    private List<TowerPriceTable> buildTowerTables(){
        List<TowerPriceTable> tables = new List<TowerPriceTable>();
        if (jsonData == null || jsonData.isEmpty()) return tables;
        
        Object rawLines = jsonData.get('_Saved_Table_Rows');
        if (rawLines == null) return tables;
        List<Object> lineList = (List<Object>) rawLines;
        
        // ── Parse lines ───────────────────────────────────────────────────────
        // Tower pricing lines key: "PV|MS|610", "FIRM|HT|900", etc.
        Map<String, LineData> towerLines = new Map<String, LineData>();
        // Nuts & Bolts lines key: "5.6|PV|610", "FOUNDATION BOLT|PV|610", etc.
        Map<String, LineData> nutsLines  = new Map<String, LineData>();
        
        for (Object obj : lineList){
            Map<String, Object> line  = (Map<String, Object>) obj;
 			String rawName = strObj(line.get('name')).toUpperCase();
            Decimal price  = decObjVal(line.get('unitPrice'));
            Decimal qty    = decObjVal(line.get('quantity'));
            if (qty == null) qty = 0;
            
            if(rawName.startsWith('PRICE MODEL - TOWER')){
                String pricingCode = rawName.contains('- FIRM-') ? 'FIRM' : 'PV';
                String steelType = rawName.contains('-MS-') ? 'MS' : 'HT';
                String gsm = extractGsm(rawName);
                
                if (gsm == null) continue;
                String key = pricingCode + '|' + steelType + '|' + gsm;
                
                towerLines.put(key, new LineData(price, qty));
            }
            else if(rawName.startsWith('NUTS') && rawName.contains('BOLT')){
                String pricingCode = rawName.contains('| PV-') ? 'PV' : 'FIRM';
                String gsm = extractGsm(rawName);
                if (gsm == null) continue;
                
                String nutsType = extractNutsType(rawName);
                if (nutsType == null) continue;
                
                String key = nutsType + '|' + pricingCode + '|' + gsm;
                nutsLines.put(key, new LineData(price, qty));
            }
        }
        
        // ── Nuts & Bolts flag configuration ───────────────────────────────────
        // Tower uses pvt_ prefix flags
        Boolean hasPvt56    = boolVal('pvs_type_5_6')   || boolVal('pvt_type_5_6');
        Boolean hasPvt68    = boolVal('pvs_type_6_8')   || boolVal('pvt_type_6_8');
        Boolean hasPvt88    = boolVal('pvs_type_8_8')   || boolVal('pvt_type_8_8');
        Boolean hasPvtFB    = boolVal('pvs_foundation_bolt_checkbox') || boolVal('pvt_foundation_bolt_checkbox');
        Boolean hasPvtMSTpl = boolVal('pvs_ms_template_without_galvanization_checkbox')
                           || boolVal('pvt_ms_template_without_galvanization_checkbox');
        
        // ── Determine table order ─────────────────────────────────────────────
        // PV first, then FIRM; within each: 610, 900, 1000
        List<String> orderedGroups = new List<String>();
        for (String pc : new List<String>{ 'PV', 'FIRM' }) {
            for (String gsm : new List<String>{ '610', '900', '1000' }) {
                Boolean hasMS = towerLines.containsKey(pc + '|MS|' + gsm);
                Boolean hasHT = towerLines.containsKey(pc + '|HT|' + gsm);
                if (hasMS || hasHT) orderedGroups.add(pc + '|' + gsm);
            }
        }
        
        // ── Build one table per group ─────────────────────────────────────────
        for (String gk : orderedGroups){
            List<String> parts = gk.split('\\|');
            String pricingCode = parts[0];
            String gsm = parts[1];
            
            String pricingLabel = (pricingCode == 'PV') ? 'PV' : 'FIRM';
            String tableTitle   = pricingLabel + ' Rates - Tower - ' + gsm + ' GSM';
            
            TowerPriceTable tbl = new TowerPriceTable(tableTitle);
            Decimal totalQty    = 0;
            Decimal totalAmt    = 0;
            
            // MS ROW
            LineData msData = towerLines.get(pricingCode + '|MS|' + gsm);
            if (msData != null) {
                Decimal tp = msData.price * msData.quantity;
                tbl.rows.add(new TowerRow('MS', 'MT',
                    fmtNum(msData.price), fmtNum(msData.quantity), fmtNum(tp), false, false));
                totalQty += msData.quantity;
                totalAmt += tp;
            }
            
            // HT row
            LineData htData = towerLines.get(pricingCode + '|HT|' + gsm);
            if (htData != null) {
                Decimal tp = htData.price * htData.quantity;
                tbl.rows.add(new TowerRow('HT', 'MT',
                    fmtNum(htData.price), fmtNum(htData.quantity), fmtNum(tp), false, false));
                totalQty += htData.quantity;
                totalAmt += tp;
            }
            
            // Nuts & Bolts rows — keyed by nutsType|pricingCode|gsm
            if (hasPvt56) {
                LineData d = nutsLines.get('5.6|' + pricingCode + '|' + gsm);
                if (d != null) {
                    Decimal tp = d.price * d.quantity;
                    tbl.rows.add(new TowerRow('Nuts & Bolts (5.6)', 'MT',
                        fmtNum(d.price), fmtNum(d.quantity), fmtNum(tp), false, true));
                    totalQty += d.quantity;
                    totalAmt += tp;
                }
            }
            if (hasPvt68) {
                LineData d = nutsLines.get('6.8|' + pricingCode + '|' + gsm);
                if (d != null) {
                    Decimal tp = d.price * d.quantity;
                    tbl.rows.add(new TowerRow('Nuts & Bolts (6.8)', 'MT',
                        fmtNum(d.price), fmtNum(d.quantity), fmtNum(tp), false, true));
                    totalQty += d.quantity;
                    totalAmt += tp;
                }
            }
            if (hasPvt88) {
                LineData d = nutsLines.get('8.8|' + pricingCode + '|' + gsm);
                if (d != null) {
                    Decimal tp = d.price * d.quantity;
                    tbl.rows.add(new TowerRow('Nuts & Bolts (8.8)', 'MT',
                        fmtNum(d.price), fmtNum(d.quantity), fmtNum(tp), false, true));
                    totalQty += d.quantity;
                    totalAmt += tp;
                }
            }
            if (hasPvtFB) {
                LineData d = nutsLines.get('FOUNDATION BOLT|' + pricingCode + '|' + gsm);
                if (d != null) {
                    Decimal tp = d.price * d.quantity;
                    tbl.rows.add(new TowerRow('Foundation Bolt', 'MT',
                        fmtNum(d.price), fmtNum(d.quantity), fmtNum(tp), false, true));
                    totalQty += d.quantity;
                    totalAmt += tp;
                }
            }
            if (hasPvtMSTpl) {
                String msTplJsonKey = getTowerMsTemplateKey(pricingCode, gsm);
                Decimal msTplPrice  = (msTplJsonKey != null) ? decVal(msTplJsonKey) : null;
                if (msTplPrice != null && msTplPrice != 0) {
                    String tplKey = (pricingCode == 'PV')
                        ? 'MS TEMPLATE (PV)|PV|' + gsm
                        : 'MS TEMPLATE (FIRM)|FIRM|' + gsm;
                    LineData d = nutsLines.get(tplKey);
                    if (d == null) d = nutsLines.get('MS TEMPLATE|' + pricingCode + '|' + gsm);
                    Decimal msTplQty = (d != null) ? d.quantity : 0;
                    Decimal tp = msTplPrice * msTplQty;
                    tbl.rows.add(new TowerRow('MS Template', 'MT',
                        fmtNum(msTplPrice), fmtNum(msTplQty), fmtNum(tp), false, true));
                    totalQty += msTplQty;
                    totalAmt += tp;
                }
            }
            
            // TOTAL row
            //tbl.rows.add(new TowerRow('TOTAL', '', '',
                //fmtNum(totalQty), fmtNum(totalAmt), true, false));
 
            tables.add(tbl); 
        }
        
        return tables;
    }
    
    // substation table build
    private List<SubstationPriceTable> buildSubstationTables(){
        List<SubstationPriceTable> tables = new List<SubstationPriceTable>();
        if (jsonData == null || jsonData.isEmpty()) return tables;
        
        Object rawLines = jsonData.get('_Saved_Table_Rows');
        if (rawLines == null) return tables;
        List<Object> lineList = (List<Object>) rawLines;
        
        // ── Parse lines ───────────────────────────────────────────────────────
        // Key format for pricing lines: "PV|GANTRY|MS|610"
        Map<String, LineData> substLines = new Map<String, LineData>();
        // Nuts key: "5.6|PV|GANTRY|610"
        Map<String, LineData> nutsLines  = new Map<String, LineData>();
        
        for (Object obj : lineList) {
            Map<String, Object> line  = (Map<String, Object>) obj;
            String rawName = strObj(line.get('name')).toUpperCase();
            Decimal price  = decObjVal(line.get('unitPrice'));
            Decimal qty    = decObjVal(line.get('quantity'));
            if (qty == null) qty = 0;
 
            if (rawName.startsWith('PRICE MODEL - SUBSTATION')) {
                // e.g. "PRICE MODEL - SUBSTATION - PV-GANTRY STRUCTURE-MS-610 GSM"
                String pricingCode = rawName.contains('- FIRM-') ? 'FIRM' : 'PV';
                String structure   = extractStructure(rawName);
                String steelType   = rawName.contains('-MS-') ? 'MS' : 'HT';
                String gsm         = extractGsm(rawName);
                if (gsm == null || structure == null) continue;
                String key = pricingCode + '|' + structure + '|' + steelType + '|' + gsm;
                substLines.put(key, new LineData(price, qty));
 
            } else if ((rawName.startsWith('NUTS') && rawName.contains('BOLT'))
                    || rawName.contains('MS TEMPLATE')) {
                // e.g. "NUTS & BOLTS - GRADE - 5.6 [GANTRY | PV-610 GSM]"
                //      "NUTS & BOLTS - FOUNDATION BOLT [EQUIPMENT | PV-610 GSM]"
                String pricingCode = rawName.contains('| PV-') ? 'PV' : 'FIRM';
                String gsm         = extractGsm(rawName);
                String structure   = extractSubstationStructureFromNuts(rawName);
                if (gsm == null) continue;
                String nutsType    = extractNutsType(rawName);
                if (nutsType == null) continue;
 
                // Key includes structure so each section gets its own nuts rows
                String key = nutsType + '|' + pricingCode + '|'
                    + (structure != null ? structure : 'ALL') + '|' + gsm;
                nutsLines.put(key, new LineData(price, qty));
            }
        }
        
        // ── Active structure types ─────────────────────────────────────────────
        Boolean hasGantry    = boolVal('pvs_gantry_structure');
        Boolean hasEquipment = boolVal('pvs_equipment_structure');
        Boolean hasComposite = boolVal('pvs_composite_structure');
        
        // ── Nuts & Bolts flag configuration ───────────────────────────────────
        Boolean has56    = boolVal('pvs_type_5_6');
        Boolean has68    = boolVal('pvs_type_6_8');
        Boolean has88    = boolVal('pvs_type_8_8');
        Boolean hasFB    = boolVal('pvs_foundation_bolt_checkbox');
        Boolean hasMSTpl = boolVal('pvs_ms_template_without_galvanization_checkbox');
        
        // ── Determine table order ─────────────────────────────────────────────
        List<String> orderedGroups = new List<String>();
        for (String pc : new List<String>{ 'PV', 'FIRM' }) {
            for (String gsm : new List<String>{ '610', '900', '1000' }) {
                // Check if any structure has data for this pricing+gsm
                Boolean found = false;
                for (String st : new List<String>{ 'GANTRY', 'EQUIPMENT', 'COMPOSITE' }) {
                    if (substLines.containsKey(pc + '|' + st + '|MS|' + gsm)
                     || substLines.containsKey(pc + '|' + st + '|HT|' + gsm)) {
                        found = true;
                        break;
                    }
                }
                if (found) orderedGroups.add(pc + '|' + gsm);
            }
        }
        
        // ── Build one table per group ─────────────────────────────────────────
        for (String gk : orderedGroups){
            List<String> parts = gk.split('\\|');
            String pricingCode = parts[0];
            String gsm = parts[1];
            
            String pricingLabel = (pricingCode == 'PV') ? 'PV' : 'FIRM';
            String tableTitle   = pricingLabel + ' Rates - Substation - ' + gsm + ' GSM';
            
            SubstationPriceTable tbl = new SubstationPriceTable(tableTitle);
            
            // Each active structure type becomes a section
            Map<String, String> structureLabels = new Map<String, String>{
                'GANTRY'    => 'GANTRY STRUCTURE',
                'EQUIPMENT' => 'EQUIPMENT STRUCTURE',
                'COMPOSITE' => 'COMPOSITE STRUCTURE'
            };
            List<String> structureOrder = new List<String>{ 'GANTRY', 'EQUIPMENT', 'COMPOSITE' };
            Map<String, Boolean> structureActive = new Map<String, Boolean>{
                'GANTRY'    => hasGantry,
                'EQUIPMENT' => hasEquipment,
                'COMPOSITE' => hasComposite
            };
                
           for (String structKey : structureOrder) {
                if (!structureActive.get(structKey)) continue;
 
                // Check this structure actually has any data for this pricing+gsm
                Boolean hasData = substLines.containsKey(pricingCode + '|' + structKey + '|MS|' + gsm)
                 || substLines.containsKey(pricingCode + '|' + structKey + '|HT|' + gsm);
                if (!hasData) continue;
 
                SubstationSection section = new SubstationSection(structureLabels.get(structKey));
 
                // MS row
                LineData msData = substLines.get(pricingCode + '|' + structKey + '|MS|' + gsm);
                if (msData != null) {
                    section.rows.add(new SubstationRow('MS', 'MT', fmtNum(msData.price), false));
                }
 
                // HT row
                LineData htData = substLines.get(pricingCode + '|' + structKey + '|HT|' + gsm);
                if (htData != null) {
                    section.rows.add(new SubstationRow('HT', 'MT', fmtNum(htData.price), false));
                }
 
                // Nuts & Bolts rows
                // Try structure-specific key first, then fall back to 'ALL'
                if (has56) {
                    LineData d = nutsLines.get('5.6|' + pricingCode + '|' + structKey + '|' + gsm);
                    if (d == null) d = nutsLines.get('5.6|' + pricingCode + '|ALL|' + gsm);
                    if (d != null) {
                        section.rows.add(new SubstationRow('Nuts & Bolts (5.6)', 'MT', fmtNum(d.price), true));
                    }
                }
                if (has68) {
                    LineData d = nutsLines.get('6.8|' + pricingCode + '|' + structKey + '|' + gsm);
                    if (d == null) d = nutsLines.get('6.8|' + pricingCode + '|ALL|' + gsm);
                    if (d != null) {
                        section.rows.add(new SubstationRow('Nuts & Bolts (6.8)', 'MT', fmtNum(d.price), true));
                    }
                }
                if (has88) {
                    LineData d = nutsLines.get('8.8|' + pricingCode + '|' + structKey + '|' + gsm);
                    if (d == null) d = nutsLines.get('8.8|' + pricingCode + '|ALL|' + gsm);
                    if (d != null) {
                        section.rows.add(new SubstationRow('Nuts & Bolts (8.8)', 'MT', fmtNum(d.price), true));
                    }
                }
                if (hasFB) {
                    LineData d = nutsLines.get('FOUNDATION BOLT|' + pricingCode + '|' + structKey + '|' + gsm);
                    if (d == null) d = nutsLines.get('FOUNDATION BOLT|' + pricingCode + '|ALL|' + gsm);
                    if (d != null) {
                        section.rows.add(new SubstationRow('Foundation Bolt', 'MT', fmtNum(d.price), true));
                    }
                }
                if (hasMSTpl) {
                    String msTplJsonKey = getSubstationMsTemplateKey(pricingCode, structKey, gsm);
                    Decimal msTplPrice  = (msTplJsonKey != null) ? decVal(msTplJsonKey) : null;
                    if (msTplPrice != null && msTplPrice != 0) {
                        section.rows.add(new SubstationRow('MS Template', 'MT', fmtNum(msTplPrice), true));
                    }
                }
 
                tbl.sections.add(section);
            }
 
            if (!tbl.sections.isEmpty()) tables.add(tbl);
        }
        return tables;
    }
    
    
    // Per Metric Ton table builder
    private List<FreightRow> buildFreightRows() {
        List<FreightRow> rows = new List<FreightRow>();
        if (jsonData == null || jsonData.isEmpty()) return rows;
        if (strVal('tower_project_for_type') != 'Per Metric Ton') return rows;
    
        for (Integer n = 1; n <= 10; n++) {
            String loc = strVal('rpt_location_' + n);
            if (String.isBlank(loc)) continue;
            String rate = strVal('rpt_rate_per_ton_' + n);
            rows.add(new FreightRow(loc, rate));
        }
        return rows;
    }
    
    // Minimum Guaranteed Loadability table builder
    private List<LoadabilityRow> buildLoadabilityRows() {
        List<LoadabilityRow> rows = new List<LoadabilityRow>();
        if (jsonData == null || jsonData.isEmpty()) return rows;
        if (strVal('tower_project_for_type') != 'Minimum Guaranteed Loadability') return rows;
    
        for (Integer n = 1; n <= 10; n++) {
            String loc = strVal('mgl_location_' + n);
            if (String.isBlank(loc)) continue;
            String description        = strVal('mgl_description_of_the_tower_' + n);
            String loadability = strVal('mgl_vehicle_loadability_' + n);
            String freight      = strVal('mgl_minimum_guranteed_freight_' + n);
            rows.add(new LoadabilityRow(loc, description, loadability, freight)); 
        }
        return rows;
    }
    
    private void computeDisplayFlags() {
        // GSM flags — check what's present in lines directly
        Set<String> gsmSet  = new Set<String>();
        Set<String> boltSet = new Set<String>();
    
        Object rawLines = jsonData.get('_Saved_Table_Rows');
        if (rawLines != null) {
            for (Object obj : (List<Object>) rawLines) {
                Map<String, Object> line = (Map<String, Object>) obj;
                String rawName = strObj(line.get('name')).toUpperCase();
    
                if (rawName.contains('1000')) gsmSet.add('1000');
                else if (rawName.contains('900'))  gsmSet.add('900');
                else if (rawName.contains('610'))  gsmSet.add('610');
    
                if (rawName.contains('8.8')) boltSet.add('8.8');
                if (rawName.contains('6.8')) boltSet.add('6.8');
                if (rawName.contains('5.6')) boltSet.add('5.6');
            }
        }
    
        // Build ordered display strings
        List<String> gsmOrdered  = new List<String>();
        List<String> boltOrdered = new List<String>();
        for (String g : new List<String>{'610','900','1000'}) {
            if (gsmSet.contains(g))  gsmOrdered.add(g);
        }
        for (String b : new List<String>{'5.6','6.8','8.8'}) {
            if (boltSet.contains(b)) boltOrdered.add(b);
        }
    
        activeGsmDisplay  = String.join(gsmOrdered,  ' , ');
        activeBoltDisplay = String.join(boltOrdered, ' , ');
        
            // Replace last comma with ' & ' if more than one item
        if (gsmOrdered.size() > 1) {
            Integer lastCommaIndex = activeGsmDisplay.lastIndexOf(',');
            if (lastCommaIndex != -1) {
                activeGsmDisplay = activeGsmDisplay.substring(0, lastCommaIndex) + 
                                   ' & ' + 
                                   activeGsmDisplay.substring(lastCommaIndex + 1).trim();
            }
        }
    
        if (boltOrdered.size() > 1) {
            Integer lastCommaIndex = activeBoltDisplay.lastIndexOf(',');
            if (lastCommaIndex != -1) {
                activeBoltDisplay = activeBoltDisplay.substring(0, lastCommaIndex) + 
                                    ' & ' + 
                                    activeBoltDisplay.substring(lastCommaIndex + 1).trim();
            }
        }
    }
    
    // MS Template Value API for Tower - Section
    private String getTowerMsTemplateKey(String pricingCode, String gsm) {
        if (pricingCode == 'PV') {
            if (gsm == '610')  return 'pvs_N28';
            if (gsm == '900')  return 'pvs_N44';
            if (gsm == '1000') return 'pvs_N59';
        } else if (pricingCode == 'FIRM') {
            if (gsm == '610')  return 'pvs_U28';
            if (gsm == '900')  return 'pvs_U44';
            if (gsm == '1000') return 'pvs_U59';
        }
        return null;
    }
    
    
    // MS Template Value API for Substation - Section
    private String getSubstationMsTemplateKey(String pricingCode, String structKey, String gsm) {
        if (pricingCode == 'PV') {
            if (structKey == 'GANTRY') {
                if (gsm == '610')  return 'pvs_AH35';
                if (gsm == '900')  return 'pvs_AH78';
                if (gsm == '1000') return 'pvs_AH121';
            } else if (structKey == 'EQUIPMENT') {
                if (gsm == '610')  return 'pvs_AH49';
                if (gsm == '900')  return 'pvs_AH92';
                if (gsm == '1000') return 'pvs_AH135';
            } else if (structKey == 'COMPOSITE') {
                if (gsm == '610')  return 'pvs_AH63';
                if (gsm == '900')  return 'pvs_AH106';
                if (gsm == '1000') return 'pvs_AH149'; // as per provided mapping
            }
        } else if (pricingCode == 'FIRM') {
            if (structKey == 'GANTRY') {
                if (gsm == '610')  return 'pvs_AP35';
                if (gsm == '900')  return 'pvs_AP78';
                if (gsm == '1000') return 'pvs_AP121';
            } else if (structKey == 'EQUIPMENT') {
                if (gsm == '610')  return 'pvs_AP49';
                if (gsm == '900')  return 'pvs_AP92';
                if (gsm == '1000') return 'pvs_AP135';
            } else if (structKey == 'COMPOSITE') {
                if (gsm == '610')  return 'pvs_AP63';
                if (gsm == '900')  return 'pvs_AP106';
                if (gsm == '1000') return 'pvs_AP149'; // as per provided mapping
            }
        }
        return null;
    }
    

	//utility methods
	private String extractGsm(String upper) {
        if (upper.contains('1000')) return '1000';
        if (upper.contains('900'))  return '900';
        if (upper.contains('610'))  return '610';
        return null;
    }
    
    private String extractNutsType(String upper) {
        if (upper.contains('8.8'))              return '8.8';
        if (upper.contains('6.8'))              return '6.8';
        if (upper.contains('5.6'))              return '5.6';
        if (upper.contains('FOUNDATION BOLT'))  return 'FOUNDATION BOLT';
        if (upper.contains('MS TEMPLATE')) {
            if (upper.contains('(PV)'))         return 'MS TEMPLATE (PV)';
            if (upper.contains('(FIRM)'))       return 'MS TEMPLATE (FIRM)';
            return 'MS TEMPLATE';
        }
        return null;
    }
    
    private String extractStructure(String upper) {
        if (upper.contains('GANTRY'))    return 'GANTRY';
        if (upper.contains('EQUIPMENT')) return 'EQUIPMENT';
        if (upper.contains('COMPOSITE')) return 'COMPOSITE';
        return null;
    }
    
    private String extractSubstationStructureFromNuts(String upper) {
        if (upper.contains('[GANTRY'))    return 'GANTRY';
        if (upper.contains('[EQUIPMENT')) return 'EQUIPMENT';
        if (upper.contains('[COMPOSITE')) return 'COMPOSITE';
        // Also handle without bracket
        if (upper.contains('GANTRY'))    return 'GANTRY';
        if (upper.contains('EQUIPMENT')) return 'EQUIPMENT';
        if (upper.contains('COMPOSITE')) return 'COMPOSITE';
        return null;  // will be stored as 'ALL'
    }
    
    private String strObj(Object v) {
        return (v == null) ? '' : String.valueOf(v).trim();
    }
    
    private String strVal(String key) {
        if (jsonData == null) return '';
        Object v = jsonData.get(key);
        return (v == null) ? '' : String.valueOf(v).trim();
    }
    
    private Boolean boolVal(String key) {
        if (jsonData == null) return false;
        Object v = jsonData.get(key);
        if (v == null) return false;
        String s = String.valueOf(v).trim().toLowerCase();
        return (s == 'true' || s == '1');
    }
    
    private Decimal decVal(String key) {
        if (jsonData == null) return null;
        Object v = jsonData.get(key);
        if (v == null) return null;
        String s = String.valueOf(v).trim();
        if (String.isBlank(s)) return null;
        try { return Decimal.valueOf(s); } catch (Exception e) { return null; }
    }
    
    private Decimal decObjVal(Object v) {
        if (v == null) return null;
        try { return Decimal.valueOf(String.valueOf(v).trim()); }
        catch (Exception e) { return null; }
    }

    private String fmtNum(Decimal d) {
        if (d == null) return '0';
    
        Boolean neg = (d < 0);
        Decimal absD = neg ? -d : d;
    
        // Round to 2 decimal places only to avoid floating precision noise (e.g. 68208.600000001)
        // — this does NOT collapse real decimals like .6 or .65
        absD = absD.setScale(2, RoundingMode.HALF_UP);
    
        Long wholePart = absD.longValue();
        Integer decPart = ((absD - wholePart) * 100).intValue(); // e.g. 60 for .60, 65 for .65
    
        String wholeStr = indianComma(wholePart);
        String result;
    
        if (decPart == 0) {
            // No meaningful decimal — show as whole number, same as before
            result = wholeStr;
        } else {
            String decStr = String.valueOf(decPart);
            if (decStr.length() < 2) decStr = '0' + decStr;      // e.g. 6 -> "06"
            if (decStr.endsWith('0')) decStr = decStr.substring(0, 1); // "60" -> "6"
            result = wholeStr + '.' + decStr;
        }
    
        return (neg ? '-' : '') + result;
    }
    
    private String indianComma(Long n) {
        if (n == null) return '0';
        Boolean neg = (n < 0);
        String  s   = String.valueOf(Math.abs(n));
        String  res = '';
        Integer len = s.length();
        if (len <= 3) {
            res = s;
        } else {
            res = s.substring(len - 3);
            s   = s.substring(0, len - 3);
            len = s.length();
            while (len > 2) {
                res = s.substring(len - 2) + ',' + res;
                s   = s.substring(0, len - 2);
                len = s.length();
            }
            if (len > 0) res = s + ',' + res;
        }
        return (neg ? '-' : '') + res;
    }

    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key)
                || jsonData.get(key) == null
                || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }
}