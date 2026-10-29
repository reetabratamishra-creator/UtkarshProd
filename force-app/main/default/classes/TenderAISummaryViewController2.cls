public with sharing class TenderAISummaryViewController2 {

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

    public List<SummaryRow> rows {get;private set;}

    // key (Key_Api_name__c) -> label (Key_Name__c), loaded once from custom metadata.
    // Acts as a whitelist: a hardcoded section key is only rendered if it exists here.
    private Map<String, String> metadataLabelByKey;
private List<Tender_Keys__mdt> metadataKeys;

    public TenderAISummaryViewController2() {

        rows = new List<SummaryRow>();
        parseFailed = false;
    Id recordId = ApexPages.currentPage().getParameters().get('id');

    if (recordId == null) {
        parseFailed = true;
        parseErrorMessage = 'Missing Tender Id.';
        return;
    }

    List<Tender__c> results = [
        SELECT
            Id,
            Name,
            External_Tender_Id__c,
            Tender_AI_Summary_status__c
        FROM Tender__c
        WHERE Id = :recordId
        LIMIT 1
    ];

    if (results.isEmpty()) {
        parseFailed = true;
        parseErrorMessage = 'Tender not found.';
        return;
    }

    tender = results[0];

    if (tender.Tender_AI_Summary_status__c == 'Fail') {
        parseFailed = true;
        parseErrorMessage = 'AI Summary generation failed.';
        return;
    }

    // Load metadata labels
    loadMetadataKeys();

    // Read all child JSONs and merge values
    Map<String,Object> mergedValues = loadMergedValues(recordId);

    if (mergedValues.isEmpty()) {
        parseFailed = true;
        parseErrorMessage = 'No AI Summary values found.';
        return;
    }

    buildRows(mergedValues);
}


private Map<String,Object> loadMergedValues(Id tenderId) {

    Map<String,Object> masterMap = new Map<String,Object>();

    List<Tender_AI_Summary_Json__c> summaries = [

        SELECT
            Id,
            Ai_Summary_Json__c,
            CreatedDate

        FROM Tender_AI_Summary_Json__c

        WHERE Tender__c = :tenderId

        ORDER BY CreatedDate ASC, Id ASC

    ];



    for (Tender_AI_Summary_Json__c summary : summaries) {

        if (String.isBlank(summary.Ai_Summary_Json__c)) {
            continue;
        }

        String json = unescapeHtml(summary.Ai_Summary_Json__c);

        for (Tender_Keys__mdt keyRec : metadataKeys) {

            String key = keyRec.Key_Api_name__c;

            String existingValue = (String)masterMap.get(key);

String newValue = extractValue(json, key);

if(String.isBlank(existingValue) &&
   String.isNotBlank(newValue)){

    masterMap.put(

        key,

        newValue
    );
}
        }
    }


    return masterMap;
}

private String extractValue(String json, String key) {

    if (String.isBlank(json) || String.isBlank(key)) {
        return null;
    }

    String searchKey = '"' + key + '"';

    Integer keyPos = json.indexOf(searchKey);

    if (keyPos == -1) {
        return null;
    }

    // Move after "Key"
    Integer index = keyPos + searchKey.length();

    // Skip spaces until :
    while (index < json.length()) {

        String ch = json.substring(index, index + 1);

        if (ch == ':') {
            index++;
            break;
        }

        index++;
    }

    // Skip whitespace
    while (index < json.length()) {

        String ch = json.substring(index, index + 1);

        if (ch != ' ' &&
            ch != '\n' &&
            ch != '\r' &&
            ch != '\t') {
            break;
        }

        index++;
    }

    if (index >= json.length()) {
        return null;
    }

    String firstChar = json.substring(index, index + 1);

    /*
     * String
     */
    if (firstChar == '"') {

        return readQuotedValue(
            json,
            index + 1
        );
    }

    /*
     * Number / Boolean / Null
     */
    return readPrimitiveValue(
        json,
        index
    );
}

private String readQuotedValue(String json, Integer startIndex) {

    String value = '';

    Boolean escaped = false;

    Integer i = startIndex;

    while (i < json.length()) {

        String ch = json.substring(i, i + 1);

        if (escaped) {
            value += ch;
            escaped = false;
            i++;
            continue;
        }

        if (ch == '\\') {
            escaped = true;
            i++;
            continue;
        }

        if (ch == '"') {
            break;
        }

        value += ch;

        i++;
    }

    value = value.replace('\\n','\n');
    value = value.replace('\\r','\r');
    value = value.replace('\\t','\t');
    value = value.replace('\\"','"');
    value = value.replace('\\\\','\\');

    return value;
}

private String readPrimitiveValue(String json, Integer startIndex) {

    Integer i = startIndex;

    String value = '';

    while (i < json.length()) {

        String ch = json.substring(i, i + 1);

        if (ch == ',' ||
            ch == '}' ||
            ch == ']') {
            break;
        }

        value += ch;

        i++;
    }

    value = value.trim();

    if (String.isBlank(value)) {
        return null;
    }

    if (value == 'null') {
        return null;
    }

    return value;
}


    // Loads the metadata key registry: Key_Api_name__c (raw JSON key) -> Key_Name__c (display label).
private void loadMetadataKeys() {

    metadataLabelByKey = new Map<String, String>();
    metadataKeys = new List<Tender_Keys__mdt>();

     metadataKeys = [

        SELECT
            Key_Api_name__c,
            Key_Name__c,
            Serial_Number__c

        FROM Tender_Keys__mdt

        ORDER BY Serial_Number__c ASC NULLS LAST, Key_Name__c ASC

    ];

      for (Integer i = metadataKeys.size() - 1; i >= 0; i--) {
        if (String.isBlank(metadataKeys[i].Key_Api_name__c)) {
            metadataKeys.remove(i);
        }
    }
}

private void buildRows(Map<String,Object> mergedValues){

    rows = new List<SummaryRow>();

    for(Tender_Keys__mdt keyRec : metadataKeys){

        String apiKey = keyRec.Key_Api_name__c;

        String label = keyRec.Key_Name__c;

        Object value = mergedValues.get(apiKey);

        rows.add(

            new SummaryRow(

                label,

                formatValue(value)

            )

        );
    }
}

    @TestVisible
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
       result = result.replace('&quot;', '\\"');
        result = result.replace('&#39;', '\'');
        result = result.replace('&apos;', '\'');
        result = result.replace('&lt;', '<');
        result = result.replace('&gt;', '>');
        result = result.replace('&nbsp;', ' ');
        result = result.replace('&amp;', '&');
        return result;
    }
}