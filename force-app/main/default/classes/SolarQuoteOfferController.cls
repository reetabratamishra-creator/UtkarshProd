/**
 * SolarQuoteOfferController
 * ─────────────────────────────────────────────────────────────────
 * Dedicated controller extension for solarquoteofferPDF.vfp.
 *
 * Pulled out of the shared QuoteExportController, which also carries
 * Crash Barrier and PEB specific state (beam sections, cb accessories,
 * PEB items, freight, etc.) that this Solar offer page never renders.
 * Only fields/methods actually referenced by the .vfp page live here.
 */
public class SolarQuoteOfferController {

    // ─── Core record / data ────────────────────────────────────
    public Quote               quoteRecord { get; set; }
    public Map<String, Object> jsonData    { get; set; }
    public String              accountName { get; set; }
    public String              contactName { get; set; }

    // ─── Solar-specific merge fields used in the page ──────────
    public String  unitOfMeasurement    { get; set; }
    public String  micronThickness      { get; set; }
    public String  tcSubjectLine        { get; set; }
    public Integer tcAdvancePayment     { get; set; }
    public Integer tcWarrantyMonths     { get; set; }
    public String  tcDeliveryDays       { get; set; }
    public String  validityDateFormatted{ get; set; }
    public String  dynamicPaymentTerms  { get; set; }

    public SolarQuoteOfferController(ApexPages.StandardController stdController) {

        if (!Test.isRunningTest()) {
            stdController.addFields(new List<String>{
                'QuoteNumber', 'Opportunity.Name', 'BillingStreet',
                'BillingCity', 'BillingState', 'BillingPostalCode', 'CreatedDate'
            });
        }

        quoteRecord = [
            SELECT Id, Name, QuoteNumber, Quote_Reference__c, Quote_Value__c, CreatedDate,
                   Account.Name, Contact.Name, Contact.Phone, Contact.Email,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode,
                   Opportunity.Name
            FROM   Quote 
            WHERE  Id = :stdController.getId()
            LIMIT  1 
        ];

        // Validity = 6 months from creation date, formatted dd.MM.yyyy
        DateTime calcDate = DateTime.newInstance(
            quoteRecord.CreatedDate.date().addMonths(6), Time.newInstance(0, 0, 0, 0)
        );
        validityDateFormatted = calcDate.format('dd.MM.yyyy');

        accountName = quoteRecord.Account != null ? quoteRecord.Account.Name : 'Account Name Not Found';
        contactName = (quoteRecord.Contact != null && String.isNotBlank(quoteRecord.Contact.Name))
            ? quoteRecord.Contact.Name : 'N/A';

        // ─── Parse the saved LWC grid JSON ──────────────────────
        jsonData = new Map<String, Object>();
        if (String.isNotBlank(quoteRecord.Quote_Value__c)) {
            try {
                jsonData = (Map<String, Object>) JSON.deserializeUntyped(quoteRecord.Quote_Value__c);
            } catch (Exception e) {
                System.debug('SolarQuoteOfferController JSON parse error: ' + e.getMessage());
                jsonData = new Map<String, Object>();
            }
        }

        // Sensible default so {!jsonData['incoterms']} never renders blank
        ensureKey('incoterms', 'Ex-Works');
        ensureKey('tc_offer_validity', '7 Days');

        unitOfMeasurement = getStr('unit_of_measurement');
        if (String.isBlank(unitOfMeasurement) || unitOfMeasurement == 'null') {
            unitOfMeasurement = 'Weight';
        }

        micronThickness = '85';
        Map<String, Object> configuredSolar = null;
        if (jsonData.get('_configuredSolarStructure') != null) {
            configuredSolar = (Map<String, Object>) jsonData.get('_configuredSolarStructure');
        }
        if (configuredSolar != null && configuredSolar.get('Lines') != null) {
            List<Object> lines = (List<Object>) configuredSolar.get('Lines');
            if (!lines.isEmpty()) {
                Map<String, Object> firstLine = (Map<String, Object>) lines[0];
                Object headMicron = firstLine.get('Effective_Micron__c');
                if (headMicron == null || String.isBlank(String.valueOf(headMicron))) {
                    headMicron = firstLine.get('Micron_Thickness__c');
                }
                if (headMicron != null && String.isNotBlank(String.valueOf(headMicron))
                        && String.valueOf(headMicron) != '-') {
                    micronThickness = String.valueOf(headMicron);
                }
            }
        }

        tcSubjectLine    = getStr('tc_subject_line');
        tcAdvancePayment = getInt('tc_advance_payment');
        tcWarrantyMonths = getInt('tc_warranty_in_months');
        tcDeliveryDays   = getStr('tc_delivery_days');

        buildDynamicPaymentTerms();
    }

