public class HighMastSOWController {

                                                 private static final Integer MAX_REPEATER_COLS = 10;
 
    public Quote quoteRecord { get; set; }
    public Map<String, Object> jsonData { get; set; }
 
    public String soWRef          { get; set; }
    public String soWDate         { get; set; }
    public String opportunityName { get; set; }
    public String buyerName       { get; set; }
    public String buyerAddress    { get; set; }
    public String deliveryAddress  { get; set; }
    public String todayDate       { get; set; }
    public String transportationType { get; set; }
    public String deliverytime { get; set; }
    public String priceVariationdays { get; set; }
    public String quationValidity { get; set; }
    public String warrFromDOC { get; set; }
    public String warrFromDOD { get; set; }
 
    public List<LineItemWrapper> lineItems { get; set; }

    // ═══════════════════════════════════════════════════════════════════
    // ANNEXURE - A LINE ITEM GROUPING - Reetabrata (18th Aug 2026)
    //
    // One "line item" = one product the customer ordered. Its parts are
    // numbered 1.1, 1.2, 1.3 ... and a SUB-TOTAL row closes the group, then
    // 2.1, 2.2 ... and so on. startGroup() marks the boundaries at the exact
    // points where a new product begins in each builder - the same
    // boundaries HMScopeCombinedController uses for its products, so the two
    // PDFs always agree.
    //
    // lineItems keeps its current shape and order and the 45 existing
    // buildRow(String.valueOf(slCounter++), ...) call sites are untouched -
    // buildRow simply overrides the number it is handed once a group is
    // open. With no group open (curGroup == 0) the old number is kept, so
    // any path not marked here behaves exactly as it does today.
    // ═══════════════════════════════════════════════════════════════════
    public List<LineGroupWrapper> lineGroups { get; set; }

    // Mast/pole name for the SUB-TOTAL heading. Held here instead of in the page's
    // IF() chain so the Signage Mast custom name reaches it. Leading space kept, so
    // the printed heading is character-for-character what it is today.
    // Deepanjan (18th Aug 2026)
    public String mastTypeLabel { get; set; }

    // Flip to true to give Transportation Charges its own SUB-TOTAL row too.
    // Combined scope numbers it but gives it no SUB-TOTAL, so this matches.
    private static final Boolean SUBTOTAL_ON_FREIGHT_GROUP = false;

    private Integer curGroup     = 0;      // 0 = no group open yet
    private Integer curPart      = 0;
    private Boolean curPlain     = false;  // whole number, no SUB-TOTAL row
    private Integer lastFlatItem = -1;
    private Integer lastFlatSection = -1;  // last section index on a flat-list branch. Deepanjan (20th Aug 2026)
    private Set<Integer> plainGroups = new Set<Integer>();
    public String subTotalUnitRate { get; set; }
    public String subTotalGST      { get; set; }
    public String subTotalUnit     { get; set; }
    public String subTotalAmount   { get; set; }
    public String grandTotal       { get; set; }
    public String grandTotalWords  { get; set; }
    
    public String typeOfMast          { get; set; }
    public Boolean isLightingPole     { get; set; }
    public Boolean isTransmissionPole { get; set; }
    public Boolean isMidHingePole     { get; set; }   // NEW
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
    // Additional Details line is new. Reetabrata (16th July 2026)
    public Boolean isSignageMast      { get; set; }
    // Latching Mast. Own Section_Logic + own Blueprint (L-Ring/Head Frame weight removed
    // there, not here), but the saved JSON is the Lighting Mast shape (same lm_* keys), so
    // it keeps using the existing High Mast builder. Reetabrata (16th July 2026)
    public Boolean isLatchingMast     { get; set; }
    // Custom Lightning Mast. Own Section_Logic + own Blueprint record, but the saved JSON is
    // the Lighting Mast shape (same lm_* keys, same r{n}_ row prefixes), so it keeps using
    // the existing High Mast builder. The ONLY difference is the Special Additions sentence
    // appended to the mast description. Faizan (24th July 2026)
    public Boolean isCustomLightningMast { get; set; }
    public String singageSpecAdd {get; set;}

    public Boolean perPolfrieght   {get; set;}
    public Decimal perPolTPCharg   {get; set;}

    // User Session Metadata
    public String loggedInUser { get; set; }
    public String loggedInUserPhone { get; set; }
    public String loggedInUserTitle { get; set; }
    public String loggedInUserEmail { get; set; }
    
     
    public HighMastSOWController(ApexPages.StandardController stdController) {
 
        todayDate         = Date.today().format();
        soWDate           = Date.today().format();
        soWRef            = 'UIL/HM/26-27/001';
        buyerName         = '';
        buyerAddress      = '';
        deliveryAddress   = '';
        opportunityName   = '';
        jsonData          = new Map<String, Object>();
        lineItems         = new List<LineItemWrapper>();
        lineGroups        = new List<LineGroupWrapper>();   // Reetabrata (18th Aug 2026)
        mastTypeLabel     = ' LIGHTING MAST';   // Deepanjan (18th Aug 2026)
        subTotalUnitRate  = '0';
        subTotalGST       = '0';
        subTotalUnit      = '0';
        subTotalAmount    = '0';
        grandTotal        = '0';
        grandTotalWords   = 'Zero Only';
        isLightingPole    = false;
        isTransmissionPole = false;
        isMidHingePole    = false;   // NEW
        isCustomizedMast  = false;
        isStadiumMast     = false;
        isFlagMast        = false;
        isSeg5FlagMast    = false;   // Deepanjan (22nd July 2026)
        isSegmentAbove5   = false;   // Deepanjan (19th Aug 2026)
        isLCLM             = false;   // Reetabrata (15th July 2026)
        isSignageMast      = false;   // Reetabrata (16th July 2026)
        isLatchingMast     = false;   // Reetabrata (16th July 2026)
        isCustomLightningMast = false;   // Faizan (24th July 2026)
 
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
        

        String mastStandard = strVal(jsonData, 'mast_standard', '');
        if (String.isBlank(mastStandard)) {
            mastStandard = strVal(jsonData, 'mast_standard_pole', '');  // fallback for this JSON shape
        }
        String mastStdLower = mastStandard.toLowerCase();
        isLightingPole     = mastStdLower.contains('lighting pole');
        // Same test the Combined controller uses, so the two SUB-TOTAL headings agree.
        // Deepanjan (24th Aug 2026)
        // 'pole' is required on purpose: the loose (custom && lighting) test the Combined
        // controller uses is also true for a "Custom Lighting Mast", which must keep its own
        // heading. Deepanjan (24th Aug 2026)
        Boolean isCustomLightingPole = mastStdLower.contains('custom lighting pole')
                                    || (mastStdLower.contains('custom')
                                        && mastStdLower.contains('lighting')
                                        && mastStdLower.contains('pole'));
        isTransmissionPole = mastStdLower.contains('transmission pole');
        isMidHingePole     = mastStdLower.contains('mid hinge');   // NEW
 
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
        // still falls through to buildHighMastLineItems(). Reetabrata (16th July 2026)
        isSignageMast    = cmType.equalsIgnoreCase('Signage Mast');
        // Latching Mast is a top-level type_of_mast value only - not offered under Segment
        // Above 5, so cmCustom is never 'Latching Mast'. mast_standard / mast_customized stay
        // blank for it, so the routing below is untouched and it still falls through to
        // buildHighMastLineItems(). Reetabrata (16th July 2026)
        isLatchingMast   = cmType.equalsIgnoreCase('Latching Mast');
        // Custom Lightning Mast is a top-level type_of_mast value only - it is not offered
        // under Segment Above 5, so cmCustom is never 'Custom Lightning Mast'. mast_standard
        // and mast_customized both stay blank for it, so the routing below is untouched and
        // it still falls through to buildHighMastLineItems(). Both spellings are accepted
        // because the picklist label has been written each way. Faizan (24th July 2026)
        isCustomLightningMast = cmType.equalsIgnoreCase('Custom Lightning Mast')
                                || cmType.equalsIgnoreCase('Custom Lighting Mast');
        isCustomizedMast = (isStadiumMast || isFlagMast)
                           && (cmType.equalsIgnoreCase('Customized Mast') || isSeg5);

        // SUB-TOTAL heading, same order the page's IF() chain used. Deepanjan (18th Aug 2026)
        // A Custom Lighting Pole used to fall through to the default and print "SUB-TOTAL OF
        // LIGHTING MAST". Only that one case is redirected - a Standard Lighting Pole still
        // has no branch here and keeps its current heading, exactly as today.
        // Deepanjan (24th Aug 2026)
        mastTypeLabel = isCustomLightingPole ? ' CUSTOM LIGHTNING POLE'
                      : isStadiumMast  ? ' STADIUM MAST'
                      : isFlagMast     ? ' FLAG MAST'
                      : isLCLM         ? ' LCLM'
                      : isSignageMast  ? ' ' + signageMastName()
                      : isLatchingMast ? ' LATCHING MAST'
                                       : ' LIGHTING MAST';
        // SEGMENT ABOVE 5 - FLAG MAST keeps isCustomizedMast true (same dispatch),
        // but the flag branch below must use the LM-keyed builder, not cmFlagLines().
        // Deepanjan (22nd July 2026)
        isSeg5FlagMast = isSeg5 && isFlagMast;
        isSegmentAbove5 = isSeg5;   // Deepanjan (19th Aug 2026)
        
        System.debug('custom Lighting pole: '+ isLightingPole +' | Customized Mast : '+ isCustomizedMast + ' | Custom Lightning Mast : '+ isCustomLightningMast);
        if(isCustomLightningMast){
            isLightingPole = false;
        }
        
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
            buildCustomizedMastLineItems();
        } else if (isLightingPole) {
            buildLightingPoleLineItems();
        } else if (isTransmissionPole) {
            buildTransmissionPoleLineItems();
        } else if (isMidHingePole) {                 // NEW
            buildMidHingePoleLineItems();            // NEW
        } else {
            buildHighMastLineItems();
        }
 
        // SUB-TOTAL is qty-weighted. Each line's Total Amount is (rate + gst) x qty, so a
        // sub-total that added the unrounded rates would not tie to the Total: a line at
        // qty 2 contributed its rate once. Weighting here makes Unit Rate + GST Amount =
        // Unit Amount = Total Amount across the row, and makes the Unit Rate column equal
        // the Combined Scope's single pre-GST rate. Deepanjan (17th July 2026)
        
        // check all quantity is same in stadium mast - 06-Aug
        Boolean weightUR = false;
        if (!lineItems.isEmpty()) {
            Decimal firstQty = (lineItems[0].qtyRaw == null ? 1 : lineItems[0].qtyRaw);
            for (LineItemWrapper w : lineItems) {
                Decimal q0 = (w.qtyRaw == null ? 1 : w.qtyRaw);
                if (q0 != firstQty) { weightUR = true; break; }
            }
        }
        
        Decimal sumUR = 0, sumGST = 0, sumUnit = 0, sumTotal = 0;
        for (LineItemWrapper w : lineItems) {
            Decimal q = (w.qtyRaw == null ? 1 : w.qtyRaw);
            sumUR    += w.unitRateRaw.setScale(2, RoundingMode.HALF_UP) * (weightUR ? q : 1);
            sumGST   += w.gstAmountRaw.setScale(2, RoundingMode.HALF_UP)  * q;
            sumUnit  += w.unitAmountRaw.setScale(2, RoundingMode.HALF_UP) * q;
            sumTotal += w.totalAmountRaw.setScale(2, RoundingMode.HALF_UP);
        }
        subTotalUnitRate = formatINR(sumUR);
        subTotalGST      = formatINR(sumGST);
        subTotalUnit      = formatINR(sumUnit);
        subTotalAmount   = formatINR(sumTotal);
        grandTotal       = formatINR(sumTotal);
        grandTotalWords  = amountInWords(sumTotal);

        // Slice the finished list into line items. Reetabrata (18th Aug 2026)
        buildLineGroups();
 
