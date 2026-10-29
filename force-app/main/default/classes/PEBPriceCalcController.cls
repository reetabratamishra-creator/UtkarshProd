/**
 * PEBPriceCalcController
 * ----------------------
 * Backend for the "PEB Price Calculator" LWC that lives as a tab on the
 * Opportunity Lightning Record Page.
 *
 * Responsibilities:
 *   1. getCalculatorData  - loads the rate metadata (Price_Calculator__mdt),
 *                           any previously saved calculation, and best-effort
 *                           section totals + Note line items read from the
 *                           "Design Estimation.pdf" attached to the Opportunity.
 *                           When several files share that name, the most
 *                           recently uploaded one is used.
 *   2. saveCalculation    - persists the calculation JSON on the Opportunity so
 *                           it can be re-opened and rendered as a PDF.
 *
 * ---------------------------------------------------------------------------
 * ESTIMATION LAYOUT (revised, simplified format)
 * ---------------------------------------------------------------------------
 *   A  Built-up (ASTM A572 ...)                 -> single line, value in the
 *   B  COLD FORMED (ASTM A653 ...)                 "Total weight (kg)" column
 *   C  HARD WARE (ASTM A307/A325)               -> itemised, ends with TOTAL
 *        1 Anchor bolts .................. C1
 *        2 Primary connection bolts
 *        3 Secondary connection bolts
 *        4 Non-standard anchor bolts
 *        TOTAL ....... CRest = TOTAL - C1
 *   D  Hot Rolled Section                       -> single line
 *   E  Deck Sheet (Sqm)                         -> single line
 *   F  Galvalume Sheet - Roof (Sqm)             -> single line
 *   G  Galvalume Sheet - Wall (Sqm)             -> single line
 *   H  Packing Material (Kg)                    -> single line
 *   Note
 *        1 <description> ...  -> B3 Special Items (rate entered on screen)
 *        2 <description> ...
 *
 * Keys returned in sectionTotals: A, B, C1, CRest, D, E, F, G, H.
 *
 * Text extraction from a PDF in pure Apex only succeeds when the PDF stores its
 * text uncompressed, so everything below is a best-effort PRE-FILL; the LWC
 * falls back to reading the same file with pdf.js in the browser, and every
 * value stays editable before the user calculates.
 */