    // ─────────────────────────────────────────────
    // Payment terms (Solar branch only — no Crash Barrier logic here)
    // ─────────────────────────────────────────────
    private void buildDynamicPaymentTerms() {
        String termType = getStr('tc_payment_terms_picklist').trim();

        String advPctStr = getStr('tc_advance_payment');
        Integer advPct = advPctStr.isNumeric() ? Integer.valueOf(advPctStr) : 30;
        Integer balPct = 100 - advPct;
        String baseTerm = '<b>' + advPct + '%</b> Advance after issuance of Purchase order and Balance <b>'
            + balPct + '%</b> ';

        if (termType.equalsIgnoreCase('Against LC Before Dispatch')) {
            String buyerDays  = getStr('tc_lc_buyer_interest_days');
            String sellerDays = getStr('tc_lc_seller_interest_days');
            dynamicPaymentTerms = baseTerm + 'Against LC Before Dispatch, Usance interest at Buyer\'s scope- '
                + (String.isNotBlank(buyerDays) ? buyerDays : '0') + ' Days and Seller\'s scope- '
                + (String.isNotBlank(sellerDays) ? sellerDays : '0') + ' Days.';
        } else if (termType.equalsIgnoreCase('Before Dispatch')) {
            dynamicPaymentTerms = baseTerm + 'Before Dispatch.';
        } else if (termType.equalsIgnoreCase('Against VFS')) {
            String vfsDays = getStr('tc_vfs_seller_interest');
            dynamicPaymentTerms = baseTerm + 'Against VFS for - '
                + (String.isNotBlank(vfsDays) ? vfsDays : '0') + ' Days.';
        } else if (termType.equalsIgnoreCase('Against PDC')) {
            String pdcDays = getStr('tc_PDC_interest');
            dynamicPaymentTerms = String.isNotBlank(pdcDays)
                ? baseTerm + 'Against PDC for - ' + pdcDays + ' Days.'
                : baseTerm + 'Against PDC.';
        } else if (termType.equalsIgnoreCase('Against Open Credit')) {
            String openCreditDays = getStr('tc_open_credit_days');
            dynamicPaymentTerms = baseTerm + 'Against Open Credit '
                + (String.isNotBlank(openCreditDays) ? openCreditDays : '0') + ' Days.';
        } else {
            dynamicPaymentTerms = '100% advance along with PI.';
        }
    }

    // ─────────────────────────────────────────────
    // Signature image lookup — Signature_{UserAlias} static resource
    // ─────────────────────────────────────────────
    public Boolean getHasSignature() {
        User currentUser = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String resourceName = 'Signature_' + currentUser.Alias;
        Integer resourceCount = [SELECT Count() FROM StaticResource WHERE Name = :resourceName LIMIT 1];
        return resourceCount > 0;
    }