        ensureKey('freight_incoterms', 'Ex-works');
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // MID HINGE POLE BUILDER  ← NEW
    // ═══════════════════════════════════════════════════════════════════════
    private void buildMidHingePoleLineItems() {
 
        Decimal gstPct    = 18;
        String  freight   = strVal(jsonData, 'freight_incoterms', 'Ex-works');
        Integer slCounter = 1;
        Decimal totalPoleQty = 0;
 
        List<Object> apexLines = getList(jsonData, '_Final_Apex_Lines');
        Set<String> mhpFdnSeen = fdnItemsPresent(apexLines);
        if (!apexLines.isEmpty()) {
            for (Object lineObj : apexLines) {
                Map<String, Object> line = (Map<String, Object>) lineObj;
                String itemName = strVal(line, 'name', 'Mid Hinge Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)
 
                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(line, 'expenses', 0).setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty        = decVal(line, 'quantity', 1);
                    
                    String displayItemName = itemName.replace('(Lump Sum)', '').trim();

                   
                    lineItems.add(buildRow(String.valueOf(slCounter++),
                                  displayItemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }
 
                Decimal qty       = decVal(line, 'quantity', 1);
                Decimal unitPrice = (decVal(line, 'unitPrice', 0)).setScale(2, RoundingMode.HALF_UP);
                String  description = buildMHPDescription(itemName, line);
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              description, unitPrice, gstPct, qty, freight));
 
                if (!itemName.containsIgnoreCase('Foundation')
                        && !itemName.containsIgnoreCase('Bracket')
                        && !itemName.containsIgnoreCase('Arm')) {
                    totalPoleQty += qty;
                    // FOUNDATION BOLT = N.R. but the estimator saved no Foundation line for
                    // this pole, so the out-of-scope sentence would have nowhere to print.
                    // Rate 0. Deepanjan (24th Aug 2026)
                    slCounter = addFdnNotInScopeRowMhp(itemName, mhpFdnSeen, qty,
                                                       gstPct, freight, slCounter);
                }
            }
            //appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
 
        List<Object> tableRows = getList(jsonData, '_Saved_Table_Rows');
        mhpFdnSeen = fdnItemsPresent(tableRows);
        if (!tableRows.isEmpty()) {
            for (Object rowObj : tableRows) {
                Map<String, Object> row = (Map<String, Object>) rowObj;
                String itemName = strVal(row, 'name', 'Mid Hinge Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)
 
                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(row, 'expenses', 0).setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty        = decVal(row, 'quantity', 1);
                    lineItems.add(buildRow(String.valueOf(slCounter++),
                                  itemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }
 
                Decimal qty       = decVal(row, 'quantity', 1);
                Decimal unitPrice = (decVal(row, 'unitPrice', 0)).setScale(2, RoundingMode.HALF_UP);
                String  description = buildMHPDescription(itemName, row);
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              description, unitPrice, gstPct, qty, freight));
 
                if (!itemName.containsIgnoreCase('Foundation')
                        && !itemName.containsIgnoreCase('Bracket')
                        && !itemName.containsIgnoreCase('Arm')) {
                    totalPoleQty += qty;
                    // FOUNDATION BOLT = N.R. but the estimator saved no Foundation line for
                    // this pole, so the out-of-scope sentence would have nowhere to print.
                    // Rate 0. Deepanjan (24th Aug 2026)
                    slCounter = addFdnNotInScopeRowMhp(itemName, mhpFdnSeen, qty,
                                                       gstPct, freight, slCounter);
                }
            }
            //appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
 
        Integer maxCols = (Integer) decVal(jsonData, 'mhp_no_of_items', 0).intValue();
        if (maxCols == 0) maxCols = MAX_REPEATER_COLS;
        maxCols = Math.min(maxCols, MAX_REPEATER_COLS);
 
        for (Integer col = 1; col <= maxCols; col++) {
            String cp = 'c' + col + '_mhp_';
            String op = 'c' + col + '_op_mhp_';
 
            Decimal height       = decVal(jsonData, cp + 'height_of_pole', 0);
            Decimal segUnitPrice = (decVal(jsonData, op + 'segment_unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
            if (height == 0 && segUnitPrice == 0) continue;
            startGroup();   // one Mid Hinge Pole = one line item. Reetabrata (18th Aug 2026)
 
            String  poleType   = strVal(jsonData, cp + 'pole_type', 'Polygonal');
            Decimal topDia     = decVal(jsonData, cp + 'top_diameter',            0);
            Decimal botDia     = decVal(jsonData, cp + 'bottom_diameter',         0);
            String  sides      = strVal(jsonData, cp + 'no_of_polygonal_side',    '');
            Decimal segTopLen  = decVal(jsonData, cp + 'segment_length',     0);
            Decimal segTopThk  = decVal(jsonData, cp + 'segment_thickness',  0);
            String  doorHeight = strVal(jsonData, cp + 'door_height',             '');
            String  bpType     = strVal(jsonData, cp + 'base_plate_type',         '');
            Decimal bpSize     = decVal(jsonData, cp + 'size_dia_of_base_plate',  0);
            Decimal bpThk      = decVal(jsonData, cp + 'thickness_of_base_plate', 0);
            String  stiffener  = strVal(jsonData, cp + 'stiffener_at_base',       '');
            String  extraMicron= strVal(jsonData, cp + 'extra_micron',            '');
            String  puPaint    = strVal(jsonData, cp + 'pu_paint_pole_brackets',  '');
            Decimal segWeight  = decVal(jsonData, cp + 'segment_weight',          0);
            Decimal qty        = decVal(jsonData, cp + 'quantity',                1);
            if (qty == 0) qty = 1;
 
            System.debug('length: '+ segTopLen + ' Thinkness: '+ segTopThk);
            String descPole =
                'Supply of'
                + (height > 0 ? ' ' + height + ' MTR' : '')
                + ' ' + poleType + ' Mid Hinge Pole'
                + (sides != '' ? ', ' + sides + ' Sided' : '')
                + (topDia > 0 ? ', Top Dia: ' + topDia.intValue() + ' mm' : '')
                + (botDia > 0 ? ', Bottom Dia: ' + botDia.intValue() + ' mm' : '')
                + (segTopLen > 0 ? ', Length: ' + segTopLen + ' mm' : '')
                + (segTopThk > 0 ? ', Thickness: ' + segTopThk + ' mm' : '')
                //+ (doorHeight != '' ? '. Door Height: ' + doorHeight + ' mm' : '')
                + (bpType != '' ? '. Base Plate: ' + bpType
                    + (bpSize > 0 ? ' ' + bpSize.intValue() + ' mm' : '')
                    + (bpThk  > 0 ? ' x ' + bpThk.intValue() + ' mm' : '') : '')
                //+ (stiffener != '' ? '. Stiffener at Base: ' + stiffener : '')
                + (extraMicron != '' ? ', with ' + extraMicron + ' micron' : '')
                + (puPaint != '' ? '. PU Paint: ' + puPaint : '')
                + '.';

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descPole = descPole +' '+suffix;
            } 
 
            lineItems.add(buildRow(String.valueOf(slCounter++), descPole, segUnitPrice, gstPct, qty, freight));
            totalPoleQty += qty;
 
            Decimal fndUnitPrice = (decVal(jsonData, op + 'foundation_unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
            Decimal fndWeight    = decVal(jsonData, cp + 'foundation_weight', 0);
            // FOUNDATION BOLT = N.R. -> the bolts are NOT in our scope. Mid Hinge Pole offers
            // N.R. on mhp_foundation_bolt_diameter exactly like the Octagonal poles, and its
            // op_mhp_foundation_unit_price formula already returns 0 for it - so the row is
            // added even when price and weight are both 0 (otherwise the sentence would have
            // nowhere to print), and it costs nothing. Deepanjan (24th Aug 2026)
            // FOUNDATION BOLT DIAMETER defaults to "N.R.", so N.R. alone is not proof the
            // user meant anything by it. The row is only forced when at least one foundation
            // figure was actually entered - otherwise an untouched Mid Hinge quote would gain
            // a bare "Suitable for foundation bolt dia. Not in our Scope" line it never had.
            // Deepanjan (24th Aug 2026)
            Boolean fbNisMhp = strVal(jsonData, cp + 'foundation_bolt_diameter', '').equalsIgnoreCase('N.R.')
                            && (String.isNotBlank(strVal(jsonData, cp + 'nr_fb_diameter', ''))
                                || decVal(jsonData, cp + 'foundation_bolt_length', 0) > 0
                                || decVal(jsonData, cp + 'bolt_quantity', 0) > 0
                                || decVal(jsonData, cp + 'fdn_quantity', 0) > 0
                                || decVal(jsonData, cp + 'pcd', 0) > 0);
            if (fbNisMhp || fndUnitPrice > 0 || fndWeight > 0) {
                String fbDiaRaw = strVal(jsonData, cp + 'foundation_bolt_diameter', '');
                if (fbDiaRaw.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw)) {
                    fbDiaRaw = strVal(jsonData, cp + 'nr_fb_diameter', '');
                }
                String  fbDia = String.isBlank(fbDiaRaw) ? '0' : fbDiaRaw;
                Decimal fbLen = decVal(jsonData, cp + 'foundation_bolt_length', 0);
                Decimal fbQty = decVal(jsonData, cp + 'bolt_quantity', 0);
                Decimal pcd   = decVal(jsonData, cp + 'pcd', 0);
                String  template = strVal(jsonData, cp + 'template', '');
 
                // Nos. from BOLT QUANTITY, falling back to FOUNDATION QUANTITY - the same
                // chain the Octagonal sentence uses, so all three products read alike.
                Decimal fbNisQtyMhp = decVal(jsonData, cp + 'bolt_quantity',
                                      decVal(jsonData, cp + 'fdn_quantity', 0));
                if (fbNisQtyMhp <= 0) fbNisQtyMhp = fbQty;

                String descFnd = fbNisMhp
                    ? fdnNotInScopeDesc(fbDia, fbLen, fbNisQtyMhp, pcd)
                    : ('Supply of FOUNDATION BOLTS - M' + fbDia + 'mm'
                    + ' x ' + fbLen.intValue() +'mm'
                    + ' (' + fbQty.intValue() + ' Nos.)'
                    + (pcd > 0 ? ' with PCD: ' + pcd.intValue() + ' mm,' : '')
                    + ' with Template and Anchor Plate'
                    + (template != '' ? '. Template: ' + template : '')
                    + '.');
 
                lineItems.add(buildRow(String.valueOf(slCounter++), descFnd, fndUnitPrice, gstPct, qty, freight));
            }
 
            Decimal brkUnitPrice = (decVal(jsonData, op + 'bracket_unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
            Decimal brkWeight    = decVal(jsonData, cp + 'bracket_weight', 0);
            if (brkUnitPrice > 0 || brkWeight > 0) {
                String bracketType = strVal(jsonData, cp + 'bracket_type', '');
                String typeOfArm   = strVal(jsonData, cp + 'type_of_arm', '');
                String brPudesc        = strVal(jsonData , cp + 'pu_paint_br_desc',  ''); 

 System.debug(' br desc '+ brPudesc);

                // Customized -> its description text; NO. OF ARM -> the word.
                // Deepanjan (24th Aug 2026)
                String brkLabel = bracketLabel(bracketType, cp, cp);
                String armTxt   = armWord(typeOfArm);
                String descBrk =
                    'Supply of Bracket / Arm'
                    + (brkLabel != '' ? ' - ' + brkLabel : '')
                    + (armTxt   != '' ? ', Type: ' + armTxt : '')
                    +' '
                    + (brPudesc!= '' ? brPudesc : '')
                    + '.';
 
                lineItems.add(buildRow(String.valueOf(slCounter++), descBrk, brkUnitPrice, gstPct, qty, freight));
            }
        }
 
        appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
 
        if (lineItems.isEmpty()) {
            startGroup();   // Reetabrata (18th Aug 2026)
            lineItems.add(buildRow('1',
                'Supply of Mid Hinge Pole (please verify quote configuration).',
                0, gstPct, 1, strVal(jsonData, 'freight_incoterms', 'Ex-works')));
        }
    }
 
    // NEW: description builder for Mid Hinge Pole (Item N) lines pulled
    // from _Final_Apex_Lines / _Saved_Table_Rows.
    
    private String buildMHPDescription(String itemName, Map<String, Object> lineMap) {
        Boolean isFoundation = itemName.containsIgnoreCase('Foundation');
        Boolean isBracket    = itemName.containsIgnoreCase('Bracket') || itemName.containsIgnoreCase('Arm');
        Boolean isAccessories = itemName.containsIgnoreCase('- ACCESSORIES - Accessories');  // NEW
    
        Integer colIdx = 1;
        Pattern pCol = Pattern.compile('\\(Item\\s*(\\d+)\\)');
        Matcher mCol = pCol.matcher(itemName);
        if (mCol.find()) {
            try { colIdx = Integer.valueOf(mCol.group(1)); } catch (Exception ex) {}
        }
        if (colIdx < 1 || colIdx > MAX_REPEATER_COLS) colIdx = 1;
    
        String cp = 'c' + colIdx + '_mhp_';
    
        Decimal polWeight = decVal(lineMap, 'weight', 0);
    
        // NEW: Handle ACCESSORIES first
        if (isAccessories) {
            String accessory = strVal(jsonData, cp + 'acc_accessory', '');
            Decimal qty = decVal(lineMap, 'quantity', 1);
            Decimal rate = decVal(jsonData, cp + 'acc_rate', 0);
            Decimal accWeight = decVal(jsonData, cp + 'acc_weight', 0);
            Decimal totalWeight = decVal(jsonData, cp + 'acc_total_weight', 0);
            
            String description = 'Supply of ACCESSORIES';
            if (String.isNotBlank(accessory)) {
                description += ' - ' + accessory;
            }
            if (qty > 0) {
                description += ' (' + qty.intValue() + ' Nos.)';
            }
            /*if (polWeight > 0) {
                description += '. Weight: ' + polWeight.setScale(3, RoundingMode.HALF_UP) + ' kg';
            } else if (accWeight > 0) {
                description += '. Weight: ' + accWeight.setScale(3, RoundingMode.HALF_UP) + ' kg';
            } else if (totalWeight > 0) {
                description += '. Weight: ' + totalWeight.setScale(3, RoundingMode.HALF_UP) + ' kg';
            }*/
            description += '.';
            return description;
        }
    
        if (isFoundation) {
            String  fbDia = strVal(jsonData, cp + 'foundation_bolt_diameter', '24');
            Decimal fbLen = decVal(jsonData, cp + 'foundation_bolt_length', 0);
            Decimal fbQty = decVal(jsonData, cp + 'bolt_quantity', 0);
            Decimal pcd   = decVal(jsonData, cp + 'pcd', 0);
            String  template = strVal(jsonData, cp + 'template', '');

            // FOUNDATION BOLT = N.R. -> not in our scope, same red sentence as every other
            // product. THIS is the path a real Mid Hinge quote takes: the builder returns on
            // _Final_Apex_Lines long before the c{n}_mhp_ fallback, so the rule has to live
            // here too. The M-size comes from N.R FB DIAMETER, and the Nos. from BOLT
            // QUANTITY falling back to FOUNDATION QUANTITY - the same chain the Octagonal
            // sentence uses. buildRow() turns the sentinels into markup.
            // Deepanjan (24th Aug 2026)
            if (fbDia.equalsIgnoreCase('N.R.')) {
                String  nrDia = strVal(jsonData, cp + 'nr_fb_diameter', '');
                Decimal nrQty = decVal(jsonData, cp + 'bolt_quantity',
                                decVal(jsonData, cp + 'fdn_quantity', 0));
                return fdnNotInScopeDesc(nrDia, fbLen, nrQty, pcd);
            }

            return 'Supply of FOUNDATION BOLTS'
                + (fbDia != '' ? ' - M' + fbDia+'mm' : '')
                + (fbLen > 0   ? ' x ' + fbLen.intValue() + 'mm' : '')
                + (fbQty > 0   ? ' (' + fbQty.intValue() + ' Nos.)' : '')
                + (pcd > 0     ? ' with PCD: ' + pcd.intValue() + ' mm,' : '')
                + ' with Template and Anchor Plate'
                + (template != '' ? '. Template: ' + template : '')
                + '.';
        }
    
        if (isBracket) {
            String bracketType = strVal(jsonData, cp + 'bracket_type', '');
            String  typeOfArm  = strVal(jsonData, cp + 'type_of_arm',  '');
            String brPudesc        = strVal(jsonData, cp + 'pu_paint_br_desc',  ''); 

    
            // Customized -> its description text; NO. OF ARM -> the word, and "arm(s)"
            // becomes "arm" because the word already carries the count.
            // Deepanjan (24th Aug 2026)
            String brkLabel = bracketLabel(bracketType, cp, cp);
            String armTxt   = armWord(typeOfArm);
            return 'Supply of Bracket / Arm'
                + (brkLabel != '' ? ' - ' + brkLabel : '') + ' bracket'
                + (armTxt != '' ? ' with ' + armTxt + ' arm' : '')
                +' '
                + (brPudesc!= '' ? brPudesc : '')
                + '.';
        }
    
        // Main pole description (original logic)
        String  poleType    = strVal(jsonData, cp + 'pole_type',               '');
        Decimal height      = decVal(jsonData, cp + 'height_of_pole',          0);
        Decimal topDia      = decVal(jsonData, cp + 'top_diameter',            0);
        Decimal botDia      = decVal(jsonData, cp + 'bottom_diameter',         0);
        String  sides       = strVal(jsonData, cp + 'no_of_polygonal_side',    '');
        Decimal segTopLen   = decVal(jsonData, cp + 'segment_length',     0);
        Decimal segTopThk   = decVal(jsonData, cp + 'segment_thickness',  0);
        String  doorHeight  = strVal(jsonData, cp + 'door_height',             '');
        String  bpType      = strVal(jsonData, cp + 'base_plate_type',         '');
        Decimal bpSize      = decVal(jsonData, cp + 'size_dia_of_base_plate',  0);
        Decimal bpThk       = decVal(jsonData, cp + 'thickness_of_base_plate', 0);
        String  stiffener   = strVal(jsonData, cp + 'stiffener_at_base',       '');
        String  extraMicron = strVal(jsonData, cp + 'extra_micron',            '');
        String  puPaint     = strVal(jsonData, cp + 'pu_paint_pole_brackets',  '');
        String  addDes     = strVal(jsonData, cp + 'ad_description',  '');
        
        String description = 'Supply of'
            + (height > 0 ? ' ' + height + ' MTR ' : '')
            + poleType +'('+ (sides != null ? sides : '')+ ' sided)' + ' Mid Hinge Pole '
            + ('No. of Segment 2')
            + (topDia > 0 ? ', Top Dia: ' + topDia.intValue() + ' mm' : '')
            + (botDia > 0 ? ', Bottom Dia: ' + botDia.intValue() + ' mm' : '')
            + (segTopLen > 0 ? ', Length: ' + segTopLen.intValue() + ' mm' : '')
            + (segTopThk > 0 ? ', Thickness: ' + segTopThk.intValue() + ' mm' : '')
            //+ (doorHeight != '' ? '. Door Height: ' + doorHeight + ' mm' : '')
            + (bpType != '' ? ', Base Plate: ' + bpType
                + (bpSize > 0 ? ' ' + bpSize.intValue() + ' mm' : '')
                + (bpThk  > 0 ? ' x ' + bpThk.intValue() + ' mm' : '') : '')
            //+ (stiffener != '' ? '. Stiffener at Base: ' + stiffener : '')
            + (extraMicron != '' ? ', with ' + extraMicron + ' micron' : '')
            + (puPaint != '' ? '. PU Paint: ' + puPaint : '')
            + (addDes != '' ? '. Additional Item: ' + addDes : '')
            + '.';

        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            description = description +' '+suffix;
        }

        return description;
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // TRANSMISSION POLE BUILDER
    // ═══════════════════════════════════════════════════════════════════════
    
    // private class to fetch both poledesc with special desc & special desc price 
    private class TPDescResult{
        String description;
        Decimal specialUnitPriceAdd;
    }
    
    private void buildTransmissionPoleLineItems() {
 
        Decimal gstPct    = 18;
        String  freight   = strVal(jsonData, 'freight_incoterms', 'Ex-works');
        Integer slCounter = 1;
        Decimal totalPoleQty = 0;
 
        List<Object> apexLines = getList(jsonData, '_Final_Apex_Lines');
        if (!apexLines.isEmpty()) {
            for (Object lineObj : apexLines) {
                Map<String, Object> line = (Map<String, Object>) lineObj;
                String  itemName  = strVal(line, 'name',     'Transmission Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)
 
                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(line, 'expenses', 0)
                                             .setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty        = decVal(line, 'quantity', 1);
                    String displayItemName = itemName.replace('(Lump Sum)', '').trim();

                    lineItems.add(buildRow(String.valueOf(slCounter++),
                                  displayItemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }
 
                Decimal qty       = decVal(line, 'quantity',  1);
                Decimal unitPrice = (decVal(line, 'unitPrice', 0))
                                        .setScale(2, RoundingMode.HALF_UP);
                // update desc & unit with special desc
                TPDescResult res = buildTPDescription(itemName, line);
                unitPrice = (unitPrice + res.specialUnitPriceAdd).setScale(2, RoundingMode.HALF_UP);

                String  description = res.description;
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              description, unitPrice, gstPct, qty, freight));
                totalPoleQty += qty;
            }
            //appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
 
        List<Object> tableRows = getList(jsonData, '_Saved_Table_Rows');
        if (!tableRows.isEmpty()) {
            for (Object rowObj : tableRows) {
                Map<String, Object> row = (Map<String, Object>) rowObj;
                String  itemName  = strVal(row, 'name',     'Transmission Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)
 
                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(row, 'expenses', 0)
                                             .setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty        = decVal(row, 'quantity', 1);
                    lineItems.add(buildRow(String.valueOf(slCounter++),
                                  itemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }
 
                Decimal qty       = decVal(row, 'quantity',  1);
                Decimal unitPrice = (decVal(row, 'unitPrice', 0) )
                                        .setScale(2, RoundingMode.HALF_UP);
                TPDescResult res = buildTPDescription(itemName, row);
                unitPrice = (unitPrice + res.specialUnitPriceAdd).setScale(2, RoundingMode.HALF_UP);
                String  description = res.description;
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              description, unitPrice, gstPct, qty, freight));
                totalPoleQty += qty;
            }
           // appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
 
        for (Integer sec : new List<Integer>{ 1, 2 }) {
            Integer maxCols = (Integer) decVal(jsonData,
                                  'tp_s' + sec + '_no_of_items', 0).intValue();
            if (maxCols == 0) maxCols = MAX_REPEATER_COLS;
            maxCols = Math.min(maxCols, MAX_REPEATER_COLS);

            for (Integer col = 1; col <= maxCols; col++) {
                
                /*
                String cp = 'c' + col + '_tp_';
                String cp2 = 'c' + col + '_tp_s2_';
    
            
                Decimal poleHeight = decVal(jsonData, cp + 'height_of_pole', 0);
                Decimal unitPrice  = (decVal(jsonData, cp + 'unit_price', 0))
                                        .setScale(2, RoundingMode.HALF_UP);
                Boolean hasSeg1 = (poleHeight != 0 || unitPrice != 0);
                
                Decimal s2Height     = decVal(jsonData, cp2 + 'height_of_pole', 0);
                Decimal s2UnitPrice  = (decVal(jsonData, cp2 + 'unit_price', 0)).setScale(2, RoundingMode.HALF_UP);
                Boolean hasSeg2 = (s2Height != 0 || s2UnitPrice != 0);
 
                if (!hasSeg1 && !hasSeg2) continue;

                if (hasSeg1) {
                    String  poleType  = strVal(jsonData, cp + 'pole_type',               'Polygonal');
                    String  noOfSides = strVal(jsonData, cp + 'no_of_polygonal_side',    '');
                    Decimal topDia    = decVal(jsonData, cp + 'top_diameter',            0);
                    Decimal botDia    = decVal(jsonData, cp + 'bottom_diameter',         0);
                    Decimal segLen    = decVal(jsonData, cp + 'segment_length',          0);
                    Decimal thickness = decVal(jsonData, cp + 'segment_thickness',       0);
                    String  bpType    = strVal(jsonData, cp + 'bearing_plate_type',      '');
                    Decimal bpSize    = decVal(jsonData, cp + 'size_dia_of_bearing_plate',  0);
                    Decimal bpThk     = decVal(jsonData, cp + 'thickness_of_bearing_plate', 0);
                    Decimal cabDia    = decVal(jsonData, cp + 'pole_cab_dia',            0);
                    Decimal cabThk    = decVal(jsonData, cp + 'pole_cab_thickness',      0);
                    Decimal dan       = decVal(jsonData, cp + 'dan',                     0);
                    String  note      = strVal(jsonData, cp + 'note',                    '');
                    String  extra     = strVal(jsonData, cp + 'extra_micron',            '');
                    Decimal segWeight = decVal(jsonData, cp + 'segment_weight',          0);
                    Decimal qty       = decVal(jsonData, cp + 'qty',                     1);
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

                    lineItems.add(buildRow(String.valueOf(slCounter++),descPole, unitPrice, gstPct, qty, freight));
                    totalPoleQty += qty;
                }

                if (hasSeg2) {
                    String  s2PoleType  = strVal(jsonData, cp2 + 'pole_type',               'Conical');
                    String  s2NoOfSides = strVal(jsonData, cp2 + 'no_of_polygonal_side',    '');
                    Decimal s2TopDia    = decVal(jsonData, cp2 + 'top_diameter',            0);
                    Decimal s2BotDia    = decVal(jsonData, cp2 + 'bottom_diameter',         0);
                    Decimal s2SegLenTop = decVal(jsonData, cp + 'segment2_length_top',     0);
                    Decimal s2LenBot    = decVal(jsonData, cp2 + 'length_bot',              0);
                    Decimal s2ThkTop    = decVal(jsonData, cp + 'segment2_thickness_top',  0);
                    Decimal s2ThkBot    = decVal(jsonData, cp2 + 'thickness_bot',           0);
                    Decimal s2Overlap   = decVal(jsonData, cp2 + 'overlap',                 0);
                    String  s2BpType    = strVal(jsonData, cp2 + 'bearing_plate_type',      '');
                    Decimal s2BpSize    = decVal(jsonData, cp2 + 'size_dia_of_bearing_plate', 0);
                    Decimal s2BpThk     = decVal(jsonData, cp2 + 'thickness_of_bearing_plate', 0);
                    Decimal s2CabDia    = decVal(jsonData, cp2 + 'pole_cab_dia',            0);
                    Decimal s2CabThk    = decVal(jsonData, cp2 + 'pole_cab_thickness',      0);
                    Decimal s2Dan       = decVal(jsonData, cp2 + 'dan',                     0);
                    String  s2Note      = strVal(jsonData, cp2 + 'note',                    '');
                    String  s2Extra     = strVal(jsonData, cp2 + 'extra_micron',            '');
                    Decimal s2SegWeight = decVal(jsonData, cp2 + 'segment_weight',          0);
                    Decimal s2Qty       = decVal(jsonData, cp2 + 'qty',                     1);
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
                        + (s2Overlap   > 0 ? ', Overlap - ' + s2Overlap.intValue() + ' mm' : '')
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

                    lineItems.add(buildRow(String.valueOf(slCounter++),descPole2, s2UnitPrice, gstPct, s2Qty, freight));
                    totalPoleQty += s2Qty;
                }
                */

                String cp = 'c' + col + '_tp_';
                system.debug('cp value is '+cp);
                Decimal height    = decVal(jsonData, cp + 'height_of_pole', 0);
                Decimal unitPrice = (decVal(jsonData, cp + 'unit_price', 0))
                                        .setScale(2, RoundingMode.HALF_UP);
                if (height == 0 && unitPrice == 0) continue;
                startGroup();   // one Transmission Pole = one line item. Reetabrata (18th Aug 2026)
 
                Decimal qty         = decVal(jsonData, cp + 'qty', 1);
                String  poleType    = strVal(jsonData, cp + 'pole_type',                  'Polygonal');
                Decimal topDia      = decVal(jsonData, cp + 'top_diameter',               0);
                Decimal botDia      = decVal(jsonData, cp + 'bottom_diameter',            0);
                String  sides       = strVal(jsonData, cp + 'no_of_polygonal_side',       '');
                Decimal segLen      = decVal(jsonData, cp + 'segment_length',             0);
                Decimal thickness   = decVal(jsonData, cp + 'segment_thickness',          0);
                String  bpType      = strVal(jsonData, cp + 'bearing_plate_type',         '');
                Decimal bpSize      = decVal(jsonData, cp + 'size_dia_of_bearing_plate',  0);
                Decimal bpThk       = decVal(jsonData, cp + 'thickness_of_bearing_plate', 0);
                Decimal cabDia      = decVal(jsonData, cp + 'pole_cab_dia',               0);
                Decimal cabThk      = decVal(jsonData, cp + 'pole_cab_thickness',         0);
                Decimal dan         = decVal(jsonData, cp + 'dan',                        0);
                String  note        = strVal(jsonData, cp + 'note',                       '');
                String  extraMicron = strVal(jsonData, cp + 'extra_micron',               '');
                Decimal segWeight   = decVal(jsonData, cp + 'segment_weight',             0);
 
                String description =
                    'Supply of'
                    + (height    > 0  ? ' ' + height    + ' MTR'            : '')
                    + ' ' + poleType  + ' Transmission Pole'
                    + (sides    != '' ? ', ' + sides + ' Sided'                        : '')
                    + (topDia   > 0   ? ', Top Dia: '    + topDia.intValue()   + ' mm' : '')
                    + (botDia   > 0   ? ', Bottom Dia: ' + botDia.intValue()   + ' mm' : '')
                    + (segLen   > 0   ? ', Length: '     + segLen.intValue()   + ' mm' : '')
                    + (thickness > 0  ? ', Thickness: '  + thickness.intValue()+ ' mm' : '')
                    + (bpType  != ''  ? '. Bearing Plate: ' + bpType
                        + (bpSize > 0 ? ' ' + bpSize.intValue()  + ' mm' : '')
                        + (bpThk  > 0 ? ' x ' + bpThk.intValue() + ' mm' : '')        : '')
                    + (cabDia   > 0   ? '. Cable Dia: '       + cabDia.intValue() + ' mm' : '')
                    + (cabThk   > 0   ? ', Cable Thickness: ' + cabThk.intValue() + ' mm' : '')
                    + (dan      > 0   ? '. DAN: ' + dan.intValue()                     : '')
                    + (extraMicron != '' ? ', with ' + extraMicron + ' micron'            : '')
                    + (note     != '' ? '. Note: ' + note                              : '')
                    + '.';

                String suffix = getWindSpeedSuffix();
                if (String.isNotBlank(suffix)) {
                    description = description +' '+suffix;
                }

                lineItems.add(buildRow(String.valueOf(slCounter++),
                              description, unitPrice, gstPct, qty, freight));
                totalPoleQty += qty; 
            }
        }
 
        appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
 
        if (lineItems.isEmpty()) {
            startGroup();   // Reetabrata (18th Aug 2026)
            lineItems.add(buildRow('1',
                'Supply of Transmission Pole (please verify quote configuration).',
                0, gstPct, 1, strVal(jsonData, 'freight_incoterms', 'Ex-works')));
        }
    }
 
    private TPDescResult buildTPDescription(String itemName, Map<String, Object> lineMap) {
 
        Integer colIdx = 1;
        System.debug('buildTPDescription called ->  ' + itemName);
        Pattern pCol = Pattern.compile('\\(Item\\s*(\\d+)\\)');
        Matcher mCol = pCol.matcher(itemName);
        if (mCol.find()) {
            try { colIdx = Integer.valueOf(mCol.group(1)); } catch (Exception ex) {}
        }
        if (colIdx < 1 || colIdx > MAX_REPEATER_COLS) colIdx = 1;

        // 2. Extract Segment Number - e.g., "Segment - 2" or "Segment - 1"
        Integer segmentNum = 1;
        Pattern pSeg = Pattern.compile('Segment\\s*-\\s*(\\d+)');
        Matcher mSeg = pSeg.matcher(itemName);
        if (mSeg.find()) {
            try { segmentNum = Integer.valueOf(mSeg.group(1)); } catch (Exception ex) {}
        }

        // 3. Dynamically construct prefix based on Segment Number
        String cp = 'c' + colIdx + '_tp_' ;
        String cp2 ='c' + colIdx + '_tp_s' + segmentNum + '_';
        
        TPDescResult result = new TPDescResult();
    	result.specialUnitPriceAdd = 0;

        if(segmentNum == 1){
            String  poleType    = strVal(jsonData, cp + 'pole_type',                  'Polygonal');
            Decimal height      = decVal(jsonData, cp + 'height_of_pole',             0);
            Decimal topDia      = decVal(jsonData, cp + 'top_diameter',               0);
            Decimal botDia      = decVal(jsonData, cp + 'bottom_diameter',            0);
            String  sides       = strVal(jsonData, cp + 'no_of_polygonal_side',       '');
            Decimal segLen      = decVal(jsonData, cp + 'segment_length',             0);
            Decimal thickness   = decVal(jsonData, cp + 'segment_thickness',          0);
            String  bpType      = strVal(jsonData, cp + 'bearing_plate_type',         '');
            Decimal bpSize      = decVal(jsonData, cp + 'size_dia_of_bearing_plate',  0);
            Decimal bpThk       = decVal(jsonData, cp + 'thickness_of_bearing_plate', 0);
            Decimal cabDia      = decVal(jsonData, cp + 'pole_cab_dia',               0);
            Decimal cabThk      = decVal(jsonData, cp + 'pole_cab_thickness',         0);
            Decimal dan         = decVal(jsonData, cp + 'dan',                        0);
            String  note        = strVal(jsonData, cp + 'note',                       '');
            String  extraMicron = strVal(jsonData, cp + 'extra_micron',               '');
            Decimal polWeight   = decVal(lineMap,  'weight',                          0);

            String shapeLabel = buildShapeLabel(poleType, sides);

            String description = 'Supply of'
                + (height    > 0  ? ' ' + height    + ' MTR '            : '')
                + shapeLabel + ' Transmission Pole'
                + (sides != '' ? ', ' + sides + ' Sided' : '')
                + (topDia   > 0   ? ', Top Dia: '    + topDia.intValue()   + ' mm' : '')
                + (botDia   > 0   ? ', Bottom Dia: ' + botDia.intValue()   + ' mm' : '')
                + (segLen   > 0   ? ', Length: '     + segLen.intValue()   + ' mm' : '')
                + (thickness > 0  ? ', Thickness: '  + thickness.intValue()+ ' mm' : '')
                + (bpType  != ''  ? '. Bearing Plate: ' + bpType
                    + (bpSize > 0 ? ' ' + bpSize.intValue()  + ' mm' : '')
                    + (bpThk  > 0 ? ' x ' + bpThk.intValue() + ' mm' : '')        : '')
                + (cabDia   > 0   ? '. Cable Dia: '       + cabDia.intValue() + ' mm' : '')
                + (cabThk   > 0   ? ', Cable Thickness: ' + cabThk.intValue() + ' mm' : '')
                + (dan      > 0   ? '. DAN: ' + dan.intValue()                     : '')
                + (extraMicron != '' ? ', with ' + extraMicron + ' micron'            : '')
                + (note     != '' ? '. Note: ' + note                              : '')
                + '.';
            
            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                description = description +' '+suffix;
            }
            
            Boolean hasSpecialDesc = boolVal(jsonData, cp + 'is_special_desc', false);
            if (hasSpecialDesc) {
                String  specialText  = strVal(jsonData, cp + 'special_desc_text', '');
                Decimal specialPrice = decVal(jsonData, cp + 'special_desc_unitPrice', 0);
                if (String.isNotBlank(specialText)) {
                    description += '. Special: ' + specialText;
                }
                result.specialUnitPriceAdd = specialPrice;   
            }
            result.description = description;
            return result;
        }
        if(segmentNum == 2)
        {
            Decimal s2Height    = decVal(jsonData, cp2 + 'height_of_pole',             0);
            String  s2PoleType  = strVal(jsonData, cp2 + 'pole_type',               'Conical');
            String  s2NoOfSides = strVal(jsonData, cp2 + 'no_of_polygonal_side',    '');
            Decimal s2TopDia    = decVal(jsonData, cp2 + 'top_diameter',            0);
            Decimal s2BotDia    = decVal(jsonData, cp2 + 'bottom_diameter',         0);
            Decimal s2SegLenTop = decVal(jsonData, cp + 'segment2_length_top',     0);
            Decimal s2LenBot    = decVal(jsonData, cp2 + 'length_bot',              0);
            Decimal s2ThkTop    = decVal(jsonData, cp + 'segment2_thickness_top',  0);
            Decimal s2ThkBot    = decVal(jsonData, cp2 + 'thickness_bot',           0);
            Decimal s2Overlap   = decVal(jsonData, cp2 + 'overlap',                 0);
            String  s2BpType    = strVal(jsonData, cp2 + 'bearing_plate_type',      '');
            Decimal s2BpSize    = decVal(jsonData, cp2 + 'size_dia_of_bearing_plate', 0);
            Decimal s2BpThk     = decVal(jsonData, cp2 + 'thickness_of_bearing_plate', 0);
            Decimal s2CabDia    = decVal(jsonData, cp2 + 'pole_cab_dia',            0);
            Decimal s2CabThk    = decVal(jsonData, cp2 + 'pole_cab_thickness',      0);
            Decimal s2Dan       = decVal(jsonData, cp2 + 'dan',                     0);
            String  s2Note      = strVal(jsonData, cp2 + 'note',                    '');
            String  s2Extra     = strVal(jsonData, cp2 + 'extra_micron',            '');
            Decimal s2SegWeight = decVal(jsonData, cp2 + 'segment_weight',          0);
            Decimal s2Qty       = decVal(jsonData, cp2 + 'qty',                     1);
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
            
            Boolean hasSpecialDesc = boolVal(jsonData, cp2 + 'is_special_desc', false);
            if (hasSpecialDesc) {
                String  specialText  = strVal(jsonData, cp2 + 'special_desc_text', '');
                Decimal specialPrice = decVal(jsonData, cp2 + 'special_desc_unitPrice', 0);
                if (String.isNotBlank(specialText)) {
                    descPole2 += '. Special Description: ' + specialText;
                }
                result.specialUnitPriceAdd = specialPrice;   
            }
            
            result.description = descPole2;
        	return result;
        }
        return result;
    }
 
    // ═══════════════════════════════════════════════════════════════════════
    // LIGHTING POLE BUILDER
    // ═══════════════════════════════════════════════════════════════════════
    private void buildLightingPoleLineItems() {
		
		System.debug('Inside buildLightingPoleLineItems');
        
        Decimal gstPct    = 18;
        String  freight   = strVal(jsonData, 'freight_incoterms', 'Ex-works');
        Integer slCounter = 1;
        Decimal totalPoleQty = 0;
        typeOfMast       = strVal(jsonData, 'type_of_mast', '');

        List<Object> apexLines = orderFlatLinesByItem(getList(jsonData, '_Final_Apex_Lines'));
        Set<String> fdnAlreadyThere = fdnSetsPresent(apexLines);
        if (!apexLines.isEmpty()) {
            for (Object lineObj : apexLines) {
                Map<String, Object> line = (Map<String, Object>) lineObj;
                String  itemName  = strVal(line, 'name',      'Lighting Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)

                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(line, 'expenses', 0).setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty       = decVal(line, 'quantity', 1);
                    String displayItemName = itemName.replace('(Lump Sum)', '').trim();

                    lineItems.add(buildRow(String.valueOf(slCounter++), displayItemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }

                Decimal qty       = decVal(line, 'quantity',  1);
                Decimal unitPrice = decVal(line, 'unitPrice', 0).setScale(2, RoundingMode.HALF_UP);
                String  description = buildLPDescription(itemName, line);
                lineItems.add(buildRow(String.valueOf(slCounter++), description, unitPrice, gstPct, qty, freight));

                if (!itemName.containsIgnoreCase('Foundation')
                        && !itemName.containsIgnoreCase('Bracket')
                        && !itemName.containsIgnoreCase('Arm')) {
                    totalPoleQty += qty;
                    // FOUNDATION BOLT = N.R. and the estimator saved no Foundation line for
                    // this pole (its FOUNDATION QUANTITY was left blank), so the out-of-scope
                    // sentence would have had nowhere to print. Emit it right after the pole
                    // row, at rate 0, inside the same line item - so the set reads
                    // pole -> foundation -> bracket. Nothing else is added or removed.
                    // Deepanjan (24th Aug 2026)
                    slCounter = addFdnNotInScopeRow(itemName, fdnAlreadyThere, qty,
                                                    gstPct, freight, slCounter);
                }
            }
            //appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
        
        List<Object> tableRows = orderFlatLinesByItem(getList(jsonData, '_Saved_Table_Rows'));
        fdnAlreadyThere = fdnSetsPresent(tableRows);
        if (!tableRows.isEmpty()) {
            for (Object rowObj : tableRows) {
                Map<String, Object> row = (Map<String, Object>) rowObj;
                String  itemName  = strVal(row, 'name',      'Lighting Pole Item');
                markFlatGroup(itemName);   // Reetabrata (18th Aug 2026)

                if (isFreightLine(itemName)) {
                    Decimal freightAmt = decVal(row, 'expenses', 0).setScale(2, RoundingMode.HALF_UP);
                    Decimal fQty       = decVal(row, 'quantity', 1);
                    String displayItemName = itemName.replace('(Lump Sum)', '').trim();

                    lineItems.add(buildRow(String.valueOf(slCounter++), displayItemName, freightAmt, gstPct, fQty, freight));
                    continue;
                }

                Decimal qty       = decVal(row, 'quantity',  1);
                Decimal unitPrice = decVal(row, 'unitPrice', 0).setScale(2, RoundingMode.HALF_UP);
                String  description = buildLPDescription(itemName, row);
                lineItems.add(buildRow(String.valueOf(slCounter++), description, unitPrice, gstPct, qty, freight));

                if (!itemName.containsIgnoreCase('Foundation')
                        && !itemName.containsIgnoreCase('Bracket')
                        && !itemName.containsIgnoreCase('Arm')) {
                    totalPoleQty += qty;
                    // FOUNDATION BOLT = N.R. and the estimator saved no Foundation line for
                    // this pole (its FOUNDATION QUANTITY was left blank), so the out-of-scope
                    // sentence would have had nowhere to print. Emit it right after the pole
                    // row, at rate 0, inside the same line item - so the set reads
                    // pole -> foundation -> bracket. Nothing else is added or removed.
                    // Deepanjan (24th Aug 2026)
                    slCounter = addFdnNotInScopeRow(itemName, fdnAlreadyThere, qty,
                                                    gstPct, freight, slCounter);
                }
            }
            //appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
            return;
        }
        
        List<Integer> sections = new List<Integer>{ 1, 2 };

        for (Integer sec : sections) {
            String secKey    = 's' + sec + '_no_of_items';
            String secKeyCus = 's' + sec + '_no_of_items_for_cus_op';
            
            // Support custom op section quantity check
            Integer maxCols = (Integer) decVal(jsonData, secKey, decVal(jsonData, secKeyCus, 0)).intValue();
            if (maxCols == 0) maxCols = MAX_REPEATER_COLS;
            maxCols = Math.min(maxCols, MAX_REPEATER_COLS);

            for (Integer col = 1; col <= maxCols; col++) {
                // Base prefix patterns
                String cs    = 'c' + col + '_s' + sec + '_';
                String csCus = 'c' + col + '_s' + sec + '_cus_op_';
                String cCusS = 'c' + col + '_cus_op_s' + sec + '_';

                Decimal height = decVal(jsonData, cs + 'height_of_pole', decVal(jsonData, csCus + 'height_of_pole', 0));

                String segPriceKey = (sec == 1) 
                    ? ('c' + col + '_lp_segment_unit_price') 
                    : ('c' + col + '_lp_segment2_unit_price');
                
                Decimal segUnitPrice = decVal(jsonData, segPriceKey, 
                                            decVal(jsonData, 'c' + col + '_cus_op_segment_base_price', 0))
                                    .setScale(2, RoundingMode.HALF_UP);
                
                if (height == 0 && segUnitPrice == 0) continue;
                startGroup();   // one Lighting Pole = one line item. Reetabrata (18th Aug 2026)

                // Attribute Fallbacks (Standard -> Custom Op)
                String  poleType    = strVal(jsonData, cs + 'pole_type',               strVal(jsonData, csCus + 'pole_type', 'Polygonal'));
                Decimal topDia      = decVal(jsonData, cs + 'top_diameter',            decVal(jsonData, csCus + 'top_diameter', 0));
                Decimal botDia      = decVal(jsonData, cs + 'bottom_diameter',         decVal(jsonData, csCus + 'bottom_diameter', 0));
                Decimal segLen      = decVal(jsonData, cs + 'segment_length',          decVal(jsonData, csCus + 'segment_length', 0));
                Decimal thickness   = decVal(jsonData, cs + 'segment_thickness',       decVal(jsonData, csCus + 'segment_thickness', 0));
                String  sides       = strVal(jsonData, cs + 'no_of_polygonal_side',    strVal(jsonData, csCus + 'no_of_polygonal_side', ''));
                String  bpType      = strVal(jsonData, cs + 'base_plate_type',         strVal(jsonData, csCus + 'base_plate_type', ''));
                Decimal bpSize      = decVal(jsonData, cs + 'size_dia_of_base_plate',  decVal(jsonData, csCus + 'size_dia_of_base_plate', 0));
                Decimal bpThk       = decVal(jsonData, cs + 'thickness_of_base_plate', decVal(jsonData, csCus + 'thickness_of_base_plate', 0));
                String  stiffener   = strVal(jsonData, cs + 'stiffener_at_base',       strVal(jsonData, csCus + 'stiffener_at_base', ''));
                Decimal doorHeight  = decVal(jsonData, cs + 'door_height',             decVal(jsonData, csCus + 'door_height', 0));
                String  boltDia     = strVal(jsonData, cs + 'foundation_bolt_diameter',strVal(jsonData, csCus + 'foundation_bolt_diameter', '24'));
                Decimal boltLen     = decVal(jsonData, cs + 'foundation_bolt_length',  decVal(jsonData, csCus + 'foundation_bolt_length', 0));
                Decimal boltQty     = decVal(jsonData, cs + 'bolt_quantity',           decVal(jsonData, csCus + 'bolt_quantity', 0));
                Decimal pcd         = decVal(jsonData, cs + 'pcd',                     decVal(jsonData, csCus + 'pcd', 0));
                String  template    = strVal(jsonData, cs + 'template',                strVal(jsonData, csCus + 'template', ''));
                String  extraMicron = strVal(jsonData, cs + 'extra_micron',            strVal(jsonData, csCus + 'extra_micron', ''));
                String  puPaintPole = strVal(jsonData, cs + 'pu_paint_pole',           strVal(jsonData, csCus + 'pu_paint_pole', ''));
        // SOLAR STRUCTURE description - Deepanjan (6th September 2026). The Custom Octagonal
                // blueprint names this field differently per section: Section 1 has
                // s1_cus_op_solar_structure, Section 2 has s2_cus_op_solar_description. Reading only
                // 'solar_structure' printed the sentence for Section 1 and silently dropped it for
                // Section 2, while the weight formula (which uses the right key) still priced the
                // solar structure - the customer paid for it and the offer never said so.
                // 'solar_structure' stays FIRST in the chain, so every quote that printed before
                // prints exactly as before; only the Section-2 blank is filled.
                String  solarStruct = strVal(jsonData, cs + 'solar_structure',
                                      strVal(jsonData, cs + 'solar_description',
                                      strVal(jsonData, csCus + 'solar_structure',
                                      strVal(jsonData, csCus + 'solar_description', ''))));
                String  batteryBox  = strVal(jsonData, cs + 'battery_box',             strVal(jsonData, csCus + 'battery_box', ''));
                String  laddar  	= strVal(jsonData, cs + 'ladder',             strVal(jsonData, csCus + 'ladder', ''));
                String  addDes  	= strVal(jsonData, cs + 'ad_description',             strVal(jsonData, csCus + 'ad_description', ''));
                
                // Core Metrics with Standard -> Op -> Custom Op fallback chain
                Decimal qty = decVal(jsonData, 'c' + col + '_lp_s' + sec + '_quantity',
                                decVal(jsonData, 'c' + col + '_op_s' + sec + '_quantity', 
                                    decVal(jsonData, cCusS + 'quantity', 1)));

                Decimal segWeight = decVal(jsonData, 'c' + col + '_lp_s' + sec + '_segment_weight',
                                    decVal(jsonData, 'c' + col + '_op_s' + sec + '_segment_weight', 
                                        decVal(jsonData, cCusS + 'segment_weight', 0)));

                Decimal fndUnitPrice = decVal(jsonData, 'c' + col + '_lp_foundation_unit_price',
                                        decVal(jsonData, 'c' + col + '_op_foundation_unit_price', 
                                            decVal(jsonData, 'c' + col + '_cus_op_foundation_unit_price', 0)))
                                    .setScale(2, RoundingMode.HALF_UP);
                                    
                Decimal fndWeight = decVal(jsonData, 'c' + col + '_s' + sec + '_foundation_weight', 
                                    decVal(jsonData, cCusS + 'foundation_weight',
                                        decVal(jsonData, csCus + 's' + sec + '_foundation_weight', 0)));

                Decimal brkUnitPrice = decVal(jsonData, 'c' + col + '_lp_bracket_unit_price',
                                        decVal(jsonData, 'c' + col + '_op_bracket_unit_price', 
                                            decVal(jsonData, 'c' + col + '_cus_op_bracket_unit_price', 0)))
                                    .setScale(2, RoundingMode.HALF_UP);
                                    
                Decimal brkWeight = decVal(jsonData, 'c' + col + '_s' + sec + '_bracket_weight', 
                                    decVal(jsonData, cCusS + 'bracket_weight', 0));
                                    
                Decimal realization = decVal(jsonData, 'c' + col + '_lp_s' + sec + '_realization_on_segment_price', 
                                        decVal(jsonData, cCusS + 'realization_on_segment_price', 5));
                
				System.debug('addDes --> '+ addDes);
                System.debug('doorHeight --> '+doorHeight);
                
                String descPole =
                    'Supply of'
                    + (height > 0 ? ' ' + height + ' MTR' : '')
                    + ' ' + poleType + ' Lighting Pole'
                    + (sides != ''    ? ', ' + sides + ' Sided'                            : '')
                    + (topDia > 0     ? ', Top Dia: '     + topDia.intValue()    + ' mm'   : '')
                    + (botDia > 0     ? ', Bottom Dia: '  + botDia.intValue()    + ' mm'   : '')
                    + (segLen > 0     ? ', Length: '      + segLen.intValue()    + ' mm'   : '')
                    + (thickness > 0  ? ', Thickness: '   + thickness.intValue() + ' mm'   : '')
                    + (bpType != ''   ? '. Base Plate: '  + bpType
                        + (bpSize > 0 ? ' ' + bpSize.intValue()  + ' mm' : '')
                        + (bpThk  > 0 ? ' x ' + bpThk.intValue() + ' mm' : '')             : '')
                    //+ (stiffener != '' ? '. Stiffener at Base: ' + stiffener               : '')
                    //+ (doorHeight > 0  ? '. Door Height: ' + doorHeight.intValue() + ' mm' : '')
                    + (extraMicron != '' ? ', with ' + extraMicron + ' micron'                : '')
                    + (puPaintPole != '' ? '. PU Paint: ' + puPaintPole                    : '')
                    + (solarStruct != '' ? '. Solar Structure: ' + solarStruct             : '')
                    + (batteryBox  != '' ? '. Battery Box: ' + batteryBox                  : '')
                    + (laddar  != '' ? '. Laddar: ' + laddar                  : '')
                    + (addDes  != '' ? '. Additional Item: ' + addDes                  : '')
                    + '.';

                String suffix = getWindSpeedSuffix();
                if (String.isNotBlank(suffix)) {
                    descPole = descPole + ' ' + suffix;
                } 

                lineItems.add(buildRow(String.valueOf(slCounter++), descPole, segUnitPrice, gstPct, qty, freight));
                totalPoleQty += qty;

                if (fndUnitPrice > 0 || fndWeight > 0) {
                    String descFnd =
                        'Supply of FOUNDATION BOLTS'
                        + (boltDia != '' ? ' - M' + boltDia +'mm'                                : '')
                        + (boltLen > 0   ? ' x '  + boltLen.intValue() + 'mm'                     : '')
                        + (boltQty > 0   ? ' ('   + boltQty.intValue() + ' Nos.)'          : '')
                        + (pcd > 0       ? ' with PCD: ' + pcd.intValue() + ' mm,'         : '')
                        + ' with Template and Anchor Plate'
                        + (template != '' ? '. Template: ' + template                      : '')
                        + '.';

                    lineItems.add(buildRow(String.valueOf(slCounter++), descFnd, fndUnitPrice, gstPct, qty, freight));
                }

                if (brkUnitPrice > 0 || brkWeight > 0) {
                    String brkType   = strVal(jsonData, cs + 'bracket_type', strVal(jsonData, csCus + 'bracket_type', ''));
                    String typeOfArm = strVal(jsonData, cs + 'type_of_arm',  strVal(jsonData, csCus + 'type_of_arm', ''));
                    Decimal armLen   = decVal(jsonData, cs + 'arm_length',   decVal(jsonData, csCus + 'arm_length', 0));
                    Decimal armDia   = decVal(jsonData, cs + 'arm_dia_od',   decVal(jsonData, csCus + 'arm_dia_od', 0));
                    
                    // Customized -> its description text; NO. OF ARM -> the word.
                    // Deepanjan (24th Aug 2026)
                    String brkLabel = bracketLabel(brkType, cs, csCus);
                    String armTxt   = armWord(typeOfArm);
                    String descBrk =
                        'Supply of Bracket / Arm'
                        + (brkLabel  != '' ? ' - ' + brkLabel                              : '')
                        + (armTxt != '' ? ', Type: ' + armTxt                              : '')
                        + (armLen > 0     ? ', Arm Length: ' + armLen.intValue()  + ' mm'  : '')
                        + (armDia > 0     ? ', Arm Dia: '   + armDia.intValue()   + ' mm'  : '')
                        + '.';

                    lineItems.add(buildRow(String.valueOf(slCounter++), descBrk, brkUnitPrice, gstPct, qty, freight));
                }
            }
        }

        appendFreightRow(gstPct, freight, slCounter, totalPoleQty);

        if (lineItems.isEmpty()) {
            startGroup();   // Reetabrata (18th Aug 2026)
            lineItems.add(buildRow('1', 'Supply of Lighting Pole (please verify quote configuration).', 0, gstPct, 1, strVal(jsonData, 'freight_incoterms', 'Ex-works')));
        }
    }

    private String buildLPDescription(String itemName, Map<String, Object> lineMap) {

        Boolean isFoundation = itemName.containsIgnoreCase('Foundation');
        Boolean isBracket    = itemName.containsIgnoreCase('Bracket') || itemName.containsIgnoreCase('Arm');

        // Extract Column/Item Index
        Integer colIdx = 1;
        Pattern pCol = Pattern.compile('\\(Item\\s*(\\d+)\\)');
        Matcher mCol = pCol.matcher(itemName);
        if (mCol.find()) {
            try { colIdx = Integer.valueOf(mCol.group(1)); } catch (Exception ex) {}
        }
        if (colIdx < 1 || colIdx > MAX_REPEATER_COLS) colIdx = 1;

        // Extract Section Index
        Integer secIdx = 1;
        Pattern pSec = Pattern.compile('-\\s*(\\d+)\\s*(?:Pole Details|\\(Item)');
        Matcher mSec = pSec.matcher(itemName);
        if (mSec.find()) {
            try { secIdx = Integer.valueOf(mSec.group(1)); } catch (Exception ex) {}
        }
        if (secIdx < 1 || secIdx > 2) secIdx = 1;

        // Prefixes based on Section Index
        String prefix    = 'c' + colIdx + '_s' + secIdx + '_';
        String prefixCus = 'c' + colIdx + '_s' + secIdx + '_cus_op_';

        // ── 1. Foundation Bolt Description ─────────────────────────────────────
        if (isFoundation) {
            String fbDiaRaw = strVal(jsonData, prefix + 'foundation_bolt_diameter', strVal(jsonData, prefixCus + 'foundation_bolt_diameter', ''));
            if (fbDiaRaw.equalsIgnoreCase('N.R.') || String.isBlank(fbDiaRaw)) {
                fbDiaRaw = strVal(jsonData, prefix + 'nr_fb_diameter', strVal(jsonData, prefixCus + 'nr_fb_diameter', ''));
            }
            String  fbDia    = String.isBlank(fbDiaRaw) ? '0' : fbDiaRaw;
            Decimal fbLen    = decVal(jsonData, prefix + 'foundation_bolt_length', decVal(jsonData, prefixCus + 'foundation_bolt_length', 0));
            Decimal fbQty    = decVal(jsonData, prefix + 'bolt_quantity',          decVal(jsonData, prefixCus + 'bolt_quantity', 0));
            String  template = strVal(jsonData, prefix + 'template',               strVal(jsonData, prefixCus + 'template', ''));
            String  boltType = template.toLowerCase().contains('j') ? 'J Type' : 'Standard';
            Boolean addFBflag  = boolVal(jsonData, prefixCus + 'fdn_ad', false);
            String addFBDes    = strVal(jsonData, prefixCus + 'fdn_ad_description', '');

            // FOUNDATION BOLT = N.R. -> the bolts are NOT in our scope. Same sentence and the
            // same red styling every other product already prints, and buildRow() turns the
            // sentinels into markup. The dimensions still come from N.R FB DIAMETER / LENGTH /
            // BOLT QUANTITY / P.C.D, each dropped when blank. Deepanjan (24th Aug 2026)
            if (fdnIsNotInScope(prefix, prefixCus)) {
                Decimal fbPcd = decVal(jsonData, prefix + 'pcd', decVal(jsonData, prefixCus + 'pcd', 0));
            // The Nos. comes from BOLT QUANTITY, falling back to FOUNDATION QUANTITY -
            // the two scopes resolve it from different keys for the normal bolt text
            // (Single reads bolt_quantity, Combined reads fdn_quantity for a Custom
            // Octagonal), so this sentence reads BOTH and stays identical in the two
            // PDFs whichever field the user fills. Deepanjan (24th Aug 2026)
                Decimal fbNisQty = fdnNisQty(prefix, prefixCus, fbQty);
                return fdnNotInScopeDesc(fbDia, fbLen, fbNisQty, fbPcd);
            }

            return 'Supply of FOUNDATION BOLTS - ' + 'J Type' + ' Bolts M' + fbDia + ' x ' + fbLen.intValue() + 'mm (' + fbQty.intValue() + ' Nos.)' + (addFBflag ? ' '+ addFBDes:'');
        }

        // ── 2. Bracket / Arm Description ───────────────────────────────────────
        if (isBracket) {
            // NO FALLBACK on either field - BRACKET TYPE used to default to 'Standard' and
            // NO. OF ARM to '1', so a bracket row with nothing entered still read "Standard
            // bracket with 1 arm(s)." Customized now prints its CUSTOMIZED DESCRIPTION text,
            // and a numeric NO. OF ARM prints as the word. Deepanjan (24th Aug 2026)
            String bracketType = strVal(jsonData, prefix + 'bracket_type', strVal(jsonData, prefixCus + 'bracket_type', ''));
            String typeOfArm   = strVal(jsonData, prefix + 'type_of_arm',   strVal(jsonData, prefixCus + 'type_of_arm', ''));
            String  armdiaod   = strVal(jsonData, prefix + 'arm_dia_od', strVal(jsonData, prefixCus + 'arm_dia_od', ''));
            String  armlength   = strVal(jsonData, prefix + 'arm_length', strVal(jsonData, prefixCus + 'arm_length', ''));
            String sleeveLength = strVal(jsonData, prefix + 'sleeve_length', strVal(jsonData, prefixCus + 'sleeve_length', ''));
            Boolean addBrflag  = boolVal(jsonData, prefixCus + 'br_ad', false);
            String addBrDes    = strVal(jsonData, prefixCus + 'br_ad_description', '');
            String brkPUDesc = strVal(jsonData, prefix + 'pu_paint_br_desc', strVal(jsonData, prefixCus + 'pu_paint_br_desc', ''));
            String brkCusDesc = strVal(jsonData, prefix + 'customized_description', strVal(jsonData, prefixCus + 'customized_description', ''));
            String brkRingDesc = strVal(jsonData, prefix + 'ring_description', strVal(jsonData, prefixCus + 'ring_description', ''));
            Boolean brkPUlag  = boolVal(jsonData, prefixCus + 'pu_paint_checkbox', false);

            
            Boolean hasArms = String.isNotBlank(typeOfArm) && !typeOfArm.equalsIgnoreCase('0') && !typeOfArm.equalsIgnoreCase('N/A');
            String  brkLabel = bracketLabel(bracketType, prefix, prefixCus);
            String  armTxt   = armWord(typeOfArm);
            String  armNumber = armNumtoWord(typeOfArm);

            return ''
            + (String.isNotBlank(brkLabel) ? brkLabel : '')
            + (hasArms ? (typeOfArm.isNumeric() ? (' '+ armTxt + ' arm') : (' ' + armTxt)) : '')
            + ' bracket'
            + (typeOfArm.isNumeric() 
                ? (
                    (armLength != '' ? ' ' + armLength + ' mm long on ' + armNumber + ' side' : '')
                    + (armdiaod != '' ? ' with ' + armdiaod + ' OD GI Pipe' : '')
                    + (String.isNotBlank(sleeveLength) ? ', ' + sleeveLength.trim() + 'mm Sleeve' : '')
                    + '.'
                )
                : (brkRingDesc != '' ? ' ' + brkRingDesc : ''))
            + (addBrflag && String.isNotBlank(addBrDes) ? ' ' + addBrDes + '.' : '')
            + (brkPUDesc != '' && brkPUlag ? ' PU Paint : ' + brkPUDesc + '.' : '');
        }

        // ── 3. Lighting Pole Description ───────────────────────────────────────
        Decimal poleHeight = decVal(jsonData, prefix + 'height_of_pole', decVal(jsonData, prefixCus + 'height_of_pole', 0));
        String  poleType   = strVal(jsonData, prefix + 'pole_type',      strVal(jsonData, prefixCus + 'pole_type', 'Octagonal'));
        String  noOfSides  = strVal(jsonData, prefix + 'no_of_polygonal_side', strVal(jsonData, prefixCus + 'no_of_polygonal_side', '8'));
        String  shapeLabel = buildShapeLabel(poleType, noOfSides);

        Decimal topDia = decVal(jsonData, prefix + 'top_diameter',    decVal(jsonData, prefixCus + 'top_diameter', 0));
        Decimal botDia = decVal(jsonData, prefix + 'bottom_diameter', decVal(jsonData, prefixCus + 'bottom_diameter', 0));

        String  extraMicron = strVal(jsonData, prefix + 'extra_micron',            strVal(jsonData, prefixCus + 'extra_micron', ''));
        String  puPaintPole = strVal(jsonData, prefix + 'pu_paint_pole_brackets',           strVal(jsonData, prefixCus + 'pu_paint_pole_brackets', ''));
        // SOLAR STRUCTURE description - Deepanjan (6th September 2026). The Custom Octagonal
        // blueprint names this field differently per section: Section 1 has
        // s1_cus_op_solar_structure, Section 2 has s2_cus_op_solar_description. Reading only
        // 'solar_structure' printed the sentence for Section 1 and silently dropped it for
        // Section 2, while the weight formula (which uses the right key) still priced the
        // solar structure - the customer paid for it and the offer never said so.
        // 'solar_structure' stays FIRST in the chain, so every quote that printed before
        // prints exactly as before; only the Section-2 blank is filled.
        String  solarStruct = strVal(jsonData, prefix + 'solar_structure',
                              strVal(jsonData, prefix + 'solar_description',
                              strVal(jsonData, prefixCus + 'solar_structure',
                              strVal(jsonData, prefixCus + 'solar_description', ''))));
        String  batteryBox  = strVal(jsonData, prefix + 'battery_box',             strVal(jsonData, prefixCus + 'battery_box', ''));
        String  laddar  	= strVal(jsonData, prefix + 'ladder_description',             strVal(jsonData, prefixCus + 'ladder_description', ''));
        Decimal bpSize = decVal(jsonData, prefix + 'size_dia_of_base_plate',  decVal(jsonData, prefixCus + 'size_dia_of_base_plate', 0));
        Decimal bpThk  = decVal(jsonData, prefix + 'thickness_of_base_plate', decVal(jsonData, prefixCus + 'thickness_of_base_plate', 0));
        String  bpType = strVal(jsonData, prefix + 'base_plate_type',         strVal(jsonData, prefixCus + 'base_plate_type', 'Square'));
		String  addDes  	= strVal(jsonData, prefix + 'ad_description',             strVal(jsonData, prefixCus + 'ad_description', ''));
        
        String descPole = 'Supply of ' + poleHeight + ' MTR ' 
                        + shapeLabel + ' Pole as per Dimension: '
                        + 'Top Dia. - ' + topDia.intValue() + ' mm, '
                        + 'Bottom Dia. - ' + botDia.intValue() + ' mm, ';

        if (secIdx == 1) {
            Decimal segLen = decVal(jsonData, prefix + 'segment_length',    decVal(jsonData, prefixCus + 'segment_length', 0));
            Decimal segThk = decVal(jsonData, prefix + 'segment_thickness', decVal(jsonData, prefixCus + 'segment_thickness', 0));

            descPole += 'Section - 1 '
                    + '(Section Length - ' + segLen.intValue() + ' mm), '
                    + 'Thickness- ' + segThk.intValue() + ' mm. ';
        } else {
            Decimal segTopLen = decVal(jsonData, prefix + 'segment2_top_length',         decVal(jsonData, prefixCus + 'segment2_top_length', 0));
            Decimal segBotLen = decVal(jsonData, prefix + 'segment1_bottom_length',      decVal(jsonData, prefixCus + 'segment1_bottom_length', 0));
            Decimal segTopThk = decVal(jsonData, prefix + 'segment2_top_thickness',      decVal(jsonData, prefixCus + 'segment2_top_thickness', 0));
            Decimal segBotThk = decVal(jsonData, prefix + 'segment1_bottom_thickness',   decVal(jsonData, prefixCus + 'segment1_bottom_thickness', 0));
            Decimal overlap   = decVal(jsonData, prefix + 'overlap',                      decVal(jsonData, prefixCus + 'overlap', 0));

            descPole += 'Section - 2 '
                    + '(Top Segment Length - ' + segTopLen.intValue() + ' mm, '
                    + 'Bottom Segment Length - ' + segBotLen.intValue() + ' mm'
                    //+ (overlap > 0 ? ', Overlap - ' + overlap.intValue() + ' mm' : '') + '), '
                    + 'Thickness - ' + segTopThk.intValue() + ' mm (Top) , '
                    + segBotThk.intValue() + ' mm (Bottom). ';
        }

        descPole += buildBasePlateDesc(bpType, bpSize, bpThk) 
            		+ (extraMicron != '' ? ', with ' + extraMicron + ' micron'                : '')
                    + (puPaintPole != '' ? '. PU Paint: ' + puPaintPole                    : '')
                    + (solarStruct != '' ? '. Solar Structure: ' + solarStruct             : '')
                    + (batteryBox  != '' ? '. Battery Box: ' + batteryBox                  : '')
                    + (laddar  != '' ? '. Laddar: ' + laddar                  : '')
            		+ (addDes  != '' ? '. Additional Item: ' + addDes                  : '')
                	+'.';
            		

        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            descPole += suffix;
        }

        return descPole;
    }
    // ═══════════════════════════════════════════════════════════════════════
    // HIGH MAST BUILDER  (unchanged aside from freight helper rename)
    // ═══════════════════════════════════════════════════════════════════════
    private void buildHighMastLineItems() {
 
        Decimal gstPct  = 18;
        String  freight = strVal(jsonData, 'freight_incoterms', 'Ex-works');
        Integer slCounter = 1;
        Decimal totalPoleQty = 0;
 		
        for (Integer m = 1; m <= 10; m++) {
            String p   = 'r' + m + '_';
            String kit = 'kit_line_' + m + '_';
 
            Decimal mastHeight = decVal(jsonData, p + 'lm_height_of_mast', 0);
            if (mastHeight == 0) continue;
            startGroup();   // one mast row = one line item. Reetabrata (18th Aug 2026)
 
            Decimal segCount   = decVal(jsonData, p + 'lm_no_of_segment', 1);
            // TOP DIA: seg 1 uses lm_1_oaf_top, seg 2..N use the top segment's OAF top - Reetabrata (8th July 2026)
            Decimal topDia     = (segCount.intValue() <= 1) ? decVal(jsonData, p + 'lm_1_oaf_top', 0) : decVal(jsonData, p + 'lm_' + segCount.intValue() + '_top_oaf_top', 0);
            // BOTTOM DIA: seg 1 uses lm_1_oaf_bottom, seg 2..N use the bottom segment's OAF bottom - Reetabrata (8th July 2026)
            Decimal botDia     = (segCount.intValue() <= 1) ? decVal(jsonData, p + 'lm_1_oaf_bottom', 0) : decVal(jsonData, p + 'lm_bot' + segCount.intValue() + '_oaf_bot', 0);
            String  lenList    = buildSegmentLengthList(jsonData, p, segCount.intValue());
            String  thkList    = buildSegmentThicknessList(jsonData, p, segCount.intValue());
            Decimal lastBotDia = botDia; // BOTTOM DIA now correct for all segment counts - Reetabrata (8th July 2026)

            Decimal qty = decVal(jsonData, p + 'lm_quantity',        1);
            Decimal bpOD  = decVal(jsonData, p + 'lm_od_of_base_plate',        0);
            Decimal bpThk = decVal(jsonData, p + 'lm_thickness_of_base_plate', 0);
            Decimal pcd   = decVal(jsonData, p + 'lm_pcd',                     0);
 
            // null stays null - no invented 24/850/6 in the offer. Deepanjan (20th Aug 2026)
            String  boltDia   = strVal(jsonData, p + 'lm_fdn_bolt_dia',    '');
            Decimal boltLen   = decVal(jsonData, p + 'lm_fdn_bolt_length',  0);
            Decimal noOfBolts = decVal(jsonData, p + 'lm_fdn_no_of_bolt',    0);
 
            Decimal mastUnitPrice = 0;
            for (Integer s = 1; s <= segCount.intValue(); s++) { // Reetabrata (8th July 2026)
                mastUnitPrice += decVal(jsonData, p + 'lm_' + s + '_unit_price', 0);
            }
            if (mastUnitPrice == 0) {
                mastUnitPrice = decVal(jsonData, p + 'lm_1_unit_price', 0);
            }

            mastUnitPrice = perPolfrieght ? mastUnitPrice + perPolTPCharg : mastUnitPrice;

            // Changes for bug UIL-HM-143
            Decimal latchingDeviceRate = decVal(jsonData, 'lm_lc_rate',        0);
            String latchDeviceDes = '';
            System.debug('latchingDeviceRate --> ' + latchingDeviceRate + ' | isLatchingMast --> '+ isLatchingMast);
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
                mastUnitPrice += rowDec(jsonData, p, 'lm_spike_unit_price', 0)
                               + rowDec(jsonData, p, 'lm_dc_unit_price',    0);
            }
            Boolean hasSpecialDesc    = siBoolVal(jsonData, p + 'lm_is_special_desc');
            // added special description for lightning mast
            String  specialDescClause = '';
            if (hasSpecialDesc) {
                String  specialDescText  = strVal(jsonData, p + 'lm_special_desc_text', '');
                Decimal specialDescPrice = decVal(jsonData, p + 'lm_special_desc_unitPrice', 0);
                if (String.isNotBlank(specialDescText)) {
                    specialDescClause = ' SPECIAL: ' + specialDescText + '.';
                }
                mastUnitPrice += specialDescPrice;
            }

            // PU PAINT is no longer added here. Since 8 Sep 2026 the realized PU Paint rate is
            // part of lm_{s}_unit_price itself (segmentGenerator.js, same rule as the normal LCLM
            // blueprint), so the segment sum above already carries it. The 4 Sep Apex fold
            // charged it a second time and was removed. Deepanjan (8th September 2026)


            Decimal boltUnitPrice = decVal(jsonData, p + 'lm_fdn_unit_price', 0);
 
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
     
            String  st = '';
            Decimal accUnitPrice = 0;
            if (segCount == 1) {
                accUnitPrice = decVal(jsonData, kit + 'lm_kit_unit_price', 0);
            } else if (segCount == 2) {
                st = kit + 'lm_' + segCount.intValue() + '_kit_unit_price';
                accUnitPrice = decVal(jsonData, st, 0);
            } else if (segCount == 3 || segCount == 4 || segCount == 5) {
                st = kit + 'lm_3_kit_unit_price';
                accUnitPrice = decVal(jsonData, st, 0);
            } else if (segCount >= 6) {
                // SEGMENT ABOVE 5: accessories price is the Additional Accessories -> TOTAL RATE
                // (= RATE + RATE * REALIZATION / 100), entered/derived in the Weight Estimator.
                // Row-prefixed key wins; unprefixed is the section default. Falls back to the raw
                // RATE so quotes saved before TOTAL RATE existed still price correctly.
                //  - Reetabrata (9th July 2026)
                accUnitPrice = decVal(jsonData, p + 'lm_acc_total_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(jsonData, 'lm_acc_total_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(jsonData, p + 'lm_acc_rate', 0);
                if (accUnitPrice == 0) accUnitPrice = decVal(jsonData, 'lm_acc_rate', 0);
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
                + ' (MS GI).' // updated ' Lighting Arrestor and Earthing Spikes (MS GI)' to 'Lighting Arrestor (MS GI)' for bug UIL-HM-136
                // Segment Above 5 lets the user add an extra-micron spec and a PU paint note.
                // Both are galvanising / finish specs rather than separate goods, so they read
                // as one more sentence of this same paragraph. The helper returns '' when
                // neither was entered, which leaves this description byte-identical to before
                // for every quote that does not use them. Reetabrata (15th July 2026)
                + micronPaintClause(p)
                + specialDescClause
                // CUSTOM LIGHTNING MAST ONLY. Guarded by the flag, so for High Mast /
                // Lighting Mast / LCLM / Signage / Latching this contributes the empty
                // string and the description above is byte-identical to before.
                // Faizan (24th July 2026)
                + (isCustomLightningMast ? buildSpecialAdditionsClause(jsonData, p) : '');

            if(isSignageMast){
               	Decimal adUnit = decVal(jsonData, p + 'lm_ad_unit_price',  0);
                String  adDesc = strVal(jsonData, p + 'lm_ad_description', '');
                String s_a_d = '';
                System.debug('adUnit --> '+adUnit +'| adDesc --> '+adDesc );
                if (adUnit > 0 && String.isNotBlank(adDesc)) {
                    mastUnitPrice += adUnit;
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
            // rate again would double-charge. This is the same sentence cmStadiumLines has
            // always printed for the Stadium recipe (its "siHas && !siSep" branch), which is
            // why Stadium never showed this bug.
            // No-op for any recipe without lm_si_* keys, and for a ticked item (that one still
            // prints as its own line below, unchanged).
            if (siHasRow(jsonData, p) && !showSpecialItemSeparatelyRow(jsonData, p)) {
                descMast += ' SPECIAL ITEM: ' + specialItemDescriptionRow(jsonData, p) + '.';
            }

            String suffix = getWindSpeedSuffix();
            if (String.isNotBlank(suffix)) {
                descMast = descMast +' '+suffix;
            }
 
            lineItems.add(buildRow(String.valueOf(slCounter++), descMast,
                          mastUnitPrice, gstPct, qty, freight));
            totalPoleQty += 1;
 
            String descBolt =
                'Supply of FOUNDATION BOLTS - M ' + boltDia
                + ' x ' + boltLen.intValue() +'mm'
                + ' (' + noOfBolts.intValue() + ' Nos.) with Template and Anchor Plate.';
            if(boltDia == 'N.R.'){
                    descBolt += ' \u0001BOLT_N_R\u0001';
                    //descBolt += ' (NOT REFLECTED ON UI)';
                    //descBolt += '<span style="color:#c00000;font-weight:bold;">( NOT REFLECTED ON UI)</span>';
                }
            // Emit only when there is real foundation data - same rule the seg5
            // Flag Mast row already uses (fndPrice > 0 || fbNo > 0). With the
            // 24/850/6 defaults gone, an untouched section would otherwise print
            // "M  x 0 (0 Nos.)" at 0. "Without Foundation" also drops the line.
            // Deepanjan (20th Aug 2026)
            // "Without Foundation" no longer drops the line - it states the bolt
            // spec and marks it out of scope, in red, at rate 0. Deepanjan (21st Aug 2026)
            if (fdnSuppressed(jsonData, p)) {
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              fdnNotInScopeDesc(boltDia, boltLen, noOfBolts, pcd),
                              0, gstPct, qty, freight));
            } else if (boltUnitPrice > 0 || noOfBolts > 0) {
                lineItems.add(buildRow(String.valueOf(slCounter++), descBolt,
                              boltUnitPrice, gstPct, qty , freight));
            }
 
            // The accessories line is emitted ONLY when it is actually priced. A zero-rate
            // row used to print anyway, filled with hardcoded default specs.
            //  - Reetabrata (9th July 2026)
                        // Segment Above 5: the RATE is optional, the specification is not. A row that
            // carries winch / power tool / wire rope / cable specs, or has OPTIONAL ELECTRICAL
            // ITEMS ticked, but no RATE printed nothing at all - the whole ACCESSORIES PART
            // sentence vanished (Q 00001324). It now prints at rate 0, exactly as the
            // Without-Foundation bolt line already does. Deepanjan (9th September 2026)
            Boolean accSpecOnly = isSegmentAbove5 == true && isSegAbove5 && accUnitPrice <= 0
                && (String.isNotBlank(winchSpec) || String.isNotBlank(toolSpec)
                    || String.isNotBlank(ropeSpec) || String.isNotBlank(cableSpec)
                    || hasOptionalElectricalItems(jsonData, kit, p));
            
            if (accUnitPrice > 0 || accSpecOnly) {
                Boolean hasOptElec = hasOptionalElectricalItems(jsonData, kit, p);
                String  aolVal = hasOptElec ? optElecVal(jsonData, kit, p, 'lm_type_of_aol') : '';
                String  controlSwitchVal = hasOptElec ? optElecVal(jsonData, kit, p, 'lm_no_of_aviation_light') : '';
                String  feederPillarVal  = hasOptElec ? optElecVal(jsonData, kit, p, 'lm_feeder_piller_control') : '';
                //String descAcc = buildAccessoriesDesc(true, mastHeight, winchSpec, toolSpec,ropeSpec, cableSets, cableSpec);
                // call overload method
                System.debug('***line 1700 kit electric '+ hasOptElec + ' ' + aolVal + ' ' + controlSwitchVal + ' ' + feederPillarVal);
                String descAcc = buildAccessoriesDesc(true, mastHeight, winchSpec, toolSpec,
                                                      ropeSpec, cableSets, cableSpec,
                                                      hasOptElec, aolVal, controlSwitchVal, feederPillarVal);
                                // Rate 0 => the numeric cells read '-' instead of 0.00, exactly like the
                // Without-Foundation line. Deepanjan (9th September 2026)
                if (accSpecOnly) descAcc += '\u0001NO_RATE\u0001';
                
                lineItems.add(buildRow(String.valueOf(slCounter++), descAcc,
                              accUnitPrice, gstPct, qty, freight));
            }
 
            // Per-row SPECIAL ITEM (27-Jul per-row sections): each mast row now
            // carries its own r{n}_lm_si_* set, so its line prints right under
            // ITS mast. Legacy quotes have no r{n}_ keys, so this is silent for
            // them and the quote-level block below still covers them; new
            // quotes have no bare keys, so that block is silent in turn - the
            // two can never both fire. Deepanjan (27th July 2026)
            if (showSpecialItemSeparatelyRow(jsonData, p)) {
                lineItems.add(buildRow(String.valueOf(slCounter++),
                              specialItemDescriptionRow(jsonData, p),
                              // QTY was hardcoded 1: one Motor priced once, however many masts
                              // the row carries. It belongs to THIS mast row, so it takes the
                              // row's own quantity. Deepanjan (4th September 2026)
                              specialItemUnitRateRow(jsonData, p), gstPct, qty, freight));
            }

            System.debug('totalPoleQty --> ' + totalPoleQty);
            System.debug('Qty --> ' + qty);
            if (totalPoleQty > 0 && (isCustomLightningMast || isLatchingMast)) {
                System.debug('isCustomLightningMast --> '+isCustomLightningMast + ' | isLatchingMast --> '+ isLatchingMast);
                Decimal adUnit = decVal(jsonData, p + 'lm_ad_unit_price',  0);
                String  adDesc = strVal(jsonData, p + 'lm_ad_description', '');

                System.debug('adUnit --> '+adUnit +'| adDesc --> '+adDesc );
                if (adUnit > 0 && String.isNotBlank(adDesc)) {
                    Decimal adRate = adUnit;
                    String  adText = 'Supply of ADDITIONAL ITEM - ' + adDesc.trim();
                    // The weight is only meaningful on the Weight basis; on the Price basis the
                    // user typed a rupee value and lm_ad_weight stays empty.
                    Decimal adWt = decVal(jsonData, p + 'lm_ad_weight', 0);
                    /*if (strVal(jsonData, 'lm_ad_basis', '').equalsIgnoreCase('Weight') && adWt > 0) {
                        adText += ' - ' + cmNum(adWt) + ' Kg';
                    }*/
                    lineItems.add(buildRow(String.valueOf(slCounter++), adText + '.',
                                adRate, gstPct, qty, freight));
                }
            }
        }
 
        // SPECIAL ITEMS: one line at the end of the offer, only when ticked. - Reetabrata (9th July 2026)
        // (Legacy quote-level keys only - see the per-row block inside the loop.)
        if (totalPoleQty > 0 && showSpecialItemSeparately(jsonData)) {
            startGroup();   // quote-level row, own line item. Reetabrata (18th Aug 2026)
            lineItems.add(buildRow(String.valueOf(slCounter++),
                          specialItemDescription(jsonData),
                          specialItemUnitRate(jsonData), gstPct, 1, freight));
        }
 
        // ADDITIONAL DETAILS: Signage Mast and Latching Mast, one line at the end of the offer.
        //
        // This sits OUTSIDE the per-mast loop above on purpose. The lm_ad_* keys are
        // unprefixed - the estimator saves one set per quote, not one per mast row - so
        // running this inside the loop would print the same row once per mast.
        //
        // lm_ad_unit_price already carries GST (the estimator formula multiplies by 1.18)
        // and buildRow() adds GST on top of the rate it is handed, so the GST is divided
        // back out here to avoid charging it twice.
        //
        // Guarded by the type flags and a non-blank description, so no other mast type can
        // reach it and no existing offer gains a row. Latching Mast added: Reetabrata (16th July 2026)
        // if (totalPoleQty > 0 && (isSignageMast || isLatchingMast)) {
        //     Decimal adUnit = decVal(jsonData, 'lm_ad_unit_price',  0);
        //     String  adDesc = strVal(jsonData, 'lm_ad_description', '');

        //     System.debug('Outside Loop adUnit --> '+adUnit +'| adDesc --> '+adDesc );
        //     if (adUnit > 0 && String.isNotBlank(adDesc)) {
        //         Decimal adRate = adUnit / (1 + (gstPct / 100));
        //         String  adText = 'Supply of ADDITIONAL ITEM - ' + adDesc.trim();
        //         // The weight is only meaningful on the Weight basis; on the Price basis the
        //         // user typed a rupee value and lm_ad_weight stays empty.
        //         Decimal adWt = decVal(jsonData, 'lm_ad_weight', 0);
        //         /*if (strVal(jsonData, 'lm_ad_basis', '').equalsIgnoreCase('Weight') && adWt > 0) {
        //             adText += ' - ' + cmNum(adWt) + ' Kg';
        //         }*/
        //         lineItems.add(buildRow(String.valueOf(slCounter++), adText + '.',
        //                       adRate, gstPct, 1, freight));
        //     }
        // }
 
        // COSTING OF LATCHING: Latching Mast only, its own line at the end of the offer.
        //
        // Unlike ADDITIONAL DETAILS above, no GST is divided back out here. The estimator's
        // lm_lc_unit_price carries the 1.18, but the raw rate and quantity are saved as their
        // own fields, so buildRow() is handed lm_lc_rate (GST-free) and applies GST itself -
        // the two agree without any division.
        //
        // The lm_lc_* keys are unprefixed (one set per quote), so this also sits outside the
        // per-mast loop. Guarded by isLatchingMast, false for every other mast type, so no
        // existing offer gains a row. Reetabrata (16th July 2026)

        // Changes for bug UIL-HM-143
        // if (totalPoleQty > 0 && isLatchingMast) {
        //     Decimal lcRate = decVal(jsonData, 'lm_lc_rate', 0);
        //     if (lcRate > 0) {
        //         Decimal lcQty = decVal(jsonData, 'lm_lc_quantity', 1);
        //         if (lcQty <= 0) lcQty = 1;
        //         startGroup();   // quote-level row, own line item. Reetabrata (18th Aug 2026)
        //         lineItems.add(buildRow(String.valueOf(slCounter++), 'Costing of Latching.',
        //                       lcRate, gstPct, lcQty, freight));
        //     }
        // }
 
        appendFreightRow(gstPct, freight, slCounter, totalPoleQty);
 
        if (lineItems.isEmpty()) {
            startGroup();   // Reetabrata (18th Aug 2026)
            lineItems.add(buildRow('1',
                'Supply of LIGHTING MAST (please verify quote configuration).',
                decVal(jsonData, 'r1_lm_1_unit_price', 0), gstPct, 1, freight));
        }
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
        String d = (withSupplyOf ? 'Supply of ' : '')
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
 
    private List<Object> getList(Map<String, Object> m, String key) {
        if (!m.containsKey(key) || m.get(key) == null) return new List<Object>();
        try { return (List<Object>) m.get(key); }
        catch (Exception e) { return new List<Object>(); }
    }
 
    private Boolean isFreightLine(String itemName) {
        if (String.isBlank(itemName)) return false;
        return itemName.containsIgnoreCase('Transportation')
            || itemName.containsIgnoreCase('Freight');
    }
 
    private void appendFreightRow(Decimal gstPct, String freight,
                                   Integer slCounter, Decimal totalPoleQty) {
        String transportAs = strVal(jsonData, 'transportation_as', '');
        if (String.isBlank(transportAs)) return;
 
        Decimal charge = decVal(jsonData, 'transportation_charges', 0);
		if (charge <= 0) return;
 
        String taLower = transportAs.toLowerCase();
 		if (taLower.contains('Lump sum') || taLower.contains('lump sum')) {
            Decimal qty = 1;
            Decimal actGst = gstPct; 
            System.debug('inside if chcek block --> ');
            startPlainGroup();   // numbered, no SUB-TOTAL. Reetabrata (18th Aug 2026)
            lineItems.add(buildRow(String.valueOf(slCounter),
                'Transportation Charges ', charge, actGst, qty, freight));
        } 
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
        // WAS: base_amount + realization. mrl_realization / lwc_realization are declared
        // type:"hidden" in segmentGenerator.js and the estimator's save routine skips
        // every hidden field, so that second term read 0 on every quote and the item came
        // out at the bare base rate (108 instead of 118 per kg) - the very shortfall the
        // 19-Aug comment above set out to fix. mrl_amount_realization / lwc_amount_realization
        // is the same figure (Base_Amount__c + 10), is a visible field, and does persist.
        // base_amount is kept only as a fallback for a quote saved before that field
        // existed. Deepanjan (21st Aug 2026)
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
 
    // Builds the accessories description, omitting any component that is unset or NA.
    private String buildAccessoriesDesc(Boolean withSupplyOf, Decimal mastHeight, String winchSpec,
                                        String toolSpec, String ropeSpec, String cableSets, String cableSpec) {
        String d = (withSupplyOf ? 'Supply of ' : '')
                 + mastHeight + ' MTR '
                 + (isLCLM ? 'LCLM' : (isSignageMast ? signageMastName() : (isLatchingMast ? 'LATCHING MAST' : 'LIGHTING MAST'))) + ' ACCESSORIES PART:';   // Reetabrata (15th July 2026) // Signage branch: Reetabrata (16th July 2026)
        if (String.isNotBlank(winchSpec)) d += ' Double Drum Winch ' + winchSpec;
        if (String.isNotBlank(toolSpec))  d += ', ' + toolSpec;   // updated 'Power Tool Motor with torque limiter' to 'Motor' for UIL-HM-137
        if (String.isNotBlank(ropeSpec))  d += ', ' + ropeSpec + ' SS Wire Rope, Manual Operating Handle';
        if (String.isNotBlank(cableSpec) && String.isNotBlank(cableSets)) {
            d += ' Trailing Cable (' + cableSets + ' Sets ' + cableSpec + '. EPR PCP Sheathed Round Coated Copper Cable.';
        }
        d += ' with GI JB (without luminaries, AOL, Control Switch & Feeder Pillar).';
        return d;
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

    private LineItemWrapper buildRow(String slNo, String descriptions,
            Decimal unitRate, Decimal gstPct, Decimal qty, String freight) {
 
        Decimal rUnitRate = unitRate.setScale(2, RoundingMode.HALF_UP);
        Decimal gstAmt    = (rUnitRate * gstPct / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal unitAmt   = rUnitRate + gstAmt;
        Decimal total     = (unitAmt * qty).setScale(2, RoundingMode.HALF_UP);
                
       System.debug('***1941 buildRow method '+ rUnitRate + ' ' + gstAmt + ' ' + unitAmt + ' ' + total );
                 
        LineItemWrapper w = new LineItemWrapper();
        w.slNo           = slNo;
        // Escape ALL descriptions (any mast type) so raw user text is safe under
        // escape="false", then restore the Stadium red clauses. Reetabrata (13th July 2026)
        String d = (descriptions == null ? '' : descriptions);
        d = d.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
        d = d.replace('\u0001RED_LED\u0001', ' <span style="color:#c00000;font-weight:bold;">(Without LED Floodlight &amp; aviation lights and feeder pillar panel)</span>');
        d = d.replace('\u0001RED_LED_LWC\u0001', ' <span style="color:#c00000;font-weight:bold;">(Without LED Floodlight &amp; aviation lights and feeder pillar panel &amp; wiring cable)</span>');   // Ladder With Cage variant. Reetabrata (13th July 2026)
        d = d.replace(' \u0001BOLT_N_R\u0001',' <span style="font-weight:bold;"> (NOT REFLECTED ON UI)</span>');
        // "Without Foundation" out-of-scope sentence - whole line red. Deepanjan (21st Aug 2026)
        d = d.replace('\u0001FDN_NIS_ON\u0001',  '<span style="color:#c00000;font-weight:bold;">');
        d = d.replace('\u0001FDN_NIS_OFF\u0001', '</span>');
        d = d.replace('\u0001BR\u0001', '<br/>');
                // Marker only - carries no text. Deepanjan (9th September 2026)
        d = d.replace('\u0001NO_RATE\u0001', '');
                
        if(singageSpecAdd != null){
                d = d.replace('\u0002_SINGAGE_MAST_ADD_DES\u0002','<span style="color: red; font-weight: bold;">' + singageSpecAdd + '</span>');
            }
        w.description    = d;
        w.unitRate       = formatINR(rUnitRate);
        w.gstPct         = String.valueOf(gstPct.intValue());
        w.gstAmount      = formatINR(gstAmt);
        w.freight        = freight;
        w.unitAmount     = formatINR(unitAmt);
        w.qty            = String.valueOf(qty.intValue());
        w.qtyRaw         = qty;
        w.totalAmount    = formatINR(total);
        w.unitRateRaw    = rUnitRate;
        w.gstAmountRaw   = gstAmt;
        w.unitAmountRaw  = unitAmt;
        w.totalAmountRaw = total;
                
                // Marker only - carries no text. Deepanjan (9th September 2026)
                
                if (descriptions != null && (descriptions.contains('\u0001FDN_NIS_ON\u0001')
                                             || descriptions.contains('\u0001NO_RATE\u0001'))) {
                                                 w.unitRateRaw    = 0;
                                                 w.gstAmountRaw   = 0;
                                                 w.unitAmountRaw  = 0;
                                                 w.totalAmountRaw = 0;
                                                 w.gstPct 		 = '-';
                                                 w.qty    		 = '-';
                                                 w.unitRate       = '-';
                                                 w.gstAmount      = '-';
                                                 w.unitAmount     = '-';
                                                 w.totalAmount    = '-';
                                                 w.freight		  = '-';
                                             }

        // ANNEXURE GROUPING: while a group is open the slNo handed in above
        // is replaced by the hierarchical one, which is why none of the
        // existing call sites had to change. Reetabrata (18th Aug 2026)
        w.groupNo = curGroup;
        if (curGroup > 0) {
            curPart++;
            w.slNo = curPlain
                   ? String.valueOf(curGroup)
                   : String.valueOf(curGroup) + '.' + String.valueOf(curPart);
        }
        return w;
    }
    
    
    // ═══════════════════════════════════════════════════════════════════════
//  CUSTOMIZED MAST — STADIUM MAST / FLAG MAST
//  Reuses the class's own strVal / decVal / buildRow / appendFreightRow.
// ═══════════════════════════════════════════════════════════════════════
private void buildCustomizedMastLineItems() {
 
    Decimal gstPct   = 18;
    String  freight  = strVal(jsonData, 'freight_incoterms', 'Ex-works');
    Integer sl       = 1;
    Decimal totalQty = 0;
 
    if (isStadiumMast) {
        if (cmBool(jsonData, 'man_riding_lift')) {
            startGroup();   // MAN RIDING LIFT product. Reetabrata (18th Aug 2026)
            sl = cmStadiumLines(gstPct, freight, sl, 'mrl_');
            totalQty += decVal(jsonData, 'mrl_quantity', 1);
        }
        if (cmBool(jsonData, 'ladder_with_cage')) {
            startGroup();   // LADDER WITH CAGE product. Reetabrata (18th Aug 2026)
            sl = cmStadiumLines(gstPct, freight, sl, 'lwc_');
            totalQty += decVal(jsonData, 'lwc_quantity', 1);
        }
    } else if (isFlagMast) {
        if (isSeg5FlagMast) {
            // SEGMENT ABOVE 5 recipe: r{n}_lm_* rows. cmFlagLines() reads
            // r{n}_fm_* and would emit nothing. Deepanjan (22nd July 2026)
            sl = cmSeg5FlagLines(gstPct, freight, sl);
            totalQty += seg5FlagRowCount();
        } else {
            sl = cmFlagLines(gstPct, freight, sl);
            totalQty += decVal(jsonData, 'fm_est_quantity', 1);
        }
    }
 
    appendFreightRow(gstPct, freight, sl, totalQty);
 
    if (lineItems.isEmpty()) {
        startGroup();   // Reetabrata (18th Aug 2026)
        lineItems.add(buildRow('1',
            'Supply of CUSTOMIZED MAST (please verify quote configuration).',
            0, gstPct, 1, freight));
    }
}
// Stadium Mast
private Integer cmStadiumLines(Decimal gstPct, String freight, Integer sl, String p) {
 
    Map<String,Object> m = jsonData;
    Integer segCount = decVal(m, p + 'no_of_segment', 0).intValue();
    if (segCount <= 0) {
        // Mast is empty, but a ticked special item must still appear on its own line
        // (we can't assume the user filled the mast). Absent special item => no-op. Reetabrata (13th July 2026)
        // Segment Above 5 only - same rule as siHas below. Deepanjan (19th Aug 2026)
        if (isSegmentAbove5 && String.isNotBlank(strVal(m, p + 'si_type', ''))
                && siBoolVal(m, p + 'si_show_separate')) {
            String d0 = strVal(m, p + 'si_description', '');
            if (String.isBlank(d0)) d0 = 'Special Item';
            Decimal v0 = decVal(m, p + 'si_value', 0);
            Decimal r0 = strVal(m, p + 'si_type', '').equalsIgnoreCase('Weight')
                           ? stadiumSiRatePerKg(m, p) * v0 : v0;
            lineItems.add(buildRow(String.valueOf(sl++),
                'Supply of SPECIAL ITEM: ' + d0 + '.', r0, gstPct, 1, freight));
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
 
    // Height display: X+Y=Z if both exist
    String heightDisplay = '';
    if (segHt > 0 && headFrm > 0) {
        heightDisplay = cmNum(segHt) + '+' + cmNum(headFrm) + '=' + cmNum(mastHt);
    } else if (mastHt > 0) {
        heightDisplay = cmNum(mastHt);
    }
 
    // ── Main mast description (without bolts and accessories) ──
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
    
    // adding pu-paint/ micron details to main line - 06-Aug
    if (cmBool(m, p + 'is_extra_micron')) {
        String micronVal = strVal(m, p + 'extra_micron', '');
        if (String.isNotBlank(micronVal)) {
            descMast += ', with ' + micronVal + ' micron';
        }
    }
    if (cmBool(m, p + 'pu_paint')) {
        String puNote = strVal(m, p + 'pu_paint_note', '');
        descMast += String.isNotBlank(puNote) ? '. PU Paint' + ' - ' + puNote.trim() : '';
    }

    String suffix = isMrl ? strVal(m, 'man_riding_wind_speed', '') : strVal(m, 'ladder_cage_wind_speed', '');
    if (String.isNotBlank(suffix)) {
        descMast = descMast +' Wind Speed - '+suffix;
    }
    
    // adding special note description
    if(strVal(m, p + 'special_note', '')!=null){
        String specialNote = strVal(m, p + 'special_note', '');
        
        descMast += String.isNotBlank(specialNote.trim()) ? ' Special Note: ' + specialNote : '';
    }
 
    // Red exclusion clause (Stadium only). Escape the dynamic description, then
    // append the fixed red span as literal markup. Reetabrata (13th July 2026)
    descMast += isMrl ? ' \u0001RED_LED\u0001' : ' \u0001RED_LED_LWC\u0001';   // MRL vs Ladder-With-Cage red clause (LWC adds '& wiring cable'). Reetabrata (13th July 2026)
 
    // ── Special item (per sub-mast: mrl_si_* / lwc_si_*) ──
    // UNTICKED 'show separate' -> fold description AND price into the mast line.
    // TICKED -> emitted as its own line after the accessories block. Absent keys => no-op.
    // The Stadium unit price does NOT fold si_price_add, so Apex owns the price here. Reetabrata (13th July 2026)
    String  siType   = strVal(m, p + 'si_type', '');
    // Special Items are a Segment Above 5 feature: the normal Customized Mast section
    // logic carries no si_ field at all. Gating siHas on the mast type makes every path
    // below - folding into the mast line and the separate line - a no-op for any other
    // recipe, so Stadium quotes outside Segment Above 5 print exactly what they print
    // today. Deepanjan (19th Aug 2026)
    Boolean siHas    = isSegmentAbove5 && String.isNotBlank(siType);
    Boolean siSep    = siHas && siBoolVal(m, p + 'si_show_separate');
    String  siDesc   = strVal(m, p + 'si_description', '');
    if (String.isBlank(siDesc)) siDesc = 'Special Item';
    Decimal siVal    = decVal(m, p + 'si_value', 0);
    // TYPE = Weight prices the item at VALUE kg x the sub-mast's rate; TYPE = Price
    // returns the typed value as-is. Deepanjan (19th Aug 2026)
    Decimal siRate   = siType.equalsIgnoreCase('Weight')
                         ? stadiumSiRatePerKg(m, p) * siVal
                         : siVal;
    if (siHas && !siSep) {
        descMast += ' SPECIAL ITEM: ' + siDesc + '.';
        segPrice += siRate;
    }
 
    // ── Add main mast line ──
    lineItems.add(buildRow(String.valueOf(sl++), descMast, segPrice, gstPct, qty, freight));
 
    // ── Foundation bolts (separate line) ──
    Decimal fndPrice = 0;
    // take the quantity value entered for foundation bolt - 06-Aug
    Decimal fbQty = decVal(m, p + 'fb_quantity', 0);
    if (fbQty <= 0) fbQty = 1;
    String  descBolt = '';
    String  fbDia = strVal(m, p + 'fb_diameter', '');
    Decimal fbLen = decVal(m, p + 'fb_length', 0);
    Decimal fbNo  = decVal(m, p + 'fb_no_of_bolt', 0);
    // isSegmentAbove5 guard: a Customized Mast Stadium quote outside Segment Above 5
    // can also carry foundation_bolt_type, and today it prints NOTHING when the user
    // picks "without". This sentence is a seg5 requirement, so it is scoped to seg5
    // and every other Stadium quote keeps printing exactly what it prints now.
    // Deepanjan (21st Aug 2026)
    if (strVal(m, p + 'foundation_bolt_type', '').containsIgnoreCase('without')) {
        //if (isSegmentAbove5) {
        // Without Foundation Bolt: state the spec the mast is suitable for and mark it
        // out of scope, in red, at rate 0 - the same sentence Lighting Mast and Flag Mast
        // already print. Stadium was simply dropping the line. Deepanjan (21st Aug 2026)
        // if without foundation selected - foundation line item will be created with this desc for stadium mast as well
            lineItems.add(buildRow(String.valueOf(sl++),
                fdnNotInScopeDesc(fbDia, fbLen, fbNo, bpPcd),
                0, gstPct, fbQty, freight));
        //}
        
    } else {
        fndPrice = decVal(m, p + 'foundation_unit_price', 0).setScale(2, RoundingMode.HALF_UP);
        Decimal fndWt = decVal(m, p + 'foundation_weight', 0);
        if (fndPrice > 0 || fndWt > 0 || fbNo > 0) {
            // Weight clause removed from the Single Scope description. fndWt is still read
            // above because it gates whether this line is emitted at all. Deepanjan (16th July 2026)
            descBolt = 'Supply of FOUNDATION BOLTS - M' + (String.isBlank(fbDia) ? '0' : fbDia)
                     + ' x ' + cmNum(fbLen) +'mm'
                     + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate'
                     + '.';
            lineItems.add(buildRow(String.valueOf(sl++), descBolt, fndPrice, gstPct, fbQty, freight));
        }
    }
 
    // ── Accessories (Manrider System or Ladder with Cage) ──
    if (isMrl) {
        Decimal accRate = decVal(m, 'mrl_mast_acc_foundation_unit_price', 0)
                              .setScale(2, RoundingMode.HALF_UP);
        Decimal accQty  = decVal(m, 'mrl_mast_acc_quantity', 1);
        if (accQty == 0) accQty = 1;
        String  accDesc = strVal(m, 'mrl_mast_acc_description', '');
        if (accRate > 0 || String.isNotBlank(accDesc)) {
            String accLine = 'Supply of standard Manrider System'
                + (String.isNotBlank(accDesc) ? ' - ' + accDesc : '')
                + '.';
            lineItems.add(buildRow(String.valueOf(sl++), accLine, accRate, gstPct, accQty, freight));
        }
    } else {
        String  accDesc = strVal(m, 'lwc_acc_description', '');
        Decimal accWt   = decVal(m, 'lwc_acc_weight', 0);
        // If there is a separate price field for ladder, you can use it; otherwise 0 as in the original
        Decimal accRate = decVal(m, 'lwc_unit_price', 0).setScale(2, RoundingMode.HALF_UP);  // adjust if a price field exists
        if (String.isNotBlank(accDesc) || accWt > 0) {
            // Weight clause removed from the Single Scope description. accWt is still read
            // above because it gates whether this line is emitted at all. Deepanjan (16th July 2026)
            String accLine = 'Supply of standard Man-Riding Ladder with Safety Cage system'
                + (String.isNotBlank(accDesc) ? ' - ' + accDesc : '')
                + '.';
            lineItems.add(buildRow(String.valueOf(sl++), accLine, accRate, gstPct, qty, freight));
        }
    }
 
    // ── Special item as its own line (only when 'show separate' is TICKED) ── Reetabrata (13th July 2026)
    if (siSep) {
        // QTY: the sub-mast's own quantity. UNTICKED already charges siRate once per unit
        // (it is added into segPrice above, which buildRow multiplies by qty), so a ticked
        // item priced at qty 1 made the same item cost different money depending only on
        // that checkbox. Deepanjan (4th September 2026)
        lineItems.add(buildRow(String.valueOf(sl++),
            'Supply of SPECIAL ITEM: ' + siDesc + '.', siRate, gstPct, qty, freight));
    }
    
    if (isMrl) {
        List<Integer> slHolder = new List<Integer>{ sl };
        addMrlKitAccessoryLine(mastHt, qty, segCount, gstPct, freight, slHolder);
        // addMrlKitAccessoryLine only fires when the quote carries KIT data. A Segment
        // Above 5 Stadium quote has none, so its Additional Accessories block never
        // reached the offer at all. Emit it here, only when the KIT line did not.
        // Deepanjan (21st Aug 2026)
        if (isSegmentAbove5 && slHolder[0] == sl) {
            addStadiumSeg5AccessoryLine(mastHt, qty, gstPct, freight, slHolder);
        }
        sl = slHolder[0];
    }
    
    return sl;  
}

// ── Segment Above 5 Stadium: Additional Accessories -> offer line ──
// The seg5 Stadium recipe keeps TYPE OF WINCH / POWER TOOL / WIRE ROPE and the rate in
// the quote-level lm_* block (MRL only - the section is gated on man_riding_lift) and
// prices it with lm_acc_total_rate (rate + realization). Wording is the shared
// buildAccessoriesDesc, so the line reads exactly like Lighting Mast and Flag Mast, with
// the unit and drum type appended the same way the seg5 LM path does.
// Deepanjan (21st Aug 2026)
private void addStadiumSeg5AccessoryLine(Decimal mastHt, Decimal qty, Decimal gstPct,
                                         String freight, List<Integer> slHolder) {
    Decimal accRate = decVal(jsonData, 'lm_acc_total_rate', 0);
    if (accRate <= 0) accRate = decVal(jsonData, 'lm_acc_rate', 0);

    String winchSpec = withDrum(withUnit(
                          specOrBlank(strVal(jsonData, 'lm_type_of_winch', ''))
                              .replace(' kg', 'Kg').replace(' KG', 'Kg'),
                          strVal(jsonData, 'lm_winch_unit', '')),
                          strVal(jsonData, 'lm_winch_drum', ''));
    String toolSpec  = withUnit(specOrBlank(strVal(jsonData, 'lm_type_of_power_tool', '')),
                                strVal(jsonData, 'lm_power_tool_unit', ''));
    String ropeSpec  = withUnit(specOrBlank(strVal(jsonData, 'lm_type_of_wire_rope', '')),
                                strVal(jsonData, 'lm_wire_rope_unit', ''));

    // Nothing typed and nothing priced -> no line, same convention as everywhere else.
    if (accRate <= 0 && String.isBlank(winchSpec)
                     && String.isBlank(toolSpec) && String.isBlank(ropeSpec)) return;
    
    Boolean hasOptElec       = hasOptionalElectricalItems(jsonData, '', '');
    String  aolVal           = hasOptElec ? optElecVal(jsonData, '', '', 'lm_type_of_aol') : '';
    String  controlSwitchVal = hasOptElec ? optElecVal(jsonData, '', '', 'lm_no_of_aviation_light') : '';
    String  feederPillarVal  = hasOptElec ? optElecVal(jsonData, '', '', 'lm_feeder_piller_control') : '';
    String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, '', '',
                                          hasOptElec, aolVal, controlSwitchVal, feederPillarVal)
                         .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');

    //String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, '', '')
    //                    .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');

    Integer sl = slHolder[0];
    lineItems.add(buildRow(String.valueOf(sl++), descAcc,
                  accRate.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
    slHolder[0] = sl;
}
// Flag Mast
private Integer cmFlagLines(Decimal gstPct, String freight, Integer sl) {
 
    Map<String,Object> m = jsonData;
    
        System.debug('***line 2561 transportation_as'+ strVal(jsonData, 'transportation_as', '') + ' ' + strVal(jsonData, 'transportation_charges', '') + freight);
 
    // Flag Mast is now row-driven: the estimator saves one r{n}_ block per mast
    // row using the Lighting Mast shape (fm_ prefix, no L-Ring). One mast line
    // per populated row; the shared sections below are emitted once.
    // Reetabrata (15th July 2026)
    Boolean anyRow = false;
    Boolean scDone = false;
    for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
        String rPfx = 'r' + rowIdx + '_';
        if (String.isBlank(strVal(m, rPfx + 'fm_height_of_mast', ''))) continue;
        Integer segCount = decVal(m, rPfx + 'fm_no_of_segment', 0).intValue();
        if (segCount <= 0) continue;
        anyRow = true;
        // Each populated r{n}_ row is one mast the customer ordered, so each one
        // is its own line item: mast + foundation + PU paint + that row's
        // accessory and additional grids all land inside it, then a SUB-TOTAL.
        // Deepanjan (19th Aug 2026)
        startGroup();
        sl = cmFlagRowLines(m, rPfx, segCount, gstPct, freight, sl);
        // Per-row annexure grids (r{n}_fm_ac_* / r{n}_fm_ad_*) - own rows, one per
        // grid, per mast. Legacy quotes have no r{n}_ grid keys -> both no-op, and
        // the bare-key builders after the loop still cover them. Mutually exclusive
        // shapes, so no line can ever print twice.
        Decimal rowQty = decVal(m, rPfx + 'fm_est_quantity', 1);
        if (rowQty == 0) rowQty = 1;
                sl = cmFlagRowGridMerged(m, rPfx, rowQty, gstPct, freight, sl, false, !scDone);
        scDone = true;
    }
    if (!anyRow) return sl;
    
    // -- Aditional and accessory part
    // Everything below the row loop is quote-level (unprefixed keys), belonging to
    // no single mast, so each shared section is its own line item.
    // Deepanjan (19th Aug 2026)
    startGroup();
    sl = cmFlagPuPaintLine(m, gstPct, freight, sl);
    sl = cmFlagAccessoryItemLines(m, gstPct, freight, sl, false);
    sl = cmFlagAdditionalItemLines(m, gstPct, freight, sl);
    // ── Supplementary Costing (single section, unprefixed)
    List<String> supParts = new List<String>();
    Decimal supAmt  = 0;
    String  scDesc  = strVal(m, 'fm_sc_description', '');
    Decimal scQty   = decVal(m, 'fm_sc_quantity', 0);
    Decimal scAmt   = decVal(m, 'fm_sc_amount',   0);
    if (String.isNotBlank(scDesc) || scAmt > 0) {
        startGroup();   // Deepanjan (19th Aug 2026)
        supParts.add(scDesc + (scQty > 0 ? ' - ' + cmNum(scQty) + ' Nos.' : ''));
        supAmt += scAmt;
        lineItems.add(buildRow(String.valueOf(sl++),
            'Supply of FLAG MAST SUPPLEMENTARY ITEMS: ' + String.join(supParts, ', ') + '.',
            supAmt.setScale(2, RoundingMode.HALF_UP), gstPct, 1, freight));
    }
 
    // ── MAST ACCESSORIES (single section, unprefixed)
    Decimal maRate = decVal(m, 'fm_mast_acc_foundation_unit_price', 0)
                         .setScale(2, RoundingMode.HALF_UP);
    String  maDesc = strVal(m, 'fm_ma_description',  '');
    String  maNote = strVal(m, 'fm_ma_special_note', '');
    Decimal maQty  = decVal(m, 'fm_ma_quantity', 1);
    if (maQty == 0) maQty = 1;
    if (maRate > 0 || String.isNotBlank(maDesc)) {
        startGroup();   // Deepanjan (19th Aug 2026)
        lineItems.add(buildRow(String.valueOf(sl++),
            'Supply of FLAG MAST ACCESSORIES'
            + (String.isNotBlank(maDesc) ? ' - ' + maDesc : '')
            + (String.isNotBlank(maNote) ? '. Note: ' + maNote : '') + '.',
            maRate, gstPct, maQty, freight));
    }
 
    // ── FEEDER PILLAR (single section, unprefixed)
    if (cmBool(m, 'fm_fp_checkbox')) {
        Decimal fpRate = decVal(m, 'fm_fp_foundation_unit_price', 0)
                             .setScale(2, RoundingMode.HALF_UP);
        Decimal fpQty  = decVal(m, 'fm_fp_quantity', 1);
        if (fpQty == 0) fpQty = 1;
        if (fpRate > 0) {
            startGroup();   // Deepanjan (19th Aug 2026)
            lineItems.add(buildRow(String.valueOf(sl++),
                'Supply of FEEDER PILLAR as per standard.', fpRate, gstPct, fpQty, freight));
        }
    }
    return sl;
}
 
// One Flag Mast row -> mast line + its foundation line + its PU paint line.
// Accessory / Additional grids are section-level, emitted once in cmFlagLines().
// Faizan (16th July 2026)
private Integer cmFlagRowLines(Map<String,Object> m, String rPfx, Integer segCount,
                               Decimal gstPct, String freight, Integer sl) {
 
    Decimal segPrice  = decVal(m, rPfx + 'fm_' + segCount + '_unit_price', 0)
                            .setScale(2, RoundingMode.HALF_UP);
    Decimal segWeight = decVal(m, rPfx + 'fm_' + segCount + '_segment_weight', 0);
    Decimal qty       = decVal(m, rPfx + 'fm_est_quantity', 1);
    if (qty == 0) qty = 1;
    
    segPrice = perPolfrieght ? segPrice + perPolTPCharg : segPrice;

    Decimal mastHt = decVal(m, rPfx + 'fm_height_of_mast', 0);
    // TOP/BOTTOM DIA come from the row's own segment OAF keys
    // (r{n}_fm_{seg}_oaf_top / _oaf_bottom). The unprefixed fm_top_dia /
    // fm_bottom_dia keys were never saved by the blueprint, so the > 0 guards
    // below silently dropped both clauses from every Flag Mast description.
    // Top = segment 1 (topmost); bottom = last populated segment.
    // Deepanjan (16th July 2026)
    // fixing Flag Mast - accessory issue - 5 Aug
    Decimal topDia = (segCount <= 1)
        ? decVal(m, rPfx + 'fm_1_oaf_top', 0)
        : decVal(m, rPfx + 'fm_' + segCount + '_top_oaf_top', 0);
    if (topDia == 0) topDia = decVal(m, rPfx + 'fm_1_oaf_top', 0);                               
    Decimal botDia = decVal(m, rPfx + 'fm_bot' + segCount + '_oaf_bot', 0);
    if (botDia == 0) botDia = cmFlagBottomDia(m, rPfx, segCount);
    Decimal bpDia  = decVal(m, rPfx + 'fm_bp_diameter',  0);
    Decimal bpThk  = decVal(m, rPfx + 'fm_bp_thickness', 0);
    Decimal bpPcd  = decVal(m, rPfx + 'fm_bp_pcd',       0);
 
    // Extra Micron moved to per-row keys; bare keys are the legacy fallback.
    Boolean hasMicron = cmBool(m, rPfx + 'fm_is_extra_micron') || cmBool(m, 'fm_is_extra_micron');
    Decimal micronVal = decVal(m, rPfx + 'fm_extra_micron', decVal(m, 'fm_extra_micron', 0));                              
    String micron = (hasMicron && micronVal>0) ? cmNum(micronVal) : '';                                   
     
    // PU PAINT and SPECIAL DESCRIPTION are folded INTO the mast line - text into the
    // description, price into the mast unit rate - mirroring the Combined Scope, which
    // prints both clauses on the mast row and carries their value in its single rate.
    // All keys are r{n}_-prefixed (per-row estimator shape), so legacy quotes resolve
    // nothing here and their mast line stays byte-identical; their PU Paint still
    // prints via the legacy cmFlagPuPaintLine after the loop.
    Boolean hasPu   = cmBool(m, rPfx + 'fm_pu_paint');
    String  puNote  = hasPu ? strVal(m, rPfx + 'fm_pu_paint_note', '') : '';
    Decimal puRate  = hasPu ? decVal(m, rPfx + 'fm_pu_paint_unit_price', 0) : 0;   // pre-GST Price Value

    Boolean hasSd   = cmBool(m, rPfx + 'fm_is_special_desc');
    String  sdText  = hasSd ? strVal(m, rPfx + 'fm_special_desc_text', '') : '';
    sdText = String.isNotBlank(sdText.trim())?' SPECIAL : ' + sdText.trim() + '.' : '';                       
    Decimal sdRate  = hasSd
        ? (decVal(m, rPfx + 'fm_special_desc_unitPrice', 0))
              .setScale(2, RoundingMode.HALF_UP)
        : 0;

    if (puRate > 0) segPrice += puRate;
    if (sdRate > 0) segPrice += sdRate;
                                   
    segPrice = segPrice.setScale(2, RoundingMode.HALF_UP);                               
 
    String descText =
        'Supply of ' + (mastHt > 0 ? cmNum(mastHt) + ' MTRS ' : '')
        + 'FLAG MAST FABRICATED AS PER DIMENSION: '
        + (topDia > 0 ? 'TOP DIA - '    + cmNum(topDia) + ' mm, ' : '')
        + (botDia > 0 ? 'BOTTOM DIA - ' + cmNum(botDia) + ' mm, ' : '')
        + 'SECTION - '    + segCount + ' nos '
        + '(SECTION LENGTH - ' + cmFlagList(m, rPfx, segCount, 'length',    ' / ') + ' mm) '
        + 'THICKNESS - '  + cmFlagList(m, rPfx, segCount, 'thickness', ', ') + ' mm.'
        + (bpDia > 0 ? ' BASE PLATE - ' + cmNum(bpDia) + ' mm x ' + cmNum(bpThk) + ' mm,' : '')
        + (bpPcd > 0 ? ' PCD - ' + cmNum(bpPcd) + ' mm.' : '')
        // Weight clause removed from the Single Scope description. Deepanjan (16th July 2026)
        + (String.isNotBlank(micron) ? ' with ' + micron + ' micron.' : '')
        + (hasPu && String.isNotBlank(puNote) ? ' PU PAINT - ' + puNote.trim() + '.' : '')
		+ sdText;
        
    String suffix = getWindSpeedSuffix();
    if (String.isNotBlank(suffix)) {
        descText = descText +' '+suffix;
    }

    lineItems.add(buildRow(String.valueOf(sl++), descText, segPrice, gstPct, qty, freight));
 
    // FOUNDATION BOLTS - own line here; folded into the mast rate in Combined Scope.
    Decimal fndPrice = decVal(m, rPfx + 'fm_foundation_unit_price', 0)
                           .setScale(2, RoundingMode.HALF_UP);
    Decimal fndWt = decVal(m, rPfx + 'fm_foundation_weight', 0);
    String  fbDia = strVal(m, rPfx + 'fm_fb_diameter', '');
    Decimal fbLen = decVal(m, rPfx + 'fm_fb_length',     0);
    Decimal fbNo  = decVal(m, rPfx + 'fm_fb_no_of_bolt', 0);
    String fbType = strVal(m, rPfx + 'fm_fdn_bolt_type', '');
    Decimal fbPcd = decVal(m, rPfx + 'fm_bp_pcd',     0);                          
                                   
    if (fbType == 'With Foundation') {
        lineItems.add(buildRow(String.valueOf(sl++),
            // Weight clause removed from the Single Scope description. fndWt is still read
            // above because it gates whether this line is emitted at all. Deepanjan (16th July 2026)
            'Supply of FOUNDATION BOLTS - M' + (String.isBlank(fbDia) ? '0' : fbDia)
            + ' x ' + cmNum(fbLen) + 'mm'
            + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate'
            + '.', fndPrice, gstPct, qty, freight));
    }
                                   else if(fbType == 'Without Foundation'){
                                       lineItems.add(buildRow(String.valueOf(sl++),fdnNotInScopeDesc(fbDia, fbLen, fbNo, fbPcd),fndPrice, gstPct, qty, freight));
                                   }                              
                                                                  
    return sl;
}
    
// method to added accessories seprately for flagMast
private Integer cmFlagRowGridLine(Map<String,Object> m, String rPfx, String gridPfx,
                                  List<String> labels, Integer rows, String heading,
                                  Decimal qty, Decimal gstPct, String freight, Integer sl,
                                  Boolean seg5) {
    Decimal grand = decVal(m, rPfx + gridPfx + 'grand_total', 0);
    List<String> parts = new List<String>();
    for (Integer i = 1; i <= rows; i++) {
        String p = rPfx + gridPfx + i + '_';
        Decimal q = decVal(m, p + 'qty', 0);
        if (q <= 0) continue;
        String opt = strVal(m, p + 'option', '');
        // seg5 ACCESSORY grid only - new wording. Every other caller keeps the old one.
        if (seg5 == true && gridPfx == 'fm_ac_') {
            // No quantity in the seg5 wording at all - his call, 21st Aug 2026.
            // The row is still skipped when qty is 0 (the guard above), so a blank
            // row cannot print; only the number stops being shown.
            parts.add(labels[i - 1] + fmAcSpec(m, p, i));
        } else {
            parts.add(labels[i - 1]
                + (String.isNotBlank(opt) ? ' (' + opt + ')' : ''));
        }
        
       System.debug('**2379 ' + parts + ' ' + p + ' ' + q + ' ' + opt);

    }
    if (parts.isEmpty() || grand <= 0) return sl;   // absent r{n}_ keys (legacy quote) -> no-op
    String mastNo = rPfx.removeStart('r').removeEnd('_');                                      
    lineItems.add(buildRow(String.valueOf(sl++),
        heading + ' (Mast ' + mastNo + ') - ' + String.join(parts, ', ') + '.',
        grand.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
    return sl;
}
    
    
    // ONE ROW for this mast's ACCESSORY + ADDITIONAL grids. Was two rows (1.3 and 1.4)
// built by two cmFlagRowGridLine calls. Rate is the sum of the two grand totals at the
// same quantity, so the money is identical to the rupee - only the presentation merges.
// Deepanjan (9th September 2026)
// ONE ROW per mast: ACCESSORIES, ADDITIONAL ITEM and (on the first populated row)
// SUPPLEMENTARY ITEMS, as three labelled blocks separated by a blank line.
// Was three separate line items. Deepanjan (9th September 2026)
// ONE ROW per mast: ACCESSORIES, ADDITIONAL ITEM and (on the first populated row)
// SUPPLEMENTARY ITEMS, as three labelled blocks separated by a blank line.
// Was three separate line items. Deepanjan (9th September 2026)
private Integer cmFlagRowGridMerged(Map<String,Object> m, String rPfx, Decimal qty,
                                    Decimal gstPct, String freight, Integer sl,
                                    Boolean seg5, Boolean isFirstRow) {
    if (qty == null || qty <= 0) qty = 1;

    Decimal acGrand = decVal(m, rPfx + 'fm_ac_grand_total', 0);
    Decimal adGrand = decVal(m, rPfx + 'fm_ad_grand_total', 0);

    List<String> acParts = new List<String>();
    for (Integer i = 1; i <= FM_AC_ROWS; i++) {
        String p = rPfx + 'fm_ac_' + i + '_';
        Decimal q = decVal(m, p + 'qty', 0);
        if (q <= 0) continue;
        String opt = strVal(m, p + 'option', '');
        acParts.add(seg5 == true
            ? FM_AC_LABELS[i - 1] + fmAcSpec(m, p, i)
            : FM_AC_LABELS[i - 1] + (String.isNotBlank(opt) ? ' (' + opt + ')' : ''));
    }

    List<String> adParts = new List<String>();
    for (Integer i = 1; i <= FM_ADD_ROWS; i++) {
        String p = rPfx + 'fm_ad_' + i + '_';
        if (decVal(m, p + 'qty', 0) <= 0) continue;
        adParts.add(FM_AD_LABELS[i - 1]);
    }

    // SUPPLEMENTARY - fm_sc_* is UNPREFIXED, one set per quote, so it prints on the
    // first populated mast row only. Its amount is divided by this row's quantity
    // because buildRow multiplies the rate back out: (scAmt / qty) x qty == scAmt,
    // the same once-per-quote charge its own line used to carry at qty 1.
    Decimal scAmt  = 0;
    String  scDesc = '';
    if (isFirstRow == true) {
        scDesc = strVal(m, 'fm_sc_description', '');
        if (String.isNotBlank(scDesc)) scAmt = decVal(m, 'fm_sc_amount', 0);
    }

    Decimal rate = (acGrand > 0 ? acGrand : 0)
                 + (adGrand > 0 ? adGrand : 0)
                 + (scAmt   > 0 ? scAmt / qty : 0);

    List<String> blocks = new List<String>();
    if (!acParts.isEmpty()) {
        blocks.add('Supply of FLAG MAST ACCESSORIES - ' + String.join(acParts, ', '));
    }
    if (!adParts.isEmpty()) {
        blocks.add(' Supply of FLAG MAST ADDITIONAL ITEM - ' + String.join(adParts, ', '));
    }
    if (String.isNotBlank(scDesc)) {
        Decimal scQty = decVal(m, 'fm_sc_quantity', 0);
        blocks.add(' Supply of FLAG MAST SUPPLEMENTARY ITEMS: ' + scDesc
                   + (scQty > 0 ? ' - ' + cmNum(scQty) + ' Nos.' : ''));
    }

    if (blocks.isEmpty() || rate <= 0) return sl;   // legacy quote -> no row, as before

    lineItems.add(buildRow(String.valueOf(sl++),
                  String.join(blocks, '\u0001BR\u0001') + '.',
                  rate.setScale(2, RoundingMode.HALF_UP), gstPct, qty, freight));
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
 
// ── Segment slot resolution + primitives (same rules as the other classes)
private String cmStadiumList(Map<String,Object> m, String p, Integer n, String attr, String sep) {
    // The list stopped at mid4, so a 7-segment Stadium printed only 5 lengths and 5
    // thicknesses (top, mid2, mid3, mid4, bottom) - mid5..mid14 were silently dropped.
    // The estimator offers 6..15 segments, i.e. top + middles 2..n-1 + bottom, so
    // mid{k} belongs on the list whenever n >= k + 1. Deepanjan (21st Aug 2026)
    List<String> keys = new List<String>();
    keys.add(p + 'top_segment_' + attr);
    if (n >= 3) keys.add(p + 'middle_segment_' + attr);          // middle_segment_ IS mid2
    for (Integer k = 3; k <= 14; k++) {
        if (n >= k + 1) keys.add(p + 'mid' + k + '_' + attr);
    }
    keys.add(p + 'bottom_' + attr);
    return cmJoin(m, keys, sep);
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
 
private Decimal cmAddTotal(Map<String,Object> m, String rPfx, String valueType) {
    // Additional Details is now a per-mast grid row. Reetabrata (15th July 2026)
    Decimal total = 0;
    if (strVal(m, rPfx + 'fm_add_value_type', '').equalsIgnoreCase(valueType)) {
        total += decVal(m, rPfx + 'fm_add_value', 0);
    }
    return total;
}
 
private String cmAddNotes(Map<String,Object> m, String rPfx) {
    List<String> notes = new List<String>();
    String d = strVal(m, rPfx + 'fm_add_desc', '');
    if (String.isNotBlank(d)) notes.add(d + '.');
    return notes.isEmpty() ? '' : ' ' + String.join(notes, ' ');
}
 
private Boolean cmBool(Map<String,Object> m, String key) {
    if (m == null || !m.containsKey(key) || m.get(key) == null) return false;
    Object v = m.get(key);
    if (v instanceof Boolean) return (Boolean) v;
    String s = String.valueOf(v).trim();
    return s.equalsIgnoreCase('true') || s == '1';
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
 
    if (rowBool(jsonData, p, 'lm_pu_paint')) {
        clause += ' PU Paint to be provided';
        String note = rowStr(jsonData, p, 'lm_pu_paint_note', '');
        if (String.isNotBlank(note)) clause += ' (' + note.trim() + ')';
        clause += '.';
    }
    return clause;
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM LIGHTNING MAST - SPECIAL ADDITIONS CLAUSE
//
// SINGLE source of truth for the Special Additions sentence. HMScopeCombinedController and
// HighMastWeightCalcController call THIS method - they do not carry their own copy - so the
// Single Scope, the Combined Scope and the Weight sheet cannot drift apart the way the
// amount columns once did.
//
// DATA SHAPE: for Custom Lightning Mast the Special Additions accordion is an
// accordion-repeater (cloneFrom "lm_special_additions", replaceTarget "lm_"), so each mast
// row saves its own r{n}_lm_<item>, r{n}_lm_<item>_note and r{n}_lm_<item>_value. The
// unprefixed key is read as a fallback so quotes saved while the section was still one
// global set keep printing.
//
// PRINT RULE: an item is printed ONLY when its checkbox is ticked AND its NOTE is non-blank.
// A missing key, a null, the literal strings "null" / "undefined" and a whitespace-only note
// all append nothing. VALUE (KG) is bracketed only when it is greater than zero, so there is
// never an empty bracket, a stray comma or a blank line.
//
// WEIGHT: nothing is added to any weight or amount here. The VALUE (KG) figures are already
// inside lm_{n}_segment_weight via the blueprint formula, so this method is text-only and
// cannot introduce a Single-vs-Combined amount discrepancy.
//
// Returns '' whenever nothing qualifies, which leaves the caller's description string
// byte-identical to what it was before this method existed.
// Faizan (24th July 2026)
// ═══════════════════════════════════════════════════════════════════════════
private static final List<String> SA_ITEM_KEYS = new List<String>{
    'lm_two_tier_ring',
    'lm_solar_mast',
    'lm_raising_lowering_stadium',
    'lm_counter_load',
    'lm_add_pu_paint',
    'lm_self_balancing'
};
private static final List<String> SA_ITEM_LABELS = new List<String>{
    'TWO TIER RING',
    'SOLAR MAST',
    'RAISING & LOWERING STADIUM TYPE',
    'COUNTER LOAD',
    'PU PAINT',
    'SELF BALANCING'
};

public static String buildSpecialAdditionsClause(Map<String,Object> src, String rowPrefix) {
    if (src == null || src.isEmpty()) return '';
    String p = (rowPrefix == null) ? '' : rowPrefix.trim();
    Boolean hasPfx = String.isNotBlank(p);

    List<String> parts = new List<String>();
    for (Integer i = 0; i < SA_ITEM_KEYS.size(); i++) {
        String base = SA_ITEM_KEYS[i];

        // Row-prefixed key wins; unprefixed is the legacy / global fallback.
        Boolean ticked = hasPfx ? saBool(src, p + base) : false;
        if (!ticked) ticked = saBool(src, base);
        if (!ticked) continue;

        String note = hasPfx ? saStr(src, p + base + '_note') : '';
        if (String.isBlank(note)) note = saStr(src, base + '_note');
        if (String.isBlank(note)) continue;   // no note -> nothing to append for this item

        Decimal kg = hasPfx ? saDec(src, p + base + '_value') : 0;
        if (kg <= 0) kg = saDec(src, base + '_value');

        parts.add(SA_ITEM_LABELS[i] + ' - ' + note);
    }
    return parts.isEmpty() ? '' : ' SPECIAL ADDITIONS: ' + String.join(parts, ', ') + '.';
}

// Text getter that also rejects the literal strings the browser can serialise into the
// quote JSON when a field is cleared, so "null" / "undefined" can never reach the PDF.
private static String saStr(Map<String,Object> src, String key) {
    if (src == null || !src.containsKey(key) || src.get(key) == null) return '';
    String v = String.valueOf(src.get(key)).trim();
    if (String.isBlank(v)) return '';
    if (v.equalsIgnoreCase('null') || v.equalsIgnoreCase('undefined')) return '';
    return v;
}

private static Boolean saBool(Map<String,Object> src, String key) {
    if (src == null || !src.containsKey(key) || src.get(key) == null) return false;
    Object v = src.get(key);
    if (v instanceof Boolean) return (Boolean) v;
    String s = String.valueOf(v).trim();
    return s.equalsIgnoreCase('true') || s == '1';
}

private static Decimal saDec(Map<String,Object> src, String key) {
    String s = saStr(src, key);
    if (String.isBlank(s)) return 0;
    try { return Decimal.valueOf(s); } catch (Exception ex) { return 0; }
}

// Mirrors cmNum() - whole numbers print without a decimal tail.
private static String saNum(Decimal d) {
    if (d == null) return '0';
    if (d == d.setScale(2, RoundingMode.FLOOR)) return String.valueOf(d.longValue());
    return String.valueOf(d.setScale(2, RoundingMode.HALF_UP));
}
 
private String cmNum(Decimal d) {
    if (d == null) return '0';
    if (d == d.setScale(2, RoundingMode.FLOOR)) return String.valueOf(d.longValue());
    return String.valueOf(d.setScale(2, RoundingMode.HALF_UP));
}
    // ═══════════════════════════════════════════════════════════════════════
// MAN RIDING LIFT — KIT line resolution (additive; reuses buildAccessoriesDesc,
// accSpecRaw, specOrBlank, codeOrBlank — same helpers High Mast already uses)
// ═══════════════════════════════════════════════════════════════════════
private Integer findKitLineForHeight(Decimal mastHt) {
    for (Integer k = 1; k <= 10; k++) {
        String kitMastHtStr = strVal(jsonData, 'kit_line_' + k + '_lm_mast_height', '');
        if (String.isBlank(kitMastHtStr)) continue;
        Decimal kitHt = 0;
        try { kitHt = Decimal.valueOf(kitMastHtStr); } catch (Exception ex) {}
        if (kitHt == mastHt || kitHt == mastHt * 10) return k;
    }
    return 0;   // no matching KIT line found
}
 
// Builds the "Supply of ... MTR STADIUM MAST ACCESSORIES PART" line item,
// only when a matching kit_line_N exists for this row's mast height.
private void addMrlKitAccessoryLine(Decimal mastHt, Decimal qty, Integer segCount,
                                     Decimal gstPct, String freight, List<Integer> slHolder) {
    Integer kitLineNum = findKitLineForHeight(mastHt);
    if (kitLineNum == 0) return;   // no KIT data -> do nothing, unchanged behavior
 
    String kit = 'kit_line_' + kitLineNum + '_';
 
    Integer kitSeg = (Integer) decVal(jsonData, kit + 'no_of_segment_select', segCount).intValue();
    if (kitSeg == 0) kitSeg = segCount;
 
    Decimal accUnitPrice = 0;
    if (kitSeg <= 1) {
        accUnitPrice = decVal(jsonData, kit + 'lm_kit_unit_price', 0);
    } else if (kitSeg == 2) {
        accUnitPrice = decVal(jsonData, kit + 'lm_2_kit_unit_price', 0);
    } else {
        accUnitPrice = decVal(jsonData, kit + 'lm_3_kit_unit_price', 0);
    }
    if (accUnitPrice <= 0) return;   // nothing priced -> skip, same convention as High Mast
 
    String cableSpec = specOrBlank(accSpecRaw(jsonData, kit, 'hm_cable_type', 'lm_cable_type', 'T=2.5 SQmm 5Core'));
    String cableSets = codeOrBlank(accSpecRaw(jsonData, kit, 'hm_no_of_cable', 'lm_no_of_cable', '1=Single cable'));
    String winchSpec = specOrBlank(accSpecRaw(jsonData, kit, 'hm_type_of_winch', 'lm_type_of_winch', 'E=350 kg'))
                          .replace(' kg', 'Kg').replace(' KG', 'Kg');
    String toolSpec  = specOrBlank(accSpecRaw(jsonData, kit, 'hm_type_of_power_tool', 'lm_type_of_power_tool', 'G=Motor,3PH'));
    String ropeSpec  = specOrBlank(accSpecRaw(jsonData, kit, 'hm_wire_rope', 'lm_type_of_wire_rope', '5=5mm dia'));
                                         
 	// check kit optional electric details
 	Boolean hasOptElec       = hasOptionalElectricalItems(jsonData, kit, '');
    String  aolVal           = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_type_of_aol') : '';
    String  controlSwitchVal = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_no_of_aviation_light') : '';
    String  feederPillarVal  = hasOptElec ? optElecVal(jsonData, kit, '', 'lm_feeder_piller_control') : '';
                                         
    //String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec)
    //                     .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');
    //call overload method
    String descAcc = buildAccessoriesDesc(true, mastHt, winchSpec, toolSpec, ropeSpec, cableSets, cableSpec,
                                          hasOptElec, aolVal, controlSwitchVal, feederPillarVal)
                         .replace('LIGHTING MAST ACCESSORIES', 'STADIUM MAST ACCESSORIES');
 
    Integer sl = slHolder[0];
    lineItems.add(buildRow(String.valueOf(sl++), descAcc, accUnitPrice, gstPct, qty, freight));
    slHolder[0] = sl;
}
    
    private static final Integer FM_AC_ROWS  = 8;   // fm_ac_{n}_* fixed rows
private static final Integer FM_ADD_ROWS = 5;   // fm_ad_{n}_* fixed rows
 
// ═══════════════════════════════════════════════════════════════════════
// FLAG MAST ACCESSORY / ADDITIONAL grids - real blueprint shape.
// Fixed-row catalogues: fm_ac_{n}_option/_qty/_rate/_amount (7 rows) and
// fm_ad_{n}_qty/_rate/_amount (5 rows). Item names are metadata header
// fields (fm_ac_{n}_hdr / fm_ad_{n}_desc), so they are not saved on the
// quote and are carried here. The old r{n}_fm_ac_item_name / r{n}_fm_add_*
// keys never existed and never resolved.
//
// PRICING: _amount is a formula = qty * rate * 1.18 (GST-INCLUSIVE).
// buildRow() adds GST itself, so the pre-GST rate is passed through and the
// realization uplift (fm_ac_realization / fm_ad_realization) is applied to
// it - mirroring _grand_total = SUM(_amount) * (1 + realization/100).
// Single Scope keeps ONE LINE PER ROW. Deepanjan (16th July 2026)
// ═══════════════════════════════════════════════════════════════════════
private static final List<String> FM_AC_LABELS = new List<String>{
    'Wire Rope', 'Wire rope', 'Winch Gear', 'Motor',
    'Snap hook', 'SS Accessories & Flag Clamps', 'Counter weight', 'Control Panel' };
 

// ── FLAG MAST ACCESSORY spec text - Segment Above 5 ONLY. Deepanjan (21st Aug 2026)
//    "Wire Rope (8) - 100 Nos"  ->  "Wire Rope 8 mm - 100"
//    Brackets gone, the value carries its unit (mm / KG / HP, plus the SGDD/DGDD
//    drum on Winch Gear), trailing "Nos" dropped. The unit is read from the
//    estimator's own fm_ac_{n}_unit box and falls back to the fixed row unit, so a
//    quote saved before that box existed still prints right. Reached only through
//    the seg5 flag on the three printers below - the single-segment Customized Mast
//    Flag Mast passes false and its wording is byte-identical to before.
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

// PU PAINT for Segment Above 5 Flag Mast - no longer its own line item.
// Deepanjan (21st Aug 2026). Lighting Mast has always printed PU Paint as a
// clause inside the mast description (micronPaintClause) and never priced it in
// the offer - the charge reaches the quote through the estimator's own
// isUnitPrice line item on lm_pu_paint_unit_price. Flag Mast seg5 uses the same
// lm_pu_paint* keys, so it now behaves identically: same wording, same row-key-
// first / bare-key fallback, and no separate offer line.
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

private static final List<String> FM_AD_LABELS = new List<String>{
    '32A STD FEEDER PILLAR', 'GI STAND',
    'CONTROL PANEL FOR OPERATE ONLY MOTOR OPERATE',
    'SMALL LIGHT FEEDER PILLAR WITH STAND', 'Decorative Dome' };
 
private Integer cmFlagAccessoryItemLines(Map<String,Object> m, Decimal gstPct,
                                         String freight, Integer sl, Boolean seg5) {
    Decimal rz = 1 + (decVal(m, 'fm_ac_realization', 0) / 100);
 
    for (Integer i = 1; i <= FM_AC_ROWS; i++) {
        String p = 'fm_ac_' + i + '_';
        
        Decimal q = decVal(m, p + 'qty', 0);
        if (q <= 0) continue;
        Decimal r = decVal(m, p + 'amount', 0) * rz;
 
        String label = FM_AC_LABELS[i - 1];
        String opt   = strVal(m, p + 'option', '');
                
        String spec = (seg5 == true)
            ? fmAcSpec(m, p, i)
            : (String.isNotBlank(opt) ? ' (' + opt + ')' : '');
        lineItems.add(buildRow(String.valueOf(sl++),
            'Supply of FLAG MAST ACCESSORY - ' + label + spec + '.',
            r.setScale(2, RoundingMode.HALF_UP), gstPct, q, freight));
    }                             
    return sl;
}
 
private Integer cmFlagAdditionalItemLines(Map<String,Object> m, Decimal gstPct,
                                          String freight, Integer sl) {
    Decimal rz = 1 + (decVal(m, 'fm_ad_realization', 0) / 100);
 
    for (Integer i = 1; i <= FM_ADD_ROWS; i++) {
        String p = 'fm_ad_' + i + '_';
        Decimal q = decVal(m, p + 'qty', 0);
        if (q <= 0) continue;
        Decimal r = decVal(m, p + 'amount', 0) * rz;
        lineItems.add(buildRow(String.valueOf(sl++),
            'Supply of FLAG MAST ADDITIONAL ITEM - ' + FM_AD_LABELS[i - 1] + '.',
            r.setScale(2, RoundingMode.HALF_UP), gstPct, q, freight));
    }
    return sl;
}
 
// PU PAINT - own line in Single Scope. fm_pu_paint_value is the "Price Value"
// (pu_paint_unit_price is isUnitPrice with formula fm_pu_paint_value), so it is a
// rupee rate, not a weight. Unprefixed = one per quote. Reetabrata (16th July 2026)
private Integer cmFlagPuPaintLine(Map<String,Object> m, Decimal gstPct, String freight, Integer sl) {
    if (!cmBool(m, 'fm_pu_paint')) return sl;
    Decimal puVal = decVal(m, 'fm_pu_paint_value', 0);
    if (puVal <= 0) return sl;
 
    String note = strVal(m, 'fm_pu_paint_note', '');
    lineItems.add(buildRow(String.valueOf(sl++),
        'Supply of FLAG MAST PU PAINT' + (String.isNotBlank(note) ? ' - ' + note : '') + '.',
        puVal.setScale(2, RoundingMode.HALF_UP), gstPct, 1, freight));
    return sl;
}
 
// ═══════════════════════════════════════════════════════════════════════
// SEGMENT ABOVE 5 - FLAG MAST (Deepanjan, 22nd July 2026)
//
// Its estimator is the LM engine: each mast row saves r{n}_lm_* keys
// (manual segment weights, LM base plate / foundation naming) plus the
// flag annexure grids (unprefixed fm_ac_* / fm_ad_*) and the LM-keyed
// PU Paint section (lm_pu_paint*). cmFlagLines() reads r{n}_fm_* keys,
// so for these quotes it found no rows and emitted nothing - that was
// the "items not showing in the offer PDF" bug. The wording below is
// the approved Flag Mast offer wording; only the keys are LM-shaped.
// Reached only when isSeg5FlagMast is true, so the single-segment
// Customized Flag Mast path and every other mast type are untouched.
// ═══════════════════════════════════════════════════════════════════════
private Integer seg5FlagRowCount() {
    Integer rows = 0;
    for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
        String p = 'r' + rowIdx + '_';
        if (decVal(jsonData, p + 'lm_height_of_mast', 0) == 0) continue;
        if (decVal(jsonData, p + 'lm_no_of_segment', 0) <= 0) continue;
        rows++;
    }
    return rows;
}
 
private Integer cmSeg5FlagLines(Decimal gstPct, String freight, Integer sl) {
    Map<String,Object> m = jsonData;
    Boolean puQuoteLevelDone = false;   // quote-level PU Paint prints on one row only
     
    for (Integer rowIdx = 1; rowIdx <= 10; rowIdx++) {
        String p = 'r' + rowIdx + '_';
 
        Decimal mastHeight = decVal(m, p + 'lm_height_of_mast', 0);
        if (mastHeight == 0) continue;
        Decimal segCount = decVal(m, p + 'lm_no_of_segment', 1);
        if (segCount <= 0) continue;
        // Same rule as cmFlagLines: one populated r{n}_ row = one line item.
        // Deepanjan (19th Aug 2026)
        startGroup();
        //get quantity
        Decimal rowQty = decVal(m, p + 'lm_quantity', 1);
        if (rowQty <= 0) rowQty = 1;
 
        // TOP/BOTTOM DIA and the per-segment lists reuse the LM helpers - the
        // row shape is exactly the Lighting Mast shape.
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

        // Extra Micron is a finish spec - one more sentence of the description.
        // PU Paint IS folded into the rate now (just above); the sentence below is
        // unchanged. Deepanjan (4th September 2026)
        String micron = rowBool(m, p, 'lm_is_extra_micron')
            ? rowStr(m, p, 'lm_extra_micron', '').trim() : '';
 
        String puClause = seg5FlagPuClause(m, p, !puQuoteLevelDone);
        if (String.isNotBlank(puClause) && !cmBool(m, p + 'lm_pu_paint')) puQuoteLevelDone = true;

        String descText =
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
        // rate again would double-charge. This is the same sentence cmStadiumLines has
        // always printed for the Stadium recipe (its "siHas && !siSep" branch), which is
        // why Stadium never showed this bug.
        // No-op for any recipe without lm_si_* keys, and for a ticked item (that one still
        // prints as its own line below, unchanged).
        if (siHasRow(m, p) && !showSpecialItemSeparatelyRow(m, p)) {
            descText += ' SPECIAL ITEM: ' + specialItemDescriptionRow(m, p) + '.';
        }

        String suffix = getWindSpeedSuffix();
        if (String.isNotBlank(suffix)) {
            descText = descText + ' ' + suffix;
        }
 
        lineItems.add(buildRow(String.valueOf(sl++), descText, mastUnitPrice, gstPct, rowQty, freight));
 
        // FOUNDATION BOLTS - LM key names on this recipe.
        String  fbDia    = strVal(m, p + 'lm_fdn_bolt_dia',    '');
        Decimal fbLen    = decVal(m, p + 'lm_fdn_bolt_length',  0);
        Decimal fbNo     = decVal(m, p + 'lm_fdn_no_of_bolt',   0);
        Decimal fndPrice = decVal(m, p + 'lm_fdn_unit_price',   0)
                               .setScale(2, RoundingMode.HALF_UP);
        // "Without Foundation": the out-of-scope sentence at rate 0, keeping the
        // typed dia / length / nos. (they are NOT zeroed before the text is built
        // any more). Deepanjan (21st Aug 2026)
        if (fdnSuppressed(m, p)) {
            lineItems.add(buildRow(String.valueOf(sl++),
                fdnNotInScopeDesc(fbDia, fbLen, fbNo, pcd),
                0, gstPct, rowQty, freight));
        } else if (fndPrice > 0 || fbNo > 0) {
            lineItems.add(buildRow(String.valueOf(sl++),
                'Supply of FOUNDATION BOLTS - M' + (String.isBlank(fbDia) ? '0' : fbDia)
                + ' x ' + cmNum(fbLen) +'mm'
                + ' (' + cmNum(fbNo) + ' Nos.) with Template and Anchor Plate.',
                fndPrice, gstPct, rowQty, freight));
        }
        
        Boolean scDone = false;   // SUPPLEMENTARY prints on the first populated row only    
        sl = cmFlagRowGridMerged(m, p, rowQty, gstPct, freight, sl, true, !scDone);
        scDone = true;
        
        // PER-ROW SPECIAL ITEM - Deepanjan (19th Aug 2026)
        // The Segment Above 5 estimator repeats Special Items per mast row for Flag
        // Mast exactly as it does for Lighting Mast and LCLM, saving r{n}_lm_si_*.
        // This builder never read them, so with 'Show separate in offer' ON the item
        // vanished from the offer altogether: si_weight_add goes to 0, so it is not
        // in the mast rate either, and no line was printed for it.
        //
        // Same three helpers buildHighMastLineItems() uses, so the rule, the wording
        // and the rate are identical: VALUE kg x TOTAL PRICE (/KG) for TYPE Weight,
        // the typed amount as-is for TYPE Price. Lands inside THIS row's line item.
        //
        // Reached only from cmSeg5FlagLines, which runs for Segment Above 5 Flag Mast
        // alone, and it is a no-op when the keys are absent - nothing else can see it.
        if (showSpecialItemSeparatelyRow(m, p)) {
            lineItems.add(buildRow(String.valueOf(sl++),
                          specialItemDescriptionRow(m, p),
                          // QTY: this row's own quantity, not 1. Deepanjan (4th September 2026)
                          specialItemUnitRateRow(m, p), gstPct, rowQty, freight));
        }
    }
 
    // Once-per-quote sections. The accessory / additional grids save the SAME
    // unprefixed fm_ac_* / fm_ad_* keys as the single-segment Flag Mast, so the
    // existing builders are reused verbatim. PU Paint uses the LM keys here.
    // seg5FlagPuPaintLine() removed - PU Paint is a clause on the mast description
    // now, not a line item of its own. Deepanjan (21st Aug 2026)
    sl = cmFlagAccessoryItemLines(jsonData, gstPct, freight, sl, true);
    sl = cmFlagAdditionalItemLines(jsonData, gstPct, freight, sl);
    return sl;
}
 
    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key) || jsonData.get(key) == null
                || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }
 
    private Decimal decVal(Map<String, Object> m, String key, Decimal def) {
        if (!m.containsKey(key) || m.get(key) == null) return def;
        try {
            String s = String.valueOf(m.get(key)).trim();
            if (String.isBlank(s)) return def;
            return Decimal.valueOf(s);
        } catch (Exception e) { return def; }
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
    // True when the FOUNDATION BOLT DIAMETER picklist is set to N.R. for this pole /
    // section. Reads exactly the same two keys the description builder reads, so a
    // group boundary can never disagree with the sentence. Deepanjan (24th Aug 2026)
    // Which (section, item) sets already carry a Foundation row in the saved list.
    // Deepanjan (24th Aug 2026)
    private Set<String> fdnSetsPresent(List<Object> flat) {
        Set<String> out = new Set<String>();
        if (flat == null) return out;
        for (Object o : flat) {
            // initialised explicitly: Apex is unforgiving about a local read on a path
            // where the only assignment sits inside a try. Deepanjan (24th Aug 2026)
            Map<String, Object> line = null;
            try { line = (Map<String, Object>) o; } catch (Exception e) { continue; }
            if (line == null) continue;
            String nm = strVal(line, 'name', '');
            if (nm.containsIgnoreCase('Foundation')) {
                out.add(String.valueOf(sectionIndexOf(nm)) + '|' + String.valueOf(itemIndexOf(nm)));
            }
        }
        return out;
    }

    // Adds the red "Not in our Scope" foundation row for a pole whose FOUNDATION BOLT
    // DIAMETER is N.R. and that has no Foundation row of its own. Rate 0, so no total
    // moves. Returns the next Sl counter - unchanged when nothing was added.
    // Deepanjan (24th Aug 2026)
    // Which item indices already carry a Foundation row in the saved list (Mid Hinge has
    // no section suffix in its names, so this keys on the item index alone).
    // Deepanjan (24th Aug 2026)
    private Set<String> fdnItemsPresent(List<Object> flat) {
        Set<String> out = new Set<String>();
        if (flat == null) return out;
        for (Object o : flat) {
            // initialised explicitly: Apex is unforgiving about a local read on a path
            // where the only assignment sits inside a try. Deepanjan (24th Aug 2026)
            Map<String, Object> line = null;
            try { line = (Map<String, Object>) o; } catch (Exception e) { continue; }
            if (line == null) continue;
            String nm = strVal(line, 'name', '');
            if (nm.containsIgnoreCase('Foundation')) out.add(String.valueOf(itemIndexOf(nm)));
        }
        return out;
    }

    // Mid Hinge twin of addFdnNotInScopeRow(). Same rule, different key shape: every Mid
    // Hinge field lives under c{n}_mhp_. Rate 0, so no total moves. Returns the next Sl
    // counter - unchanged when nothing was added. Deepanjan (24th Aug 2026)
    private Integer addFdnNotInScopeRowMhp(String itemName, Set<String> fdnAlreadyThere,
                                           Decimal poleQty, Decimal gstPct, String freight,
                                           Integer slCounter) {
        Integer ix = itemIndexOf(itemName);
        if (fdnAlreadyThere.contains(String.valueOf(ix))) return slCounter;

        String cp = 'c' + ix + '_mhp_';
        if (!strVal(jsonData, cp + 'foundation_bolt_diameter', '').equalsIgnoreCase('N.R.')) return slCounter;

        String  nrDia = strVal(jsonData, cp + 'nr_fb_diameter', '');
        Decimal fbLen = decVal(jsonData, cp + 'foundation_bolt_length', 0);
        Decimal fbQty = decVal(jsonData, cp + 'bolt_quantity', decVal(jsonData, cp + 'fdn_quantity', 0));
        Decimal fbPcd = decVal(jsonData, cp + 'pcd', 0);

        // FOUNDATION BOLT DIAMETER defaults to "N.R.", so N.R. alone is not proof the user
        // meant anything by it - the row is only added when a foundation figure was entered.
        if (String.isBlank(nrDia) && fbLen <= 0 && fbQty <= 0 && fbPcd <= 0) return slCounter;

        Decimal rowQty = (poleQty == null || poleQty <= 0) ? 1 : poleQty;
        lineItems.add(buildRow(String.valueOf(slCounter++),
                      fdnNotInScopeDesc(nrDia, fbLen, fbQty, fbPcd),
                      0, gstPct, rowQty, freight));
        return slCounter;
    }

    // ── BRACKET WORDING ──────────────────────────────────────────────────────
    // BRACKET TYPE = Customized -> print the CUSTOMIZED DESCRIPTION text instead of the
    // word "Customized" (e.g. "Channel Bracket"). Blank description keeps "Customized",
    // exactly as today. Every other type is returned untouched.
    // Deepanjan (24th Aug 2026)
    private String bracketLabel(String bracketType, String prefix, String prefixCus) {
        if (!'Customized'.equalsIgnoreCase(bracketType)) return bracketType;
        // NOTE: the local is custDesc, not desc - 'desc' is an Apex reserved word (SOQL
        // ORDER BY ... DESC) and will not compile. Deepanjan (24th Aug 2026)
        String custDesc = strVal(jsonData, prefix + 'customized_description',
                          strVal(jsonData, prefixCus + 'customized_description', ''));
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

    private Integer addFdnNotInScopeRow(String itemName, Set<String> fdnAlreadyThere,
                                        Decimal poleQty, Decimal gstPct, String freight,
                                        Integer slCounter) {
        Integer ix  = itemIndexOf(itemName);
        Integer sec = sectionIndexOf(itemName);
        if (fdnAlreadyThere.contains(String.valueOf(sec) + '|' + String.valueOf(ix))) return slCounter;

        String prefix    = 'c' + ix + '_s' + sec + '_';
        String prefixCus = 'c' + ix + '_s' + sec + '_cus_op_';
        if (!fdnIsNotInScope(prefix, prefixCus)) return slCounter;

        String fbDiaRaw = strVal(jsonData, prefix + 'nr_fb_diameter',
                          strVal(jsonData, prefixCus + 'nr_fb_diameter', ''));
        Decimal fbLen   = decVal(jsonData, prefix + 'foundation_bolt_length',
                          decVal(jsonData, prefixCus + 'foundation_bolt_length', 0));
        Decimal fbQty   = fdnNisQty(prefix, prefixCus, 0);
        Decimal fbPcd   = decVal(jsonData, prefix + 'pcd',
                          decVal(jsonData, prefixCus + 'pcd', 0));

        Decimal rowQty = (poleQty == null || poleQty <= 0) ? 1 : poleQty;
        lineItems.add(buildRow(String.valueOf(slCounter++),
                      fdnNotInScopeDesc(fbDiaRaw, fbLen, fbQty, fbPcd),
                      0, gstPct, rowQty, freight));
        return slCounter;
    }

    // Nos. for the out-of-scope sentence: BOLT QUANTITY first, then FOUNDATION
    // QUANTITY, then whatever the caller already resolved. Deepanjan (24th Aug 2026)
    private Decimal fdnNisQty(String prefix, String prefixCus, Decimal fallback) {
        Decimal q = decVal(jsonData, prefix + 'bolt_quantity',
                    decVal(jsonData, prefixCus + 'bolt_quantity',
                    decVal(jsonData, prefix + 'fdn_quantity',
                    decVal(jsonData, prefixCus + 'fdn_quantity', 0))));
        return q > 0 ? q : (fallback == null ? 0 : fallback);
    }

    private Boolean fdnIsNotInScope(String prefix, String prefixCus) {
        return strVal(jsonData, prefix + 'foundation_bolt_diameter',
               strVal(jsonData, prefixCus + 'foundation_bolt_diameter', '')).equalsIgnoreCase('N.R.');
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
    
    private Boolean boolVal(Map<String, Object> data, String key, Boolean defaultVal) {
        if (data == null || !data.containsKey(key) || data.get(key) == null) return defaultVal;
        Object v = data.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        String s = String.valueOf(v).trim();
        return s.equalsIgnoreCase('true') || s == '1';
    }
 
    private String afterEq(String raw, String fallback) {
        if (String.isBlank(raw)) return fallback;
        return raw.contains('=') ? raw.substringAfter('=').trim() : raw.trim();
    }
 
    /*private String buildAddress(Account a) {
        if (a == null) return '';
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.BillingStreet))     parts.add(a.BillingStreet);
        if (String.isNotBlank(a.BillingCity))       parts.add(a.BillingCity);
        if (String.isNotBlank(a.BillingState))      parts.add(a.BillingState);
        if (String.isNotBlank(a.BillingPostalCode)) parts.add(a.BillingPostalCode);
        return String.join(parts, ', ');
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
        String[] ones = new String[]{
            '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
            'Seventeen', 'Eighteen', 'Nineteen'
        };
        String[] tens = new String[]{
            '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
            'Sixty', 'Seventy', 'Eighty', 'Ninety'
        };
        String result = '';
        Long crore = num / 10000000;  num = Math.mod(num, 10000000);
        Long lakh  = num / 100000;    num = Math.mod(num, 100000);
        Long thou  = num / 1000;      num = Math.mod(num, 1000);
        Long hund  = num / 100;       num = Math.mod(num, 100);
        if (crore > 0) result += twoD(crore, ones, tens) + ' Crore ';
        if (lakh  > 0) result += twoD(lakh,  ones, tens) + ' Lakh ';
        if (thou  > 0) result += twoD(thou,  ones, tens) + ' Thousand ';
        if (hund  > 0) result += ones[(Integer) hund]    + ' Hundred ';
        if (num   > 0) result += twoD(num,   ones, tens) + ' ';
        return result.trim() + ' Only';
    }
 
   /* private String twoD(Long n, String[] ones, String[] tens) {
        if (n < 20) return ones[(Integer) n];
        return tens[(Integer)(n / 10)]
            + (Math.mod(n, 10) > 0 ? ' ' + ones[(Integer) Math.mod(n, 10)] : '');
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

    private String buildBearingPlateDesc(String bpType, Decimal bpSize, Decimal bpThk) {
        String sz = String.valueOf(bpSize.intValue());
        String th = String.valueOf(bpThk.intValue());
        if (bpType != null && bpType.equalsIgnoreCase('Circular'))
            return 'Bearing Plate- Dia ' + sz + ' x ' + th + ' mm';
        return 'Bearing Plate- ' + sz + ' x ' + sz + ' x ' + th + ' mm';
    }
    
     private String buildBasePlateDesc(String bpType, Decimal bpSize, Decimal bpThk) {
        String sz = String.valueOf(bpSize.intValue());
        String th = String.valueOf(bpThk.intValue());
        if (bpType != null && bpType.equalsIgnoreCase('Circular'))
            return 'Base Plate- Dia ' + sz + ' x ' + th + ' mm';
        return 'Base Plate- ' + sz + ' x ' + sz + ' x ' + th + ' mm';
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


    // ═══════════════════════════════════════════════════════════════════════
    // ANNEXURE - A LINE ITEM GROUPING HELPERS - Reetabrata (18th Aug 2026)
    // ═══════════════════════════════════════════════════════════════════════

    // Opens a new line item. Every buildRow() after this lands inside it.
    private void startGroup() {
        curGroup++;
        curPart  = 0;
        curPlain = false;
    }

    // Opens a group that carries a whole number and no SUB-TOTAL row
    // (Transportation Charges - the same rule the Combined scope uses).
    private void startPlainGroup() {
        curGroup++;
        curPart  = 0;
        curPlain = true;
        if (!SUBTOTAL_ON_FREIGHT_GROUP) plainGroups.add(curGroup);
    }

    // _Final_Apex_Lines / _Saved_Table_Rows are FLAT - the only thing that says
    // which product a row belongs to is the "(Item n)" already embedded in the
    // saved name, which the description builders in this class already parse.
    // A new n opens a new line item; a freight row opens a plain group.
    // ── FLAT SAVED LIST -> ONE SET PER POLE ──────────────────────────────────
    // _Final_Apex_Lines / _Saved_Table_Rows come back in the order the estimator
    // wrote them, which for Custom Lighting Pole is EVERY pole's segment first and
    // then every pole's bracket:
    //     Segment (Item 1), Segment (Item 2), Segment (Item 3),
    //     Bracket (Item 1), Bracket (Item 2), Bracket (Item 3)
    // markFlatGroup() opens a new line item whenever the (section, item) key
    // changes, so that order produced SIX groups - 1.1, 2.1, 3.1, 4.1, 5.1, 6.1 -
    // each with its own SUB-TOTAL row. It has to read as one set per pole:
    //     Item 1: its segment, then its bracket  -> 1.1, 1.2, one SUB-TOTAL
    //     Item 2: ...                            -> 2.1, ...
    // This ONLY regroups: rows are bucketed by (section, item), buckets come out in
    // first-appearance order, and the order INSIDE a bucket is left exactly as it
    // was saved - no row is re-sorted by kind, dropped or merged. Freight rows and
    // anything that is not a Map keep their own position by getting a bucket of
    // their own, so a payload that was already set-by-set comes back byte-identical
    // and every other department is untouched. If the rebuilt list ever came out a
    // different length the original is returned. Deepanjan (24th Aug 2026)
    private List<Object> orderFlatLinesByItem(List<Object> flat) {
        if (flat == null || flat.size() < 2) return flat;
        List<String>              keyOrder = new List<String>();
        Map<String, List<Object>> buckets  = new Map<String, List<Object>>();
        Integer loneSeq = 0;

        for (Object o : flat) {
            String key;
            Map<String, Object> line = null;
            try { line = (Map<String, Object>) o; } catch (Exception e) { line = null; }
            if (line == null) {
                key = 'X|' + String.valueOf(loneSeq++);          // keeps its place
            } else {
                String nm = strVal(line, 'name', '');
                key = isFreightLine(nm)
                        ? 'F|' + String.valueOf(loneSeq++)       // keeps its place
                        : String.valueOf(sectionIndexOf(nm)) + '|' + String.valueOf(itemIndexOf(nm));
            }
            if (!buckets.containsKey(key)) {
                buckets.put(key, new List<Object>());
                keyOrder.add(key);
            }
            buckets.get(key).add(o);
        }

        List<Object> ordered = new List<Object>();
        for (String k : keyOrder) ordered.addAll(buckets.get(k));
        return ordered.size() == flat.size() ? ordered : flat;   // never lose a row
    }

    private void markFlatGroup(String itemName) {
        if (isFreightLine(itemName)) {
            startPlainGroup();
            lastFlatItem    = -1;
            lastFlatSection = -1;
            return;
        }
        Integer ix = itemIndexOf(itemName);
        // Custom Lighting Pole saves BOTH pole designs under "(Item 1)" and tells
        // them apart only by the section suffix ("Segment - 1 ..." vs "- 2 ..."),
        // so item index alone kept all six rows in one group: 1.1 ... 1.6 with a
        // single SUB-TOTAL. The section index is now part of the key. Any payload
        // where the section never varies gets sec = 1 throughout and behaves
        // exactly as before. Deepanjan (20th Aug 2026)
        Integer sec = sectionIndexOf(itemName);
        if (curGroup == 0 || ix != lastFlatItem || sec != lastFlatSection) {
            startGroup();
            lastFlatItem    = ix;
            lastFlatSection = sec;
        }
    }

    // Same rule the description builders already use to pick the c{n}_s{sec}_
    // prefix (Pattern '-\\s*(\\d+)\\s*(?:Pole Details|\\(Item)'), so a group boundary
    // can never disagree with the description it produces. Names without that
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

    private Integer itemIndexOf(String itemName) {
        if (String.isBlank(itemName)) return 1;
        Matcher mIx = Pattern.compile('\\(Item\\s*(\\d+)\\)').matcher(itemName);
        if (mIx.find()) {
            try { return Integer.valueOf(mIx.group(1)); } catch (Exception ex) { return 1; }
        }
        return 1;
    }

    // Slices lineItems into line items WITHOUT reordering or dropping anything.
    // Rows that were never marked (groupNo 0) keep their original number and
    // get no SUB-TOTAL, so an unmarked path can never lose a row.
    private void buildLineGroups() {
        lineGroups = new List<LineGroupWrapper>();
        if (lineItems == null || lineItems.isEmpty()) return;

        Integer prevNo = null;
        LineGroupWrapper g = null;

        for (LineItemWrapper w : lineItems) {
            Integer gNo = (w.groupNo == null ? 0 : w.groupNo);
            if (g == null || gNo != prevNo) {
                g = new LineGroupWrapper();
                g.groupNo      = gNo;
                g.rows         = new List<LineItemWrapper>();
                g.showSubTotal = (gNo > 0 && !plainGroups.contains(gNo));
                lineGroups.add(g);
                prevNo = gNo;
            }
            g.rows.add(w);
        }

        // Renumber by appearance. A builder is free to open a group that then
        // emits nothing (a shared section whose keys are all empty, for example);
        // that group never reaches lineGroups, but it has already consumed a
        // number, which would make the printed Sl. No. jump - 1, 2, then 4. So the
        // number a row actually prints is decided here, once, from the groups that
        // really exist. Deepanjan (19th Aug 2026)
        Integer shown = 0;
        for (LineGroupWrapper grp : lineGroups) {
            if (grp.groupNo == null || grp.groupNo <= 0) continue;   // unmarked rows keep their own number
            Boolean plain = plainGroups.contains(grp.groupNo);
            shown++;
            grp.groupNo = shown;
            Integer part = 0;
            for (LineItemWrapper w : grp.rows) {
                part++;
                w.groupNo = shown;
                w.slNo    = plain ? String.valueOf(shown)
                                  : String.valueOf(shown) + '.' + String.valueOf(part);
            }
        }

        for (LineGroupWrapper grp : lineGroups) {
            fillGroupTotals(grp);
        }
    }

    // The SUB-TOTAL row spans Sl No. .. Qty, so the ONLY figure printed is the
    // Total Amount: this line item's total including GST, i.e. the plain sum of
    // the Total Amount cells above it. Adding the SUB-TOTALs therefore lands
    // exactly on the Total row. Deepanjan (18th Aug 2026)
    //
    // The other three are still filled, weighted the same way, in case those
    // columns are ever wanted back on the row - they stay consistent with each
    // other (Unit Rate + GST Amount = Unit Amount = Total Amount).
    private void fillGroupTotals(LineGroupWrapper g) {
        Decimal sumUR = 0, sumGST = 0, sumUnit = 0, sumTotal = 0;
        for (LineItemWrapper w : g.rows) {
            Decimal q = (w.qtyRaw == null ? 1 : w.qtyRaw);
            sumUR    += w.unitRateRaw.setScale(2, RoundingMode.HALF_UP) * q;
            sumGST   += w.gstAmountRaw.setScale(2, RoundingMode.HALF_UP)  * q;
            sumUnit  += w.unitAmountRaw.setScale(2, RoundingMode.HALF_UP) * q;
            sumTotal += w.totalAmountRaw.setScale(2, RoundingMode.HALF_UP);
        }
        g.subTotalUnitRate = formatINR(sumUR);
        g.subTotalGST      = formatINR(sumGST);
        g.subTotalUnit     = formatINR(sumUnit);
        g.subTotalAmount   = formatINR(sumTotal);
    }

    // One line item and its own SUB-TOTAL.
    public class LineGroupWrapper {
        public Integer groupNo                      { get; set; }
        public List<LineItemWrapper> rows           { get; set; }
        public Boolean showSubTotal                 { get; set; }
        public String  subTotalUnitRate             { get; set; }
        public String  subTotalGST                  { get; set; }
        public String  subTotalUnit                 { get; set; }
        public String  subTotalAmount               { get; set; }
    }

    public class LineItemWrapper {
        public String  slNo           { get; set; }
        // Which line item this row belongs to. Reetabrata (18th Aug 2026)
        public Integer groupNo        { get; set; }
        public String  description    { get; set; }
        public String  unitRate       { get; set; }
        public String  gstPct         { get; set; }
        public String  gstAmount      { get; set; }
        public String  freight        { get; set; }
        public String  unitAmount     { get; set; }
        public String  qty            { get; set; }
        // Unrounded qty, so the SUB-TOTAL row can weight each line correctly.
        // qty above is String.valueOf(qty.intValue()). Not used by the VF page.
        // Deepanjan (17th July 2026)
        public Decimal qtyRaw         { get; set; }
        public String  totalAmount    { get; set; }
        public Decimal unitRateRaw    { get; set; }
        public Decimal gstAmountRaw   { get; set; }
        public Decimal unitAmountRaw  { get; set; }
        public Decimal totalAmountRaw { get; set; }
    }
    
}