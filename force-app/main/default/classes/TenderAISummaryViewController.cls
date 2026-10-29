public with sharing class TenderAISummaryViewController {

    public Tender__c tender { get; private set; }
    public Boolean parseFailed { get; private set; }
    public String parseErrorMessage { get; private set; }
    public String recordId { get; private set; }
    public String rawFallback { get; private set; }

    public class SummaryRow {
        public String label { get; set; }
        public String value { get; set; }
        public SummaryRow(String label, String value) {
            this.label = label;
            this.value = String.isBlank(value) ? '-' : value;
        }
    }

    public class SummarySection {
        public String title { get; set; }
        public List<SummaryRow> rows { get; set; }
        public SummarySection(String title, List<SummaryRow> rows) {
            this.title = title;
            this.rows = rows;
        }
    }

    private class SectionDef {
        String title;
        List<String> keys;
        SectionDef(String title, List<String> keys) {
            this.title = title;
            this.keys = keys;
        }
    }

    public List<SummarySection> sections { get; private set; }

    public TenderAISummaryViewController() {
        parseFailed = false;
        sections = new List<SummarySection>();

        recordId = ApexPages.currentPage().getParameters().get('id');
        if (recordId == null) {
            parseFailed = true;
            parseErrorMessage = 'No Tender record Id was provided in the URL.';
            return;
        }

        List<Tender__c> results = [
            SELECT Id, Name, External_Tender_Id__c,
                   Tender_AI_Summary_JSON_1__c,
                   Tender_AI_Summary_JSON_2__c,
                   Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (results.isEmpty()) {
            parseFailed = true;
            parseErrorMessage = 'Tender record not found.';
            return;
        }

        tender = results[0];

        String part1 = tender.Tender_AI_Summary_JSON_1__c;
        String part2 = tender.Tender_AI_Summary_JSON_2__c;
        String fullJson = (part1 != null ? part1 : '') + (part2 != null ? part2 : '');

        if (String.isBlank(fullJson)) {
            parseFailed = true;
            parseErrorMessage = 'No AI Summary data has been stored for this Tender yet.';
            return;
        }

        // Rich Text Area fields store HTML-encoded content - decode first.
        fullJson = unescapeHtml(fullJson);

        Map<String, Object> dataObj = tryParseData(fullJson);

        if (dataObj == null) {
            parseFailed = true;
            parseErrorMessage = 'Could not parse this as JSON - showing raw stored value below.';
            rawFallback = fullJson;
            return;
        }

        buildSections(dataObj);
    }

    // Parses the JSON and returns Data[0] as a Map. Attempts a simple
    // repair (closing off dangling braces/brackets) if the stored value
    // was truncated mid-field due to overflowing the two text fields.
    private Map<String, Object> tryParseData(String jsonText) {
        Map<String, Object> result = attemptParse(jsonText);
        if (result != null) {
            return result;
        }

        // Try a best-effort repair: cut back to the last fully-closed
        // "key": value pair and re-close the JSON structure.
        String repaired = repairTruncatedJson(jsonText);
        if (repaired != null) {
            result = attemptParse(repaired);
        }
        return result;
    }

    private Map<String, Object> attemptParse(String jsonText) {
        try {
            Object parsed = JSON.deserializeUntyped(jsonText);
            if (!(parsed instanceof Map<String, Object>)) {
                return null;
            }
            Map<String, Object> root = (Map<String, Object>) parsed;
            Object dataVal = root.get('Data');
            if (dataVal instanceof List<Object>) {
                List<Object> dataList = (List<Object>) dataVal;
                if (!dataList.isEmpty() && dataList[0] instanceof Map<String, Object>) {
                    return (Map<String, Object>) dataList[0];
                }
            }
            // Some responses may not be wrapped in "Data" - fall back to
            // treating the root object itself as the field map.
            return root;
        } catch (Exception e) {
            return null;
        }
    }

    // Naive truncation repair: trims the string back to the last comma
    // that follows a complete "key": "value" (or value) pair, then
    // appends enough closing brackets to balance what's open.
    private String repairTruncatedJson(String jsonText) {
        Integer lastGoodComma = jsonText.lastIndexOf(',');
        if (lastGoodComma < 0) {
            return null;
        }

        String trimmed = jsonText.substring(0, lastGoodComma);

        Integer openBraces = 0, openBrackets = 0;
        Boolean inString = false;
        Boolean escaped = false;
        for (Integer i = 0; i < trimmed.length(); i++) {
            String c = trimmed.substring(i, i + 1);
            if (escaped) { escaped = false; continue; }
            if (c == '\\') { escaped = true; continue; }
            if (c == '"') { inString = !inString; continue; }
            if (inString) { continue; }
            if (c == '{') openBraces++;
            if (c == '}') openBraces--;
            if (c == '[') openBrackets++;
            if (c == ']') openBrackets--;
        }

        String closer = '';
        for (Integer i = 0; i < openBraces; i++) closer += '}';
        for (Integer i = 0; i < openBrackets; i++) closer += ']';

        return trimmed + closer;
    }

    private void buildSections(Map<String, Object> dataObj) {
        for (SectionDef def : getSectionDefs()) {
            List<SummaryRow> rows = new List<SummaryRow>();
            for (String key : def.keys) {
                Object val = dataObj.containsKey(key) ? dataObj.get(key) : null;
                rows.add(new SummaryRow(prettifyLabel(key), formatValue(val)));
            }
            sections.add(new SummarySection(def.title, rows));
        }
    }

    // Fixed field order/grouping - matches the keys the AI Summary JSON
    // actually contains. Add/remove keys here only; the page never
    // needs to change.
    private List<SectionDef> getSectionDefs() {
        List<SectionDef> defs = new List<SectionDef>();

        defs.add(new SectionDef('Tender Basic Details', new List<String>{
            'Tender_Id','GEM_Bid_number','Organisation_Tender_ID','Project_name',
            'Type_of_Bid','BOQ_Title'
        }));

        defs.add(new SectionDef('Important Dates', new List<String>{
            'Bid_End_Date_Time','Bid_Opening_Date_Time','Bid_Offer_Validity_From_EndDate',
            'Bid_Validity','Last_date_for_Seeking_Clarification','Time_Allowed_for_Clarifications',
            'Due_date_and_time_of_sending_hardcopy_at_site'
        }));

        defs.add(new SectionDef('Organisation Details', new List<String>{
            'Ministry_State_Name','Department_Name','Organisation_Name','Office_Name',
            'State','Delivery_district','Delivery_Location','Location','Site_location'
        }));

        defs.add(new SectionDef('Item / Quantity Details', new List<String>{
            'Item_Category','Category','Products','Total_Quantity','Quantity_of_job',
            'Quantity_Details','Contract_Period','Contract_period',
            'Completion_period','Completion_Period'
        }));

        defs.add(new SectionDef('Eligibility Criteria', new List<String>{
            'Eligibility_Criteria','Oem_Average_Turnover','Min_Avg_Annual_Turnover',
            'Years_Of_Past_Experience','Past_Experience_Required','MSE_Exemption',
            'Startup_Exemption','MII_Compliance','MII_Purchase_Preference',
            'MSE_Purchase_Preference','Naxal_Affected_Area',
            'Joint_Venture_OR_Consortium_OR_JV','Scope_Classification'
        }));

        defs.add(new SectionDef('Financial & EMD Details', new List<String>{
            'Estimated_Bid_Value','Estimated_Cost','Emd_Amount','EMD_Value',
            'Emd_Instrument_Type','Mode_of_submitting_EMD','Emd_Mode_Type',
            'RA_applicable_or_not','Bid_to_Ra_Enabled','Ra_Qualification_Rule',
            'Reverse_Auction_Qualification_Rule','BG_exempt_or_not',
            'ePBG_Percentage','ePBG_Duration_Months','Performance_Bank_Guarantee',
            'Document_Fees','Payment_terms'
        }));

        defs.add(new SectionDef('Evaluation Details', new List<String>{
            'Evaluation_Method','Advisory_Bank','Evaluation_Criteria_Technical_OR_Financial',
            'Evaluation_Weightage'
        }));

        defs.add(new SectionDef('Bid Submission Details', new List<String>{
            'Bid_Details','Hard_Copy_Submission','Courier_Speed_Post_Submission',
            'Document_required_from_seller','Affidavit_notarized_documents'
        }));

        defs.add(new SectionDef('Scope of Work', new List<String>{
            'Short_Summary_Scope_Of_work','Work_to_be_Done_Site_or_Workshop',
            'Inspection_Required','Site_Visit_Requirement','Mandatory_Sample_Submission'
        }));

        defs.add(new SectionDef('Pre-Bid Meeting', new List<String>{
            'Pre_Bid_Meeting','Mandatory_Pre_bid_Meeting','Pre_Bid_Meeting_Details'
        }));

        defs.add(new SectionDef('Terms & Clauses', new List<String>{
            'Mediation_Clause','Arbitration_Clause','Levy_of_Penalty',
            'Defect_Liability_Period',
            'Clause_for_continuous_running_machine_after_commissioning',
            'Generation_loss_clause_in_tender','Past_Performance'
        }));

        defs.add(new SectionDef('Contact & Checklist', new List<String>{
            'Contact_Details','Checklist'
        }));

        return defs;
    }

    private String prettifyLabel(String key) {
        if (String.isBlank(key)) return key;
        String spaced = key.replace('_', ' ');
        List<String> words = spaced.split(' ');
        List<String> out = new List<String>();
        for (String w : words) {
            if (String.isBlank(w)) continue;
            out.add(w.substring(0,1).toUpperCase() + (w.length() > 1 ? w.substring(1) : ''));
        }
        return String.join(out, ' ');
    }

    private String formatValue(Object val) {
        if (val == null) return '';
        if (val instanceof List<Object>) {
            List<String> parts = new List<String>();
            for (Object item : (List<Object>) val) parts.add(formatValue(item));
            return String.join(parts, ', ');
        }
        if (val instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) val;
            List<String> parts = new List<String>();
            for (String k : m.keySet()) parts.add(k + ': ' + formatValue(m.get(k)));
            return String.join(parts, '; ');
        }
        return String.valueOf(val);
    }

    private String unescapeHtml(String input) {
        if (input == null) return input;
        String result = input;
        result = result.replace('&quot;', '"');
        result = result.replace('&#39;', '\'');
        result = result.replace('&apos;', '\'');
        result = result.replace('&lt;', '<');
        result = result.replace('&gt;', '>');
        result = result.replace('&nbsp;', ' ');
        result = result.replace('&amp;', '&');
        return result;
    }
}