    // ─────────────────────────────────────────────
    // Structure line items — read directly from the LWC flat-grid JSON
    // (mirrors <apex:repeat value="{!solarItems}"> in the page)
    // ─────────────────────────────────────────────
    public List<SolarItem> getSolarItems() {
        List<SolarItem> items = new List<SolarItem>();
        if (jsonData == null) return items;

        Map<String, Object> configuredSolar = null;
        if (jsonData.get('_configuredSolarStructure') != null) {
            configuredSolar = (Map<String, Object>) jsonData.get('_configuredSolarStructure');
        }

        if (configuredSolar != null && configuredSolar.get('Lines') != null) {
            List<Object> lines = (List<Object>) configuredSolar.get('Lines');
            for (Object lineObj : lines) {
                Map<String, Object> line = (Map<String, Object>) lineObj;
                SolarItem item = new SolarItem();
                
                item.material   = String.valueOf(line.get('Material__c'));
                item.grade      = String.valueOf(line.get('Material_Grade__c'));
                item.thickness  = String.valueOf(line.get('Thickness__c'));

                /*
                 * Micron shown on the offer. Lines saved since 1st August 2026
                 * carry Effective_Micron__c - the picked value plus the +20
                 * minimum-to-average conversion when that checkbox was ticked
                 * (client rule: 70 Minimum = 90 Average). Older lines only have
                 * Micron_Thickness__c, so fall back to it.
                 */
                Object effMicron = line.get('Effective_Micron__c');
                item.micron = (effMicron != null && String.isNotBlank(String.valueOf(effMicron)))
                            ? String.valueOf(effMicron)
                            : String.valueOf(line.get('Micron_Thickness__c'));
                
                item.weight     = getSafeDecimal(line.get('Total_Weight__c'));
                item.unitWeight = getSafeDecimal(line.get('Unit_Weight__c'));
                item.quantity   = getSafeDecimal(line.get('Quantity__c'));
                
                Decimal lineUnitPrice = getSafeDecimal(line.get('Unit_Price__c'));
                
                // Rate for MT table
                item.rate = lineUnitPrice; 
                
                // For PCS table, lineUnitPrice is already the Piece Rate!
                // The PDF expects unitCost to be the MT rate.
                if (item.unitWeight > 0) {
                    item.unitCost = lineUnitPrice / item.unitWeight; 
                } else {
                    item.unitCost = lineUnitPrice;
                }
                
                if (item.quantity == 0) item.quantity = 1;
                
                items.add(item);
            }
        }

        return items;
    }
    // 
    // Dynamic text for PDF Introduction based on material
    // 
    public String getDynamicSubjectHeader() {
        for (SolarItem item : getSolarItems()) {
            if (item.material != null) {
                String mat = item.material.toUpperCase();
                if (mat.contains('RSJ')) return 'Supply of RSJ POLE';
                if (mat.contains('PIER') || mat.contains('BEAM') || mat.contains('HBM') || mat.contains('WBM')) return 'of Piers/C sections';
            }
        }
        return 'Supply of MMS STRUCTURE';
    }

    public String getDynamicSubjectBody() {
        for (SolarItem item : getSolarItems()) {
            if (item.material != null) {
                String mat = item.material.toUpperCase();
                if (mat.contains('RSJ')) return 'RSJ Pole';
                if (mat.contains('PIER') || mat.contains('BEAM') || mat.contains('HBM') || mat.contains('WBM')) return 'H Beam/Piers/C sections';
            }
        }
        return 'Solar MMS Structure';
    }

    public String getDynamicSupplyOfText() {
        for (SolarItem item : getSolarItems()) {
            if (item.material != null) {
                String mat = item.material.toUpperCase();
                if (mat.contains('RSJ')) return 'RSJ Pole';
                if (mat.contains('PIER') || mat.contains('BEAM') || mat.contains('HBM') || mat.contains('WBM')) return 'H Beam/Piers/C Sections';
            }
        }
        return 'Solar MMS Structure';
    }
    // ─────────────────────────────────────────────
    // JSON helpers
    // ─────────────────────────────────────────────
    private void ensureKey(String key, String defaultValue) {
        if (!jsonData.containsKey(key) || jsonData.get(key) == null
            || String.isBlank(String.valueOf(jsonData.get(key)))) {
            jsonData.put(key, defaultValue);
        }
    }

    private String getStr(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        return v != null ? String.valueOf(v) : '';
    }

    private Decimal getDec(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        if (v == null || String.valueOf(v).trim() == '') return 0;
        try { return Decimal.valueOf(String.valueOf(v)); }
        catch (Exception e) { return 0; }
    }

    private Integer getInt(String key) {
        Object v = jsonData != null ? jsonData.get(key) : null;
        if (v == null || String.valueOf(v).trim() == '') return 0;
        try { return Integer.valueOf(String.valueOf(v)); }
        catch (Exception e) { return 0; }
    }

    private Decimal getSafeDecimal(Object val) {
        if (val == null || String.valueOf(val) == '') return 0;
        try { return Decimal.valueOf(String.valueOf(val)); }
        catch (Exception e) { return 0; }
    }

    // ─────────────────────────────────────────────
    // Wrapper — only the fields solarquoteofferPDF.vfp actually reads
    // ─────────────────────────────────────────────
    public class SolarItem {
        public String  material   { get; set; }
        public String  grade      { get; set; }
        public String  thickness  { get; set; }
        public String  micron     { get; set; }
        public Decimal weight     { get; set; }
        public Decimal rate       { get; set; }
        public Decimal quantity   { get; set; }
        public Decimal unitWeight { get; set; }
        public Decimal unitCost   { get; set; }
    }
}