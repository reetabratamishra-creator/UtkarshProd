public class TelecomDocumentController {
    
    public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
    public Decimal totalAmount { get; set; }
    public String quoteNumber {get; set;}
    public String todayDate { get; set; }
    public String quoteAccount { get; set; }
    
    public List<TowerGroup> towerDetailGroups { get; private set; }
    public List<MGLRow> mglRows { get; private set; }
    public List<RPTRow> rptRows { get; private set; }
    public Boolean hasTowerGroups { get; private set; }
    public Boolean hasMGLRows { get; private set; }
    public Boolean hasRPTRows { get; private set; }
    public Boolean isMGLForType {get; set;}
    public Boolean isRPTForType {get; set;}
    public Boolean isBOMNotAvailable {get; set;}
    public Boolean isBOMAvailable {get; set;}
    
    public String logoBase64 { get; set; }
    public String currentUser { get; set; }
    public String currentUserPhone { get; set; }
    public String currentUserEmail { get; set; }
    public Boolean hasForIncoterms { get; set; }
    public Boolean hasExIncoterms { get; set; }
    public String incotermsVal { get; set; }
    
    // Payments terms details
    public Decimal tcOfferValidity { get; set; }
    public Decimal tcMonthDays { get; set; }
    public String tcDeliveryDetail { get; set; }
    public String tcPaymentDetails { get; set; }
    public Decimal tcPriceValidity { get; set; }
    
    // New Margin Checking
    public boolean isActualMargin { get; set; }
    public boolean isBOMMargin { get; set; }
    
    // telecom tower tables
    private List<TowerGroup> towerTablesInternal;
    public List<TowerGroup> getTowerTables() {
        return towerDetailGroups;
    }
    
    public class TowerGroup {
        public String subType { get; set; }
        public List<TowerRow> rows { get; set; }
		public boolean showTable { get; set; }   
        
        public TowerGroup() { 
            rows = new List<TowerRow>(); 
        }
    }
    
    public class MGLRow {
        public String  location  { get; set; }  
        public String  descriptionOfTower { get; set; }  
        public String vehicleLoadability { get; set; } 
        public String minimumGuaranteedFreight { get; set; }
    }
    
    public class RPTRow {
        public Integer slNo { get; set; } 
        public String  location { get; set; } 
        public String ratePerTon { get; set; }
    }
    
    public class TowerRow {
        public Integer slNo { get; set; }  
        public String  description { get; set; }   
        public String  hsnCode { get; set; }  
        public Decimal towerWeight { get; set; }  
        public Integer quantity { get; set; } 
        public String  uom { get; set; }  
        public String ratePerMT { get; set; }  
        public String unitRate { get; set; }  
        public String totalBasicRate { get; set; }   
    }
    
    private static final List<String> gsmList  = new List<String>{ '610', '900', '1000' };
        
    private static final Set<String> GSM_TOWER_TYPES =
        new Set<String>{ 'Angular', 'Tubular', 'Tubular Signalling' };
    
    public TelecomDocumentController(ApexPages.StandardController stdController){
        totalAmount = 0.00;
        todayDate = Date.today().format();
        jsonData = new Map<String, Object>();
        
        List<Quote> quotes = [SELECT Id, Name, Quote_Value__c, QuoteNumber, AccountId, Quote_Reference__c 
                      FROM Quote 
                      WHERE Id = :stdController.getId() LIMIT 1];
        User u = [SELECT Id, Name, Phone, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        currentUser = u.Name;
        currentUserPhone = u.Phone;
        currentUserEmail = u.Email;
        
        if (!quotes.isEmpty()){
            quoteRecord = quotes[0];
            quoteNumber = quotes[0].Quote_Reference__c;
            if(!String.isEmpty(quotes[0].AccountId))
            	quoteAccount = [SELECT ID, Name FROM Account WHERE Id = :quotes[0].AccountId].Name;
            if (String.isNotBlank(quoteRecord.Quote_Value__c)){
                try{
                    jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
                    buildTable();
                }
                catch(Exception ex){
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Failed to parse Quote JSON: ' + ex.getMessage()
                    ));
                }
            }
        }
        else {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Quote record not found for this page.'
            ));
        }
        
        try {
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
        } catch (Exception logoEx) {
            logoBase64 = '';
        }
        
        initSafetyKeys();
    }
    
    private void initSafetyKeys(){
        // evaluate cleanly even when buildTable() was never called.
        if (isMGLForType     == null) isMGLForType     = false;
        if (isRPTForType     == null) isRPTForType     = false;
        if (isBOMAvailable   == null) isBOMAvailable   = false;
        if (isBOMNotAvailable== null) isBOMNotAvailable= false;
        if (hasTowerGroups   == null) hasTowerGroups   = false;
        if (hasMGLRows == null) hasMGLRows = false;
        if (hasRPTRows == null) hasRPTRows = false;
     
        // ── Collection guards ────────────────────────────────────────
        // Visualforce <apex:repeat> throws when the var is null;
        if (towerDetailGroups == null) towerDetailGroups = new List<TowerGroup>();
        if (mglRows == null) mglRows = new List<MGLRow>();
        if (rptRows == null) rptRows = new List<RPTRow>();
     
        // ── Scalar guards ────────────────────────────────────────────
        if (totalAmount  == null) totalAmount  = 0.00;
        if (todayDate    == null) todayDate    = Date.today().format();
        if (quoteNumber  == null) quoteNumber  = '';
        if (quoteAccount == null) quoteAccount = '';
    }
    
    public void buildTable(){
        List<Object> lines = (List<Object>) jsonData.get('_Saved_Table_Rows');
        if (lines == null || lines.isEmpty()) return;
        
        towerDetailGroups = new List<TowerGroup>();
        mglRows = new List<MGLRow>();
        rptRows = new List<RPTRow>();
        
        // check which forType it is.
        isMGLForType = (gs(jsonData.get('tele_for_type'), '') == 'Minimum Guaranteed Loadability');
        isRPTForType = (gs(jsonData.get('tele_for_type'), '') == 'Per Metric Ton');
        isBOMNotAvailable = (gs(jsonData.get('tub_material_list'), '') == 'BOM Not Availabel');
        isBOMAvailable = (gs(jsonData.get('tub_material_list'), '') == 'BOM Availabel');
        incotermsVal = gs(jsonData.get('Incoterms'), '');
        hasForIncoterms = (gs(jsonData.get('Incoterms'), '') == 'F.O.R');
        hasExIncoterms = (gs(jsonData.get('Incoterms'), '') == 'Ex-works');
        
        // get terms & condition details
        tcOfferValidity =  gd(jsonData, 'terms_offer_validity_value');
        tcMonthDays = gd(jsonData, 'terms_offer_month_days');
        tcDeliveryDetail = gs(jsonData.get('terms_offer_delivery_details'), '');
        tcPriceValidity = gd(jsonData, 'terms_offer_price_validity');
        tcPaymentDetails = gs(jsonData.get('terms_payment_terms'), '');
        
        // get Margin detail
        isActualMargin = gb(jsonData.get('ang_margin_awt_checkbox'), false);
        isBOMMargin = gb(jsonData.get('ang_margin_checkbox'), false);
                
        if(incotermsVal==null || incotermsVal=='') incotermsVal = 'Ex-works';
        
        
        String towerType = gs(jsonData.get('type_of_tower'), '');
        
        if(GSM_TOWER_TYPES.contains(towerType)){
            towerDetailGroups = buildGsmTable(lines, towerType);
        }
        else {
            towerDetailGroups = buildGeneralTable(lines);
        }
        buildMglAndRptRows(lines);
        
        hasTowerGroups = !towerDetailGroups.isEmpty();
        hasMGLRows     = !mglRows.isEmpty();
        hasRPTRows     = !rptRows.isEmpty();
    }
    
    private List<TowerGroup> buildGsmTable(List<Object> lines, String towerType){
        List<TowerGroup> groups = new List<TowerGroup>();
        
        Map<String, Integer> productIndexByName   = buildProductIndex('tub_product_details');
    	Map<String, Integer> awtProductIndexByName = buildProductIndex('tub_awt_product_details');
        if (productIndexByName.isEmpty() && awtProductIndexByName.isEmpty()) return groups;
        
            for (String gsm : gsmList) {
                if (!isGsmEnabled(gsm)) continue;
                
                TowerGroup bomGrp = new TowerGroup();
                bomGrp.subType = towerType + ' - ' + gsm + ' GSM (Rate as per BOM)';
                bomGrp.showTable = (isBOMMArgin==true);
        
                TowerGroup awtGrp = new TowerGroup();
                awtGrp.subType = towerType + ' - ' + gsm + ' GSM (Rate as per Actual Weight)';
                awtGrp.showTable = (isActualMArgin==true);
                
                Integer bomSlNo = 1;
        		Integer awtSlNo = 1;
                
                for (Object lineObj : lines) {
                    Map<String, Object> line = (Map<String, Object>) lineObj;
                    String rawName = gs(line.get('name'), '');
                    if (String.isBlank(rawName)) continue;
                    
                    TubularLineKey key = parseGsmLine(rawName, towerType);
                    if (key == null || key.gsm != gsm) continue;
                    
                    if(key.isActualWeight){
                        Integer idx = awtProductIndexByName.get(key.productName);
                		if (idx == null) continue; // unknown AWT product — skip rather than guess
                        
                        TowerRow r       = new TowerRow();
                        r.slNo           = awtSlNo++;
                        r.hsnCode        = '73082011';
                        r.description    = key.productName;
                        r.towerWeight    = gd(jsonData, 'tub_awt_tower_weight' + idx);
                        r.quantity       = gi(line.get('quantity'));
                        r.uom            = 'SET';
                        r.ratePerMT      = fmtNum(gd(jsonData, 'tub_awt_rate_per_mt' + idx + '_' + gsm));
                        r.unitRate       = fmtNum(gd(jsonData, 'tub_awt_basic_rate'  + idx + '_' + gsm));
                        r.totalBasicRate = fmtNum(gd(jsonData, 'tub_awt_total_value' + idx + '_' + gsm));
        
                        if (gd(jsonData, 'tub_awt_basic_rate' + idx + '_' + gsm) == 0) {
                            Decimal unitPrice = gd(line, 'unitPrice');
                            r.unitRate       = fmtNum(unitPrice);
                            r.totalBasicRate = fmtNum(unitPrice * gi(line.get('quantity')));
                        }        
                        awtGrp.rows.add(r);
                    }
                    else{
						Integer idx = productIndexByName.get(key.productName);
                        if (idx == null) continue; // unknown product — skip rather than guess
                        
                        TowerRow r       = new TowerRow();
                        r.slNo           = bomSlNo++;
                        r.hsnCode        = '73082011';
                        r.description    = key.productName;
                        r.towerWeight    = gd(jsonData, 'tub_tower_weight' + idx);
                        r.quantity       = gi(line.get('quantity'));
                        r.uom            = 'SET';
                        r.ratePerMT      = fmtNum(gd(jsonData, 'tub_rate_per_mt' + idx + '_' + gsm));
                        r.unitRate       = fmtNum(gd(jsonData, 'tub_basic_rate'  + idx + '_' + gsm));
                        r.totalBasicRate = fmtNum(gd(jsonData, 'tub_total_value' + idx + '_' + gsm));
                        
                        if (gd(jsonData, 'tub_basic_rate' + idx + '_' + gsm) == 0) {
                            Decimal unitPrice = gd(line, 'unitPrice');
                            r.unitRate       = fmtNum(unitPrice);
                            r.totalBasicRate = fmtNum(unitPrice * gi(line.get('quantity')));
                        }
                        bomGrp.rows.add(r);
                    }
                }
                
                if (!bomGrp.rows.isEmpty()) groups.add(bomGrp);
                if (!awtGrp.rows.isEmpty()) groups.add(awtGrp);
        }
        
        return groups;
    }
    
    private class TubularLineKey {
        String productName;
        String gsm;
        Boolean isActualWeight;
    }
    
    private TubularLineKey parseGsmLine(String rawName, String towerType) {
        String prefix = 'TELECOM TOWER PART DETAILS - ' + towerType + ' - ';
        if (!rawName.startsWith(prefix)) return null;
        
        String remainder = rawName.trim().substring(prefix.length());
        
        // check Actual Weight type check
        Boolean isAWT = remainder.toUpperCase().contains('(AWT)');
        String awtSuffix = '(AWT)';
        if (isAWT) {
            // strip whatever whitespace/casing variant preceded it
            Integer parenIdx = remainder.toUpperCase().lastIndexOf('(AWT)');
            remainder = remainder.substring(0, parenIdx).trim();
        }
        
        Integer lastDash = remainder.lastIndexOf(' - ');
        if (lastDash < 0) return null;
        
        String productName = remainder.substring(0, lastDash).trim();
        String gsmPart      = remainder.substring(lastDash + 3).trim(); // "<gsm> GSM"
        String gsmDigits    = gsmPart.replaceAll('[^0-9]', '');
        
        if (String.isBlank(productName) || String.isBlank(gsmDigits)) return null;
        
        TubularLineKey key = new TubularLineKey();
        key.productName = productName;
        key.gsm = gsmDigits;
        key.isActualWeight = isAWT;
        return key;
    }
    
    private Map<String, Integer> buildProductIndex(String fieldPfx) {
        Map<String, Integer> tubMap = new Map<String, Integer>();
        Integer idx = 1;
        while (jsonData.containsKey(fieldPfx + idx)) {
            String name = gs(jsonData.get(fieldPfx + idx), '').trim();
            if (String.isNotBlank(name)) {
                tubMap.put(name, idx);
            }
            idx++;
        }
        return tubMap;
    }
    
    private Boolean isGsmEnabled(String gsm) {
        return gb(jsonData.get('ang_gsm_' + gsm), true);
    }
    
    private List<TowerGroup> buildGeneralTable(List<Object> lines){
        
        List<TowerGroup> towerTable  = new List<TowerGroup>();        
        Integer angIdx = 1;
        
        // Preserve sub-type insertion order across the loop
        Map<String, TowerGroup> groupMap   = new Map<String, TowerGroup>();
        List<String> groupOrder = new List<String>();
        
        for (Object lineObj : lines){
            Map<String, Object> line = (Map<String, Object>) lineObj;
            
            String rawName = gs(line.get('name'), '');
            if (String.isBlank(rawName)) continue;
            
            Integer d1 = rawName.indexOf(' - ');
            Integer d2 = (d1 >= 0) ? rawName.indexOf(' - ', d1 + 3) : -1;
            if (d1 < 0 || d2 < 0) continue;
            
            String tableType = rawName.substring(0, d1).trim();
            String subType   = rawName.substring(d1 + 3, d2).trim();
            String itemName  = rawName.substring(d2 + 3).trim();
            
            if (tableType == 'TELECOM TOWER PART DETAILS') {
 
                // Create group for this sub-type on first encounter
                if (!groupMap.containsKey(subType)) {
                    TowerGroup g = new TowerGroup();
                    g.subType = subType;
                    groupMap.put(subType, g);
                    groupOrder.add(subType);
                }
 
                TowerRow r       = new TowerRow();
                // slNo is 1-based within each sub-type group
                r.slNo           = groupMap.get(subType).rows.size() + 1;
                r.description    = itemName;
                r.hsnCode        = '73082011'; 
                r.towerWeight    = gd(jsonData, 'ang_tower_weight' + angIdx);
                r.quantity       = gi(line.get('quantity'));
                r.uom            = gs(jsonData.get('ang_uom' + angIdx), 'SET');
                r.ratePerMT      = fmtNum(gd(jsonData, 'ang_rate_per_mt'  + angIdx));
                r.unitRate       = fmtNum(gd(jsonData, 'ang_basic_rate'   + angIdx));
                r.totalBasicRate = fmtNum(gd(jsonData, 'ang_total_value'  + angIdx));
 
                if (String.isEmpty(r.unitRate)) {
                    r.unitRate       = fmtNum(gd(line, 'unitPrice'));
                    r.totalBasicRate = fmtNum(gd(jsonData, 'ang_basic_rate'+ angIdx) * gi(line.get('quantity')));
                }
 
                groupMap.get(subType).rows.add(r);
                angIdx++; 
            }
        }
        
        for (String st : groupOrder) {
            towerTable.add(groupMap.get(st));
        }
        
        return towerTable;
    }
    
   private void buildMglAndRptRows(List<Object> lines){
        Integer mglIdx = 1;
        Integer rptIdx = 1;
        
        for (Object lineObj : lines){
            Map<String, Object> line = (Map<String, Object>) lineObj;
            String rawName = gs(line.get('name'), '');
            if (String.isBlank(rawName)) continue;
            
            Integer d1 = rawName.indexOf(' - ');
            if (d1 < 0) continue;
            String tableType = rawName.substring(0, d1).trim();
            
            if (tableType == 'MINIMUM GUARANTEED LOADABILITY') {
                String loc = gs(jsonData.get('mgl_location_' + mglIdx), '');
                if (String.isNotBlank(loc)) {
                    MGLRow r                    = new MGLRow();
                    r.location                  = loc;
                    r.descriptionOfTower        = gs(jsonData.get('mgl_description_of_the_tower_' + mglIdx), '');
                    r.vehicleLoadability        = fmtNum(gd(jsonData, 'mgl_vehicle_loadability_'        + mglIdx));
                    r.minimumGuaranteedFreight  = fmtNum(gd(jsonData, 'mgl_minimum_guranteed_freight_'  + mglIdx));
                    
                    System.debug('***** line 365 '+ r + ' gate data '+ gd(jsonData, 'mgl_minimum_guranteed_freight_'  + mglIdx) + ' get decimal '+ fmtNum(gd(jsonData, 'mgl_minimum_guranteed_freight_'  + mglIdx)));
                    mglRows.add(r);
                }
                mglIdx++; 
            } 
            else if (tableType == 'PER METRIC TON RATE') {
                String loc = gs(jsonData.get('rpt_location_' + rptIdx), '');
                if (String.isNotBlank(loc)) {
                    RPTRow r     = new RPTRow();
                    r.slNo       = gi(jsonData.get('rpt_sl_no' + rptIdx)); 
                    r.location   = loc;
                    r.ratePerTon = fmtNum(gd(jsonData, 'rpt_rate_per_ton_' + rptIdx));
                    rptRows.add(r);
                }
                rptIdx++;
            }
        }
    }
    
    // utility methods
    
    private static Decimal gd(Map<String, Object> m, String key) {
        if (m == null) return 0;
        Object v = m.get(key);
        if (v == null) return 0;
        try { return Decimal.valueOf(String.valueOf(v).trim()); }
        catch (Exception e) { return 0; }
    }
    
    private static Integer gi(Object v) {
        if (v == null) return 0;
        try {
            String s = String.valueOf(v);
            // Handle Double/Decimal strings like "1.0", "5.0"
            if (s.contains('.')) s = s.substringBefore('.');
            return Integer.valueOf(s);
        } catch (Exception e) { return 0; }
    }
    
    private static String gs(Object v, String def) {
        if (v == null) return def;
        String s = String.valueOf(v);
        return (s == 'null' || s.trim().length() == 0) ? def : s;
    }
    
    private static Boolean gb(Object v, Boolean def) {
        if (v == null) return def;
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim().toLowerCase();
        if (s == 'true')  return true;
        if (s == 'false') return false;
        return def;
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
}