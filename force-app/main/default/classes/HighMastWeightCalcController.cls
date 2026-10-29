public class HighMastWeightCalcController {
    
                                             public Quote   quoteRecord     { get; set; }
    public String  soWRef          { get; set; }
    // Mast type shown in the sheet title. Held here instead of in the page's IF()
    // chain so a renamed Signage Mast prints the same name the offer PDF prints.
    // Deepanjan (18th Aug 2026)
    public String  mastTypeTitle   { get; set; }
    public String  soWDate         { get; set; }
    public String  todayDate       { get; set; }
 
    public List<RowData>              rowDataList        { get; set; }
    public List<LightingPoleData>     lpRowList          { get; set; }
    public List<LightingPoleData>     lpDisplayList      { get; set; }
    public List<TransmissionPoleData> tpRowList          { get; set; }
    public List<MidHingePoleData>     mhpRowList         { get; set; }
    public Boolean                    isLightingPole     { get; set; }
    public Boolean                    isTransmissionPole { get; set; }
    public Boolean                    isMidHingePole     { get; set; }
    public Boolean                    isCustomizedMast   { get; set; }
    public Boolean                    isStadiumMast      { get; set; }
    public Boolean                    isFlagMast         { get; set; }
    // SEGMENT ABOVE 5 - FLAG MAST: LM engine data (lm_* keys) + flag annexure grids
    // (unprefixed fm_ac_* / fm_ad_*). Routed to buildHighMastData() with the flag's
    // no-L-Ring rows; buildCustomizedMastData() (fm_* shape) is bypassed. The page
    // title and the annexure block both key off isFlagMast, which stays true.
    // Deepanjan (19th July 2026)
    public Boolean                    isSeg5FlagMast     { get; set; }
    // Lightning Cum Lighting Mast. Same lm_* JSON shape as Lighting Mast, so it keeps using
    // buildHighMastData(); only the sheet title and the added spike / down-conductor weight
    // differ. Reetabrata (15th July 2026)
    public Boolean                    isLCLM             { get; set; }
    // Signage Mast. Same lm_* JSON shape as Lighting Mast, so it keeps using
    // buildHighMastData(); only the Additional Details weight is new.
    // Reetabrata (16th July 2026)
    public Boolean                    isSignageMast      { get; set; }
    // Latching Mast. Same lm_* JSON shape as Lighting Mast, so it keeps using
    // buildHighMastData(). Its lighter weight comes from its own Blueprint record, not from
    // this class. Reetabrata (16th July 2026)
    public Boolean                    isLatchingMast     { get; set; }
    // Custom Lightning Mast. Same lm_* JSON shape as Lighting Mast, so it keeps using
    // buildHighMastData(). Its VALUE (KG) figures are already inside lm_{n}_segment_weight
    // via the blueprint formula, so NOTHING is added to any weight here - this flag only
    // exposes the Special Additions note for the sheet. Faizan (24th July 2026)
    public Boolean                    isCustomLightningMast { get; set; }
 
    // ── SEGMENT ABOVE 5 extras (unprefixed, one set per quote) - Reetabrata (9th July 2026) ──
    public Boolean hasAdditionalAcc     { get; set; }
    public String  accRate              { get; set; }
    public String  accRealization       { get; set; }
    public String  accRealizationAmount { get; set; }
    public String  accTotalRate         { get; set; }
 
    public Boolean hasSpecialItem       { get; set; }
    public String  siType               { get; set; }
    public String  siDescription        { get; set; }
    public String  siValue              { get; set; }
    public Boolean siShownSeparately    { get; set; }
    
    // Flag Mast Additional and Accessory 
    public List<FmItemRow> fmAccessoryList { get; set; }
    public List<FmItemRow> fmAdditionalList { get; set; }
    public Boolean hasFmAccessory  { get; set; }
    public Boolean hasFmAdditional { get; set; }
    public String  fmAcTotal       { get; set; }
    public String  fmAddTotal      { get; set; }
    
 
    // Grid maxRows straight from the blueprint.
    private static final Integer FM_AC_MAX_ROWS  = 8;
    private static final Integer FM_ADD_MAX_ROWS = 5;
 
 
    private static final Integer MAX_REPEATER_COLS = 10;
    private Map<String, Object> jd = new Map<String, Object>();
 
    public HighMastWeightCalcController(ApexPages.StandardController sc) {
        todayDate          = Date.today().format();
        soWDate            = Date.today().format();
        soWRef             = 'UIL/HM/26-27/001';
        rowDataList        = new List<RowData>();
        lpRowList          = new List<LightingPoleData>();
        lpDisplayList      = new List<LightingPoleData>();
        isLightingPole     = false;
        tpRowList          = new List<TransmissionPoleData>();
        isTransmissionPole = false;
        mhpRowList         = new List<MidHingePoleData>();
        isMidHingePole     = false;
        mastTypeTitle      = 'Lighting Mast';   // Deepanjan (18th Aug 2026)
        isCustomizedMast   = false;
        isStadiumMast      = false;
        isFlagMast         = false;
        isLCLM             = false;   // Reetabrata (15th July 2026)
        isSignageMast      = false;   // Reetabrata (16th July 2026)
        isLatchingMast     = false;   // Reetabrata (16th July 2026)
        isSeg5FlagMast     = false;   // Deepanjan (19th July 2026)
        isCustomLightningMast = false;   // Faizan (24th July 2026)
        fmAccessoryList  = new List<FmItemRow>();
        fmAdditionalList = new List<FmItemRow>();
        hasFmAccessory   = false;
        hasFmAdditional  = false;
        fmAcTotal        = '0';
        fmAddTotal       = '0';
        
 
        
 
        List<Quote> ql = [
            SELECT Id, Name, QuoteNumber,Quote_Reference__c,
                   Account.Name, Account.BillingStreet,
                   Account.BillingCity, Account.BillingState,
                   Account.BillingPostalCode,
                   Opportunity.Name, Quote_Value__c
            FROM   Quote
            WHERE  Id = :sc.getId()
            LIMIT  1
        ];
        if (ql.isEmpty()) return;
        quoteRecord = ql[0];
 
        soWRef = String.isNotBlank(quoteRecord.Quote_Reference__c) ? quoteRecord.Quote_Reference__c : soWRef;
 
        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jd = (Map<String,Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
            } catch (Exception ex) {
                System.debug('JSON parse error: ' + ex.getMessage());
            }
        }
 
        String mastStandard = sGet('mast_standard', '');
        if (String.isBlank(mastStandard)) {
            mastStandard = sGet('mast_standard_pole', '');
        }
        String mastStdLower = mastStandard.toLowerCase();
        
        // Check for Mid Hinge Pole - handle both "Mid Hinge" and "Mid Hinge Pole"
        isMidHingePole     = mastStdLower.contains('mid hinge') || mastStdLower.contains('mid-hinge');
        isLightingPole     = mastStdLower.contains('lighting pole') || isMidHingePole;
        isTransmissionPole = mastStdLower.contains('transmission pole');
 
        buildSegmentAbove5Extras();
 
        String cmType   = sGet('type_of_mast',    '');
        String cmCustom = sGet('mast_customized', '');
        // Segment Above 5 saves the sub-mast under seg5_mast_type instead of
        // mast_customized, and type_of_mast = 'Segment Above 5'. Treat it as the
        // same Customized/Stadium shape - identical mrl_/lwc_ fields. Reetabrata (13th July 2026)
        String cmSeg5   = sGet('seg5_mast_type', '');
        Boolean isSeg5  = cmType.equalsIgnoreCase('Segment Above 5');
        if (String.isBlank(cmCustom) && isSeg5) cmCustom = cmSeg5;
        isStadiumMast    = cmCustom.equalsIgnoreCase('STADIUM MAST');
        isFlagMast       = cmCustom.equalsIgnoreCase('FLAG MAST');
        // LCLM carries no sub-type, so mast_standard / mast_customized stay blank and every
        // branch below still routes it to buildHighMastData(). Reetabrata (15th July 2026)
        isLCLM           = cmType.equalsIgnoreCase('Lightning Cum Lighting Mast')
        // Segment Above 5 also offers LCLM, but there type_of_mast = 'Segment Above 5' and the
        // sub-mast arrives in cmCustom (copied from seg5_mast_type just above) as 'LCLM'.
        // Both shapes save the same lm_* keys, so both keep routing to the High Mast builder
        // below - only the naming and the spike / down-conductor text differ.
        // Reetabrata (15th July 2026)
                           || cmCustom.equalsIgnoreCase('LCLM');
        // Signage Mast is a top-level type_of_mast value only - it is not offered under
        // Segment Above 5, so cmCustom is never 'Signage Mast'. mast_standard and
        // mast_customized both stay blank for it, so the routing below is untouched and it
        // still falls through to buildHighMastData(). Reetabrata (16th July 2026)
        isSignageMast    = cmType.equalsIgnoreCase('Signage Mast');
        // Latching Mast is a top-level type_of_mast value only - not offered under Segment
        // Above 5, so cmCustom is never 'Latching Mast'. mast_standard / mast_customized stay
        // blank for it, so the routing below is untouched and it still falls through to
        // buildHighMastData(). Reetabrata (16th July 2026)
        isLatchingMast   = cmType.equalsIgnoreCase('Latching Mast');
        // Custom Lightning Mast is a top-level type_of_mast value only - not offered under
        // Segment Above 5, so cmCustom is never 'Custom Lightning Mast'. mast_standard /
        // mast_customized stay blank for it, so the routing below is untouched and it still
        // falls through to buildHighMastData(). Both spellings are accepted because the
        // picklist label has been written each way. Faizan (24th July 2026)
        isCustomLightningMast = cmType.equalsIgnoreCase('Custom Lightning Mast')
                                || cmType.equalsIgnoreCase('Custom Lighting Mast');
        isCustomizedMast = (isStadiumMast || isFlagMast)
                           && (cmType.equalsIgnoreCase('Customized Mast') || isSeg5);

        // Sheet title, same order the page's IF() chain used. Deepanjan (18th Aug 2026)
        mastTypeTitle = isStadiumMast  ? 'Stadium Mast'
                      : isFlagMast     ? 'Flag Mast'
                      : isLCLM         ? 'LCLM'
                      : isSignageMast  ? signageMastTitle()
                      : isLatchingMast ? 'Latching Mast'
                                       : 'Lighting Mast';
        // SEGMENT ABOVE 5 - FLAG MAST (Deepanjan, 19th July 2026): its estimator is the
        // LM engine (lm_* keys, manual segment weights) plus the flag annexure grids
        // (unprefixed fm_ac_* / fm_ad_*), NOT the single-segment fm_* shape. It must
        // therefore route to buildHighMastData() like Seg5 LCLM does - the Customized
        // builder reads fm_height_of_mast etc. and would build an empty fallback row.
        isSeg5FlagMast = isSeg5 && isFlagMast;
        if (isSeg5FlagMast) isCustomizedMast = false;
 
        if (isCustomizedMast) {
            buildCustomizedMastData();
        } else if (isLightingPole) {
            if (isMidHingePole) {
                buildMidHingePoleData();
                mapMidHingeToLightingPole();
            } else {
                buildLightingPoleData();
            }
        } else if (isTransmissionPole) {
            buildTransmissionPoleData();
        } else {
            buildHighMastData();
        }
    }
 
    // ═══════════════════════════════════════════════════════════════
    // MAP MID HINGE TO LIGHTING POLE DISPLAY
    // ═══════════════════════════════════════════════════════════════
    private void mapMidHingeToLightingPole() {
        lpRowList.clear();
        lpDisplayList.clear();
        
        // ── Map to lpRowList for costing table ──
        for (MidHingePoleData mhp : mhpRowList) {
            LightingPoleData lp = new LightingPoleData();
            lp.rowIndex = mhp.rowIndex;
            lp.itemName = mhp.itemName;
            lp.weight = mhp.weight;
            lp.quantity = mhp.quantity;
            lp.unitPrice = mhp.unitPrice;
            lp.unitCost = mhp.unitCost;
            lp.isFoundation = mhp.isFoundation;
            lp.isBracket = mhp.isBracket;
            lp.colNum = mhp.colNum;
            lpRowList.add(lp);
        }
        
        // ── Map to lpDisplayList for main spec display ──
        Map<Integer, List<MidHingePoleData>> byCol = new Map<Integer, List<MidHingePoleData>>();
        for (MidHingePoleData mhp : mhpRowList) {
            if (mhp.isAccessories) continue;
            Integer col = (mhp.colNum != null) ? mhp.colNum : 1;
            if (!byCol.containsKey(col)) byCol.put(col, new List<MidHingePoleData>());
            byCol.get(col).add(mhp);
        }
        
        List<Integer> colKeys = new List<Integer>(byCol.keySet());
        colKeys.sort();
        
        for (Integer colNum : colKeys) {
            List<MidHingePoleData> rows = byCol.get(colNum);
            
            LightingPoleData d = new LightingPoleData();
            d.colNum = colNum;
            d.sectionNum = 1;
            d.isTwoSegment = false;
            d.rowIndex = colNum;
            d.itemName = 'MID HINGE POLE (Item ' + colNum + ')';
            
            for (MidHingePoleData mhp : rows) {
                if (mhp.isFoundation) {
                    d.foundationWeight = mhp.weight;
                    d.boltDia = mhp.boltDia;
                    d.boltLength = mhp.boltLength;
                    d.boltQty = mhp.boltQty;
                    d.pcd = mhp.pcd;
                    d.template = mhp.template;
                } else if (mhp.isBracket) {
                    d.bracketType   = mhp.bracketType;
                    d.typeOfArm     = mhp.typeOfArm;
                    d.bracketWeight = (mhp.weight != null) ? mhp.weight : '0';
                    d.hasBracket    = true; 
                } else {
                    d.poleType = mhp.poleType;
                    d.height = mhp.height;
                    d.topDia = mhp.topDia;
                    d.botDia = mhp.botDia;
                    d.noOfSides = mhp.noOfSides;
                    d.segLength = mhp.segTopLen;
                    d.thickness = mhp.segTopThk;
                    d.basePlateType = mhp.basePlateType;
                    d.bpSize = mhp.bpSize;
                    d.bpThickness = mhp.bpThickness;
                    d.stiffener = mhp.stiffener;
                    d.doorHeight = mhp.doorHeight;
                    d.weight = mhp.weight;
                    d.extraMicron = mhp.extraMicron;
                    d.puPaint = mhp.puPaint;
                }
            }
            
            Decimal segWt = 0;
            Decimal fWt = 0;
            Decimal bWt = 0;
            if (d.bracketType != null && d.bracketWeight != null) {
                try { bWt = Decimal.valueOf(d.bracketWeight.replace(',', '')); } catch(Exception ex){}
            }
            
            try { if (d.weight != null) segWt = Decimal.valueOf(d.weight.replace(',', '')); } catch(Exception ex){}
            if (d.foundationWeight != null && d.foundationWeight != '0') {
                try { fWt = Decimal.valueOf(d.foundationWeight.replace(',', '')); } catch(Exception ex){}
            }
            d.totalWeightGI = fmtDec(segWt + fWt + bWt);
            
            lpDisplayList.add(d);
        }
    }
 
    // ═══════════════════════════════════════════════════════════════
    // MID HINGE POLE BUILDER
    // ═══════════════════════════════════════════════════════════════
    private void buildMidHingePoleData() {
        List<Object> apexLines = getList('_Final_Apex_Lines');
        if (!apexLines.isEmpty()) {
            Integer idx = 1;
            for (Object lineObj : apexLines) {
                Map<String,Object> line = (Map<String,Object>) lineObj;
                String itemName = sGetM(line, 'name', 'Mid Hinge Pole Item');
                
                MidHingePoleData mhp = new MidHingePoleData();
                mhp.rowIndex   = idx++;
                mhp.itemName   = itemName;
                mhp.weight     = fmtDecM(line, 'weight',   0);
                mhp.quantity   = fmtDecM(line, 'quantity', 1);
                mhp.unitPrice  = fmtDecM(line, 'unitPrice', 0);
                mhp.unitCost   = fmtDecM(line, 'unitCost',  0);
                
                Integer colIdx = parseItemIndex(itemName);
                mhp.colNum     = colIdx;
                String  cp     = 'c' + colIdx + '_mhp_';
                
                mhp.isFoundation = itemName.containsIgnoreCase('Foundation');
                mhp.isBracket    = itemName.containsIgnoreCase('Bracket') || itemName.containsIgnoreCase('Arm');
                mhp.isAccessories = itemName.containsIgnoreCase('ACCESSORIES');
                
                if (!mhp.isAccessories) {
                    fillMHPSpecFields(mhp, cp);
                } else {
                    mhp.accessoryName = sGet(cp + 'acc_accessory', '');
                    mhp.accessoryRate = fmtDec(decVal(cp + 'acc_rate', 0));
                    mhp.accessoryTotalWeight = fmtDec(decVal(cp + 'acc_total_weight', 0));
                }
                
                mhpRowList.add(mhp);
            }
            return;
        }
 
        List<Object> tableRows = getList('_Saved_Table_Rows');
        if (!tableRows.isEmpty()) {
            Integer idx = 1;
            for (Object rowObj : tableRows) {
                Map<String,Object> row = (Map<String,Object>) rowObj;
                String itemName = sGetM(row, 'name', 'Mid Hinge Pole Item');
                
                MidHingePoleData mhp = new MidHingePoleData();
                mhp.rowIndex   = idx++;
                mhp.itemName   = itemName;
                mhp.weight     = fmtDecM(row, 'weight',   0);
                mhp.quantity   = fmtDecM(row, 'quantity', 1);
                mhp.unitPrice  = fmtDecM(row, 'unitPrice', 0);
                mhp.unitCost   = fmtDecM(row, 'unitCost',  0);
                
                Integer colIdx = parseItemIndex(itemName);
                mhp.colNum     = colIdx;
                String  cp     = 'c' + colIdx + '_mhp_';
                
                mhp.isFoundation = itemName.containsIgnoreCase('Foundation');
                mhp.isBracket    = itemName.containsIgnoreCase('Bracket') || itemName.containsIgnoreCase('Arm');
                mhp.isAccessories = itemName.containsIgnoreCase('ACCESSORIES');
                
                if (!mhp.isAccessories) {
                    fillMHPSpecFields(mhp, cp);
                } else {
                    mhp.accessoryName = sGet(cp + 'acc_accessory', '');
                    mhp.accessoryRate = fmtDec(decVal(cp + 'acc_rate', 0));
                    mhp.accessoryTotalWeight = fmtDec(decVal(cp + 'acc_total_weight', 0));
                }
                
                mhpRowList.add(mhp);
            }
            return;
        }
 
        // ── Process Pole Items (1-10) ──
        Integer idx = 1;
        for (Integer col = 1; col <= MAX_REPEATER_COLS; col++) {
            String cp = 'c' + col + '_mhp_';
            String op = 'c' + col + '_op_mhp_';
 
            Decimal poleHeight   = decVal(cp + 'height_of_pole', 0);
            Decimal segUnitPrice = (decVal(op + 'segment_unit_price', 0))
                                       .setScale(2, RoundingMode.HALF_UP);
            if (poleHeight == 0 && segUnitPrice == 0) continue;
 
            MidHingePoleData mhp = new MidHingePoleData();
            mhp.rowIndex   = idx++;
            mhp.colNum     = col;
            mhp.isFoundation = false;
            mhp.isBracket    = false;
            mhp.isAccessories = false;
            mhp.itemName     = 'MID HINGE POLE (Item ' + col + ')';
            mhp.quantity     = fmtDec(decVal(cp + 'quantity', 1));
            mhp.weight       = fmtDec(decVal(cp + 'segment_weight', 0));
            mhp.unitPrice    = fmtDec(segUnitPrice);
            mhp.unitCost     = fmtDec(decVal(op + 'segment_unit_cost', 0));
            fillMHPSpecFields(mhp, cp);
            mhpRowList.add(mhp);
 
            // ── Foundation ──
            Decimal fndPrice = decVal(op + 'foundation_unit_price', 0);
            Decimal fndWt    = decVal(cp + 'foundation_weight', 0);
            if (fndPrice > 0 || fndWt > 0) {
                MidHingePoleData mhpFnd = new MidHingePoleData();
                mhpFnd.rowIndex   = idx++;
                mhpFnd.colNum     = col;
                mhpFnd.isFoundation = true;
                mhpFnd.isBracket    = false;
                mhpFnd.isAccessories = false;
                mhpFnd.itemName     = 'MID HINGE POLE - Foundation accessories (Item ' + col + ')';
                mhpFnd.quantity     = fmtDec(decVal(cp + 'quantity', 1));
                mhpFnd.weight       = fmtDec(fndWt);
                mhpFnd.unitPrice    = fmtDec(fndPrice);
                mhpFnd.unitCost     = fmtDec(decVal(op + 'foundation_unit_cost', 0));
                fillMHPSpecFields(mhpFnd, cp);
                mhpRowList.add(mhpFnd);
            }
 
            // ── Bracket ──
            Decimal brkPrice = decVal(op + 'bracket_unit_price', 0);
            Decimal brkWt    = decVal(cp + 'bracket_weight', 0);
            if (brkPrice > 0 || brkWt > 0) {
                MidHingePoleData mhpBrk = new MidHingePoleData();
                mhpBrk.rowIndex   = idx++;
                mhpBrk.colNum     = col;
                mhpBrk.isFoundation = false;
                mhpBrk.isBracket    = true;
                mhpBrk.isAccessories = false;
                mhpBrk.itemName     = 'MID HINGE POLE - Bracket (Item ' + col + ')';
                mhpBrk.quantity     = fmtDec(decVal(cp + 'quantity', 1));
                mhpBrk.weight       = fmtDec(brkWt);
                mhpBrk.unitPrice    = fmtDec(brkPrice);
                mhpBrk.unitCost     = fmtDec(decVal(op + 'bracket_unit_cost', 0));
                fillMHPSpecFields(mhpBrk, cp);
                mhpRowList.add(mhpBrk);
            }
        }
 
        // ── Process Accessories ──
        Integer accMaxCols = (Integer) decVal('mhp_accessories_no_of_items', 0).intValue();
        if (accMaxCols == 0) accMaxCols = MAX_REPEATER_COLS;
        accMaxCols = Math.min(accMaxCols, MAX_REPEATER_COLS);
 
        for (Integer col = 1; col <= accMaxCols; col++) {
            String cp = 'c' + col + '_mhp_';
            String op = 'c' + col + '_op_mhp_';
 
            String accessory = sGet(cp + 'acc_accessory', '');
            if (String.isBlank(accessory)) continue;
 
            Decimal accQty = decVal(cp + 'acc_quantity', 1);
            if (accQty == 0) accQty = 1;
            
            Decimal accUnitPrice = (decVal(op + 'acc_unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
            if (accUnitPrice == 0) {
                Decimal rate = decVal(cp + 'acc_rate', 0);
                accUnitPrice = (rate * accQty).setScale(2, RoundingMode.HALF_UP);
            }
            
            Decimal accWeight = decVal(cp + 'acc_weight', 0);
            Decimal accTotalWeight = decVal(cp + 'acc_total_weight', 0);
            Decimal weightToShow = accTotalWeight > 0 ? accTotalWeight : accWeight;
 
            MidHingePoleData mhpAcc = new MidHingePoleData();
            mhpAcc.rowIndex   = idx++;
            mhpAcc.colNum     = col;
            mhpAcc.isFoundation = false;
            mhpAcc.isBracket    = false;
            mhpAcc.isAccessories = true;
            mhpAcc.itemName     = 'MID HINGE POLE - ACCESSORIES - Accessories Details (Item ' + col + ')';
            mhpAcc.quantity     = fmtDec(accQty);
            mhpAcc.weight       = fmtDec(weightToShow);
            mhpAcc.unitPrice    = fmtDec(accUnitPrice);
            mhpAcc.unitCost     = fmtDec(decVal(op + 'acc_unit_cost', 0));
            mhpAcc.accessoryName = accessory;
            mhpAcc.accessoryRate = fmtDec(decVal(cp + 'acc_rate', 0));
            mhpAcc.accessoryTotalWeight = fmtDec(accTotalWeight);
            
            mhpRowList.add(mhpAcc);
        }
 
        if (mhpRowList.isEmpty()) {
            MidHingePoleData mhp = new MidHingePoleData();
            mhp.rowIndex = 1;
            mhp.colNum   = 1;
            mhp.isAccessories = false;
            mhp.itemName = 'Mid Hinge Pole (please verify quote configuration)';
            mhpRowList.add(mhp);
        }
    }
 
    private void fillMHPSpecFields(MidHingePoleData mhp, String cp) {
        mhp.poleType       = sGet(cp + 'pole_type',               'Polygonal');
        mhp.height         = fmtNum(cp + 'height_of_pole');
        mhp.topDia         = fmtNum(cp + 'top_diameter');
        mhp.botDia         = fmtNum(cp + 'bottom_diameter');
        mhp.segTopLen      = fmtNum(cp + 'segment_length');
        mhp.segTopThk      = fmtNum(cp + 'segment_thickness');
        mhp.overlap        = fmtNum(cp + 'overlap');
        mhp.noOfSides      = sGet(cp + 'no_of_polygonal_side',    '');
        mhp.basePlateType  = sGet(cp + 'base_plate_type',         '');
        mhp.bpSize         = fmtNum(cp + 'size_dia_of_base_plate');
        mhp.bpThickness    = fmtNum(cp + 'thickness_of_base_plate');
        mhp.stiffener      = sGet(cp + 'stiffener_at_base',       '');
        mhp.doorHeight     = fmtNum(cp + 'door_height');
        
        String fbDiaRaw = sGet(cp + 'foundation_bolt_diameter', '');
        if (fbDiaRaw.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw)) {
            fbDiaRaw = sGet(cp + 'nr_fb_diameter', '');
        }
        mhp.boltDia        = String.isBlank(fbDiaRaw) ? '0' : fbDiaRaw;
        mhp.boltLength     = fmtNum(cp + 'foundation_bolt_length');
        mhp.boltQty        = fmtNum(cp + 'bolt_quantity');
        mhp.pcd            = fmtNum(cp + 'pcd');
        mhp.template       = sGet(cp + 'template',                '');
        mhp.extraMicron    = sGet(cp + 'extra_micron',            '');
        mhp.puPaint        = sGet(cp + 'pu_paint_pole_brackets',  '');
        mhp.bracketType    = sGet(cp + 'bracket_type',            '');
        mhp.typeOfArm      = sGet(cp + 'type_of_arm',             '');
        mhp.armLength      = fmtNum(cp + 'arm_length');
        mhp.armDia         = fmtNum(cp + 'arm_dia_od');
        mhp.sleeveDia      = fmtNum(cp + 'sleeve_dia_od');
        mhp.sleeveLength   = fmtNum(cp + 'sleeve_length');
    }
 
    // ═══════════════════════════════════════════════════════════════
    // LIGHTING POLE BUILDER
    // ═══════════════════════════════════════════════════════════════
    private void buildLightingPoleData() {
        List<Object> apexLines = getList('_Final_Apex_Lines');
        if (!apexLines.isEmpty()) {
            Integer idx = 1;
            for (Object lineObj : apexLines) {
                Map<String,Object> line = (Map<String,Object>) lineObj;
                LightingPoleData lp = new LightingPoleData();
                lp.rowIndex   = idx++;
                lp.itemName   = sGetM(line, 'name',      'Lighting Pole Item');
                lp.weight     = fmtDecM(line, 'weight',   0);
                lp.quantity   = fmtDecM(line, 'quantity', 1);
                lp.unitPrice  = fmtDecM(line, 'unitPrice', 0);
                lp.unitCost   = fmtDecM(line, 'unitCost',  0);
                Integer colIdx = parseItemIndex(lp.itemName);
                Integer secIdx = parseSectionIndex(lp.itemName);
                lp.colNum      = colIdx;
                lp.sectionNum  = secIdx;
                String  cs     = 'c' + colIdx + '_s' + secIdx + '_';
                fillLPSpecFields(lp, cs);
                lp.isFoundation = lp.itemName.containsIgnoreCase('Foundation');
                lp.isBracket    = lp.itemName.containsIgnoreCase('Bracket') || lp.itemName.containsIgnoreCase('Arm');
                lpRowList.add(lp);
            }
            buildLPDisplayList();
            return;
        }
 
        List<Object> tableRows = getList('_Saved_Table_Rows');
        if (!tableRows.isEmpty()) {
            Integer idx = 1;
            for (Object rowObj : tableRows) {
                Map<String,Object> row = (Map<String,Object>) rowObj;
                LightingPoleData lp   = new LightingPoleData();
                lp.rowIndex   = idx++;
                lp.itemName   = sGetM(row, 'name',      'Lighting Pole Item');
                lp.weight     = fmtDecM(row, 'weight',   0);
                lp.quantity   = fmtDecM(row, 'quantity', 1);
                lp.unitPrice  = fmtDecM(row, 'unitPrice', 0);
                lp.unitCost   = fmtDecM(row, 'unitCost',  0);
                Integer colIdx = parseItemIndex(lp.itemName);
                Integer secIdx = parseSectionIndex(lp.itemName);
                lp.colNum      = colIdx;
                lp.sectionNum  = secIdx;
                String  cs     = 'c' + colIdx + '_s' + secIdx + '_';
                fillLPSpecFields(lp, cs);
                lp.isFoundation = lp.itemName.containsIgnoreCase('Foundation');
                lp.isBracket    = lp.itemName.containsIgnoreCase('Bracket') || lp.itemName.containsIgnoreCase('Arm');
                lpRowList.add(lp);
            }
            buildLPDisplayList();
            return;
        }
 
        List<Integer> sections = new List<Integer>{ 1, 2 };
        Integer idx = 1;
        for (Integer sec : sections) {
            Integer maxCols = (Integer) decVal('s' + sec + '_no_of_items', 0).intValue();
            if (maxCols == 0) maxCols = MAX_REPEATER_COLS;
            maxCols = Math.min(maxCols, MAX_REPEATER_COLS);
            
            for (Integer col = 1; col <= maxCols; col++) {
                String cs = 'c' + col + '_s' + sec + '_';
                Decimal height       = decVal(cs + 'height_of_pole', 0);
                
                String segPriceKey = (sec == 1) 
                    ? 'c' + col + '_lp_segment_unit_price'
                    : 'c' + col + '_lp_segment2_unit_price';
                Decimal segUnitPrice = decVal(segPriceKey, 0);
                
                if (height == 0 && segUnitPrice == 0) continue;
 
                LightingPoleData lpPole = new LightingPoleData();
                lpPole.rowIndex     = idx++;
                lpPole.colNum       = col;
                lpPole.sectionNum   = sec;
                lpPole.isFoundation = false;
                lpPole.isBracket    = false;
                lpPole.itemName     = 'LIGHTING POLE - Segment - ' + sec + ' Pole Details (Item ' + col + ')';
                
                Decimal qty = decVal('c' + col + '_lp_s' + sec + '_quantity', 
                               decVal(cs + 'quantity', 1));
                lpPole.quantity     = fmtDec(qty);
                lpPole.weight       = fmtDec(decVal('c' + col + '_lp_s' + sec + '_segment_weight', 
                                               decVal(cs + 'segment_weight', 0)));
                lpPole.unitPrice    = fmtDec(segUnitPrice);
                lpPole.unitCost     = fmtDec(decVal('c' + col + '_lp_segment_unit_cost', 0));
                fillLPSpecFields(lpPole, cs);
                lpRowList.add(lpPole);
 
                String fndPriceKey = 'c' + col + '_lp_foundation_unit_price';
                Decimal fndPrice = decVal(fndPriceKey, 0);
                Decimal fndWt    = decVal(cs + 'foundation_weight', 0);
                if (fndPrice > 0 || fndWt > 0) {
                    LightingPoleData lpFnd = new LightingPoleData();
                    lpFnd.rowIndex     = idx++;
                    lpFnd.colNum       = col;
                    lpFnd.sectionNum   = sec;
                    lpFnd.isFoundation = true;
                    lpFnd.isBracket    = false;
                    lpFnd.itemName     = 'LIGHTING POLE - Foundation accessories - ' + sec + ' (Item ' + col + ')';
                    lpFnd.quantity     = fmtDec(qty);
                    lpFnd.weight       = fmtDec(fndWt);
                    lpFnd.unitPrice    = fmtDec(fndPrice);
                    lpFnd.unitCost     = fmtDec(decVal('c' + col + '_lp_foundation_unit_cost', 0));
                    fillLPSpecFields(lpFnd, cs);
                    lpRowList.add(lpFnd);
                }
 
                String brkPriceKey = 'c' + col + '_lp_bracket_unit_price';
                Decimal brkPrice = decVal(brkPriceKey, 0);
                Decimal brkWt    = decVal(cs + 'bracket_weight', 0);
                if (brkPrice > 0 || brkWt > 0) {
                    LightingPoleData lpBrk = new LightingPoleData();
                    lpBrk.rowIndex     = idx++;
                    lpBrk.colNum       = col;
                    lpBrk.sectionNum   = sec;
                    lpBrk.isFoundation = false;
                    lpBrk.isBracket    = true;
                    lpBrk.itemName     = 'LIGHTING POLE - Bracket - ' + sec + ' (Item ' + col + ')';
                    lpBrk.quantity     = fmtDec(qty);
                    lpBrk.weight       = fmtDec(brkWt);
                    lpBrk.unitPrice    = fmtDec(brkPrice);
                    lpBrk.unitCost     = fmtDec(decVal('c' + col + '_lp_bracket_unit_cost', 0));
                    fillLPSpecFields(lpBrk, cs);
                    lpRowList.add(lpBrk);
                }
            }
        }
 
        if (lpRowList.isEmpty()) {
            LightingPoleData lp = new LightingPoleData();
            lp.rowIndex = 1;
            lp.colNum   = 1;
            lp.sectionNum = 1;
            lp.itemName = 'Lighting Pole (please verify quote configuration)';
            lpRowList.add(lp);
        }
        buildLPDisplayList();
    }
 
    private void fillLPSpecFields(LightingPoleData lp, String cs) {
        lp.poleType       = sGet(lpAttr(cs, 'pole_type'),               'Polygonal');
        lp.height         = fmtNum(lpAttr(cs, 'height_of_pole'));
        lp.topDia         = fmtNum(lpAttr(cs, 'top_diameter'));
        lp.botDia         = fmtNum(lpAttr(cs, 'bottom_diameter'));
        lp.segLength      = fmtNum(lpAttr(cs, 'segment_length'));
        lp.thickness      = fmtNum(lpAttr(cs, 'segment_thickness'));
        lp.noOfSides      = sGet(lpAttr(cs, 'no_of_polygonal_side'),    '');
        lp.basePlateType  = sGet(lpAttr(cs, 'base_plate_type'),         '');
        lp.bpSize         = fmtNum(lpAttr(cs, 'size_dia_of_base_plate'));
        lp.bpThickness    = fmtNum(lpAttr(cs, 'thickness_of_base_plate'));
        lp.stiffener      = sGet(lpAttr(cs, 'stiffener_at_base'),       '');
        lp.doorHeight     = fmtNum(lpAttr(cs, 'door_height'));
        lp.boltDia        = sGet(lpAttr(cs, 'foundation_bolt_diameter'),'24');
        lp.boltLength     = fmtNum(lpAttr(cs, 'foundation_bolt_length'));
        lp.boltQty        = fmtNum(lpAttr(cs, 'bolt_quantity'));
        lp.pcd            = fmtNum(lpAttr(cs, 'pcd'));
        lp.template       = sGet(lpAttr(cs, 'template'),                '');
        lp.extraMicron    = sGet(lpAttr(cs, 'extra_micron'),            '');
        lp.puPaint        = sGet(lpAttr(cs, 'pu_paint_pole'),           '');
        lp.solarStructure = sGet(lpAttr(cs, 'solar_structure'),         '');
        lp.batteryBox     = sGet(lpAttr(cs, 'battery_box'),             '');
        lp.bracketType    = sGet(lpAttr(cs, 'bracket_type'),            '');
        lp.typeOfArm      = sGet(lpAttr(cs, 'type_of_arm'),             '');
        lp.armLength      = fmtNum(lpAttr(cs, 'arm_length'));
        lp.armDia         = fmtNum(lpAttr(cs, 'arm_dia_od'));
        lp.sleeveDia      = fmtNum(lpAttr(cs, 'sleeve_dia_od'));
        lp.sleeveLength   = fmtNum(lpAttr(cs, 'sleeve_length'));
    }
 
    private void buildLPDisplayList() {
        lpDisplayList.clear();
        Map<Integer, List<LightingPoleData>> byCol = new Map<Integer, List<LightingPoleData>>();
        for (LightingPoleData lp : lpRowList) {
            Integer col = (lp.colNum != null) ? lp.colNum : 1;
            if (!byCol.containsKey(col)) byCol.put(col, new List<LightingPoleData>());
            byCol.get(col).add(lp);
        }
 
        List<Integer> colKeys = new List<Integer>(byCol.keySet());
        colKeys.sort();
 
        for (Integer colNum : colKeys) {
            List<LightingPoleData> rows = byCol.get(colNum);
 
            LightingPoleData sec1Row = null;
            LightingPoleData sec2Row = null;
            LightingPoleData fndRow  = null;
            LightingPoleData brkRow  = null;
 
            for (LightingPoleData row : rows) {
                if (row.isFoundation == true) {
                    if (fndRow == null) fndRow = row;
                } else if (row.isBracket == true) {
                    if (brkRow == null) brkRow = row;
                } else {
                    Integer sn = (row.sectionNum != null) ? row.sectionNum : 1;
                    if (sn == 2 && sec2Row == null)      sec2Row = row;
                    else if (sn != 2 && sec1Row == null) sec1Row = row;
                }
            }
            if (sec1Row == null) sec1Row = sec2Row;
            if (sec1Row == null) continue;
 
            LightingPoleData d = new LightingPoleData();
            d.colNum      = colNum;
            d.sectionNum  = (sec1Row.sectionNum != null) ? sec1Row.sectionNum : 1;
            d.isTwoSegment = (sec2Row != null);
            d.itemName     = sec1Row.itemName;
            d.rowIndex     = sec1Row.rowIndex;
            d.poleType     = sec1Row.poleType;
            d.height       = sec1Row.height;
            d.topDia       = sec1Row.topDia;
            d.botDia       = sec1Row.botDia;
            d.noOfSides    = sec1Row.noOfSides;
            d.basePlateType= sec1Row.basePlateType;
            d.bpSize       = sec1Row.bpSize;
            d.bpThickness  = sec1Row.bpThickness;
            d.stiffener    = sec1Row.stiffener;
            d.doorHeight   = sec1Row.doorHeight;
            d.boltDia      = sec1Row.boltDia;
            d.boltLength   = sec1Row.boltLength;
            d.boltQty      = sec1Row.boltQty;
            d.pcd          = sec1Row.pcd;
            d.template     = sec1Row.template;
            d.extraMicron  = sec1Row.extraMicron;
            d.puPaint      = sec1Row.puPaint;
            d.weight       = sec1Row.weight;
 
            if (!d.isTwoSegment) {
                d.segLength = sec1Row.segLength;
                d.thickness = sec1Row.thickness;
            } else {
                d.segLengthBot = sec1Row.segLength;
                d.thicknessBot = sec1Row.thickness;
                d.segLengthTop = sec2Row.segLength;
                d.thicknessTop = sec2Row.thickness;
                d.overlapLen   = sGet('c' + colNum + '_s1_overlap_length', sGet('c' + colNum + '_lp_overlap', ''));
            }
 
            d.foundationWeight = (fndRow != null && fndRow.weight != null) ? fndRow.weight : '0';
            // Bracket details. The four spec fields come from the same cs prefix on every
            // row, so sec1Row is a valid source when no bracket line item was created
            // (rate and weight both zero but the bracket is still configured).
            LightingPoleData brkSrc = (brkRow != null) ? brkRow : sec1Row;
            d.bracketType   = brkSrc.bracketType;
            d.typeOfArm     = brkSrc.typeOfArm;
            d.armLength     = brkSrc.armLength;
            d.armDia        = brkSrc.armDia;
            d.sleeveDia     = brkSrc.sleeveDia;
            d.sleeveLength  = brkSrc.sleeveLength;
            d.bracketWeight = (brkRow != null && brkRow.weight != null) ? brkRow.weight : '0';
            d.hasBracket    = (brkRow != null)
                              || String.isNotBlank(brkSrc.bracketType)
                              || String.isNotBlank(brkSrc.typeOfArm)
                              || String.isNotBlank(brkSrc.sleeveDia)
                              || String.isNotBlank(brkSrc.sleeveLength);
 
            Decimal segWt = 0;
            Decimal fWt   = 0;
            Decimal bWt = 0;
            try { segWt = Decimal.valueOf(sec1Row.weight.replace(',', '')); } catch(Exception ex){}
            if (fndRow != null && fndRow.weight != null) {
                try { fWt = Decimal.valueOf(fndRow.weight.replace(',', '')); } catch(Exception ex){}
            }
            
            if (brkRow != null && brkRow.weight != null) {
                try { bWt = Decimal.valueOf(brkRow.weight.replace(',', '')); } catch(Exception ex){}
            }
            d.totalWeightGI = fmtDec(segWt + fWt + bWt);
            
 
            lpDisplayList.add(d);
        }
    }
 
    // ═══════════════════════════════════════════════════════════════
    // TRANSMISSION POLE BUILDER
    // ═══════════════════════════════════════════════════════════════
    private void buildTransmissionPoleData() {
        List<Object> apexLines = getList('_Final_Apex_Lines');
        if (!apexLines.isEmpty()) {
            Integer idx = 1;
            for (Object lineObj : apexLines) {
                Map<String,Object> line = (Map<String,Object>) lineObj;
                TransmissionPoleData tp = new TransmissionPoleData();
                tp.rowIndex  = idx++;
                tp.itemName  = sGetM(line, 'name',      'Transmission Pole Item');
                tp.weight    = fmtDecM(line, 'weight',   0);
                tp.quantity  = fmtDecM(line, 'quantity', 1);
                tp.unitPrice = fmtDecM(line, 'unitPrice', 0);
                tp.unitCost  = fmtDecM(line, 'unitCost',  0);
                Integer colIdx = parseItemIndex(tp.itemName);
                String  cp     = 'c' + colIdx + '_tp_';
                fillTPSpecFields(tp, cp);
                tpRowList.add(tp);
            }
            return;
        }
 
        List<Object> tableRows = getList('_Saved_Table_Rows');
        if (!tableRows.isEmpty()) {
            Integer idx = 1;
            for (Object rowObj : tableRows) {
                Map<String,Object> row = (Map<String,Object>) rowObj;
                TransmissionPoleData tp = new TransmissionPoleData();
                tp.rowIndex  = idx++;
                tp.itemName  = sGetM(row, 'name',      'Transmission Pole Item');
                tp.weight    = fmtDecM(row, 'weight',   0);
                tp.quantity  = fmtDecM(row, 'quantity', 1);
                tp.unitPrice = fmtDecM(row, 'unitPrice', 0);
                tp.unitCost  = fmtDecM(row, 'unitCost',  0);
                Integer colIdx = parseItemIndex(tp.itemName);
                String  cp     = 'c' + colIdx + '_tp_';
                fillTPSpecFields(tp, cp);
                tpRowList.add(tp);
            }
            return;
        }
 
        Integer idx = 1;
        for (Integer col = 1; col <= MAX_REPEATER_COLS; col++) {
            String  cp        = 'c' + col + '_tp_';
            Decimal height    = decVal(cp + 'height_of_pole', 0);
            Decimal unitPrice = decVal(cp + 'unit_price', 0);
            if (height == 0 && unitPrice == 0) continue;
 
            TransmissionPoleData tp = new TransmissionPoleData();
            tp.rowIndex  = idx++;
            tp.itemName  = 'TRANSMISSION POLE (Item ' + col + ')';
            tp.quantity  = fmtDec(decVal(cp + 'qty', 1));
            tp.weight    = fmtDec(decVal(cp + 'segment_weight', 0));
            tp.unitPrice = fmtDec(unitPrice);
            tp.unitCost  = fmtDec(decVal(cp + 'unit_cost', 0));
            fillTPSpecFields(tp, cp);
            tpRowList.add(tp);
        }
 
        if (tpRowList.isEmpty()) {
            TransmissionPoleData tp = new TransmissionPoleData();
            tp.rowIndex = 1;
            tp.itemName = 'Transmission Pole (please verify quote configuration)';
            tpRowList.add(tp);
        }
    }
 
    private void fillTPSpecFields(TransmissionPoleData tp, String cp) {
        tp.poleType         = sGet(cp + 'pole_type',                    'Polygonal');
        tp.height           = fmtNum(cp + 'height_of_pole');
        tp.topDia           = fmtNum(cp + 'top_diameter');
        tp.botDia           = fmtNum(cp + 'bottom_diameter');
        tp.noOfSides        = sGet(cp + 'no_of_polygonal_side',         '');
        tp.segLength        = fmtNum(cp + 'segment_length');
        tp.thickness        = fmtNum(cp + 'segment_thickness');
        tp.bearingPlateType = sGet(cp + 'bearing_plate_type',           '');
        tp.bpSize           = fmtNum(cp + 'size_dia_of_bearing_plate');
        tp.bpThickness      = fmtNum(cp + 'thickness_of_bearing_plate');
        tp.poleCabDia       = fmtNum(cp + 'pole_cab_dia');
        tp.poleCabThickness = fmtNum(cp + 'pole_cab_thickness');
        tp.dan              = fmtNum(cp + 'dan');
        tp.note             = sGet(cp + 'note',                         '');
        tp.extraMicron      = sGet(cp + 'extra_micron',                 '');
        tp.realization      = fmtNum(cp + 'realization');
    }
 
    private Integer parseItemIndex(String name) {
        if (String.isBlank(name)) return 1;
        Pattern p = Pattern.compile('\\(Item\\s*(\\d+)\\)');
        Matcher m = p.matcher(name);
        if (m.find()) { try { return Integer.valueOf(m.group(1)); } catch(Exception ex){} }
        return 1;
    }
 
    private Integer parseSectionIndex(String name) {
        if (String.isBlank(name)) return 1;
        Pattern p = Pattern.compile('(?i)-\\s*(\\d+)\\s+(?:Pole|Foundation|accessories)');
        Matcher m = p.matcher(name);
        if (m.find()) { try { return Integer.valueOf(m.group(1)); } catch(Exception ex){} }
        return 1;
    }
 
    // ═══════════════════════════════════════════════════════════════
    // HIGH MAST BUILDER
    // ═══════════════════════════════════════════════════════════════
    private void buildHighMastData() {
        for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
            String rPfx  = 'r' + rowIdx + '_';
            String htRaw = sGet(rPfx + 'lm_height_of_mast', '');
            if (String.isBlank(htRaw)) continue;
            RowData rd = buildRowData(rowIdx, rPfx);
            if (rd != null) rowDataList.add(rd);
        }
        applyAdditionalDetailWeight();   // Reetabrata (16th July 2026)

        // SEGMENT ABOVE 5 - FLAG MAST: the accessory / additional costing tables are
        // one set per quote with the SAME unprefixed fm_ac_* / fm_ad_* keys the
        // single-segment Flag Mast saves, so the existing builder is reused verbatim.
        // The page block is gated by isFlagMast (still true) + hasFmAccessory /
        // hasFmAdditional, so no other mast type gains a table.
        // Deepanjan (19th July 2026)
        if (isSeg5FlagMast) {
            buildFlagMastExtras();
        }
    }
 
    // ADDITIONAL DETAILS (Signage Mast): the user-entered weight is part of the mast, so it
    // belongs in TOTAL WEIGHT (GI).
    //
    // The lm_ad_* keys are UNPREFIXED - the estimator saves one set per quote, not one per
    // mast row - so this runs once, after the loop, and lands on the first built row only.
    // Adding it inside buildRowData() would repeat the same kilograms on every row of a
    // multi-mast quote.
    //
    // It counts only on the Weight basis; on the Price basis the user typed a rupee value
    // and lm_ad_weight stays empty. Guarded by isSignageMast, so no other mast type reaches
    // this and no existing weight sheet moves. Reetabrata (16th July 2026)
    private void applyAdditionalDetailWeight() {
        if ((!isSignageMast && !isLatchingMast) || rowDataList.isEmpty()) return;   // Latching added: Reetabrata (16th July 2026)
        if (!sGet('lm_ad_basis', '').equalsIgnoreCase('Weight')) return;
 
        Decimal adWt = decVal('lm_ad_weight', 0);
        if (adWt <= 0) return;
 
        RowData rd = rowDataList[0];
        rd.additionalWeight = fmtDec(adWt);
 
        Decimal baseWt = 0;
        try {
            baseWt = Decimal.valueOf(String.isBlank(rd.totalWeightGI)
                                     ? '0' : rd.totalWeightGI.replace(',', ''));
        } catch (Exception ex) { baseWt = 0; }
        rd.totalWeightGI = fmtDec(baseWt + adWt);
    }
 
    private RowData buildRowData(Integer rowIdx, String rPfx) {
        RowData rd = new RowData();
        rd.rowIndex       = rowIdx;
        rd.segmentHeaders = new List<String>();
        rd.segmentData    = new List<SegmentCol>();
        rd.segmentPricing = new List<LabelValue>();
        rd.accessories    = new List<AccessoryLineItem>();
        rd.rowPrefix = rPfx;
 
        rd.mastHeight  = fmtNum(rPfx + 'lm_height_of_mast');
        rd.noOfSegment = sGet(rPfx + 'lm_no_of_segment', '2');
        // Display defaults stripped: null stays null on the weight PDF - Deepanjan (20th Aug 2026)
        rd.noOfSides   = sGet(rPfx + 'lm_no_of_sides',   '');
 
        Integer segCount = 2;
        try { segCount = Integer.valueOf(String.isBlank(rd.noOfSegment) ? '2' : rd.noOfSegment); }
        catch (Exception ex) { segCount = 2; }
 
        Map<Integer,String> titleMap = new Map<Integer,String>{1=>'One',2=>'Two',3=>'Three',4=>'Four',5=>'Five'};
        rd.segmentTitleWord = titleMap.containsKey(segCount) ? titleMap.get(segCount) : String.valueOf(segCount);
 
        buildSegmentData(rd, rPfx, segCount);
 
        rd.basePlateType    = sGet(rPfx + 'lm_base_plate_type', '');
        rd.bpOD             = fmtNum(rPfx + 'lm_od_of_base_plate');
        rd.bpThickness      = fmtNum(rPfx + 'lm_thickness_of_base_plate');
        rd.pcd              = fmtNum(rPfx + 'lm_pcd');
        rd.anchorPlateThick = fmtNum(rPfx + 'lm_anchor_plate_thickness');
        rd.fdnBoltDia       = sGet(rPfx + 'lm_fdn_bolt_dia', '');
        rd.fdnBoltLength    = fmtNum(rPfx + 'lm_fdn_bolt_length');
        rd.fdnNoOfBolt      = fmtNum(rPfx + 'lm_fdn_no_of_bolt');
        rd.noOfNut          = fmtNum(rPfx + 'lm_fdn_no_of_nut');
        rd.stiffnerThickness= fmtNum(rPfx + 'lm_fdn_stiffner_thickness');
        rd.lRingType        = sGet(rPfx + 'lm_type_of_l_ring', '');
        rd.ringDia          = sGet(rPfx + 'lm_ring_diameter',  '');
        // SEGMENT ABOVE 5 - FLAG MAST: no L-Ring section in its recipe - blank both
        // cells, exactly as the single-segment Flag Mast row builder does, instead of
        // letting the defaults above print a fictional Fixed Ring / 800.
        // Deepanjan (19th July 2026)
        if (isSeg5FlagMast) { rd.lRingType = ''; rd.ringDia = ''; }
 
        //String wtVal = fmtNum(rPfx + 'lm_' + segCount + '_segment_weight');
        //if (String.isBlank(wtVal) || wtVal == '0') wtVal = fmtNum(rPfx + 'lm_fdn_acc_weight');
        //rd.totalWeightGI = wtVal;

        //Updated by Faizan in Document The total weight must be equal to segemnt+foundation weight
		
        String wtVal = fmtNum(rPfx + 'lm_' + segCount + '_segment_weight');
        Decimal segmentWeight = decVal(rPfx + 'lm_' + segCount + '_segment_weight', 0);
        Decimal foundationWeight = decVal(rPfx + 'lm_fdn_acc_weight', 0);
        
        Decimal totalWeight = segmentWeight + foundationWeight;
        
        rd.totalWeightGI = fmtDec(totalWeight);
 
        // LCLM: the Lightning Spike and the Down Conductor are part of the mast, so their
        // weights belong in TOTAL WEIGHT (GI). Both keys are unprefixed (single section, not
        // per row) and are absent for every other mast type, where isLCLM is false and this
        // block never runs. Reetabrata (15th July 2026)
        if (isLCLM) {
            // Row keys first (27-Jul per-row sections), bare keys as legacy fallback.
            Decimal spkLen = 0; Decimal spkWt = 0; Decimal dcnWt = 0;
            for (String sp : new List<String>{'r1_','r2_','r3_','r4_','r5_','r6_','r7_','r8_','r9_','r10_',''}) {
                if (spkLen == 0) spkLen = decVal(sp + 'lm_spike_length', 0);
                if (spkWt  == 0) spkWt  = decVal(sp + 'lm_spike_weight', 0);
                if (dcnWt  == 0) dcnWt  = decVal(sp + 'lm_dc_weight',    0);
            }
            if (spkLen > 0) rd.spikeLength = fmtDec(spkLen);
            if (spkWt  > 0) rd.spikeWeight = fmtDec(spkWt);
            if (dcnWt  > 0) rd.dcWeight    = fmtDec(dcnWt);
 
            Decimal extraWt = spkWt + dcnWt;
            if (extraWt > 0) {
                Decimal baseWt = 0;
                try { baseWt = Decimal.valueOf(String.isBlank(wtVal) ? '0' : wtVal.replace(',', '')); }
                catch (Exception ex) { baseWt = 0; }
                rd.totalWeightGI = fmtDec(baseWt + extraWt);
            }
        }
 
        // CUSTOM LIGHTNING MAST: expose the Special Additions note for this mast row.
        //
        // TEXT ONLY. rd.totalWeightGI is deliberately NOT touched: the VALUE (KG) figures are
        // already folded into lm_{n}_segment_weight by the blueprint segment-weight formula
        // (and multiplied by realization there), so adding them again here would double-count
        // the kilograms and put the weight sheet out of step with the offer.
        //
        // Built by the SAME shared helper the two scope PDFs call, with the same row prefix,
        // so the three documents can never print different Special Additions text.
        // Faizan (24th July 2026)
        if (isCustomLightningMast) {
            rd.specialAdditionsNote =
                HighMastSOWController.buildSpecialAdditionsClause(jd, rPfx).trim();
        }
 
        Integer kitLineNum = findKitLineForRow(rowIdx, rd.mastHeight);
        String  kitPfx     = 'kit_line_' + kitLineNum + '_';
        // SEGMENT ABOVE 5: there is no KIT line - the accessory config is entered in the
        // Weight Estimator's "Additional Accessories" section (unprefixed keys) - Reetabrata (9th July 2026)
        if (segCount >= 6) { kitPfx = ''; }
        // Segment Above 5 (>=6) has no KIT code -> no costing block. Standard rows keep it.
        // This is the SINGLE source of truth for 'is there a KIT line'. Reetabrata (13th July 2026)
        // Signage Mast has no KIT accordion at all (its Section_Logic record binds none), so
        // its rows hide the Costing Utkarsh block and the Cost/Set summary the same way
        // Segment Above 5 does - regardless of segment count. isSignageMast is false for
        // every other mast type, so nothing else moves. Reetabrata (16th July 2026)
        rd.showCosting = (segCount < 6) && !isSignageMast;
        String  accPfx;
 
        Integer kitSeg = (Integer) decVal(kitPfx + 'no_of_segment_select', segCount).intValue();
        if (kitSeg == 0) kitSeg = segCount;
        if      (kitSeg <= 1) accPfx = kitPfx + 'lm_';
        else if (kitSeg == 2) accPfx = kitPfx + 'lm_2_';
        else                  accPfx = kitPfx + 'lm_3_';
 
        rd.cfgQtyOfHM       = fmtNum(kitPfx + 'lm_qty_of_hm');
        rd.cfgMastHeight    = fmtNum(kitPfx + 'lm_mast_height');
        rd.cfgTypeOfLum     = sGet(kitPfx + 'lm_type_of_luminaries', '');
        rd.cfgNoOfLum       = sGet(kitPfx + 'lm_no_of_luminaries',   '');
        rd.cfgCgBox         = sGet(kitPfx + 'lm_cg_box_per_lum',     '');
        rd.cfgWeldedArm     = fmtNum(kitPfx + 'lm_type_of_welded_arm');
        rd.cfgSuspnSysm     = (sGet(kitPfx + 'lm_suspension_system', ''));
        rd.cfgCableType     = (sGet(kitPfx + 'lm_cable_type',  ''));
        rd.cfgNoOfCable     = beforeEq(sGet(kitPfx + 'lm_no_of_cable', ''));
        rd.cfgTierLRing     = beforeEq(sGet(kitPfx + 'lm_l_ring_tier', ''));
        rd.cfgRingVW        = (sGet(kitPfx + 'lm_type_of_ring_vw', ''));
        rd.cfgTypeOfWinch   = (sGet(kitPfx + 'lm_type_of_winch',      ''));
        rd.cfgTypePowerTool = (sGet(kitPfx + 'lm_type_of_power_tool', ''));
        rd.cfgTypeWireRope  = beforeEq(sGet(kitPfx + 'lm_type_of_wire_rope',  ''));
        rd.cfgTypeOfAol     = sGet(kitPfx + 'lm_type_of_aol',           'X');
        rd.cfgNoOfAvnLight  = sGet(kitPfx + 'lm_no_of_aviation_light',  'X');
        rd.cfgFeederPillar  = sGet(kitPfx + 'lm_feeder_piller_control', 'X');
 
        if      (kitSeg == 1) { rd.codeNoTitle = 'Code No-01 (For 10M to 14M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 1 (10 to 14m)'; }
        else if (kitSeg == 2) { rd.codeNoTitle = 'Code No-02 (For 15M to 18M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 2 (15m to 18m)'; }
        else if (kitSeg >= 3) { rd.codeNoTitle = 'Code No-03 (For 21M to 30M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 3 (21m to 30m)'; }
 
        buildAccessories(rd, accPfx, kitPfx, kitSeg);
 
        rd.costPerSet = fmtDec(decVal(accPfx + 'kit_base_price', 0));
        Decimal grandTotal = 0;
        for (AccessoryLineItem ali : rd.accessories) grandTotal += ali.totalCostRaw;
        Decimal cost = Decimal.valueOf(rd.costPerSet);
        // get quantity of mast selected
        Decimal kitQty = decVal(kitPfx + 'lm_qty_of_hm', 0);
        rd.totalCostPrice =fmtDec((cost * kitQty)) ;
        return rd;
    }
 
    private Integer findKitLineForRow(Integer rowIdx, String mastHtStr) {
        Decimal rowHt = 0;
        try { rowHt = Decimal.valueOf(mastHtStr); } catch (Exception ex) {}
        for (Integer k = 1; k <= 10; k++) {
            String kitMastHt = sGet('kit_line_' + k + '_lm_mast_height', '');
            if (String.isBlank(kitMastHt)) continue;
            Decimal kitHt = 0;
            try { kitHt = Decimal.valueOf(kitMastHt); } catch (Exception ex) {}
            if (kitHt == rowHt || kitHt == rowHt * 10) return k;
        }
        return rowIdx;
    }
 
    // Flag Mast reuses this builder with mp='fm_'; High Mast keeps mp='lm_'.
    // Reetabrata (15th July 2026)
    private void buildSegmentData(RowData rd, String p, Integer segCount) {
        buildSegmentData(rd, p, segCount, 'lm_');
    }
 
    private void buildSegmentData(RowData rd, String p, Integer segCount, String mp) {
        if (segCount == 1) {
            rd.segmentHeaders.add('Segment 1');
            rd.segmentData.add(segCol(fmtNum(p+mp+'1_length'),fmtNum(p+mp+'1_thickness'),fmtNum(p+mp+'1_oaf_top'),fmtNum(p+mp+'1_oaf_bottom'),'',fmtNum(p+mp+'1_longitudinal_welding'),1));
            rd.segmentPricing.add(lv('Segment Weight (kg)',fmtNum(p+mp+'1_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',fmtNum(p+mp+'1_base_price')));
            rd.segmentPricing.add(lv('Unit Price',fmtDec(decVal(p+mp+'1_unit_price',0))));
            rd.segmentPricing.add(lv('Unit Cost', fmtDec(decVal(p+mp+'1_unit_cost', 0))));
        } else if (segCount == 2) {
            rd.segmentHeaders.add('Segment 1 (Top)');
            rd.segmentHeaders.add('Segment 2 (Bottom)');
            // The 2-segment blueprint names the top segment *_2_top_* for every mast type
            // that uses it (Lighting Mast, LCLM, Signage Mast, Flag Mast). This Apex used to
            // read *_1_*, which exists only in the 1-segment template, so the top column
            // printed blank for 2-segment lm_* quotes; the 15th July change fixed it for
            // Flag Mast only.
            //
            // Now every type reads *_2_top_* FIRST and falls back to the legacy *_1_* key
            // when *_2_top_* is blank. So:
            //   - current 2-segment quotes (which save *_2_top_*)  -> values now print;
            //   - any old quote that somehow saved *_1_* keys      -> prints exactly what it
            //     printed before, because the fallback returns the same value;
            //   - quotes with neither                              -> blank, same as before.
            // No saved number is reinterpreted - only the lookup order gains a second try.
            // Reetabrata (16th July 2026)
            rd.segmentData.add(segCol(
                fmtNumFb(p+mp+'2_top_length',    p+mp+'1_length'),
                fmtNumFb(p+mp+'2_top_thickness', p+mp+'1_thickness'),
                fmtNumFb(p+mp+'2_top_oaf_top',   p+mp+'1_oaf_top'),
                fmtNumFb(p+mp+'2_top_oaf_bot',   p+mp+'1_oaf_bottom'),
                fmtNum(p+mp+'ovr_t_b'),
                fmtNum(p+mp+'2_longitudinal_welding'),1));
            Boolean ovrBot2 = getBoolVal(p+mp+'override_bot2');
            rd.segmentData.add(segCol(ovrBot2?fmtNum(p+mp+'ovr_bot2_length'):fmtNum(p+mp+'bot2_length'),ovrBot2?fmtNum(p+mp+'ovr_bot2_thickness'):fmtNum(p+mp+'bot2_thickness'),ovrBot2?fmtNum(p+mp+'ovr_bot2_oaf_top'):fmtNum(p+mp+'bot2_oaf_top'),ovrBot2?fmtNum(p+mp+'ovr_bot2_oaf_bot'):fmtNum(p+mp+'bot2_oaf_bot'),'',fmtNum(p+mp+'2_longitudinal_welding'),2));
            rd.segmentPricing.add(lv('Segment Weight (kg)',fmtNum(p+mp+'2_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',fmtNum(p+mp+'2_base_price')));
            rd.segmentPricing.add(lv('Unit Price',fmtDec(decVal(p+mp+'2_unit_price',0))));
            rd.segmentPricing.add(lv('Unit Cost', fmtDec(decVal(p+mp+'2_unit_cost', 0))));
        } else if (segCount == 3) {
            rd.segmentHeaders.add('Top Seg'); rd.segmentHeaders.add('Mid Seg'); rd.segmentHeaders.add('Bottom Seg');
            rd.segmentData.add(segCol(fmtNum(p+mp+'3_top_length'),fmtNum(p+mp+'3_top_thickness'),fmtNum(p+mp+'3_top_oaf_top'),fmtNum(p+mp+'3_top_oaf_bot'),fmtNum(p+mp+'ovr_t_m'),fmtNum(p+mp+'3_longitudinal_welding'),1));
            Boolean ovrMid2 = getBoolVal(p+mp+'override_mid2');
            rd.segmentData.add(segCol(ovrMid2?fmtNum(p+mp+'ovr_mid2_length'):fmtNum(p+mp+'mid2_length'),ovrMid2?fmtNum(p+mp+'ovr_mid2_thickness'):fmtNum(p+mp+'mid2_thickness'),ovrMid2?fmtNum(p+mp+'ovr_mid2_oaf_top'):fmtNum(p+mp+'mid2_oaf_top'),ovrMid2?fmtNum(p+mp+'ovr_mid2_oaf_bot'):fmtNum(p+mp+'mid2_oaf_bot'),fmtNum(p+mp+'ovr_m_b'),'',2));
            Boolean ovrBot3 = getBoolVal(p+mp+'override_bot3');
            rd.segmentData.add(segCol(ovrBot3?fmtNum(p+mp+'ovr_bot3_length'):fmtNum(p+mp+'bot3_length'),ovrBot3?fmtNum(p+mp+'ovr_bot3_thickness'):fmtNum(p+mp+'bot3_thickness'),ovrBot3?fmtNum(p+mp+'ovr_bot3_oaf_top'):fmtNum(p+mp+'bot3_oaf_top'),ovrBot3?fmtNum(p+mp+'ovr_bot3_oaf_bot'):fmtNum(p+mp+'bot3_oaf_bot'),'','',3));
            rd.segmentPricing.add(lv('Segment Weight (kg)',fmtNum(p+mp+'3_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',fmtNum(p+mp+'3_base_price')));
            rd.segmentPricing.add(lv('Unit Price',fmtDec(decVal(p+mp+'3_unit_price',0))));
            rd.segmentPricing.add(lv('Unit Cost', fmtDec(decVal(p+mp+'3_unit_cost', 0))));
        } else if (segCount == 4) {
            rd.segmentHeaders.add('Top Seg'); rd.segmentHeaders.add('Mid Seg 1'); rd.segmentHeaders.add('Mid Seg 2'); rd.segmentHeaders.add('Bottom Seg');
            rd.segmentData.add(segCol(fmtNum(p+mp+'4_top_length'),fmtNum(p+mp+'4_top_thickness'),fmtNum(p+mp+'4_top_oaf_top'),fmtNum(p+mp+'4_top_oaf_bot'),fmtNum(p+mp+'ovr_t_m'),fmtNum(p+mp+'4_longitudinal_welding'),1));
            Boolean ovrMid2b = getBoolVal(p+mp+'override_mid2');
            rd.segmentData.add(segCol(ovrMid2b?fmtNum(p+mp+'ovr_mid2_length'):fmtNum(p+mp+'mid2_length'),ovrMid2b?fmtNum(p+mp+'ovr_mid2_thickness'):fmtNum(p+mp+'mid2_thickness'),ovrMid2b?fmtNum(p+mp+'ovr_mid2_oaf_top'):fmtNum(p+mp+'mid2_oaf_top'),ovrMid2b?fmtNum(p+mp+'ovr_mid2_oaf_bot'):fmtNum(p+mp+'mid2_oaf_bot'),fmtNum(p+mp+'ovr_m1_m2'),'',2));
            Boolean ovrMid3b = getBoolVal(p+mp+'override_mid3');
            rd.segmentData.add(segCol(ovrMid3b?fmtNum(p+mp+'ovr_mid3_length'):fmtNum(p+mp+'mid3_length'),ovrMid3b?fmtNum(p+mp+'ovr_mid3_thickness'):fmtNum(p+mp+'mid3_thickness'),ovrMid3b?fmtNum(p+mp+'ovr_mid3_oaf_top'):fmtNum(p+mp+'mid3_oaf_top'),ovrMid3b?fmtNum(p+mp+'ovr_mid3_oaf_bot'):fmtNum(p+mp+'mid3_oaf_bot'),fmtNum(p+mp+'ovr_m2_b'),'',3));
            Boolean ovrBot4 = getBoolVal(p+mp+'override_bot4');
            rd.segmentData.add(segCol(ovrBot4?fmtNum(p+mp+'ovr_bot4_length'):fmtNum(p+mp+'bot4_length'),ovrBot4?fmtNum(p+mp+'ovr_bot4_thickness'):fmtNum(p+mp+'bot4_thickness'),ovrBot4?fmtNum(p+mp+'ovr_bot4_oaf_top'):fmtNum(p+mp+'bot4_oaf_top'),ovrBot4?fmtNum(p+mp+'ovr_bot4_oaf_bot'):fmtNum(p+mp+'bot4_oaf_bot'),'','',4));
            rd.segmentPricing.add(lv('Segment Weight (kg)',fmtNum(p+mp+'4_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',fmtNum(p+mp+'4_base_price')));
            rd.segmentPricing.add(lv('Unit Price',fmtDec(decVal(p+mp+'4_unit_price',0))));
            rd.segmentPricing.add(lv('Unit Cost', fmtDec(decVal(p+mp+'4_unit_cost', 0))));
        } else if (segCount == 5) {
            rd.segmentHeaders.add('Top'); rd.segmentHeaders.add('Mid 1'); rd.segmentHeaders.add('Mid 2'); rd.segmentHeaders.add('Mid 3'); rd.segmentHeaders.add('Bottom');
            rd.segmentData.add(segCol(fmtNum(p+mp+'5_top_length'),fmtNum(p+mp+'5_top_thickness'),fmtNum(p+mp+'5_top_oaf_top'),fmtNum(p+mp+'5_top_oaf_bot'),fmtNum(p+mp+'ovr_t_m'),fmtNum(p+mp+'5_longitudinal_welding'),1));
            Boolean ovrMid2c = getBoolVal(p+mp+'override_mid2');
            rd.segmentData.add(segCol(ovrMid2c?fmtNum(p+mp+'ovr_mid2_length'):fmtNum(p+mp+'mid2_length'),ovrMid2c?fmtNum(p+mp+'ovr_mid2_thickness'):fmtNum(p+mp+'mid2_thickness'),ovrMid2c?fmtNum(p+mp+'ovr_mid2_oaf_top'):fmtNum(p+mp+'mid2_oaf_top'),ovrMid2c?fmtNum(p+mp+'ovr_mid2_oaf_bot'):fmtNum(p+mp+'mid2_oaf_bot'),fmtNum(p+mp+'ovr_m1_m2'),'',2));
            Boolean ovrMid3c = getBoolVal(p+mp+'override_mid3');
            rd.segmentData.add(segCol(ovrMid3c?fmtNum(p+mp+'ovr_mid3_length'):fmtNum(p+mp+'mid3_length'),ovrMid3c?fmtNum(p+mp+'ovr_mid3_thickness'):fmtNum(p+mp+'mid3_thickness'),ovrMid3c?fmtNum(p+mp+'ovr_mid3_oaf_top'):fmtNum(p+mp+'mid3_oaf_top'),ovrMid3c?fmtNum(p+mp+'ovr_mid3_oaf_bot'):fmtNum(p+mp+'mid3_oaf_bot'),fmtNum(p+mp+'ovr_m2_m3'),'',3));
            Boolean ovrMid4c = getBoolVal(p+mp+'override_mid4');
            rd.segmentData.add(segCol(ovrMid4c?fmtNum(p+mp+'ovr_mid4_length'):fmtNum(p+mp+'mid4_length'),ovrMid4c?fmtNum(p+mp+'ovr_mid4_thickness'):fmtNum(p+mp+'mid4_thickness'),ovrMid4c?fmtNum(p+mp+'ovr_mid4_oaf_top'):fmtNum(p+mp+'mid4_oaf_top'),ovrMid4c?fmtNum(p+mp+'ovr_mid4_oaf_bot'):fmtNum(p+mp+'mid4_oaf_bot'),fmtNum(p+mp+'ovr_m3_b'),'',4));
            Boolean ovrBot5 = getBoolVal(p+mp+'override_bot5');
            rd.segmentData.add(segCol(ovrBot5?fmtNum(p+mp+'ovr_bot5_length'):fmtNum(p+mp+'bot5_length'),ovrBot5?fmtNum(p+mp+'ovr_bot5_thickness'):fmtNum(p+mp+'bot5_thickness'),ovrBot5?fmtNum(p+mp+'ovr_bot5_oaf_top'):fmtNum(p+mp+'bot5_oaf_top'),ovrBot5?fmtNum(p+mp+'ovr_bot5_oaf_bot'):fmtNum(p+mp+'bot5_oaf_bot'),'','',5));
            rd.segmentPricing.add(lv('Segment Weight (kg)',fmtNum(p+mp+'5_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',fmtNum(p+mp+'5_base_price')));
            rd.segmentPricing.add(lv('Unit Price',fmtDec(decVal(p+mp+'5_unit_price',0))));
            rd.segmentPricing.add(lv('Unit Cost', fmtDec(decVal(p+mp+'5_unit_cost', 0))));
        } else if (segCount >= 6) {
            // ── SEGMENT ABOVE 5: same field pattern as the 5-segment branch, generalized ── Reetabrata (8th July 2026)
            rd.segmentHeaders.add('Top');
            for (Integer j = 1; j <= segCount - 2; j++) rd.segmentHeaders.add('Mid ' + j);
            rd.segmentHeaders.add('Bottom');
 
            rd.segmentData.add(segCol(
                fmtNum(p+mp+''+segCount+'_top_length'),
                fmtNum(p+mp+''+segCount+'_top_thickness'),
                fmtNum(p+mp+''+segCount+'_top_oaf_top'),
                fmtNum(p+mp+''+segCount+'_top_oaf_bot'),
                fmtNum(p+mp+'ovr_t_m'),
                fmtNum(p+mp+''+segCount+'_longitudinal_welding'), 1));
 
            for (Integer k = 2; k <= segCount - 1; k++) {
                Boolean ovrMid = getBoolVal(p+mp+'override_mid'+k);
                String seg  = 'mid' + k;
                String junc = (k < segCount - 1)
                    ? p+mp+'ovr_m'+(k-1)+'_m'+k
                    : p+mp+'ovr_m'+(k-1)+'_b';
                rd.segmentData.add(segCol(
                    pickSeg(p, seg, 'length',    ovrMid),
                    pickSeg(p, seg, 'thickness', ovrMid),
                    pickSeg(p, seg, 'oaf_top',   ovrMid),
                    pickSeg(p, seg, 'oaf_bot',   ovrMid),
                    fmtNum(junc), '', k));
            }
 
            Boolean ovrBot = getBoolVal(p+mp+'override_bot'+segCount);
            String segB = 'bot' + segCount;
            rd.segmentData.add(segCol(
                pickSeg(p, segB, 'length',    ovrBot),
                pickSeg(p, segB, 'thickness', ovrBot),
                pickSeg(p, segB, 'oaf_top',   ovrBot),
                pickSeg(p, segB, 'oaf_bot',   ovrBot),
                '', '', segCount));
 
            rd.segmentPricing.add(lv('Segment Weight (kg)', fmtNum(p+mp+''+segCount+'_segment_weight')));
            rd.segmentPricing.add(lv('Base Price',          fmtNum(p+mp+''+segCount+'_base_price')));
            rd.segmentPricing.add(lv('Unit Price', fmtDec(decVal(p+mp+''+segCount+'_unit_price', 0))));
            rd.segmentPricing.add(lv('Unit Cost',  fmtDec(decVal(p+mp+''+segCount+'_unit_cost',  0))));
        }
        
        
    }
 
    // ═══════════════════════════════════════════════════════════════
    // SEGMENT ABOVE 5 - Additional Accessories + Special Items
    // Both are stored UNPREFIXED by the estimator (one set per quote).
    // Each block renders only when its keys exist, so every other mast
    // type is completely unaffected. - Reetabrata (9th July 2026)
    // ═══════════════════════════════════════════════════════════════
    private void buildSegmentAbove5Extras() {
        hasAdditionalAcc  = false;
        hasSpecialItem    = false;
        siShownSeparately = false;
        accRate = '0'; accRealization = '0'; accRealizationAmount = '0'; accTotalRate = '0';
        siType  = ''; siDescription  = ''; siValue = '0';
 
        if (jd == null || jd.isEmpty()) return;
 
        // 27-Jul per-row sections: the estimator now saves r{n}_lm_acc_* and
        // r{n}_lm_si_* per mast row and the bare keys no longer exist on new
        // quotes (which made both tables vanish from the weight PDF). The
        // scan below finds each family's FIRST populated row; '' scans the
        // bare keys last, so legacy quotes print exactly as before.
        // NOTE: this surfaces one row's values in the existing single table -
        // a per-row table needs the VF page reworked as well.
        // Deepanjan (27th July 2026)
        List<String> rowPrefixes = new List<String>{
            'r1_','r2_','r3_','r4_','r5_','r6_','r7_','r8_','r9_','r10_',''
        };
 
        for (String p : rowPrefixes) {
            if (jd.containsKey(p + 'lm_acc_rate') || jd.containsKey(p + 'lm_acc_total_rate')) {
                Decimal rate = decVal(p + 'lm_acc_rate', 0);
                Decimal real = decVal(p + 'lm_acc_realization', 0);
                Decimal ramt = decVal(p + 'lm_acc_realization_amount', rate * real / 100);
                Decimal totl = decVal(p + 'lm_acc_total_rate', rate + ramt);
                if (rate != 0 || totl != 0) {
                    hasAdditionalAcc     = true;
                    accRate              = fmtDec(rate);
                    accRealization       = fmtDec(real);
                    accRealizationAmount = fmtDec(ramt);
                    accTotalRate         = fmtDec(totl);
                    break;
                }
            }
        }
 
        for (String p : rowPrefixes) {
            String t = sGet(p + 'lm_si_type', '');
            if (String.isNotBlank(t)) {
                hasSpecialItem    = true;
                siType            = t;
                siDescription     = sGet(p + 'lm_si_description', '');
                siValue           = fmtDec(decVal(p + 'lm_si_value', 0));
                // Ticked  => billed as its own offer line, NOT folded into mast price/weight.
                // Unticked => already folded in by lm_si_price_add / lm_si_weight_add.
                siShownSeparately = siBoolVal(p + 'lm_si_show_separate');
                break;
            }
        }
    }
 
    private Boolean siBoolVal(String key) {
        if (jd == null || !jd.containsKey(key) || jd.get(key) == null) return false;
        Object v = jd.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        String sv = String.valueOf(v).trim();
        return sv.equalsIgnoreCase('true') || sv == '1';
    }
 
    private Boolean getBoolVal(String key) {
        if (!jd.containsKey(key) || jd.get(key) == null) return false;
        try { return (Boolean) jd.get(key); } catch (Exception ex) { return false; }
    }
    
    // returns the override value when the override is ON and non-zero, otherwise the base value - Reetabrata (8th July 2026)
    private String pickSeg(String p, String seg, String attr, Boolean ovrOn) {
        if (ovrOn && decVal(p + 'lm_ovr_' + seg + '_' + attr, 0) != 0) {
            return fmtNum(p + 'lm_ovr_' + seg + '_' + attr);
        }
        return fmtNum(p + 'lm_' + seg + '_' + attr);
    }
 
    // ═══════════════════════════════════════════════════════════════
    // RESOLVE REMARKS
    // ═══════════════════════════════════════════════════════════════
    private String resolveRemark(String sNo, Decimal qty, String winchType,
            String suspnSysm, String noOfSides, String typeOfAol, Integer segCount) {
        Boolean hasQty = (qty != null && qty >= 1);
        Integer sides = 0;
        try { sides = Integer.valueOf(noOfSides); } catch(Exception ex){}
 
        if (segCount == 1) {
            if (sNo == '1') { if(suspnSysm=='A') return 'HMRSI0042'; else if(suspnSysm=='E') return 'HMRSI000060'; else return '0'; }
            if (sNo == '1.1') return hasQty ? 'CMMEC0050' : '----';
            if (sNo == '1.2') return 'HMRSI0032';
            if (sNo == '1.3') return 'HMRSI000045';
            if (sNo == '2') { if(noOfSides=='Q') return 'HMRSI0034'; else if(noOfSides=='G') return 'HMRSI0027'; else return '0'; }
            if (sNo == '2.1') return hasQty ? 'CMMEC0048' : '----';
            if (sNo == '2.2') return hasQty ? 'CMMEC0049' : '----';
            if (sNo == '2.3') return hasQty ? 'CMMEC0022' : '----';
            if (sNo == '2.4') return hasQty ? 'HMRSI0018' : '----';
            if (sNo == '3') { if(suspnSysm=='T') return 'HMELC0003'; else if(suspnSysm=='F') return 'HMELC0004'; else return '0'; }
            if (sNo == '4') { if(sides==6) return 'HMMEC0021'; else if(sides==8) return 'HMMEC0023'; else return '0'; }
            if (sNo == '20') { if(typeOfAol=='S') return 'HMRSI0002'; else if(typeOfAol=='D') return 'HMRSI0001'; else if(typeOfAol=='L') return 'HMRSI000061'; else if(typeOfAol=='K') return 'HMRSI0031'; else return '----'; }
        }
        if (segCount == 2) {
            if (sNo == '1') { if(winchType=='B') return 'HMRSI0042'; else if(winchType=='C') return 'HMRSI0011'; else if(winchType=='A') return 'HMRSI000060'; else if(winchType=='D') return 'HMMEC000190'; else return '0'; }
            if (sNo == '1.1') return hasQty ? 'CMMEC0050' : '----';
            if (sNo == '1.2') return 'HMRSI0032';
            if (sNo == '1.3') return 'HMRSI000045';
            if (sNo == '2')   return hasQty ? 'HMRSI0043' : '----';
            if (sNo == '2.1') return hasQty ? 'CMMEC0048' : '----';
            if (sNo == '2.2') return hasQty ? 'CMMEC0049' : '----';
            if (sNo == '2.3') return hasQty ? 'CMMEC0022' : '----';
            if (sNo == '2.4') return hasQty ? 'HMRSI0018' : '----';
            if (sNo == '3') { if(suspnSysm=='T') return 'HMELC0003'; else if(suspnSysm=='F') return 'HMELC0004'; else return '0'; }
            if (sNo == '4') { if(sides==6) return 'HMMEC0021'; else if(sides==8) return 'HMMEC0023'; else return '0'; }
            if (sNo == '20') { if(typeOfAol=='S') return 'HMRSI0002'; else if(typeOfAol=='D') return 'HMRSI0001'; else if(typeOfAol=='L') return 'HMRSI000061'; else if(typeOfAol=='K') return 'HMRSI0031'; else return '----'; }
        }
        // segCount >= 3
        if (sNo == '1') { if(winchType=='C') return 'HMRSI0011'; else if(winchType=='D') return 'HMRSI0041'; else return 'HMRSI0032'; }
        if (sNo == '1.1') return hasQty ? 'CMMEC0050' : '----';
        if (sNo == '1.2') return 'HMRSI0032';
        if (sNo == '1.3') return 'HMRSI000045';
        if (sNo == '2')   return hasQty ? 'HMRSI0043' : '----';
        if (sNo == '2.1') return hasQty ? 'CMMEC0048' : '----';
        if (sNo == '2.2') return hasQty ? 'CMMEC0049' : '----';
        if (sNo == '2.3') return hasQty ? 'CMMEC0022' : '----';
        if (sNo == '2.4') return hasQty ? 'HMRSI0038' : '----';
        if (sNo == '3') { if(suspnSysm=='T') return 'HMELC0003'; else if(suspnSysm=='F') return 'HMELC0004'; else if(suspnSysm=='S') return 'HMELC000020'; else if(suspnSysm=='H') return 'HMELC0002'; else return '0'; }
        if (sNo == '4') { if(sides==6) return 'HMMEC0021'; else if(sides==8) return 'HMMEC0023'; else return '0'; }
        if (sNo == '20') { if(typeOfAol=='S') return 'HMRSI0002'; else if(typeOfAol=='D') return 'HMRSI0001'; else if(typeOfAol=='L') return 'HMRSI000061'; else if(typeOfAol=='K') return 'HMRSI0031'; else return '----'; }
        // shared qty-based codes
        if (sNo=='5')    return hasQty?'HMMEC0009':'----';   if (sNo=='6')    return hasQty?'HMMEC0004':'----';
        if (sNo=='7')    return hasQty?'HMMEC0018':'----';   if (sNo=='8')    return hasQty?'HMMEC0001':'----';
        if (sNo=='9')    return hasQty?'HMMEC0002':'----';   if (sNo=='10')   return hasQty?'HMFST0011':'----';
        if (sNo=='10.1') return hasQty?'HMFST0024':'----';   if (sNo=='10.2') return hasQty?'HMFST0001':'----';
        if (sNo=='11')   return hasQty?'HMFST0012':'----';   if (sNo=='12')   return hasQty?'HMFST0007':'----';
        if (sNo=='12.1') return hasQty?'HMFST0038':'----';   if (sNo=='12.2') return hasQty?'HMELC0005':'----';
        if (sNo=='13')   return hasQty?'HMFST0020':'----';   if (sNo=='13.1') return hasQty?'HMFST0029':'----';
        if (sNo=='13.2') return hasQty?'HMFST0003':'----';   if (sNo=='13.3') return 'CMFST000515';
        if (sNo=='13.4') return 'HMMEC000190';               if (sNo=='14')   return hasQty?'CMFST0323':'----';
        if (sNo=='15')   return hasQty?'HMFST0016':'----';   if (sNo=='15.1') return 'HMFST000064';
        if (sNo=='15.2') return hasQty?'HMFST0030':'----';   if (sNo=='15.3') return hasQty?'HMFST0004':'----';
        if (sNo=='16')   return hasQty?'CMMEC001767':'----';  if (sNo=='16.1') return hasQty?'HMFST0028':'----';
        if (sNo=='16.2') return hasQty?'HMFST0002':'----';   if (sNo=='17')   return hasQty?'HMMEC0013':'----';
        if (sNo=='17.1') return 'HMRSI0019';                 if (sNo=='17.2') return 'HMRSI0020';
        if (sNo=='17.3') return hasQty?'HMMEC0014':'----';   if (sNo=='17.4') return hasQty?'HMFST0033':'----';
        if (sNo=='17.5') return hasQty?'HMFST0031':'----';   if (sNo=='17.6') return 'HMMEC0011';
        if (sNo=='18')   return hasQty?'CMELC0816':'----';   if (sNo=='19')   return hasQty?'HMRSI0016':'----';
        if (sNo=='19.1') return 'HMMEC0045';
        if (sNo=='21')   return hasQty?'HMMEC0046':'----';   if (sNo=='21.1') return hasQty?'HMMEC0057':'----';
        if (sNo=='22')   return hasQty?'HMRSI0003':'----';   if (sNo=='23')   return hasQty?'HMRSI0004':'----';
        if (sNo=='24')   return hasQty?'CMGEN000673':'----';  if (sNo=='24.1') return 'CMGEN0088';
        if (sNo=='24.2') return 'CMGEN002209';               if (sNo=='25')   return 'CMGEN000655';
        if (sNo=='25.1') return '----';
        return '';
    }
 
    // ═══════════════════════════════════════════════════════════════
    // BUILD ACCESSORIES
    // ═══════════════════════════════════════════════════════════════
    private void buildAccessories(RowData rd, String k, String kitPfx, Decimal kitSeg) {
        String  winchDesc = resolveWinchDescription(beforeEq(sGet(kitPfx+'lm_type_of_winch','')), (Integer) kitSeg);
        Decimal rdQty30   = decVal(k+'rope_drum_30_qty_consumed',0);
        Decimal rdQty40   = decVal(k+'rope_drum_40_qty_consumed',0);
        Decimal rdQty20   = decVal(k+'rope_drum_20_qty_consumed',0);
        Decimal rdCost30  = decVal(k+'rope_drum_30',0);
        Decimal rdCost40  = decVal(k+'rope_drum_40',0);
        Decimal rdCost20  = decVal(k+'rope_drum_20',0);

        System.debug('rdQuantity: '+ rdQty20 +' rd20 cost: '+rdCost20 );
        String  winchType = rd.cfgTypeOfWinch;
        String  suspnSysm = rd.cfgSuspnSysm;
        String  noOfSides = rd.noOfSides;
        String  typeOfAol = rd.cfgTypeOfAol;
        Integer segCount  = 2;
        try { segCount = Integer.valueOf(rd.noOfSegment); } catch(Exception ex){}
 
        AccessoryLineItem ali;
        ali=accFromKeys('1','High Mast winch',winchDesc,'Nos.',k+'high_mast_winch_qty_consumed',k+'high_mast_winch',false); ali.remarks=resolveRemark('1',decVal(k+'high_mast_winch_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('1.1','Sprocket','Sprocket,1/2", 40 Teeth, Simp.','Nos.',k+'sprocket_40t_qty_consumed',k+'sprocket_40t',true); ali.remarks=resolveRemark('1.1',decVal(k+'sprocket_40t_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        if (kitSeg >= 3) {
            ali=accRaw('1.2','Rope Drum 20 Mtr','Rope Drum 20 Mtr','Nos.',fmtQty(rdQty20),fmtDec(rdCost20),fmtQty(rdQty20),true,rdCost20==0); ali.remarks=resolveRemark('1.2',rdQty20,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
            ali=accRaw('1.3','Rope Drum 30 Mtr','Rope Drum 30 Mtr','Nos.',fmtQty(rdQty30),fmtDec(rdCost30),fmtQty(rdQty30),true,rdCost30==0); ali.remarks=resolveRemark('1.3',rdQty30,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
            ali=accRaw('1.4','Rope Drum 40 Mtr','Rope Drum 40 Mtr','Nos.',fmtQty(rdQty40),fmtDec(rdCost40),fmtQty(rdQty40),true,rdCost40==0); ali.remarks=resolveRemark('1.4',rdQty40,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
 
        } else if (kitSeg == 2) {
            ali=accRaw('1.2','Rope Drum 20 Mtr','Rope Drum 20 Mtr','Nos.',fmtQty(rdQty20),fmtDec(rdCost20),fmtQty(rdQty20),true,rdCost20==0); ali.remarks=resolveRemark('1.2',rdQty20,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
			ali=accRaw('1.3','Rope Drum 30 Mtr','Rope Drum 30 Mtr','Nos.',fmtQty(rdQty30),fmtDec(rdCost30),fmtQty(rdQty30),true,rdCost30==0); ali.remarks=resolveRemark('1.3',rdQty30,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        } else {
            ali=accRaw('1.2','Rope Drum 20 Mtr','Rope Drum 20 Mtr','Nos.',fmtQty(rdQty20),fmtDec(rdCost20),fmtQty(rdQty20),true,rdCost20==0); ali.remarks=resolveRemark('1.2',rdQty20,winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        }
        String ptDesc=afterEq(sGet(kitPfx+'lm_type_of_power_tool',''));
        ali=accFromKeys('2','Power Tool',ptDesc,'Nos.',k+'power_tool_qty_consumed',k+'power_tool',false); ali.remarks=resolveRemark('2',decVal(k+'power_tool_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('2.1','Sprocket','Sprocket,1/2",15teeth,Simp.','Nos.',k+'sprocket_15t_qty_consumed',k+'sprocket_15t',true); ali.remarks=resolveRemark('2.1',decVal(k+'sprocket_15t_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('2.2','Sprocket','Sprocket,1/2",20teeth,Simp.','Nos.',k+'sprocket_20t_qty_consumed',k+'sprocket_20t',true); ali.remarks=resolveRemark('2.2',decVal(k+'sprocket_20t_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('2.3','Simplex Chain, 1/2"','Simplex Chain, 1/2"','Nos.',k+'simplex_chain_qty_consumed',k+'simplex_chain',true); ali.remarks=resolveRemark('2.3',decVal(k+'simplex_chain_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('2.4','Torque Limiter','','Nos.',k+'torque_limiter_qty_consumed',k+'torque_limiter',true); ali.remarks=resolveRemark('2.4',decVal(k+'torque_limiter_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        String cblDesc=afterEq(sGet(kitPfx+'lm_cable_type',''));
        ali=accFromKeys('3','Trailing Cable*',cblDesc,'Meter',k+'trailing_cable_qty_consumed',k+'trailing_cable',false); ali.remarks=resolveRemark('3',decVal(k+'trailing_cable_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        String ropeDesc=afterEq(sGet(kitPfx+'lm_type_of_wire_rope',''));
        ali=accFromKeys('4','SS. Wire Rope',ropeDesc,'Meter',k+'ss_wire_rope_qty_consumed',k+'ss_wire_rope',false); ali.remarks=resolveRemark('4',decVal(k+'ss_wire_rope_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('5','Doc Clamp 6mm with Nut','SS.6mm Dia','Nos.',k+'doc_clamp_6mm_qty_consumed',k+'doc_clamp_6mm',false); ali.remarks=resolveRemark('5',decVal(k+'doc_clamp_6mm_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('6','Aluminium ferrul 6mm','SS 6mm Dia','Nos.',k+'aluminium_ferrul_qty_consumed',k+'aluminium_ferrul',false); ali.remarks=resolveRemark('6',decVal(k+'aluminium_ferrul_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('7','SS Thimble 6mm','SS 6mm Dia','Nos.',k+'ss_thimble_6mm_qty_consumed',k+'ss_thimble_6mm',false); ali.remarks=resolveRemark('7',decVal(k+'ss_thimble_6mm_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('8','Al Cable & wire clamp','','Nos.',k+'al_cable_wire_clamp_qty_consumed',k+'al_cable_wire_clamp',false); ali.remarks=resolveRemark('8',decVal(k+'al_cable_wire_clamp_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('9','Al Cable Clamp','','Nos.',k+'al_cable_clamp_qty_consumed',k+'al_cable_clamp',false); ali.remarks=resolveRemark('9',decVal(k+'al_cable_clamp_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('10','SS Bolt (M12x40)','M12x40','Nos.',k+'ss_bolt_m12x40_qty_consumed',k+'ss_bolt_m12x40',false); ali.remarks=resolveRemark('10',decVal(k+'ss_bolt_m12x40_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('10.1','SS Nut(M12)','M12','Nos.',k+'ss_nut_m12_qty_consumed',k+'ss_nut_m12',true); ali.remarks=resolveRemark('10.1',decVal(k+'ss_nut_m12_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('10.2','SS Washers(M12)','M12','Nos.',k+'ss_washers_m12_qty_consumed',k+'ss_washers_m12',true); ali.remarks=resolveRemark('10.2',decVal(k+'ss_washers_m12_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('11','SS Bolt (M12x60)','M12x60','Nos.',k+'ss_bolt_m12x60_qty_consumed',k+'ss_bolt_m12x60',false); ali.remarks=resolveRemark('11',decVal(k+'ss_bolt_m12x60_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('12','SS Bolt(M10x40)','M10x40','Nos.',k+'ss_bolt_m10x40_qty_consumed',k+'ss_bolt_m10x40',false); ali.remarks=resolveRemark('12',decVal(k+'ss_bolt_m10x40_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('12.1','SS Nut(M10)','M10','Nos.',k+'ss_nut_m10_qty_consumed',k+'ss_nut_m10',true); ali.remarks=resolveRemark('12.1',decVal(k+'ss_nut_m10_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('12.2','SS Washers(M10)','M10','Nos.',k+'ss_washers_m10_qty_consumed',k+'ss_washers_m10',true); ali.remarks=resolveRemark('12.2',decVal(k+'ss_washers_m10_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('13','SS Screw (M6x30)','M6x30','Nos.',k+'ss_screw_m6x30_qty_consumed',k+'ss_screw_m6x30',false); ali.remarks=resolveRemark('13',decVal(k+'ss_screw_m6x30_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('13.1','SS Nut(M6)','M6','Nos.',k+'ss_nut_m6_qty_consumed',k+'ss_nut_m6',true); ali.remarks=resolveRemark('13.1',decVal(k+'ss_nut_m6_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('13.2','SS Washers(M6)','M6','Nos.',k+'ss_washers_m6_qty_consumed',k+'ss_washers_m6',true); ali.remarks=resolveRemark('13.2',decVal(k+'ss_washers_m6_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('13.3','SS Allen Bolt M6x30','','Nos.',k+'ss_allen_bolt_m6x30_qty_consumed',k+'ss_allen_bolt_m6x30',true); ali.remarks=resolveRemark('13.3',decVal(k+'ss_allen_bolt_m6x30_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('13.4','MS Hinge Roller M15x60','','Set',k+'ms_hinge_roller_qty_consumed',k+'ms_hinge_roller',true); ali.remarks=resolveRemark('13.4',decVal(k+'ms_hinge_roller_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('14','SS Bolt(M12x85)','M12x85','Nos.',k+'ss_bolt_m12x85_qty_consumed',k+'ss_bolt_m12x85',false); ali.remarks=resolveRemark('14',decVal(k+'ss_bolt_m12x85_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('15','SS Bolt(M8x40)','M8x40','Nos.',k+'ss_bolt_m8x40_qty_consumed',k+'ss_bolt_m8x40',false); ali.remarks=resolveRemark('15',decVal(k+'ss_bolt_m8x40_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('15.1','SS Bolt M8x75','M8x75','Nos.',k+'ss_bolt_m8x75_qty_consumed',k+'ss_bolt_m8x75',true); ali.remarks=resolveRemark('15.1',decVal(k+'ss_bolt_m8x75_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('15.2','SS Nut (M8)','M8','Nos.',k+'ss_nut_m8_qty_consumed',k+'ss_nut_m8',true); ali.remarks=resolveRemark('15.2',decVal(k+'ss_nut_m8_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('15.3','SS Washers (M8)','M8','Nos.',k+'ss_washers_m8_qty_consumed',k+'ss_washers_m8',true); ali.remarks=resolveRemark('15.3',decVal(k+'ss_washers_m8_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('16','Split Pin','','Nos.',k+'split_pin_qty_consumed',k+'split_pin',false); ali.remarks=resolveRemark('16',decVal(k+'split_pin_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('16.1','SS Nut (M5)','M5','Nos.',k+'ss_nut_m5_qty_consumed',k+'ss_nut_m5',true); ali.remarks=resolveRemark('16.1',decVal(k+'ss_nut_m5_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('16.2','SS Washers(M5)','M5','Nos.',k+'ss_washers_m5_qty_consumed',k+'ss_washers_m5',true); ali.remarks=resolveRemark('16.2',decVal(k+'ss_washers_m5_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17','Die cast Al & cable pulley','LM6','Nos.',k+'die_cast_pulley_qty_consumed',k+'die_cast_pulley',false); ali.remarks=resolveRemark('17',decVal(k+'die_cast_pulley_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.1','Solid Rope Pulley','','Nos.',k+'solid_rope_pulley_qty_consumed',k+'solid_rope_pulley',true); ali.remarks=resolveRemark('17.1',decVal(k+'solid_rope_pulley_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.2','Solid Cable Pulley','','Nos.',k+'solid_cable_pulley_qty_consumed',k+'solid_cable_pulley',true); ali.remarks=resolveRemark('17.2',decVal(k+'solid_cable_pulley_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.3','SS Axle, 5/8 X95','5/8x95','Nos.',k+'ss_axle_5_8x95_qty_consumed',k+'ss_axle_5_8x95',true); ali.remarks=resolveRemark('17.3',decVal(k+'ss_axle_5_8x95_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.4','SS Stud Pin, M5x95','M5 x95','Nos.',k+'ss_stud_pin_m5x95_qty_consumed',k+'ss_stud_pin_m5x95',true); ali.remarks=resolveRemark('17.4',decVal(k+'ss_stud_pin_m5x95_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.5','SS Spacer','','Nos.',k+'ss_spacer_qty_consumed',k+'ss_spacer',true); ali.remarks=resolveRemark('17.5',decVal(k+'ss_spacer_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('17.6','SS Pin M5 X 50','','Nos.',k+'ss_pin_m5x50_qty_consumed',k+'ss_pin_m5x50',true); ali.remarks=resolveRemark('17.6',decVal(k+'ss_pin_m5x50_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('18','Terminal','','Nos.',k+'terminal_qty_consumed',k+'terminal',false); ali.remarks=resolveRemark('18',decVal(k+'terminal_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('19','PG Gland','','Nos.',k+'pg_gland_qty_consumed',k+'pg_gland',false); ali.remarks=resolveRemark('19',decVal(k+'pg_gland_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('19.1','Junction Box(250*175*100)','','Nos.',k+'junction_box_qty_consumed',k+'junction_box',true); ali.remarks=resolveRemark('19.1',decVal(k+'junction_box_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('20','AOL','NA','Nos.',k+'aol_qty_consumed',k+'aol',false); ali.remarks=resolveRemark('20',decVal(k+'aol_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('21','Allen Key 4mm','','Nos.',k+'allen_key_4mm_qty_consumed',k+'allen_key_4mm',false); ali.remarks=resolveRemark('21',decVal(k+'allen_key_4mm_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('21.1','Allen Key 5mm','','Nos.',k+'allen_key_5mm_qty_consumed',k+'allen_key_5mm',true); ali.remarks=resolveRemark('21.1',decVal(k+'allen_key_5mm_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('22','Control Panel','As Per Standard','Nos.',k+'control_panel_qty_consumed',k+'control_panel',false); ali.remarks=resolveRemark('22',decVal(k+'control_panel_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('23','Feeder Pillar','As Per Standard','Nos.',k+'feeder_pillar_qty_consumed',k+'feeder_pillar',false); ali.remarks=resolveRemark('23',decVal(k+'feeder_pillar_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('24','PVC C Channel','As Per Standard','Meter',k+'pvc_c_channel_qty_consumed',k+'pvc_c_channel',false); ali.remarks=resolveRemark('24',decVal(k+'pvc_c_channel_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('24.1','Gear Oil','','Lit',k+'gear_oil_qty_consumed',k+'gear_oil',true); ali.remarks=resolveRemark('24.1',decVal(k+'gear_oil_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('24.2','PVC Bottle','','Nos.',k+'pvc_bottle_qty_consumed',k+'pvc_bottle',true); ali.remarks=resolveRemark('24.2',decVal(k+'pvc_bottle_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('25','Plastic Drum With Cover & Lock','','Nos.',k+'plastic_drum_qty_consumed',k+'plastic_drum',false); ali.remarks=resolveRemark('25',decVal(k+'plastic_drum_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
        ali=accFromKeys('25.1','Woven Cloth','','Meter',k+'wooven_cloth_qty_consumed',k+'wooven_cloth',true); ali.remarks=resolveRemark('25.1',decVal(k+'wooven_cloth_qty_consumed',0),winchType,suspnSysm,noOfSides,typeOfAol,segCount); rd.accessories.add(ali);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    //  CUSTOMIZED MAST — segment spec tables
    //  Reuses the class's own sGet / decVal / fmtNum / fmtDec / lv / segCol.
    //  One RowData per variant. Segment count drives headers and columns, so
    //  3/4/5 (Stadium) and 1..5 (Flag) render correctly with no code change.
    //  `accessories` is left empty -> the page-2 costing table prints headers
    //  only, which is correct for these product types.
    // ═══════════════════════════════════════════════════════════════════════
    private void buildCustomizedMastData() {
        if (isStadiumMast) {
            if (cmBoolK('man_riding_lift')){
                addCustomizedRow('mrl_', 'MAN RIDING LIFT');
                applyKitCostingToCustomizedRow(rowDataList[rowDataList.size() - 1]); 
            }
            if (cmBoolK('ladder_with_cage')) addCustomizedRow('lwc_', 'LADDER WITH CAGE');
        } else if (isFlagMast) {
            buildFlagMastData();      // row-driven, LM shape
            buildFlagMastExtras();    // accessory + additional tables (one set per quote)
        }
 
        if (rowDataList.isEmpty()) {
            RowData rd = new RowData();
            rd.rowIndex         = 1;
            rd.mastHeight       = '';
            rd.noOfSegment      = '0';
            rd.noOfSides        = '';
            rd.segmentTitleWord = 'Customized';
            rd.segmentHeaders   = new List<String>();
            rd.segmentData      = new List<SegmentCol>();
            rd.segmentPricing   = new List<LabelValue>();
            rd.accessories      = new List<AccessoryLineItem>();
            rd.showCosting      = false;   // fallback customized row: no costing. Reetabrata (13th July 2026)
            rd.codeNoTitle      = 'Customized Mast (please verify quote configuration)';
            rd.costingGroupTitle = '';
            rd.costPerSet       = '0';
            rd.totalCostPrice   = '0';
            rowDataList.add(rd);
        }
    }
 
 
    // ═══════════════════════════════════════════════════════════════════════
    //  FLAG MAST — row-driven builder (mirrors the High Mast/Lighting Mast path).
    //  The estimator now saves one r{n}_ block per mast row using the same
    //  shape as Lighting Mast, with the fm_ prefix and no L-Ring fields.
    //  Reetabrata (15th July 2026)
    // ═══════════════════════════════════════════════════════════════════════
    private void buildFlagMastData() {
        for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
            String rPfx  = 'r' + rowIdx + '_';
            String htRaw = sGet(rPfx + 'fm_height_of_mast', '');
            if (String.isBlank(htRaw)) continue;
            RowData rd = buildFlagRowData(rowIdx, rPfx);
            if (rd != null) rowDataList.add(rd);
        }
    }
 
    private RowData buildFlagRowData(Integer rowIdx, String rPfx) {
        Integer segCount = decVal(rPfx + 'fm_no_of_segment', 0).intValue();
        if (segCount <= 0) return null;
 
        RowData rd = new RowData();
        rd.rowIndex       = rowDataList.size() + 1;
        rd.segmentHeaders = new List<String>();
        rd.segmentData    = new List<SegmentCol>();
        rd.segmentPricing = new List<LabelValue>();
        rd.accessories    = new List<AccessoryLineItem>();
        rd.rowPrefix = rPfx;
 
        rd.mastHeight  = fmtNum(rPfx + 'fm_height_of_mast');
        rd.noOfSegment = String.valueOf(segCount);
        rd.noOfSides   = sGet(rPfx + 'fm_no_of_sides', '');
 
        Map<Integer,String> titleMap = new Map<Integer,String>{
            1=>'One', 2=>'Two', 3=>'Three', 4=>'Four', 5=>'Five' };
        rd.segmentTitleWord = titleMap.containsKey(segCount)
                            ? titleMap.get(segCount) : String.valueOf(segCount);
 
        // Same segment/pricing engine as Lighting Mast, fm_ prefixed.
        buildSegmentData(rd, rPfx, segCount, 'fm_');
 
        rd.basePlateType     = sGet(rPfx + 'fm_bp_type', 'Circular');
        rd.bpOD              = fmtNum(rPfx + 'fm_bp_diameter');
        rd.bpThickness       = fmtNum(rPfx + 'fm_bp_thickness');
        rd.pcd               = fmtNum(rPfx + 'fm_bp_pcd');
        rd.anchorPlateThick  = fmtNum(rPfx + 'fm_bp_anchor_plate_thickness');
        rd.fdnBoltDia        = sGet(rPfx + 'fm_fb_diameter', '');
        rd.fdnBoltLength     = fmtNum(rPfx + 'fm_fb_length');
        rd.fdnNoOfBolt       = fmtNum(rPfx + 'fm_fb_no_of_bolt');
        rd.noOfNut           = fmtNum(rPfx + 'fm_fb_no_of_nut');
        rd.stiffnerThickness = fmtNum(rPfx + 'fm_fb_stiffner_thickness');
        // Flag Mast has no L-Ring. Reetabrata (15th July 2026)
        rd.lRingType         = '';
        rd.ringDia           = '';
 
        // Flag Mast PU Paint carries no weight - the blueprint only saves
        // fm_pu_paint_value, which is a rupee amount, not kilograms. The old
        // fm_pu_paint_weight key was never saved, so this always added 0.
        // Removing it also stops segmentPricing[0] (segment 1's slot) being
        // overwritten with the LAST segment's weight on multi-segment rows.
        // Deepanjan (16th July 2026)
        Decimal segWt = decVal(rPfx + 'fm_' + segCount + '_segment_weight', 0);
        Decimal fndWt = decVal(rPfx + 'fm_foundation_weight', 0);
        rd.totalWeightGI = fmtDec(segWt + fndWt);
 
        // Flag Mast carries no KIT code -> no costing block (unchanged behaviour).
        rd.showCosting       = false;
        rd.codeNoTitle       = 'FLAG MAST';
        rd.costingGroupTitle = 'Costing - FLAG MAST';
        rd.costPerSet        = '0';
        rd.totalCostPrice    = '0';
        return rd;
    }
 
    // ═══════════════════════════════════════════════════════════════
    // FLAG MAST - ACCESSORY COSTING and ADDITIONAL DETAILS
    // Fixed-row catalogues, not user-named repeaters:
    //   fm_ac_{n}_option / _qty / _rate / _amount   (7 rows)
    //   fm_ad_{n}_qty / _rate / _amount             (5 rows)
    // Item names are metadata header fields (fm_ac_{n}_hdr / fm_ad_{n}_desc,
    // type=header), so they are not saved on the quote and are carried in the
    // label tables below. The old r{n}_fm_ac_* / r{n}_fm_add_* keys never existed.
    // _amount is a saved formula (qty * rate * 1.18, GST-inclusive) and the
    // grand totals additionally carry the realization uplift.
    // Deepanjan (16th July 2026)
    // ═══════════════════════════════════════════════════════════════
    private static final List<String> FM_AC_LABELS = new List<String>{
        'Wire Rope', 'Wire rope', 'Winch Gear', 'Motor',
        'Snap hook', 'SS Accessories & Flag Clamps', 'Counter weight', 'Control Panel' };
 
    private static final List<String> FM_AD_LABELS = new List<String>{
        '32A STD FEEDER PILLAR', 'GI STAND',
        'CONTROL PANEL FOR OPERATE ONLY MOTOR OPERATE',
        'SMALL LIGHT FEEDER PILLAR WITH STAND', 'Decorative Dome' };
 
    private void buildFlagMastExtras() {
        fmAccessoryList  = new List<FmItemRow>();
        fmAdditionalList = new List<FmItemRow>();
        
        for (RowData rd : rowDataList){
            String p = String.isBlank(rd.rowPrefix) ? '' : rd.rowPrefix;
            
            rd.fmAccessoryList  = buildFmItemRows(p + 'fm_ac_', FM_AC_MAX_ROWS,  FM_AC_LABELS, true);
        	rd.fmAdditionalList = buildFmItemRows(p + 'fm_ad_', FM_ADD_MAX_ROWS, FM_AD_LABELS, false);
            rd.fmAcTotal        = resolveFmTotal(p + 'fm_ac_grand_total',  rd.fmAccessoryList);
            rd.fmAddTotal       = resolveFmTotal(p + 'fm_ad_grand_total', rd.fmAdditionalList);
            
            System.debug('****1641 '+ rd.fmAccessoryList + ' ' + rd.fmAdditionalList + ' p -> ' + p);
            
            rd.hasFmAccessory   = !rd.fmAccessoryList.isEmpty();
            rd.hasFmAdditional  = !rd.fmAdditionalList.isEmpty();
            
            fmAccessoryList.addAll(rd.fmAccessoryList);
            fmAdditionalList.addAll(rd.fmAdditionalList);
        }
        
        hasFmAccessory  = !fmAccessoryList.isEmpty();
        hasFmAdditional = !fmAdditionalList.isEmpty();
        
        fmAcTotal       = resolveFmTotal('fm_ac_grand_total', fmAccessoryList);
        fmAddTotal      = resolveFmTotal('fm_ad_grand_total', fmAdditionalList);
    }
 
    private List<FmItemRow> buildFmItemRows(String mid, Integer maxRows,
                                            List<String> labels, Boolean withOption) {
        List<FmItemRow> rows = new List<FmItemRow>();
           Integer slNo = 0;                                                
           for (Integer i = 1; i <= maxRows; i++) {
                String p = mid + i + '_';
     
                Decimal qty = decVal(p + 'qty', 0);
                if (qty <= 0) continue;
               	slNo++;
     
                Decimal rate = decVal(p + 'rate', 0);
                // amount is a readOnly formula (qty * rate * 1.18); recompute on the
                // same basis only if the estimator did not save it.
                Decimal amount = decVal(p + 'amount', qty * rate * 1.18);
     
                String label = labels[i - 1];
                if (withOption) {
                    String opt = sGet(p + 'option', '');
                    if (String.isNotBlank(opt)) label += ' (' + opt + ')';
                }
                 
                FmItemRow r  = new FmItemRow();
                // sl_no is a readOnly label field in the blueprint and saves blank,
                // so the fixed catalogue position is used.
                r.slNo       = String.valueOf(slNo);
                r.itemName   = label;
                r.quantity   = fmtQty(qty);
                r.rate       = fmtDec(rate);
                r.amount     = fmtDec(amount);
                r.amountRaw  = amount;
                rows.add(r);
            }
                                                 
        return rows;
    }
 
    private String resolveFmTotal(String totalKey, List<FmItemRow> rows) {
        
        if (jd.containsKey(totalKey)) {   // legacy bare-key quotes
            Decimal saved = decVal(totalKey, 0);
            if (saved != 0) return fmtDec(saved);
        }
        
        Decimal sum = 0;
        for (FmItemRow r : rows) sum += r.amountRaw;
        return fmtDec(sum);
    }
 
    private void addCustomizedRow(String p, String variant) {
 
        Boolean isFm = (p == 'fm_');
        Integer n    = isFm ? decVal('fm_no_of_segment', 0).intValue()
                            : decVal(p + 'no_of_segment', 0).intValue();
        if (n <= 0) return;
 
        RowData rd = new RowData();
        rd.rowIndex       = rowDataList.size() + 1;
        rd.segmentHeaders = cmHeaders(n);
        rd.segmentData    = new List<SegmentCol>();
        rd.segmentPricing = new List<LabelValue>();
        rd.accessories    = new List<AccessoryLineItem>();
 
        Decimal mastHt = decVal(p + 'height_of_mast', 0);
        if (!isFm && mastHt == 0) {
            mastHt = decVal(p + 'segment_height', 0) + decVal(p + 'head_frame_height', 0);
        }
        rd.mastHeight  = fmtDec(mastHt);
        rd.noOfSegment = String.valueOf(n);
        rd.noOfSides   = '';
 
        Map<Integer,String> titleMap = new Map<Integer,String>{
            1=>'One', 2=>'Two', 3=>'Three', 4=>'Four', 5=>'Five' };
        rd.segmentTitleWord = titleMap.containsKey(n) ? titleMap.get(n) : String.valueOf(n);
 
        List<String> lens = isFm ? cmFlagValues(n, 'length')    : cmStadiumValues(p, n, 'length');
        List<String> thks = isFm ? cmFlagValues(n, 'thickness') : cmStadiumValues(p, n, 'thickness');
 
        String topDia = fmtDec(decVal(isFm ? 'fm_top_dia'    : p + 'top_dia',    0));
        String botDia = fmtDec(decVal(isFm ? 'fm_bottom_dia' : p + 'bottom_dia', 0));
 
        for (Integer i = 0; i < rd.segmentHeaders.size(); i++) {
            rd.segmentData.add(segCol(
                (i < lens.size()) ? lens[i] : '',
                (i < thks.size()) ? thks[i] : '',
                (i == 0) ? topDia : '',
                (i == rd.segmentHeaders.size() - 1) ? botDia : '',
                '', '', i + 1));
        }
 
        // Pricing
        String wKey, bKey, uKey, cKey;
        if (isFm) {
            wKey = 'fms_est_weight'; bKey = 'fms_base_price';
            uKey = 'fms_unit_price'; cKey = 'fms_unit_cost';
        } else if (p == 'mrl_') {
            wKey = 'mrl_man_riding_total_weight'; bKey = 'mrl_man_riding_base_price';
            uKey = 'mrl_man_riding_unit_price';   cKey = 'mrl_man_riding_unit_cost';
        } else {
            wKey = 'lwc_ladder_cage_weight';    bKey = 'lwc_ladder_cage_base_price';
            uKey = 'lwc_ladder_cage_unit_price'; cKey = 'lwc_ladder_cage_unit_cost';
        }
 
        Decimal segWt = decVal(wKey, 0);
        // Flag Mast PU Paint has no weight field, and this builder is only ever
        // invoked with 'mrl_'/'lwc_' anyway. Deepanjan (16th July 2026)
 
        rd.segmentPricing.add(lv('Segment Weight (kg)', fmtDec(segWt)));
        rd.segmentPricing.add(lv('Base Price',          fmtDec(decVal(bKey, 0))));
        rd.segmentPricing.add(lv('Unit Price',          fmtDec(decVal(uKey, 0))));
        rd.segmentPricing.add(lv('Unit Cost',           fmtDec(decVal(cKey, 0))));
 
        // Base plate + foundation
        String bpP = isFm ? 'fm_bp_' : p + 'bp_';
        String fbP = isFm ? 'fm_fb_' : p + 'fb_';
        rd.basePlateType    = 'Circular';
        rd.bpOD             = fmtNum(bpP + 'diameter');
        rd.bpThickness      = fmtNum(bpP + 'thickness');
        rd.pcd              = fmtNum(bpP + 'pcd');
        rd.anchorPlateThick = '';
        rd.fdnBoltDia       = sGet(fbP + 'diameter', '');
        rd.fdnBoltLength    = fmtNum(fbP + 'length');
        rd.fdnNoOfBolt      = fmtNum(fbP + 'no_of_bolt');
        rd.noOfNut          = '';
        rd.stiffnerThickness = '';
        rd.lRingType        = '';
        rd.ringDia          = '';
 
        Decimal fndWt = decVal(isFm ? 'fm_foundation_weight' : p + 'foundation_weight', 0);
        rd.totalWeightGI = fmtDec(segWt + fndWt);
 
        rd.showCosting       = false;   // Customized/Stadium: no KIT code -> hide costing block. Reetabrata (13th July 2026)
        rd.codeNoTitle       = variant;
        rd.costingGroupTitle = 'Costing - ' + variant;
        rd.costPerSet        = '0';
        rd.totalCostPrice    = '0';
 
        rowDataList.add(rd);
    }
    
    
    // ═══════════════════════════════════════════════════════════════
// MAN RIDING LIFT — KIT costing hook (reuses High Mast KIT logic)
// If a kit_line_N exists whose lm_mast_height matches this row's
// mast height, populate the same accessories/costing block the
// High Mast builder uses. If no KIT line exists, row is left
// exactly as addCustomizedRow() built it (showCosting = false).
// ═══════════════════════════════════════════════════════════════
private void applyKitCostingToCustomizedRow(RowData rd) {
    Integer kitLineNum = findKitLineForRow(rd.rowIndex, rd.mastHeight);
    String  kitPfx      = 'kit_line_' + kitLineNum + '_';
 
    // No KIT data for this row -> leave row untouched (no costing)
    if (!jd.containsKey(kitPfx + 'lm_mast_height')) return;
 
    Integer kitSeg = (Integer) decVal(kitPfx + 'no_of_segment_select', 0).intValue();
    if (kitSeg == 0) {
        try { kitSeg = Integer.valueOf(rd.noOfSegment); } catch (Exception ex) { kitSeg = 2; }
    }
 
    String accPfx;
    if      (kitSeg <= 1) accPfx = kitPfx + 'lm_';
    else if (kitSeg == 2) accPfx = kitPfx + 'lm_2_';
    else                  accPfx = kitPfx + 'lm_3_';
 
    rd.cfgQtyOfHM       = fmtNum(kitPfx + 'lm_qty_of_hm');
    rd.cfgMastHeight    = fmtNum(kitPfx + 'lm_mast_height');
    rd.cfgTypeOfLum     = sGet(kitPfx + 'lm_type_of_luminaries', '');
    rd.cfgNoOfLum       = sGet(kitPfx + 'lm_no_of_luminaries',   '');
    rd.cfgCgBox         = sGet(kitPfx + 'lm_cg_box_per_lum',     '');
    rd.cfgWeldedArm     = fmtNum(kitPfx + 'lm_type_of_welded_arm');
    rd.cfgSuspnSysm     = afterEq(sGet(kitPfx + 'lm_suspension_system', ''));
    rd.cfgCableType     = (sGet(kitPfx + 'lm_cable_type',  ''));
    rd.cfgNoOfCable     = (sGet(kitPfx + 'lm_no_of_cable', ''));
    rd.cfgTierLRing     = (sGet(kitPfx + 'lm_l_ring_tier', ''));
    rd.cfgRingVW        = (sGet(kitPfx + 'lm_type_of_ring_vw', ''));
    rd.cfgTypeOfWinch   = beforeEq(sGet(kitPfx + 'lm_type_of_winch',      ''));
    rd.cfgTypePowerTool = beforeEq(sGet(kitPfx + 'lm_type_of_power_tool', ''));
    rd.cfgTypeWireRope  = afterEq(sGet(kitPfx + 'lm_type_of_wire_rope',  ''));
    rd.cfgTypeOfAol     = sGet(kitPfx + 'lm_type_of_aol',           'X');
    rd.cfgNoOfAvnLight  = sGet(kitPfx + 'lm_no_of_aviation_light',  'X');
    rd.cfgFeederPillar  = sGet(kitPfx + 'lm_feeder_piller_control', 'X');
 
    if      (kitSeg == 1) { rd.codeNoTitle = 'Code No-01 (For 10M to 14M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 1 (10 to 14m)'; }
    else if (kitSeg == 2) { rd.codeNoTitle = 'Code No-02 (For 15M to 18M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 2 (15m to 18m)'; }
    else if (kitSeg >= 3) { rd.codeNoTitle = 'Code No-03 (For 21M to 30M)'; rd.costingGroupTitle = 'Costing Utkarsh Group 3 (21m to 30m)'; }
 
    rd.accessories = new List<AccessoryLineItem>();
    buildAccessories(rd, accPfx, kitPfx, kitSeg);   // same helper the High Mast builder uses
 
    rd.costPerSet = fmtDec(decVal(accPfx + 'kit_base_price', 0));
    Decimal grandTotal = 0;
    for (AccessoryLineItem ali : rd.accessories) grandTotal += ali.totalCostRaw;
    rd.totalCostPrice = fmtDec(grandTotal);
 
    rd.showCosting = true;   // only flip this on when a KIT line was actually found
}
 
    private List<String> cmHeaders(Integer n) {
        List<String> h = new List<String>();
        if (n <= 1) { h.add('Segment 1'); return h; }
        h.add('Top Seg');
        for (Integer i = 1; i <= n - 2; i++) h.add('Mid Seg ' + i);
        h.add('Bottom Seg');
        return h;
    }
 
    private List<String> cmStadiumValues(String p, Integer n, String attr) {
        // Stopped at mid4, so the weight sheet left Mid Seg 5 and Bottom Seg blank on a
        // 7-segment Stadium - cmHeaders(n) always emits n columns but this returned only 5
        // values. top + middles 2..n-1 + bottom => mid{k} whenever n >= k + 1.
        // Same fix as cmStadiumList in both offer controllers. Deepanjan (21st Aug 2026)
        List<String> keys = new List<String>();
        keys.add(p + 'top_segment_' + attr);
        if (n >= 3) keys.add(p + 'middle_segment_' + attr);          // middle_segment_ IS mid2
        for (Integer k = 3; k <= 14; k++) {
            if (n >= k + 1) keys.add(p + 'mid' + k + '_' + attr);
        }
        keys.add(p + 'bottom_' + attr);
        return cmValues(keys);
    }
 
    private List<String> cmFlagValues(Integer n, String attr) {
        List<String> keys = new List<String>();
        keys.add('fms_top_segment_' + attr);
        if (n >= 3) keys.add('fms_middle_segment_2_' + attr);
        if (n >= 4) keys.add('fms_middle_segment_3_' + attr);
        if (n >= 5) keys.add('fms_middle_segment_4_' + attr);
        if (n >= 2) keys.add('fms_bottom_segment_' + attr);
        return cmValues(keys);
    }
 
    private List<String> cmValues(List<String> keys) {
        List<String> out = new List<String>();
        for (String k : keys) out.add(fmtNum(k));
        return out;
    }
 
    private Boolean cmBoolK(String key) {
        if (jd == null || !jd.containsKey(key) || jd.get(key) == null) return false;
        Object v = jd.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim();
        return s.equalsIgnoreCase('true') || s == '1';
    }
 
    // ═══════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════
    private AccessoryLineItem accFromKeys(String sNo, String itemName, String descVal,
            String unitVal, String qKey, String cKey, Boolean isSub) {
        Decimal qty  = decVal(qKey, 0);
        Decimal cost = decVal(cKey, 0);
        return accRaw(sNo, itemName, descVal, unitVal, fmtQty(qty), fmtDec(cost), fmtQty(qty), isSub, cost == 0);
    }
 
    private AccessoryLineItem accRaw(String sNo, String itemName, String descVal,
            String unitVal, String qty, String cost, String tqty, Boolean isSub, Boolean isZeroFlag) {
        AccessoryLineItem r = new AccessoryLineItem();
        r.sNo = sNo; r.itemName = itemName; r.description = descVal; r.unit = unitVal;
        r.qtyConsumed = qty; r.totalCost = cost; r.totalQty = tqty;
        r.isSubItem = isSub; r.isZero = isZeroFlag; r.remarks = '';
        try { r.totalCostRaw = Decimal.valueOf(cost.replace(',', '')); }
        catch (Exception ex) { r.totalCostRaw = 0; }
        return r;
    }
 
    private SegmentCol segCol(String len, String thk, String oafTop, String oafBot,
            String ovlp, String lw, Integer idx) {
        SegmentCol sc = new SegmentCol();
        sc.length=len; sc.thickness=thk; sc.oafTop=oafTop; sc.oafBot=oafBot;
        sc.overlap=ovlp; sc.longWeld=lw; sc.segIndex=idx;
        return sc;
    }
 
    private LabelValue lv(String lbl, String val) {
        LabelValue lv2 = new LabelValue();
        lv2.label = lbl; lv2.value = val;
        return lv2;
    }
 
    private List<Object> getList(String key) {
        if (!jd.containsKey(key) || jd.get(key) == null) return new List<Object>();
        try { return (List<Object>) jd.get(key); }
        catch (Exception e) { return new List<Object>(); }
    }
 
    private String fmtDecM(Map<String,Object> m, String key, Decimal def) {
        if (!m.containsKey(key) || m.get(key) == null) return fmtDec(def);
        try {
            String s = String.valueOf(m.get(key)).trim();
            return String.isBlank(s) ? fmtDec(def) : fmtDec(Decimal.valueOf(s));
        } catch (Exception ex) { return fmtDec(def); }
    }
 
    private String sGetM(Map<String,Object> m, String key, String def) {
        if (!m.containsKey(key) || m.get(key) == null) return def;
        String v = String.valueOf(m.get(key)).trim();
        return String.isNotBlank(v) ? v : def;
    }
 
    // fmtNum with a fallback key: primary first, legacy second. Both go through the same
    // fmtNum so formatting is identical either way. Reetabrata (16th July 2026)
    private String fmtNumFb(String primaryKey, String legacyKey) {
        String v = fmtNum(primaryKey);
        return String.isNotBlank(v) ? v : fmtNum(legacyKey);
    }
 
    private String fmtNum(String key) {
        if (!jd.containsKey(key) || jd.get(key) == null) return '';
        String v = String.valueOf(jd.get(key)).trim();
        if (String.isBlank(v)) return '';
        try {
            Decimal d = Decimal.valueOf(v);
            if (d == d.setScale(0, RoundingMode.FLOOR)) return String.valueOf(d.longValue());
            return String.valueOf(d.setScale(2, RoundingMode.HALF_UP));
        } catch (Exception ex) { return v; }
    }
 
    // ═══════════════════════════════════════════════════════════════
// HIGH MAST WINCH DESCRIPTION — depends on Type of Winch (Q6/Q48/Q89)
// AND the segment group (1, 2, or 3+) since each group has its own
// gearbox rating table.
// ═══════════════════════════════════════════════════════════════
private String resolveWinchDescription(String winchTypeLetter, Integer kitSeg) {
    if (String.isBlank(winchTypeLetter)) return '';
 
    if (kitSeg <= 1) {
        if (winchTypeLetter == 'A') return 'GEAR BOX 500KG,50:1,3 in';
        if (winchTypeLetter == 'B') return 'GEAR BOX 750 KG,50:1, 3½ in';
        if (winchTypeLetter == 'C') return 'GEAR BOX 750KG,50:1,3½ in';
        if (winchTypeLetter == 'D') return 'GEAR BOX 1500KG,50:1,3½ in';
        if (winchTypeLetter == 'E') return 'GEAR BOX 350KG,50:1,3 in';
        if (winchTypeLetter == 'X') return 'NA';
    } else if (kitSeg == 2) {
        if (winchTypeLetter == 'A') return 'GEAR BOX 350KG,50:1,3 in';
        if (winchTypeLetter == 'B') return 'GEAR BOX 500KG,50:1,3 in';
        if (winchTypeLetter == 'C') return 'GEAR BOX 750KG,50:1,3½ in';
        if (winchTypeLetter == 'D') return 'GEAR BOX 600KG,50:1,3½ in';
        if (winchTypeLetter == 'X') return 'NA';
    } else { // kitSeg >= 3
        if (winchTypeLetter == 'A') return 'GEAR BOX 500KG,50:1,3 in';
        if (winchTypeLetter == 'B') return 'GEAR BOX 750 KG,50:1, 3½ in';
        if (winchTypeLetter == 'C') return 'GEAR BOX 750KG,50:1,3½ in';
        if (winchTypeLetter == 'D') return 'GEAR BOX 1500KG,50:1,3½ in';
        if (winchTypeLetter == 'E') return 'GEAR BOX 1000KG,50:1,3½ in';
        if (winchTypeLetter == 'F') return 'GEAR BOX 600KG,50:1,3½ in';
        if (winchTypeLetter == 'X') return 'NA';
    }
    return '';
}
    // ═══════════════════════════════════════════════════════════════════════
    // SIGNAGE MAST - CUSTOM NAME  (Deepanjan, 18th Aug 2026)
    //
    // Mirrors signageMastName() in HighMastSOWController / HMScopeCombinedController
    // so the weight sheet and the two offer PDFs never print different names. Reads
    // the same sm_rename / sm_rename_value pair the estimator saves (YES/NO picklist plus
    // the text that opens on YES), read through sGet like every other quote-level key.
    //
    // No weight, formula or row is affected - isSignageMast stays true and every
    // calculation runs exactly as today. Not ticked, blank, or a legacy quote with
    // no key returns 'Signage Mast', so existing sheets are byte-identical.
    // ═══════════════════════════════════════════════════════════════════════
    private String signageMastTitle() {
        if (!isSignageMast) return 'Signage Mast';
        if (!'YES'.equalsIgnoreCase(sGet('sm_rename', 'NO'))) return 'Signage Mast';
        String nm = sGet('sm_rename_value', '');
        return String.isBlank(nm) ? 'Signage Mast' : nm.trim();
    }

    private String sGet(String key, String defaultVal) {
        if (!jd.containsKey(key) || jd.get(key) == null) return defaultVal;
        String v = String.valueOf(jd.get(key)).trim();
        return String.isNotBlank(v) ? v : defaultVal;
    }
 
    private Decimal decVal(String key, Decimal defaultVal) {
        if (!jd.containsKey(key) || jd.get(key) == null) return defaultVal;
        try {
            String s = String.valueOf(jd.get(key)).trim();
            return String.isBlank(s) ? defaultVal : Decimal.valueOf(s);
        } catch (Exception ex) { return defaultVal; }
    }
 
    private String beforeEq(String rawVal) {
        if (String.isBlank(rawVal)) return '';
        return rawVal.contains('=') ? rawVal.substringBefore('=').trim() : rawVal.trim();
    }
 
    private String afterEq(String rawVal) {
        if (String.isBlank(rawVal)) return rawVal;
        return rawVal.contains('=') ? rawVal.substringAfter('=').trim() : rawVal.trim();
    }
 
    private String fmtDec(Decimal val) {
        if (val == null) return '0';
        if (val == val.setScale(0, RoundingMode.FLOOR)) return String.valueOf(val.longValue());
        return String.valueOf(val.setScale(2, RoundingMode.HALF_UP));
    }
 
    private String fmtQty(Decimal val) {
        if (val == null || val == 0) return '0';
        if (val == val.setScale(0, RoundingMode.FLOOR)) return String.valueOf(val.longValue());
        return String.valueOf(val.setScale(1, RoundingMode.HALF_UP));
    }
    
    
    // Custom Lighting Pole saves its spec fields with a cus_op_ infix
// (c1_s1_cus_op_height_of_pole) while Lighting Pole / Mid Hinge save them bare
// (c1_s1_height_of_pole). Bare key wins when present, so every existing quote
// resolves exactly as before; the cus_op_ form is only tried as a second pass.
private String lpAttr(String cs, String attr) {
    if (jd.containsKey(cs + attr))              return cs + attr;
    if (jd.containsKey(cs + 'cus_op_' + attr))  return cs + 'cus_op_' + attr;
    return cs + attr;
}
    
 
 
    // ═══════════════════════════════════════════════════════════════
    // INNER CLASSES
    // ═══════════════════════════════════════════════════════════════
    public class TransmissionPoleData {
        public Integer rowIndex          { get; set; }
        public String  itemName          { get; set; }
        public String  weight            { get; set; }
        public String  quantity          { get; set; }
        public String  unitPrice         { get; set; }
        public String  unitCost          { get; set; }
        public String  poleType          { get; set; }
        public String  height            { get; set; }
        public String  topDia            { get; set; }
        public String  botDia            { get; set; }
        public String  noOfSides         { get; set; }
        public String  segLength         { get; set; }
        public String  thickness         { get; set; }
        public String  bearingPlateType  { get; set; }
        public String  bpSize            { get; set; }
        public String  bpThickness       { get; set; }
        public String  poleCabDia        { get; set; }
        public String  poleCabThickness  { get; set; }
        public String  dan               { get; set; }
        public String  note              { get; set; }
        public String  extraMicron       { get; set; }
        public String  realization       { get; set; }
    }
 
 	public class FmItemRow {
        public String  slNo      { get; set; }
        public String  itemName  { get; set; }
        public String  quantity  { get; set; }
        public String  rate      { get; set; }
        public String  amount    { get; set; }
        public Decimal amountRaw { get; set; }
    }
 
    public class MidHingePoleData {
        public Integer rowIndex      { get; set; }
        public String  itemName      { get; set; }
        public Boolean isFoundation  { get; set; }
        public Boolean isBracket     { get; set; }
        public Boolean isAccessories { get; set; }
        public String  weight        { get; set; }
        public String  quantity      { get; set; }
        public String  unitPrice     { get; set; }
        public String  unitCost      { get; set; }
        public String  poleType      { get; set; }
        public String  height        { get; set; }
        public String  topDia        { get; set; }
        public String  botDia        { get; set; }
        public String  segTopLen     { get; set; }
        public String  segBotLen     { get; set; }
        public String  segTopThk     { get; set; }
        public String  segBotThk     { get; set; }
        public String  overlap       { get; set; }
        public String  noOfSides     { get; set; }
        public String  basePlateType { get; set; }
        public String  bpSize        { get; set; }
        public String  bpThickness   { get; set; }
        public String  stiffener     { get; set; }
        public String  doorHeight    { get; set; }
        public String  boltDia       { get; set; }
        public String  boltLength    { get; set; }
        public String  boltQty       { get; set; }
        public String  pcd           { get; set; }
        public String  template      { get; set; }
        public String  extraMicron   { get; set; }
        public String  puPaint       { get; set; }
        public String  bracketType   { get; set; }
        public String  typeOfArm     { get; set; }
        public String  armLength     { get; set; }
        public String  armDia        { get; set; }
        public String  sleeveDia    { get; set; }
        public String  sleeveLength { get; set; }
        public Integer colNum        { get; set; }
        public String  accessoryName { get; set; }
        public String  accessoryRate { get; set; }
        public String  accessoryTotalWeight { get; set; }
    }
 
    public class LightingPoleData {
        public Integer rowIndex      { get; set; }
        public String  itemName      { get; set; }
        public Boolean isFoundation  { get; set; }
        public Boolean isBracket     { get; set; }
        public String  weight        { get; set; }
        public String  quantity      { get; set; }
        public String  unitPrice     { get; set; }
        public String  unitCost      { get; set; }
        public String  poleType      { get; set; }
        public String  height        { get; set; }
        public String  topDia        { get; set; }
        public String  botDia        { get; set; }
        public String  segLength     { get; set; }
        public String  thickness     { get; set; }
        public String  noOfSides     { get; set; }
        public String  basePlateType { get; set; }
        public String  bpSize        { get; set; }
        public String  bpThickness   { get; set; }
        public String  stiffener     { get; set; }
        public String  doorHeight    { get; set; }
        public String  boltDia       { get; set; }
        public String  boltLength    { get; set; }
        public String  boltQty       { get; set; }
        public String  pcd           { get; set; }
        public String  template      { get; set; }
        public String  extraMicron   { get; set; }
        public String  puPaint       { get; set; }
        public String  solarStructure{ get; set; }
        public String  batteryBox    { get; set; }
        public String  bracketType   { get; set; }
        public String  typeOfArm     { get; set; }
        public String  armLength     { get; set; }
        public String  armDia        { get; set; }
        public String  sleeveDia    { get; set; }
        public String  sleeveLength { get; set; }
        public Boolean hasBracket    { get; set; }
    	public String  bracketWeight { get; set; }
        public Integer colNum        { get; set; }
        public Integer sectionNum    { get; set; }
        public Boolean isTwoSegment  { get; set; }
        public String  foundationWeight { get; set; }
        public String  totalWeightGI { get; set; }
        public String  segLengthTop  { get; set; }
        public String  segLengthBot  { get; set; }
        public String  thicknessTop  { get; set; }
        public String  thicknessBot  { get; set; }
        public String  overlapLen    { get; set; }
    }
 
    public class RowData {
        // Signage Mast only, and only on the FIRST mast row - left null everywhere else, so
        // every other row and every other mast type keeps rendering exactly the rows it
        // always did. Reetabrata (16th July 2026)
        public String  additionalWeight { get; set; }
        // Custom Lightning Mast only - the Special Additions sentence, identical to the one
        // printed on the Single / Combined Scope because both come from the same shared
        // helper. Blank for every other mast type, so their rows render unchanged.
        // Faizan (24th July 2026)
        public String  specialAdditionsNote { get; set; }
        // LCLM only - blank for every other mast type, so their rows stay hidden.
        // Reetabrata (15th July 2026)
        public String  spikeLength   { get; set; }
        public String  spikeWeight   { get; set; }
        public String  dcWeight      { get; set; }
        public Boolean showCosting      { get; set; }   // false for Segment Above 5 (any type) - no KIT costing. Reetabrata (13th July 2026)
        public Integer rowIndex         { get; set; }
        public String  mastHeight       { get; set; }
        public String  noOfSegment      { get; set; }
        public String  noOfSides        { get; set; }
        public String  segmentTitleWord { get; set; }
        public List<String>            segmentHeaders  { get; set; }
        public List<SegmentCol>        segmentData     { get; set; }
        public List<LabelValue>        segmentPricing  { get; set; }
        public List<AccessoryLineItem> accessories     { get; set; }
        public String basePlateType     { get; set; }
        public String bpOD              { get; set; }
        public String bpThickness       { get; set; }
        public String pcd               { get; set; }
        public String anchorPlateThick  { get; set; }
        public String fdnBoltDia        { get; set; }
        public String fdnBoltLength     { get; set; }
        public String fdnNoOfBolt       { get; set; }
        public String noOfNut           { get; set; }
        public String stiffnerThickness { get; set; }
        public String lRingType         { get; set; }
        public String ringDia           { get; set; }
        public String totalWeightGI     { get; set; }
        public String cfgQtyOfHM        { get; set; }
        public String cfgMastHeight     { get; set; }
        public String cfgTypeOfLum      { get; set; }
        public String cfgNoOfLum        { get; set; }
        public String cfgCgBox          { get; set; }
        public String cfgWeldedArm      { get; set; }
        public String cfgSuspnSysm      { get; set; }
        public String cfgCableType      { get; set; }
        public String cfgNoOfCable      { get; set; }
        public String cfgTierLRing      { get; set; }
        public String cfgRingVW         { get; set; }
        public String cfgTypeOfWinch    { get; set; }
        public String cfgTypePowerTool  { get; set; }
        public String cfgTypeWireRope   { get; set; }
        public String cfgTypeOfAol      { get; set; }
        public String cfgNoOfAvnLight   { get; set; }
        public String cfgFeederPillar   { get; set; }
        public String codeNoTitle       { get; set; }
        public String costingGroupTitle { get; set; }
        public String costPerSet        { get; set; }
        public String totalCostPrice    { get; set; }
        
        // Adding variable to create addition/accessory details for each mast.
        public String rowPrefix { get; set; }

        public List<FmItemRow> fmAccessoryList  { get; set; }
        public List<FmItemRow> fmAdditionalList { get; set; }
        public String          fmAcTotal        { get; set; }
        public String          fmAddTotal       { get; set; }
        public Boolean hasFmAccessory  { get; set; }
        public Boolean hasFmAdditional { get; set; }

        public RowData() {
            rowPrefix        = '';
            fmAccessoryList  = new List<FmItemRow>();
            fmAdditionalList = new List<FmItemRow>();
            fmAcTotal        = '0';
            fmAddTotal       = '0';
        }
    }
 
    public class SegmentCol {
        public String  length    { get; set; }
        public String  thickness { get; set; }
        public String  oafTop    { get; set; }
        public String  oafBot    { get; set; }
        public String  overlap   { get; set; }
        public String  longWeld  { get; set; }
        public Integer segIndex  { get; set; }
    }
 
    public class LabelValue {
        public String label { get; set; }
        public String value { get; set; }
    }
 
    public class AccessoryLineItem {
        public String  sNo          { get; set; }
        public String  itemName     { get; set; }
        public String  description  { get; set; }
        public String  unit         { get; set; }
        public String  qtyConsumed  { get; set; }
        public String  totalCost    { get; set; }
        public String  totalQty     { get; set; }
        public Decimal totalCostRaw { get; set; }
        public Boolean isSubItem    { get; set; }
        public Boolean isZero       { get; set; }
        public String  remarks      { get; set; }
    }
 


 
}