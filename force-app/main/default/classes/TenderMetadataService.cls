// ============================================================
// CLASS — TenderMetadataService.cls 
// ─────────────────────────────────────────────────────────────
// PURPOSE:
//   Reads all Tender_Key_words_Final__mdt custom metadata
//   records and builds the category matching prompt string
//   to send to Gemini for tender category analysis.
//
// METHODS:
//   getAllCategories()
//     → Queries all Tender_Key_words_Final__mdt records.
//       Returns list of CategoryConfig objects.
//
//   buildMetadataPrompt(categories)
//     → Builds a formatted prompt string from the category
//       list. Returns blank string if list is empty.
//

// ============================================================
public with sharing class TenderMetadataService {

    public class CategoryConfig {
        public String  label;
        public String  department;
        public String  positiveKeywords;
        public String  negativeKeywords;
        public Boolean isRelevant;
        public Boolean isExcluded;
        public String  schemaPrompt;
    }

    // ─────────────────────────────────────────────────────────
    // Fetch all metadata records and return as list
    // ─────────────────────────────────────────────────────────
    public static List<CategoryConfig> getAllCategories() {

        List<CategoryConfig> categories = new List<CategoryConfig>();

        List<Tender_Key_words_Final__mdt> metadataList = [
            SELECT  Label,
                    Department__c,
                    Matched_Positive_Keywords__c,
                    Matched_Negative_Keywords__c,
                    Is_Relevant__c,
                    Is_Excluded__c,
                    Schema_Prompt__c
            FROM    Tender_Key_words_Final__mdt
            ORDER BY Label ASC
        ];

        System.debug('Total Metadata Categories Found: ' + metadataList.size());

        for (Tender_Key_words_Final__mdt md : metadataList) {
            CategoryConfig cc   = new CategoryConfig();
            cc.label            = md.Label;
            cc.department       = md.Department__c;
            cc.positiveKeywords = md.Matched_Positive_Keywords__c;
            cc.negativeKeywords = md.Matched_Negative_Keywords__c;
            cc.isRelevant       = md.Is_Relevant__c;
            cc.isExcluded       = md.Is_Excluded__c;
            cc.schemaPrompt     = md.Schema_Prompt__c;
            categories.add(cc);

            System.debug('Loaded Category: ' + cc.label
                + ' | Relevant: ' + cc.isRelevant
                + ' | Excluded: ' + cc.isExcluded);
        }

        return categories;
    }

    // ─────────────────────────────────────────────────────────
    // Build the full metadata prompt string to send to Gemini
    // ─────────────────────────────────────────────────────────
    public static String buildMetadataPrompt(List<CategoryConfig> categories) {

        // FIX: empty list guard
        if (categories == null || categories.isEmpty()) {
            System.debug('WARNING: buildMetadataPrompt called with empty list. Returning blank.');
            return '';
        }

        String prompt = '';

        for (CategoryConfig cc : categories) {

            // FIX: skip record entirely if label is null — avoids
            //      "--- CATEGORY: null ---" in Gemini prompt
            if (String.isBlank(cc.label)) {
                System.debug('WARNING: Skipping CategoryConfig with blank label.');
                continue;
            }

            prompt += '\n--- CATEGORY: ' + cc.label + ' ---\n';

            // FIX: null guard on department
            prompt += 'Department    : '
                + (String.isBlank(cc.department) ? 'N/A' : cc.department) + '\n';

            // FIX: null guard on Boolean fields — null prints as "null" in string
            prompt += 'Is Relevant   : ' + (cc.isRelevant  == true ? 'true' : 'false') + '\n';
            prompt += 'Is Excluded   : ' + (cc.isExcluded  == true ? 'true' : 'false') + '\n';

            if (String.isNotBlank(cc.positiveKeywords)) {
                prompt += 'Positive Keywords (MUST be present to match): '
                    + cc.positiveKeywords + '\n';
            }

            if (String.isNotBlank(cc.negativeKeywords)) {
                prompt += 'Negative Keywords (if present, category is EXCLUDED): '
                    + cc.negativeKeywords + '\n';
            }

            if (String.isNotBlank(cc.schemaPrompt)) {
                prompt += 'Analysis Instruction: ' + cc.schemaPrompt + '\n';
            }
        }

        // FIX: log warning if prompt is very large — heap safety indicator
        System.debug('Built Metadata Prompt Length: ' + prompt.length() + ' chars');
        if (prompt.length() > 100000) {
            System.debug('WARNING: Metadata prompt exceeds 100,000 chars. '
                + 'Risk of heap pressure or Gemini input limit.');
        }

        return prompt;
    }
}