public with sharing class PEBPriceCalcController {

    // DeveloperName of the Price_Calculator__mdt record that holds the PEB rates.
    private static final String RATE_CONFIG_DEV_NAME = 'PEB_Rate_Config';

    // Title (without extension) of the estimation file to read from the Opportunity.
    private static final String ESTIMATION_TITLE = 'Design Estimation';

    // Every key the LWC expects back in sectionTotals.
    private static final List<String> TOTAL_KEYS = new List<String>{
        'A', 'B', 'C1', 'CRest', 'D', 'E', 'F', 'G', 'H'
    };

    /* ===================================================================== */
    /* Wrappers returned to the LWC                                          */
    /* ===================================================================== */
    public class CalculatorData {
        @AuraEnabled public String rateConfigJson;      // JSON_Payload__c from metadata
        @AuraEnabled public Decimal gstPercent;         // default GST from metadata
        @AuraEnabled public String savedJson;           // previously saved calculation (or null)
        @AuraEnabled public String estimationFileName;  // name of the PDF that was read (or null)
        @AuraEnabled public Boolean estimationReadable; // true when text could be extracted
        @AuraEnabled public Map<String, Decimal> sectionTotals; // best-effort pre-fill
        @AuraEnabled public List<SpecialItem> specialItems;     // rows under "Note"
    }

    /** One line item picked up from the Note section of the estimation. */
    public class SpecialItem {
        @AuraEnabled public String description;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal qty;
    }

    /* ===================================================================== */
    /* Public entry point                                                    */
    /* ===================================================================== */
    @AuraEnabled
    public static CalculatorData getCalculatorData(Id opportunityId) {
        try {
            CalculatorData data = new CalculatorData();

            // --- 1. Rate metadata ------------------------------------------------
            List<Price_Calculator__mdt> configs = [
                SELECT DeveloperName, JSON_Payload__c, GST__c
                FROM Price_Calculator__mdt
                WHERE DeveloperName = :RATE_CONFIG_DEV_NAME
                LIMIT 1
            ];
            if (configs.isEmpty() || String.isBlank(configs[0].JSON_Payload__c)) {
                throw new AuraHandledException(
                    'Rate configuration not found. Please create the "PEB_Rate_Config" ' +
                    'record under the Price_Calculator custom metadata type.'
                );
            }
            data.rateConfigJson = configs[0].JSON_Payload__c;
            data.gstPercent = configs[0].GST__c != null ? configs[0].GST__c : 18;

            // --- 2. Previously saved calculation --------------------------------
            if (opportunityId != null) {
                List<Opportunity> opps = [
                    SELECT Id, Price_Calculation_JSON__c
                    FROM Opportunity
                    WHERE Id = :opportunityId
                    LIMIT 1
                ];
                if (!opps.isEmpty()) {
                    data.savedJson = opps[0].Price_Calculation_JSON__c;
                }
            }

            // --- 3. Best-effort read of the Design Estimation.pdf blob ----------
            data.sectionTotals = defaultSectionTotals();
            data.specialItems = new List<SpecialItem>();
            data.estimationReadable = false;
            ContentVersion cv = findEstimationPdf(opportunityId);
            if (cv != null) {
                data.estimationFileName = cv.Title + '.' + cv.FileExtension;
                String text = blobToText(cv.VersionData);
                if (String.isNotBlank(text)) {
                    data.estimationReadable = true;
                    data.sectionTotals = parseSectionTotals(text);
                    data.specialItems = parseSpecialItems(text);
                }
            }

            return data;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load calculator data: ' + e.getMessage());
        }
    }

    /* ===================================================================== */
    /* Return the estimation PDF bytes so the LWC can read it client-side.   */
    /* Used when server-side text extraction failed (compressed PDF).        */
    /* ===================================================================== */
    @AuraEnabled
    public static String getEstimationFileBase64(Id opportunityId) {
        try {
            ContentVersion cv = findEstimationPdf(opportunityId);
            if (cv == null || cv.VersionData == null) {
                return null;
            }
            return EncodingUtil.base64Encode(cv.VersionData);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load estimation file: ' + e.getMessage());
        }
    }

    /* ===================================================================== */
    /* Return the Building Description PDF bytes for client-side extraction. */
    /* ===================================================================== */
    @AuraEnabled
    public static String getBuildingDescriptionFileBase64(Id opportunityId, Id quoteId) {
        try {
            ContentVersion cv = findBuildingDescriptionPdf(opportunityId, quoteId);
            if (cv == null || cv.VersionData == null) {
                return null;
            }
            return EncodingUtil.base64Encode(cv.VersionData);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load building description file: ' + e.getMessage());
        }
    }

    /* ===================================================================== */
    /* Persist the calculation                                               */
    /* ===================================================================== */
    @AuraEnabled
    public static void saveCalculation(Id opportunityId, String payload) {
        try {
            Opportunity opp = new Opportunity(
                Id = opportunityId,
                Price_Calculation_JSON__c = payload
            );
            update opp;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to save calculation: ' + e.getMessage());
        }
    }

    /**
     * Clears the Price_Calculation_JSON__c field on the Opportunity so that
     * staging data used for PDF generation does not linger on the record.
     */
    @AuraEnabled
    public static void clearCalculation(Id opportunityId) {
        try {
            if (opportunityId == null) {
                return;
            }
            Opportunity opp = new Opportunity(
                Id = opportunityId,
                Price_Calculation_JSON__c = null
            );
            update opp;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to clear calculation: ' + e.getMessage());
        }
    }

    /**
     * Renders the PEBPriceCalcPDF Visualforce page for the Opportunity and
     * returns it as a base64 string so the LWC can trigger a browser download.
     * The calculation JSON must already be saved (call saveCalculation first).
     */
    @AuraEnabled
    public static String generatePdf(Id opportunityId) {
        try {
            PageReference pdf = Page.PEBPriceCalcPDF;
            pdf.getParameters().put('id', opportunityId);
            Blob body = Test.isRunningTest()
                ? Blob.valueOf('TEST-PDF')
                : pdf.getContentAsPDF();
            return EncodingUtil.base64Encode(body);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to generate PDF: ' + e.getMessage());
        }
    }

    /* ===================================================================== */
    /* File lookup                                                           */
    /* ===================================================================== */

    /**
     * Locate the "Design Estimation.pdf" linked to the Opportunity.
     * When several files share that name, the most recently uploaded one wins.
     */
    private static ContentVersion findEstimationPdf(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
        ]) {
            docIds.add(link.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return null;
        }

        String titlePattern = ESTIMATION_TITLE + '%';   // 'Design Estimation%'

        // IsLatest = true           -> newest version of each document
        // ORDER BY CreatedDate DESC -> newest upload first
        List<ContentVersion> pdfs = [
            SELECT Id, Title, FileExtension, VersionData, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND IsLatest = true
              AND FileExtension = 'pdf'
              AND Title LIKE :titlePattern
            ORDER BY CreatedDate DESC
        ];
        if (pdfs.isEmpty()) {
            return null;
        }

        // Exact (case/space-insensitive) name match takes priority; the list is
        // already newest-first, so the first hit is the latest upload.
        String target = ESTIMATION_TITLE.toLowerCase();
        for (ContentVersion cv : pdfs) {
            if (cv.Title != null && cv.Title.trim().toLowerCase() == target) {
                return cv;
            }
        }

        // Otherwise the newest file whose name starts with "Design Estimation"
        // (covers "Design Estimation (1)", "Design Estimation v2", etc.).
        return pdfs[0];
    }

    /**
     * Locate the "Building Description.pdf" or QRF document linked to the Opportunity or Quote.
     * When several files share that name, the most recently uploaded one wins.
     */
    public static ContentVersion findBuildingDescriptionPdf(Id opportunityId, Id quoteId) {
        Set<Id> entityIds = new Set<Id>();
        if (opportunityId != null) {
            entityIds.add(opportunityId);
            String oppStr = String.valueOf(opportunityId);
            if (oppStr.startsWith('0Q0')) {
                for (Quote q : [SELECT OpportunityId FROM Quote WHERE Id = :opportunityId LIMIT 1]) {
                    if (q.OpportunityId != null) {
                        entityIds.add(q.OpportunityId);
                    }
                }
            }
        }
        if (quoteId != null) {
            entityIds.add(quoteId);
            for (Quote q : [SELECT OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1]) {
                if (q.OpportunityId != null) {
                    entityIds.add(q.OpportunityId);
                }
            }
        }
        if (entityIds.isEmpty()) {
            return null;
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
        ]) {
            docIds.add(link.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return null;
        }

        List<ContentVersion> pdfs = [
            SELECT Id, Title, FileExtension, VersionData, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND IsLatest = true
              AND FileExtension = 'pdf'
              AND (Title LIKE '%Building%Description%' OR Title LIKE '%Building Description%' OR Title LIKE '%QRF%' OR Title LIKE '%QFR%')
            ORDER BY CreatedDate DESC
        ];
        if (pdfs.isEmpty()) {
            return null;
        }

        for (ContentVersion cv : pdfs) {
            if (cv.Title != null && cv.Title.trim().toLowerCase().contains('building description')) {
                return cv;
            }
        }
        return pdfs[0];
    }

    /** Decode a PDF blob to text. Returns null when the bytes are not UTF-8 text. */
    private static String blobToText(Blob body) {
        if (body == null) {
            return null;
        }
        try {
            String text = body.toString();
            return String.isBlank(text) ? null : text;
        } catch (Exception e) {
            // Binary / compressed PDF streams are not decodable in Apex.
            return null;
        }
    }

    /* ===================================================================== */
    /* Parsing                                                               */
    /* ===================================================================== */

    private static Map<String, Decimal> defaultSectionTotals() {
        Map<String, Decimal> m = new Map<String, Decimal>();
        for (String k : TOTAL_KEYS) {
            m.put(k, 0);
        }
        return m;
    }

    /**
     * Best-effort extraction of the section values from the estimation text.
     *
     * In the revised layout each section is a single row and its value sits in
     * the right-most ("Total weight") column. Because that value is printed a
     * fraction above the section label, a linear text dump usually renders it
     * just BEFORE the label - so valueForSection() looks backwards first and
     * only then forwards. Anything it cannot find confidently stays 0 for the
     * user to complete manually.
     */
    private static Map<String, Decimal> parseSectionTotals(String rawText) {
        Map<String, Decimal> totals = defaultSectionTotals();
        String text = rawText.replaceAll('[\\r\\n]+', ' ').replaceAll(' +', ' ');

        totals.put('A', valueForSection(text, new List<String>{ 'Built-up', 'Built up', 'A572' }));
        totals.put('B', valueForSection(text, new List<String>{ 'COLD FORMED', 'Cold Formed', 'A653' }));
        totals.put('D', valueForSection(text, new List<String>{ 'Hot Rolled', 'Misc. HR', 'IS-2062' }));
        totals.put('E', valueForSection(text, new List<String>{ 'Deck Sheet', 'DECKING', 'Mezzanine deck' }));
        totals.put('F', valueForSection(text, new List<String>{ 'Galvalume Sheet - Roof', 'Galvalume Sheet -Roof' }));
        totals.put('G', valueForSection(text, new List<String>{ 'Galvalume Sheet - Wall', 'Galvalume Sheet -Wall' }));
        totals.put('H', valueForSection(text, new List<String>{ 'Packing Material', 'Packing' }));

        // --- Section C (hardware) ------------------------------------------
        // C1    = the value on the first "Anchor bolts" line.
        // CRest = remaining bolt lines (hardware TOTAL - C1 when TOTAL includes C1,
        //         or hardware TOTAL directly when TOTAL <= C1 represents connection bolts).
        totals.put('C1', firstNumberAfter(text, new List<String>{ 'Anchor bolts', 'Anchor Bolt' }));
        Decimal hardwareTotal = firstTotalAfter(text, new List<String>{ 'HARD WARE', 'HARDWARE', 'A307' });
        if (hardwareTotal != null && hardwareTotal > 0) {
            Decimal c1 = totals.get('C1');
            Decimal rest;
            if (c1 != null && c1 > 0 && hardwareTotal > c1) {
                rest = hardwareTotal - c1;
            } else {
                rest = hardwareTotal;
            }
            totals.put('CRest', rest > 0 ? rest : 0);
        }

        // Null-safety: never return nulls.
        for (String k : totals.keySet()) {
            if (totals.get(k) == null) {
                totals.put(k, 0);
            }
        }
        return totals;
    }

    /**
     * Best-effort extraction of the line items printed under the "Note" heading
     * at the bottom of the estimation. Each item carries a description, a unit
     * and a quantity/weight; the RATE is always entered by the user on screen.
     *
     * Two shapes are supported:
     *   1. columnar   "1 Down spout pipe 110 mm dia   360   Mtr"
     *   2. inline     "down spout pipe 110mm dia pvc @ 360m"
     */
    private static List<SpecialItem> parseSpecialItems(String rawText) {
        // Special items are no longer auto-extracted from the PDF.
        // Users can add special items manually on the screen if needed.
        return new List<SpecialItem>();
    }

    /** Turns one Note line into a SpecialItem. */
    private static SpecialItem toSpecialItem(String raw) {
        String line = raw == null ? '' : raw.trim();
        if (String.isBlank(line)) {
            return null;
        }
        SpecialItem si = new SpecialItem();
        si.qty = 0;
        si.unit = 'No.s';

        // Drop a leading serial number ("1 Example" / "1Example").
        line = line.replaceFirst('^[0-9]{1,3}[\\.\\)]?\\s*', '');

        // Shape 2: "... @ 360m"
        Matcher at = Pattern.compile('(?i)@\\s*([0-9][0-9,\\.]*)\\s*([a-zA-Z\\.]*)').matcher(line);
        if (at.find()) {
            si.qty = nvl(toDecimal(at.group(1)));
            si.unit = normaliseUnit(at.group(2));
            line = (line.substring(0, at.start()) + ' ' + line.substring(at.end())).trim();
        } else {
            // Shape 1: trailing "<qty> <unit>" or "<unit> <qty>" columns.
            Matcher qu = Pattern.compile('(?i)([0-9][0-9,\\.]*)\\s+(Sqm|Sq\\.M|Kg|Nos|No\\.s|Mtr|RM|M)\\b').matcher(line);
            Matcher uq = Pattern.compile('(?i)\\b(Sqm|Sq\\.M|Kg|Nos|No\\.s|Mtr|RM|M)\\s+([0-9][0-9,\\.]*)').matcher(line);
            if (qu.find()) {
                si.qty = nvl(toDecimal(qu.group(1)));
                si.unit = normaliseUnit(qu.group(2));
                line = (line.substring(0, qu.start()) + ' ' + line.substring(qu.end())).trim();
            } else if (uq.find()) {
                si.unit = normaliseUnit(uq.group(1));
                si.qty = nvl(toDecimal(uq.group(2)));
                line = (line.substring(0, uq.start()) + ' ' + line.substring(uq.end())).trim();
            }
        }

        si.description = line.replaceAll(' +', ' ').trim();
        return String.isBlank(si.description) ? null : si;
    }

    /** Maps a raw unit token onto the calculator's picklist values. */
    private static String normaliseUnit(String raw) {
        String u = raw == null ? '' : raw.toLowerCase().replaceAll('[^a-z]', '');
        if (String.isBlank(u)) {
            return 'No.s';
        }
        if (new Set<String>{ 'sqm', 'sqmt', 'sqmtr', 'm2', 'sq' }.contains(u)) {
            return 'Sq.M';
        }
        if (new Set<String>{ 'kg', 'kgs' }.contains(u)) {
            return 'Kg';
        }
        if (new Set<String>{ 'm', 'mt', 'mtr', 'mtrs', 'rm', 'rmt', 'metre', 'meter' }.contains(u)) {
            return 'Mtr';
        }
        return 'No.s';
    }

    /**
     * Value printed on a single-line section row. The number may sit just before
     * the label (common in a linear text dump of this layout) or just after it,
     * so both directions are tried - nearest wins.
     */
    private static Decimal valueForSection(String text, List<String> anchors) {
        for (String anchor : anchors) {
            Integer idx = text.indexOf(anchor);
            if (idx < 0) {
                continue;
            }
            // Look backwards over a short window for the last number.
            Integer frm = Math.max(0, idx - 80);
            String head = text.substring(frm, idx);
            Decimal back = lastNumberIn(head);
            if (back != null && back > 0) {
                return back;
            }
            // Otherwise take the LAST number after the label to bypass inline specifications like "Grade 50".
            Decimal fwd = lastNumberIn(text.substring(idx + anchor.length(),
                Math.min(text.length(), idx + anchor.length() + 120)));
            if (fwd != null && fwd > 0) {
                return fwd;
            }
        }
        return null;
    }

    private static Decimal lastNumberIn(String s) {
        Matcher m = Pattern.compile('([0-9][0-9,]*(?:\\.[0-9]+)?)').matcher(s);
        Decimal last = null;
        while (m.find()) {
            Decimal d = toDecimal(m.group(1));
            if (d != null) {
                last = d;
            }
        }
        return last;
    }

    private static Decimal firstNumberIn(String s) {
        Matcher m = Pattern.compile('([0-9][0-9,]*(?:\\.[0-9]+)?)').matcher(s);
        return m.find() ? toDecimal(m.group(1)) : null;
    }

    /** Finds the number following the first "TOTAL" that appears after any anchor. */
    private static Decimal firstTotalAfter(String text, List<String> anchors) {
        for (String anchor : anchors) {
            Integer idx = text.indexOf(anchor);
            if (idx < 0) {
                continue;
            }
            String tail = text.substring(idx);
            Matcher m = Pattern.compile('(?i)TOTAL[^0-9]{0,12}([0-9][0-9,\\.]*)').matcher(tail);
            if (m.find()) {
                return toDecimal(m.group(1));
            }
        }
        return null;
    }

    /**
     * Finds the Total-weight value on the first "Anchor bolts" line. The line
     * reads "1 Anchor bolts 1.00 kg 2,539.00 2,539", so the wanted number is the
     * last one on that fragment rather than the first.
     */
    private static Decimal firstNumberAfter(String text, List<String> anchors) {
        for (String anchor : anchors) {
            Integer idx = text.indexOf(anchor);
            if (idx < 0) {
                continue;
            }
            Integer start = idx + anchor.length();
            Integer stop = Math.min(text.length(), start + 60);
            String frag = text.substring(start, stop);
            // Cut the fragment at the next line item so we stay on this row.
            Matcher nxt = Pattern.compile('(?i)(Primary|Secondary|Non-standard|TOTAL)').matcher(frag);
            if (nxt.find()) {
                frag = frag.substring(0, nxt.start());
            }
            Decimal v = lastNumberIn(frag);
            if (v != null) {
                return v;
            }
        }
        return null;
    }

    private static Decimal nvl(Decimal d) {
        return d == null ? 0 : d;
    }

    private static Decimal toDecimal(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String cleaned = raw.replace(',', '');
        try {
            return Decimal.valueOf(cleaned);
        } catch (Exception e) {
            return null;
        }
    }
}