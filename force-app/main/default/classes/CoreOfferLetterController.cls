public with sharing class CoreOfferLetterController {

    // ── Quote record ──
    public Quote quoteRecord { get; set; }

    // ── Parsed from Quote_Value__c JSON ──
    public String  priceBasis             { get; set; }
    public String  incoterms              { get; set; }
    public String  subjectLine            { get; set; }
    public String  deliverySchedule       { get; set; }
    public String  deliveryScheduleUnit   { get; set; }   // NEW: e.g. "Days" / "Weeks"
    public String  paymentTerms           { get; set; }
    // Optional free-text the user can add under Point 4 - Payment Terms.
    // Blank = point 4 prints exactly as before. Deepanjan (25th July 2026)
    public String  paymentTermsNote       { get; set; }
    public String  pvBaseMonth            { get; set; }
    public String  pvBaseYear             { get; set; }
    public String  zincCoating            { get; set; }
    public Decimal warrantyStart          { get; set; }
    public Decimal warrantyEnd            { get; set; }
    public Decimal offerValidity          { get; set; }
    public Decimal discount               { get; set; }
    public Integer numberOfMaterials      { get; set; }
    public Integer numberOfSpecialMaterials { get; set; }   // NEW

    // NEW: Reference & enquiry date fields (were missing entirely)
    public String  yourRef                { get; set; }
    public String  enquiryDate            { get; set; }

    // NEW: F.O.R / transportation fields
    public String  forValue                  { get; set; }   // Per mt (Included Price) | Per mt (Excluded Price) | Lump sum (Included Price) | Lump sum (Excluded Price)
    public Decimal transportationChargesPerMt   { get; set; }
    public Decimal transportationChargesLumpsum { get; set; }
    public Decimal transitInsuranceCharges      { get; set; }
    
    // NEW: Loading Charges (separate from freight)
    public String  loadingCharges            { get; set; }   // same 4 option values
    public Decimal loadingChargesPerMt       { get; set; }
    public Decimal loadingChargesLumpsum     { get; set; }
    
    // NEW: convenience booleans for VF rendering (avoids string-matching in markup)
    public Boolean isFreightPerMtIncluded    { get; set; }
    public Boolean isFreightPerMtExcluded    { get; set; }
    public Boolean isFreightLumpsumIncluded  { get; set; }
    public Boolean isFreightLumpsumExcluded  { get; set; }
    public Boolean isLoadingPerMtIncluded    { get; set; }
    public Boolean isLoadingPerMtExcluded    { get; set; }
    public Boolean isLoadingLumpsumIncluded  { get; set; }
    public Boolean isLoadingLumpsumExcluded  { get; set; }

    // ── Loading-charge table integration (Deepanjan, 23rd July 2026) ──
    // showLoadingColumn: Per mt (Excluded) renders its own "Loading Charge"
    // column; when false the page omits the whole column (th + every td).
    public Boolean showLoadingColumn     { get; set; }
    // loadingIncludedNote: Per mt (Included) prints a bold note box under the table.
    public Boolean loadingIncludedNote   { get; set; }
    // Lump sum (Included) boxed figures - base, its 18% GST, and the incl-GST
    // value that joins the grand TOTAL.
    public Decimal lumpIncBase           { get; set; }
    public Decimal lumpIncGst            { get; set; }
    public Decimal lumpIncTotal          { get; set; }
    // Same treatment for FOR / freight (Deepanjan, 23rd July 2026)
    public Boolean showFreightColumn     { get; set; }
    public Boolean freightIncludedNote   { get; set; }
    public Decimal freightLumpIncBase    { get; set; }
    public Decimal freightLumpIncGst     { get; set; }
    public Decimal freightLumpIncTotal   { get; set; }
    // MATERIAL LIST table under Annexure-A: one row per selected sub-type
    // (type + subtype + qty + per-unit weight). Deepanjan (24th July 2026)
    public List<MaterialListRow> materialListRows { get; set; }
    public Boolean showMaterialList      { get; set; }
    // Dynamic tail of the "Total order value" note: names what this quote's
    // TOTAL actually includes (loading / freight / insurance, per selection)
    // and keeps only the truly-absent ones on the exclusive side.
    // Deepanjan (24th July 2026)
    public String  totalNoteSuffix       { get; set; }
    
    // PV Base Month commodity rates
    public Decimal billetsRate            { get; set; }
    public Decimal zincRate               { get; set; }
    public Decimal cpiRate                { get; set; }

    // Payment term conditional fields
    public Decimal lcInterest             { get; set; }
    public String  lcReflectSeparately    { get; set; }   // Against LC: Yes/No dropdown
    public Boolean showUsanceColumn       { get; set; }   // LC + reflect=Yes -> separate Usance Interest column
    public Decimal usanceBuyerDays        { get; set; }
    public Decimal usanceSellerDays       { get; set; }
    public Decimal usancePct              { get; set; }
    public Decimal pdcDays                { get; set; }
    public Decimal pdcInterestPct         { get; set; }
    public Decimal openCreditDays         { get; set; }
    public Decimal openCreditInterestPct  { get; set; }

    // Payment term booleans
    public Boolean isAgainstLC            { get; set; }
    public Boolean isAgainstPDC           { get; set; }
    public Boolean isAgainstOpenCredit    { get; set; }
    public Boolean isPriceVariation       { get; set; }

    // Line items
    public List<LineItemWrapper> lineItems { get; set; }
    public Decimal grandTotalExGST        { get; set; }
    public Decimal grandTotalIncGST       { get; set; }
    public Decimal totalQuantityMT        { get; set; }
    public String  grandTotalWords        { get; set; }
    // Indian-grouped (12,34,56,789.00) display strings. Underlying Decimals are
    // untouched - all maths still runs on them. Deepanjan (25th July 2026)
    public String  grandTotalIncGSTFmt    { get; set; }
    public String  materialListTotalWeight { get; set; }
    // Sum of the Quantity (MT) column AS DISPLAYED (weights where present,
    // quantities elsewhere), for the Annexure TOTAL row. totalQuantityMT still
    // holds the true quantity sum for anything else that reads it.
    public Decimal totalQuantityDisplay   { get; set; }
    
    // Eiditable Clause
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

    // ── Base 64 ──
    public String logoBase64 { get; set; }

    // ── CONSTRUCTOR ──
    public CoreOfferLetterController(ApexPages.StandardController stdCtrl) {
        Id quoteId = stdCtrl.getId();

        quoteRecord = [
            SELECT  Id, Name, QuoteNumber,Quote_Reference__c,
                    Account.Name, Account.BillingStreet,
                    Account.BillingCity, Account.BillingState,
                    Account.BillingPostalCode,
                    Opportunity.Name,
                    Quote_Value__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        List<StaticResource> resources = [
            SELECT Body, ContentType
            FROM StaticResource
            WHERE Name = 'UtkarshLogo'
            LIMIT 1
        ];
        if (!resources.isEmpty()) {
            String b64 = EncodingUtil.base64Encode(resources[0].Body);
            logoBase64 = 'data:' + resources[0].ContentType + ';base64,' + b64;
        }

        lineItems        = new List<LineItemWrapper>();
        grandTotalExGST  = 0;
        grandTotalIncGST = 0;
        totalQuantityMT  = 0;

        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            Map<String, Object> qv = (Map<String, Object>)
                JSON.deserializeUntyped(quoteRecord.Quote_Value__c);

            priceBasis            = strVal(qv, 'Price_Basis');
            incoterms             = strVal(qv, 'psd_incoterms');
            subjectLine           = strVal(qv, 'subject_line');
            deliverySchedule      = strVal(qv, 'delivery_schedule');
            deliveryScheduleUnit  = strVal(qv, 'delivery_schedule_in');   // NEW
            paymentTerms          = strVal(qv, 'payment_terms');
            paymentTermsNote      = strVal(qv, 'payment_terms_note');
            pvBaseMonth           = strVal(qv, 'price_variable_month');
            pvBaseYear            = strVal(qv, 'price_variable_year');
            zincCoating           = strVal(qv, 'zinc_coating');
            warrantyStart         = decVal(qv, 'warranty_start_date');
            warrantyEnd           = decVal(qv, 'warranty_end_date');
            offerValidity         = decVal(qv, 'offer_validity');
            discount              = decVal(qv, 'discount');
            numberOfMaterials     = (Integer) decVal(qv, 'number_of_materials');
            numberOfSpecialMaterials = (Integer) decVal(qv, 'number_of_special_materials'); // NEW

            // NEW: was missing — these are why "Ref:" and "enquiry dated" rendered blank
            yourRef               = strVal(qv, 'your_ref');
            enquiryDate           = formatDmy(strVal(qv, 'enquiry_date'));

            // NEW: F.O.R / transportation
            forValue                   = strVal(qv, 'for_value');
            transportationChargesPerMt = decVal(qv, 'transportation_charges');
            transportationChargesLumpsum = decVal(qv, 'lumpsum_charges');
            
            transitInsuranceCharges = decVal(qv, 'transit_insurance_charges');
            
            // NEW: Loading Charges
            loadingCharges          = strVal(qv, 'loading_charges');
            loadingChargesPerMt     = decVal(qv, 'loading_charges_per_mt');
            loadingChargesLumpsum   = decVal(qv, 'loading_charges_lumpsum');
            
            // NEW: derive booleans once, right after parsing
            isFreightPerMtIncluded   = forValue == 'Per mt (Included Price)';
            isFreightPerMtExcluded   = forValue == 'Per mt (Excluded Price)';
            isFreightLumpsumIncluded = forValue == 'Lump sum (Included Price)';
            isFreightLumpsumExcluded = forValue == 'Lump sum (Excluded Price)';
            
            isLoadingPerMtIncluded   = loadingCharges == 'Per mt (Included Price)';
            showLoadingColumn   = false;
            showUsanceColumn    = false;
            loadingIncludedNote = false;
            lumpIncBase = 0; lumpIncGst = 0; lumpIncTotal = 0;
            showFreightColumn   = false;
            freightIncludedNote = false;
            freightLumpIncBase = 0; freightLumpIncGst = 0; freightLumpIncTotal = 0;
            materialListRows = new List<MaterialListRow>();
            showMaterialList = false;
            isLoadingPerMtExcluded   = loadingCharges == 'Per mt (Excluded Price)';
            isLoadingLumpsumIncluded = loadingCharges == 'Lump sum (Included Price)';
            isLoadingLumpsumExcluded = loadingCharges == 'Lump sum (Excluded Price)';

            transitInsuranceCharges = decVal(qv, 'transit_insurance_charges');

            billetsRate           = decVal(qv, 'billets_rate');
            zincRate              = decVal(qv, 'zinc_rate');
            cpiRate               = decVal(qv, 'cpi_rate');

            lcReflectSeparately   = strVal(qv, 'lc_interest_reflect_separately');
            usanceBuyerDays       = decVal(qv, 'usance_interest_buyer_days');
            usanceSellerDays      = decVal(qv, 'usance_interest_seller_days');
            usancePct             = decVal(qv, 'usance_interest_percentage');
            pdcDays               = decVal(qv, 'against_pdc_days');
            pdcInterestPct        = decVal(qv, 'pdc_interest_percentage');
            openCreditDays        = decVal(qv, 'against_open_credit_days');
            openCreditInterestPct = decVal(qv, 'open_credit_interest_percentage');
            
            // Clause

            clause3  = defaultIfBlank(strVal(qv, 'clause_3'),
                'Rates and Taxes: The rates quoted are exclusive of Goods & Service Taxes and therefore the Goods & Service Taxes shall be chargeable extra @18% on the total order value.');
            
            clause5  = defaultIfBlank(strVal(qv, 'clause_5'),
                'Delivery Schedule: If the delivery date is not accounted for with any subjective precondition in that event the delivery schedule shall be accounted for from the date of the receipt of the supply order however if an advance payment has to be made with the supply order the date of receipt of such advance payment or the supply order, whichever is later shall be the date from which the delivery date shall be accounted for. The supplier will be responsible for delivering the entire consignment segment-wise, subject to mutual discussion and taking into account the date of receipt of the clear techno commercial order and commercial clearance. However, this is contingent upon normal working conditions.' + (String.isNotBlank(deliverySchedule) ? (' Here, delivery schedule shall be ' + deliverySchedule + ' ' + (deliveryScheduleUnit != null ? deliveryScheduleUnit : '') + ' from the date of clear order & commercial clearance.') : ''));
            
            clause7PerMtExcluded   = defaultIfBlank(strVal(qv, 'clause_7_per_mt_excluded'),
                'Loading Charges: Rs. 0 per MT (Basic) will be charged extra at actual.');
            clause7LumpsumExcluded = defaultIfBlank(strVal(qv, 'clause_7_lumpsum_excluded'),
                'Loading Charges: Rs. 0 (Lump Sum) will be charged extra at actual.');
            clause7PerMtIncluded   = defaultIfBlank(strVal(qv, 'clause_7_per_mt_included'),
                'Loading Charges: Rs. 0 per MT (Basic) is included in the quoted unit price.');
            clause7LumpsumIncluded = defaultIfBlank(strVal(qv, 'clause_7_lumpsum_included'),
                'Loading Charges: Rs. 0 (Lump Sum) is included in the quoted unit price.');
            
            clause8  = defaultIfBlank(strVal(qv, 'clause_8'),
                'Transportation & Freight: The rates quoted for the materials and/or goods are on FOR basis are exclusive of any transportation and freight charges, therefore be it mentioned here that if the Supplier has to facilitate the process of transportation in that event such freight charges shall become chargeable additionally.');
            
            clause9  = defaultIfBlank(strVal(qv, 'clause_9'),
                'Inspection: The Buyer at its own cost shall have to make arrangements for pre-delivery third party inspection of the entire quantity offered, by any recognised inspection agency at the Supplier\'s plant and/or factory or the Buyer may depute its own team at the Supplier\'s plant or factory who shall be deemed to have the requisite competence to carry out such pre-delivery inspection and it is only after the receipt of the inspection clearance certification the materials shall be put under despatch. If for any reason the Buyer fails to depute any third party inspection agency to carry out the pre-delivery inspection in that event the Supplier shall at the cost of the Buyer cause such third party pre-delivery inspection to be carried out at the Supplier\'s plant or factory and such inspection for all practical purposes shall be deemed to have been caused at the behest of the Buyer. Such third party inspection caused prior to delivery or despatch of the materials shall be considered and construed as final for all issues on quality and technical parameters.');
            
            clause12 = defaultIfBlank(strVal(qv, 'clause_12'),
                'Warranty: The Supplier\'s products are covered by a mechanical guarantee for a period of ' + (warrantyStart != null ? String.valueOf(warrantyStart.intValue()) : '12') + ' months from the date of commissioning or at the latest ' + (warrantyEnd != null ? String.valueOf(warrantyEnd.intValue()) : '18') + ' months from the date of delivery as per the agreed incoterm, unless a longer period has been accepted by the Supplier on case by case basis. The warranty period for a defective material, which has been replaced, shall extend only to the extent of the unexpired term of such warranty from the date of replacement. Repaired or corrected materials shall remain warranted for the balance of the original warranty period.');
            
            clause13 = defaultIfBlank(strVal(qv, 'clause_13'),
                'Return of Goods: Be it noted that after obtaining satisfactory inspection clearance certification once the goods are sold and delivered the Buyer will not be entitled to return the same by raising any technical issues or defects.');
            
            clause15 = defaultIfBlank(strVal(qv, 'clause_15'),
                'Validity: This offer shall remain valid for a period of ' + (offerValidity != null ? String.valueOf(offerValidity.intValue()) : '6') + ' days from the date of issuing of the present quotation thereafter with the efflux of time this offer shall deemed become null and void, unless the same is revalidated in writing.');
            
            clause16 = defaultIfBlank(strVal(qv, 'clause_16'),
                'Penal interest & Ground Rent: Once the material is inspected and final IC is cleared, then if there is any delay to lift the material for commercial clearance (i.e. Payment / Opening of LC, etc) then both Ground Rent of 1% monthly and Penal interest of 18% per annum shall be charged to the Buyer. Also in the event if the Buyer fails to make payment of the invoices raised within seven days and/or as may be agreed otherwise, from the date of receipt of the same in that event the Supplier shall be entitled to impose penal interest @10% per annum quarterly compoundable.');
            
            clause20 = defaultIfBlank(strVal(qv, 'clause_20'),
                'Price variation: PVC will be applicable as per IEEMA circular, where base month will be considered as ' + pvBaseMonth + ' ' + pvBaseYear + '.');

            // bold every clause lead-in for the offer pages - Deepanjan (23rd July 2026)
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
            
            point26Label = defaultIfBlank(strVal(qv, 'point_26_label'), 'As new requirement');
            point26Text  = strVal(qv, 'point_26_text');
            hasPoint26   = String.isNotBlank(point26Text);

            // ── Detect JSON format ──
            // New format uses c${n}_ prefix (column-repeater).
            // Old format uses _n suffix (legacy).
            Boolean isNewFormat = qv.containsKey('c1_material_list_type');

            List<String>  matTypes   = new List<String>();
            List<Decimal> quantities = new List<Decimal>();
            // Per-column total weight (MT), captured only for DISPLAY in the
            // Quantity (MT) column. All maths keeps using quantities[i].
            // Deepanjan (26th July 2026)
            List<Decimal> colWeights = new List<Decimal>();
            List<String>  colPrefixes = new List<String>();
            // Sum of each column's ROUNDED material-list rows, keyed by prefix.
            // The Quantity column prints THIS when available, so the Annexure
            // figure always equals what the material-list rows visibly add up
            // to at WT_SCALE decimals. Deepanjan (27th July 2026)
            Map<String, Decimal> colRowWtSum = new Map<String, Decimal>();
            List<Decimal> unitRates  = new List<Decimal>();
            List<Decimal> addedUps   = new List<Decimal>();
            List<Decimal> costPrices = new List<Decimal>();

            if (isNewFormat) {
                Integer maxCols = (numberOfMaterials != null && numberOfMaterials > 0)
                    ? numberOfMaterials : 10;
                for (Integer n = 1; n <= maxCols; n++) {
                    String p = 'c' + n + '_';
                    String mat = strVal(qv, p + 'material_list_type');
                    if (String.isBlank(mat)) continue;
                    matTypes.add(mat);
                    // NOTE: field in JSON is c{n}_quantity_pc and c{n}_unit_rate /
                    // c{n}_total_weight_mt / c{n}_unit_price, not 'quantity_mt' / 'added_up' / 'cost_price'.
                    // Kept original key names below unchanged from your existing logic;
                    // adjust here if your JSON's actual keys differ per column type.
                    // PV saves quantity as c{n}_quantity_pc, FIRM as c{n}_quantity_mt.
                    // Read whichever is populated so both bases flow to the PDF. Path B.
                    Decimal qtyVal = decVal(qv, p + 'quantity_pc');
                    if (qtyVal == null || qtyVal == 0) qtyVal = decVal(qv, p + 'quantity_mt');
                    quantities.add(qtyVal);
                    colWeights.add(decVal(qv, p + 'total_weight_mt'));
                    colPrefixes.add(p);
                    unitRates.add(decVal(qv, p + 'unit_rate'));
                    addedUps.add(decVal(qv, p + 'added_up'));
                    costPrices.add(decVal(qv, p + 'cost_price'));
                }
            } else {
                // Old format: _1, _2, _3 suffix
                for (Integer n = 1; n <= 3; n++) {
                    String s = '_' + n;
                    String mat = strVal(qv, 'material_list_type' + s);
                    if (String.isBlank(mat)) continue;
                    matTypes.add(mat);
                    quantities.add(decVal(qv, 'quantity_mt' + s));
                    colWeights.add(null);   // old format has no per-column weight
                    colPrefixes.add(null);
                    unitRates.add(decVal(qv, 'unit_rate' + s));
                    addedUps.add(decVal(qv, 'added_up' + s));
                    costPrices.add(decVal(qv, 'cost_price' + s));
                }
            }

            // ── MATERIAL LIST (below Annexure-A) ──
            // One row per selected sub-type of every material column: the widget
            // saves c{n}_subtype_qty as [{subtype, qty, wt}] where wt is the
            // per-unit weight in MT (embedded at save time). For rows saved
            // before wt existed, a single-subtype column derives it from
            // c{n}_total_weight_mt / qty; otherwise the cell stays blank.
            // Deepanjan (24th July 2026)
            Integer mlSl = 1;
            for (Integer n = 1; n <= 10; n++) {
                String p = 'c' + n + '_';
                String grp = strVal(qv, p + 'material_list_type');
                String subJson = strVal(qv, p + 'subtype_qty');
                if (String.isBlank(grp) || String.isBlank(subJson)) continue;
                List<Object> entries;
                try {
                    entries = (List<Object>) JSON.deserializeUntyped(subJson);
                } catch (Exception e) { continue; }
                Decimal colTotalWt = decVal(qv, p + 'total_weight_mt');
                for (Object o : entries) {
                    Map<String, Object> e = (Map<String, Object>) o;
                    String sub = e.get('subtype') != null ? String.valueOf(e.get('subtype')) : '';
                    if (String.isBlank(sub)) continue;
                    Decimal q = 0;
                    if (e.get('qty') != null) {
                        try { q = Decimal.valueOf(String.valueOf(e.get('qty'))); } catch (Exception ex) { q = 0; }
                    }
                    Decimal wtMt = null;
                    if (e.get('wt') != null) {
                        try { wtMt = Decimal.valueOf(String.valueOf(e.get('wt'))); } catch (Exception ex) { wtMt = null; }
                    }
                    if (wtMt == null && entries.size() == 1 && q > 0 && colTotalWt != null && colTotalWt > 0) {
                        wtMt = (colTotalWt / q);
                    }
                    MaterialListRow r = new MaterialListRow();
                    r.slNo          = mlSl++;
                    r.groupName     = grp;
                    r.riNo          = sub;
                    r.weightNosKg   = wtMt != null ? (wtMt * 1000).setScale(3, RoundingMode.HALF_UP) : null;
                    r.requiredQty   = q;
                    r.totalWeightMt = (wtMt != null && q > 0)
                                        ? (wtMt * q).setScale(WT_SCALE, RoundingMode.HALF_UP) : null;
                    if (r.totalWeightMt != null) {
                        Decimal run = colRowWtSum.containsKey(p) ? colRowWtSum.get(p) : 0;
                        colRowWtSum.put(p, run + r.totalWeightMt);
                    }
                    materialListRows.add(r);
                }
            }

            // ── NEW: SPECIAL ITEMS also print in the MATERIAL LIST ──
            // Client (28th July 2026): the special items must appear in the
            // MATERIAL LIST table too, and the user may enter several of them
            // (one per c{n}_ss_ column). Description = the user's material
            // name exactly as typed (same only-user-input rule as Annexure-A),
            // R.I NO. stays blank. Rows read the SAME saved c{n}_ss_* fields
            // the Annexure loop uses, so no blueprint/JSON change is needed and
            // one loop serves FIRM and Price Variation alike. These rows
            // deliberately do NOT touch colRowWtSum - that map feeds the
            // material columns' Quantity (MT) display in Annexure-A.
            // Deepanjan (28th July 2026)
            Integer mlSpecialCols = (numberOfSpecialMaterials != null && numberOfSpecialMaterials > 0)
                ? numberOfSpecialMaterials : 10;
            for (Integer n = 1; n <= mlSpecialCols; n++) {
                String sp = 'c' + n + '_ss_';
                String ssNm = strVal(qv, sp + 'material_name');
                if (String.isBlank(ssNm)) continue;
                Decimal q   = decVal(qv, sp + 'quantity_pc');
                Decimal wt  = decVal(qv, sp + 'weight_mt');        // per-pc weight (MT)
                Decimal tot = decVal(qv, sp + 'total_weight_mt');  // wt x qty saved by the UI
                if ((tot == null || tot == 0) && wt != null && wt > 0 && q != null && q > 0) tot = wt * q;
                if ((wt == null || wt == 0) && tot != null && tot > 0 && q != null && q > 0) wt = tot / q;
                MaterialListRow r = new MaterialListRow();
                r.slNo          = mlSl++;
                r.groupName     = ssNm;
                r.riNo          = 'Special';
                r.weightNosKg   = (wt != null && wt > 0) ? (wt * 1000).setScale(3, RoundingMode.HALF_UP) : null;
                r.requiredQty   = q;
                r.totalWeightMt = (tot != null && tot > 0) ? tot.setScale(WT_SCALE, RoundingMode.HALF_UP) : null;
                materialListRows.add(r);
            }
            showMaterialList = !materialListRows.isEmpty();

            // ── Build line items ──
            Decimal gstRate = 0.18;
            Integer slNo    = 1;

            for (Integer i = 0; i < matTypes.size(); i++) {
                Decimal baseRate    = costPrices[i] != null ? costPrices[i] : 0;
                Decimal addedUpVal  = addedUps[i]   != null ? addedUps[i]   : 0;
                Decimal discVal     = discount       != null ? discount       : 0;
                Boolean hasDiscount = discVal > 0;

                Decimal finalUnitPrice;
                Boolean isInterestBearing = (paymentTerms == 'Against PDC' ||
                                             (paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC') ||
                                             paymentTerms == 'Against LC');

                // c{n}_cost_price is ALREADY net: the blueprint summary computes it
                // as unit_rate - discount + added_up, and that is exactly what the
                // user sees in the Material Price Summary. Re-applying added_up /
                // discount here double-counted them (e.g. 75897 became 76197).
                // The Item Rate on the PDF must equal the summary's Cost Price.
                // Deepanjan (24th July 2026)
                // Against LC (28th July 2026): interest is computed exactly like
                // Against Open Credit with PDC, but from the Usance Interest in
                // Buyer's Account (days) and % of Usance Interest. It is ALWAYS
                // folded into the taxable unit price so GST and totals are
                // identical whether it is reflected separately or not; when
                // "LC Interest Reflect Separately" = Yes the page splits it back
                // out into its own Usance Interest column (Item Rate then shows
                // baseRate). Deepanjan (28th July 2026)
                Decimal usanceForRow = 0;
                if (isInterestBearing) {
                    Decimal interestDays = 0;
                    Decimal interestPct  = 0;

                    if (paymentTerms == 'Against PDC') {
                        interestDays = pdcDays        != null ? pdcDays        : 0;
                        interestPct  = pdcInterestPct != null ? pdcInterestPct : 0;
                    } else if (paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC') {
                        interestDays = openCreditDays        != null ? openCreditDays        : 0;
                        interestPct  = openCreditInterestPct != null ? openCreditInterestPct : 0;
                    } else if (paymentTerms == 'Against LC') {
                        interestDays = usanceBuyerDays != null ? usanceBuyerDays : 0;
                        interestPct  = usancePct       != null ? usancePct       : 0;
                    }

                    Decimal interest = (baseRate * interestDays * interestPct) / (100 * 365);
                    finalUnitPrice   = baseRate + interest;
                    if (paymentTerms == 'Against LC') usanceForRow = interest;
                } else {
                    finalUnitPrice = baseRate;
                }

                if (finalUnitPrice < 0) finalUnitPrice = 0;

                LineItemWrapper w = new LineItemWrapper();
                w.slNo            = slNo++;
                w.itemName        = matTypes[i];
                w.itemType        = 'material';
                w.baseRate        = baseRate.setScale(2, RoundingMode.HALF_UP);
                w.unitRate        = unitRates[i] != null
                                    ? unitRates[i].setScale(2, RoundingMode.HALF_UP) : 0;
                w.addedUp         = addedUpVal.setScale(2, RoundingMode.HALF_UP);
                w.discountAmt     = hasDiscount ? discVal.setScale(2, RoundingMode.HALF_UP) : 0;
                w.unitPrice       = finalUnitPrice.setScale(2, RoundingMode.HALF_UP);
                w.usanceInterest  = usanceForRow > 0 ? usanceForRow.setScale(2, RoundingMode.HALF_UP) : null;
                w.quantity        = (quantities[i] != null && quantities[i] > 0)
                                    ? quantities[i]
                                    : (w.unitPrice > 0 ? 1 : 0);
                // Priority: (1) the column's material-list rows summed at
                // WT_SCALE - so this cell and the rows beneath it always agree
                // digit for digit; (2) the stored column weight rounded the same
                // way (column has a weight but no subtype rows); (3) quantity.
                // Deepanjan (27th July 2026)
                Decimal rowsWt = (colPrefixes[i] != null) ? colRowWtSum.get(colPrefixes[i]) : null;
                w.quantityDisplay = (rowsWt != null && rowsWt > 0)
                                    ? rowsWt
                                    : ((colWeights[i] != null && colWeights[i] > 0)
                                        ? colWeights[i].setScale(WT_SCALE, RoundingMode.HALF_UP)
                                        : w.quantity);
                w.gstPct          = 18;
                w.gstAmount       = (w.unitPrice * gstRate).setScale(2, RoundingMode.HALF_UP);
                w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                w.totalExGST      = (w.unitPrice * w.quantity).setScale(2, RoundingMode.HALF_UP);
                w.totalInclGST    = (w.unitRateInclGST * w.quantity).setScale(2, RoundingMode.HALF_UP);

                grandTotalExGST  += w.totalExGST;
                grandTotalIncGST += w.totalInclGST;
                totalQuantityMT  += w.quantity;
                lineItems.add(w);
            }

            // ── NEW: Build SPECIAL SECTION line items (c{n}_ss_* fields) ──
            // These were being completely dropped before — they exist in
            // _Final_Apex_Lines / _pendingLineItems ("Price Variation - Special
            // Section (Item 1)") but the controller never read the c{n}_ss_*
            // source fields, so Annexure A never showed them.
            Integer maxSpecialCols = (numberOfSpecialMaterials != null && numberOfSpecialMaterials > 0)
                ? numberOfSpecialMaterials : 10;

            for (Integer n = 1; n <= maxSpecialCols; n++) {
                String sp = 'c' + n + '_ss_';
                String ssName = strVal(qv, sp + 'material_name');
                if (String.isBlank(ssName)) continue;

                Decimal ssQty      = decVal(qv, sp + 'quantity_pc');
                Decimal ssUnitCost = decVal(qv, sp + 'unit_cost');
                Decimal ssUnitPrice = decVal(qv, sp + 'unit_price');
                // The Special Section rate is PER MT, so the amount multiplies by
                // the TOTAL WEIGHT (ss_total_weight_mt = weight x qty), not by the
                // piece count - e.g. 12 MT x 5 pc = 60 MT x rate. Same rule for
                // Price Variation and FIRM (this loop serves both). Old quotes
                // saved before the weight fields existed fall back to the piece
                // count, so their PDFs keep printing what they always printed.
                // Deepanjan (27th July 2026)
                Decimal ssTotWt    = decVal(qv, sp + 'total_weight_mt');
                if ((ssTotWt == null || ssTotWt == 0)) {
                    Decimal ssWt = decVal(qv, sp + 'weight_mt');
                    if (ssWt != null && ssWt > 0 && ssQty != null && ssQty > 0) {
                        ssTotWt = ssWt * ssQty;
                    }
                }

                Decimal discVal     = discount != null ? discount : 0;
                // ss_unit_price already equals the UI's Special Section Unit Price
                // (formula ss_unit_rate || 0); the quote-level discount is a
                // material-engine input and must not be re-subtracted here.
                // Deepanjan (24th July 2026)
                Decimal finalPrice  = (ssUnitPrice != null && ssUnitPrice > 0)
                                        ? ssUnitPrice : ssUnitCost;
                if (finalPrice < 0) finalPrice = 0;

                // Interest applies to SPECIAL lines too (29th July 2026): the
                // same payment-term interest that folds into the material Item
                // Rate was skipping specials (client screenshot: the material
                // row carried Usance Interest, "test 1" did not). Same day/pct
                // sources, same formula, folded into the taxable rate before
                // GST so every later fold/retotal (amountMult) works unchanged.
                // Deepanjan (29th July 2026)
                Decimal ssPreInterestRate = finalPrice;
                Decimal ssUsanceForRow    = 0;
                Boolean ssInterestBearing = (paymentTerms == 'Against PDC' ||
                                             paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC' ||
                                             paymentTerms == 'Against LC');
                if (ssInterestBearing) {
                    Decimal ssIntDays = 0;
                    Decimal ssIntPct  = 0;
                    if (paymentTerms == 'Against PDC') {
                        ssIntDays = pdcDays        != null ? pdcDays        : 0;
                        ssIntPct  = pdcInterestPct != null ? pdcInterestPct : 0;
                    } else if (paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC') {
                        ssIntDays = openCreditDays        != null ? openCreditDays        : 0;
                        ssIntPct  = openCreditInterestPct != null ? openCreditInterestPct : 0;
                    } else if (paymentTerms == 'Against LC') {
                        ssIntDays = usanceBuyerDays != null ? usanceBuyerDays : 0;
                        ssIntPct  = usancePct       != null ? usancePct       : 0;
                    }
                    Decimal ssInterest = (finalPrice * ssIntDays * ssIntPct) / (100 * 365);
                    finalPrice += ssInterest;
                    if (paymentTerms == 'Against LC') ssUsanceForRow = ssInterest;
                }

                LineItemWrapper w = new LineItemWrapper();
                w.slNo            = slNo++;
                w.itemName        = ssName;
                w.itemType        = 'special';
                w.baseRate        = (ssUnitCost != null ? ssUnitCost : 0).setScale(2, RoundingMode.HALF_UP);
                w.unitRate        = (ssUnitPrice != null ? ssUnitPrice : 0).setScale(2, RoundingMode.HALF_UP);
                w.addedUp         = 0;
                w.discountAmt     = discVal > 0 ? discVal.setScale(2, RoundingMode.HALF_UP) : 0;
                w.unitPrice       = finalPrice.setScale(2, RoundingMode.HALF_UP);
                w.usanceInterest  = ssUsanceForRow > 0 ? ssUsanceForRow.setScale(2, RoundingMode.HALF_UP) : null;
                w.quantity        = (ssQty != null && ssQty > 0) ? ssQty : 1;
                // Amount multiplier: total weight when present, else the legacy qty.
                Decimal ssMult    = (ssTotWt != null && ssTotWt > 0) ? ssTotWt : w.quantity;
                w.quantityDisplay = ssMult;   // Quantity (MT) column shows 60, and 236 x 60 adds up on paper
                w.amountMult      = ssMult;   // and every later retotal keeps multiplying by it
                w.gstPct          = 18;
                w.gstAmount       = (w.unitPrice * gstRate).setScale(2, RoundingMode.HALF_UP);
                w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                w.totalExGST      = (w.unitPrice * ssMult).setScale(2, RoundingMode.HALF_UP);
                w.totalInclGST    = (w.unitRateInclGST * ssMult).setScale(2, RoundingMode.HALF_UP);

                grandTotalExGST  += w.totalExGST;
                grandTotalIncGST += w.totalInclGST;
                totalQuantityMT  += w.quantity;
                lineItems.add(w);
            }

            // ── Add transportation as its own line item when "Lump sum" ──
            // (Matches the _newLineItemGenerators rule: Lump Sum -> goes to
            // "expenses", does NOT carry GST, and is its own row, not blended
            // into unit price like the "Per mt" case.)
            // ══════════════════════════════════════════════════════════════
            // FREIGHT (for_value) + LOADING CHARGES (loading_charges)
            // Table-integrated, ORDER-SAFE pattern. Deepanjan (23rd July 2026)
            //
            //   Step 1 - INCLUDED folds first: Per mt (Included) freight and/or
            //            loading join the item rate BEFORE GST; the row's GST,
            //            incl-GST rate and totals are rebuilt once.
            //   Step 2 - EXCLUDED columns after: Per mt (Excluded) freight and/or
            //            loading render their own columns; GST stays on the base
            //            rate, the charge joins only the incl-GST figures.
            //   Step 3 - LUMP SUMS last: Excluded -> separate line WITH GST @18%;
            //            Included -> boxed value + 18% GST added to the TOTAL.
            //
            // Doing folds before columns keeps mixed selections correct (e.g.
            // freight Included + loading Excluded): the fold's GST rebuild can
            // never wipe out a column's incl-GST addition. Charges never touch
            // freight / insurance lines (itemType 'transportation').
            // ══════════════════════════════════════════════════════════════

            // ══════════════════════════════════════════════════════════════
            // CHARGE-SIDE PAYMENT-TERM INTEREST (29th July 2026)
            // The interest used to sit on the goods rates only. Client asked
            // for the charges to carry it as well, so loading, transportation
            // and transit insurance are grossed up ONCE here, before any of
            // the steps below read them. Doing it at the source means the
            // Step 1 folds, the Step 2 columns, the Step 3a lines and the
            // Step 3b Included boxes all inherit it without a single one of
            // those blocks changing. Same rate source and formula as the goods
            // (days x pct / 100 / 365); the interest slice of each lump sum and
            // of the insurance is kept so the Annexure Usance Interest column
            // can print it on those lines. Deepanjan (29th July 2026)
            // ══════════════════════════════════════════════════════════════
            Decimal chargeIntDays = 0;
            Decimal chargeIntPct  = 0;
            if (paymentTerms == 'Against PDC') {
                chargeIntDays = pdcDays        != null ? pdcDays        : 0;
                chargeIntPct  = pdcInterestPct != null ? pdcInterestPct : 0;
            } else if (paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC') {
                chargeIntDays = openCreditDays        != null ? openCreditDays        : 0;
                chargeIntPct  = openCreditInterestPct != null ? openCreditInterestPct : 0;
            } else if (paymentTerms == 'Against LC') {
                chargeIntDays = usanceBuyerDays != null ? usanceBuyerDays : 0;
                chargeIntPct  = usancePct       != null ? usancePct       : 0;
            }
            Decimal freightLumpInterest = 0;
            Decimal loadingLumpInterest = 0;
            Decimal insuranceInterest   = 0;
            if (chargeIntDays > 0 && chargeIntPct > 0) {
                Decimal chargeIntRate = (chargeIntDays * chargeIntPct) / (100 * 365);
                if (transportationChargesPerMt != null && transportationChargesPerMt > 0) {
                    transportationChargesPerMt = (transportationChargesPerMt
                        + transportationChargesPerMt * chargeIntRate).setScale(2, RoundingMode.HALF_UP);
                }
                if (loadingChargesPerMt != null && loadingChargesPerMt > 0) {
                    loadingChargesPerMt = (loadingChargesPerMt
                        + loadingChargesPerMt * chargeIntRate).setScale(2, RoundingMode.HALF_UP);
                }
                if (transportationChargesLumpsum != null && transportationChargesLumpsum > 0) {
                    freightLumpInterest = (transportationChargesLumpsum * chargeIntRate).setScale(2, RoundingMode.HALF_UP);
                    transportationChargesLumpsum = (transportationChargesLumpsum + freightLumpInterest).setScale(2, RoundingMode.HALF_UP);
                }
                if (loadingChargesLumpsum != null && loadingChargesLumpsum > 0) {
                    loadingLumpInterest = (loadingChargesLumpsum * chargeIntRate).setScale(2, RoundingMode.HALF_UP);
                    loadingChargesLumpsum = (loadingChargesLumpsum + loadingLumpInterest).setScale(2, RoundingMode.HALF_UP);
                }
                if (transitInsuranceCharges != null && transitInsuranceCharges > 0) {
                    insuranceInterest = (transitInsuranceCharges * chargeIntRate).setScale(2, RoundingMode.HALF_UP);
                    transitInsuranceCharges = (transitInsuranceCharges + insuranceInterest).setScale(2, RoundingMode.HALF_UP);
                }
            }

            Boolean freightFold = isFreightPerMtIncluded
                                  && transportationChargesPerMt != null && transportationChargesPerMt > 0;
            Boolean loadingFold = isLoadingPerMtIncluded
                                  && loadingChargesPerMt != null && loadingChargesPerMt > 0;
            Boolean freightCol  = isFreightPerMtExcluded
                                  && transportationChargesPerMt != null && transportationChargesPerMt > 0;
            Boolean loadingCol  = isLoadingPerMtExcluded
                                  && loadingChargesPerMt != null && loadingChargesPerMt > 0;

            // ── Step 1: folds (rate grows, GST follows) ──
            if (freightFold || loadingFold) {
                freightIncludedNote = freightFold;
                loadingIncludedNote = loadingFold;
                Decimal foldAmt = 0;
                if (freightFold) foldAmt += transportationChargesPerMt;
                if (loadingFold) foldAmt += loadingChargesPerMt;
                foldAmt = foldAmt.setScale(2, RoundingMode.HALF_UP);

                for (LineItemWrapper w : lineItems) {
                    if (w.itemType == 'transportation') continue;
                    grandTotalExGST  -= w.totalExGST;
                    grandTotalIncGST -= w.totalInclGST;
                    w.unitPrice       = (w.unitPrice + foldAmt).setScale(2, RoundingMode.HALF_UP);
                    Decimal rowGstRate = (w.gstPct != null && w.gstPct > 0)
                                         ? (Decimal.valueOf(w.gstPct) / 100) : 0;
                    w.gstAmount       = (w.unitPrice * rowGstRate).setScale(2, RoundingMode.HALF_UP);
                    w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                    Decimal foldQty   = (w.amountMult != null) ? w.amountMult : w.quantity;
                    w.totalExGST      = (w.unitPrice * foldQty).setScale(2, RoundingMode.HALF_UP);
                    w.totalInclGST    = (w.unitRateInclGST * foldQty).setScale(2, RoundingMode.HALF_UP);
                    grandTotalExGST  += w.totalExGST;
                    grandTotalIncGST += w.totalInclGST;
                }
            }

            // ── Step 2: excluded per-MT columns (after every GST rebuild) ──
            if (freightCol || loadingCol) {
                showFreightColumn = freightCol;
                showLoadingColumn = loadingCol;
                Decimal fPerMt = freightCol ? transportationChargesPerMt.setScale(2, RoundingMode.HALF_UP) : 0;
                Decimal lPerMt = loadingCol ? loadingChargesPerMt.setScale(2, RoundingMode.HALF_UP) : 0;

                for (LineItemWrapper w : lineItems) {
                    if (w.itemType == 'transportation') {
                        if (freightCol) w.freightCharge = 0;
                        if (loadingCol) w.loadingCharge = 0;
                        continue;
                    }
                    Decimal colAmt = 0;
                    if (freightCol) { w.freightCharge = fPerMt; colAmt += fPerMt; }
                    if (loadingCol) { w.loadingCharge = lPerMt; colAmt += lPerMt; }
                    if (colAmt == 0) continue;
                    // GST is computed on Item Rate + Loading + Transportation
                    // (Deepanjan, 23rd July 2026 - per client instruction the excluded
                    // charges join the GST base; only the Item Rate cell stays base-only).
                    grandTotalExGST  -= w.totalExGST;
                    grandTotalIncGST -= w.totalInclGST;
                    Decimal gstBase   = (w.unitPrice + colAmt).setScale(2, RoundingMode.HALF_UP);
                    Decimal rowGstRate = (w.gstPct != null && w.gstPct > 0)
                                         ? (Decimal.valueOf(w.gstPct) / 100) : 0;
                    w.gstAmount       = (gstBase * rowGstRate).setScale(2, RoundingMode.HALF_UP);
                    w.unitRateInclGST = (gstBase + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                    Decimal colQty    = (w.amountMult != null) ? w.amountMult : w.quantity;
                    w.totalExGST      = (gstBase * colQty).setScale(2, RoundingMode.HALF_UP);
                    w.totalInclGST    = (w.unitRateInclGST * colQty).setScale(2, RoundingMode.HALF_UP);
                    grandTotalExGST  += w.totalExGST;
                    grandTotalIncGST += w.totalInclGST;
                }
            }

            // ── Step 3a: lump sums, EXCLUDED -> their own line WITH GST @18% ──
            if (isFreightLumpsumExcluded && transportationChargesLumpsum != null && transportationChargesLumpsum > 0) {
                LineItemWrapper w = new LineItemWrapper();
                w.slNo            = slNo++;
                w.itemName        = 'Transportation Charges (Lump Sum)';
                w.itemType        = 'transportation';
                w.isFlatCharge    = true;   // Quantity (MT) prints "-", stays out of TOTAL weight
                w.baseRate        = 0;
                w.unitRate        = transportationChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                w.addedUp         = 0;
                w.discountAmt     = 0;
                w.unitPrice       = transportationChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                w.usanceInterest  = (paymentTerms == 'Against LC' && freightLumpInterest > 0) ? freightLumpInterest : null;
                w.quantity        = 1;
                w.gstPct          = 18;
                w.gstAmount       = (w.unitPrice * 0.18).setScale(2, RoundingMode.HALF_UP);
                w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                w.totalExGST      = w.unitPrice;
                w.totalInclGST    = w.unitRateInclGST;
                grandTotalExGST  += w.totalExGST;
                grandTotalIncGST += w.totalInclGST;
                lineItems.add(w);
            }
            if (isLoadingLumpsumExcluded && loadingChargesLumpsum != null && loadingChargesLumpsum > 0) {
                LineItemWrapper w = new LineItemWrapper();
                w.slNo            = slNo++;
                w.itemName        = 'Loading Charges (Lump Sum)';
                w.itemType        = 'transportation';
                w.isFlatCharge    = true;   // Quantity (MT) prints "-", stays out of TOTAL weight
                w.baseRate        = 0;
                w.unitRate        = loadingChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                w.addedUp         = 0;
                w.discountAmt     = 0;
                w.unitPrice       = loadingChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                w.usanceInterest  = (paymentTerms == 'Against LC' && loadingLumpInterest > 0) ? loadingLumpInterest : null;
                w.quantity        = 1;
                w.gstPct          = 18;
                w.gstAmount       = (w.unitPrice * 0.18).setScale(2, RoundingMode.HALF_UP);
                w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                w.totalExGST      = w.unitPrice;
                w.totalInclGST    = w.unitRateInclGST;
                grandTotalExGST  += w.totalExGST;
                grandTotalIncGST += w.totalInclGST;
                lineItems.add(w);
            }

            // ── Step 3b: lump sums, INCLUDED -> boxed value + 18% GST into TOTAL ──
            if (isFreightLumpsumIncluded && transportationChargesLumpsum != null && transportationChargesLumpsum > 0) {
                freightLumpIncBase  = transportationChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                freightLumpIncGst   = (freightLumpIncBase * 0.18).setScale(2, RoundingMode.HALF_UP);
                freightLumpIncTotal = (freightLumpIncBase + freightLumpIncGst).setScale(2, RoundingMode.HALF_UP);
                grandTotalExGST  += freightLumpIncBase;
                grandTotalIncGST += freightLumpIncTotal;
            }
            if (isLoadingLumpsumIncluded && loadingChargesLumpsum != null && loadingChargesLumpsum > 0) {
                lumpIncBase  = loadingChargesLumpsum.setScale(2, RoundingMode.HALF_UP);
                lumpIncGst   = (lumpIncBase * 0.18).setScale(2, RoundingMode.HALF_UP);
                lumpIncTotal = (lumpIncBase + lumpIncGst).setScale(2, RoundingMode.HALF_UP);
                grandTotalExGST  += lumpIncBase;
                grandTotalIncGST += lumpIncTotal;
            }

            // ── Dynamic total-note: name what this TOTAL really carries ──
            // Anything the user selected (loading / freight, included OR
            // excluded modes) now lands inside the table total; transit
            // insurance is its own GST-bearing line inside the total too.
            // Only the charges NOT selected stay on the exclusive side, and
            // TCS is always exclusive. Deepanjan (24th July 2026)
            Boolean hasLoading   = isLoadingPerMtExcluded || isLoadingPerMtIncluded
                                   || isLoadingLumpsumExcluded || isLoadingLumpsumIncluded;
            Boolean hasFreight   = isFreightPerMtExcluded || isFreightPerMtIncluded
                                   || isFreightLumpsumExcluded || isFreightLumpsumIncluded;
            Boolean hasInsurance = transitInsuranceCharges != null && transitInsuranceCharges > 0;

            // Every selected charge lands inside this TOTAL in all four modes, so the
            // inclusive side is unchanged. What was missing is WHICH WAY it got there:
            // "Included" modes sit inside the quoted unit price, "Excluded" modes are
            // billed on top of it. Without that, a quote with F.O.R = Per mt (Excluded)
            // read as if freight were already in the rate. The qualifier depends only on
            // Included vs Excluded - Per mt vs Lump sum is already spelt out in Points 7
            // and 8 - so both charges are covered by two phrases, not sixteen strings.
            // Deepanjan (24th July 2026)
            String inRate = ' (included in the quoted unit price)';
            String extra  = ' (charged extra at actual)';
            Boolean loadingInRate = isLoadingPerMtIncluded || isLoadingLumpsumIncluded;
            Boolean freightInRate = isFreightPerMtIncluded || isFreightLumpsumIncluded;

            List<String> inclParts = new List<String>{ 'all rates', 'taxes' };
            if (hasLoading)   inclParts.add('Loading Charges' + (loadingInRate ? inRate : extra));
            if (hasFreight)   inclParts.add('Transportation or Freight Charges' + (freightInRate ? inRate : extra));
            if (hasInsurance) inclParts.add('Transit Insurance Charges');

            List<String> exclParts = new List<String>();
            if (!hasFreight)   exclParts.add('any Transportation or Freight Charges');
            if (!hasInsurance) exclParts.add('any Transit Insurance Charges');
            exclParts.add('any TCS Charges (If any)');

            totalNoteSuffix = 'which is inclusive of ' + String.join(inclParts, ', ')
                            + ' but exclusive of ' + String.join(exclParts, ' or ') + '.';
            // ── Add transit insurance as its own line item ──
            if (transitInsuranceCharges != null && transitInsuranceCharges > 0) {
                LineItemWrapper w = new LineItemWrapper();
                w.slNo            = slNo++;
                w.itemName        = 'Transit Insurance Charges';
                w.itemType        = 'transportation';   // reuse same rendering bucket as lump sum
                w.isFlatCharge    = true;   // flat charge, not a tonnage: Quantity (MT) prints "-"
                w.baseRate        = 0;
                w.unitRate        = transitInsuranceCharges.setScale(2, RoundingMode.HALF_UP);
                w.addedUp         = 0;
                w.discountAmt     = 0;
                w.unitPrice       = transitInsuranceCharges.setScale(2, RoundingMode.HALF_UP);
                w.usanceInterest  = (paymentTerms == 'Against LC' && insuranceInterest > 0) ? insuranceInterest : null;
                w.quantity        = 1;
                w.gstPct          = 18;   // GST applies here too - Deepanjan (23rd July 2026)
                w.gstAmount       = (w.unitPrice * 0.18).setScale(2, RoundingMode.HALF_UP);
                w.unitRateInclGST = (w.unitPrice + w.gstAmount).setScale(2, RoundingMode.HALF_UP);
                w.totalExGST      = (w.unitPrice * w.quantity).setScale(2, RoundingMode.HALF_UP);
                w.totalInclGST    = (w.unitRateInclGST * w.quantity).setScale(2, RoundingMode.HALF_UP);

                grandTotalExGST  += w.totalExGST;
                grandTotalIncGST += w.totalInclGST;
                lineItems.add(w);
            }
        }

        // ── Booleans (safe even when JSON is blank) ──
        isAgainstLC         = paymentTerms == 'Against LC';
        showUsanceColumn    = isAgainstLC && lcReflectSeparately == 'Yes';
        isAgainstPDC        = paymentTerms == 'Against PDC';
        isAgainstOpenCredit = (paymentTerms == 'Against Open Credit' || paymentTerms == 'Against Open Credit with PDC');
        isPriceVariation    = priceBasis   == 'Price Variation';

        grandTotalExGST  = grandTotalExGST.setScale(2,  RoundingMode.HALF_UP);
        grandTotalIncGST = grandTotalIncGST.setScale(2, RoundingMode.HALF_UP);
        grandTotalWords  = numberToWords(grandTotalIncGST);

        // One pass at the very end so every branch above (materials, special,
        // transportation, lump sums) is covered. Deepanjan (25th July 2026)
        grandTotalIncGSTFmt = formatIndian(grandTotalIncGST);
        totalQuantityDisplay = 0;
        if (lineItems != null) {
            for (LineItemWrapper li : lineItems) {
                li.totalInclGSTFmt = formatIndian(li.totalInclGST);
                // Non-material lines (special/transportation) never set a
                // display value - fall back to their quantity.
                li.itemRateDisplay = (li.unitPrice != null ? li.unitPrice : 0)
                                     - (li.usanceInterest != null ? li.usanceInterest : 0);
                if (li.isFlatCharge) {
                    li.quantityDisplay = null;   // page prints "-"; a lump sum has no tonnage
                } else {
                    if (li.quantityDisplay == null) li.quantityDisplay = li.quantity;
                    if (li.quantityDisplay != null) totalQuantityDisplay += li.quantityDisplay;
                }
            }
        }
        totalQuantityDisplay = totalQuantityDisplay.setScale(WT_SCALE, RoundingMode.HALF_UP);
        Decimal mlTotalWt = 0;
        if (materialListRows != null) {
            for (MaterialListRow r : materialListRows) {
                if (r.totalWeightMt != null) mlTotalWt += r.totalWeightMt;
            }
        }
        materialListTotalWeight = String.valueOf(mlTotalWt.setScale(WT_SCALE, RoundingMode.HALF_UP));
    }

    // ── WRAPPER ──
    public class LineItemWrapper {
        public Integer slNo            { get; set; }
        public String  itemName        { get; set; }
        public String  itemType        { get; set; }   // NEW: 'material' | 'special' | 'transportation'
        public Decimal unitRate        { get; set; }
        public Decimal baseRate        { get; set; }
        public Decimal addedUp         { get; set; }
        public Decimal discountAmt     { get; set; }
        public Decimal unitPrice       { get; set; }
        public Decimal quantity        { get; set; }
        // What the Quantity (MT) column PRINTS: the column's total weight when
        // available, else the quantity. totalExGST / totalInclGST still
        // multiply by quantity - amounts are unchanged by design (Deepanjan,
        // 26th July 2026: "Total Amount e kono change hobe na ... but in
        // Quantity (MT) weight dekhabe").
        public Decimal quantityDisplay { get; set; }
        // What the TOTALS multiply by. Null = use quantity (materials, specials
        // from legacy quotes). Special lines set it to their total weight in MT,
        // and EVERY later retotal (per-MT fold, excluded-column GST rebuild)
        // must honour it - recomputing with quantity was silently reverting the
        // special line to rate x pieces. Deepanjan (27th July 2026)
        public Decimal amountMult      { get; set; }
        public Integer gstPct          { get; set; }
        public Decimal gstAmount       { get; set; }
        public Decimal unitRateInclGST { get; set; }
        public Decimal totalExGST      { get; set; }
        public Decimal totalInclGST    { get; set; }
        // Indian-grouped display copy of totalInclGST (the Decimal above still
        // carries the maths). Deepanjan (25th July 2026)
        public String  totalInclGSTFmt { get; set; }
        // Per-MT loading charge shown in its own column (Per mt Excluded only).
        public Decimal loadingCharge   { get; set; }
        // Per-MT transportation charge column (FOR Per mt Excluded only).
        public Decimal freightCharge   { get; set; }
        // Against LC only: the usance interest per MT, shown in its own
        // Annexure-A column when LC Interest Reflect Separately = Yes.
        public Decimal usanceInterest  { get; set; }
        // Flat (non-MT) charge line - the lump-sum rows. Their quantity of 1
        // is a line count, not a tonnage, so the Quantity (MT) cell prints
        // "-" and the 1 stays out of the TOTAL weight. Null-safe getter so
        // every other line reads false without touching its builder.
        // Deepanjan (29th July 2026)
        // Item Rate cell when the LC usance interest is shown in its own
        // column: the taxable rate MINUS that interest, i.e. everything the
        // rate already carries (base + any Included loading/transportation)
        // except the interest itself. Derived at the very end from unitPrice,
        // so every earlier step - folds, excluded-column retotals, lump sums -
        // is already baked in and none of them needed changing.
        // Deepanjan (29th July 2026)
        public Decimal itemRateDisplay { get; set; }
        public Boolean isFlatCharge {
            get { return isFlatCharge == null ? false : isFlatCharge; }
            set;
        }
    }

    // One printed row of the MATERIAL LIST table (below Annexure-A).
    public class MaterialListRow {
        public Integer slNo          { get; set; }
        public String  groupName     { get; set; }
        public String  riNo          { get; set; }
        public Decimal weightNosKg   { get; set; }
        public Decimal requiredQty   { get; set; }
        public Decimal totalWeightMt { get; set; }
    }

    // ── HELPERS ──
    // Bold the lead-in of a clause ("Rates and Taxes:", "Warranty:", ...) for
    // the PDF. The pages already render clauses with escape="false".
    // Deepanjan (23rd July 2026)
    private static String boldClausePrefix(String t) {
        if (String.isBlank(t)) return t;
        Integer idx = t.indexOf(':');
        if (idx > 0 && idx < 60) {
            return '<b>' + t.substring(0, idx + 1) + '</b>' + t.substring(idx + 1);
        }
        return t;
    }

    // Every printed weight (Annexure Quantity column, material-list rows, both
    // TOTAL rows) uses this many decimals. Flip 3 <-> 4 here and everything
    // stays consistent, because the totals are summed from the ROUNDED rows -
    // never re-rounded from the raw value. Deepanjan (27th July 2026)
    private static final Integer WT_SCALE = 3;

    // Indian digit grouping: last three digits, then pairs - 9168089.31 ->
    // 91,68,089.31. Works for any magnitude (thousand/lakh/crore/above) and
    // keeps exactly two decimals. Deepanjan (25th July 2026)
    private static String formatIndian(Decimal amount) {
        if (amount == null) return '';
        Boolean neg = amount < 0;
        Decimal absAmt = neg ? -amount : amount;
        String fixed = String.valueOf(absAmt.setScale(2, RoundingMode.HALF_UP));
        String intPart = fixed.substringBefore('.');
        String decPart = fixed.substringAfter('.');
        String grouped;
        if (intPart.length() <= 3) {
            grouped = intPart;
        } else {
            grouped = intPart.right(3);
            String rest = intPart.left(intPart.length() - 3);
            while (rest.length() > 2) {
                grouped = rest.right(2) + ',' + grouped;
                rest = rest.left(rest.length() - 2);
            }
            grouped = rest + ',' + grouped;
        }
        return (neg ? '-' : '') + grouped + '.' + decPart;
    }

    // yyyy-MM-dd (how the WEM saves dates) -> dd/MM/yyyy for print. Anything
    // that isn't that shape passes through unchanged. Deepanjan (25th July 2026)
    private static String formatDmy(String iso) {
        if (String.isBlank(iso)) return iso;
        String t = iso.trim();
        if (t.length() >= 10 && t.mid(4,1) == '-' && t.mid(7,1) == '-') {
            return t.mid(8,2) + '/' + t.mid(5,2) + '/' + t.left(4);
        }
        return t;
    }

    private static String strVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return (v != null && String.valueOf(v).trim() != '') ? String.valueOf(v) : '';
    }
    
    private static String defaultIfBlank(String val, String fallback) {
    return String.isNotBlank(val) ? val : fallback;
}

    private static Decimal decVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        if (v == null) return 0;
        String s = String.valueOf(v).trim();
        if (s == '' || s == 'null') return 0;
        try { return Decimal.valueOf(s); } catch (Exception e) { return 0; }
    }

    // ── NUMBER TO WORDS ──
    private static String numberToWords(Decimal amount) {
        if (amount == null || amount == 0) return 'Zero';
        Long rupees = amount.longValue();
        Long paise  = Math.round((amount - rupees) * 100);
        String result = convertToWords(rupees) + ' Rupees';
        if (paise > 0) result += ' and ' + convertToWords(paise) + ' Paise';
        return result + ' Only';
    }

    private static String convertToWords(Long n) {
        if (n == 0) return 'Zero';
        String[] ones = new String[]{
            '','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
            'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen',
            'Seventeen','Eighteen','Nineteen'
        };
        String[] tens = new String[]{
            '','','Twenty','Thirty','Forty','Fifty',
            'Sixty','Seventy','Eighty','Ninety'
        };
        String result = '';
        if (n >= 10000000) { result += convertToWords(n/10000000) + ' Crore ';    n = Math.mod(n, 10000000); }
        if (n >= 100000)   { result += convertToWords(n/100000)   + ' Lakh ';     n = Math.mod(n, 100000);   }
        if (n >= 1000)     { result += convertToWords(n/1000)     + ' Thousand '; n = Math.mod(n, 1000);     }
        if (n >= 100)      { result += ones[(Integer)(n/100)]     + ' Hundred ';  n = Math.mod(n, 100);      }
        if (n >= 20)       { result += tens[(Integer)(n/10)]      + ' ';          n = Math.mod(n, 10);       }
        if (n > 0)         { result += ones[(Integer)n]           + ' ';                                      }
        return result.trim();
    }
}