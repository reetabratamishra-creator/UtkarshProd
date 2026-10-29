public class CostingExportController {
    
    public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
    public List<Map<String, Object>> lineItems { get; set; }
    public Decimal totalAmount { get; set; }
    public String todayDate { get; set; }
    
    Public String quoteNumber { get; set; }
    public String logoBase64 { get; set; }
    public String currentUser { get; set; }
    
    public class CostRow{
        public String label    { get; set; }
        public String value    { get; set; }
        public Boolean isSpacer { get; set; }
        
        public CostRow(String label, String value) {
            this.label    = label;
            this.value    = value;
            this.isSpacer = false;
        }

        public CostRow() {
            this.isSpacer = true;
        }
    }
    
    public class TableGroup {
        public String  productType { get; set; }
        public String  pricingType { get; set; }
        public String  gsm         { get; set; }
        public String structureType { get; set; }
        
        public TableGroup(String productType, String pricingType, String gsm, String structureType){
            this.productType = productType;
            this.pricingType = pricingType;
            this.gsm = gsm;
            this.structureType = structureType;
        }
        
        public String tableTitle() {
            return productType + ' - ' + pricingType + '-' + gsm + ' GSM';
        }
        
        /** Unique dedup key */
        public String groupKey() {
            String key = productType + '|' + pricingType + '|' + gsm;
            if (String.isNotBlank(structureType)) key += '|' + structureType;
            return key;
        }
    }
    
    public class PriceTable{
        public String title { get; set; } 
        public List<CostRow> rows { get; set; }
        public String footerNote { get; set; }
        public Boolean isLast { get; set; }
        
        public PriceTable(String title) {
            this.title = title;
            this.rows = new List<CostRow>();
            this.footerNote = '';
            this.isLast = false;
        }
    }
    
    public List<PriceTable> priceTables;
    
    public List<PriceTable> getPriceTables() {
        if (priceTables == null) {
            priceTables = buildTables();
        }
        return priceTables;
    }
    
    public CostingExportController(ApexPages.StandardController stdController){
        totalAmount = 0.00;
        lineItems = new List<Map<String, Object>>();
        todayDate = Date.today().format();
        jsonData = new Map<String, Object>();
        List<Quote> quotes = [SELECT Id, Name, Quote_Value__c, QuoteNumber
                      FROM Quote 
                      WHERE Id = :stdController.getId() LIMIT 1];
        currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Name;
        
        if (!quotes.isEmpty()) {
            quoteRecord = quotes[0];
            quoteNumber = quotes[0].QuoteNumber;
            if (String.isNotBlank(quoteRecord.Quote_Value__c)){
                try{
                    jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
                    
                    lineItems = buildLineItems();
                    
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
                }
                catch(Exception ex){
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Failed to parse Quote JSON: ' + ex.getMessage()
                    ));
                }
            }
        } else {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Quote record not found for this page.'
            ));
        }
        
        initSafetyKeys();
    }
    
    private void initSafetyKeys() {
        
        // ── Tower – Price Variation ──────────────────────────────────────────
        ensureKey('pvt_pv_billets',                               '0');
        ensureKey('pvt_pv_avg_of_blooms',                         '0');
        ensureKey('pvt_pv_convergence_to_angles',                 '0');
        ensureKey('pvt_pv_zinc_value',                            '0');
        ensureKey('pvt_pv_zinc_consumption_percent',              '0');
        ensureKey('pvt_pv_scrap',                                 '0');
        ensureKey('pvt_pv_scrap_value',                           '0');
        ensureKey('pvt_pv_interest_component_on_product_cycle',   '0');
        ensureKey('pvt_pv_cost_of_production',                    '0');
        ensureKey('pvt_pv_margin',                                '0');
        ensureKey('pvt_pv_additional_pricing',                    '0');
        ensureKey('pvt_pv_proto',                                 'NO');
        ensureKey('pvt_pv_proto_required',                        '0');
 
        // ── Tower – FIRM ─────────────────────────────────────────────────────
        ensureKey('pvt_firm_market_price',                        '0');
        ensureKey('pvt_firm_zinc_value',                          '0');
        ensureKey('pvt_firm_zinc_consumption_percent',            '0');
        ensureKey('pvt_firm_scrap',                               '0');
        ensureKey('pvt_firm_scrap_value',                         '0');
        ensureKey('pvt_firm_interest_component_on_product_cycle', '0');
        ensureKey('pvt_firm_cost_of_production',                  '0');
        ensureKey('pvt_firm_margin',                              '0');
        ensureKey('pvt_firm_additional_pricing',                  '0');
        ensureKey('pvt_firm_proto',                               'NO');
        ensureKey('pvt_firm_proto_required',                      'N/A');
 
        // ── Substation – Price Variation ─────────────────────────────────────
        ensureKey('pvs_pv_billets',                               '0');
        ensureKey('pvs_pv_avg_of_blooms',                         '0');
        ensureKey('pvs_pv_conversion_to_angle',                   '0');
        ensureKey('pvs_pv_zinc_value',                            '0');
        ensureKey('pvs_pv_zinc_consumption_percent',              '0');
        ensureKey('pvs_pv_scrap',                                 '0');
        ensureKey('pvs_pv_scrap_value',                           '0');
        ensureKey('pvs_pv_interest_component_on_product_cycle',   '0');
        ensureKey('pvs_pv_cost_of_production',                    '0');
        ensureKey('pvs_pv_margin',                                '0');
        ensureKey('pvs_pv_additional_pricing',                    '0');
        ensureKey('pvs_pv_proto',                                 'NO');
        ensureKey('pvs_pv_proto_required',                        '0');
 
        // ── Substation – FIRM ────────────────────────────────────────────────
        ensureKey('pvs_firm_market_price',                        '0');
        ensureKey('pvs_firm_zinc_value',                          '0');
        ensureKey('pvs_firm_zinc_consumption_percent',            '0');
        ensureKey('pvs_firm_scrap',                               '0');
        ensureKey('pvs_firm_scrap_value',                         '0');
        ensureKey('pvs_firm_interest_component_on_product_cycle', '0');
        ensureKey('pvs_firm_cost_of_production',                  '0');
        ensureKey('pvs_firm_margin',                              '0');
        ensureKey('pvs_firm_additional_pricing',                  '0');
        ensureKey('pvs_firm_proto',                               'NO');
        ensureKey('pvs_firm_proto_required',                      'N/A');
        
        // Tower PV – per-GSM zinc
        ensureKey('pvt_pv_zinc_value_610',  '0');
        ensureKey('pvt_pv_zinc_value_900',  '0');
        ensureKey('pvt_pv_zinc_value_1000', '0');
        
        // Tower FIRM – per-GSM zinc
        ensureKey('pvt_firm_zinc_value_610',  '0');
        ensureKey('pvt_firm_zinc_value_900',  '0');
        ensureKey('pvt_firm_zinc_value_1000', '0');
        
        // Substation PV – per-GSM zinc
        ensureKey('pvs_pv_zinc_value_610',  '0');
        ensureKey('pvs_pv_zinc_value_900',  '0');
        ensureKey('pvs_pv_zinc_value_1000', '0');
        
        // Substation FIRM – per-GSM zinc
        ensureKey('pvs_firm_zinc_value_610',  '0');
        ensureKey('pvs_firm_zinc_value_900',  '0');
        ensureKey('pvs_firm_zinc_value_1000', '0');
        
        ensureKey('pvs_detail_ms_template_price_firm_gantry',    '0');
        ensureKey('pvs_detail_ms_template_price_firm_equipment', '0');
        ensureKey('pvs_detail_ms_template_price_firm_composite', '0');
        
        ensureKey('pvs_detail_ms_template_price_pv_tower',     '0');
        ensureKey('pvs_detail_ms_template_price_pv_gantry',    '0');
        ensureKey('pvs_detail_ms_template_price_pv_equipment', '0');
        ensureKey('pvs_detail_ms_template_price_pv_composite', '0');
    }
    
    private List<Map<String, Object>> buildLineItems(){
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        Object rawRows = jsonData.get('_Saved_Table_Rows');
        if (rawRows == null) return result;
        
        for (Object r : (List<Object>) rawRows) {
            Map<String, Object> row = (Map<String, Object>) r;
            result.add(row);
             
            // Accumulate running total from netPrice
            Object np = row.get('netPrice');
            if (np != null) {
                String npStr = String.valueOf(np).trim();
                if (String.isNotBlank(npStr)) {
                    try { totalAmount += Decimal.valueOf(npStr); } catch (Exception e) {}
                }
            }
        }
        
        return result;
    }
    
    private List<PriceTable> buildTables(){
        
        List<PriceTable> tables = new List<PriceTable>();
        Map<String, TableGroup> groupMap   = new Map<String, TableGroup>();
        List<String> groupOrder = new List<String>();
        
        if (jsonData == null || jsonData.isEmpty()) return tables;
        
        Object rawLines = jsonData.get('_Saved_Table_Rows');
        
         // Step 1: scan _Saved_Table_Rows to discover all unique table groups
        for(Object lineObj : (List<Object>) rawLines){
            Map<String, Object> line = (Map<String, Object>) lineObj;
            String itemName = strObj(line.get('name'));
            
            if (String.isBlank(itemName)) continue;
            
            ParsedName pn = parseName(itemName);
            if (pn == null) continue;
            
            String key = pn.groupKey();
            if (!groupMap.containsKey(key)) {
                groupMap.put(key, new TableGroup(pn.productType, pn.pricingType, pn.gsm, pn.structureType));
                groupOrder.add(key);
            }
        }
        
        // ── Step 2: build one table per group ─────────────────────────────────
        for (String key : groupOrder) {
            TableGroup tg = groupMap.get(key);
            PriceTable pt;
            
            if (tg.productType == 'TOWER') {
                pt = (tg.pricingType == 'FIRM')
                   ? buildTowerFirmTable(tg)
                   : buildTowerPvTable(tg);
            } else {  // SUBSTATION
                pt = (tg.pricingType == 'FIRM')
                   ? buildSubstationFirmTable(tg)
                   : buildSubstationPvTable(tg);
            }
 
            tables.add(pt);
        }
        
        if(!tables.isEmpty()){
            tables[tables.size() - 1].isLast = true;
        }
        
        return tables;
    }
    
    private class ParsedName {
        public String productType { get; set; }  // TOWER | SUBSTATION
        public String pricingType { get; set; }  // FIRM  | PRICE VARIATION
        public String gsm         { get; set; }  // 610   | 900 | 1000
        public String structureType { get; set; }
        
        public String groupKey() {
            return productType + '|' + pricingType + '|' + gsm;
        }
    }
    
    private ParsedName parseName(String raw){
        String u = raw.toUpperCase();
        ParsedName pn = new ParsedName();
        
        // ── Product type ──────────────────────────────────────────────────────
        if      (u.contains('SUBSTATION')) pn.productType = 'SUBSTATION';
        else if (u.contains('TOWER'))      pn.productType = 'TOWER';
        else return null;
        
        // ── Pricing type ──────────────────────────────────────────────────────
        if (u.contains('PRICE VARIATION') || u.contains('PV-')) {
            pn.pricingType = 'PRICE VARIATION';
        } else if (u.contains('FIRM')) {
            pn.pricingType = 'FIRM';
        } else {
            return null;
        }
        
        // ── GSM ────────────────────────────────────────────────────────────────
        if      (u.contains('1000')) pn.gsm = '1000';
        else if (u.contains('900'))  pn.gsm = '900';
        else if (u.contains('610'))  pn.gsm = '610';
        else return null;
        
        // Structure type (only meaningful for Substation)
        if      (u.contains('GANTRY'))    pn.structureType = 'GANTRY';
        else if (u.contains('EQUIPMENT')) pn.structureType = 'EQUIPMENT';
        else if (u.contains('COMPOSITE')) pn.structureType = 'COMPOSITE';
        else                              pn.structureType = null;
 
        return pn;
    }
    
   	/** Tower – Price Variation (pvt_pv_* keys) */
    private PriceTable buildTowerPvTable(TableGroup tg) {
        PriceTable t = new PriceTable(tg.tableTitle());
 
        Decimal billets     = decVal('pvt_pv_billets');
        Decimal avgBlooms   = decVal('pvt_pv_avg_of_blooms');
        Decimal conversion  = decVal('pvt_pv_convergence_to_angles');
        Decimal zincValue   = decVal('pvt_pv_zinc_value_' + tg.gsm);
        Decimal zincPct     = decVal('pvt_pv_zinc_consumption_percent');
        Decimal scrapPct    = decVal('pvt_pv_scrap');
        Decimal scrapValue  = decVal('pvt_pv_scrap_value');
        Decimal invCarrying = decVal('pvt_pv_interest_component_on_product_cycle');
        Decimal costOfProd  = decVal('pvt_pv_cost_of_production');
        Decimal margin      = decVal('pvt_pv_margin');
        Decimal addPricing  = decVal('pvt_pv_additional_pricing');
        String  protoFlag   = strVal('pvt_pv_proto');
        Decimal bankInterest = decVal('pvt_pv_bank_interest');
        Decimal numOfDays = decVal('pvt_pv_no_of_days');
        String bbDisplayName = strVal('pvt_price_module');
         
        if(numOfDays==null) numOfDays = 0;                        
        // Prefer avg-of-blooms; fall back to billets alone
        If(bbDisplayName != null && bbDisplayName=='PGCIL'){
            bbDisplayName = 'Blooms';
        }
        else if(bbDisplayName != null && bbDisplayName=='IEEMA'){
            bbDisplayName = 'Blooms & Billets';
        }
        
        if(String.isEmpty(bbDisplayName)){
            bbDisplayName = 'Blooms & Billets';
        }
        Decimal bbDisplay = (avgBlooms != null && avgBlooms > 0) ? avgBlooms : billets;
 
        addRow(t, bbDisplayName, fmtNum(bbDisplay));
        addRow(t, 'Conversion to Angles', fmtNum(conversion));
        addRow(t, 'Zinc' , fmtNum(zincValue));
        addRow(t, 'Scrap', fmtNum(scrapValue));
        //addRow(t, '', '');       // blank spacer
        if(bankInterest > 0.0 && numOfDays>0){
            addRow(t, 'Bank Interest ('+numOfDays+') days', fmtNum(bankInterest));
        }
        addRow(t, 'Inventory Carrying Cost & Working Capital', fmtNum(invCarrying));
        addRow(t, 'Cost of Production', fmtNum(costOfProd));
        //addRow(t, '', '0');
        addRow(t, 'Margin', fmtNum(margin));
 
        return t;
    }
 
    // ── Row order for FIRM tables: ────────────────────────────────────────────
    /** Tower – FIRM (pvt_firm_* keys) */
    private PriceTable buildTowerFirmTable(TableGroup tg) {
        PriceTable t = new PriceTable(tg.tableTitle());
 
        // In FIRM pricing the raw-material row is "ANGLES" (market price of angles purchased)
        Decimal angles      = decVal('pvt_firm_angles');
        Decimal zincValue   = decVal('pvt_firm_zinc_value_' + tg.gsm);
        Decimal zincPct     = decVal('pvt_firm_zinc_consumption_percent');
        Decimal scrapPct    = decVal('pvt_firm_scrap');
        Decimal scrapValue  = decVal('pvt_firm_scrap_value');
        Decimal costOfProd  = decVal('pvt_firm_cost_of_production');
        Decimal invCarrying = decVal('pvt_firm_interest_component_on_product_cycle');
        Decimal margin      = decVal('pvt_firm_margin');
        Decimal addPricing  = decVal('pvt_firm_additional_pricing');
        String  protoFlag   = strVal('pvt_firm_proto');
        Decimal bankInterest = decVal('pvt_firm_bank_interest');
        Decimal numOfDays = decVal('pvt_firm_no_of_days');
                                
        if(numOfDays==null) numOfDays = 0;
 
        addRow(t, 'ANGLES', fmtNum(angles));
        addRow(t, 'Zinc', fmtNum(zincValue));
        addRow(t, 'Scrap' + pctSuffix(scrapPct), fmtNum(scrapValue));
        //addRow(t, '', '');
        if(bankInterest > 0.0 && numOfDays>0){
            addRow(t, 'Bank Interest', fmtNum(bankInterest));
        }
        addRow(t, 'Cost of Production', fmtNum(costOfProd));
        addRow(t, 'Inventory Carrying Cost & Working Capital', fmtNum(invCarrying));
        addRow(t, 'Proto',  '800');
        addRow(t, 'Margin', fmtNum(margin));
 
        return t;
    }
 
    /** Substation – Price Variation (pvs_pv_* keys + structure footnote) */
    private PriceTable buildSubstationPvTable(TableGroup tg) {
        PriceTable t = new PriceTable(tg.tableTitle());
 
        Decimal billets     = decVal('pvs_pv_billets');
        Decimal avgBlooms   = decVal('pvs_pv_avg_of_blooms');
        Decimal conversion  = decVal('pvs_pv_conversion_to_angle');
        Decimal zincValue   = decVal('pvs_pv_zinc_value_' + tg.gsm);
        Decimal zincPct     = decVal('pvs_pv_zinc_consumption_percent');
        Decimal scrapPct    = decVal('pvs_pv_scrap');
        Decimal scrapValue  = decVal('pvs_pv_scrap_value');
        Decimal invCarrying = decVal('pvs_pv_interest_component_on_product_cycle');
        Decimal costOfProd  = decVal('pvs_pv_cost_of_production');
        Decimal margin      = decVal('pvs_pv_margin');
        Decimal addPricing  = decVal('pvs_pv_additional_pricing');
        String  protoFlag   = strVal('pvs_pv_proto');
        String msTemplatePrice = getMsTemplatePriceForStructure('Price Variation',tg.structureType);
        Decimal bankInterest = decVal('pvs_BJ34');
        Decimal numOfDays = decVal('pvs_pv_no_of_days');
        String bbDisplayName = strVal('pvs_price_module');
        
        if(numOfDays==null) numOfDays = 0;
        
        If(bbDisplayName != null && bbDisplayName=='PGCIL'){
            bbDisplayName = 'Blooms';
        }
        else if(bbDisplayName != null && bbDisplayName=='IEEMA'){
            bbDisplayName = 'Blooms & Billets';
        }
        
         if(String.isEmpty(bbDisplayName)){
            bbDisplayName = 'Blooms & Billets';
        }
        
        Decimal bbDisplay = (avgBlooms != null && avgBlooms > 0) ? avgBlooms : billets;
        System.debug('****line 432 ' + fmtNum(bbDisplay));
 
        addRow(t, bbDisplayName, fmtNum(bbDisplay));
        addRow(t, 'Conversion to Angles', fmtNum(conversion));
        addRow(t, 'Zinc', fmtNum(zincValue));
        addRow(t, 'Scrap' + pctSuffix(scrapPct), fmtNum(scrapValue));
        //addRow(t, '', '');
        if(bankInterest > 0.0 && numOfDays>0){
            addRow(t, 'Bank Interest ('+numOfDays+') days', fmtNum(bankInterest));
        }
        addRow(t, 'Inventory Carrying Cost & Working Capital', fmtNum(invCarrying));
        addRow(t, 'Cost of Production', fmtNum(costOfProd));
        //addRow(t, '',  '0');
        addRow(t, 'Margin', fmtNum(margin));
 
        t.footerNote = buildSubstationFooterNote();
        return t;
    }
 
    /** Substation – FIRM (pvs_firm_* keys + structure footnote) */
    private PriceTable buildSubstationFirmTable(TableGroup tg) {
        PriceTable t = new PriceTable(tg.tableTitle());
 
        Decimal angles      = decVal('pvs_firm_angles');
        Decimal zincValue   = decVal('pvs_firm_zinc_value_' + tg.gsm);
        Decimal zincPct     = decVal('pvs_firm_zinc_consumption_percent');
        Decimal scrapPct    = decVal('pvs_firm_scrap');
        Decimal scrapValue  = decVal('pvs_firm_scrap_value');
        Decimal costOfProd  = decVal('pvs_firm_cost_of_production');
        Decimal invCarrying = decVal('pvs_firm_interest_component_on_product_cycle');
        Decimal margin      = decVal('pvs_firm_margin');
        Decimal addPricing  = decVal('pvs_firm_additional_pricing');
        String  protoFlag   = strVal('pvs_firm_proto');
        String msTemplatePrice = getMsTemplatePriceForStructure('FIRM',tg.structureType);
        Decimal bankInterest = decVal('pvs_BT29');
        Decimal numOfDays = decVal('pvs_firm_no_of_days');
        if(numOfDays==null) numOfDays = 0;
 
        addRow(t, 'ANGLES', fmtNum(angles));
        addRow(t, 'Zinc', fmtNum(zincValue));
        addRow(t, 'Scrap' + pctSuffix(scrapPct), fmtNum(scrapValue));
        //addRow(t, '', '');
        if(bankInterest > 0.0 && numOfDays>0){
            addRow(t, 'Bank Interest', fmtNum(bankInterest));
        }
        addRow(t, 'Cost of Production', fmtNum(costOfProd));
        addRow(t, 'Inventory Carrying Cost & Working Capital', fmtNum(invCarrying));
        //addRow(t, '', '0');
        addRow(t, 'Margin', fmtNum(margin));
 
        t.footerNote = buildSubstationFooterNote();
        return t;
    }
 
    private String buildSubstationFooterNote() {
        return '** This above price is for Tower. For Gantry structure +4000, Equipment structure +10000 & composite structure +7000 will be added on the above Tower price **';
    }
    
    // utility methods
    private String strObj(Object v) {
        return (v == null) ? '' : String.valueOf(v).trim();
    }
    
    private Boolean boolVal(String key) {
        Object v = jsonData.get(key);
        if (v == null) return false;
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim().toLowerCase();
        return (s == 'true' || s == '1' || s == 'yes');
    }
    
    private Decimal decVal(String key) {
        Object v = jsonData.get(key);
        if (v == null) return null;
        String s = String.valueOf(v).trim();
        if (String.isBlank(s)) return null;
        try { return Decimal.valueOf(s); } catch (Exception e) { return null; }
    }
    
    private String strVal(String key) {
        Object v = jsonData.get(key);
        return (v == null) ? '' : String.valueOf(v).trim();
    }
      
    private String fmtNum(Decimal d) {
        if (d == null) return '0';
    
        Boolean neg = (d < 0);
        Decimal absD = neg ? -d : d;
    
        // Round to 2 decimal places only to avoid floating precision noise (e.g. 68208.600000001)
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
    
     private void addRow(PriceTable t, String label, String value) {
        t.rows.add(new CostRow(label, value));
     }
    
    private String pctSuffix(Decimal pct) {
        if (pct == null || pct <= 0) return '';
        return ' (' + pct.stripTrailingZeros().toPlainString() + '%)';
    }
    
    // ── Helper: inject default only when key is absent / null / blank ────────
    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key)
                || jsonData.get(key) == null
                || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }
    
    private String getMsTemplatePriceForStructure(String pricingType, String structureType) {
        String key;
    
        if (pricingType == 'FIRM') {
            if      (structureType == 'GANTRY')    key = 'pvs_detail_ms_template_price_firm_gantry';
            else if (structureType == 'EQUIPMENT') key = 'pvs_detail_ms_template_price_firm_equipment';
            else if (structureType == 'COMPOSITE') key = 'pvs_detail_ms_template_price_firm_composite';
            else                                    key = 'pvs_detail_ms_template_price_firm_gantry'; // safe fallback
        } else {
            // PRICE VARIATION
            if      (structureType == 'GANTRY')    key = 'pvs_detail_ms_template_price_pv_gantry';
            else if (structureType == 'EQUIPMENT') key = 'pvs_detail_ms_template_price_pv_equipment';
            else if (structureType == 'COMPOSITE') key = 'pvs_detail_ms_template_price_pv_composite';
            else                                    key = 'pvs_detail_ms_template_price_pv_tower'; // Tower context
        }
        
        return fmtNum(decVal(key));
    }
}