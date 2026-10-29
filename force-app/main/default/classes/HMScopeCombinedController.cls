public class HMScopeCombinedController {

                                                 public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
 
    public String soWRef          { get; set; }
    public String soWDate         { get; set; }
    public String opportunityName { get; set; }
    public String buyerName       { get; set; }
    public String buyerAddress    { get; set; }
    public String deliveryAddress { get; set; }
    public String todayDate       { get; set; }
    public String  deliveryScheduleUnit   { get; set; }
    public String  transportationType  { get; set; }
    public String deliverytime { get; set; }
    public String priceVariationdays { get; set; }
    public String quationValidity { get; set; }
    public String warrFromDOC { get; set; }
    public String warrFromDOD { get; set; }

    public List<MastGroupWrapper> mastGroups { get; set; }

    /* ANNEXURE GROUPING - one entry per line item (product), each carrying its own rows
       and its own sub-total. mastGroups is left exactly as it was, so anything else that
       reads it is untouched; the page now repeats over productGroups instead.
       Deepanjan (18th August 2026) */
    public List<ProductGroupWrapper> productGroups { get; set; }

    // Mast/pole name for the SUB-TOTAL heading, and the accessories clause label.
    // Held here instead of in the page's IF() chains so the Signage Mast custom name
    // reaches them. Both keep the exact spacing the page used. Deepanjan (18th Aug 2026)
    public String mastTypeLabel    { get; set; }
    public String accessoriesLabel { get; set; }

    /* Index into mastGroups where each Customized Mast product starts. Stadium calls the
       builder once per prefix (mrl_ / lwc_) and Flag once per row, and each call can add
       several groups - this is what tells the collapse where one product ends and the
       next begins. Deepanjan (18th August 2026) */
    private List<Integer> cmProductStart = new List<Integer>();
    
    public String typeOfMast          { get; set; }
    public Boolean isLightingPole     { get; set; }
    public Boolean isTransmissionPole { get; set; }
    public Boolean isMidHingePole     { get; set; }
    public Boolean isCustomizedMast   { get; set; }
    public Boolean isStadiumMast      { get; set; }
    public Boolean isFlagMast         { get; set; }
    // SEGMENT ABOVE 5 - FLAG MAST: rows save r{n}_lm_* (LM engine) plus the flag
    // annexure grids, so it needs its own builder. Deepanjan (22nd July 2026)
    public Boolean isSeg5FlagMast     { get; set; }
    // TRUE when type_of_mast = 'Segment Above 5', whatever sub-mast is chosen under
    // it. Segment Above 5 is the only recipe with a TOTAL PRICE (/KG) field and the
    // only one with Special Items, so anything that must apply ONLY to it is gated
    // on this rather than on the presence of a key. Deepanjan (19th Aug 2026)
    public Boolean isSegmentAbove5    { get; set; }
    // Lightning Cum Lighting Mast. Its saved JSON is the Lighting Mast shape (same lm_* keys),
    // so it deliberately keeps using the existing High Mast builder; only the mast name and the
    // arrestor phrase differ. Reetabrata (15th July 2026)
    public Boolean isLCLM             { get; set; }
    // Signage Mast. Its own Section_Logic record, but the saved JSON is the Lighting Mast
    // shape (same lm_* keys), so it keeps using the existing High Mast builder. Only the
    // Additional Details clause is new. Reetabrata (16th July 2026)
    public Boolean isSignageMast      { get; set; }
    // Latching Mast. Own Section_Logic + own Blueprint (L-Ring/Head Frame weight removed
    // there, not here), but the saved JSON is the Lighting Mast shape (same lm_* keys), so
    // it keeps using the existing High Mast builder. Reetabrata (16th July 2026)
    public Boolean isLatchingMast     { get; set; }
    // Custom Lightning Mast. Own Section_Logic + own Blueprint record, but the saved JSON is
    // the Lighting Mast shape (same lm_* keys, same r{n}_ row prefixes), so it keeps using
    // the existing High Mast builder. The ONLY difference is the Special Additions sentence
    // appended to the mast description, built by the SHARED helper in HighMastSOWController
    // so Single Scope and Combined Scope can never print different text. Faizan (24th July 2026)
    public Boolean isCustomLightningMast { get; set; }

    public Boolean perPolfrieght   {get; set;}
    public Decimal perPolTPCharg   {get; set;}
 
    public String subTotalUnitRate { get; set; }
    public String subTotalGST      { get; set; }
    public String subTotalUnit     { get; set; }
    public String subTotalAmount   { get; set; }
    public String grandTotal       { get; set; }
    public String grandTotalWords  { get; set; } 

    // User Session Metadata
    public String loggedInUser { get; set; }
    public String loggedInUserPhone { get; set; }
    public String loggedInUserTitle { get; set; }
    public String loggedInUserEmail { get; set; }
    
 
    private static final Integer MAX_REPEATER_COLS = 10;
 
    public HMScopeCombinedController(ApexPages.StandardController stdController) {
 
        todayDate          = Date.today().format();
        soWDate            = Date.today().format();
        soWRef             = 'UIL/HM/26-27/001';
        buyerName          = '';
        buyerAddress       = '';
        deliveryAddress    = '';
        opportunityName    = '';
        jsonData           = new Map<String, Object>();
        mastGroups         = new List<MastGroupWrapper>();
        productGroups      = new List<ProductGroupWrapper>();
        mastTypeLabel      = ' LIGHTING MAST';                              // Deepanjan (18th Aug 2026)
        accessoriesLabel   = 'Supply of LIGHTING MAST ACCESSORIES PART: ';  // Deepanjan (18th Aug 2026)
        isLightingPole     = false;
        isTransmissionPole = false;
        isMidHingePole     = false;
        isCustomizedMast   = false;
        isStadiumMast      = false;
        isFlagMast         = false;
        isSeg5FlagMast     = false;   // Deepanjan (22nd July 2026)
        isSegmentAbove5    = false;   // Deepanjan (19th Aug 2026)
        isLCLM             = false;   // Reetabrata (15th July 2026)
        isSignageMast      = false;   // Reetabrata (16th July 2026)
        isLatchingMast     = false;   // Reetabrata (16th July 2026)
        isCustomLightningMast = false;   // Faizan (24th July 2026)
        subTotalUnitRate   = '0';
        subTotalGST        = '0';
        subTotalUnit       = '0';
        subTotalAmount     = '0';
        grandTotal         = '0';
        grandTotalWords    = 'Zero Only';
 
        List<Quote> quoteList = [
            SELECT  Id, Name, QuoteNumber,Quote_Reference__c,
                    Account.Name,
                    Account.BillingStreet,
                    Account.BillingCity,
                    Account.BillingState,
                    Account.BillingPostalCode,
                    Opportunity.Name,
                    Contact.Name,
                    Contact.Phone,
                    Contact.Email,
                    Quote_Value__c
            FROM    Quote
            WHERE   Id = :stdController.getId()
            LIMIT   1
        ];
 
        if (quoteList.isEmpty()) return;
        quoteRecord = quoteList[0];
 
        soWRef          = String.isNotBlank(quoteRecord.Quote_Reference__c)
                            ? quoteRecord.Quote_Reference__c : 'UIL/HM/26-27/001';
        buyerName       = quoteRecord.Account != null
                            ? quoteRecord.Account.Name : '';
        //buyerAddress    = buildAddress(quoteRecord.Account);
        opportunityName = quoteRecord.Opportunity != null
                            ? quoteRecord.Opportunity.Name : '';
 
        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jsonData = (Map<String, Object>)
                    JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
            } catch (Exception e) {
                System.debug('JSON Parse Error: ' + e.getMessage());
            }
        }
        Boolean useShippingAddress = jsonData.get('override_existing_address') == true;
        buyerAddress = buildAddress(jsonData, 'def_');
        deliveryAddress = buildAddress(jsonData, useShippingAddress ? 'ovr_' : 'def_');
        String deliverydays = strVal(jsonData, 'tc_del_schedule', '30');
        String deliveryUnit = strVal(jsonData, 'tc_del_schedule_in', 'Days');
        deliverytime = deliverydays + ' ' + deliveryUnit;

        priceVariationdays = strVal(jsonData, 'tc_price_variation', '30');
        quationValidity = strVal(jsonData, 'tc_quot_validity', '5');
        String warrantyFromDoc = strVal(jsonData, 'tc_comm_months', '12');
        String warrantyFromDod = strVal(jsonData, 'tc_del_months', '18');
        warrFromDOC = warrantyFromDoc + ' ('+ CurrencyInWords.convertNumberOnly(Decimal.valueOf(warrantyFromDoc)) + ')';
        warrFromDOD = warrantyFromDod + ' ('+ CurrencyInWords.convertNumberOnly(Decimal.valueOf(warrantyFromDod)) + ')';
        
        String mastStd = strVal(jsonData, 'mast_standard', '');
        if (String.isBlank(mastStd)) {
            mastStd = strVal(jsonData, 'mast_standard_pole', '');
        }
        String mastStdLower = mastStd.toLowerCase();
        
        // Check for Custom Lighting Pole FIRST (before regular lighting pole)
        Boolean isCustomLightingPole = mastStdLower.contains('custom lighting pole') || 
                                       (mastStdLower.contains('custom') && mastStdLower.contains('lighting'));
        
        isLightingPole     = mastStdLower.contains('lighting pole') && !isCustomLightingPole;
        isTransmissionPole = mastStdLower.contains('transmission pole');
        isMidHingePole     = mastStdLower.contains('mid hinge');
 
        String cmType   = strVal(jsonData, 'type_of_mast',    '');
        String cmCustom = strVal(jsonData, 'mast_customized', '');
        // Segment Above 5 saves the sub-mast under seg5_mast_type instead of
        // mast_customized, and type_of_mast = 'Segment Above 5'. Treat it as the
        // same Customized/Stadium shape - identical mrl_/lwc_ fields. Reetabrata (13th July 2026)
        String cmSeg5   = strVal(jsonData, 'seg5_mast_type', '');
        Boolean isSeg5  = cmType.equalsIgnoreCase('Segment Above 5');
        if (String.isBlank(cmCustom) && isSeg5) cmCustom = cmSeg5;
        isStadiumMast    = cmCustom.equalsIgnoreCase('STADIUM MAST');
        isFlagMast       = cmCustom.equalsIgnoreCase('FLAG MAST');
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
        // still falls through to buildHighMastGroups(). Reetabrata (16th July 2026)
        isSignageMast    = cmType.equalsIgnoreCase('Signage Mast');
        // Latching Mast is a top-level type_of_mast value only - not offered under Segment
        // Above 5, so cmCustom is never 'Latching Mast'. mast_standard / mast_customized stay
        // blank for it, so the routing below is untouched and it still falls through to
        // buildHighMastGroups(). Reetabrata (16th July 2026)
        isLatchingMast   = cmType.equalsIgnoreCase('Latching Mast');
        // Custom Lightning Mast is a top-level type_of_mast value only - it is not offered
        // under Segment Above 5, so cmCustom is never 'Custom Lightning Mast'. mast_standard
        // and mast_customized both stay blank for it, so the routing below is untouched and
        // it still falls through to buildHighMastGroups(). Both spellings are accepted
        // because the picklist label has been written each way. Faizan (24th July 2026)
        isCustomLightningMast = cmType.equalsIgnoreCase('Custom Lightning Mast')
                                || cmType.equalsIgnoreCase('Custom Lighting Mast');
        isCustomizedMast = (isStadiumMast || isFlagMast)
                           && (cmType.equalsIgnoreCase('Customized Mast') || isSeg5);

        // SUB-TOTAL heading and accessories label, in the same order the page's IF()
        // chains used, so no quote changes except a renamed Signage Mast.
        // Deepanjan (18th Aug 2026)
        // A Custom Lighting Pole sets isCustomLightingPole and CLEARS isLightingPole, so it
        // used to fall all the way through to the default and print "SUB-TOTAL OF LIGHTING
        // MAST". It gets its own heading now; Standard Lighting Pole, Transmission, Mid
        // Hinge and every mast type keep exactly the heading they print today.
        // Deepanjan (24th Aug 2026)
        // The extra contains('pole') guard: isCustomLightingPole above uses a loose
        // (custom && lighting) test that is also true for a "Custom Lighting Mast". Routing
        // keeps that behaviour untouched; only this HEADING is narrowed to real poles, so a
        // Custom Lighting Mast still prints exactly what it prints today.
        // Deepanjan (24th Aug 2026)
        mastTypeLabel = (isCustomLightingPole && mastStdLower.contains('pole')) ? ' CUSTOM LIGHTNING POLE'
                      : isTransmissionPole ? ' TRANSMISSION POLE'
                      : isLightingPole     ? ' LIGHTING POLE'
                      : isStadiumMast      ? ' STADIUM MAST'
                      : isFlagMast         ? ' FLAG MAST'
                      : isLCLM             ? ' LCLM'
                      : isSignageMast      ? ' ' + signageMastName()
                      : isLatchingMast     ? ' LATCHING MAST'
                                           : ' LIGHTING MAST';

        accessoriesLabel = (isLightingPole || isMidHingePole || isCustomLightingPole)
                             ? ''
                         : isLCLM         ? 'Supply of LCLM ACCESSORIES PART: '
                         : isSignageMast  ? 'Supply of ' + signageMastName() + ' ACCESSORIES PART: '
                         : isLatchingMast ? 'Supply of LATCHING MAST ACCESSORIES PART: '
                                          : 'Supply of LIGHTING MAST ACCESSORIES PART: ';
        // SEGMENT ABOVE 5 - FLAG MAST keeps isCustomizedMast true (same dispatch),
        // but the flag branch must use the LM-keyed builder, not cmFlagGroups().
        // Deepanjan (22nd July 2026)
        isSeg5FlagMast = isSeg5 && isFlagMast;
        isSegmentAbove5 = isSeg5;   // Deepanjan (19th Aug 2026)
        // Segment Above 5: the accessories string itself now starts "Supply of <h> MTR ... PART:"
        // (see buildAccessoriesDesc), so the page must not print the label in front of it.
        // Deepanjan (7th September 2026)
        if (isSeg5) accessoriesLabel = '';
        
        Decimal gstPct  = 18;
        String  freight = strVal(jsonData, 'freight_incoterms', 'Ex-works');
        transportationType = freight;

        perPolfrieght = false;
        perPolTPCharg = 0;
        String  transAs = strVal(jsonData, 'transportation_as', null);
        if(freight == 'F.O.R (Freight on Road)' && transAs =='Per pole/Mast'){
            perPolfrieght = true;
            perPolTPCharg = decVal(jsonData, 'transportation_charges', 0);
        }

        System.debug('custom Lighting pole: '+ isCustomLightingPole +' | Customized Mast : '+ isCustomizedMast + ' | Custom Lightning Mast : '+ isCustomLightningMast);
        
        User currentUser = [SELECT Id, Name, Email, MobilePhone, Title FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        loggedInUser = currentUser.Name;
        loggedInUserPhone = String.isNotBlank(currentUser.MobilePhone) ? currentUser.MobilePhone : 'N/A';
        loggedInUserTitle = String.isNotBlank(currentUser.Title) ? currentUser.Title : 'N/A';
        loggedInUserEmail = String.isNotBlank(currentUser.Email) ? currentUser.Email : 'N/A';
        
        if(isCustomLightningMast){
            isCustomLightingPole = false;
        }
 
        if (isCustomizedMast) {
            buildCustomizedMastGroups(jsonData, gstPct, freight);
        }else if (isCustomLightingPole) {
            buildLightingPoleGroups(jsonData, gstPct, freight);
        } else if (isLightingPole) {
            buildLightingPoleGroups(jsonData, gstPct, freight);
        } else if (isTransmissionPole) {
            buildTransmissionPoleGroups(jsonData, gstPct, freight);
        } else if (isMidHingePole) {
            buildMidHingePoleGroups(jsonData, gstPct, freight);
        } else {
            buildHighMastGroups(jsonData, gstPct, freight);
        }
 
        buildProductGroups();

        Decimal sumUR = 0, sumGST = 0, sumUnit = 0, sumTotal = 0;
        for (MastGroupWrapper g : mastGroups) {
            sumUR    += g.unitRateRaw.setScale(2, RoundingMode.HALF_UP);
            sumGST   += g.gstAmountRaw.setScale(2, RoundingMode.HALF_UP);
            sumUnit  += g.unitAmountRaw.setScale(2, RoundingMode.HALF_UP);
            sumTotal += g.totalAmountRaw;
        }
        subTotalUnitRate = formatINR(sumUR);
        subTotalGST      = formatINR(sumGST);
        subTotalUnit     = formatINR(sumUnit);
        subTotalAmount   = formatINR(sumTotal);
        grandTotal       = formatINR(sumTotal);
        grandTotalWords  = amountInWords(sumTotal);
 
        ensureKey('freight_incoterms', 'Ex-works');
    }
 
    // ═══════════════════════════════════════════════════════════════
    //  BUILD FROM APEX LINES / TABLE ROWS (for Custom Lighting Pole)
    // ═══════════════════════════════════════════════════════════════
   private void buildFromApexLines(Map<String,Object> m, Decimal gstPct, String freight) {
    Integer slCounter = 1;
    
    // Map to group items by Item number
    Map<Integer, Map<String, Object>> groupedItems = new Map<Integer, Map<String, Object>>();
    
    List<Object> apexLines = getList(m, '_Final_Apex_Lines');
    List<Object> sourceLines = apexLines;
    
    if (sourceLines.isEmpty()) {
        sourceLines = getList(m, '_Saved_Table_Rows');
    }
    
    if (!sourceLines.isEmpty()) {
        for (Object lineObj : sourceLines) {
            Map<String, Object> line = (Map<String, Object>) lineObj;
            String itemName = strVal(line, 'name', 'Item');
            
            // Extract Item number from name
            Integer itemNum = 1;
            Pattern pItem = Pattern.compile('\\(Item\\s*(\\d+)\\)');
            Matcher mItem = pItem.matcher(itemName);
            if (mItem.find()) {
                try { itemNum = Integer.valueOf(mItem.group(1)); } catch (Exception ex) {}
            }
            
            // Custom Lighting Pole saves BOTH pole designs under "(Item 1)"; only the
            // section suffix tells them apart. Keying on itemNum alone made the second
            // design OVERWRITE the first in this map - one group, one pole, wrong qty.
            // groupKey = itemNum*10 + section keeps the natural 1.1, 1.2, 2.1 ordering
            // and collapses to today's behaviour whenever the section never varies.
            // Deepanjan (20th Aug 2026)
            Integer secIdx   = sectionIndexOf(itemName);
            Integer groupKey = itemNum * 10 + secIdx;

            if (!groupedItems.containsKey(groupKey)) {
                groupedItems.put(groupKey, new Map<String, Object>());
                groupedItems.get(groupKey).put('itemNum', itemNum);
                groupedItems.get(groupKey).put('secIdx',  secIdx);
                groupedItems.get(groupKey).put('qty', 0);
                groupedItems.get(groupKey).put('unitPrice', 0);
                groupedItems.get(groupKey).put('weight', 0);
                groupedItems.get(groupKey).put('poleName', '');
                groupedItems.get(groupKey).put('foundationName', '');
                groupedItems.get(groupKey).put('bracketName', '');
                groupedItems.get(groupKey).put('polePrice', 0);
                groupedItems.get(groupKey).put('foundationPrice', 0);
                groupedItems.get(groupKey).put('bracketPrice', 0);
                groupedItems.get(groupKey).put('poleWeight', 0);
                groupedItems.get(groupKey).put('foundationWeight', 0);
                groupedItems.get(groupKey).put('bracketWeight', 0);
                groupedItems.get(groupKey).put('description', '');
                groupedItems.get(groupKey).put('boltDescription', '');
                groupedItems.get(groupKey).put('bracketDescription', '');
            }
            
            Map<String, Object> groupMap = groupedItems.get(groupKey);
            Decimal qty = decVal(line, 'quantity', 1);
            Decimal unitPrice = decVal(line, 'unitPrice', 0);
            Decimal weight = decVal(line, 'weight', 0);
            
            // Determine item type and store in appropriate fields
            if (itemName.containsIgnoreCase('Foundation')) {
                groupMap.put('foundationPrice', unitPrice);
                groupMap.put('foundationWeight', weight);
                groupMap.put('foundationName', itemName);
                // Use the same quantity as pole
                if (groupMap.get('qty') == null || (Decimal)groupMap.get('qty') == 0) {
                    groupMap.put('qty', qty);
                }
            } else if (itemName.containsIgnoreCase('Bracket') || itemName.containsIgnoreCase('Arm')) {
                groupMap.put('bracketPrice', unitPrice);
                groupMap.put('bracketWeight', weight);
                groupMap.put('bracketName', itemName);
                if (groupMap.get('qty') == null || (Decimal)groupMap.get('qty') == 0) {
                    groupMap.put('qty', qty);
                }
            } else {
                // Pole item
                groupMap.put('polePrice', unitPrice);
                groupMap.put('poleWeight', weight);
                groupMap.put('poleName', itemName);
                groupMap.put('qty', qty);
            }
        }
        
        // Now build combined rows from grouped items
        List<Integer> sortedKeys = new List<Integer>(groupedItems.keySet());
        sortedKeys.sort();
        
        for (Integer groupKey : sortedKeys) {
            Map<String, Object> groupMap = groupedItems.get(groupKey);
            Integer itemNum = (Integer) groupMap.get('itemNum');
            Integer secIdx  = (Integer) groupMap.get('secIdx');
            if (itemNum == null) itemNum = 1;
            if (secIdx  == null) secIdx  = 1;
            
            Decimal polePrice = (Decimal)groupMap.get('polePrice');
            Decimal foundationPrice = (Decimal)groupMap.get('foundationPrice');
            Decimal bracketPrice = (Decimal)groupMap.get('bracketPrice');
            Decimal qty = (Decimal)groupMap.get('qty');
            if (qty == null || qty == 0) qty = 1;
            
            Decimal poleWeight = (Decimal)groupMap.get('poleWeight');
            Decimal foundationWeight = (Decimal)groupMap.get('foundationWeight');
            Decimal bracketWeight = (Decimal)groupMap.get('bracketWeight');
            
            String poleName = (String)groupMap.get('poleName');
            String foundationName = (String)groupMap.get('foundationName');
            String bracketName = (String)groupMap.get('bracketName');
            
            // Build combined description
            String descPole = buildCombinedDescription(poleName, foundationName, bracketName, 
                                                       poleWeight, foundationWeight, bracketWeight);
            
            // Build bolt description (if foundation exists)
            String descBolt = '';
            if (foundationPrice > 0 || foundationWeight > 0) {
                descBolt = buildBoltDescription(poleName, itemNum, secIdx);
            }
            
            // Build bracket description (if bracket exists)
            String descBracket = '';
            if (bracketPrice > 0 || bracketWeight > 0) {
                descBracket = buildBracketDescription(bracketName);
            }
            
            // Calculate combined price
            Decimal combinedUnitRate = polePrice + foundationPrice + bracketPrice;
            Decimal combinedGST = (combinedUnitRate * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
            Decimal combinedUnit = combinedUnitRate + combinedGST;
            Decimal combinedTotal = (combinedUnit * qty).setScale(2, RoundingMode.HALF_UP);
            
            MastGroupWrapper grp = new MastGroupWrapper();
            grp.slNo = String.valueOf(slCounter++);
            grp.descMast = descPole;
            grp.descBolt = descBolt;
            grp.descAcc = descBracket;
            grp.unitRate = formatINR(combinedUnitRate.setScale(2, RoundingMode.HALF_UP));
            grp.gstPct = String.valueOf(gstPct.intValue());
            grp.gstAmount = formatINR(combinedGST);
            grp.freight = freight;
            grp.unitAmount = formatINR(combinedUnit.setScale(2, RoundingMode.HALF_UP));
            grp.qty = String.valueOf(qty.intValue());
            grp.totalAmount = formatINR(combinedTotal);
            grp.unitRateRaw = combinedUnitRate;
            grp.gstAmountRaw = combinedGST;
            grp.unitAmountRaw = combinedUnit;
            grp.totalAmountRaw = combinedTotal;
            mastGroups.add(grp);
        }
        
        appendLumpSumFreightGroup(m, gstPct, freight, slCounter);
        return;
    }
    
    if (mastGroups.isEmpty()) {
        MastGroupWrapper grp = new MastGroupWrapper();
        grp.slNo = '1';
        grp.descMast = 'Supply of CUSTOM LIGHTING POLE (please verify quote configuration).';
        grp.descBolt = '';
        grp.descAcc = '';
        grp.unitRate = '0';
        grp.gstPct = String.valueOf(gstPct.intValue());
        grp.gstAmount = '0';
        grp.freight = freight;
        grp.unitAmount = '0';
        grp.qty = '1';
        grp.totalAmount = '0';
        grp.unitRateRaw = 0;
        grp.gstAmountRaw = 0;
        grp.unitAmountRaw = 0;
        grp.totalAmountRaw = 0;
        mastGroups.add(grp);
    }
}
 
private String buildCombinedDescription(String poleName, String foundationName, String bracketName,
                                        Decimal poleWeight, Decimal foundationWeight, Decimal bracketWeight) {
    String description = '';
    
    // Build pole description
    if (String.isNotBlank(poleName)) {
        // Extract the core description from the pole name
        String poleDesc = poleName;
        // Remove " - Segment - 1 Pole Details" or similar suffixes
        poleDesc = poleDesc.replaceAll(' - Segment - \\d+ Pole Details', '');
        poleDesc = poleDesc.replaceAll(' \\(Item \\d+\\)', '');
        description = 'Supply of ' + poleDesc;
        /*if (poleWeight > 0) {
            description += '. Weight: ' + poleWeight.setScale(3, RoundingMode.HALF_UP) + ' kg';
        }*/
    }
    
    // Add foundation to description
    if (String.isNotBlank(foundationName)) {
        if (String.isBlank(description)) {
            description = 'Supply of Foundation Bolts';
        }
        // Foundation weight will be shown separately in bolt description
    }
    
    // Add bracket to description
    if (String.isNotBlank(bracketName)) {
        if (String.isBlank(description)) {
            description = 'Supply of Bracket / Arm';
        }
        // Bracket weight will be shown separately in bracket description
    }
    
    if (String.isBlank(description)) {
        description = 'Supply of Custom Lighting Pole';
    }

    String suffix = getWindSpeedSuffix();
    if (String.isNotBlank(suffix)) {
        description = description +' '+suffix;
    }
    return description + '.';
}
 
// Same rule the description builders use to pick the c{n}_s{sec}_ prefix, so a
// grouping boundary can never disagree with the description. Names without that
// shape return 1, exactly as before. Deepanjan (20th Aug 2026)
private Integer sectionIndexOf(String itemName) {
    if (String.isBlank(itemName)) return 1;
    Integer secIdx = 1;
    Matcher mSec = Pattern.compile('-\\s*(\\d+)\\s*(?:Pole Details|\\(Item)').matcher(itemName);
    if (mSec.find()) {
        try { secIdx = Integer.valueOf(mSec.group(1)); } catch (Exception ex) { secIdx = 1; }
    }
    if (secIdx < 1 || secIdx > 2) secIdx = 1;
    return secIdx;
}

// Kept for any existing caller: section 1 behaviour, unchanged.
private String buildBoltDescription(String poleName, Integer itemNum) {
    return buildBoltDescription(poleName, itemNum, 1);
}

private String buildBoltDescription(String poleName, Integer itemNum, Integer secIdx) {
    // Try to extract bolt details from the pole name or JSON
    String description = 'Supply of FOUNDATION BOLTS';
    
    // Try to get bolt details from JSON if available
    String cp = 'c' + itemNum + '_s' + secIdx + '_cus_op_';   // was hard-coded s1 - Deepanjan (20th Aug 2026)
    String fbDia = strVal(jsonData, cp + 'foundation_bolt_diameter', '24');
    Decimal fbLen = decVal(jsonData, cp + 'foundation_bolt_length', 0);
    Decimal fbQty = decVal(jsonData, cp + 'bolt_quantity', 0);
    
    if (fbLen > 0 && fbQty > 0) {
        description += ' - M' + fbDia + ' x ' + fbLen.intValue() + ' (' + fbQty.intValue() + ' Nos.)';
    }
    
    // Add weight from the foundation item
    Decimal fndWeight = decVal(jsonData, cp + 'foundation_weight', 0);
    /*if (fndWeight > 0) {
        description += '. Weight: ' + fndWeight.setScale(3, RoundingMode.HALF_UP) + ' kg';
    }*/
    
    return description + '.';
}
 
private String buildBracketDescription(String bracketName) {
    String description = 'Supply of Bracket / Arm';
    
    // Extract bracket type from name if available
    if (String.isNotBlank(bracketName)) {
        String cleanName = bracketName.replaceAll(' - Bracket Details - \\d+', '');
        cleanName = cleanName.replaceAll(' \\(Item \\d+\\)', '');
        if (!cleanName.containsIgnoreCase('Bracket')) {
            description += ' - ' + cleanName;
        }
    }
    
    return description + '.';
}
    // ═══════════════════════════════════════════════════════════════
    //  MID HINGE POLE — build MastGroupWrapper list
    // ═══════════════════════════════════════════════════════════════
    
private void buildMidHingePoleGroups(Map<String,Object> m,
                                      Decimal gstPct, String freight) {
    Integer slCounter = 1;
 
    // First, check if there are accessories in _Final_Apex_Lines
    List<Object> apexLines = getList(m, '_Final_Apex_Lines');
    List<Map<String, Object>> accessoryLines = new List<Map<String, Object>>();
    
    // Collect all accessory lines
    if (!apexLines.isEmpty()) {
        for (Object lineObj : apexLines) {
            Map<String, Object> line = (Map<String, Object>) lineObj;
            String itemName = strVal(line, 'name', '');
            if (String.isNotBlank(itemName) && itemName.contains('ACCESSORIES')) {
                accessoryLines.add(line);
            }
        }
    }
 
    for (Integer n = 1; n <= MAX_REPEATER_COLS; n++) {
        String cp = 'c' + n + '_mhp_';
        String op = 'c' + n + '_op_mhp_';
 
        Decimal poleHeight   = decVal(m, cp + 'height_of_pole', 0);
        Decimal segUnitPrice = (decVal(m, op + 'segment_unit_price', 0))
                                   .setScale(2, RoundingMode.HALF_UP);
        if (poleHeight == 0 && segUnitPrice == 0) continue;
 
        String  poleType    = strVal(m, cp + 'pole_type',               '');
        String  noOfSides   = strVal(m, cp + 'no_of_polygonal_side',    '');
        Decimal topDia      = decVal(m, cp + 'top_diameter',            0);
        Decimal botDia      = decVal(m, cp + 'bottom_diameter',         0);
        Decimal segTopLen   = decVal(m, cp + 'segment_length',     0);
        Decimal segTopThk   = decVal(m, cp + 'segment_thickness',  0);
        String  doorHeight  = strVal(m, cp + 'door_height',             '');
        String  bpType      = strVal(m, cp + 'base_plate_type',         '');
        Decimal bpSize      = decVal(m, cp + 'size_dia_of_base_plate',  0);
        Decimal bpThk       = decVal(m, cp + 'thickness_of_base_plate', 0);
        String  stiffener   = strVal(m, cp + 'stiffener_at_base',       '');
        Boolean needExtra   = boolVal(m, cp + 'need_extra_micron', false);
        String  extraMicron = strVal(m, cp + 'extra_micron',            '');
        String  puPaint     = strVal(m, cp + 'pu_paint_pole_brackets',  '');
        String  addDes     = strVal(m, cp + 'ad_description',  '');
        Decimal segWeight   = decVal(m, cp + 'segment_weight',          0);
        Decimal qty         = decVal(m, cp + 'quantity',                1);
        if (qty == 0) qty = 1;
 
        String shapeLabel = buildShapeLabel(poleType, noOfSides);
 
        // ── Build POLE description ──
        String descPole =
            'Supply of ' + (poleHeight > 0 ? poleHeight + ' MTR ' : '')
            + poleType +'('+ (noOfSides != null ? noOfSides : '')+ ' sided)' + ' Mid Hinge Pole'
            + ' No. of Segment 2 : Top Dia. - ' + topDia.intValue() + ' mm, '
            + 'Bottom Dia. - ' + botDia.intValue() + ' mm'
            + (segTopLen > 0 ? ', Length - '      + segTopLen.intValue() + ' mm' : '')
            + (segTopThk > 0 ? ', Thickness - '   + segTopThk.intValue() + ' mm' : '')
            //+ (doorHeight != '' ? '. Door Height: ' + doorHeight + ' mm' : '')
            + (bpType   != '' ? '. ' + buildBasePlateDesc(bpType, bpSize, bpThk) : '')
            //+ (stiffener != '' ? '. Stiffener at Base: ' + stiffener : '')
            + (needExtra && extraMicron != '' ? ', with ' + extraMicron + ' micron' : '')
            + (puPaint  != '' ? '. PU Paint: ' + puPaint : '')
            + (addDes  != '' ? '. Additional Item: ' + addDes : '')
            + '.';

        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            descPole += suffix;
        }
 
        // ── Foundation details ──
        String fbDiaRaw = strVal(m, cp + 'foundation_bolt_diameter', '');
        if (fbDiaRaw.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw)) {
            fbDiaRaw = strVal(m, cp + 'nr_fb_diameter', '');
        }
        String  fbDia    = String.isBlank(fbDiaRaw) ? '0' : fbDiaRaw;
        Decimal fbLen     = decVal(m, cp + 'foundation_bolt_length', 0);
        Decimal fbQty     = decVal(m, cp + 'bolt_quantity',          0);
        Decimal fbfdnQty  = decVal(m, cp + 'fdn_quantity',          0);
        Decimal pcd       = decVal(m, cp + 'pcd',                    0);
        String  template  = strVal(m, cp + 'template',               '');
        Decimal fndUnitPrice = (decVal(m, op + 'foundation_unit_price', 0))
                                   .setScale(2, RoundingMode.HALF_UP);
        Decimal fndWeight    = decVal(m, cp + 'foundation_weight', 0);
 
        // FOUNDATION BOLT = N.R. -> the bolts are NOT in our scope. Mid Hinge Pole offers
        // N.R. on mhp_foundation_bolt_diameter exactly like the Octagonal poles (and its
        // op_mhp_foundation_unit_price formula already returns 0 for it), so it prints the
        // same red sentence. It goes on the POLE description because the page prefixes
        // descBolt with its own hardcoded "Supply of FOUNDATION BOLTS - " label, and this
        // builder assigns descMast RAW (it never passes through cmGroupMoney) so the
        // sentinels are turned into markup here. Deepanjan (24th Aug 2026)
        // Same guard as the Single scope: N.R. is the picklist DEFAULT, so the sentence is
        // only printed when a foundation figure was actually entered. Deepanjan (24th Aug 2026)
        Boolean fbNisMhp = strVal(m, cp + 'foundation_bolt_diameter', '').equalsIgnoreCase('N.R.')
                        && (String.isNotBlank(strVal(m, cp + 'nr_fb_diameter', ''))
                            || fbLen > 0 || fbQty > 0 || fbfdnQty > 0 || pcd > 0);
        Decimal fbNisQtyMhp = decVal(m, cp + 'bolt_quantity', decVal(m, cp + 'fdn_quantity', 0));
        if (fbNisQtyMhp <= 0) fbNisQtyMhp = fbQty;

        String descBolt = '';
        if (fbNisMhp) {
            descPole += ' ' + fdnNotInScopeDesc(fbDia, fbLen, fbNisQtyMhp, pcd)
                .replace('\u0001FDN_NIS_ON\u0001', '<span class="desc-bolt" style="color:#c00000;font-weight:bold;">')
                .replace('\u0001FDN_NIS_OFF\u0001', '</span>');
        } else if (fbLen > 0 || fbQty > 0) {
            descBolt =
                'Standard Bolts M' + fbDia
                + ' x ' + fbLen.intValue()
                + ' (' + fbQty.intValue() + ' Nos.)'
                + (pcd > 0 ? ' PCD: ' + pcd.intValue() + ' mm' : '')
                + (template != '' ? '. Template: ' + template : '')
                + '.';
        }
 
        // ── Bracket details ──
        // BRACKET TYPE was read with a 'Standard' default and brkQty was forced to 1, so the
        // test below was true even on a quote where Arm / Bracket Details was left completely
        // empty - the offer printed "Supply of Bracket / Arm: Standard bracket." out of thin
        // air. The sentence now needs the user to have actually entered a bracket type; the
        // 'Standard' default is kept for every other use so no price or weight changes.
        // Deepanjan (24th Aug 2026)
        // No 'Standard' fallback - print only what was entered. Deepanjan (24th Aug 2026)
        String  bracketType = strVal(m, cp + 'bracket_type', '');
        String  typeOfArm   = strVal(m, cp + 'type_of_arm',  '');
        String  armlength   = strVal(m, cp + 'arm_length', '');
        String  armdiaod   = strVal(m, cp + 'arm_dia_od', '');
        String  sleeveLength   = strVal(m, cp + 'sleeve_length', '');
        String brPudesc        = strVal(m, cp + 'pu_paint_br_desc',  ''); 
        Decimal brkUnitPrice = (decVal(m, op + 'bracket_unit_price', 0))
                                   .setScale(2, RoundingMode.HALF_UP);
        Decimal brkWeight    = decVal(m, cp + 'bracket_weight', 0);
        Decimal brkQty       = decVal(m, cp + 'brk_quantity',   0);
        if (brkQty == 0) brkQty = 1;
 
System.debug(' br desc '+ brPudesc);
        String descBrk = '';
        // Entered, and not N.R. - Mid Hinge always excluded N.R. here and that stays.
        // Deepanjan (24th Aug 2026)
        if (String.isNotBlank(bracketType) && !bracketType.equalsIgnoreCase('N.R.')) {
            // Customized -> its description text; NO. OF ARM -> the word, and "arm(s)"
            // becomes "arm". Deepanjan (24th Aug 2026)
            String brkLabel = bracketLabel(m, bracketType, cp, cp);
            String armTxt   = armWord(typeOfArm);
            descBrk = brkLabel
                        + (armTxt != '' ? ' with ' + armTxt + ' arm' : '')
                        + ' bracket'
                        + (armLength != '' ? ' ' + armLength + ' mm long on one side' : '')
                        + (armdiaod != '' ? ' with ' + armdiaod + ' OD GI Pipe' : '')
                        + (String.isNotBlank(sleeveLength) ? ', ' + sleeveLength.trim() + 'mm Sleeve' : '')
                        + (brPudesc != '' ? ' ' + brPudesc : '')
                        + '.';
        }
 
        // ═══════════════════════════════════════════════════════
        // Add POLE as combined line item (Pole + Foundation + Bracket)
        // ═══════════════════════════════════════════════════════
        
        Decimal adjustedSegUnitPrice = perPolfrieght ? segUnitPrice + perPolTPCharg : segUnitPrice;
        Decimal roundedSegUnitPrice = adjustedSegUnitPrice.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedFbnUnitPrice = fndUnitPrice.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedBrkUnitPrice = brkUnitPrice.setScale(2, RoundingMode.HALF_UP);
        System.debug('seg price: ' + roundedSegUnitPrice + ' fnd price: ' + roundedFbnUnitPrice + ' brk price: '+ roundedBrkUnitPrice);

        // COMBINED QUANTITY - Deepanjan (22nd Aug 2026). Same change as buildHighMastGroups,
        // but here the three components can carry DIFFERENT quantities, so the whole-lot
        // figure is kept and divided back out by the pole quantity. The total is unchanged
        // because it is rebuilt as unit x qty from the undivided sum.
        Decimal cmQty = qty;
        if (cmQty == null || cmQty <= 0) cmQty = 1;
        Decimal combinedUnitRate = ((roundedSegUnitPrice * qty) + (roundedFbnUnitPrice * fbfdnQty) + (roundedBrkUnitPrice * brkQty)) / cmQty;

        Decimal segGST = (roundedSegUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal fbnGST = (roundedFbnUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal brkGST = (roundedBrkUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);

        Decimal combinedGST      = ((segGST * qty) + (fbnGST * fbfdnQty) + (brkGST * brkQty)) / cmQty;
        Decimal combinedUnit     = combinedUnitRate + combinedGST;
        Decimal combinedTotal    = (combinedUnit * cmQty).setScale(2, RoundingMode.HALF_UP);
        
        System.debug('segUnitPrice --> '+segUnitPrice);
        System.debug('adjustedSegUnitPrice --> '+adjustedSegUnitPrice);
        System.debug('poleQty --> '+qty);
        System.debug('fbnUnitPrice --> '+fndUnitPrice);
        System.debug('fbQty --> '+fbfdnQty);
        System.debug('brkUnitPrice --> '+brkUnitPrice);
        System.debug('brkQty --> '+brkQty);
        System.debug('combinedGST --> '+combinedGST);
        System.debug('combinedTotal --> '+combinedUnitRate);

        //Decimal combinedUnitRate = segUnitPrice + fndUnitPrice + brkUnitPrice;
        //Decimal combinedGST = (combinedUnitRate * gstPct / 100).setScale(0, RoundingMode.HALF_UP);
        //Decimal combinedUnit = combinedUnitRate + combinedGST;
        //Decimal combinedTotal = (combinedUnit * qty).setScale(0, RoundingMode.HALF_UP);
 
        MastGroupWrapper grp = new MastGroupWrapper();
        grp.slNo = String.valueOf(slCounter++);
        grp.descMast = descPole;
        grp.descBolt = descBolt;
        grp.descAcc = descBrk;
        grp.unitRate = formatINR2(combinedUnitRate);
        grp.gstPct = String.valueOf(gstPct.intValue());
        grp.gstAmount = formatINR2(combinedGST);
        grp.freight = freight;
        grp.unitAmount = formatINR2(combinedUnit);
        grp.qty = String.valueOf(cmQty.intValue());
        grp.qtyRaw = cmQty;                        // was never set here
        grp.totalAmount = formatINR(combinedTotal);
        grp.unitRateRaw = combinedUnitRate;
        grp.gstAmountRaw = combinedGST;
        grp.unitAmountRaw = combinedUnit;
        grp.totalAmountRaw = combinedTotal;
        mastGroups.add(grp);
    }
 
    // ═══════════════════════════════════════════════════════════
    // ADD ACCESSORIES as a SINGLE consolidated line item
    // ═══════════════════════════════════════════════════════════
    Decimal accBaseTotal = 0;

    for (Map<String, Object> accLine : accessoryLines) {
        Decimal unitPrice = decVal(accLine, 'unitPrice', 0);
        Decimal quantity  = decVal(accLine, 'quantity', 1);

        if (unitPrice <= 0) continue;

        accBaseTotal += (unitPrice  );
    }

    if (accBaseTotal > 0) {
        // Accessory NAMES come from the c1..c10_mhp_acc_accessory config keys,
        // not from the _Final_Apex_Lines item names (those are generic).
        List<String> accNames = new List<String>();
        for (Integer i = 1; i <= 10; i++) {
            String nm = strVal(m, 'c' + i + '_mhp_acc_accessory', '');
            if (String.isNotBlank(nm)) {
                accNames.add(nm.trim());
            }
        }
        Decimal accUnitRate = accBaseTotal.setScale(2, RoundingMode.HALF_UP);
        Decimal accGST      = (accUnitRate * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal accUnit     = accUnitRate + accGST;
        Decimal accTotal    = accUnit.setScale(2, RoundingMode.HALF_UP);

        MastGroupWrapper accGrp = new MastGroupWrapper();
        accGrp.slNo           = String.valueOf(slCounter++);
        accGrp.descMast       = buildAccessoryDescription(accNames);
        accGrp.descBolt       = '';
        accGrp.descAcc        = '';
        accGrp.unitRate       = formatINR(accUnitRate);
        accGrp.gstPct         = String.valueOf(gstPct.intValue());
        accGrp.gstAmount      = formatINR(accGST);
        accGrp.freight        = freight;
        accGrp.unitAmount     = formatINR(accUnit);
        accGrp.qty            = '1';
        accGrp.totalAmount    = formatINR(accTotal);
        accGrp.unitRateRaw    = accUnitRate;
        accGrp.gstAmountRaw   = accGST;
        accGrp.unitAmountRaw  = accUnit;
        accGrp.totalAmountRaw = accTotal;
        mastGroups.add(accGrp);
    }
 
    appendLumpSumFreightGroup(m, gstPct, freight, slCounter);
 
    if (mastGroups.isEmpty()) {
        MastGroupWrapper grp = new MastGroupWrapper();
        grp.slNo = '1'; 
        grp.descMast = 'Supply of MID HINGE POLE (please verify quote configuration).';
        grp.descBolt = ''; 
        grp.descAcc = ''; 
        grp.unitRate = '0';
        grp.gstPct = String.valueOf(gstPct.intValue()); 
        grp.gstAmount = '0';
        grp.freight = freight; 
        grp.unitAmount = '0'; 
        grp.qty = '1'; 
        grp.totalAmount = '0';
        grp.unitRateRaw = 0; 
        grp.gstAmountRaw = 0; 
        grp.unitAmountRaw = 0; 
        grp.totalAmountRaw = 0;
        mastGroups.add(grp);
    }
}
    // ═══════════════════════════════════════════════════════════════
    //  TRANSMISSION POLE — build MastGroupWrapper list
    // ═══════════════════════════════════════════════════════════════
    private void buildTransmissionPoleGroups(Map<String,Object> m,Decimal gstPct, String freight) {
        Integer slCounter = 1;
 
        for (Integer n = 1; n <= 10; n++) {
            String cp = 'c' + n + '_tp_';
            String cp2 = 'c' + n + '_tp_s2_';
 
           
            Decimal poleHeight = decVal(m, cp + 'height_of_pole', 0);
            Decimal unitPrice  = (decVal(m, cp + 'unit_price', 0))
                                     .setScale(2, RoundingMode.HALF_UP);
            Boolean hasSeg1 = (poleHeight != 0 || unitPrice != 0);
            
            Decimal s2Height     = decVal(m, cp2 + 'height_of_pole', 0);
            Decimal s2UnitPrice  = (decVal(m, cp2 + 'unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
            Boolean hasSeg2 = (s2Height != 0 || s2UnitPrice != 0);
 
            if (!hasSeg1 && !hasSeg2) continue;
            
            if (hasSeg1) {
            String  poleType  = strVal(m, cp + 'pole_type',               'Polygonal');
            String  noOfSides = strVal(m, cp + 'no_of_polygonal_side',    '');
            Decimal topDia    = decVal(m, cp + 'top_diameter',            0);
            Decimal botDia    = decVal(m, cp + 'bottom_diameter',         0);
            Decimal segLen    = decVal(m, cp + 'segment_length',          0);
            Decimal thickness = decVal(m, cp + 'segment_thickness',       0);
            String  bpType    = strVal(m, cp + 'bearing_plate_type',      '');
            Decimal bpSize    = decVal(m, cp + 'size_dia_of_bearing_plate',  0);
            Decimal bpThk     = decVal(m, cp + 'thickness_of_bearing_plate', 0);
            Decimal cabDia    = decVal(m, cp + 'pole_cab_dia',            0);
            Decimal cabThk    = decVal(m, cp + 'pole_cab_thickness',      0);
            Decimal dan       = decVal(m, cp + 'dan',                     0);
            String  note      = strVal(m, cp + 'note',                    '');
            String  extra     = strVal(m, cp + 'extra_micron',            '');
            Decimal segWeight = decVal(m, cp + 'segment_weight',          0);
            Decimal qty       = decVal(m, cp + 'qty',                     1);
            if (qty == 0) qty = 1;
 
            String shapeLabel = buildShapeLabel(poleType, noOfSides);
 
            String descPole =
                'Supply of ' + (poleHeight > 0 ? poleHeight + ' MTR ' : '')
                + shapeLabel + ' Transmission Pole'
                + (noOfSides != '' ? ', ' + noOfSides + ' Sided' : '')
                + ': Top Dia. - ' + topDia.intValue() + ' mm, '
                + 'Bottom Dia. - ' + botDia.intValue() + ' mm'
                + (segLen    > 0  ? ', Length - '    + segLen.intValue()    + ' mm' : '')
                + (thickness > 0  ? ', Thickness - ' + thickness.intValue() + ' mm' : '')
                + (bpType   != '' ? '. ' + buildBearingPlateDesc(bpType, bpSize, bpThk) : '')
                + (cabDia   > 0   ? '. Cable Dia: '   + cabDia.intValue() + ' mm' : '')
                + (cabThk   > 0   ? ', Thickness: '   + cabThk.intValue() + ' mm' : '')
                + (dan      > 0   ? '. DAN: ' + dan.intValue() : '')
                + (extra   != ''  ? ', with ' + extra + ' micron' : '')
                + (note    != ''  ? '. Note: ' + note : '')
                + '.';

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descPole += suffix;
            }
                
            Boolean hasSpecialDesc = boolVal(m, cp + 'is_special_desc', false);
            if (hasSpecialDesc) {
                String  specialText  = strVal(m, cp + 'special_desc_text', '');
                Decimal specialPrice = decVal(m, cp + 'special_desc_unitPrice', 0);
                if (String.isNotBlank(specialText)) {
                    descPole += '. Special: ' + specialText;
                }
                unitPrice = (unitPrice + specialPrice).setScale(2, RoundingMode.HALF_UP);
            }
            
            Decimal adjustedSegUnitPrice = perPolfrieght ? (unitPrice + perPolTPCharg).setScale(2, RoundingMode.HALF_UP) : unitPrice.setScale(2, RoundingMode.HALF_UP);

            Decimal gstAmt   = (adjustedSegUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
            Decimal unitAmt  = adjustedSegUnitPrice + gstAmt;
            Decimal totalAmt = (unitAmt * qty).setScale(2, RoundingMode.HALF_UP);
 
            MastGroupWrapper grp = new MastGroupWrapper();
            grp.slNo           = String.valueOf(slCounter++);
            grp.descMast       = descPole;
            grp.descBolt       = '';
            grp.descAcc        = '';
            grp.unitRate       = formatINR(adjustedSegUnitPrice.setScale(2, RoundingMode.HALF_UP));
            grp.gstPct         = String.valueOf(gstPct.intValue());
            grp.gstAmount      = formatINR(gstAmt);
            grp.freight        = freight;
            grp.unitAmount     = formatINR(unitAmt.setScale(2, RoundingMode.HALF_UP));
            grp.qty            = String.valueOf(qty.intValue());
            grp.totalAmount    = formatINR(totalAmt);
            grp.unitRateRaw    = adjustedSegUnitPrice;
            grp.gstAmountRaw   = gstAmt;
            grp.unitAmountRaw  = unitAmt;
            grp.totalAmountRaw = totalAmt;
            mastGroups.add(grp);
            }
            
            
 
        if (hasSeg2) {
            String  s2PoleType  = strVal(m, cp2 + 'pole_type',               'Conical');
            String  s2NoOfSides = strVal(m, cp2 + 'no_of_polygonal_side',    '');
            Decimal s2TopDia    = decVal(m, cp2 + 'top_diameter',            0);
            Decimal s2BotDia    = decVal(m, cp2 + 'bottom_diameter',         0);
            Decimal s2SegLenTop = decVal(m, cp + 'segment2_length_top',     0);
            Decimal s2LenBot    = decVal(m, cp2 + 'length_bot',              0);
            Decimal s2ThkTop    = decVal(m, cp + 'segment2_thickness_top',  0);
            Decimal s2ThkBot    = decVal(m, cp2 + 'thickness_bot',           0);
            Decimal s2Overlap   = decVal(m, cp2 + 'overlap',                 0);
            String  s2BpType    = strVal(m, cp2 + 'bearing_plate_type',      '');
            Decimal s2BpSize    = decVal(m, cp2 + 'size_dia_of_bearing_plate', 0);
            Decimal s2BpThk     = decVal(m, cp2 + 'thickness_of_bearing_plate', 0);
            Decimal s2CabDia    = decVal(m, cp2 + 'pole_cab_dia',            0);
            Decimal s2CabThk    = decVal(m, cp2 + 'pole_cab_thickness',      0);
            Decimal s2Dan       = decVal(m, cp2 + 'dan',                     0);
            String  s2Note      = strVal(m, cp2 + 'note',                    '');
            String  s2Extra     = strVal(m, cp2 + 'extra_micron',            '');
            Decimal s2SegWeight = decVal(m, cp2 + 'segment_weight',          0);
            Decimal s2Qty       = decVal(m, cp2 + 'qty',                     1);
            if (s2Qty == 0) s2Qty = 1;
    
            String s2ShapeLabel = buildShapeLabel(s2PoleType, s2NoOfSides);
    
            String descPole2 =
                'Supply of ' + (s2Height > 0 ? s2Height + ' MTR ' : '')
                + s2ShapeLabel + ' Transmission Pole'
                + (s2NoOfSides != '' ? ', ' + s2NoOfSides + ' Sided' : '')
                + ': Top Dia. - ' + s2TopDia.intValue() + ' mm, '
                + 'Bottom Dia. - ' + s2BotDia.intValue() + ' mm'
                + (s2SegLenTop > 0 ? ', Length(Top) - ' + s2SegLenTop.intValue() + ' mm' : '')
                + (s2LenBot    > 0 ? ', Length(Bot) - ' + s2LenBot.intValue()    + ' mm' : '')
                + (s2ThkTop    > 0 ? ', Thickness(Top) - ' + s2ThkTop.intValue() + ' mm' : '')
                + (s2ThkBot    > 0 ? ', Thickness(Bot) - ' + s2ThkBot.intValue() + ' mm' : '')
                //+ (s2Overlap   > 0 ? ', Overlap - ' + s2Overlap.intValue() + ' mm' : '')
                + (s2BpType   != '' ? '. ' + buildBearingPlateDesc(s2BpType, s2BpSize, s2BpThk) : '')
                + (s2CabDia   > 0   ? '. Cable Dia: ' + s2CabDia.intValue() + ' mm' : '')
                + (s2CabThk   > 0   ? ', Thickness: ' + s2CabThk.intValue() + ' mm' : '')
                + (s2Dan      > 0   ? '. DAN: ' + s2Dan.intValue() : '')
                + (s2Extra   != ''  ? ', with ' + s2Extra + ' micron' : '')
                + (s2Note    != ''  ? '. Note: ' + s2Note : '')
            + '.';

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descPole2 += suffix;
            }
            
            Boolean hasSpecialDesc2 = boolVal(m, cp2 + 'is_special_desc', false);
            if (hasSpecialDesc2) {
                String  specialText2  = strVal(m, cp2 + 'special_desc_text', '');
                Decimal specialPrice2 = decVal(m, cp2 + 'special_desc_unitPrice', 0);
                if (String.isNotBlank(specialText2)) {
                    descPole2 += '. Special: ' + specialText2;
                }
                s2UnitPrice = (s2UnitPrice + specialPrice2).setScale(2, RoundingMode.HALF_UP);
            }
            
            Decimal adjustedSeg2UnitPrice = perPolfrieght ? (s2UnitPrice + perPolTPCharg).setScale(2, RoundingMode.HALF_UP) : s2UnitPrice.setScale(2, RoundingMode.HALF_UP);

            Decimal s2GstAmt   = (adjustedSeg2UnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
            Decimal s2UnitAmt  = adjustedSeg2UnitPrice + s2GstAmt;
            Decimal s2TotalAmt = (s2UnitAmt * s2Qty).setScale(2, RoundingMode.HALF_UP);
    
            MastGroupWrapper grp2 = new MastGroupWrapper();
            grp2.slNo           = String.valueOf(slCounter++);
            grp2.descMast       = descPole2;
            grp2.descBolt       = '';
            grp2.descAcc        = '';
            grp2.unitRate       = formatINR(adjustedSeg2UnitPrice.setScale(2, RoundingMode.HALF_UP));
            grp2.gstPct         = String.valueOf(gstPct.intValue());
            grp2.gstAmount      = formatINR(s2GstAmt);
            grp2.freight        = freight;
            grp2.unitAmount     = formatINR(s2UnitAmt.setScale(2, RoundingMode.HALF_UP));
            grp2.qty            = String.valueOf(s2Qty.intValue());
            grp2.totalAmount    = formatINR(s2TotalAmt);
            grp2.unitRateRaw    = adjustedSeg2UnitPrice;
            grp2.gstAmountRaw   = s2GstAmt;
            grp2.unitAmountRaw  = s2UnitAmt;
            grp2.totalAmountRaw = s2TotalAmt;
            mastGroups.add(grp2);
        }
        }
    
            appendLumpSumFreightGroup(m, gstPct, freight, slCounter);
    
            if (mastGroups.isEmpty()) {
                MastGroupWrapper grp = new MastGroupWrapper();
                grp.slNo = '1'; grp.descMast = 'Supply of TRANSMISSION POLE (please verify quote configuration).';
                grp.descBolt = ''; grp.descAcc = ''; grp.unitRate = '0';
                grp.gstPct = String.valueOf(gstPct.intValue()); grp.gstAmount = '0';
                grp.freight = freight; grp.unitAmount = '0'; grp.qty = '1'; grp.totalAmount = '0';
                grp.unitRateRaw = 0; grp.gstAmountRaw = 0; grp.unitAmountRaw = 0; grp.totalAmountRaw = 0;
                mastGroups.add(grp);
            }
    }
 
    // ═══════════════════════════════════════════════════════════════
    //  LIGHTING POLE — build MastGroupWrapper list
    // ═══════════════════════════════════════════════════════════════
private void buildLightingPoleGroups(Map<String, Object> m, Decimal gstPct, String freight) {
    Integer slCounter = 1;

    // Check top-level JSON fields for mast type and standard pole type
    typeOfMast       = strVal(m, 'type_of_mast', '');
    String mastStandardPole = strVal(m, 'mast_standard_pole', '');
    Boolean isCustomOctagonal = (typeOfMast.equalsIgnoreCase('Octagonal Pole') && 
                                 mastStandardPole.equalsIgnoreCase('Custom Lighting Pole'));
    Boolean isStandardOctagonal = (typeOfMast.equalsIgnoreCase('Octagonal Pole') && 
                                 mastStandardPole.equalsIgnoreCase('Standard Lighting Pole'));
    
    // ── Section 1 items ──────────────────────────────────────────
    for (Integer n = 1; n <= MAX_REPEATER_COLS; n++) {
        // Base prefix patterns
        String pStd  = 'c' + n + '_s1_';
        String pCus  = 'c' + n + '_s1_cus_op_';
        String lpStd = 'c' + n + '_lp_';
        String lpCus = 'c' + n + '_cus_op_';

        // Primary prefix selection based on pole classification
        String p  = isCustomOctagonal ? pCus : pStd;
        String lp = isCustomOctagonal ? lpCus : lpStd;

        // Main height lookup with robust prefix fallbacks
        Decimal poleHeight = decVal(m, p + 'height_of_pole', 
                             decVal(m, pStd + 'height_of_pole', 
                             decVal(m, pCus + 'height_of_pole', 0)));
        if (poleHeight == 0) continue;

        String poleType   = strVal(m, p + 'pole_type', strVal(m, pCus + 'pole_type', 'Octagonal'));
        String noOfSides  = strVal(m, p + 'no_of_polygonal_side', strVal(m, pCus + 'no_of_polygonal_side', '8'));
        String shapeLabel = buildShapeLabel(poleType, noOfSides);

        Decimal topDia = decVal(m, p + 'top_diameter', decVal(m, pCus + 'top_diameter', 0));
        Decimal botDia = decVal(m, p + 'bottom_diameter', decVal(m, pCus + 'bottom_diameter', 0));
        Decimal segLen = decVal(m, p + 'segment_length', decVal(m, pCus + 'segment_length', 0));
        Decimal segThk = decVal(m, p + 'segment_thickness', decVal(m, pCus + 'segment_thickness', 0));

        String  extraMicron = strVal(m, p + 'extra_micron',            strVal(m, pCus + 'extra_micron', ''));
        String  puPaintPole = strVal(m, p + 'pu_paint_pole_brackets',           strVal(m, pCus + 'pu_paint_pole_brackets', ''));
        // SOLAR STRUCTURE description - Deepanjan (6th September 2026). The Custom Octagonal
        // blueprint names this field differently per section: Section 1 has
        // s1_cus_op_solar_structure, Section 2 has s2_cus_op_solar_description. Reading only
        // 'solar_structure' printed the sentence for Section 1 and silently dropped it for
        // Section 2, while the weight formula (which uses the right key) still priced the
        // solar structure - the customer paid for it and the offer never said so.
        // 'solar_structure' stays FIRST in the chain, so every quote that printed before
        // prints exactly as before; only the Section-2 blank is filled.
        String  solarStruct = strVal(m, p + 'solar_structure',
                              strVal(m, p + 'solar_description',
                              strVal(m, pCus + 'solar_structure',
                              strVal(m, pCus + 'solar_description', ''))));
        String  batteryBox  = strVal(m, p + 'battery_box',             strVal(m, pCus + 'battery_box', ''));
        String  laddar  	= strVal(m, p + 'ladder_description',             strVal(m, pCus + 'ladder_description', ''));
        String 	addDes 		= strVal(m, p + 'ad_description',             strVal(m, pCus + 'ad_description', ''));
        
        Decimal bpSize = decVal(m, p + 'size_dia_of_base_plate', decVal(m, pCus + 'size_dia_of_base_plate', 0));
        Decimal bpThk  = decVal(m, p + 'thickness_of_base_plate', decVal(m, pCus + 'thickness_of_base_plate', 0));
        String  bpType = strVal(m, p + 'base_plate_type', strVal(m, pCus + 'base_plate_type', 'Square'));

        String fbDiaRaw = strVal(m, p + 'foundation_bolt_diameter', strVal(m, pCus + 'foundation_bolt_diameter', ''));
        if (fbDiaRaw.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw)) {
            fbDiaRaw = strVal(m, p + 'nr_fb_diameter', strVal(m, pCus + 'nr_fb_diameter', ''));
        }
        String  fbDia    = String.isBlank(fbDiaRaw) ? '0' : fbDiaRaw;
        // FOUNDATION BOLT = N.R. -> the bolts are NOT in our scope. Same sentence and the
        // same red styling the Segment Above 5 masts already print. It goes on the POLE
        // description because the page prefixes descBolt with its own hardcoded
        // "Supply of FOUNDATION BOLTS - " label. Deepanjan (24th Aug 2026)
        Boolean fbNis    = strVal(m, p + 'foundation_bolt_diameter',
                                  strVal(m, pCus + 'foundation_bolt_diameter', '')).equalsIgnoreCase('N.R.');
        Decimal fbPcd    = decVal(m, p + 'pcd', decVal(m, pCus + 'pcd', 0));
        Decimal fbLen    = decVal(m, p + 'foundation_bolt_length', decVal(m, pCus + 'foundation_bolt_length', 0));
        Decimal stdfbQty    = decVal(m, p + 'bolt_quantity', decVal(m, pCus + 'fdn_quantity', 0));
        Decimal cusfbQty    = decVal(m, pCus + 'fdn_quantity', 0);
        Decimal octStanQty  = decval(m, p + 'fdn_quantity', 0);
        Decimal fbQty    = isCustomOctagonal ? cusfbQty : isStandardOctagonal ? octStanQty : stdfbQty;
        String  template = strVal(m, p + 'template', strVal(m, pCus + 'template', ''));
        String  boltType = template.toLowerCase().contains('j') ? 'J Type' : 'Standard';


        Boolean addFBFlag = boolVal(m, pCus + 'fdn_ad', false);
        String addFBDes    = strVal(m, pCus + 'fdn_ad_description', '');
        Boolean addBrflag  = boolVal(m, pCus + 'br_ad', false);
        String addBrDes    = strVal(m, pCus + 'br_ad_description', '');

        // NO FALLBACK on either field. BRACKET TYPE used to default to 'Standard' and NO.
        // OF ARM to '1', so an untouched Arm / Bracket Details still produced a full
        // sentence. Whatever the user entered is printed; nothing entered, nothing
        // printed. Deepanjan (24th Aug 2026)
        String bracketType = strVal(m, p + 'bracket_type', strVal(m, pCus + 'bracket_type', ''));
        String typeOfArm   = strVal(m, p + 'type_of_arm', strVal(m, pCus + 'type_of_arm', ''));
        String  armdiaod   = strVal(m, p + 'arm_dia_od', strVal(m, pCus + 'arm_dia_od', ''));
        String  armlength   = strVal(m, p + 'arm_length', strVal(m, pCus + 'arm_length', ''));
        String sleeveLength = strVal(m, p + 'sleeve_length', strVal(m, pCus + 'sleeve_length', ''));
        Decimal brkQty     = decVal(m, p + 'brk_quantity', decVal(m, pCus + 'brk_quantity', 0));

        // Quantity lookup chain
        Decimal poleQty = decVal(m, lp + 's1_quantity',
                          decVal(m, lp + 'quantity',
                          decVal(m, p + 'quantity',
                          decVal(m, 'c' + n + 'cus_op_s1_quantity',
                          decVal(m, 'c' + n + '_op_s1_quantity', 1)))));
        if (poleQty == 0) poleQty = 1;

        // Pricing lookups
        Decimal segUnitPrice = decVal(m, lp + 'segment_unit_price',
                               decVal(m, 'c' + n + '_lp_segment_unit_price',
                               decVal(m, 'c' + n + '_op_segment_unit_price',
                               decVal(m, 'c' + n + '_cus_op_segment_base_price', 0))));

        Decimal fbnUnitPrice = decVal(m, lp + 'foundation_unit_price',
                               decVal(m, 'c' + n + '_lp_foundation_unit_price',
                               decVal(m, 'c' + n + '_op_foundation_unit_price',
                               decVal(m, 'c' + n + '_cus_op_foundation_unit_price', 0))));

        Decimal brkUnitPrice = decVal(m, lp + 'bracket_unit_price',
                               decVal(m, 'c' + n + '_lp_bracket_unit_price',
                               decVal(m, 'c' + n + '_op_bracket_unit_price',
                               decVal(m, 'c' + n + '_cus_op_bracket_unit_price', 0))));
        
        // ── Standardized Calculation Logic ──────────────────────────
        // 
        System.debug('perPolfrieght --> '+ perPolfrieght);
        System.debug('perPolTPCharg --> '+ perPolTPCharg);
        System.debug('poleQty --> '+ poleQty);
        
        Decimal adjustedSegUnitPrice = perPolfrieght ? segUnitPrice + perPolTPCharg : segUnitPrice;
        Decimal roundedSegUnitPrice = adjustedSegUnitPrice.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedFbnUnitPrice = fbnUnitPrice.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedBrkUnitPrice = brkUnitPrice.setScale(2, RoundingMode.HALF_UP);
        
        Decimal combinedUnitRate = (roundedSegUnitPrice  + roundedFbnUnitPrice  + roundedBrkUnitPrice );

        Decimal segGST = (roundedSegUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal fbnGST = (roundedFbnUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal brkGST = (roundedBrkUnitPrice * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        
        Decimal combinedGST      =(segGST  + fbnGST + brkGST ).setScale(2, RoundingMode.HALF_UP);
        combinedUnitRate = combinedUnitRate.setScale(2, RoundingMode.HALF_UP);
        combinedGST      = combinedGST.setScale(2, RoundingMode.HALF_UP);

        Decimal combinedUnit     = combinedUnitRate + combinedGST;
        Decimal combinedTotal    = (combinedUnit * poleQty).setScale(2, RoundingMode.HALF_UP);
        
        System.debug('segUnitPrice --> '+segUnitPrice);
        System.debug('adjustedSegUnitPrice --> '+adjustedSegUnitPrice);
        System.debug('poleQty --> '+poleQty);
        System.debug('fbnUnitPrice --> '+fbnUnitPrice);
        System.debug('fbQty --> '+fbQty);
        System.debug('brkUnitPrice --> '+brkUnitPrice);
        System.debug('brkQty --> '+brkQty);
        System.debug('combinedGST --> '+combinedGST);
        System.debug('combinedTotal --> '+combinedTotal);


        String descPole =
            'Supply of ' + poleHeight + ' MTR '
            + shapeLabel + ' Pole as per Dimension: '
            + 'Top Dia. - ' + topDia.intValue() + ' mm, '
            + 'Bottom Dia. - ' + botDia.intValue() + ' mm, '
            + 'Section - 1 '
            + '(Section Length - ' + segLen.intValue() + ' mm), '
            + 'Thickness- ' + segThk.intValue() + ' mm, '
            + buildBasePlateDesc(bpType, bpSize, bpThk) 
            + (extraMicron != '' ? ', with ' + extraMicron + ' micron'                : '')
            + (puPaintPole != '' ? '. PU Paint: ' + puPaintPole                    : '')
            + (solarStruct != '' ? '. Solar Structure: ' + solarStruct             : '')
            + (batteryBox  != '' ? '. Battery Box: ' + batteryBox                  : '')
            + (laddar  	   != '' ? '. Laddar: ' + laddar                           : '')
            + (addDes      != '' ? '. Additional Item: ' + addDes                 : '')
            +'.';
        
        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            descPole += suffix;
        }

        String descBolt = fbNis
                        ? ''
                        : ('J Type Bolts M' + fbDia + ' x ' + fbLen.intValue() + 'mm (' + stdfbQty.intValue() + ' Nos.) with Template.' 
                          + (addFBFlag ? ' ' + addFBDes : ''));
        // Nos. for the out-of-scope sentence: BOLT QUANTITY first, then FOUNDATION
        // QUANTITY, then whatever fbQty already resolved - so the sentence reads the
        // same in Single and Combined whichever field the user fills. The normal bolt
        // text keeps using fbQty exactly as before. Deepanjan (24th Aug 2026)
        Decimal fbNisQty = decVal(m, p + 'bolt_quantity',
                           decVal(m, pCus + 'bolt_quantity',
                           decVal(m, p + 'fdn_quantity',
                           decVal(m, pCus + 'fdn_quantity', 0))));
        if (fbNisQty <= 0) fbNisQty = fbQty;
        if (fbNis) {
            // This builder assigns descMast RAW (it never passes through cmGroupMoney), so
            // the sentinels are turned into markup right here. The cell already renders with
            // escape="false". Deepanjan (24th Aug 2026)
            descPole += ' ' + fdnNotInScopeDesc(fbDia, fbLen, fbNisQty, fbPcd)
                .replace('\u0001FDN_NIS_ON\u0001', '<span class="desc-bolt" style="color:#c00000;font-weight:bold;">')
                .replace('\u0001FDN_NIS_OFF\u0001', '</span>');
        }

        // BRACKET DETAILS print when a bracket ACTUALLY EXISTS - that was the complaint:
        // the sentence showed up on quotes where Arm / Bracket Details was left empty. It
        // used to key off hasArms, and NO. OF ARM defaults to '1', so hasArms was true even
        // on an untouched quote and the sentence always printed. The test is now the bracket
        // PRICE, which the estimator computes as 0 for N.R. and 0 when no weight was entered.
        // Applies to Custom and Standard alike; the price itself is untouched, so no total
        // moves. Deepanjan (24th Aug 2026)
        Boolean hasArms = String.isNotBlank(typeOfArm) && !typeOfArm.equalsIgnoreCase('0') && !typeOfArm.equalsIgnoreCase('N/A');
        Boolean showBracket = (String.isNotBlank(bracketType) && !'N.R.'.equalsIgnoreCase(bracketType.trim()));
        System.debug('showBracket 1326 -> '+ showBracket);
        // Customized -> its description text; a numeric NO. OF ARM -> the word, with
        // "arm(s)" reduced to "arm". Deepanjan (24th Aug 2026)
        String brkLabel = bracketLabel(m, bracketType, p, pCus);
        String armTxt   = armWord(typeOfArm);
        String  armNumber = armNumtoWord(typeOfArm);
        String brkPUDesc = strVal(m, pCus + + 'pu_paint_br_desc', '');
        String brkCusDesc = strVal(m, pCus + + 'customized_description', '');
        String brkRingDesc = strVal(m, pCus + + 'ring_description', '');
        Boolean brkPuFlag = boolVal(m, pCus + 'pu_paint_checkbox', false);
        
        String descBrk = showBracket
                        ? (brkLabel
                           + (hasArms
                              ? ((typeOfArm != null && typeOfArm.isNumeric()
                                    ? ' ' + armTxt + ' arm bracket '
                                        + (armLength != '' ?  ' '+ armLength + ' mm long on '+ armNumber +' side' : '')
                                        + (armdiaod != '' ? ' with ' + armdiaod + ' OD GI Pipe' : '')
                                        + (String.isNotBlank(sleeveLength) ? ', ' + sleeveLength.trim() + 'mm Sleeve' : '')
                                    : ' ' + armTxt + ' bracket'
                                        + (String.isNotBlank(brkRingDesc) ? ' ' + brkRingDesc : ''))
                                 + '.')
                              : '.')
                           + (addBrflag && String.isNotBlank(addBrDes) ? ' ' + addBrDes : '')
                           + (String.isNotBlank(brkPUDesc) && brkPuFlag ? ' PU Paint: ' + brkPUDesc + '.' : ''))
                        : '';
        System.debug('line 1344 : '+ descBrk +' arm length: '+ armlength + ' armdiaOd : '+armdiaOd);

        // ── Field Assignments Aligned with cmCollapseSlice ──
        MastGroupWrapper grp = new MastGroupWrapper();
        grp.slNo           = String.valueOf(slCounter++);
        grp.descMast       = descPole;
        grp.descBolt       = descBolt;
        grp.descAcc        = descBrk;
        grp.unitRate       = formatINR(combinedUnitRate.setScale(2, RoundingMode.HALF_UP));
        grp.gstPct         = String.valueOf(gstPct.intValue());
        grp.gstAmount      = formatINR(combinedGST.setScale(2, RoundingMode.HALF_UP));
        grp.freight        = freight;
        grp.unitAmount     = formatINR(combinedUnit.setScale(2, RoundingMode.HALF_UP));
        grp.qty            = String.valueOf(poleQty.intValue());
        grp.qtyRaw         = poleQty;
        grp.totalAmount    = formatINR(combinedTotal.setScale(2, RoundingMode.HALF_UP));
        grp.unitRateRaw    = combinedUnitRate.setScale(2, RoundingMode.HALF_UP);
        grp.gstAmountRaw   = combinedGST.setScale(2, RoundingMode.HALF_UP);
        grp.unitAmountRaw  = combinedUnit.setScale(2, RoundingMode.HALF_UP);
        grp.totalAmountRaw = combinedTotal.setScale(2, RoundingMode.HALF_UP);

        System.debug('gstAmount'+ grp.gstAmount +' '+ 'gstAmountRaw'+ grp.gstAmountRaw);
        mastGroups.add(grp);
    }

    // ── Section 2 items ────────────────────────────────────────
    for (Integer n = 1; n <= MAX_REPEATER_COLS; n++) {
        // Base prefix patterns
        String p2Std  = 'c' + n + '_s2_';
        String p2Cus  = 'c' + n + '_s2_cus_op_';
        String lpStd  = 'c' + n + '_lp_';
        String lpCus  = 'c' + n + '_cus_op_';

        // Primary prefix selection based on pole classification
        String p2 = isCustomOctagonal ? p2Cus : p2Std;
        String lp = isCustomOctagonal ? lpCus : lpStd;

        Decimal poleHeight2 = decVal(m, p2 + 'height_of_pole', 
                              decVal(m, p2Std + 'height_of_pole', 
                              decVal(m, p2Cus + 'height_of_pole', 0)));
        if (poleHeight2 == 0) continue;

        String poleType2   = strVal(m, p2 + 'pole_type', strVal(m, p2Cus + 'pole_type', 'Octagonal'));
        String noOfSides2  = strVal(m, p2 + 'no_of_polygonal_side', strVal(m, p2Cus + 'no_of_polygonal_side', '8'));
        String shapeLabel2 = buildShapeLabel(poleType2, noOfSides2);

        Decimal topDia2    = decVal(m, p2 + 'top_diameter', decVal(m, p2Cus + 'top_diameter', 0));
        Decimal botDia2    = decVal(m, p2 + 'bottom_diameter', decVal(m, p2Cus + 'bottom_diameter', 0));
        Decimal segTopLen2 = decVal(m, p2 + 'segment2_top_length', decVal(m, p2Cus + 'segment2_top_length', 0));
        Decimal segBotLen2 = decVal(m, p2 + 'segment1_bottom_length', decVal(m, p2Cus + 'segment1_bottom_length', 0));
        Decimal segTopThk2 = decVal(m, p2 + 'segment2_top_thickness', decVal(m, p2Cus + 'segment2_top_thickness', 0));
        Decimal segBotThk2 = decVal(m, p2 + 'segment1_bottom_thickness', decVal(m, p2Cus + 'segment1_bottom_thickness', 0));
        Decimal overlap2   = decVal(m, p2 + 'overlap', decVal(m, p2Cus + 'overlap', 0));

        String  extraMicron = strVal(m, p2 + 'extra_micron',            strVal(m, p2Cus + 'extra_micron', ''));
        String  puPaintPole = strVal(m, p2 + 'pu_paint_pole_brackets',           strVal(m, p2Cus + 'pu_paint_pole_brackets', ''));
        // SOLAR STRUCTURE description - Deepanjan (6th September 2026). The Custom Octagonal
        // blueprint names this field differently per section: Section 1 has
        // s1_cus_op_solar_structure, Section 2 has s2_cus_op_solar_description. Reading only
        // 'solar_structure' printed the sentence for Section 1 and silently dropped it for
        // Section 2, while the weight formula (which uses the right key) still priced the
        // solar structure - the customer paid for it and the offer never said so.
        // 'solar_structure' stays FIRST in the chain, so every quote that printed before
        // prints exactly as before; only the Section-2 blank is filled.
        String  solarStruct = strVal(m, p2 + 'solar_structure',
                              strVal(m, p2 + 'solar_description',
                              strVal(m, p2Cus + 'solar_structure',
                              strVal(m, p2Cus + 'solar_description', ''))));
        String  batteryBox  = strVal(m, p2 + 'battery_box',             strVal(m, p2Cus + 'battery_box', ''));
        String  laddar  	= strVal(m, p2 + 'ladder_description',             strVal(m, p2Cus + 'ladder_description', ''));
        String 	addDes		= strVal(m, p2 + 'ad_description',             strVal(m, p2Cus + 'ad_description', ''));
        
        Decimal bpSize2 = decVal(m, p2 + 'size_dia_of_base_plate', decVal(m, p2Cus + 'size_dia_of_base_plate', 0));
        Decimal bpThk2  = decVal(m, p2 + 'thickness_of_base_plate', decVal(m, p2Cus + 'thickness_of_base_plate', 0));
        String  bpType2 = strVal(m, p2 + 'base_plate_type', strVal(m, p2Cus + 'base_plate_type', 'Square'));

        String fbDiaRaw2 = strVal(m, p2 + 'foundation_bolt_diameter', strVal(m, p2Cus + 'foundation_bolt_diameter', ''));
        if (fbDiaRaw2.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw2)) {
            fbDiaRaw2 = strVal(m, p2 + 'nr_fb_diameter', strVal(m, p2Cus + 'nr_fb_diameter', ''));
        }
        String  fbDia2    = String.isBlank(fbDiaRaw2) ? '0' : fbDiaRaw2;
        // Same N.R. rule as section 1. Deepanjan (24th Aug 2026)
        Boolean fbNis2    = strVal(m, p2 + 'foundation_bolt_diameter',
                                   strVal(m, p2Cus + 'foundation_bolt_diameter', '')).equalsIgnoreCase('N.R.');
        Decimal fbPcd2    = decVal(m, p2 + 'pcd', decVal(m, p2Cus + 'pcd', 0));
        Decimal fbLen2    = decVal(m, p2 + 'foundation_bolt_length', decVal(m, p2Cus + 'foundation_bolt_length', 0));
        Decimal stdfbQty2 = decVal(m, p2 + 'bolt_quantity', decVal(m, p2Cus + 'bolt_quantity', 0));
        Decimal cusfbQty2 = decVal(m, p2Cus + 'fdn_quantity', 0);
        Decimal octStanQty2  = decval(m, p2 + 'fdn_quantity', 0);
        Decimal fbQty2    = isCustomOctagonal ? cusfbQty2 :isStandardOctagonal ? octStanQty2 :stdfbQty2;
        String  template2 = strVal(m, p2 + 'template', strVal(m, p2Cus + 'template', ''));
        String  boltType2 = template2.toLowerCase().contains('j') ? 'J Type' : 'Standard';

        // Same rule as section 1: no defaults, print only what was entered.
        String bracketType2 = strVal(m, p2 + 'bracket_type', strVal(m, p2Cus + 'bracket_type', ''));
        String typeOfArm2   = strVal(m, p2 + 'type_of_arm', strVal(m, p2Cus + 'type_of_arm', ''));
        String  armdiaod2   = strVal(m, p2 + 'arm_dia_od', strVal(m, p2Cus + 'arm_dia_od', ''));
        String  armlength2   = strVal(m, p2 + 'arm_length', strVal(m, p2Cus + 'arm_length', ''));
        String sleeveLength2 = strVal(m, p2 + 'sleeve_length', strVal(m, p2Cus + 'sleeve_length', ''));
        Decimal brkQty2     = decVal(m, p2 + 'brk_quantity', decVal(m, p2Cus + 'brk_quantity', 0));

        Boolean addFBFlag2 = boolVal(m, p2Cus + 'fdn_ad', false);
        String addFBDes2    = strVal(m, p2Cus + 'fdn_ad_description', '');
        Boolean addBrflag2  = boolVal(m, p2Cus + 'br_ad', false);
        String addBrDes2    = strVal(m, p2Cus + 'br_ad_description', '');

        Decimal poleQty2 = decVal(m, lp + 's2_quantity', 
                           decVal(m, p2 + 'quantity', 
                           decVal(m, 'c' + n + '_s2_quantity',
                           decVal(m, 'c' + n + 'cus_op_s1_quantity', 
                           decVal(m, 'c' + n + '_op_s2_quantity', 1)))));
        if (poleQty2 == 0) poleQty2 = 1;

        Decimal segUnitPrice2 = decVal(m, lp + 's2_segment_unit_price',
                                decVal(m, 'c' + n + '_lp_segment2_unit_price',
                                decVal(m, 'c' + n + '_op_segment2_unit_price',
                                decVal(m, 'c' + n + '_cus_op_s2_segment_unit_price', 0))));

        Decimal fbnUnitPrice2 = decVal(m, 'c' + n + '_op_foundation2_unit_price',
                                decVal(m, 'c' + n + '_cus_op_foundation2_unit_price', 
                                decVal(m, 'c' + n + '_cus_op_s2_foundation_unit_price',
                                decVal(m, 'c' + n + '_lp_foundation2_unit_price', 0))));

        Decimal brkUnitPrice2 = decVal(m, 'c' + n + '_op_bracket2_unit_price',
                                decVal(m, 'c' + n + '_cus_op_bracket2_unit_price', 
                                decVal(m, 'c' + n + '_lp_bracket2_unit_price', 
                                decVal(m, 'c' + n + '_cus_op_s2_bracket_unit_price', 0))));
                                
        // ── Standardized Calculation Logic ──────────────────────────
        Decimal adjustedSegUnitPrice2 = perPolfrieght ? segUnitPrice2 + perPolTPCharg : segUnitPrice2;
        Decimal roundedSegUnitPrice2 = adjustedSegUnitPrice2.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedFbnUnitPrice2 = fbnUnitPrice2.setScale(2, RoundingMode.HALF_UP);
        Decimal roundedBrkUnitPrice2 = brkUnitPrice2.setScale(2, RoundingMode.HALF_UP);

        Decimal combinedUnitRate2 = (roundedSegUnitPrice2 + roundedFbnUnitPrice2  + roundedBrkUnitPrice2 );

        // Calculate GST per unit type individually with half-up rounding, then sum total GST
        Decimal segGST2 = (roundedSegUnitPrice2 * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal fbnGST2 = (roundedFbnUnitPrice2 * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal brkGST2 = (roundedBrkUnitPrice2 * gstPct / 100).setScale(2, RoundingMode.HALF_UP);

        Decimal combinedGST2   = (segGST2  + fbnGST2  + brkGST2 ).setScale(2, RoundingMode.HALF_UP);
        combinedUnitRate2 = combinedUnitRate2.setScale(2, RoundingMode.HALF_UP);
        combinedGST2      = combinedGST2.setScale(2, RoundingMode.HALF_UP);

        Decimal combinedUnit2  = combinedUnitRate2 + combinedGST2;
        Decimal combinedTotal2 = (combinedUnit2 * poleQty2).setScale(2, RoundingMode.HALF_UP);

        System.debug('segUnitPrice2 --> ' + segUnitPrice2);
        System.debug('adjustedSegUnitPrice2 --> ' + adjustedSegUnitPrice2);
        System.debug('poleQty2 --> ' + poleQty2);
        System.debug('fbnUnitPrice2 --> ' + fbnUnitPrice2);
        System.debug('fbQty2 --> ' + fbQty2);
        System.debug('brkUnitPrice2 --> ' + brkUnitPrice2);
        System.debug('brkQty2 --> ' + brkQty2);
        System.debug('combinedGST2 --> ' + combinedGST2);
        System.debug('combinedTotal2 --> ' + combinedTotal2);

        String descPole2 =
            'Supply of ' + poleHeight2 + ' MTR '
            + shapeLabel2 + ' Pole as per Dimension: '
            + 'Top Dia. - ' + topDia2.intValue() + ' mm, '
            + 'Bottom Dia. - ' + botDia2.intValue() + ' mm, '
            + 'Section - 2 '
            + '(Top Segment Length - ' + segTopLen2.intValue() + ' mm, '
            + 'Bottom Segment Length - ' + segBotLen2.intValue() + ' mm'
            //+ (overlap2 > 0 ? ', Overlap - ' + overlap2.intValue() + ' mm' : '') + '), '
            + 'Thickness - ' + segTopThk2.intValue() + ' mm (Top) / '
            + segBotThk2.intValue() + ' mm (Bottom). '
            + buildBasePlateDesc(bpType2, bpSize2, bpThk2) 
            + (extraMicron != '' ? ', with ' + extraMicron + ' micron'                : '')
            + (puPaintPole != '' ? '. PU Paint: ' + puPaintPole                    : '')
            + (solarStruct != '' ? '. Solar Structure: ' + solarStruct             : '')
            + (batteryBox  != '' ? '. Battery Box: ' + batteryBox                  : '')
            + (laddar  != '' ? '. Laddar: ' + laddar                  : '')
            + (addDes      != '' ? '. Additional Item: ' + addDes                 : '')
            +'.';

        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            descPole2 += suffix;
        }

        String descBolt2 = fbNis2
                         ? ''
                         : ( 'J Type Bolts M' + fbDia2 + ' x ' + fbLen2.intValue() + 'mm (' + fbQty2.intValue() + ' Nos.)'
                         + (addFBFlag2 ? ' ' + addFBDes2 : ''));

        Decimal fbNisQty2 = decVal(m, p2 + 'bolt_quantity',
                            decVal(m, p2Cus + 'bolt_quantity',
                            decVal(m, p2 + 'fdn_quantity',
                            decVal(m, p2Cus + 'fdn_quantity', 0))));
        if (fbNisQty2 <= 0) fbNisQty2 = fbQty2;
        if (fbNis2) {
            descPole2 += ' ' + fdnNotInScopeDesc(fbDia2, fbLen2, fbNisQty2, fbPcd2)
                .replace('\u0001FDN_NIS_ON\u0001', '<span class="desc-bolt" style="color:#c00000;font-weight:bold;">')
                .replace('\u0001FDN_NIS_OFF\u0001', '</span>');
        }
        
        Boolean hasArms2 = String.isNotBlank(typeOfArm2) && !typeOfArm2.equalsIgnoreCase('0') && !typeOfArm2.equalsIgnoreCase('N/A');
        // Same rule as section 1: the sentence needs a real bracket, not the '1' default
        // on NO. OF ARM. Deepanjan (24th Aug 2026)
        Boolean showBracket2 = (String.isNotBlank(bracketType2) && !'N.R.'.equalsIgnoreCase(bracketType2.trim()));
        // Same two rules as section 1. Deepanjan (24th Aug 2026)
        String brkLabel2 = bracketLabel(m, bracketType2, p2, p2Cus);
        String armTxt2   = armWord(typeOfArm2);
        String  armNumber2 = armNumtoWord(typeOfArm2);
        String brkPUDesc = strVal(m, p2Cus + + 'pu_paint_br_desc', '');
        String brkCusDesc = strVal(m, p2Cus + + 'customized_description', '');
        String brkRingDesc = strVal(m, p2Cus + + 'ring_description', '');
        Boolean brkPuFlag = boolVal(m, p2Cus + 'pu_paint_checkbox', false);
        
        String descBrk2 = showBracket2 
        ? (brkLabel2 
            + (hasArms2 
                ? ((typeOfArm2 != null && typeOfArm2.isNumeric() 
                    ? (' ' + armTxt2 + ' arm bracket.') 
                      + (String.isNotBlank(armlength2) ? (' ' + armlength2 + ' mm long on ' + armNumber2 + ' side with ') : '')
                      + (String.isNotBlank(armdiaod2) ? (armdiaod2 + ' OD GI Pipe , ') : '')
                      + (String.isNotBlank(sleeveLength2) ? (sleeveLength2 + 'mm Sleeve') : '')
                    : (' ' + armTxt2 + ' bracket')
                      + (String.isNotBlank(brkRingDesc) ? (' ' + brkRingDesc + '.') : ''))
                    )
                : '.')
            + (addBrflag2 && String.isNotBlank(addBrDes2) ? (' ' + addBrDes2) : '')
            + (brkPuFlag && String.isNotBlank(brkPUDesc) ? (' PU Paint : ' + brkPUDesc + '.') : '')) 
        : '';

        System.debug('line 1591 : '+ descBrk2 +' arm length: '+ armlength2 + ' armdiaOd : '+armdiaod2);

        // ── Field Assignments Aligned with cmCollapseSlice ──
        MastGroupWrapper grp2 = new MastGroupWrapper();
        grp2.slNo           = String.valueOf(slCounter++);
        grp2.descMast       = descPole2;
        grp2.descBolt       = descBolt2;
        grp2.descAcc        = descBrk2;
        grp2.unitRate       = formatINR(combinedUnitRate2.setScale(2, RoundingMode.HALF_UP));
        grp2.gstPct         = String.valueOf(gstPct.intValue());
        grp2.gstAmount      = formatINR(combinedGST2.setScale(2, RoundingMode.HALF_UP));
        grp2.freight        = freight;
        grp2.unitAmount     = formatINR(combinedUnit2.setScale(2, RoundingMode.HALF_UP));
        grp2.qty            = String.valueOf(poleQty2.intValue());
        grp2.qtyRaw         = poleQty2;
        grp2.totalAmount    = formatINR(combinedTotal2.setScale(2, RoundingMode.HALF_UP));
        grp2.unitRateRaw    = combinedUnitRate2.setScale(2, RoundingMode.HALF_UP);
        grp2.gstAmountRaw   = combinedGST2.setScale(2, RoundingMode.HALF_UP);
        grp2.unitAmountRaw  = combinedUnit2.setScale(2, RoundingMode.HALF_UP);
        grp2.totalAmountRaw = combinedTotal2.setScale(2, RoundingMode.HALF_UP);

        mastGroups.add(grp2);
    }

    appendLumpSumFreightGroup(m, gstPct, freight, slCounter);

    if (mastGroups.isEmpty()) {
        MastGroupWrapper grp = new MastGroupWrapper();
        grp.slNo = '1'; 
        grp.descMast = 'Supply of LIGHTING POLE (please verify quote configuration).';
        grp.descBolt = ''; 
        grp.descAcc = ''; 
        grp.unitRate = '0';
        grp.gstPct = String.valueOf(gstPct.intValue()); 
        grp.gstAmount = '0';
        grp.freight = freight; 
        grp.unitAmount = '0'; 
        grp.qty = '1'; 
        grp.qtyRaw = 1;
        grp.totalAmount = '0';
        grp.unitRateRaw = 0; 
        grp.gstAmountRaw = 0; 
        grp.unitAmountRaw = 0; 
        grp.totalAmountRaw = 0;
        mastGroups.add(grp);
    }
}
 
    // ═══════════════════════════════════════════════════════════════
    //  HIGH MAST — original logic
    // ═══════════════════════════════════════════════════════════════
    private void buildHighMastGroups(Map<String,Object> m,
                                      Decimal gstPct, String freight) {
        Integer slCounter = 1;
 
        for (Integer mast = 1; mast <= 10; mast++) {
            String p   = 'r' + mast + '_';
            String kit = 'kit_line_' + mast + '_';
 
            Decimal mastHeight = decVal(m, p + 'lm_height_of_mast', 0);
            if (mastHeight == 0) continue;
 
            Decimal segCount   = decVal(m, p + 'lm_no_of_segment',      1);
            // TOP DIA: seg 1 uses lm_1_oaf_top, seg 2..N use the top segment's OAF top - Reetabrata (8th July 2026)
            Decimal topDia     = (segCount.intValue() <= 1) ? decVal(m, p + 'lm_1_oaf_top', 0) : decVal(m, p + 'lm_' + segCount.intValue() + '_top_oaf_top', 0);
            // BOTTOM DIA: seg 1 uses lm_1_oaf_bottom, seg 2..N use the bottom segment's OAF bottom - Reetabrata (8th July 2026)
            Decimal botDia     = (segCount.intValue() <= 1) ? decVal(m, p + 'lm_1_oaf_bottom', 0) : decVal(m, p + 'lm_bot' + segCount.intValue() + '_oaf_bot', 0);
 
            String  lenList    = buildSegmentLengthList(m, p, segCount.intValue());
            String  thkList    = buildSegmentThicknessList(m, p, segCount.intValue());
            Decimal lastBotDia = botDia; // BOTTOM DIA now correct for all segment counts - Reetabrata (8th July 2026)
 
            Decimal bpOD  = decVal(m, p + 'lm_od_of_base_plate',        0);
            Decimal bpThk = decVal(m, p + 'lm_thickness_of_base_plate', 0);
            Decimal pcd   = decVal(m, p + 'lm_pcd',                     0);
 
            // null stays null - no invented 24/850/6 in the offer. Deepanjan (20th Aug 2026)
            String  boltDia   = strVal(m, p + 'lm_fdn_bolt_dia',    '');
            Decimal boltLen   = decVal(m, p + 'lm_fdn_bolt_length',  0);
            Decimal noOfBolts = decVal(m, p + 'lm_fdn_no_of_bolt',     0);

            Decimal qty       = decVal(m, p + 'lm_quantity',        1);
 
            Decimal mastUnitPrice = 0;
            for (Integer s = 1; s <= segCount.intValue(); s++) { // Reetabrata (8th July 2026)
                mastUnitPrice += decVal(m, p + 'lm_' + s + '_unit_price', 0);
            }
            if (mastUnitPrice == 0) mastUnitPrice = decVal(m, p + 'lm_1_unit_price', 0);
            
            mastUnitPrice = perPolfrieght ? mastUnitPrice + perPolTPCharg : mastUnitPrice;

             // Changes for bug UIL-HM-143 
            Decimal latchingDeviceRate = decVal(m, 'lm_lc_rate',        0);
            String latchDeviceDes = '';
            if(isLatchingMast && latchingDeviceRate > 0){
                latchDeviceDes = 'with Latching Device ';
                mastUnitPrice += latchingDeviceRate;
            }

            /*
             * LCLM ONLY. The Lightning Spike and Down Conductor are already named
             * inside the mast description ("with the following items: ... Lightning
             * Spike, Down Conductor Fixing Arrangement ..."), and the estimator
             * prices them on their own keys, but neither amount was ever reaching
             * the offer - the quote carried lm_spike_unit_price / lm_dc_unit_price
             * while this rate only summed the segments, so the money was dropped.
             * Folding them into the mast rate keeps the document layout exactly as
             * it is and just makes the figure complete. Row key first, bare key
             * fallback, same as every other seg5 read. Every other mast type has
             * neither key, so this adds 0 and nothing changes for them.
             * Deepanjan (10th August 2026)
             */
            if (isLCLM) {
                mastUnitPrice += rowDec(m, p, 'lm_spike_unit_price', 0)
                               + rowDec(m, p, 'lm_dc_unit_price',    0);
            }
            // adding special desc 
            Boolean hasSpecialDesc    = siBoolVal(jsonData, p + 'lm_is_special_desc');
            String  specialDescClause = '';
            if (hasSpecialDesc) {
                String  specialDescText  = strVal(jsonData, p + 'lm_special_desc_text', '');
                Decimal specialDescPrice = decVal(jsonData, p + 'lm_special_desc_unitPrice', 0);
                if (String.isNotBlank(specialDescText)) {
                    specialDescClause = ' Special : ' + specialDescText + '.';
                }
                mastUnitPrice += specialDescPrice;
            }

            // PU PAINT is no longer added here. Since 8 Sep 2026 the realized PU Paint rate is
            // part of lm_{s}_unit_price itself (segmentGenerator.js, same rule as the normal LCLM
            // blueprint), so the segment sum above already carries it. The 4 Sep Apex fold
            // charged it a second time and was removed. Deepanjan (8th September 2026)


            Decimal boltUnitPrice = decVal(m, p + 'lm_fdn_unit_price', 0);
 
            // Segment Above 5 writes lm_* keys and must NOT inherit the legacy hm_* defaults.
            //  - Reetabrata (9th July 2026)
            Boolean isSegAbove5 = segCount >= 6;
 
            Decimal noOfLum    = decVal(jsonData, kit + 'lm_no_of_luminaries',
                                  decVal(jsonData, p + 'hm_no_of_luminaries',
                                  decVal(jsonData, 'hm_no_of_luminaries',
                                  decVal(jsonData, p + 'lm_no_of_luminaries',
                                  decVal(jsonData, 'lm_no_of_luminaries', 6)))));
            Decimal weldedArms = decVal(jsonData, kit + 'lm_type_of_welded_arm',
                                  decVal(jsonData, p + 'hm_no_of_welded_arms',
                                  decVal(jsonData, 'hm_no_of_welded_arms',
                                  decVal(jsonData, p + 'lm_type_of_welded_arm',
                                  decVal(jsonData, 'lm_type_of_welded_arm', 6)))));
            String  lumType  = accSpecRaw(jsonData, kit, p, 'hm_type_of_luminaries', 'lm_type_of_luminaries', 'Symmetric');

            String suspRaw   = accSpecRaw(jsonData, kit, p, 'hm_suspension_system', 'lm_suspension_system', '3= 3 suspension');
            String suspNum   = suspRaw.contains('=') ? suspRaw.substringBefore('=').trim() : '3';
            
            String cableSpec = specOrBlank(accSpecRaw(jsonData, kit, p, 'hm_cable_type', 'lm_cable_type',
                                                      isSegAbove5 ? '' : 'T=2.5 SQmm 5Core'));
            String cableSets = codeOrBlank(accSpecRaw(jsonData, kit, p, 'hm_no_of_cable', 'lm_no_of_cable',
                                                      isSegAbove5 ? '' : '1=Single cable'));
            
            String winchSpec = withDrum(withUnit(
                                 specOrBlank(accSpecRaw(jsonData, kit, p, 'hm_type_of_winch', 'lm_type_of_winch',
                                                      isSegAbove5 ? '' : 'E=350 kg')).replace(' kg', 'Kg').replace(' KG', 'Kg'),
                                 isSegAbove5 ? accSpecRaw(jsonData, kit, p, 'lm_winch_unit', 'lm_winch_unit', '') : ''),
                                 isSegAbove5 ? accSpecRaw(jsonData, kit, p, 'lm_winch_drum', 'lm_winch_drum', '') : '');
            String toolSpec  = withUnit(
                                 specOrBlank(accSpecRaw(jsonData, kit, p, 'hm_type_of_power_tool', 'lm_type_of_power_tool',
                                                      isSegAbove5 ? '' : 'G=Motor,3PH')),
                                 isSegAbove5 ? accSpecRaw(jsonData, kit, p, 'lm_power_tool_unit', 'lm_power_tool_unit', '') : '');
            String ropeSpec  = withUnit(
                                 specOrBlank(accSpecRaw(jsonData, kit, p, 'hm_wire_rope', 'lm_type_of_wire_rope',
                             isSegAbove5 ? '' : '5=5mm dia')),
                                 isSegAbove5 ? accSpecRaw(jsonData, kit, p, 'lm_wire_rope_unit', 'lm_wire_rope_unit', '') : '');
            Decimal accUnitPrice = 0;
            if (segCount == 1) {
                accUnitPrice = decVal(m, kit + 'lm_kit_unit_price', 0);
            } else if (segCount == 2) {
                accUnitPrice = decVal(m, kit + 'lm_' + segCount.intValue() + '_kit_unit_price', 0);
            } else if (segCount >= 6) {
                // SEGMENT ABOVE 5: accessories price is the Additional Accessories -> TOTAL RATE
                // (= RATE + RATE * REALIZATION / 100), entered/derived in the Weight Estimator.
                // Row-prefixed key wins; unprefixed is the section default. Falls back to the raw

                //  - Reetabrata (9th July 2026)
                accUnitPrice = decVal(m, p + 'lm_acc_total_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(m, 'lm_acc_total_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(m, p + 'lm_acc_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(m, 'lm_acc_rate', 0);
            } else if (segCount >= 3) {
                accUnitPrice = decVal(m, kit + 'lm_3_kit_unit_price', 0);
            }
 
            String descMast =
                'Supply of ' + mastHeight + ' MTRS '
                + + (isLCLM ? 'LCLM' : (isSignageMast ? signageMastName() : (isLatchingMast ? 'LATCHING MAST' : (isCustomLightningMast ? 'CUSTOM LIGHTNING MAST' : 'LIGHTING MAST')))) + ' '   // CLM branch: Faizan (24th July 2026) + ' '   // Reetabrata (15th July 2026) // Signage branch: Reetabrata (16th July 2026)
                + 'FABRICATED AS PER DIMENSION :. '
                + 'TOP DIA - ' + topDia.intValue() + ' mm, '
                + 'BOTTOM DIA - ' + lastBotDia.intValue() + ' mm, '
                + 'SECTION - ' + segCount.intValue() + ' '
                + '(SECTION LENGTH - ' + lenList + 'mm) '
                + 'THICKNESS - ' + thkList + ' mm. '
                + 'BASE PLATE - ' + bpOD.intValue() + 'mm x ' + bpThk.intValue() + 'mm, '
                + 'PCD - ' + pcd.intValue() + 'mm, '
                + 'with the following items: High Mast sections with base plate, '
                + 'Lantern carriage suitable to fix ' + noOfLum.intValue()
                + ' nos. of LED Luminaries ' + lumType
                + ' in ' + weldedArms.intValue() + ' welded arm, '
                + suspNum + ' suspension Head frame, '
                + latchDeviceDes
                + 'L-Stopper , Mounting Plates, '    // updated  'L-Stopper (' + suspNum + ' Nos.)' to 'L-Stopper' for bug UIL-HM-134
                // Only the arrestor phrase differs for LCLM. Reetabrata (15th July 2026)
                + (isLCLM ? lclmSpikeClause(p) : 'Lighting Arrestor')  
                + ' (MS GI).'  // updated ' Lighting Arrestor and Earthing Spikes (MS GI)' to 'Lighting Arrestor (MS GI)' for bug UIL-HM-136
                // Segment Above 5 lets the user add an extra-micron spec and a PU paint note.
                // Both are galvanising / finish specs rather than separate goods, so they read
                // as one more sentence of this same paragraph. The helper returns '' when
                // neither was entered, which leaves this description byte-identical to before
                // for every quote that does not use them. Reetabrata (15th July 2026)
                + micronPaintClause(p)
                + specialDescClause
                // CUSTOM LIGHTNING MAST ONLY - same shared helper, same row prefix and the
                // same jsonData the Single Scope reads, so the Combined Scope prints exactly
                // the same sentence. Returns '' for every other mast type, so their combined
                // descriptions are byte-identical to before. Faizan (24th July 2026)
                + (isCustomLightningMast
                     ? HighMastSOWController.buildSpecialAdditionsClause(m, p) : '');

            Decimal adRate = 0;
            String singageSpecAdd = '';

            if(isSignageMast){

                Decimal adUnit = decVal(m, p + 'lm_ad_unit_price',  0);
                String  adDesc = strVal(m, p + 'lm_ad_description', '');
                String s_a_d = '';
                System.debug('adUnit --> '+adUnit +'| adDesc --> '+adDesc );
                if (adUnit > 0 && String.isNotBlank(adDesc)) {
                    adRate = adUnit;
                    s_a_d += '\u0002_SINGAGE_MAST_ADD_DES\u0002';
                    singageSpecAdd = adDesc;
                }

                descMast =
                'Supply of ' + mastHeight + ' MTRS '
                + signageMastName() + ' '   // separator - without it the name ran
                                            // straight into FABRICATED, e.g.
                                            // "LIGHTNENING MASTFABRICATED".
                                            // The general branch above already had
                                            // it. Deepanjan (19th Aug 2026)
                + 'FABRICATED AS PER DIMENSION :. '
                + 'TOP DIA - ' + topDia.intValue() + ' mm, '
                + 'BOTTOM DIA - ' + lastBotDia.intValue() + ' mm, '
                + 'SECTION - ' + segCount.intValue() + ' '
                + '(SECTION LENGTH - ' + lenList + 'mm) '
                + 'THICKNESS - ' + thkList + ' mm. '
                + 'BASE PLATE - ' + bpOD.intValue() + 'mm x ' + bpThk.intValue() + 'mm, '
                + 'PCD - ' + pcd.intValue() + 'mm, '
                + 'with the following items: High Mast sections with base plate & Lighting Arrestor '
                + s_a_d
                + micronPaintClause(p);

            }


            // ─── SPECIAL ITEM, 'Show separate in offer' UNTICKED ─── Deepanjan (4th September 2026)
            // The estimator has already folded the VALUE into lm_{n}_unit_price through the
            // hidden lm_si_price_add / lm_si_weight_add formulas, so the money is correct - but
            // the typed ITEM DESCRIPTION was printed nowhere at all. TEXT ONLY here; adding the
            // rate again would double-charge. Same sentence cmStadiumGroups has always printed
            // for Stadium (its "siHas && !siSep" branch), which is why Stadium never showed it.
            if (siHasRow(m, p) && !showSpecialItemSeparatelyRow(m, p)) {
                descMast += ' SPECIAL ITEM: ' + specialItemDescriptionRow(m, p) + '.';
            }

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descMast += suffix;
            }

            // Blank + rate 0 when "Without Foundation", or when the section was never
            // filled in (the 24/850/6 defaults are gone). The VF page hides the whole
            // clause on a blank descBolt. Deepanjan (20th Aug 2026)
            String descBolt = '';
            if (fdnSuppressed(m, p)) {
                // "Without Foundation": rate 0 and the out-of-scope sentence, appended
                // to descMast so it goes through the escape pass below and needs no VF
                // change (descBolt would get the page's hardcoded "Supply of FOUNDATION
                // BOLTS - " label in front of it). Deepanjan (21st Aug 2026)
                boltUnitPrice = 0;
                descMast += ' ' + fdnNotInScopeDesc(boltDia, boltLen, noOfBolts, pcd);
            } else if (boltUnitPrice <= 0 && noOfBolts <= 0) {
                boltUnitPrice = 0;
            } else {
                descBolt =
                    'M ' + boltDia + ' x ' + boltLen.intValue() +'mm'
                    + ' (' + noOfBolts.intValue() + ' Nos.) with Template and Anchor Plate.';
            }
                
            // Blank => the VF page's rendered="{!grp.descAcc != ''}" hides the whole clause.
            //  - Reetabrata (9th July 2026)
            String descAcc = '';
            // Segment Above 5: the RATE is optional, the specification is not. A row that
            // carries winch / power tool / wire rope / cable specs, or has OPTIONAL ELECTRICAL
            // ITEMS ticked, but no RATE printed nothing at all - the whole ACCESSORIES PART
            // sentence vanished (Q 00001324). It now prints at rate 0, exactly as the
            // Without-Foundation bolt line already does. Deepanjan (9th September 2026)
            Boolean accSpecOnly = isSegmentAbove5 == true && isSegAbove5 && accUnitPrice <= 0
                && (String.isNotBlank(winchSpec) || String.isNotBlank(toolSpec)
                    || String.isNotBlank(ropeSpec) || String.isNotBlank(cableSpec)
                    || hasOptionalElectricalItems(m, kit, p));
            
            if (accUnitPrice > 0 || accSpecOnly){
                Boolean hasOptElec       = hasOptionalElectricalItems(m, kit, p);
                String  aolVal           = hasOptElec ? optElecVal(m, kit, p, 'lm_type_of_aol') : '';
                String  controlSwitchVal = hasOptElec ? optElecVal(m, kit, p, 'lm_no_of_aviation_light') : '';
                String  feederPillarVal  = hasOptElec ? optElecVal(m, kit, p, 'lm_feeder_piller_control') : '';
                //descAcc = buildAccessoriesDesc(false, mastHeight, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec);
                // call overloaded method
                descAcc = buildAccessoriesDesc(false, mastHeight, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec,
                                               hasOptElec, aolVal, controlSwitchVal, feederPillarVal);
            }
            
            //System.debug('totalPoleQty --> ' + totalPoleQty);
            if (isCustomLightningMast || isLatchingMast) {
                System.debug('isCustomLightningMast --> '+isCustomLightningMast + ' | isLatchingMast --> '+isLatchingMast);
                Decimal adUnit = decVal(m, p + 'lm_ad_unit_price',  0);
                String  adDesc = strVal(m, p + 'lm_ad_description', '');

                System.debug('adUnit --> '+adUnit +'| adDesc --> '+adDesc );
                if (adUnit > 0 && String.isNotBlank(adDesc)) {
                    adRate = adUnit;
                    descMast += '\u0001_ADD_DES\u0001' + adDesc.trim() + '.';
                }
            }

			System.debug('mastUnitPrice --> '+ mastUnitPrice + ' | boltUnitPrice --> '+ boltUnitPrice + ' | accUnitPrice --> '+accUnitPrice+' |adRate --> '+adRate +' | Qty --> ' + qty);
            // COMBINED QUANTITY - Deepanjan (22nd Aug 2026)
            // Was: every component multiplied by qty and grp.qty hardcoded to '1', so the
            // offer showed "Unit Rate = the whole lot, Qty 1" whatever quantity was entered.
            // Now the rate is per unit and the real quantity is printed, exactly the way
            // buildLightingPoleGroups (Octagonal Pole) and buildTransmissionPoleGroups
            // already do it. Every component here shares the SAME qty, so the total is
            // algebraically identical: (Sum rate)xq + (Sum gst)xq == (Sum rate + Sum gst)xq.
            Decimal cmQty = qty;
            if (cmQty == null || cmQty <= 0) cmQty = 1;

            // ── PER-COMPONENT MONEY THROUGH cmLineMoney ── Deepanjan (5th September 2026)
            // GST is derived from each rounded component rate, then the four GST values are
            // summed. This keeps the Single and Combined scope totals aligned without any
            // separate payment-term interest factor being applied inside the calculation.
            Decimal[] mastMny = cmLineMoney(mastUnitPrice, gstPct);
            Decimal[] boltMny = cmLineMoney(boltUnitPrice, gstPct);
            Decimal[] accMny  = cmLineMoney(accUnitPrice,  gstPct);
            Decimal[] adMny   = cmLineMoney(adRate,        gstPct);
            Decimal combinedUnitRate = mastMny[0] + boltMny[0] + accMny[0] + adMny[0];
            Decimal combinedGST      = mastMny[1] + boltMny[1] + accMny[1] + adMny[1];

            Decimal combinedUnit     = combinedUnitRate + combinedGST;
            Decimal combinedTotal    = (combinedUnit * cmQty).setScale(2, RoundingMode.HALF_UP);

 			System.debug('combinedUnit --> '+ combinedUnit);
            System.debug('combinedTotal --> '+ combinedTotal);
            
            String d = (descMast == null ? '' : descMast);
            d = d.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
            d = d.replace('\u0001_ADD_DES\u0001',' <br/><br/><span style="font-weight:bold;"> Supply of ADDITIONAL ITEM - </span>');
            // "Without Foundation" out-of-scope sentence - own block, whole line red.
            // desc-bolt is display:block in the page CSS, so it sits under the mast
            // text exactly where the bolt clause used to. Deepanjan (21st Aug 2026)
            d = d.replace('\u0001FDN_NIS_ON\u0001', '<span class="desc-bolt" style="color:#c00000;font-weight:bold;">');
            
            d = d.replace('\u0001FDN_NIS_OFF\u0001', '</span>');
            if(singageSpecAdd != null){
                d = d.replace('\u0002_SINGAGE_MAST_ADD_DES\u0002','<span style="color: red; font-weight: bold;">' + singageSpecAdd + '</span>');
            }

            MastGroupWrapper grp = new MastGroupWrapper();
            grp.slNo           = String.valueOf(slCounter++);
            grp.descMast       = d;
            grp.descBolt       = descBolt;
            grp.descAcc        = descAcc;
            // Segment Above 5: the page's bold label is blank (constructor), so the bold head
            // comes from the group - same text Single prints, height included, styling kept.
            // Split on ' ACCESSORIES PART:'; when the string has no head (nothing priced) both
            // stay as they are. Deepanjan (7th September 2026)
            grp.descAccHead    = '';
            if (isSegmentAbove5 == true && String.isNotBlank(descAcc)) {
                Integer cut = descAcc.indexOf(' ACCESSORIES PART:');
                if (cut > 0) {
                    cut += ' ACCESSORIES PART:'.length();
                    grp.descAccHead = descAcc.substring(0, cut) + ' ';
                    grp.descAcc     = descAcc.substring(cut).trim();
                }
            }
            grp.unitRate       = formatINR(combinedUnitRate.setScale(2, RoundingMode.HALF_UP));
            grp.gstPct         = String.valueOf(gstPct.intValue());
            grp.gstAmount      = formatINR(combinedGST);
            grp.freight        = freight;
            grp.unitAmount     = formatINR(combinedUnit);
            grp.qty            = String.valueOf(cmQty.intValue());
            grp.qtyRaw         = cmQty;            // was never set here - cmCollapseSlice needs it
            grp.totalAmount    = formatINR(combinedTotal);
            grp.unitRateRaw    = combinedUnitRate;
            grp.gstAmountRaw   = combinedGST;
            grp.unitAmountRaw  = combinedUnit;
            grp.totalAmountRaw = combinedTotal;
            grp.boltDia        = boltDia;
            // Per-row SPECIAL ITEM (27-Jul per-row sections): folded into THIS
            // row's group, exactly like the legacy fold below did for the last
            // group. Silent for legacy quotes (no r{n}_ keys); the legacy block
            // below is silent for new quotes (no bare keys). Deepanjan (27th July 2026)
            if (showSpecialItemSeparatelyRow(m, p)) {
                // QUANTITY-AWARE FOLD - Deepanjan (22nd Aug 2026). These blocks used to add a
                // once-per-quote charge to a WHOLE-LOT rate on a group whose qty was hardcoded 1,
                // so total = unit was right. The group now carries a per-unit rate and the real
                // quantity, so the whole-lot figure is rebuilt first, the charge added there, and
                // the result divided back out - total comes to the identical rupee as before.
                // PER-MAST, not once-per-quote - Deepanjan (4th September 2026). The charge
                // used to be added to the WHOLE-LOT figure once (+ rSiRate), which is what the
                // Single scope's hardcoded qty 1 did. Both now carry the row's own quantity, so
                // the two documents still come to the identical rupee.
                // ── PER-COMPONENT GST ── Deepanjan (4th September 2026)
                // Segment Above 5 special items keep their own row price, but each component's
                // GST is still derived from the rounded per-component rate before the final fold.
                // This keeps the total consistent with the Single Scope version without any
                // separate interest-factor adjustment.
                Decimal[] rSiMny  = cmLineMoney(specialItemUnitRateRow(m, p), gstPct);
                Decimal rQty      = (grp.qtyRaw == null || grp.qtyRaw <= 0) ? 1 : grp.qtyRaw;
                Decimal rWhole    = (grp.unitRateRaw  + rSiMny[0]) * rQty;
                Decimal rWholeGST = (grp.gstAmountRaw + rSiMny[1]) * rQty;
                Decimal rNewRate = rWhole    / rQty;
                Decimal rNewGST  = rWholeGST / rQty;
                Decimal rNewUnit = rNewRate + rNewGST;
                Decimal rNewTot  = (rNewUnit * rQty).setScale(2, RoundingMode.HALF_UP);
                grp.descSpecial    = specialItemDescriptionRow(m, p);
                grp.unitRate       = formatINR2(rNewRate);
                grp.gstAmount      = formatINR2(rNewGST);
                grp.unitAmount     = formatINR2(rNewUnit);
                grp.totalAmount    = formatINR(rNewTot);
                grp.unitRateRaw    = rNewRate;
                grp.gstAmountRaw   = rNewGST;
                grp.unitAmountRaw  = rNewUnit;
                grp.totalAmountRaw = rNewTot;
            }
 
            mastGroups.add(grp);
        }
 
        // SPECIAL ITEMS: folded into the LAST mast group as a 4th description line,
        // its price added to that group's combined rate. Shown once per quote, only
        // when ticked. - Reetabrata (9th July 2026)
        if (!mastGroups.isEmpty() && showSpecialItemSeparately(m)) {
            MastGroupWrapper lastGrp = mastGroups[mastGroups.size() - 1];
            Decimal siRate   = specialItemUnitRate(m);
            // See the QUANTITY-AWARE FOLD note above. Deepanjan (22nd Aug 2026)
            Decimal sQty     = (lastGrp.qtyRaw == null || lastGrp.qtyRaw <= 0) ? 1 : lastGrp.qtyRaw;
            Decimal sWhole   = (lastGrp.unitRateRaw * sQty) + siRate;
            Decimal sWholeG  = (sWhole * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
            Decimal newRate  = sWhole  / sQty;
            Decimal newGST   = sWholeG / sQty;
            Decimal newUnit  = newRate + newGST;
            Decimal newTotal = (newUnit * sQty).setScale(2, RoundingMode.HALF_UP);
 
            lastGrp.descSpecial    = specialItemDescription(m);
            lastGrp.unitRate       = formatINR2(newRate);
            lastGrp.gstAmount      = formatINR2(newGST);
            lastGrp.unitAmount     = formatINR2(newUnit);
            lastGrp.totalAmount    = formatINR(newTotal);
            lastGrp.unitRateRaw    = newRate;
            lastGrp.gstAmountRaw   = newGST;
            lastGrp.unitAmountRaw  = newUnit;
            lastGrp.totalAmountRaw = newTotal;
        }
 
        // ADDITIONAL DETAILS: Signage Mast only. Folded into the LAST mast group as one more
        // description line, its price added to that group's combined rate - the same shape
        // SPECIAL ITEMS uses just above.
        //
        // Text and price both land on the SAME single group on purpose. The lm_ad_* keys are
        // unprefixed - the estimator saves one set per quote, not one per mast row - so a
        // quote with three masts must still show the line once and charge it once.
        //
        // Every other mast type leaves those keys absent, so both helpers return empty and
        // no group's description, rate or total moves. Reetabrata (16th July 2026)
        if (!mastGroups.isEmpty()) {
            String  adDesc = additionalDetailDesc(m);
            Decimal adRate = additionalDetailRate(m, gstPct);
            if (String.isNotBlank(adDesc) && adRate > 0) {
                MastGroupWrapper adGrp = mastGroups[mastGroups.size() - 1];
                // See the QUANTITY-AWARE FOLD note above. Deepanjan (22nd Aug 2026)
                Decimal aQty       = (adGrp.qtyRaw == null || adGrp.qtyRaw <= 0) ? 1 : adGrp.qtyRaw;
                Decimal aWhole     = (adGrp.unitRateRaw * aQty) + adRate;
                Decimal aWholeG    = (aWhole * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
                Decimal adNewRate  = aWhole  / aQty;
                Decimal adNewGST   = aWholeG / aQty;
                Decimal adNewUnit  = adNewRate + adNewGST;
                Decimal adNewTotal = (adNewUnit * aQty).setScale(2, RoundingMode.HALF_UP);
 
                adGrp.descAdditional = adDesc;
                adGrp.unitRate       = formatINR2(adNewRate);
                adGrp.gstAmount      = formatINR2(adNewGST);
                adGrp.unitAmount     = formatINR2(adNewUnit);
                adGrp.totalAmount    = formatINR(adNewTotal);
                adGrp.unitRateRaw    = adNewRate;
                adGrp.gstAmountRaw   = adNewGST;
                adGrp.unitAmountRaw  = adNewUnit;
                adGrp.totalAmountRaw = adNewTotal;
            }
        }
 
        // COSTING OF LATCHING: Latching Mast only, its OWN group row - not folded into a mast
        // group the way ADDITIONAL DETAILS is above, because it is a standalone charge.
        //
        // cmGroup() applies GST to the rate it is handed, and lm_lc_rate is stored GST-free
        // (the estimator's lm_lc_unit_price carries the 1.18 for display only), so no division
        // is needed here.
        //
        // The lm_lc_* keys are unprefixed (one set per quote), so this runs once, after the
        // row loop. Guarded by isLatchingMast, false for every other mast type, so no existing
        // offer gains a group. Reetabrata (16th July 2026)
        
        
        // Changes for bug UIL-HM-143
        // if (isLatchingMast && !mastGroups.isEmpty()) {
        //     Decimal lcRate = decVal(m, 'lm_lc_rate', 0);
        //     if (lcRate > 0) {
        //         Decimal lcQty = decVal(m, 'lm_lc_quantity', 1);
        //         if (lcQty <= 0) lcQty = 1;
        //         mastGroups.add(cmGroup(String.valueOf(slCounter++), 'Costing of Latching.', '',
        //                        lcRate, gstPct, lcQty, freight));
        //     }
        // }
 
        appendLumpSumFreightGroup(m, gstPct, freight, slCounter);
 
        if (mastGroups.isEmpty()) {
            Decimal fr = decVal(jsonData, 'r1_lm_1_unit_price', 0);
            Decimal fg = (fr * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
            Decimal fu = fr + fg;
            MastGroupWrapper grp = new MastGroupWrapper();
            grp.slNo = '1'; grp.descMast = 'Supply of LIGHTING MAST (please verify quote configuration).';
            grp.descBolt = ''; grp.descAcc = ''; grp.unitRate = formatINR(fr.setScale(2, RoundingMode.HALF_UP));
            grp.gstPct = String.valueOf(gstPct.intValue()); grp.gstAmount = formatINR(fg);
            grp.freight = strVal(jsonData, 'freight_incoterms', 'Ex-works');
            grp.unitAmount = formatINR(fu); grp.qty = '1'; grp.totalAmount = formatINR(fu);
            grp.unitRateRaw = fr; grp.gstAmountRaw = fg; grp.unitAmountRaw = fu; grp.totalAmountRaw = fu;
            mastGroups.add(grp);
        }
    }
 
    // ═══════════════════════════════════════════════════════════════
    //  HELPER METHODS
    // ═══════════════════════════════════════════════════════════════
    private String buildShapeLabel(String poleType, String noOfSides) {
        if (String.isBlank(poleType)) return 'GI Octagonal';
        String pt = poleType.trim();
        if (pt.equalsIgnoreCase('Conical')) return 'GI Conical';
        if (pt.equalsIgnoreCase('Polygonal') || pt.equalsIgnoreCase('Octagonal')) {
            String sides = String.isBlank(noOfSides) ? '8' : noOfSides.trim();
            if (sides == '8') return 'GI Octagonal';
            return 'GI ' + sides + '-Sided Polygonal';
        }
        return 'GI ' + pt;
    }
 
    private String buildBasePlateDesc(String bpType, Decimal bpSize, Decimal bpThk) {
        String sz = String.valueOf(bpSize.intValue());
        String th = String.valueOf(bpThk.intValue());
        if (bpType != null && bpType.equalsIgnoreCase('Circular'))
            return 'Base Plate- Dia ' + sz + ' x ' + th + ' mm';
        return 'Base Plate- ' + sz + ' x ' + sz + ' x ' + th + ' mm';
    }
 
    private String buildBearingPlateDesc(String bpType, Decimal bpSize, Decimal bpThk) {
        String sz = String.valueOf(bpSize.intValue());
        String th = String.valueOf(bpThk.intValue());
        if (bpType != null && bpType.equalsIgnoreCase('Circular'))
            return 'Bearing Plate- Dia ' + sz + ' x ' + th + ' mm';
        return 'Bearing Plate- ' + sz + ' x ' + sz + ' x ' + th + ' mm';
    }
 
    // segment length/thickness by physical position (1=top, 2..N-1=middle, N=bottom); override value wins when entered - Reetabrata (8th July 2026)
    private Decimal segAttr(Map<String,Object> m, String p, Integer segCount, Integer s, String attr) {
        if (segCount <= 1) return decVal(m, p + 'lm_1_' + attr, 0);
        if (s == 1)        return decVal(m, p + 'lm_' + segCount + '_top_' + attr, 0);
        String seg = (s >= segCount) ? 'bot' + segCount : 'mid' + s;
        Decimal ovr = decVal(m, p + 'lm_ovr_' + seg + '_' + attr, 0);
        if (ovr != 0) return ovr;
        return decVal(m, p + 'lm_' + seg + '_' + attr, 0);
    }
 
    private String buildSegmentLengthList(Map<String,Object> m, String p, Integer segCount) {
        List<String> parts = new List<String>();
        for (Integer s = 1; s <= segCount; s++) {
            Decimal len = segAttr(m, p, segCount, s, 'length');
            if (len > 0) parts.add(String.valueOf(len.intValue()));
        }
        return parts.isEmpty() ? '0' : String.join(parts, ' / ');
    }
 
    private String buildSegmentThicknessList(Map<String,Object> m, String p, Integer segCount) {
        List<String> parts = new List<String>();
        for (Integer s = 1; s <= segCount; s++) {
            Decimal thk = segAttr(m, p, segCount, s, 'thickness');
            if (thk > 0) parts.add(String.valueOf(thk.intValue()));
        }
        return parts.isEmpty() ? '0' : String.join(parts, ', ');
    }
 
    private Decimal lastSegmentBottomDia(Map<String,Object> m, String p,
                                         Integer segCount, Decimal fallback) {
        for (Integer s = segCount; s >= 1; s--) {
            Decimal bot = decVal(m, p + 'lm_' + s + '_oaf_bottom', 0);
            if (bot > 0) return bot;
        }
        return fallback;
    }
 
    private void appendLumpSumFreightGroup(Map<String,Object> m, Decimal gstPct,
                                            String freight, Integer slCounter) {
        String transportAs = strVal(m, 'transportation_as', '');
        System.debug('transportAs --> '+transportAs);
        if (!transportAs.equalsIgnoreCase('Lump sum')) return;
 
        Decimal lumpSum = decVal(m, 'transportation_charges', 0);
        System.debug('lumpSum --> '+lumpSum);
        if (lumpSum <= 0) return;
        Decimal fGst  = (lumpSum * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal fUnit = lumpSum + fGst;
        Decimal fTot  = fUnit.setScale(2, RoundingMode.HALF_UP);
        System.debug('fGst --> '+fGst +' | fUnit --> '+fUnit +' | fTot --> '+fTot);                                 
        MastGroupWrapper fg = new MastGroupWrapper();
        fg.slNo           = String.valueOf(slCounter);
        fg.descMast       = 'Transportation Charges ';
        fg.descBolt       = '';
        fg.descAcc        = '';
        fg.unitRate       = formatINR(lumpSum.setScale(2, RoundingMode.HALF_UP));
        fg.gstPct         = String.valueOf(gstPct.intValue());
        fg.gstAmount      = formatINR(fGst);
        fg.freight        = freight;
        fg.unitAmount     = formatINR(fUnit.setScale(2, RoundingMode.HALF_UP));
        fg.qty            = '1';
        fg.totalAmount    = formatINR(fTot);
        fg.unitRateRaw    = lumpSum;
        fg.gstAmountRaw   = fGst;
        fg.unitAmountRaw  = fUnit;
        fg.totalAmountRaw = fTot;
        mastGroups.add(fg);
    }
 
    private List<Object> getList(Map<String, Object> m, String key) {
        if (!m.containsKey(key) || m.get(key) == null) return new List<Object>();
        try { return (List<Object>) m.get(key); }
        catch (Exception e) { return new List<Object>(); }
    }
 
    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key) || jsonData.get(key) == null
                || String.isBlank(String.valueOf(jsonData.get(key))))
            jsonData.put(key, defaultValue);
    }
 
    private Decimal decVal(Map<String, Object> m, String key, Decimal def) {
        if (!m.containsKey(key) || m.get(key) == null) return def;
        try {
            String s = String.valueOf(m.get(key)).trim();
            if (String.isBlank(s)) return def;
            return Decimal.valueOf(s);
        } catch (Exception e) { return def; }
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // SPECIAL ITEMS - LIGHTING MAST (SEGMENT ABOVE 5) - Reetabrata (9th July 2026)
    // ───────────────────────────────────────────────────────────────────────
    // The Weight Estimator stores ONE unprefixed Special Item per quote:
    //   lm_si_type ('Price' | 'Weight'), lm_si_description, lm_si_value,
    //   lm_si_show_separate (checkbox).
    //
    // When "Show separate in offer" is UNTICKED, the LWC has already folded the
    // value into lm_N_unit_price / lm_N_segment_weight via the hidden formulas
    // lm_si_price_add and lm_si_weight_add. Apex therefore adds NOTHING in that
    // case - adding it again would double-count.
    //
    // When it is TICKED, lm_si_price_add / lm_si_weight_add evaluate to 0 and
    // the item is shown as its own entry at the end of the offer:
    //   TYPE = Price  -> unit rate is the value exactly as entered
    //   TYPE = Weight -> unit rate is BASE PRICE (per kg) x the value
    //
    // Absent keys (any mast other than Segment Above 5) => guard is false and
    // nothing at all is emitted, so existing offers are unchanged.
    // ═══════════════════════════════════════════════════════════════════════
    private Boolean siBoolVal(Map<String,Object> m, String key) {
        if (m == null || !m.containsKey(key) || m.get(key) == null) return false;
        Object v = m.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim();
        return s.equalsIgnoreCase('true') || s == '1';
    }
 
    private Boolean showSpecialItemSeparately(Map<String,Object> m) {
        if (!siBoolVal(m, 'lm_si_show_separate')) return false;
        return String.isNotBlank(strVal(m, 'lm_si_type', ''));
    }
 
    private String specialItemDescription(Map<String,Object> m) {
        String d = strVal(m, 'lm_si_description', '');
        return String.isBlank(d) ? 'Special Item' : d;
    }
 
    // BASE PRICE per kg, as persisted by the estimator (lm_N_base_price = Base_Amount__c).
    // Base_Amount__c is not on the Quote SOQL, so the evaluated value is read back
    // from the saved JSON. Falls back to the foundation, then to segment 1.
    // Stadium Special Item rate per kg: the sub-mast's own realized rate, exactly what
    // mrl_swd_display_unit_price / lwc_ladder_cage_unit_price price the mast at
    // (Stadium carries realization as a PERCENT). base_amount alone has no realization
    // in it, which is what made the item come out short.
    //
    // No mast-type branch here - both callers are gated on isSegmentAbove5, so this is
    // only ever reached from Segment Above 5. Deepanjan (19th Aug 2026)
    private Decimal stadiumSiRatePerKg(Map<String,Object> m, String p) {
        // WAS: base_amount + realization. mrl_realization / lwc_realization are type:"hidden"
        // in segmentGenerator.js and the estimator never saves a hidden field, so that term
        // read 0 on every quote - the item went out at the bare base rate. amount_realization
        // is the same figure, is visible, and does persist. Deepanjan (21st Aug 2026)
        Decimal withRealz = decVal(m, p + 'amount_realization', 0);
        if (withRealz > 0) return withRealz;
        // Fallbacks, both of which DO persist: the sub-mast's own base price field, then
        // the legacy base_amount key. base_amount itself is being hidden in the estimator
        // (it duplicates BASE MAN RIDING PRICE / LADDER WITH CAGE BASE PRICE on screen),
        // so it can no longer be the only source. Deepanjan (21st Aug 2026)
        Decimal basePrice = decVal(m, p == 'mrl_' ? 'mrl_man_riding_base_price'
                                                  : 'lwc_ladder_cage_base_price', 0);
        return basePrice > 0 ? basePrice : decVal(m, p + 'base_amount', 0);
    }

    private Decimal specialItemBasePricePerKg(Map<String,Object> m) {
        for (Integer r = 1; r <= 10; r++) {
            String p = 'r' + r + '_';
            Integer seg = decVal(m, p + 'lm_no_of_segment', 0).intValue();
            if (seg > 0) {
                Decimal bp = decVal(m, p + 'lm_' + seg + '_base_price', 0);
                if (bp > 0) return bp;
            }
            Decimal fbp = decVal(m, p + 'lm_fdn_base_price', 0);
            if (fbp > 0) return fbp;
            Decimal sbp = decVal(m, p + 'lm_1_base_price', 0);
            if (sbp > 0) return sbp;
        }
        return 0;
    }
 
    // TYPE = Weight prices the item at VALUE kg x the quote's TOTAL PRICE (/KG),
    // the same rate a segment is priced at. It used to use the BASE PRICE, which is
    // Base_Amount__c with no realization - on Qno 00001135 that made a 10 kg item
    // 105 x 10 = 1,050 instead of 110 x 10 = 1,100. Deepanjan (19th Aug 2026)
    //
    // Special Items exist only on the Segment Above 5 recipe today; any other recipe
    // keeps the old base-price rate. TYPE = Price returns the typed value as-is.
    private Decimal specialItemUnitRate(Map<String,Object> m) {
        Decimal val = decVal(m, 'lm_si_value', 0);
        if (strVal(m, 'lm_si_type', '').equalsIgnoreCase('Weight')) {
            if (isSegmentAbove5) return decVal(m, 'lm_total_price', 0) * val;
            return specialItemBasePricePerKg(m) * val;
        }
        return val;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PER-ROW READS - Deepanjan (27th July 2026)
    // Since 27-Jul the Segment Above 5 estimator repeats Special Items,
    // Extra Micron & PU Paint (and for LCLM the Spike / Down Conductor
    // sections) PER MAST ROW, saving r{n}_lm_* keys - the bare lm_* keys no
    // longer exist on new quotes, which is why they vanished from the PDFs.
    // Every reader below tries the row key FIRST and falls back to the bare
    // key, so legacy quotes keep printing exactly what they always printed.
    // ═══════════════════════════════════════════════════════════════════════
    private String rowStr(Map<String,Object> m, String p, String key, String def) {
        String v = strVal(m, p + key, '');
        return String.isNotBlank(v) ? v : strVal(m, key, def);
    }
    private Decimal rowDec(Map<String,Object> m, String p, String key, Decimal def) {
        Decimal v = decVal(m, p + key, 0);
        return (v != 0) ? v : decVal(m, key, def);
    }
    private Boolean rowBool(Map<String,Object> m, String p, String key) {
        return siBoolVal(m, p + key) || siBoolVal(m, key);
    }

    // Does this row carry a Special Item at all (ticked or not)? Companion to
    // showSpecialItemSeparatelyRow, which answers "and is it shown on its own line".
    // Deepanjan (4th September 2026)
    private Boolean siHasRow(Map<String,Object> m, String p) {
        return String.isNotBlank(strVal(m, p + 'lm_si_type', ''));
    }

    private Boolean showSpecialItemSeparatelyRow(Map<String,Object> m, String p) {
        if (!siBoolVal(m, p + 'lm_si_show_separate')) return false;
        return String.isNotBlank(strVal(m, p + 'lm_si_type', ''));
    }
    private String specialItemDescriptionRow(Map<String,Object> m, String p) {
        String d = strVal(m, p + 'lm_si_description', '');
        return String.isBlank(d) ? 'Special Item' : d;
    }
    private Decimal specialItemUnitRateRow(Map<String,Object> m, String p) {
        Decimal val = decVal(m, p + 'lm_si_value', 0);
        if (strVal(m, p + 'lm_si_type', '').equalsIgnoreCase('Weight')) {
            // Segment Above 5: VALUE kg x TOTAL PRICE (/KG). The mast type decides
            // it, full stop - a zero rate means the quote's own TOTAL PRICE is zero
            // and the item is worth zero, not that some other rate should stand in.
            // Deepanjan (19th Aug 2026)
            if (isSegmentAbove5) return rowDec(m, p, 'lm_total_price', 0) * val;

            // every other recipe - old behaviour below, unchanged
            // this row's base price first, then the shared cross-row hunt
            Decimal bp = decVal(m, p + 'lm_fdn_base_price', 0);
            if (bp == 0) {
                Integer seg = decVal(m, p + 'lm_no_of_segment', 0).intValue();
                if (seg > 0) bp = decVal(m, p + 'lm_' + seg + '_base_price', 0);
            }
            if (bp == 0) bp = specialItemBasePricePerKg(m);
            return bp * val;
        }
        return val;
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // ACCESSORY SPEC RESOLUTION - Reetabrata (9th July 2026)
    // The Segment Above 5 estimator saves its "Additional Accessories" picklists as
    // lm_* keys. Every other mast type saves hm_*. This reads hm_* FIRST so existing
    // masts behave exactly as before, then falls back to lm_*.
    // Legacy hardcoded defaults are applied ONLY to hm_* masts: for Segment Above 5 a
    // blank picklist means "omit the clause", never "print 350Kg".
    // ═══════════════════════════════════════════════════════════════════════
    private String accSpecRaw(Map<String,Object> m, String p, String hmKey, String lmKey, String def) {
        String v = strVal(m, p + hmKey, '');
        if (String.isBlank(v)) v = strVal(m, hmKey, '');
        if (String.isBlank(v)) v = strVal(m, p + lmKey, '');
        if (String.isBlank(v)) v = strVal(m, lmKey, '');
        return String.isBlank(v) ? def : v;
    }
 
    // Returns the spec after '='. Blank when unset or explicitly not-applicable
    // ('X=NA', '0=NA', 'X'), so the clause is dropped from the description.
    /* Unit box beside TYPE OF WINCH / POWER TOOL / WIRE ROPE - Deepanjan (21st Aug 2026).
       Those three are free-text now, so the unit lives in its own disabled box in
       the UI (lm_winch_unit KG, lm_power_tool_unit HP, lm_wire_rope_unit "mm Dia")
       and has to be appended here: user types 500 -> offer reads "500 KG".
       An older quote has no unit key at all and already carries the unit inside its
       CODE=Description value, so unit comes back blank and its offer text is left
       byte-identical. X / NA suppression is untouched - specOrBlank still returns
       '' for those and this returns '' with it, so the whole clause still drops. */
    private String withUnit(String spec, String unit) {
        if (String.isBlank(spec)) return '';
        if (String.isBlank(unit)) return spec;
        String u = unit.trim();
        // Already there? Test the unit's FIRST word, so "8mm" is not turned into
        // "8 mm Dia mm" and "500KG" is left alone.
        String uHead = u.contains(' ') ? u.substringBefore(' ') : u;
        if (spec.containsIgnoreCase(uHead)) return spec;
        // The unit belongs right after the NUMBER, not at the end of the clause:
        // "500 DGDD" has to read "500 KG DGDD", not "500 DGDD KG".
        Matcher mNum = Pattern.compile('^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(.*)$').matcher(spec);
        if (mNum.matches()) {
            String num  = mNum.group(1);
            String rest = mNum.group(2).trim();
            return String.isBlank(rest) ? num + ' ' + u : num + ' ' + u + ' ' + rest;
        }
        return spec + ' ' + u;   // no leading number - just append
    }

    /* Drum type (SGDD / DGDD) picked from its own box beside TYPE OF WINCH -
       Deepanjan (21st Aug 2026). Kept separate from withUnit so the unit still
       lands right after the number and the drum type goes last:
       "1500" + "KG" + "DGDD" -> "1500 KG DGDD". Blank drum adds nothing, and a
       drum already present in the typed text is not repeated. */
    private String withDrum(String spec, String drum) {
        if (String.isBlank(spec)) return '';
        if (String.isBlank(drum)) return spec;
        String d = drum.trim();
        if (spec.containsIgnoreCase(d)) return spec;
        return spec + ' ' + d;
    }

    private String specOrBlank(String raw) {
        if (String.isBlank(raw)) return '';
        Boolean hasEq = raw.contains('=');
        String code = hasEq ? raw.substringBefore('=').trim() : '';
        String spec = hasEq ? raw.substringAfter('=').trim() : raw.trim();
        if (code.equalsIgnoreCase('X') || spec.equalsIgnoreCase('NA')) return '';
        return spec;
    }
 
    // Same, but returns the code before '=' (used for "no. of cable sets").
    private String codeOrBlank(String raw) {
        if (String.isBlank(raw)) return '';
        Boolean hasEq = raw.contains('=');
        String code = hasEq ? raw.substringBefore('=').trim() : raw.trim();
        String spec = hasEq ? raw.substringAfter('=').trim() : '';
        if (code.equalsIgnoreCase('X') || spec.equalsIgnoreCase('NA')) return '';
        return code;
    }
 

    // ═══════════════════════════════════════════════════════════════════════
    // SIGNAGE MAST - CUSTOM NAME  (Deepanjan, 18th Aug 2026)
    //
    // The estimator carries a YES/NO picklist sm_rename and a text sm_rename_value that
    // only opens on YES - declared exactly like the wind_speed / wind_speed_value pair
    // that already works in this same Section Logic record. When it is set to YES and a
    // name is typed, that name prints wherever SIGNAGE MAST
    // would have printed - description lines, the SUB-TOTAL heading and the weight
    // sheet title.
    //
    // NOTHING else moves: no flag, no builder route, no rate, weight or formula.
    // isSignageMast stays true, so every calculation runs exactly as it does today
    // and only the printed words change.
    //
    // Not ticked, blank name, or a legacy quote with no sm_rename key at all - all
    // three return 'SIGNAGE MAST', so existing offers are byte-identical.
    // ═══════════════════════════════════════════════════════════════════════
    private String signageMastName() {
        if (!isSignageMast) return 'SIGNAGE MAST';
        if (!'YES'.equalsIgnoreCase(strVal(jsonData, 'sm_rename', 'NO'))) return 'SIGNAGE MAST';
        String nm = strVal(jsonData, 'sm_rename_value', '');
        return String.isBlank(nm) ? 'SIGNAGE MAST' : nm.trim().toUpperCase();
    }

    // Builds the accessories description, omitting any component that is unset or NA.
    private String buildAccessoriesDesc(Boolean withSupplyOf, Decimal mastHeight, String winchSpec,
                                        String toolSpec, String ropeSpec, String cableSets, String cableSpec) {
        String d = (withSupplyOf ? 'Supply of ' : '')
                 + mastHeight + ' MTR '
                 + (isLCLM ? 'LCLM' : (isSignageMast ? signageMastName() : (isLatchingMast ? 'LATCHING MAST' : 'LIGHTING MAST'))) + ' ACCESSORIES PART:';   // Reetabrata (15th July 2026) // Signage branch: Reetabrata (16th July 2026)
        if (String.isNotBlank(winchSpec)) d += ' Double Drum Winch ' + winchSpec;
        if (String.isNotBlank(toolSpec))  d += ', ' + toolSpec; // updated 'Power Tool Motor with torque limiter' to 'Motor' for UIL-HM-137
        if (String.isNotBlank(ropeSpec))  d += ', ' + ropeSpec + ' SS Wire Rope, Manual Operating Handle';
        if (String.isNotBlank(cableSpec) && String.isNotBlank(cableSets)) {
            d += ' Trailing Cable (' + cableSets + ' Sets ' + cableSpec + '. EPR PCP Sheathed Round Coated Copper Cable.';
        }
        d += ' with GI JB (without luminaries, AOL, Control Switch & Feeder Pillar).';
        return d;
    }
    
     // method to check option electrical line item selected for kit code - rajeev 26-08
    // OPTIONAL ELECTRICAL ITEMS on the ROW - Deepanjan (6th September 2026)
    // rowPfx was accepted but never read. Segment Above 5 keeps the optional electrical
    // items inside its own accessories section, saved on the row (r{n}_lm_optional_
    // electrical_items / _type_of_aol / _no_of_aviation_light / _feeder_piller_control),
    // not in a KIT line - so for every seg5 mast hasOptElec came back false and the offer
    // printed "(without luminaries, AOL, Control Switch & Feeder Pillar)" while the
    // customer had ticked them (Q 00001316). KIT is still consulted FIRST, then the row,
    // so normal Lighting Mast (optional items in the KIT modal) is unchanged; callers
    // that pass rowPfx = '' are unchanged too.
    private Boolean hasOptionalElectricalItems(Map<String,Object> m, String kitPfx, String rowPfx) {
        if (String.isNotBlank(kitPfx) && m.containsKey(kitPfx + 'lm_optional_electrical_items')) {
            return siBoolVal(m, kitPfx + 'lm_optional_electrical_items');
        }
        if (String.isNotBlank(rowPfx) && m.containsKey(rowPfx + 'lm_optional_electrical_items')) {
            return siBoolVal(m, rowPfx + 'lm_optional_electrical_items');
        }
        return false;
    }
    
    private String optElecVal(Map<String,Object> m, String kitPfx, String rowPfx, String key) {
        if (String.isNotBlank(kitPfx)) {
            String v = strVal(m, kitPfx + key, '');
            if (String.isNotBlank(v)) return v;
        }
        // the row's own value (Segment Above 5) - Deepanjan (6th September 2026)
        if (String.isNotBlank(rowPfx)) {
            String v = strVal(m, rowPfx + key, '');
            if (String.isNotBlank(v)) return v;
        }
        return strVal(m, key, '');
    }
    
    // OPTIONAL ELECTRICAL ITEMS wording for Segment Above 5 (Q 00001316) - Deepanjan (7th September 2026)
    // Now identical in shape to the KIT branch in buildAccessoriesDesc: picked items LEAD
    // the clause by name, everything else falls in after "without luminaries", and
    // luminaries always sits inside the bracket. Deepanjan (11th September 2026)
    //
    // FEEDER PILLAR and CONTROL SWITCH both come off the ONE feeder_piller_control
    // picklist, so its code decides both:
    //   X...  ("X=NA", "X=Neither fidder piller nor control piller") -> neither supplied
    //   0...  ("0=No fidder piller needed")                          -> Control Switch only
    //   any other code                                               -> Feeder Pillar only
    // AOL is its own field and follows the plain X rule.
    //
    //   AOL + feeder picked : " AOL & Feeder Pillar with GI JB (without luminaries, Control Switch)."
    //   AOL only, code 0    : " AOL & Control Switch with GI JB (without luminaries, Feeder Pillar)."
    //   AOL only, code X    : " AOL with GI JB (without luminaries, Feeder Pillar & Control Switch)."
    //   none picked         : " with GI JB (without luminaries, AOL, Feeder Pillar & Control Switch)."
    private String seg5OptElecClause(String aolValue, String controlSwitchValue, String feederPillarValue) {
        List<String> leadItems    = new List<String>();
        List<String> withoutItems = new List<String>{ 'luminaries' };

        if (String.isNotBlank(aolValue) && !aolValue.trim().startsWithIgnoreCase('X')) {
            leadItems.add('AOL');
        } else {
            withoutItems.add('AOL');
        }

        String fpCode = String.isBlank(feederPillarValue) ? 'X' : feederPillarValue.trim().toUpperCase();

        if (fpCode.startsWith('X')) {
            withoutItems.add('Feeder Pillar');
            withoutItems.add('Control Switch');
        } else if (fpCode.startsWith('0')) {
            leadItems.add('Control Switch');
            withoutItems.add('Feeder Pillar');
        } else {
            leadItems.add('Feeder Pillar');
            withoutItems.add('Control Switch');
        }

        String d = ' ';
        if (!leadItems.isEmpty()) d += optElecJoin(leadItems) + ' ';
        d += 'with GI JB (without ' + optElecJoin(withoutItems) + ').';
        return d;
    }

    // A selection counts only when it is non-blank and its code is not X (NA) or 0 (none):
    // "X= NA", "X=NA", "X=Neither fidder piller nor control piller", "0=No fidder piller needed".
    private Boolean optElecPicked(String v) {
        if (String.isBlank(v)) return false;
        String code = v.trim().toUpperCase();
        return !(code.startsWith('X') || code.startsWith('0'));
    }

    // "A", "A & B", "A, B & C"
    private String optElecJoin(List<String> items) {
        if (items.size() == 1) return items[0];
        List<String> head = new List<String>(items);
        String last = head.remove(head.size() - 1);
        return String.join(head, ', ') + ' & ' + last;
    }

   	// New buildAccessoriesDesc overload method with optional electric items for consideration.
   	private String buildAccessoriesDesc(Boolean withSupplyOf, Decimal mastHeight, String winchSpec,
                                        String toolSpec, String ropeSpec, String cableSets, String cableSpec,
                                        Boolean hasOptionalElectrical, String aolValue,
                                        String controlSwitchValue, String feederPillarValue) {
        // Combined, Segment Above 5 (withSupplyOf = false and isSegmentAbove5): print the same
        // head Single prints - "Supply of 60 MTR LIGHTING MAST ACCESSORIES PART:" - and the
        // page's document-level accessoriesLabel is blanked for seg5 in the constructor, so the
        // label no longer appears twice (Q 00007764). Normal Lighting Mast / LCLM / Signage /
        // Latching keep the label + headless string they had. Deepanjan (7th September 2026)
        Boolean seg5Head = (!withSupplyOf && isSegmentAbove5 == true);
        String d = ((withSupplyOf || seg5Head) ? 'Supply of ' : '')
                 + mastHeight + ' MTR '
                 + (isLCLM ? 'LCLM' : (isSignageMast ? signageMastName() : (isLatchingMast ? 'LATCHING MAST' : 'LIGHTING MAST'))) + ' ACCESSORIES PART:';   // Reetabrata (15th July 2026) // Signage branch: Reetabrata (16th July 2026)
        if (String.isNotBlank(winchSpec)) d += ' Double Drum Winch ' + winchSpec;
        if (String.isNotBlank(toolSpec))  d += ', ' + toolSpec;   // updated 'Power Tool Motor with torque limiter' to 'Motor' for UIL-HM-137
        if (String.isNotBlank(ropeSpec))  d += ', ' + ropeSpec + ' SS Wire Rope, Manual Operating Handle';
        if (String.isNotBlank(cableSpec) && String.isNotBlank(cableSets)) {
            d += ' Trailing Cable (' + cableSets + ' Sets ' + cableSpec + '. EPR PCP Sheathed Round Coated Copper Cable';
        }
        if (hasOptionalElectrical == true && isSegmentAbove5 == true) {
            // Segment Above 5 wording - picked items outside the bracket, the rest inside.
            // Normal Lighting Mast / Stadium (KIT path) keep the branch below. Q 00001316.
            // Deepanjan (7th September 2026)
            d += seg5OptElecClause(aolValue, controlSwitchValue, feederPillarValue);
        } else                 if (hasOptionalElectrical == true) {
            // Feeder Pillar and Control Switch both come off the ONE feeder_piller_control
            // picklist, so its code decides both:
            //   X... ("X=NA", "X=Neither fidder piller nor control piller") -> neither supplied
            //   0... ("0=No fidder piller needed")                          -> Control Switch only
            //   anything else                                              -> Feeder Pillar only
            // AOL is its own field and follows the plain X rule.
            // Deepanjan (9th September 2026)
            List<String> leadItems    = new List<String>();
            List<String> withoutItems = new List<String>{ 'luminaries' };

            if (String.isNotBlank(aolValue) && !aolValue.trim().startsWithIgnoreCase('X')) {
                leadItems.add('AOL');
            } else {
                withoutItems.add('AOL');
            }

            String fpCode = String.isBlank(feederPillarValue) ? 'X' : feederPillarValue.trim().toUpperCase();

            if (fpCode.startsWith('X')) {
                withoutItems.add('Feeder Pillar');
                withoutItems.add('Control Switch');
            } else if (fpCode.startsWith('0')) {
                leadItems.add('Control Switch');
                withoutItems.add('Feeder Pillar');
            } else {
                leadItems.add('Feeder Pillar');
                withoutItems.add('Control Switch');
            }

            d += ' ';
            if (!leadItems.isEmpty()) d += optElecJoin(leadItems) + ' ';
            d += 'with GI JB (without ' + optElecJoin(withoutItems) + ').';
        } else {
            d += ' with GI JB (without luminaries, AOL, Control Switch & Feeder Pillar).';
        }
        return d;
    }
 
 
    // ═══════════════════════════════════════════════════════════════════════
    //  CUSTOMIZED MAST — STADIUM MAST / FLAG MAST
    //  Reuses the class's own strVal / decVal / formatINR /
    //  appendLumpSumFreightGroup. Unreachable for any pre-existing quote.
    // ═══════════════════════════════════════════════════════════════════════
    private static final Integer CM_MAX_COLS = 10;
 
    private void buildCustomizedMastGroups(Map<String,Object> m,
                                            Decimal gstPct, String freight) {
        Integer sl = 1;
 
        if (isStadiumMast) {
            // Each prefix is one product: mrl_ is the mast with its Man Rider and
            // accessories, lwc_ is the mast with its foundation bolts and ladder.
            // Deepanjan (18th August 2026)
            if (cmBool(m, 'man_riding_lift'))  { cmProductStart.add(mastGroups.size()); sl = cmStadiumGroups(m, gstPct, freight, sl, 'mrl_'); }
            if (cmBool(m, 'ladder_with_cage')) { cmProductStart.add(mastGroups.size()); sl = cmStadiumGroups(m, gstPct, freight, sl, 'lwc_'); }
        } else if (isFlagMast) {
            // SEGMENT ABOVE 5 recipe: r{n}_lm_* rows. cmFlagGroups() reads
            // r{n}_fm_* and would emit nothing. Deepanjan (22nd July 2026)
            //
            // A Flag Mast quote can carry SEVERAL masts (r1_, r2_ ... each with its
            // own fm_height_of_mast), so the product boundary cannot be opened once
            // here - that made the whole department collapse into a single line item
            // numbered 1. Each builder opens one per populated row instead, plus one
            // for the once-per-quote sections. Deepanjan (19th Aug 2026)
            sl = isSeg5FlagMast
                ? cmSeg5FlagGroups(m, gstPct, freight, sl)
                : cmFlagGroups(m, gstPct, freight, sl);
        }
 
        // Stadium / Flag present each product as ONE line item. Until 18 Aug 2026 this
        // collapsed EVERY group into a single line item, which is why a two product quote
        // printed one row numbered 1. It now collapses each product's own slice, so two
        // products give two line items. Reached only from here, so no other mast type is
        // affected. Deepanjan (16th July 2026, per-product 18th August 2026)
        cmCollapsePerProduct(gstPct, freight);
        sl = mastGroups.size() + 1;
 
        appendLumpSumFreightGroup(m, gstPct, freight, sl);
 
        if (mastGroups.isEmpty()) {
            mastGroups.add(cmGroup('1',
                'Supply of CUSTOMIZED MAST (please verify quote configuration).',
                '', 0, gstPct, 1, freight));
        }
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOMIZED MAST - collapse every Stadium / Flag group into a SINGLE line item.
    //
    // Runs AFTER the builders, so each group's description and rate are produced by
    // the existing untouched logic and only the presentation is merged here. It also
    // runs BEFORE appendLumpSumFreightGroup, so Transportation Charges stay their own
    // line - it is not a mast line item.
    //
    // DESCRIPTION: only descMast and descBolt are ever populated on this path (cmGroup
    // hardcodes descAcc = '' and never touches descSpecial / descAdditional), so those
    // three slots need no handling. descMast is already escaped by cmGroup and renders
    // escape="false"; descBolt is raw and is normally escaped by the VF page, so it is
    // escaped HERE before being folded into descMast. The original block spans and the
    // page's "Supply of FOUNDATION BOLTS - " label are reproduced so the merged cell
    // lays out exactly as the separate rows did.
    //
    // RATE: when every group shares one quantity, that quantity is kept and the rates
    // are simply added - the common case, and nothing is lost. When they differ there
    // is no single honest quantity, so each rate is weighted by its own quantity and
    // the line goes out as qty 1, which preserves the money.
    // Deepanjan (16th July 2026)
    // ═══════════════════════════════════════════════════════════════════════
    /* Collapses each product's slice of mastGroups into one line item. With a single
       product this behaves exactly as the old whole-list collapse did.
       Deepanjan (18th August 2026) */
    private void cmCollapsePerProduct(Decimal gstPct, String freight) {
        if (mastGroups.size() <= 1) return;
        if (cmProductStart.isEmpty()) cmProductStart.add(0);

        List<MastGroupWrapper> collapsed = new List<MastGroupWrapper>();
        for (Integer i = 0; i < cmProductStart.size(); i++) {
            // 'from' is a reserved word in Apex, hence startIdx / endIdx.
            // Deepanjan (18th August 2026)
            Integer startIdx = cmProductStart[i];
            Integer endIdx   = (i + 1 < cmProductStart.size())
                             ? cmProductStart[i + 1] : mastGroups.size();
            if (startIdx >= mastGroups.size() || endIdx <= startIdx) continue;

            List<MastGroupWrapper> slice = new List<MastGroupWrapper>();
            for (Integer k = startIdx; k < endIdx; k++) slice.add(mastGroups[k]);

            collapsed.add(cmCollapseSlice(slice, gstPct, freight));
        }

        if (!collapsed.isEmpty()) {
            mastGroups.clear();
            mastGroups.addAll(collapsed);
        }
    }

    /* The original whole-list collapse, unchanged apart from working on the slice it is
       handed and returning the merged group instead of rewriting mastGroups.
       Deepanjan (16th July 2026, made slice-aware 18th August 2026) */
    private MastGroupWrapper cmCollapseSlice(List<MastGroupWrapper> slice,
                                             Decimal gstPct, String freight) {
        if (slice.size() == 1) return slice[0];

        Decimal firstQty   = slice[0].qtyRaw;
        Boolean uniformQty = true;
        for (MastGroupWrapper g : slice) {
            if (g.qtyRaw != firstQty) { uniformQty = false; break; }
        }
 
        List<String> blocks = new List<String>();
        Decimal      rate   = 0;
        Decimal      gst    = 0;
        
        Boolean firstBlock = true; 
        String manRiderBlock = '';
                                                 
        for (MastGroupWrapper g : slice) {
           if (String.isNotBlank(g.descMast)) {
                // MAN RIDER LIFT is quote-level ("common for all N nos. above mast"), so
                // it reads last - after the accessories - rather than between foundation
                // and accessories where the group order puts it. Held back and appended
                // below; its money is untouched. Deepanjan (9th September 2026)
                if (g.descMast.contains('Manrider System')) {
                    manRiderBlock = g.descMast;
                } else {
                    blocks.add('<span class="' + (firstBlock ? 'desc-mast' : 'desc-acc') + '">'
                             + g.descMast + '</span>');
                    firstBlock = false;
                }
            }
            if (String.isNotBlank(g.descBolt)) {
                blocks.add('<span class="desc-bolt">'
                         + '<span class="desc-label">Supply of FOUNDATION BOLTS - </span>'
                         + cmEsc(g.descBolt) + '</span>');
                firstBlock = false;
            }
            // Each group's rate and GST are ALREADY rounded per component, the same way
            // Single Scope rounds each of its lines. They are added, never re-derived
            // from a raw sum - recomputing GST here would round at a different
            // granularity and reopen the gap between the two scopes.
            // Deepanjan (17th July 2026)
            // g.qtyRaw is null on the few groups built with `new MastGroupWrapper()` instead
            // of cmGroup(). None of them reaches a collapsed slice today, but a null here
            // would be a hard NPE rather than a wrong number, so it defaults to 1.
            // Deepanjan (22nd Aug 2026)
            Decimal gq = (g.qtyRaw == null || g.qtyRaw <= 0) ? 1 : g.qtyRaw;
            rate += uniformQty ? g.unitRateRaw  : (g.unitRateRaw  * gq);
            gst  += uniformQty ? g.gstAmountRaw : (g.gstAmountRaw * gq);
        }
 
        if (String.isNotBlank(manRiderBlock)) {
            blocks.add('<span class="' + (firstBlock ? 'desc-mast' : 'desc-acc') + '">'
                     + manRiderBlock + '</span>');
            firstBlock = false;
        }
         
        // COMBINED QUANTITY - Deepanjan (22nd Aug 2026)
        // The uniform branch already printed the real quantity. The non-uniform branch used
        // to force qty to 1 and keep the whole-lot figure; now the same whole-lot figure is
        // divided back out by the first group's quantity (the MAST group - every builder
        // adds it first in its product slice), so the offer shows the real quantity and a
        // true per-unit rate. Total is untouched: unit x qty reproduces the same sum.
        
                                                
        Decimal qty = (firstQty == null) ? 1 : firstQty;
        if (qty <= 0) qty = 1;
        if (!uniformQty) { rate = rate / qty; gst = gst / qty; }
        Decimal unit  = rate + gst;
        Decimal total = (unit * qty).setScale(2, RoundingMode.HALF_UP);
 
        MastGroupWrapper g0 = new MastGroupWrapper();
        g0.slNo           = '1';
        g0.descMast       = String.join(blocks, '');
        g0.descBolt       = '';
        g0.descAcc        = '';
        g0.unitRate       = formatINR2(rate);
        g0.gstPct         = String.valueOf(gstPct.intValue());
        g0.gstAmount      = formatINR2(gst);
        g0.freight        = freight;
        g0.unitAmount     = formatINR2(unit);
        g0.qty            = String.valueOf(qty.intValue());
        g0.qtyRaw         = qty;
        g0.totalAmount    = formatINR(total);
        g0.unitRateRaw    = rate;
        g0.gstAmountRaw   = gst;
        g0.unitAmountRaw  = unit;
        g0.totalAmountRaw = total;
 
        return g0;
    }
 
    // descMast renders escape="false", so anything folded into it must arrive escaped.
    // Same replacements cmGroup already applies. Deepanjan (16th July 2026)
    private String cmEsc(String s) {
        return (s == null ? '' : s)
            .replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;');
    }
 
    // ── STADIUM MAST: prefix 'mrl_' (Man Riding Lift) or 'lwc_' (Ladder With Cage)
    private Integer cmStadiumGroups(Map<String,Object> m, Decimal gstPct,
                                     String freight, Integer sl, String p) {
 
        Integer segCount = decVal(m, p + 'no_of_segment', 0).intValue();
        if (segCount <= 0) {
            // Mast empty but ticked special item still shows as its own group. Reetabrata (13th July 2026)
            // Segment Above 5 only - same rule as siHas below. Deepanjan (19th Aug 2026)
            if (isSegmentAbove5 && String.isNotBlank(strVal(m, p + 'si_type', ''))
                    && siBoolVal(m, p + 'si_show_separate')) {
                String d0 = strVal(m, p + 'si_description', '');
                if (String.isBlank(d0)) d0 = 'Special Item';
                Decimal v0 = decVal(m, p + 'si_value', 0);
                Decimal r0 = strVal(m, p + 'si_type', '').equalsIgnoreCase('Weight')
                            ? stadiumSiRatePerKg(m, p) * v0 : v0;
                mastGroups.add(cmGroup(String.valueOf(sl++),
                    'Supply of SPECIAL ITEM: ' + d0 + '.', '', r0, gstPct, 1, freight));
            }
            return sl;
        }
 
        Boolean isMrl   = (p == 'mrl_');
        String  variant = isMrl ? 'MAN RIDING LIFT' : 'LADDER WITH CAGE';

        Decimal segPrice  = decVal(m, isMrl ? 'mrl_man_riding_unit_price'
                                            : 'lwc_ladder_cage_unit_price', 0)
                                .setScale(2, RoundingMode.HALF_UP);
        Decimal segWeight = decVal(m, isMrl ? 'mrl_man_riding_total_weight'
                                            : 'lwc_ladder_cage_weight', 0);
        Decimal qty = decVal(m, p + 'quantity', 1);
        if (qty == 0) qty = 1;

        segPrice = perPolfrieght ? segPrice + perPolTPCharg : segPrice;

        Decimal segHt    = decVal(m, p + 'segment_height',    0);
        Decimal headFrm  = decVal(m, p + 'head_frame_height', 0);
        Decimal mastHt   = decVal(m, p + 'height_of_mast',    0);
        if (mastHt == 0) mastHt = segHt + headFrm;

        Decimal topDia = decVal(m, p + 'top_dia',      0);
        Decimal botDia = decVal(m, p + 'bottom_dia',   0);
        Decimal bpDia  = decVal(m, p + 'bp_diameter',  0);
        Decimal bpThk  = decVal(m, p + 'bp_thickness', 0);
        Decimal bpPcd  = decVal(m, p + 'bp_pcd',       0);

        Decimal noOfLum  = decVal(m, p + 'no_of_lum', 0);
        String  lumType  = strVal(m, p + 'type_of_lum',  '');
        Decimal watt     = decVal(m, p + 'watt', 0);

        // Height display: X+Y=Z
        String heightDisplay = '';
        if (segHt > 0 && headFrm > 0) {
            heightDisplay = cmNum(segHt) + '+' + cmNum(headFrm) + '=' + cmNum(mastHt);
        } else if (mastHt > 0) {
            heightDisplay = cmNum(mastHt);
        }

        // ── Main description (plain text, no red) ──
        String descMast = 'Supply of ' + heightDisplay + ' MTRS STADIUM MAST FABRICATED PART AS PER DIMENSION: '   // was LIGHTING MAST. Reetabrata (13th July 2026)
            + 'TOP DIA - ' + cmNum(topDia) + ' mm, '
            + 'BOTTOM DIA - ' + cmNum(botDia) + ' mm, '
            + 'SECTION - ' + segCount + ' nos '
            + '(SECTION LENGTH - ' + cmStadiumList(m, p, segCount, 'length', ' / ') + ' mm) '
            + 'THICKNESS - ' + cmStadiumList(m, p, segCount, 'thickness', ', ') + ' mm.';

        if (bpDia > 0) descMast += ' BASE PLATE - ' + cmNum(bpDia) + 'mm x ' + cmNum(bpThk) + 'mm,';
        if (bpPcd > 0) descMast += ' PCD - ' + cmNum(bpPcd) + 'mm,';

        descMast += ' with following items: High Mast sections with base plate';

        if (noOfLum > 0) {
            descMast += ', Fixed Lantern carriage suitable to fix ' + cmNum(noOfLum) + ' nos. of Luminaries'
                + (String.isNotBlank(lumType) ? ' (' + lumType : '')
                + (watt > 0 ? ' ' + cmNum(watt) + ' watt' : '')
                + (String.isNotBlank(lumType) ? ')' : '');
        }
                  
        // adding pu paint/micron desc to main desc prices are already added in json - 06-Aug                                 
        if (cmBool(m, p + 'is_extra_micron')) {
            String micronVal = strVal(m, p + 'extra_micron', '');
            if (String.isNotBlank(micronVal)) {
                descMast += ', with ' + micronVal + ' micron';
            }
        }
        if (cmBool(m, p + 'pu_paint')) {
            String puNote = strVal(m, p + 'pu_paint_note', '');
            descMast += String.isNotBlank(puNote) ? '. PU Paint' +  ' - ' + puNote.trim() : '';
        }                                 
        
        String suffix = isMrl ? strVal(m, 'man_riding_wind_speed', '') : strVal(m, 'ladder_cage_wind_speed', '');
        if (String.isNotBlank(suffix)) {
            descMast += ' Wind Speed - ' + suffix;
        }
        
        // adding special note description
        if(strVal(m, p + 'special_note', '')!=null){
            String specialNote = strVal(m, p + 'special_note', '');
            descMast += String.isNotBlank(specialNote.trim()) ? ' Special Note: ' + specialNote : '';
        }                                 
                                         

        // Append the required exclusion text (no red styling in Apex)
        // Red exclusion clause (Stadium only); escape dynamic desc then append markup. Reetabrata (13th July 2026)
        descMast += isMrl ? ' \u0001RED_LED\u0001' : ' \u0001RED_LED_LWC\u0001';   // LWC clause adds '& wiring cable'. Reetabrata (13th July 2026)   // Reetabrata (13th July 2026)

        // ── Foundation bolts (separate line) ──
        Decimal fndPrice = 0;
        String  descBolt = '';
        String  fbDia = strVal(m, p + 'fb_diameter', '');
        Decimal fbLen = decVal(m, p + 'fb_length',     0);
        Decimal fbNo  = decVal(m, p + 'fb_no_of_bolt', 0);
        // isSegmentAbove5 guard: a Customized Mast Stadium quote outside Segment Above 5
        // can also carry foundation_bolt_type, and today it prints NOTHING when the user
        // picks "without". This sentence is a seg5 requirement, so it is scoped to seg5
        // and every other Stadium quote keeps printing exactly what it prints now.
        // Deepanjan (21st Aug 2026)
        if (strVal(m, p + 'foundation_bolt_type', '').containsIgnoreCase('without')) {
            //if (isSegmentAbove5) {
            // Without Foundation Bolt: the out-of-scope sentence, in red, at rate 0 - the
            // same one Lighting Mast and Flag Mast print. It goes on descMast, not descBolt,
            // because the page prefixes descBolt with its own hardcoded "Supply of
            // FOUNDATION BOLTS - " label. Deepanjan (21st Aug 2026)
            // if without foundation selected - foundation line item will be created with this desc for stadium mast as well

                descMast += ' ' + fdnNotInScopeDesc(fbDia, fbLen, fbNo, bpPcd);
            //}
        } else {
            fndPrice      = decVal(m, p + 'foundation_unit_price', 0).setScale(2, RoundingMode.HALF_UP);
            Decimal fndWt = decVal(m, p + 'foundation_weight', 0);
            if (fndPrice > 0 || fndWt > 0 || fbNo > 0) {
                descBolt = 'M' + (String.isBlank(fbDia) ? '0' : fbDia)
                        + ' x ' + cmNum(fbLen) +'mm'
                        + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate'
                        + '.';
            }
        }

        // ── Special item (per sub-mast: mrl_si_* / lwc_si_*) ── Reetabrata (13th July 2026)
        // UNTICKED -> fold description + price into this group. TICKED -> own group below.
        // Stadium unit price does not fold si_price_add, so Apex owns the price. Absent keys => no-op.
        String  siType = strVal(m, p + 'si_type', '');
        // Special Items are a Segment Above 5 feature: the normal Customized Mast section
        // logic carries no si_ field at all. Gating siHas on the mast type makes every path
        // below - folding into the mast line and the separate line - a no-op for any other
        // recipe, so Stadium quotes outside Segment Above 5 print exactly what they print
        // today. Deepanjan (19th Aug 2026)
        Boolean siHas  = isSegmentAbove5 && String.isNotBlank(siType);
        Boolean siSep  = siHas && siBoolVal(m, p + 'si_show_separate');
        String  siDesc = strVal(m, p + 'si_description', '');
        if (String.isBlank(siDesc)) siDesc = 'Special Item';
        Decimal siVal  = decVal(m, p + 'si_value', 0);
        // TYPE = Weight prices the item at VALUE kg x the sub-mast's rate; TYPE = Price
        // returns the typed value as-is. Deepanjan (19th Aug 2026)
        Decimal siRate = siType.equalsIgnoreCase('Weight')
                        ? stadiumSiRatePerKg(m, p) * siVal
                        : siVal;
        if (siHas && !siSep) {
            descMast += ' SPECIAL ITEM: ' + siDesc + '.';
        }

        // Single Scope bills the mast and the foundation as TWO lines, each rounded on its
        // own; rounding the sum here would drift. Deepanjan (17th July 2026)
        Decimal[] mastMny = cmLineMoney(segPrice + ((siHas && !siSep) ? siRate : 0), gstPct);
        Decimal[] fndMny  = cmLineMoney(fndPrice, gstPct);

        mastGroups.add(cmGroupMoney(String.valueOf(sl++), descMast, '',
                                    mastMny[0], mastMny[1], gstPct, qty, freight));
                                         
         if (String.isNotBlank(descBolt) || fndPrice > 0) {
            Decimal fbQty = decVal(m, p + 'fb_quantity', 0);
            if (fbQty <= 0) fbQty = 1;
            mastGroups.add(cmGroupMoney(String.valueOf(sl++), '', descBolt,
                                fndMny[0], fndMny[1], gstPct, fbQty, freight));
        }
        // ── Accessories ──
        if (isMrl) {
            Decimal accRate = decVal(m, 'mrl_mast_acc_foundation_unit_price', 0)
                                .setScale(2, RoundingMode.HALF_UP);
            Decimal accQty  = decVal(m, 'mrl_mast_acc_quantity', 1);
            if (accQty == 0) accQty = 1;
            String  accDesc = strVal(m, 'mrl_mast_acc_description', '');
            if (accRate > 0 || String.isNotBlank(accDesc)) {
                mastGroups.add(cmGroup(String.valueOf(sl++),
                    'Supply of standard Manrider System'
                    + (String.isNotBlank(accDesc) ? ' - ' + accDesc : ''),
                    '', accRate, gstPct, accQty, freight));
            }
        } else {
            String  accDesc = strVal(m, 'lwc_acc_description', '');
            Decimal accWt   = decVal(m, 'lwc_acc_weight', 0);
            Decimal accRate = decVal(m,'lwc_unit_price',0).setScale(2, RoundingMode.HALF_UP);
            if (String.isNotBlank(accDesc) || accWt > 0) {
                mastGroups.add(cmGroup(String.valueOf(sl++),
                    'Supply of standard Man-Riding Ladder with Safety Cage system'
                    + (String.isNotBlank(accDesc) ? ' - ' + accDesc : '')
                    + '.','', accRate, gstPct, qty, freight));
            }
        }

        // ── Special item as its own group (only when 'show separate' is TICKED) ── Reetabrata (13th July 2026)
        if (siSep) {
            // QTY: the sub-mast's own quantity. UNTICKED already charges siRate once per unit
            // (see cmLineMoney(segPrice + siRate) above), so a ticked item priced at qty 1 made
            // the same item cost different money depending only on that checkbox.
            // Deepanjan (4th September 2026)
            mastGroups.add(cmGroup(String.valueOf(sl++),
                'Supply of SPECIAL ITEM: ' + siDesc + '.', '', siRate, gstPct, qty, freight));
        }
                                            
        // ── NEW: Man Riding Lift — KIT accessories group, only if a matching KIT is configured ──
        if (isMrl) {
            Integer slBeforeKit = sl;
            sl = addMrlKitAccessoryGroup(m, mastHt, qty, segCount, gstPct, freight, sl);
            // addMrlKitAccessoryGroup only fires on a quote that carries KIT data. A
            // Segment Above 5 Stadium quote has none, so its Additional Accessories block
            // never reached the offer. Emit it when the KIT group did not.
            // Deepanjan (21st Aug 2026)
            if (isSegmentAbove5 && sl == slBeforeKit) {
                sl = addStadiumSeg5AccessoryGroup(m, mastHt, qty, gstPct, freight, sl);
            }
        }
                                            
                                            
        return sl;
    }    // ── FLAG MAST
    // ── Segment Above 5 Stadium: Additional Accessories -> offer group ──
    // Mirrors HighMastSOWController.addStadiumSeg5AccessoryLine so Single and Combined
    // print the same words at the same rate. Deepanjan (21st Aug 2026)
    private Integer addStadiumSeg5AccessoryGroup(Map<String,Object> m, Decimal mastHt, Decimal qty,
                                                 Decimal gstPct, String freight, Integer sl) {
        Decimal accRate = decVal(m, 'lm_acc_total_rate', 0);
        if (accRate <= 0) accRate = decVal(m, 'lm_acc_rate', 0);

        String winchSpec = withDrum(withUnit(
                              specOrBlank(strVal(m, 'lm_type_of_winch', ''))
                                  .replace(' kg', 'Kg').replace(' KG', 'Kg'),
                              strVal(m, 'lm_winch_unit', '')),
                              strVal(m, 'lm_winch_drum', ''));
        String toolSpec  = withUnit(specOrBlank(strVal(m, 'lm_type_of_power_tool', '')),
                                    strVal(m, 'lm_power_tool_unit', ''));
        String ropeSpec  = withUnit(specOrBlank(strVal(m, 'lm_type_of_wire_rope', '')),
                                    strVal(m, 'lm_wire_rope_unit', ''));

        if (accRate <= 0 && String.isBlank(winchSpec)
                         && String.isBlank(toolSpec) && String.isBlank(ropeSpec)) return sl;

        //String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, '', '')
        //                     .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');
        Boolean hasOptElec       = hasOptionalElectricalItems(m, '', '');
        String  aolVal           = hasOptElec ? optElecVal(m, '', '', 'lm_type_of_aol') : '';
        String  controlSwitchVal = hasOptElec ? optElecVal(m, '', '', 'lm_no_of_aviation_light') : '';
        String  feederPillarVal  = hasOptElec ? optElecVal(m, '', '', 'lm_feeder_piller_control') : '';
        String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, '', '',
                                              hasOptElec, aolVal, controlSwitchVal, feederPillarVal)
                             .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');                     

        mastGroups.add(cmGroup(String.valueOf(sl++), descAcc, '',
                       accRate.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
        return sl;
    }

    private Integer cmFlagGroups(Map<String,Object> m, Decimal gstPct,
                                String freight, Integer sl) {

        // Flag Mast is now row-driven: one r{n}_ block per mast row, Lighting Mast
        // shape with the fm_ prefix and no L-Ring. Reetabrata (15th July 2026)
        Boolean anyRow = false;
        for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
            String rPfx = 'r' + rowIdx + '_';
            if (String.isBlank(strVal(m, rPfx + 'fm_height_of_mast', ''))) continue;
            Integer segCount = decVal(m, rPfx + 'fm_no_of_segment', 0).intValue();
            if (segCount <= 0) continue;
            anyRow = true;
            // one populated r{n}_ row = one line item. Deepanjan (19th Aug 2026)
            cmProductStart.add(mastGroups.size());
            sl = cmFlagRowGroups(m, rPfx, segCount, gstPct, freight, sl);
            sl = cmFlagAccessoryItemGroups(m, rPfx, rowIdx, gstPct, freight, sl, false);
        	sl = cmFlagAdditionalItemGroups(m, rPfx, rowIdx, gstPct, freight, sl);
        }
        if (!anyRow) return sl;
        
        // PU Paint, Supplementary Costing, Mast Accessories and Feeder Pillar below
        // belong to no single mast, so they open their own line item instead of
        // falling into the last mast's. Deepanjan (19th Aug 2026)
        cmProductStart.add(mastGroups.size());
        sl = cmFlagPuPaintGroup(m, gstPct, freight, sl);
         

        // ── Supplementary Costing (single section)
        String  scDesc = strVal(m, 'fm_sc_description', '');
        Decimal scQty  = decVal(m, 'fm_sc_quantity', 0);
        Decimal scAmt  = decVal(m, 'fm_sc_amount',   0);
        if (String.isNotBlank(scDesc) || scAmt > 0) {
            mastGroups.add(cmGroup(String.valueOf(sl++),
                ' Supply of FLAG MAST SUPPLEMENTARY ITEMS: ' + scDesc
                + (scQty > 0 ? ' - ' + cmNum(scQty) + ' Nos.' : '') + '.',
                '', scAmt.setScale(2, RoundingMode.HALF_UP), gstPct, 1, freight));
        }

        // ── MAST ACCESSORIES (single section)
        Decimal maRate = decVal(m, 'fm_mast_acc_foundation_unit_price', 0)
                            .setScale(2, RoundingMode.HALF_UP);
        String  maDesc = strVal(m, 'fm_ma_description',  '');
        String  maNote = strVal(m, 'fm_ma_special_note', '');
        Decimal maQty  = decVal(m, 'fm_ma_quantity', 1);
        if (maQty == 0) maQty = 1;
        if (maRate > 0 || String.isNotBlank(maDesc)) {
            mastGroups.add(cmGroup(String.valueOf(sl++),
                'Supply of FLAG MAST ACCESSORIES'
                + (String.isNotBlank(maDesc) ? ' - ' + maDesc : '')
                + (String.isNotBlank(maNote) ? '. Note: ' + maNote : '') + '.',
                '', maRate, gstPct, maQty, freight));
        }

        // ── FEEDER PILLAR (single section)
        if (cmBool(m, 'fm_fp_checkbox')) {
            Decimal fpRate = decVal(m, 'fm_fp_foundation_unit_price', 0)
                                .setScale(2, RoundingMode.HALF_UP);
            Decimal fpQty  = decVal(m, 'fm_fp_quantity', 1);
            if (fpQty == 0) fpQty = 1;
            if (fpRate > 0) {
                mastGroups.add(cmGroup(String.valueOf(sl++),
                    'Supply of FEEDER PILLAR as per standard.', '', fpRate, gstPct, fpQty, freight));
            }
        }
        return sl;
    }
 
    // One Flag Mast row -> mast group + that row's accessory kit group.
    // Reetabrata (15th July 2026)
    private Integer cmFlagRowGroups(Map<String,Object> m, String rPfx, Integer segCount,
                                    Decimal gstPct, String freight, Integer sl) {
 
        Decimal segPrice  = decVal(m, rPfx + 'fm_' + segCount + '_unit_price', 0)
                                .setScale(2, RoundingMode.HALF_UP);
        Decimal segWeight = decVal(m, rPfx + 'fm_' + segCount + '_segment_weight', 0);
        Decimal qty       = decVal(m, rPfx + 'fm_est_quantity', 1);
        if (qty == 0) qty = 1;

        segPrice = perPolfrieght ? segPrice + perPolTPCharg : segPrice;
 
        // PU Paint is NOT added here. fm_pu_paint_value is unprefixed - one value per
        // quote - and Single Scope bills it as its own line at qty 1. Adding it to this
        // row's rate charged it once per mast row AND multiplied it by the row quantity.
        // It is now emitted once per quote by cmFlagPuPaintGroup(). Deepanjan (17th July 2026)
                                        
        Decimal mastHt = decVal(m, rPfx + 'fm_height_of_mast', 0);
        // TOP/BOTTOM DIA come from the row's own segment OAF keys
        // (r{n}_fm_{seg}_oaf_top / _oaf_bottom). The unprefixed fm_top_dia /
        // fm_bottom_dia keys were never saved by the blueprint, so the > 0 guards
        // below silently dropped both clauses from every Flag Mast description.
        // Top = segment 1 (topmost); bottom = last populated segment.
        // Deepanjan (16th July 2026)
        Decimal topDia = decVal(m, rPfx + 'fm_1_oaf_top', 0);
        Decimal botDia = cmFlagBottomDia(m, rPfx, segCount);
        if (segCount <= 1) {
            topDia = decVal(m, rPfx + 'fm_1_oaf_top',    0);
            botDia = decVal(m, rPfx + 'fm_1_oaf_bottom', 0);
        } else {
            topDia = decVal(m, rPfx + 'fm_' + segCount + '_top_oaf_top', 0);
            String botKey = cmBool(m, rPfx + 'fm_override_bot' + segCount)
                ? rPfx + 'fm_ovr_bot' + segCount + '_oaf_bot'
                : rPfx + 'fm_bot' + segCount + '_oaf_bot';
            botDia = decVal(m, botKey, 0);
            if (botDia == 0) botDia = cmFlagBottomDia(m, rPfx, segCount); // legacy fallback
        }                                
                                        
                                        
        Decimal wind   = strVal(m, 'fm_wind_speed', '').equalsIgnoreCase('YES')
                             ? decVal(m, 'fm_wind_speed_value', 0) : 0;   // fm_wind_speed is a YES/NO picklist; the figure lives in fm_wind_speed_value. Deepanjan (16th July 2026)
        Decimal bpDia  = decVal(m, rPfx + 'fm_bp_diameter',  0);
        Decimal bpThk  = decVal(m, rPfx + 'fm_bp_thickness', 0);
        Decimal bpPcd  = decVal(m, rPfx + 'fm_bp_pcd',       0);
                                                                        
 
        // EXTRA MICRON — per-row key first, bare-key fallback for legacy quotes.
        // rajeev (Aug 2026)
        String micron = siBoolVal(m, rPfx + 'fm_is_extra_micron')
            ? strVal(m, rPfx + 'fm_extra_micron', '') : '';
        if (String.isBlank(micron) && cmBool(m, 'fm_is_extra_micron')) {
            micron = cmNum(decVal(m, 'fm_extra_micron', 0));
        }
 
        // PU PAINT — folded into THIS row: text appended to the description,
        // rate added to the money. r{n}_ keys ONLY (no bare fallback), so
        // legacy quotes are still billed solely by cmFlagPuPaintGroup() and
        // PU Paint can never be charged twice on any quote vintage.
        // fm_pu_paint_value is the pre-GST figure (the saved
        // fm_pu_paint_unit_price = value x 1.18); GST is re-applied once
        // below via cmLineMoney. rajeev (Aug 2026)
        Decimal puRate   = 0;
        String  puClause = '';
        if (siBoolVal(m, rPfx + 'fm_pu_paint')) {
            Decimal puVal = decVal(m, rPfx + 'fm_pu_paint_unit_price', 0);
            if (puVal > 0) {
                puRate = puVal;
                String note = strVal(m, rPfx + 'fm_pu_paint_note', '');
                puClause = String.isNotBlank(note) ? ' PU PAINT' + ' - ' + note + '.' : '';
            }
        }
                                        
        // SPECIAL DESCRIPTION — folded into THIS row: text appended to the
        // description, rate added to the money. The saved unitPrice already
        // carries GST (Price basis: value x realization x 1.18; Weight basis:
        // weight x base price x 1.18 — verified: 14667.4 / 1.18 = 12,430
        // exactly), so it is divided back out here and GST re-applied once
        // below via cmLineMoney — the same treatment additionalDetailRate()
        // gives lm_ad_unit_price. r{n}_ keys ONLY; these fields have no
        Decimal sdRate   = 0;
        String  sdClause = '';
        if (siBoolVal(m, rPfx + 'fm_is_special_desc')) {
            Decimal sdIncl = decVal(m, rPfx + 'fm_special_desc_unitPrice', 0);
            if (sdIncl > 0) {
                sdRate = (sdIncl).setScale(2, RoundingMode.HALF_UP);
                String d = strVal(m, rPfx + 'fm_special_desc_text', '');
                sdClause = String.isNotBlank(d)? ' SPECIAL : ' + d + '.' : '';
            }
        }                                
 
        String descMast =
            'Supply of ' + (mastHt > 0 ? cmNum(mastHt) + ' MTRS ' : '')
            + 'FLAG MAST FABRICATED AS PER DIMENSION: '
            + (topDia > 0 ? 'TOP DIA - '    + cmNum(topDia) + ' mm, ' : '')
            + (botDia > 0 ? 'BOTTOM DIA - ' + cmNum(botDia) + ' mm, ' : '')
            + 'SECTION - '    + segCount + ' nos '
            + '(SECTION LENGTH - ' + cmFlagList(m, rPfx, segCount, 'length',    ' / ') + ' mm) '
            + 'THICKNESS - '  + cmFlagList(m, rPfx, segCount, 'thickness', ', ') + ' mm.'
            + (bpDia > 0 ? ' BASE PLATE - ' + cmNum(bpDia) + ' mm x ' + cmNum(bpThk) + ' mm,' : '')
            + (bpPcd > 0 ? ' PCD - ' + cmNum(bpPcd) + ' mm.' : '')
            + (wind > 0 ? ' Wind Speed: ' + cmNum(wind) + 'm/s.' : '')
            + (String.isNotBlank(micron) ? ' with ' + micron + ' micron.' : '')
            + puClause 
            + sdClause
            // PU Paint text removed: it is now its own group (cmFlagPuPaintGroup), which
            // carries the same wording Single Scope uses. Leaving it here as well would
            // print it twice in the merged cell. Deepanjan (17th July 2026)
            + cmAddNotes(m, rPfx);

        
        
        Decimal fndPrice = decVal(m, rPfx + 'fm_foundation_unit_price', 0)
                               .setScale(2, RoundingMode.HALF_UP);
        String  descBolt = '';
        Decimal fndWt = decVal(m, rPfx + 'fm_foundation_weight', 0);
        String  fbDia = strVal(m, rPfx + 'fm_fb_diameter', '');
        Decimal fbLen = decVal(m, rPfx + 'fm_fb_length',     0);
        Decimal fbNo  = decVal(m, rPfx + 'fm_fb_no_of_bolt', 0);
        String fbType = strVal(m, rPfx + 'fm_fdn_bolt_type', '');
        Decimal fbPcd = decVal(m, rPfx + 'fm_bp_pcd',     0);
                                        
         System.debug('fbType '+ fbType);                               
                                        
        if (fbType == 'With Foundation') {
            descBolt = 'M' + (String.isBlank(fbDia) ? '0' : fbDia)
                     + ' x ' + cmNum(fbLen) +'mm'
                     + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate'
                     + '.';
        }
        else if(fbType == 'Without Foundation'){
             fndPrice = 0;
             descMast += ' ' + fdnNotInScopeDesc(fbDia, fbLen, fbNo, fbPcd);
        }                               
 
        // Single Scope bills the mast and the foundation as TWO lines, so each is
        // rounded on its own there. Rounding segPrice + fndPrice as one sum here would
        // drift from that, so the two are rounded separately and added.
        // Deepanjan (17th July 2026)
        Decimal[] mastMny = cmLineMoney(segPrice + puRate + sdRate, gstPct);
        Decimal[] fndMny  = cmLineMoney(fndPrice, gstPct);
                                         
        mastGroups.add(cmGroupMoney(String.valueOf(sl++), descMast, descBolt,
                               mastMny[0] + fndMny[0], mastMny[1] + fndMny[1],
                               gstPct, qty, freight));
        
        return sl;
    }
 
    // PU PAINT - once per quote, qty 1, mirroring HighMastSOWController.cmFlagPuPaintLine
    // exactly (same key, same rate, same quantity). Deepanjan (17th July 2026)
    private Integer cmFlagPuPaintGroup(Map<String,Object> m, Decimal gstPct,
                                       String freight, Integer sl) {
        if (!cmBool(m, 'fm_pu_paint')) return sl;
        Decimal puVal = decVal(m, 'fm_pu_paint_value', 0);
        if (puVal <= 0) return sl;
 
        String note = strVal(m, 'fm_pu_paint_note', '');
        mastGroups.add(cmGroup(String.valueOf(sl++),
            'Supply of FLAG MAST PU PAINT' + (String.isNotBlank(note) ? ' - ' + note : '') + '.',
            '', puVal.setScale(2, RoundingMode.HALF_UP), gstPct, 1, freight));
        return sl;                                
                                           
    }

    // SPECIAL DESCRIPTION per row: r{n}_fm_is_special_desc / _text / _unitPrice.
    // The saved unitPrice already carries GST (Price basis: value x realization
    // x 1.18; Weight basis: weight x base price x 1.18 — verified: 14667.4/1.18
    // = 12,430 = 110 x 113 exactly), so it is divided back out before cmGroup()
    // re-applies GST once. rajeev 03-08-2026
    private Integer cmFlagSpecialDescGroups(Map<String,Object> m, Decimal gstPct,
                                               String freight, Integer sl) {
        for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
            String rPfx = 'r' + rowIdx + '_';
            if (!siBoolVal(m, rPfx + 'fm_is_special_desc')) continue;
            Decimal unitIncl = decVal(m, rPfx + 'fm_special_desc_unitPrice', 0);
            if (unitIncl <= 0) continue;
 
            Decimal rate = unitIncl / (1 + (gstPct / 100));
            String  d    = strVal(m, rPfx + 'fm_special_desc_text', '');
            if (String.isBlank(d)) d = 'Special Description';
 
            mastGroups.add(cmGroup(String.valueOf(sl++),
                'Supply of SPECIAL DESCRIPTION (Mast ' + rowIdx + '): ' + d + '.',
                '', rate.setScale(2, RoundingMode.HALF_UP), gstPct,
                flagLineQty(m, 'Special Description - ' + rowIdx, 1), freight));
        }
        return sl;
    }
 
    // Quantity for a Flag Mast section line, taken from the estimator's own
    // finalized lines so Combined bills exactly what the estimator computed.
    // Name match is on the unique suffix (e.g. 'Accessory Costing Format - 3').
    private Decimal flagLineQty(Map<String,Object> m, String namePart, Decimal def) {
        for (String listKey : new List<String>{ '_Final_Apex_Lines', '_Saved_Table_Rows' }) {
            for (Object o : getList(m, listKey)) {
                try {
                    Map<String,Object> line = (Map<String,Object>) o;
                    if (strVal(line, 'name', '').contains(namePart)) {
                        Decimal q = decVal(line, 'quantity', def);
                        return q > 0 ? q : def;
                    }
                } catch (Exception e) { /* malformed line — keep scanning */ }
            }
        }
        return def;
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // SEGMENT ABOVE 5 - FLAG MAST (Deepanjan, 22nd July 2026)
    //
    // Its estimator is the LM engine: each mast row saves r{n}_lm_* keys plus
    // the flag annexure grids (unprefixed fm_ac_* / fm_ad_*) and the LM-keyed
    // PU Paint section (lm_pu_paint*). cmFlagGroups() reads r{n}_fm_* keys, so
    // for these quotes it found no rows and emitted nothing. The wording below
    // is the approved Flag Mast offer wording; only the keys are LM-shaped.
    // Mast and foundation are rounded separately and added, mirroring
    // cmFlagRowGroups() so the Combined Scope ties to the Single Scope.
    // Reached only when isSeg5FlagMast is true.
    // ═══════════════════════════════════════════════════════════════════════
    private Integer cmSeg5FlagGroups(Map<String,Object> m, Decimal gstPct,
                                     String freight, Integer sl) {
        Boolean puQuoteLevelDone = false;   // quote-level PU Paint prints on one row only
 
        for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
            String p = 'r' + rowIdx + '_';
 
            Decimal mastHeight = decVal(m, p + 'lm_height_of_mast', 0);
            if (mastHeight == 0) continue;
            Decimal segCount = decVal(m, p + 'lm_no_of_segment', 1);
            if (segCount <= 0) continue;
            // Same rule as cmFlagGroups: one populated r{n}_ row = one line item.
            // Deepanjan (19th Aug 2026)
            cmProductStart.add(mastGroups.size());
            // get flag mast quantity
            Decimal rowQty = decVal(m, p + 'lm_quantity', 1);
        	if (rowQty <= 0) rowQty = 1;
 
            Decimal topDia = (segCount.intValue() <= 1)
                ? decVal(m, p + 'lm_1_oaf_top', 0)
                : decVal(m, p + 'lm_' + segCount.intValue() + '_top_oaf_top', 0);
            Decimal botDia = (segCount.intValue() <= 1)
                ? decVal(m, p + 'lm_1_oaf_bottom', 0)
                : decVal(m, p + 'lm_bot' + segCount.intValue() + '_oaf_bot', 0);
            String lenList = buildSegmentLengthList(m, p, segCount.intValue());
            String thkList = buildSegmentThicknessList(m, p, segCount.intValue());
 
            Decimal bpOD  = decVal(m, p + 'lm_od_of_base_plate',        0);
            Decimal bpThk = decVal(m, p + 'lm_thickness_of_base_plate', 0);
            Decimal pcd   = decVal(m, p + 'lm_pcd',                     0);
 
            Decimal mastUnitPrice = 0;
            for (Integer s = 1; s <= segCount.intValue(); s++) {
                mastUnitPrice += decVal(m, p + 'lm_' + s + '_unit_price', 0);
            }
            if (mastUnitPrice == 0) mastUnitPrice = decVal(m, p + 'lm_1_unit_price', 0);

            mastUnitPrice = perPolfrieght ? mastUnitPrice + perPolTPCharg : mastUnitPrice;

            // PU PAINT is no longer added here. Since 8 Sep 2026 the realized PU Paint rate is
            // part of lm_{s}_unit_price itself (segmentGenerator.js, same rule as the normal LCLM
            // blueprint), so the segment sum above already carries it. The 4 Sep Apex fold
            // charged it a second time and was removed. Deepanjan (8th September 2026)


            String micron = rowBool(m, p, 'lm_is_extra_micron')
                ? rowStr(m, p, 'lm_extra_micron', '').trim() : '';
 
            String puClause = seg5FlagPuClause(m, p, !puQuoteLevelDone);
            if (String.isNotBlank(puClause) && !cmBool(m, p + 'lm_pu_paint')) puQuoteLevelDone = true;

            String descMast =
                'Supply of ' + cmNum(mastHeight) + ' MTRS '
                + 'FLAG MAST FABRICATED AS PER DIMENSION: '
                + (topDia > 0 ? 'TOP DIA - '    + cmNum(topDia) + ' mm, ' : '')
                + (botDia > 0 ? 'BOTTOM DIA - ' + cmNum(botDia) + ' mm, ' : '')
                + 'SECTION - '    + segCount.intValue() + ' nos '
                + '(SECTION LENGTH - ' + lenList + ' mm) '
                + 'THICKNESS - '  + thkList + ' mm.'
                + (bpOD > 0 ? ' BASE PLATE - ' + cmNum(bpOD) + ' mm x ' + cmNum(bpThk) + ' mm,' : '')
                + (pcd  > 0 ? ' PCD - ' + cmNum(pcd) + ' mm.' : '')
                + (String.isNotBlank(micron) ? ' with ' + micron + ' micron.' : '')
                // PU Paint now reads inside the mast description, exactly as Lighting
                // Mast has always done. Deepanjan (21st Aug 2026)
                + puClause;
 

            // ─── SPECIAL ITEM, 'Show separate in offer' UNTICKED ─── Deepanjan (4th September 2026)
            // The estimator has already folded the VALUE into lm_{n}_unit_price through the
            // hidden lm_si_price_add / lm_si_weight_add formulas, so the money is correct - but
            // the typed ITEM DESCRIPTION was printed nowhere at all. TEXT ONLY here; adding the
            // rate again would double-charge. Same sentence cmStadiumGroups has always printed
            // for Stadium (its "siHas && !siSep" branch), which is why Stadium never showed it.
            if (siHasRow(m, p) && !showSpecialItemSeparatelyRow(m, p)) {
                descMast += ' SPECIAL ITEM: ' + specialItemDescriptionRow(m, p) + '.';
            }

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descMast += ' ' + suffix;
            }
 
            // FOUNDATION BOLTS - LM key names; folded into this row's rate with
            // its own cell text, exactly like cmFlagRowGroups().
            String  fbDia    = strVal(m, p + 'lm_fdn_bolt_dia',    '');
            Decimal fbLen    = decVal(m, p + 'lm_fdn_bolt_length',  0);
            Decimal fbNo     = decVal(m, p + 'lm_fdn_no_of_bolt',   0);
            Decimal fndPrice = decVal(m, p + 'lm_fdn_unit_price',   0)
                                   .setScale(2, RoundingMode.HALF_UP);
            String descBolt = '';
            // "Without Foundation": rate 0 and the out-of-scope sentence on descMast
            // (see the LM path). dia / length / nos. are NOT zeroed before the text is
            // built any more. Deepanjan (21st Aug 2026)
            if (fdnSuppressed(m, p)) {
                fndPrice = 0;
                descMast += ' ' + fdnNotInScopeDesc(fbDia, fbLen, fbNo, pcd);
            } else if (fndPrice > 0 || fbNo > 0) {
                descBolt = 'M' + (String.isBlank(fbDia) ? '0' : fbDia)
                         + ' x ' + cmNum(fbLen) + 'mm'
                         + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate.';
            }

            Decimal[] mastMny = cmLineMoney(mastUnitPrice, gstPct);
            Decimal[] fndMny  = cmLineMoney(fndPrice, gstPct);
             
            mastGroups.add(cmGroupMoney(String.valueOf(sl++), descMast, descBolt,
                                   mastMny[0] + fndMny[0], mastMny[1] + fndMny[1],
                                   gstPct, rowQty, freight));

            // ORDER FIX - Deepanjan (21st Aug 2026)
            // These two ran BEFORE the mast group was added, so inside the collapsed
            // product cell the offer read "Supply of FLAG MAST ACCESSORY (Mast 1) ..."
            // and only then "Supply of 70 MTRS FLAG MAST FABRICATED ...". Moving them
            // below puts the mast first, matching the Single scope (1.1 mast, 1.2
            // foundation, 1.3 accessory, 1.4 additional). Only the sl numbers and the
            // order inside mastGroups change - every rate, GST and total is untouched.
            sl = cmFlagAccessoryItemGroups(m, p, rowIdx, gstPct, freight, sl, true);
        	sl = cmFlagAdditionalItemGroups(m, p, rowIdx, gstPct, freight, sl);

            // PER-ROW SPECIAL ITEM - Deepanjan (19th Aug 2026)
            // Mirrors the Single scope: the Segment Above 5 estimator repeats Special
            // Items per mast row for Flag Mast, saving r{n}_lm_si_*, and this builder
            // never read them - with 'Show separate in offer' ON the item disappeared
            // from the offer entirely. Same three helpers buildHighMastGroups() uses,
            // added as its own group inside THIS row's product slice, so the line item
            // numbering is untouched.
            //
            // Reached only from cmSeg5FlagGroups (Segment Above 5 Flag Mast) and a
            // no-op when the keys are absent, so no other mast type can see it.
            if (showSpecialItemSeparatelyRow(m, p)) {
                Decimal siRate = specialItemUnitRateRow(m, p);
                mastGroups.add(cmGroup(String.valueOf(sl++),
                               specialItemDescriptionRow(m, p), '',
                               // QTY: this row's own quantity, not 1. Deepanjan (4th September 2026)
                               siRate, gstPct, rowQty, freight));
            }
        }
 
        // Once-per-quote sections. The accessory / additional grids save the SAME
        // unprefixed fm_ac_* / fm_ad_* keys as the single-segment Flag Mast, so
        // the existing builders are reused verbatim. PU Paint uses the LM keys.
        //
        // These belong to no single mast, so they open their own line item.
        // Deepanjan (19th Aug 2026)
        // seg5FlagPuPaintGroup() removed - PU Paint is a clause on the mast
        // description now, not a group of its own, so this once-per-quote product
        // slice has nothing left to open. Deepanjan (21st Aug 2026)
        return sl;
    }
 
    // Bottom dia = the last populated segment's OAF bottom, scanned upward so a
    // blank trailing segment falls back to the one above it. Mirrors the existing
    // lastSegmentBottomDia() convention, with the fm_ prefix. Deepanjan (16th July 2026)
    private Decimal cmFlagBottomDia(Map<String,Object> m, String rPfx, Integer segCount) {
        for (Integer s = segCount; s >= 1; s--) {
            Decimal bot = decVal(m, rPfx + 'fm_' + s + '_oaf_bottom', 0);
            if (bot > 0) return bot;
        }
        return 0;
    }
 
    // ── Row builder: identical maths to every other builder in this class
    //
    // The rate is rounded to whole rupees BEFORE GST, exactly as
    // HighMastSOWController.buildRow does, so a component priced the same way in both
    // scopes produces the same money. Deepanjan (17th July 2026)
    private MastGroupWrapper cmGroup(String slNo, String descMast, String descBolt,
            Decimal unitRate, Decimal gstPct, Decimal qty, String freight) {
        Decimal[] mny = cmLineMoney(unitRate, gstPct);
        return cmGroupMoney(slNo, descMast, descBolt, mny[0], mny[1], gstPct, qty, freight);
    }
 
    // Per-component money, mirroring HighMastSOWController.buildRow line for line:
    // rate rounded to whole rupees, then GST derived from that ROUNDED rate.
    // Any Combined group that folds several Single Scope lines must add these up
    // rather than rounding a raw sum, or the two scopes drift apart.
    // Deepanjan (17th July 2026)
    private Decimal[] cmLineMoney(Decimal rawRate, Decimal gstPct) {
        Decimal r = (rawRate == null ? 0 : rawRate).setScale(2, RoundingMode.HALF_UP);

        Decimal g = (r * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        return new Decimal[]{ r, g };
    }
 
    // Builds a group from money that has ALREADY been rounded per component.
    private MastGroupWrapper cmGroupMoney(String slNo, String descMast, String descBolt,
            Decimal rate, Decimal gst, Decimal gstPct, Decimal qty, String freight) {

        Decimal unit  = rate + gst;
        Decimal total = (unit * qty).setScale(2, RoundingMode.HALF_UP);
 
        MastGroupWrapper g = new MastGroupWrapper();
        g.slNo           = slNo;
        // Stadium-only path. Escape dynamic text, then restore the red exclusion
        // clauses as literal markup (cell renders escape="false"). Reetabrata (13th July 2026)
        String dM = (descMast == null ? '' : descMast)
            .replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
            .replace('\u0001RED_LED\u0001', ' <span style="color:#c00000;font-weight:bold;">(Without LED Floodlight &amp; aviation lights and feeder pillar panel)</span>')
            .replace('\u0001RED_LED_LWC\u0001', ' <span style="color:#c00000;font-weight:bold;">(Without LED Floodlight &amp; aviation lights and feeder pillar panel &amp; wiring cable)</span>')   // Ladder With Cage variant. Reetabrata (13th July 2026)
            // "Without Foundation" out-of-scope sentence. Deepanjan (21st Aug 2026)
            .replace('\u0001FDN_NIS_ON\u0001', '<span class="desc-bolt" style="color:#c00000;font-weight:bold;">')
            .replace('\u0001FDN_NIS_OFF\u0001', '</span>');
        g.descMast       = dM;
        g.descBolt       = descBolt;  // VF prepends "Supply of FOUNDATION BOLTS - "
        g.descAcc        = '';        // left blank: VF hardcodes a Lighting-Mast label here
        g.unitRate       = formatINR(rate.setScale(2, RoundingMode.HALF_UP));
        g.gstPct         = String.valueOf(gstPct.intValue());
        g.gstAmount      = formatINR(gst);
        g.freight        = freight;
        g.unitAmount     = formatINR(unit.setScale(0, RoundingMode.HALF_UP));
        g.qty            = String.valueOf(qty.intValue());
        g.qtyRaw         = qty;
        g.totalAmount    = formatINR(total);
        g.unitRateRaw    = rate;
        g.gstAmountRaw   = gst;
        g.unitAmountRaw  = unit;
        g.totalAmountRaw = total;
        return g;
    }
 
    // ── Segment slots are derived from NO OF SEGMENT, read top -> middles -> bottom.
    //    3/4/5 (Stadium) and 1..5 (Flag) therefore reflow with no code change.
    private String cmStadiumList(Map<String,Object> m, String p, Integer n, String attr, String sep) {
        // Stopped at mid4, so a 7-segment Stadium printed 5 lengths instead of 7.
        // top + middles 2..n-1 + bottom => mid{k} belongs whenever n >= k + 1.
        // Identical to HighMastSOWController.cmStadiumList. Deepanjan (21st Aug 2026)
        List<String> keys = new List<String>();
        keys.add(p + 'top_segment_' + attr);
        if (n >= 3) keys.add(p + 'middle_segment_' + attr);          // middle_segment_ IS mid2
        for (Integer k = 3; k <= 14; k++) {
            if (n >= k + 1) keys.add(p + 'mid' + k + '_' + attr);
        }
        keys.add(p + 'bottom_' + attr);
        return cmJoin(m, keys, sep);
    }
 
    private String cmFlagList(Map<String,Object> m, String rPfx, Integer n, String attr, String sep) {
        // Mirrors the Lighting Mast segment shape (override-aware), fm_ prefixed.
        // Reetabrata (15th July 2026)
        List<String> keys = new List<String>();
        if (n == 1) {
            keys.add(rPfx + 'fm_1_' + attr);
        } else if (n == 2) {
            keys.add(rPfx + 'fm_2_top_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_bot2')
                     ? rPfx + 'fm_ovr_bot2_' + attr : rPfx + 'fm_bot2_' + attr);
        } else if (n == 3) {
            keys.add(rPfx + 'fm_3_top_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid2')
                     ? rPfx + 'fm_ovr_mid2_' + attr : rPfx + 'fm_mid2_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_bot3')
                     ? rPfx + 'fm_ovr_bot3_' + attr : rPfx + 'fm_bot3_' + attr);
        } else if (n == 4) {
            keys.add(rPfx + 'fm_4_top_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid2')
                     ? rPfx + 'fm_ovr_mid2_' + attr : rPfx + 'fm_mid2_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid3')
                     ? rPfx + 'fm_ovr_mid3_' + attr : rPfx + 'fm_mid3_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_bot4')
                     ? rPfx + 'fm_ovr_bot4_' + attr : rPfx + 'fm_bot4_' + attr);
        } else {
            keys.add(rPfx + 'fm_5_top_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid2')
                     ? rPfx + 'fm_ovr_mid2_' + attr : rPfx + 'fm_mid2_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid3')
                     ? rPfx + 'fm_ovr_mid3_' + attr : rPfx + 'fm_mid3_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_mid4')
                     ? rPfx + 'fm_ovr_mid4_' + attr : rPfx + 'fm_mid4_' + attr);
            keys.add(cmBool(m, rPfx + 'fm_override_bot5')
                     ? rPfx + 'fm_ovr_bot5_' + attr : rPfx + 'fm_bot5_' + attr);
        }
        return cmJoin(m, keys, sep);
    }
 
    private String cmJoin(Map<String,Object> m, List<String> keys, String sep) {
        List<String> parts = new List<String>();
        for (String k : keys) {
            Decimal v = decVal(m, k, 0);
            if (v > 0) parts.add(cmNum(v));
        }
        return parts.isEmpty() ? '0' : String.join(parts, sep);
    }
 
    // ── Additional Details column-repeater (custom metadata: additional_Detail)
    private Decimal cmAddTotal(Map<String,Object> m, String rPfx, String valueType) {
        // Additional Details is now a per-mast grid row. Reetabrata (15th July 2026)
        Decimal total = 0;
        if (strVal(m, rPfx + 'fm_add_value_type', '').equalsIgnoreCase(valueType)) {
            total += decVal(m, rPfx + 'fm_add_value', 0);
        }
        return total;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
// MAN RIDING LIFT — KIT accessories group (additive; reuses buildAccessoriesDesc,
// accSpecRaw, specOrBlank, codeOrBlank, cmGroup — same helpers already in this class)
// ═══════════════════════════════════════════════════════════════════════
private Integer findKitLineForHeight(Map<String,Object> m, Decimal mastHt) {
    for (Integer k = 1; k <= 10; k++) {
        String kitMastHtStr = strVal(m, 'kit_line_' + k + '_lm_mast_height', '');
        if (String.isBlank(kitMastHtStr)) continue;
        Decimal kitHt = 0;
        try { kitHt = Decimal.valueOf(kitMastHtStr); } catch (Exception ex) {}
        if (kitHt == mastHt || kitHt == mastHt * 10) return k;
    }
    return 0;   // no matching KIT line found
}
 
// Adds one extra group row for MRL KIT accessories, ONLY if a matching
// kit_line_N exists and is priced. Returns the updated sl counter.
private Integer addMrlKitAccessoryGroup(Map<String,Object> m, Decimal mastHt, Decimal qty,
                                         Integer segCount, Decimal gstPct, String freight, Integer sl) {
    Integer kitLineNum = findKitLineForHeight(m, mastHt);
    if (kitLineNum == 0) return sl;   // no KIT data -> unchanged behavior
 
    String kit = 'kit_line_' + kitLineNum + '_';
 
    Integer kitSeg = (Integer) decVal(m, kit + 'no_of_segment_select', segCount).intValue();
    if (kitSeg == 0) kitSeg = segCount;
 
    Decimal accUnitPrice = 0;                                       
    if (kitSeg <= 1) {
        accUnitPrice = decVal(m, kit + 'lm_kit_unit_price', 0);
    } else if (kitSeg == 2) {
        accUnitPrice = decVal(m, kit + 'lm_2_kit_unit_price', 0);
    } else {
        accUnitPrice = decVal(m, kit + 'lm_3_kit_unit_price', 0);
    }
    if (accUnitPrice <= 0) return sl;   // nothing priced -> skip 
    String cableSpec = specOrBlank(accSpecRaw(m, kit, 'hm_cable_type', 'lm_cable_type', 'T=2.5 SQmm 5Core'));
    String cableSets = codeOrBlank(accSpecRaw(m, kit, 'hm_no_of_cable', 'lm_no_of_cable', '1=Single cable'));
    String winchSpec = specOrBlank(accSpecRaw(m, kit, 'hm_type_of_winch', 'lm_type_of_winch', 'E=350 kg'))
                          .replace(' kg', 'Kg').replace(' KG', 'Kg');
    String toolSpec  = specOrBlank(accSpecRaw(m, kit, 'hm_type_of_power_tool', 'lm_type_of_power_tool', 'G=Motor,3PH'));
    String ropeSpec  = specOrBlank(accSpecRaw(m, kit, 'hm_wire_rope', 'lm_type_of_wire_rope', '5=5mm dia'));
                                            
    // check kit optional electric details
 	Boolean hasOptElec       = hasOptionalElectricalItems(jsonData, kit, '');
    String  aolVal           = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_type_of_aol') : '';
    String  controlSwitchVal = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_no_of_aviation_light') : '';
    String  feederPillarVal  = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_feeder_piller_control') : '';
 
    //String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec)
    //                     .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');
    
    String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec,
                                          hasOptElec, aolVal, controlSwitchVal, feederPillarVal)
                         .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');                                         
    mastGroups.add(cmGroup(String.valueOf(sl++), descAcc, '', accUnitPrice, gstPct, qty, freight));
    return sl;
}
 
    private String cmAddNotes(Map<String,Object> m, String rPfx) {
        List<String> notes = new List<String>();
        String d = strVal(m, rPfx + 'fm_add_desc', '');
        if (String.isNotBlank(d)) notes.add(d + '.');
        return notes.isEmpty() ? '' : ' ' + String.join(notes, ' ');
    }
 
    // ── Tolerates Boolean true, "true" and "1"
    private Boolean cmBool(Map<String,Object> m, String key) {
        if (m == null || !m.containsKey(key) || m.get(key) == null) return false;
        Object v = m.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim();
        return s.equalsIgnoreCase('true') || s == '1';
    }
 
// LCLM: replaces the 'Lighting Arrestor' phrase with the Lightning Spike (length + weight)
// followed by the Down Conductor Fixing Arrangement (weight), per the client's mark-up.
// Each figure prints only when it was entered, so no empty bracket ever appears - e.g. when the
// spike is priced by PRICE the weight is not captured. Only called when isLCLM is true.
// Reetabrata (15th July 2026)
private String lclmSpikeClause(String p) {
    // Row key first, bare key fallback - per-row sections since 27-Jul.
    Decimal spikeLen = rowDec(jsonData, p, 'lm_spike_length', 0);
    Decimal spikeWt  = rowDec(jsonData, p, 'lm_spike_weight',  0);
    Decimal dcWt     = rowDec(jsonData, p, 'lm_dc_weight',     0);
 
    // Weights are no longer printed - the client asked for the spike length only
    // and nothing after "Down Conductor Fixing Arrangement". The spikeWt / dcWt
    // reads above are deliberately left in place: they cost nothing, they keep
    // this method's shape intact, and putting the Kg phrases back is then a
    // one-line change. The weight PDF reads its own copies of those keys in
    // HighMastWeightCalcController and is unaffected by this.
    // Deepanjan (10th August 2026)
    List<String> spikeSpec = new List<String>();
    if (spikeLen > 0) spikeSpec.add(cmNum(spikeLen) + ' MTR');
 
    String clause = 'Lightning Spike';
    if (!spikeSpec.isEmpty()) clause += ' (' + String.join(spikeSpec, ' - ') + ')';
 
    clause += ', Down Conductor Fixing Arrangement';
    return clause;
}
 
    // Extra Micron / PU Paint sentence appended to the mast description.
// Keys are only populated by the Segment Above 5 recipes (lm_* for Lighting Mast and LCLM),
// so this stays empty - and the description unchanged - for every other quote.
// Reetabrata (15th July 2026)
private String micronPaintClause(String p) {
    // Row key first, bare key fallback - per-row sections since 27-Jul.
    // Deepanjan (27th July 2026)
    String clause = '';
 
    String micron = rowStr(jsonData, p, 'lm_extra_micron', '');
    if (String.isNotBlank(micron)) clause += ' with ' + micron.trim() + ' micron.';
 	System.debug('outside '+p+'lm_pu_paint');
    if (rowBool(jsonData, p, 'lm_pu_paint')) {
        System.debug('inside '+p+'lm_pu_paint');
        clause += ' PU Paint to be provided';
        String note = rowStr(jsonData, p, 'lm_pu_paint_note', '');
        if (String.isNotBlank(note)) clause += ' (' + note.trim() + ')';
        clause += '.';
    }
    return clause;
}
 
// ADDITIONAL DETAILS (Signage Mast) - the sentence shown under the mast description.
//
// This deliberately does NOT go into descMast. buildHighMastGroups() assigns descMast
// unescaped and the page renders that cell with escape="false", whereas descAdditional is
// rendered by a plain outputText, so VF escapes it - and lm_ad_description is free text the
// user types. Same reason descSpecial exists as its own property.
//
// Returns '' unless this is a Signage Mast quote with a description typed in, so no other
// mast type can reach the text. Reetabrata (16th July 2026)
private String additionalDetailDesc(Map<String,Object> m) {
    // Latching Mast shares the same lm_ad_* block. Reetabrata (16th July 2026)
    if (!isSignageMast && !isLatchingMast) return '';
    // NOTE: 'desc' is an Apex reserved keyword (SOQL ORDER BY ... DESC) and cannot be used
    // as a variable name. Reetabrata (16th July 2026)
    String adText = strVal(m, 'lm_ad_description', '');
    if (String.isBlank(adText)) return '';
    String c = adText.trim();
    // The weight is only meaningful on the Weight basis; on the Price basis the user typed a
    // rupee value and lm_ad_weight stays empty.
    Decimal w = decVal(m, 'lm_ad_weight', 0);
    if (strVal(m, 'lm_ad_basis', '').equalsIgnoreCase('Weight') && w > 0) {
        c += ' - ' + cmNum(w) + ' Kg';
    }
    return c + '.';
}
 
// ADDITIONAL DETAILS (Signage Mast) - the pre-GST rate folded into the group's combined
// rate. lm_ad_unit_price already carries GST (the estimator formula multiplies by 1.18) and
// the group recomputes GST from its rate, so the GST is divided back out here to avoid
// charging it twice. Returns 0 when unused, which leaves every other quote's totals
// untouched. Reetabrata (16th July 2026)
private Decimal additionalDetailRate(Map<String,Object> m, Decimal gstPct) {
    // Latching Mast shares the same lm_ad_* block. Reetabrata (16th July 2026)
    if (!isSignageMast && !isLatchingMast) return 0;
    if (String.isBlank(strVal(m, 'lm_ad_description', ''))) return 0;
    Decimal adUnit = decVal(m, 'lm_ad_unit_price', 0);
    if (adUnit <= 0) return 0;
    return adUnit / (1 + (gstPct / 100));
}
 
    // Flag mast additional and accessory part
    private static final Integer FM_AC_ROWS  = 8;
private static final Integer FM_ADD_ROWS = 5;
 
// ═══════════════════════════════════════════════════════════════════════
// FLAG MAST ACCESSORY / ADDITIONAL grids - real blueprint shape.
// Both are FIXED-ROW catalogues, not user-named repeaters:
//   fm_ac_{n}_option / _qty / _rate / _amount   (7 rows)
//   fm_ad_{n}_qty / _rate / _amount             (5 rows)
// The item name lives in the metadata as a header field (fm_ac_{n}_hdr /
// fm_ad_{n}_desc, type=header), so it is NOT saved on the quote and has to
// be carried here. The old r{n}_fm_ac_item_name / r{n}_fm_add_* keys the
// previous code read do not exist and never resolved.
//
// PRICING: _amount is a readOnly formula = qty * rate * 1.18, i.e. it is
// GST-INCLUSIVE. cmGroup() adds GST itself, so the pre-GST figure (qty * rate)
// is what gets summed here - passing _amount would charge GST twice.
// _grand_total = SUM(_amount) * (1 + realization/100), so the realization
// uplift is applied to the pre-GST sum to land on the same number.
// Deepanjan (16th July 2026)
// ═══════════════════════════════════════════════════════════════════════
private static final List<String> FM_AC_LABELS = new List<String>{
    'Wire Rope', 'Wire rope', 'Winch Gear', 'Motor',
    'Snap hook', 'SS Accessories & Flag Clamps', 'Counter weight', 'Control Panel' };
 
private static final List<String> FM_AD_LABELS = new List<String>{
    '32A STD FEEDER PILLAR', 'GI STAND',
    'CONTROL PANEL FOR OPERATE ONLY MOTOR OPERATE',
    'SMALL LIGHT FEEDER PILLAR WITH STAND', 'Decorative Dome' };
 

// ── FLAG MAST ACCESSORY spec text - Segment Above 5 ONLY. Deepanjan (21st Aug 2026)
//    "Wire Rope (8) - 100 Nos"  ->  "Wire Rope 8 mm - 100"
//    Same helper and same fixed units as HighMastSOWController, so the Single and
//    Combined scopes cannot drift. The single-segment Customized Mast Flag Mast
//    passes seg5 = false and its wording stays byte-identical.
private static final List<String> FM_AC_UNITS = new List<String>{
    'mm', 'mm', 'KG', 'HP', '', '', '', '' };

private String fmAcSpec(Map<String,Object> m, String p, Integer i) {
    String opt = strVal(m, p + 'option', '');
    if (String.isBlank(opt)) return '';
    String unit = strVal(m, p + 'unit',
                  (i >= 1 && i <= FM_AC_UNITS.size()) ? FM_AC_UNITS[i - 1] : '');
    String gear = strVal(m, p + 'gear', '');
    String s = ' ' + opt.trim();
    if (String.isNotBlank(unit)) s += ' ' + unit.trim();
    if (String.isNotBlank(gear)) s += ' ' + gear.trim();
    return s;
}

// PU PAINT for Segment Above 5 Flag Mast - no longer its own group.
// Lighting Mast has always printed PU Paint as a clause inside the mast
// description (micronPaintClause) and never priced it in the offer - the charge
// reaches the quote through the estimator's own isUnitPrice line item on
// lm_pu_paint_unit_price. Flag Mast seg5 uses the same lm_pu_paint* keys, so it
// now behaves identically. Deepanjan (21st Aug 2026)
private String seg5FlagPuClause(Map<String,Object> m, String p, Boolean allowQuoteLevel) {
    // Row key first. The QUOTE-LEVEL key (a pre-27-Jul quote that saved a single
    // unprefixed lm_pu_paint) is honoured on the FIRST mast row only - a blanket
    // bare-key fallback would repeat the same sentence on all ten rows, where the
    // old seg5FlagPuPaintLine printed it exactly once. Deepanjan (21st Aug 2026)
    Boolean rowOn = cmBool(m, p + 'lm_pu_paint');
    Boolean qOn   = (allowQuoteLevel == true) && cmBool(m, 'lm_pu_paint');
    if (!rowOn && !qOn) return '';
    String note = rowOn ? strVal(m, p + 'lm_pu_paint_note', '')
                        : strVal(m, 'lm_pu_paint_note', '');
    String c = ' PU Paint to be provided';
    if (String.isNotBlank(note)) c += ' (' + note.trim() + ')';
    return c + '.';
}

private Integer cmFlagAccessoryItemGroups(Map<String,Object> m, String rPfx, Integer rowIdx,
                                                 Decimal gstPct, String freight, Integer sl,
                                                 Boolean seg5) {
    Decimal grand = decVal(m, rPfx + 'fm_ac_grand_total', 0);
    if (grand <= 0) return sl;

    List<String> parts = new List<String>();
    for (Integer i = 1; i <= FM_AC_ROWS; i++) {
        String p = rPfx + 'fm_ac_' + i + '_';
        Decimal q = decVal(m, p + 'qty',    0);
        Decimal a = decVal(m, p + 'amount', 0);
        if (q <= 0 && a <= 0) continue;
        String opt = strVal(m, p + 'option', '');
        if (seg5 == true) {
            // No quantity in the seg5 wording at all - his call, 21st Aug 2026.
            parts.add(FM_AC_LABELS[i - 1] + fmAcSpec(m, p, i));
        } else {
            parts.add(FM_AC_LABELS[i - 1]
                      + (String.isNotBlank(opt) ? ' (' + opt + ')' : ''));
        }
    }

        Decimal qty = decVal(m, rPfx + 'fm_est_quantity', 0);
    if (qty <= 0) qty = decVal(m, rPfx + 'lm_quantity', 0);   // Segment Above 5 rows carry the mast qty here
    if (qty <= 0) qty = 1;
    mastGroups.add(cmGroup(String.valueOf(sl++),
        'Supply of FLAG MAST ACCESSORY '
        + (parts.isEmpty() ? '' : ' - ' + String.join(parts, ', ')) + '.',
        '', grand.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
    return sl;
}
    
private Integer cmFlagAdditionalItemGroups(Map<String,Object> m, String rPfx, Integer rowIdx,
                                                  Decimal gstPct, String freight, Integer sl) {
    Decimal grand = decVal(m, rPfx + 'fm_ad_grand_total', 0);
    if (grand <= 0) return sl;
    Decimal rate = grand;

    List<String> parts = new List<String>();
    for (Integer i = 1; i <= FM_ADD_ROWS; i++) {
        String p = rPfx + 'fm_ad_' + i + '_';
        Decimal q = decVal(m, p + 'qty', 0);
        if (q <= 0) continue;
          parts.add(FM_AD_LABELS[i - 1]);
    }
        Decimal qty = decVal(m, rPfx + 'fm_est_quantity', 0);
    if (qty <= 0) qty = decVal(m, rPfx + 'lm_quantity', 0);   // Segment Above 5 rows carry the mast qty here
    if (qty <= 0) qty = 1;
    mastGroups.add(cmGroup(String.valueOf(sl++),
        ' Supply of FLAG MAST ADDITIONAL ITEM '
        + (parts.isEmpty() ? '' : ' - ' + String.join(parts, ', ')) + '.',
        '', rate.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
    return sl;
}
private String cmNum(Decimal d) {
        if (d == null) return '0';
        if (d == d.setScale(2, RoundingMode.FLOOR)) return String.valueOf(d.longValue());
        return String.valueOf(d.setScale(2, RoundingMode.HALF_UP));
    }
 
    private Boolean boolVal(Map<String,Object> m, String key, Boolean def) {
        if (!m.containsKey(key) || m.get(key) == null) return def;
        try { return (Boolean) m.get(key); } catch (Exception e) { return def; }
    }
 
    /* FOUNDATION BOLT TYPE - Deepanjan (20th Aug 2026)
       "Without Foundation" drops the whole foundation line - description AND
       rate - exactly as the Customized Mast builder already does with
       foundation_bolt_type. Any recipe without that picklist leaves the key
       absent -> '' -> not 'without' -> every existing offer is unchanged. */
    private Boolean fdnSuppressed(Map<String, Object> m, String p) {
        return strVal(m, p + 'lm_fdn_bolt_type', '').containsIgnoreCase('without');
    }

    /* "Without Foundation" wording - Deepanjan (21st Aug 2026)
       The foundation line used to be dropped entirely. It now prints the bolt
       spec the mast is SUITABLE for and states that it is not supplied, in red,
       at rate 0. The whole sentence is red, so it is wrapped in FDN_NIS_ON /
       FDN_NIS_OFF sentinels that the description escape pass turns into a span -
       the same trick RED_LED already uses, so the dynamic values still go
       through the HTML escape first.
       "PCD <n>mm " is omitted in full when lm_pcd is blank / 0 - his call.
       Reached only when lm_fdn_bolt_type contains "without", a key that exists
       on the Segment Above 5 recipes alone, so no other mast type can see it. */
    // ── BRACKET WORDING ──────────────────────────────────────────────────────
    // BRACKET TYPE = Customized -> print the CUSTOMIZED DESCRIPTION text instead of the
    // word "Customized" (e.g. "Channel Bracket"). Blank description keeps "Customized",
    // exactly as today. Every other type is returned untouched. Mirrors the helper of the
    // same name in HighMastSOWController so both PDFs read alike.
    // Deepanjan (24th Aug 2026)
    private String bracketLabel(Map<String, Object> m, String bracketType, String prefix, String prefixCus) {
        if (!'Customized'.equalsIgnoreCase(bracketType)) return bracketType;
        // NOTE: the local is custDesc, not desc - 'desc' is an Apex reserved word (SOQL
        // ORDER BY ... DESC) and will not compile. Deepanjan (24th Aug 2026)
        String custDesc = strVal(m, prefix + 'customized_description',
                          strVal(m, prefixCus + 'customized_description', ''));
        return String.isNotBlank(custDesc) ? custDesc.trim() : bracketType;
    }

    // NO. OF ARM is a 1/2/3/4 picklist (it only enables for a Standard bracket) and the
    // offer must read the word: "Standard bracket with Double arm". Anything else - blank
    // or a free-text value like "Ring" - comes back untouched. Deepanjan (24th Aug 2026)
    private String armWord(String typeOfArm) {
        if (String.isBlank(typeOfArm)) return typeOfArm;
        String t = typeOfArm.trim();
        if (t == '1') return 'Single';
        if (t == '2') return 'Double';
        if (t == '3') return 'Triple';
        if (t == '4') return 'Four';
        return t;
    }

    private String armNumtoWord(String typeOfArm) {
        if (String.isBlank(typeOfArm)) return typeOfArm;
        String t = typeOfArm.trim();
        if (t == '1') return 'One';
        if (t == '2') return 'Two';
        if (t == '3') return 'Three';
        if (t == '4') return 'Four';
        return t;
    }

    private String fdnNotInScopeDesc(String fbDia, Decimal fbLen, Decimal fbNo, Decimal pcd) {
        // Every part is dropped when it is blank / 0, same rule PCD follows, and the
        // separator goes with the part it belongs to - so no stray " x ", no leading
        // space and no dangling comma. Deepanjan (21st Aug 2026)
        List<String> dims = new List<String>();
        // '0' is what the callers substitute for a blank diameter, so it is treated as
        // blank here too - otherwise an untouched foundation printed "dia. M0".
        // A real bolt diameter is never 0. Deepanjan (24th Aug 2026)
        // Add Dia with conditional "J Type " prefix
        if (String.isNotBlank(fbDia) && !fbDia.trim().equals('0')) {
            dims.add(('Octagonal Pole'.equalsIgnoreCase(typeOfMast) ? 'J Type Bolts M' : 'M') + fbDia.trim());
        }
        if (fbLen != null && fbLen > 0)          dims.add(cmNum(fbLen) + 'mm');
        String spec = String.join(dims, ' x ');
        if (fbNo != null && fbNo > 0) {
            spec += (String.isBlank(spec) ? '' : ' ') + '(' + cmNum(fbNo) + 'nos.)';
        }
        if (pcd != null && pcd > 0) {
            spec += (String.isBlank(spec) ? '' : ', ') + 'PCD ' + cmNum(pcd) + 'mm';
        }
        return '\u0001FDN_NIS_ON\u0001'
             + 'Suitable for foundation bolt dia.'
             + (String.isBlank(spec) ? '' : ' ' + spec)
             + ' Not in our Scope'
             + '\u0001FDN_NIS_OFF\u0001';
    }

    private String strVal(Map<String, Object> m, String key, String def) {
        if (!m.containsKey(key) || m.get(key) == null) return def;
        String v = String.valueOf(m.get(key)).trim();
        return String.isNotBlank(v) ? v : def;
    }
 
    private String afterEq(String raw, String fallback) {
        if (String.isBlank(raw)) return fallback;
        return raw.contains('=') ? raw.substringAfter('=').trim() : raw.trim();
    }
 
    /*private String buildAddress(Account a) {
        if (a == null) return '';
        List<String> p = new List<String>();
        if (String.isNotBlank(a.BillingStreet))     p.add(a.BillingStreet);
        if (String.isNotBlank(a.BillingCity))       p.add(a.BillingCity);
        if (String.isNotBlank(a.BillingState))      p.add(a.BillingState);
        if (String.isNotBlank(a.BillingPostalCode)) p.add(a.BillingPostalCode);
        return String.join(p, ', ');
    }*/
    
    private String buildAddress(Map<String,Object> jsonData, String prefix) {
        if (jsonData == null) return '';
        String destination = '';
        List<String> addressParts = new List<String>();
        List<String> fieldSuffixes = new List<String>{'street', 'city', 'state', 'zip', 'country'};

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

        return String.isNotBlank(destination) ? ' ' + destination : '';
    }

    // KIT-aware resolution. The winch / power tool / wire rope / cable picklists live in the
    // HM ITEMS (KIT line) section, so they save as kit_line_{n}_lm_*. buildHighMastLineItems()
    // was passing only the r{n}_ mast-row prefix, so every one of them missed and the
    // hardcoded legacy defaults ('E=350 kg', 'G=Motor,3PH', '5=5mm dia') printed instead.
    // Order: kit first (the real source), then the row prefix, then bare - so any quote that
    // already resolved keeps resolving to the same value.
    private String accSpecRaw(Map<String,Object> m, String kitPfx, String rowPfx,
                              String hmKey, String lmKey, String def) {
        for (String pfx : new List<String>{ kitPfx, rowPfx, '' }) {
            String v = strVal(m, pfx + hmKey, '');
            if (String.isBlank(v)) v = strVal(m, pfx + lmKey, '');
            if (String.isNotBlank(v)) return v;
        }
        return def;
    }
 
    /* Divide-by-quantity (the Combined quantity change, 22nd Aug 2026) can leave the per
       unit figures fractional - MRL: 24,28,250 / 4 = 6,07,062.50. Printing those rounded to
       whole rupees makes Unit Rate x Qty disagree with Total on paper by a rupee or two, so
       the three per-unit cells print the paise WHEN THERE ARE ANY. A whole-rupee value is
       formatted exactly as formatINR always did, so every existing offer is byte-identical.
       Deepanjan (22nd Aug 2026) */
    private String formatINR2(Decimal val) {
        if (val == null) return '0';
        Decimal r2 = val.setScale(2, RoundingMode.HALF_UP);
        if (r2 == r2.setScale(2, RoundingMode.HALF_UP)) return formatINR(r2);   // whole -> unchanged
        Decimal whole = r2.abs().setScale(2, RoundingMode.DOWN);
        Integer paise = ((r2.abs() - whole) * 100).setScale(2, RoundingMode.HALF_UP).intValue();
        String  pStr  = (paise < 10 ? '0' : '') + String.valueOf(paise);
        return (r2 < 0 ? '-' : '') + formatINR(whole) + '.' + pStr;
    }

        private String formatINR(Decimal val) {
        if (val == null) return '0.00';
        Decimal d   = val.setScale(2, RoundingMode.HALF_UP);
        Boolean neg = d < 0;
        d = d.abs();

        Long    whole = d.setScale(2, RoundingMode.DOWN).longValue();
        Integer paise = ((d - whole) * 100).setScale(2, RoundingMode.HALF_UP).intValue();
        if (paise >= 100) { whole += 1; paise = 0; }   // guards 99.999 -> 100.00

        String s = String.valueOf(whole);
        String grouped;
        if (s.length() <= 3) {
            grouped = s;
        } else {
            String result    = s.substring(s.length() - 3);
            String remaining = s.substring(0, s.length() - 3);
            while (remaining.length() > 2) {
                result    = remaining.substring(remaining.length() - 2) + ',' + result;
                remaining = remaining.substring(0, remaining.length() - 2);
            }
            grouped = remaining + ',' + result;
        }

        String pStr = (paise < 10 ? '0' : '') + String.valueOf(paise);
        return (neg ? '-' : '') + grouped + '.' + pStr;
    }
 
    private String numberToWords(Long num) {
        if (num == 0) return 'Zero Only';
        String[] ones = new String[]{ '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen' };
        String[] tens = new String[]{ '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety' };
        String result = '';
        Long crore = num / 10000000; num = Math.mod(num, 10000000);
        Long lakh  = num / 100000;   num = Math.mod(num, 100000);
        Long thou  = num / 1000;     num = Math.mod(num, 1000);
        Long hund  = num / 100;      num = Math.mod(num, 100);
        if (crore > 0) result += twoD(crore, ones, tens) + ' Crore ';
        if (lakh  > 0) result += twoD(lakh,  ones, tens) + ' Lakh ';
        if (thou  > 0) result += twoD(thou,  ones, tens) + ' Thousand ';
        if (hund  > 0) result += ones[(Integer) hund]    + ' Hundred ';
        if (num   > 0) result += twoD(num,   ones, tens) + ' ';
        return result.trim() + ' Only';
    }
 
    /*private String twoD(Long n, String[] ones, String[] tens) {
        if (n < 20) return ones[(Integer) n];
        return tens[(Integer)(n / 10)] + (Math.mod(n, 10) > 0 ? ' ' + ones[(Integer) Math.mod(n, 10)] : '');
    }*/
    
    // ── Reetabrata (8th July 2026)
    private String twoD(Long n, String[] ones, String[] tens) {
    if (n < 0) n = 0;
    if (n < 20) return ones[(Integer) n];
    Integer t = (Integer)(n / 10);
    if (t > 9) {
        // n >= 100 (very large group) — break into hundreds so we never index past the array - Reetabrata (8th July 2026)
        Long h = n / 100;
        Long rem = Math.mod(n, 100);
        return twoD(h, ones, tens) + ' Hundred' + (rem > 0 ? ' ' + twoD(rem, ones, tens) : '');
    }
    return tens[t] + (Math.mod(n, 10) > 0 ? ' ' + ones[(Integer) Math.mod(n, 10)] : '');
}

/**
 * Resolves the appropriate wind speed suffix string based on YES/NO payload flags and direct value keys.
 */
private String getWindSpeedSuffix() {
    String windSpeedVal = '';
    
    // --- YES / NO Key Check Evaluators ---
    Boolean isLpWind     = 'YES'.equalsIgnoreCase(strVal(jsonData, 'lp_wind_speed', 'NO'));
    Boolean isTpWind     = 'YES'.equalsIgnoreCase(strVal(jsonData, 'tp_wind_speed', 'NO'));
    Boolean isMastWind   = 'YES'.equalsIgnoreCase(strVal(jsonData, 'wind_speed', 'NO'));
    Boolean isFmWind     = 'YES'.equalsIgnoreCase(strVal(jsonData, 'fm_wind_speed', 'NO'));
    
    Boolean isOpWind     = 'YES'.equalsIgnoreCase(strVal(jsonData, 'op_wind_speed', 'NO'));
    Boolean isCusOpWind  = 'YES'.equalsIgnoreCase(strVal(jsonData, 'for_cus_op_wind_speed', 'NO'));
    Boolean isOpMhpWind  = 'YES'.equalsIgnoreCase(strVal(jsonData, 'op_mhp_wind_speed', 'NO'));

    // --- Direct Wind Speed Value Check Evaluators ---
    String manRidingWind   = strVal(jsonData, 'man_riding_wind_speed', '');
    String ladderCageWind  = strVal(jsonData, 'ladder_cage_wind_speed', '');

    // DEBUG LOG: Trace actual string evaluations
    System.debug('--- WIND SPEED YES/NO & DIRECT VALUE EVALUATION START ---');
    System.debug('Flags (YES/NO) -> lp_wind_speed: ' + isLpWind + ', tp_wind_speed: ' + isTpWind + ', wind_speed: ' + isMastWind + ', fm_wind_speed: ' + isFmWind);
    System.debug('Flags (YES/NO) -> op_wind_speed: ' + isOpWind + ', for_cus_op_wind_speed: ' + isCusOpWind + ', op_mhp_wind_speed: ' + isOpMhpWind);
    System.debug('Direct Values  -> man_riding_wind_speed: ' + manRidingWind + ', ladder_cage_wind_speed: ' + ladderCageWind);

    // --- Mapping Priority Hierarchy ---
    // 1. Check YES/NO evaluated mappings first
    if (isLpWind) {
        windSpeedVal = strVal(jsonData, 'lp_wind_speed_value', '');
        System.debug('Matched: Lightning Pole. Value: ' + windSpeedVal);
    } else if (isTpWind) {
        windSpeedVal = strVal(jsonData, 'tp_wind_speed_value', '');
        System.debug('Matched: Transmission Pole. Value: ' + windSpeedVal);
    } else if (isMastWind) {
        windSpeedVal = strVal(jsonData, 'wind_speed_value', '');
        System.debug('Matched: Lightning Mast. Value: ' + windSpeedVal);
    } else if (isFmWind) {
        windSpeedVal = strVal(jsonData, 'fm_wind_speed_value', '');
        System.debug('Matched: Flag Mast. Value: ' + windSpeedVal);
    } else if (isOpWind) {
        windSpeedVal = strVal(jsonData, 'op_wind_speed_value', '');
        System.debug('Matched: Standard Lightning Pole (Octagonal). Value: ' + windSpeedVal);
    } else if (isCusOpWind) {
        windSpeedVal = strVal(jsonData, 'for_cus_op_wind_speed_value', '');
        System.debug('Matched: Customized Lightning Pole (Octagonal). Value: ' + windSpeedVal);
    } else if (isOpMhpWind) {
        windSpeedVal = strVal(jsonData, 'op_mhp_wind_speed_value', '');
        System.debug('Matched: Mid Hinge Pole (Octagonal). Value: ' + windSpeedVal);
    } 
    // 2. Fall back to Direct Value Keys if no YES/NO flags are active
    else if (String.isNotBlank(manRidingWind)) {
        windSpeedVal = manRidingWind;
        System.debug('Matched Direct Value: Man Riding. Value: ' + windSpeedVal);
    } else if (String.isNotBlank(ladderCageWind)) {
        windSpeedVal = ladderCageWind;
        System.debug('Matched Direct Value: Ladder Cage. Value: ' + windSpeedVal);
    } else {
        System.debug('No active wind speed flag or direct value populated.');
    }

    System.debug('--- WIND SPEED YES/NO & DIRECT VALUE EVALUATION END ---');

    if (String.isNotBlank(windSpeedVal)) {
        return ' wind speed ' + windSpeedVal + '.';
    }
    return '';
}
// ── Reetabrata (8th July 2026)
    /* ONE LINE ITEM ON THE ANNEXURE. Each product owns its rows and its own sub-total,
       so the page can print: 1 <product> ... SUB-TOTAL, 2 <product> ... SUB-TOTAL, Total.
       Deepanjan (18th August 2026) */
    public class ProductGroupWrapper {
        public String  slNo           { get; set; }
        public List<MastGroupWrapper> rows { get; set; }
        public Boolean showSubTotal   { get; set; }
        public String  subUnitRate    { get; set; }
        public String  subGstAmount   { get; set; }
        public String  subUnitAmount  { get; set; }
        public String  subTotalAmount { get; set; }
        // Qty for the SUB-TOTAL row. Without it the row jumps from Unit Amount
        // straight to Total Amount with the x qty step invisible, which is what
        // made the figures look wrong. Deepanjan (18th Aug 2026)
        public String  subQty         { get; set; }

        public ProductGroupWrapper() {
            rows         = new List<MastGroupWrapper>();
            showSubTotal = true;
        }
    }
    
    
    // for wording and paisa 

        private String amountInWords(Decimal amt) {
        if (amt == null) amt = 0;
        Decimal d     = amt.setScale(2, RoundingMode.HALF_UP);
        Long    rupee = d.setScale(0, RoundingMode.DOWN).longValue();
        Integer paise = ((d - rupee) * 100).setScale(0, RoundingMode.HALF_UP).intValue();
        if (paise >= 100) { rupee += 1; paise = 0; }

        String w = numberToWords(rupee);
        if (paise == 0) return w;
        return w.removeEnd(' Only').trim() + ' and '
             + numberToWords(paise).removeEnd(' Only').trim() + ' Paise Only';
    }
    
            /*
            * @Method: buildAccessoryDescription
            * @Purpose: Builds "Supply of MID-HINGE ACCESSORIES - 350 KG WINCH, 6mm WIRE ROPE WITH FASTENERS
            *           alongwith LOCK & MANUAL HANDLE" from the accessory names.
            *           Known accessories get their standard size prefix; LOCK & MANUAL HANDLE is always
            *           moved to the end and introduced with "alongwith".
            */
    private static String buildAccessoryDescription(List<String> names) {
        if (names == null || names.isEmpty()) {
            return 'Supply of MID-HINGE ACCESSORIES';
        }

        List<String> mainParts = new List<String>();
        String tailPart = null;

        for (String nm : names) {
            if (String.isBlank(nm)) continue;
            String n = nm.trim();

            if (n.containsIgnoreCase('LOCK') && n.containsIgnoreCase('MANUAL HANDLE')) {
                tailPart = 'LOCK & MANUAL HANDLE';
            }
            else if (n.containsIgnoreCase('WIRE ROPE')) {
                mainParts.add('6mm WIRE ROPE WITH FASTENERS');
            }
            else if (n.containsIgnoreCase('WINCH')) {
                mainParts.add('350 KG WINCH');
            }
            else {
                // Unrecognised accessory - use the configured name as-is
                mainParts.add(n);
            }
        }

        String joined = String.join(mainParts, ', ');

        if (tailPart != null) {
            joined = String.isBlank(joined) ? tailPart : joined + ' alongwith ' + tailPart;
        }

        if (String.isBlank(joined)) {
            return 'Supply of MID-HINGE ACCESSORIES';
        }
        return 'Supply of MID-HINGE ACCESSORIES - ' + joined;
    }
    
    /* Every group in mastGroups is one line item by this point - the Customized Mast path
       has already collapsed each product into a single group, and every other mast type
       adds exactly one group per mast. The rows are renumbered 1..N here, so the numbering
       no longer depends on the slCounter each builder happens to keep.

       Transportation Charges is not a product, so it is numbered like any other row but
       carries no sub-total of its own - flip showSubTotal to true below if that line
       should get one. Deepanjan (18th August 2026) */
    private void buildProductGroups() {
        Integer n = 1;
        for (MastGroupWrapper g : mastGroups) {
            g.slNo = String.valueOf(n);

            ProductGroupWrapper prod = new ProductGroupWrapper();
            prod.slNo = String.valueOf(n);
            prod.rows.add(g);

            Boolean isTransport = (g.descMast != null)
                && g.descMast.startsWithIgnoreCase('Transportation Charges');
            prod.showSubTotal = !isTransport;

            // The SUB-TOTAL row mirrors its own line row, so it must use the same formatter -
            // otherwise a divided (fractional) per-unit rate printed 6,07,062.50 on the line
            // and 6,07,063 one row below it. formatINR2 is identical to formatINR for whole
            // rupees, so every existing offer is unchanged. Deepanjan (22nd Aug 2026)
            prod.subUnitRate    = formatINR2(g.unitRateRaw);
            prod.subGstAmount   = formatINR2(g.gstAmountRaw);
            prod.subUnitAmount  = formatINR2(g.unitAmountRaw);
            prod.subTotalAmount = formatINR(g.totalAmountRaw);
            prod.subQty         = g.qty;   // Deepanjan (18th Aug 2026)

            productGroups.add(prod);
            n++;
        }
    }

    public class MastGroupWrapper {
        public String  slNo           { get; set; }
        public String  descMast       { get; set; }
        public String  descBolt       { get; set; }
        public String  descAcc        { get; set; }
        public String  descAccHead    { get; set; }   // Segment Above 5: per-mast bold head "Supply of <h> MTR ... ACCESSORIES PART: " (replaces the document-level accessoriesLabel, which is blank for seg5) - Deepanjan (7th September 2026)
        public String  descSpecial    { get; set; }   // Segment Above 5 special item - Reetabrata (9th July 2026)
        public String  descAdditional { get; set; }   // Signage Mast Additional Details - Reetabrata (16th July 2026)
        public String  unitRate       { get; set; }
        public String  gstPct         { get; set; }
        public String  gstAmount      { get; set; }
        public String  freight        { get; set; }
        public String  unitAmount     { get; set; }
        public String  qty            { get; set; }
        // Unrounded qty, kept so cmCollapseSlice can weight each group's rate
        // exactly. qty above is String.valueOf(qty.intValue()) and would lose a
        // fractional quantity. Not referenced by the VF page. Deepanjan (16th July 2026)
        public Decimal qtyRaw         { get; set; }
        public String  totalAmount    { get; set; }
        public Decimal unitRateRaw    { get; set; }
        public Decimal gstAmountRaw   { get; set; }
        public Decimal unitAmountRaw  { get; set; }
        public Decimal totalAmountRaw { get; set; }
        public String boltDia         { get; set; }  // added by shivendra for lightning Mast if Dia = N.R. then on UI we need to show (NOT REFLECTED ON UI) in bold (4th Aug 2026)
    }
}