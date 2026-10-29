/*public with sharing class PolymerHDPEKeywordService {

    public class KeywordConfig {
        public String  label;
        public String  positiveKeywords;
        public String  negativeKeywords;
        public String  schemaPrompt;
        public Boolean isExcluded;
        public Boolean isRelevant;
    }

    // Returns a map keyed by Label: "Polymer - Excluded" / "Polymer - Relevant"
    public static Map<String, KeywordConfig> getPolymerKeywords() {
        Map<String, KeywordConfig> result = new Map<String, KeywordConfig>();

        List<Tender_Key_words_Final__mdt> mdtList = [
            SELECT Label, Matched_Positive_Keywords__c, Matched_Negative_Keywords__c,
                   Schema_Prompt__c, Is_Excluded__c, Is_Relevant__c
            FROM Tender_Key_words_Final__mdt
            WHERE Label = 'Polymer - Relevant' OR Label = 'Polymer - Excluded'
        ];

        for (Tender_Key_words_Final__mdt m : mdtList) {
            KeywordConfig kc     = new KeywordConfig();
            kc.label             = m.Label;
            kc.positiveKeywords  = m.Matched_Positive_Keywords__c;
            kc.negativeKeywords  = m.Matched_Negative_Keywords__c;
            kc.schemaPrompt      = m.Schema_Prompt__c;
            kc.isExcluded        = m.Is_Excluded__c;
            kc.isRelevant        = m.Is_Relevant__c;
            result.put(m.Label, kc);
        }

        System.debug('PolymerHDPEKeywordService: loaded ' + result.size() + ' keyword configs.');
        return result;
    }
}*/
/*
================================================================================
CLASS: PolymerHDPEKeywordService
--------------------------------------------------------------------------------
WHY THIS CLASS EXISTS:
Single source of truth for loading the Polymer/HDPE keyword configuration from
Tender_Key_words_Final__mdt (Custom Metadata Type "Tender Key words For Polymer
& HDPE"). Both the Step 1 (Prompt Builder / AI Summary check) and Step 2
(Gemini document fallback check) flows use the SAME two config records loaded
here, so keyword changes only need to be made in one place (Setup ->
Custom Metadata Types) and both AI paths pick them up automatically.

<<< CHANGED >>>
- The old "Polymer - Excluded" concept has been REMOVED ENTIRELY. There is no
  more Excluded metadata record and no more excluded/negative-keyword logic
  anywhere in the Polymer/HDPE flow.
- We now load exactly TWO "Relevant" records: Polymer_Relevant and
  HDPE_Relevant, keyed by DeveloperName (Custom Metadata Record Name), NOT by
  Label, since DeveloperName is guaranteed unique/stable while Label is a
  free-text display value that could be edited in Setup.
- Added Department__c to the query and to KeywordConfig - this field holds the
  literal product value ("Polymer" / "HDPE") that should be written to
  Tender__c.Product_Name__c / Department_Name__c when this config is the one
  that matched. This means the calling code NEVER needs to hardcode the
  string "Polymer" or "HDPE" - it always comes from metadata.
- The returned Map is now keyed by a simple logical key ("Polymer" / "HDPE"),
  taken directly from Department__c, instead of the old Label-based key
  ("Polymer - Relevant"). This keeps calling code simpler and decoupled from
  the exact metadata Label text.
================================================================================
*/
public with sharing class PolymerHDPEKeywordService {

    // Custom Metadata DeveloperNames (Custom Metadata Record Name) as seen in
    // Setup -> Custom Metadata Types -> Tender Key words For Polymer & HDPE.
    private static final String DEV_NAME_POLYMER = 'Polymer_Relevant';
    private static final String DEV_NAME_HDPE    = 'HDPE_Relevant';

    // Small data holder returned per keyword config record.
    public class KeywordConfig {
        public String  label;             // MasterLabel, e.g. "Polymer - Relevant" - for display/debug only
        public String  developerName;      // DeveloperName, e.g. "Polymer_Relevant"
        public String  department;         // Department__c - the actual value to write back, e.g. "Polymer" / "HDPE"
        public String  positiveKeywords;   // Matched_Positive_Keywords__c - used to build both the Prompt Builder input and the Gemini fallback prompt
        public String  negativeKeywords;   // Matched_Negative_Keywords__c - kept only for visibility/debug, NOT used in any matching logic anymore
        public String  schemaPrompt;       // Schema_Prompt__c - optional extra instruction text, still supported if populated
        public Boolean isRelevant;         // Is_Relevant__c - expected true for both records now
    }

    // ----------------------------------------------------------------------
    // METHOD: getPolymerKeywords
    // Loads the Polymer_Relevant and HDPE_Relevant custom metadata records
    // and returns them in a Map keyed by logical department name ("Polymer" /
    // "HDPE"), NOT by metadata Label. This is called ONCE per batch execution
    // (from PolymerHDPEBatch's constructor) and the resulting map is reused
    // for every Tender in every execute() chunk, to avoid repeated SOQL.
    // ----------------------------------------------------------------------
    public static Map<String, KeywordConfig> getPolymerKeywords() {
        Map<String, KeywordConfig> result = new Map<String, KeywordConfig>();

        List<Tender_Key_words_Final__mdt> mdtList = [
            SELECT Label, DeveloperName, Department__c,
                   Matched_Positive_Keywords__c, Matched_Negative_Keywords__c,
                   Schema_Prompt__c, Is_Excluded__c, Is_Relevant__c
            FROM Tender_Key_words_Final__mdt
            WHERE DeveloperName = :DEV_NAME_POLYMER
               OR DeveloperName = :DEV_NAME_HDPE
        ];

        for (Tender_Key_words_Final__mdt m : mdtList) {
            KeywordConfig kc     = new KeywordConfig();
            kc.label             = m.Label;
            kc.developerName     = m.DeveloperName;
            kc.department        = m.Department__c;
            kc.positiveKeywords  = m.Matched_Positive_Keywords__c;
            kc.negativeKeywords  = m.Matched_Negative_Keywords__c;
            kc.schemaPrompt      = m.Schema_Prompt__c;
            kc.isRelevant        = m.Is_Relevant__c;

            // Key the map by the ACTUAL department value from metadata
            // (falls back to DeveloperName-derived key only if Department__c
            // was left blank on the metadata record, so a config error never
            // silently disappears from the map).
            String mapKey = String.isNotBlank(m.Department__c)
                ? m.Department__c
                : m.DeveloperName;

            result.put(mapKey, kc);
        }

        System.debug('[PolymerHDPEKeywordService] Loaded ' + result.size()
                      + ' keyword config(s). Keys=' + result.keySet());
        return result;
    }
}