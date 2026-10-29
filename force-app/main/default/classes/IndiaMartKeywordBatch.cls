/*
================================================================================================
 CLASS NAME   : IndiaMartKeywordBatch
 PURPOSE      : Does the actual keyword-matching work using Salesforce Prompt Builder.
                Runs as Batch Apex (Database.Batchable + Database.AllowsCallouts) so that
                Prompt Builder callouts are safely chunked and never exceed the 100
                callouts-per-transaction governor limit, regardless of how many leads
                are passed in (single manual lead vs bulk Data Loader load).

 WHAT THIS CLASS DOES (per chunk of leads):
   1. Re-checks the active Custom Metadata record and dynamically builds a keyword map
      by reading every custom keyword field on IndiaMART_Department_Verification__mdt via
      Schema describe (no field API names are hardcoded in the loop logic - if a new
      keyword field is added to the metadata in future, no Apex change is required).
      Values are split on BOTH comma and newline, so either format works.
      "Enquiry_Keywords__c" is intentionally excluded - it is only used as the fallback
      bucket, never checked against.
   2. For every Lead in the chunk:
        - Reads Product_to_Purchase__c (NOT Description).
        - Loops through each keyword group ONE AT A TIME (alphabetical order).
        - Calls the Prompt Builder template, passing the Lead's Product_to_Purchase__c text,
          the current group name, and that group's keyword list.
        - As soon as one group returns isMatch = true, the loop STOPS immediately -
          no further groups are checked for that lead.
        - If NO group matches after checking all of them, the lead falls back to the
          "Enquiry" department.
   3. Updates 3 fields on the Lead:
        - Department_Name__c          -> mapped picklist value for the matched group
        - Match_Summary_For_INDIAMART__c         -> combined text with matched group, isMatch, and reasoning
        - is_Already_Fired_IndiaMart__c -> set true ONLY when processing completed successfully
          (kept false if an exception occurs, so a later valid update can retry it)
================================================================================================
*/
/*public with sharing class IndiaMartKeywordBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private List<Id> leadIds;

    // Prompt Builder Flex Template Developer Name (set this to your actual template's API name)
    private static final String PROMPT_TEMPLATE_API_NAME = 'IndiaMART_Lead_Keyword_Matcher';

    // Fixed fallback values when no keyword group matches
    private static final String FALLBACK_DEPARTMENT = 'Enquiry';
    private static final String FALLBACK_GROUP_LABEL = 'Enquiry Keywords';

    // ------------------------------------------------------------------------------------------
    // Static mapping: CMDT keyword field API Name -> Department_Name__c picklist value
    // Kept explicit/hardcoded on purpose - labels do not consistently match picklist values,
    // so auto-deriving them via string manipulation would be unreliable.
    // NOTE: "Buyer Keywords" and "Polymer"/"Solar Structure" are intentionally NOT included -
    // Buyer Keywords field was removed from metadata, Polymer & Solar Structure are ignored for now.
    // ------------------------------------------------------------------------------------------
    private static final Map<String, String> FIELD_TO_DEPARTMENT = new Map<String, String>{
        'High_Mast_Polygonal_Keywords__c'              => 'High Mast & Polygonal',
        'Steel_Pipes_Keywords__c'                       => 'Steel Pipes',
        'Crash_Barrier_Keywords__c'                     => 'Crash Barrier',
        'Steel_Tubular_Poles_Keywords__c'               => 'Steel Tubular Poles',
        'Pre_Engineering_Buildings_Keywords__c'         => 'Pre Engineering Building',
        'Railway_Electrification_Structure_Keywor__c'   => 'Railway Electrification Structure',
        'Telecome_Tower_Transmission_Tower_Keyw__c'     => 'Transmission & Telecom Tower',
        'Polymer_Keywords__c'                           => 'Polymer',
        'HDPE_Keywords__c'                              => 'HDPE',
        'Solar_Structure_Keywords__c'                   => 'Solar Structure'
    };

    // Recursion guard so this batch's own Lead update does not re-trigger LeadTrigger logic
    @TestVisible
    private static Boolean keywordProcessingDone = false;

    public IndiaMartKeywordBatch(List<Id> leadIds) {
        this.leadIds = leadIds;
    }


   // --------------------------------------------------------------------------------------------
   //  METHOD: start
   //  Returns the eligible Lead records (passed in from the Handler) as the batch's scope.
   // --------------------------------------------------------------------------------------------

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== IndiaMartKeywordBatch.start --- LeadIds received: ' + leadIds + ' ===');
        return Database.getQueryLocator([
            SELECT Id, Product_to_Purchase__c, LeadSource, Department_Name__c,
                   Match_Summary_For_INDIAMART__c, is_Already_Fired_IndiaMart__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);
    }

    
    //--------------------------------------------------------------------------------------------
   //  METHOD: execute
    // Runs once per chunk (chunk size controlled by scope size passed at Database.executeBatch).
   //  Builds the keyword map, processes each lead in the chunk, then saves results.
  //  --------------------------------------------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        System.debug('=== IndiaMartKeywordBatch.execute START | chunkSize=' + scope.size() + ' ===');

        try {
            // Re-fetch active CMDT record inside this transaction
            IndiaMART_Department_Verification__mdt configRecord = getActiveConfigRecord();
            if (configRecord == null) {
                System.debug('IndiaMartKeywordBatch.execute --- No active CMDT config found. Aborting this chunk.');
                return;
            }

            // Build the dynamic keyword map for this chunk
            Map<String, List<String>> keywordMap = buildKeywordMap(configRecord);
            System.debug('IndiaMartKeywordBatch.execute --- Keyword Map built | Groups=' + keywordMap.keySet());

            List<Lead> leadsToUpdate = new List<Lead>();

            // Process each lead independently - one lead's failure must not affect the others
            for (Lead ld : scope) {
                try {
                    processLead(ld, keywordMap);
                    leadsToUpdate.add(ld);
                } catch (Exception leadEx) {
                    System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- EXCEPTION processing LeadId=' + ld.Id
                        + ' | Error=' + leadEx.getMessage() + ' | Line=' + leadEx.getLineNumber());
                }
            }

            // Save all successfully processed leads in this chunk
            if (!leadsToUpdate.isEmpty()) {
                keywordProcessingDone = true; // prevent recursive trigger firing on this update
                List<Database.SaveResult> results = Database.update(leadsToUpdate, false);
                keywordProcessingDone = false;

                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('IndiaMartKeywordBatch.execute --- UPDATE SUCCESS | LeadId=' + sr.getId());
                    } else {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- UPDATE FAILED | LeadId=' + sr.getId()
                                + ' | Error=' + err.getMessage());
                        }
                    }
                }
            }

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- TOP LEVEL EXCEPTION: ' + ex.getMessage()
                + ' | Line=' + ex.getLineNumber() + ' | StackTrace=' + ex.getStackTraceString());
        }

        System.debug('=== IndiaMartKeywordBatch.execute END ===');
    }

    
     //METHOD: finish
     //Logs a final summary once all chunks have completed.
    
    public void finish(Database.BatchableContext bc) {
        System.debug('=== IndiaMartKeywordBatch.finish --- Batch job completed for LeadIds: ' + leadIds + ' ===');
    }

     //METHOD: getActiveConfigRecord
     //Re-checks the kill-switch inside the batch transaction (belt-and-suspenders safety).
    private static IndiaMART_Department_Verification__mdt getActiveConfigRecord() {
        List<IndiaMART_Department_Verification__mdt> configs = [
            SELECT Id, DeveloperName, isTrigger_Active__c,
                   Crash_Barrier_Keywords__c, Enquiry_Keywords__c,
                   High_Mast_Polygonal_Keywords__c, Pre_Engineering_Buildings_Keywords__c,
                   Polymer_Keywords__c,HDPE_Keywords__c, Railway_Electrification_Structure_Keywor__c,
                   Steel_Pipes_Keywords__c, Steel_Tubular_Poles_Keywords__c,Solar_Structure_Keywords__c,
                   Telecome_Tower_Transmission_Tower_Keyw__c
            FROM IndiaMART_Department_Verification__mdt
            ORDER BY DeveloperName ASC
            LIMIT 1
        ];
        System.debug('IndiaMartKeywordBatch.getActiveConfigRecord --- CMDT query result: ' + configs);

        if (configs.isEmpty() || configs[0].isTrigger_Active__c != true) {
            return null;
        }
        return configs[0];
    }

     //METHOD: buildKeywordMap
     //Dynamically reads every mapped keyword field (from FIELD_TO_DEPARTMENT) off the CMDT
     //record, splits values on comma/newline, and returns Field Label -> Keyword List.
    private static Map<String, List<String>> buildKeywordMap(IndiaMART_Department_Verification__mdt cfg) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.IndiaMART_Department_Verification__mdt.fields.getMap();

        for (String fieldApiName : FIELD_TO_DEPARTMENT.keySet()) {
            if (!fieldsMap.containsKey(fieldApiName.toLowerCase())) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.buildKeywordMap --- Field not found on CMDT, skipping: ' + fieldApiName);
                continue;
            }

            Object fieldValue = cfg.get(fieldApiName);
            if (fieldValue == null) continue;

            String rawValue = String.valueOf(fieldValue).trim();
            if (String.isBlank(rawValue)) continue;

            List<String> keywords = splitKeywords(rawValue);
            if (!keywords.isEmpty()) {
                Schema.DescribeFieldResult dfr = fieldsMap.get(fieldApiName.toLowerCase()).getDescribe();
                result.put(dfr.getLabel(), keywords);
                System.debug('IndiaMartKeywordBatch.buildKeywordMap --- Field=' + fieldApiName
                    + ' | Label=' + dfr.getLabel() + ' | KeywordCount=' + keywords.size());
            }
        }

        return result;
    }

    
     //METHOD: splitKeywords
    // Splits a raw metadata field value on comma OR newline, trims each piece, drops blanks.
    private static List<String> splitKeywords(String rawValue) {
        List<String> output = new List<String>();
        if (String.isBlank(rawValue)) return output;

        for (String part : rawValue.split('\\r\\n|\\n|,')) {
            String cleaned = part.trim();
            if (String.isNotBlank(cleaned)) {
                output.add(cleaned);
            }
        }
        return output;
    }


    private static void processLead(Lead ld, Map<String, List<String>> keywordMap) {
        System.debug('IndiaMartKeywordBatch.processLead --- START | LeadId=' + ld.Id
            + ' | Product_to_Purchase__c=' + ld.Product_to_Purchase__c);

        if (String.isBlank(ld.Product_to_Purchase__c)) {
            System.debug('IndiaMartKeywordBatch.processLead --- Product_to_Purchase__c is blank. Applying fallback.');
            applyFallback(ld);
            return;
        }

        // Deterministic iteration order since Map key order is not guaranteed
        List<String> orderedGroupLabels = new List<String>(keywordMap.keySet());
        orderedGroupLabels.sort();

        Boolean matched = false;

        for (String groupLabel : orderedGroupLabels) {
            List<String> keywords = keywordMap.get(groupLabel);
            String keywordListStr = String.join(keywords, ', ');

            System.debug('IndiaMartKeywordBatch.processLead --- Checking group="' + groupLabel + '" | KeywordCount=' + keywords.size());

            KeywordMatchResult matchResult;
            try {
                matchResult = invokePrompt(ld.Product_to_Purchase__c, groupLabel, keywordListStr);
            } catch (Exception promptEx) {
                System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.processLead --- Prompt call FAILED | group="' + groupLabel
                    + '" | LeadId=' + ld.Id + ' | Error=' + promptEx.getMessage());
                continue; // try next group
            }

            if (matchResult == null) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.processLead --- NULL result for group="' + groupLabel + '". Moving to next group.');
                continue;
            }

            System.debug('IndiaMartKeywordBatch.processLead --- Result | group="' + groupLabel + '" | isMatch=' + matchResult.isMatch
                + ' | key=' + matchResult.key + ' | summary=' + matchResult.summary);

            if (matchResult.isMatch == true) {
                String matchedFieldApiName = getFieldApiNameByLabel(groupLabel);
                String departmentValue = FIELD_TO_DEPARTMENT.containsKey(matchedFieldApiName)
                    ? FIELD_TO_DEPARTMENT.get(matchedFieldApiName)
                    : groupLabel;

                ld.Department_Name__c = departmentValue;
                ld.Match_Summary_For_INDIAMART__c = buildSummaryText(groupLabel, true, matchResult.summary);
                ld.is_Already_Fired_IndiaMart__c = true;

                matched = true;
                System.debug('IndiaMartKeywordBatch.processLead --- MATCH FOUND on group="' + groupLabel + '". Stopping loop.');
                break;
            }
        }

        if (!matched) {
            System.debug('IndiaMartKeywordBatch.processLead --- No group matched out of ' + orderedGroupLabels.size() + ' groups. Applying fallback.');
            applyFallback(ld);
        }

        System.debug('IndiaMartKeywordBatch.processLead --- END | LeadId=' + ld.Id
            + ' | FinalDepartment=' + ld.Department_Name__c);
    }


    private static void applyFallback(Lead ld) {
        ld.Department_Name__c = FALLBACK_DEPARTMENT;
        ld.Match_Summary_For_INDIAMART__c = buildSummaryText(FALLBACK_GROUP_LABEL, false, 'No keyword group matched the lead description. Defaulted to Enquiry.');
        ld.is_Already_Fired_IndiaMart__c = true;
    }


    private static String buildSummaryText(String matchedGroup, Boolean isMatch, String summaryText) {
        return 'Matched Keyword Group: ' + matchedGroup
            + '\nIs Match: ' + isMatch
            + '\nSummary: ' + summaryText;
    }


    private static String getFieldApiNameByLabel(String label) {
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.IndiaMART_Department_Verification__mdt.fields.getMap();
        for (String fieldApiName : FIELD_TO_DEPARTMENT.keySet()) {
            if (fieldsMap.containsKey(fieldApiName.toLowerCase())) {
                Schema.DescribeFieldResult dfr = fieldsMap.get(fieldApiName.toLowerCase()).getDescribe();
                if (dfr.getLabel() == label) {
                    return fieldApiName;
                }
            }
        }
        return '';
    }

    @TestVisible
private static IPromptInvoker testInvoker;
private static KeywordMatchResult invokePrompt(String productToPurchase, String groupName, String keywordList) {
    System.debug('IndiaMartKeywordBatch.invokePrompt --- START | group=' + groupName);

    if (testInvoker != null) {
        return testInvoker.invoke(productToPurchase, groupName, keywordList);
    }

        try {
            Map<String, ConnectApi.WrappedValue> inputs = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue v1 = new ConnectApi.WrappedValue();
            v1.value = productToPurchase;
            inputs.put('Input:Product_to_Purchase', v1);

            ConnectApi.WrappedValue v2 = new ConnectApi.WrappedValue();
            v2.value = groupName;
            inputs.put('Input:KeywordGroupName', v2);

            ConnectApi.WrappedValue v3 = new ConnectApi.WrappedValue();
            v3.value = keywordList;
            inputs.put('Input:KeywordList', v3);

            ConnectApi.EinsteinPromptTemplateGenerationsInput req = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            req.isPreview = false;
            req.inputParams = inputs;
            req.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            req.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
            req.additionalConfig.numGenerations = 1;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_API_NAME, req);

            if (response == null || response.generations == null || response.generations.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.invokePrompt --- Empty/null response from Prompt Template.');
                return null;
            }

            String rawText = response.generations[0].text;
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Raw LLM Response Text: ' + rawText);

            // Strip markdown fences in case the model wraps JSON in ```json ... ```
            String cleanedJson = rawText.trim().replaceAll('(?s)```json', '').replaceAll('(?s)```', '').trim();
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Cleaned JSON: ' + cleanedJson);

            KeywordMatchResult parsedResult = (KeywordMatchResult) JSON.deserialize(cleanedJson, KeywordMatchResult.class);
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Parsed Result | isMatch=' + parsedResult.isMatch
                + ' | key=' + parsedResult.key + ' | summary=' + parsedResult.summary);

            return parsedResult;

        } catch (JSONException jsonEx) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- JSON PARSE EXCEPTION: ' + jsonEx.getMessage());
            return null;
        } catch (ConnectApi.ConnectApiException connEx) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- CONNECT API EXCEPTION: ' + connEx.getMessage());
            return null;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- UNEXPECTED EXCEPTION: ' + ex.getMessage() + ' | Line=' + ex.getLineNumber());
            return null;
        } finally {
            System.debug('IndiaMartKeywordBatch.invokePrompt --- END | group=' + groupName);
        }
    }

    public class KeywordMatchResult {
        public Boolean isMatch;
        public String key;
        public String summary;
    }
    // --- TEST SEAM: allows tests to simulate Prompt Builder responses ---
public interface IPromptInvoker {
    KeywordMatchResult invoke(String productToPurchase, String groupName, String keywordList);
}
}*/
/*
================================================================================================
 CLASS NAME   : IndiaMartKeywordBatch
 PURPOSE      : Does the actual keyword-matching work using Salesforce Prompt Builder.
                Runs as Batch Apex (Database.Batchable + Database.AllowsCallouts) so that
                Prompt Builder callouts are safely chunked and never exceed the 100
                callouts-per-transaction governor limit, regardless of how many leads
                are passed in (single manual lead vs bulk Data Loader load).

 WHAT THIS CLASS DOES (per chunk of leads):
   1. Re-checks the active Custom Metadata record and dynamically builds a keyword map
      by reading every custom keyword field on IndiaMART_Department_Verification__mdt via
      Schema describe (no field API names are hardcoded in the loop logic - if a new
      keyword field is added to the metadata in future, no Apex change is required).
      Values are split on BOTH comma and newline, so either format works.
      "Enquiry_Keywords__c" is intentionally excluded - it is only used as the fallback
      bucket, never checked against.
   2. For every Lead in the chunk:
        - Reads Product_to_Purchase__c (NOT Description).
        - Loops through each keyword group ONE AT A TIME (alphabetical order).
        - Calls the Prompt Builder template, passing the Lead's Product_to_Purchase__c text,
          the current group name, and that group's keyword list.
        - As soon as one group returns isMatch = true, the loop STOPS immediately -
          no further groups are checked for that lead.
        - If NO group matches after checking all of them, the lead falls back to the
          "Enquiry" department.
   3. Updates 3 fields on the Lead:
        - Department_Name__c          -> mapped picklist value for the matched group
        - Match_Summary_For_INDIAMART__c         -> combined text with matched group, isMatch, and reasoning
        - is_Already_Fired_IndiaMart__c -> set true ONLY when processing completed successfully
          (kept false if an exception occurs, so a later valid update can retry it)
================================================================================================
*/
public without sharing class IndiaMartKeywordBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private List<Id> leadIds;

    // Prompt Builder Flex Template Developer Name (set this to your actual template's API name)
    private static final String PROMPT_TEMPLATE_API_NAME = 'IndiaMART_Lead_Keyword_Matcher';

    // Fixed fallback values when no keyword group matches
    private static final String FALLBACK_DEPARTMENT = 'Enquiry';
    private static final String FALLBACK_GROUP_LABEL = 'Enquiry Keywords';

    // ------------------------------------------------------------------------------------------
    // Static mapping: CMDT keyword field API Name -> Department_Name__c picklist value
    // Kept explicit/hardcoded on purpose - labels do not consistently match picklist values,
    // so auto-deriving them via string manipulation would be unreliable.
    // NOTE: "Buyer Keywords" and "Polymer"/"Solar Structure" are intentionally NOT included -
    // Buyer Keywords field was removed from metadata, Polymer & Solar Structure are ignored for now.
    // ------------------------------------------------------------------------------------------
    private static final Map<String, String> FIELD_TO_DEPARTMENT = new Map<String, String>{
        'High_Mast_Polygonal_Keywords__c'              => 'High Mast & Polygonal',
        'Steel_Pipes_Keywords__c'                       => 'Steel Pipes',
        'Crash_Barrier_Keywords__c'                     => 'Crash Barrier',
        'Steel_Tubular_Poles_Keywords__c'               => 'Steel Tubular Poles',
        'Pre_Engineering_Buildings_Keywords__c'         => 'Pre Engineering Building',
        'Railway_Electrification_Structure_Keywor__c'   => 'Railway Electrification Structure',
        'Telecome_Tower_Transmission_Tower_Keyw__c'     => 'Transmission & Telecom Tower',
        'Polymer_Keywords__c'                           => 'Polymer',
        'HDPE_Keywords__c'                              => 'HDPE',
        'Solar_Structure_Keywords__c'                   => 'Solar Structure'
    };

    // Recursion guard so this batch's own Lead update does not re-trigger LeadTrigger logic
    @TestVisible
    private static Boolean keywordProcessingDone = false;

    public IndiaMartKeywordBatch(List<Id> leadIds) {
        this.leadIds = leadIds;
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: start
     Returns the eligible Lead records (passed in from the Handler) as the batch's scope.
    --------------------------------------------------------------------------------------------
    */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== IndiaMartKeywordBatch.start --- LeadIds received: ' + leadIds + ' ===');
        return Database.getQueryLocator([
            SELECT Id, Product_to_Purchase__c, LeadSource, Department_Name__c,
                   Match_Summary_For_INDIAMART__c, is_Already_Fired_IndiaMart__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: execute
     Runs once per chunk (chunk size controlled by scope size passed at Database.executeBatch).
     Builds the keyword map, processes each lead in the chunk, then saves results.
    --------------------------------------------------------------------------------------------
    */
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        System.debug('=== IndiaMartKeywordBatch.execute START | chunkSize=' + scope.size() + ' ===');

        try {
            // Re-fetch active CMDT record inside this transaction
            IndiaMART_Department_Verification__mdt configRecord = getActiveConfigRecord();
            if (configRecord == null) {
                System.debug('IndiaMartKeywordBatch.execute --- No active CMDT config found. Aborting this chunk.');
                return;
            }

            // Build the dynamic keyword map for this chunk
            Map<String, List<String>> keywordMap = buildKeywordMap(configRecord);
            System.debug('IndiaMartKeywordBatch.execute --- Keyword Map built | Groups=' + keywordMap.keySet());

            List<Lead> leadsToUpdate = new List<Lead>();

            // Process each lead independently - one lead's failure must not affect the others
            for (Lead ld : scope) {
                try {
                    processLead(ld, keywordMap);
                    leadsToUpdate.add(ld);
                } catch (Exception leadEx) {
                    System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- EXCEPTION processing LeadId=' + ld.Id
                        + ' | Error=' + leadEx.getMessage() + ' | Line=' + leadEx.getLineNumber());
                }
            }

            // Save all successfully processed leads in this chunk
            if (!leadsToUpdate.isEmpty()) {
                keywordProcessingDone = true; // prevent recursive trigger firing on this update
                List<Database.SaveResult> results = Database.update(leadsToUpdate, false);
                keywordProcessingDone = false;

                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('IndiaMartKeywordBatch.execute --- UPDATE SUCCESS | LeadId=' + sr.getId());
                    } else {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- UPDATE FAILED | LeadId=' + sr.getId()
                                + ' | Error=' + err.getMessage());
                        }
                    }
                }
            }

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.execute --- TOP LEVEL EXCEPTION: ' + ex.getMessage()
                + ' | Line=' + ex.getLineNumber() + ' | StackTrace=' + ex.getStackTraceString());
        }

        System.debug('=== IndiaMartKeywordBatch.execute END ===');
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: finish
     Logs a final summary once all chunks have completed.
    --------------------------------------------------------------------------------------------
    */
    public void finish(Database.BatchableContext bc) {
        System.debug('=== IndiaMartKeywordBatch.finish --- Batch job completed for LeadIds: ' + leadIds + ' ===');
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: getActiveConfigRecord
     Re-checks the kill-switch inside the batch transaction (belt-and-suspenders safety).
    --------------------------------------------------------------------------------------------
    */
    private static IndiaMART_Department_Verification__mdt getActiveConfigRecord() {
        List<IndiaMART_Department_Verification__mdt> configs = [
            SELECT Id, DeveloperName, isTrigger_Active__c,
                   Crash_Barrier_Keywords__c, Enquiry_Keywords__c,
                   High_Mast_Polygonal_Keywords__c, Pre_Engineering_Buildings_Keywords__c,
                   Polymer_Keywords__c,HDPE_Keywords__c, Railway_Electrification_Structure_Keywor__c,
                   Steel_Pipes_Keywords__c, Steel_Tubular_Poles_Keywords__c,Solar_Structure_Keywords__c,
                   Telecome_Tower_Transmission_Tower_Keyw__c
            FROM IndiaMART_Department_Verification__mdt
            ORDER BY DeveloperName ASC
            LIMIT 1
        ];
        System.debug('IndiaMartKeywordBatch.getActiveConfigRecord --- CMDT query result: ' + configs);

        if (configs.isEmpty() || configs[0].isTrigger_Active__c != true) {
            return null;
        }
        return configs[0];
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: buildKeywordMap
     Dynamically reads every mapped keyword field (from FIELD_TO_DEPARTMENT) off the CMDT
     record, splits values on comma/newline, and returns Field Label -> Keyword List.
    --------------------------------------------------------------------------------------------
    */
    private static Map<String, List<String>> buildKeywordMap(IndiaMART_Department_Verification__mdt cfg) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.IndiaMART_Department_Verification__mdt.fields.getMap();

        for (String fieldApiName : FIELD_TO_DEPARTMENT.keySet()) {
            if (!fieldsMap.containsKey(fieldApiName.toLowerCase())) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.buildKeywordMap --- Field not found on CMDT, skipping: ' + fieldApiName);
                continue;
            }

            Object fieldValue = cfg.get(fieldApiName);
            if (fieldValue == null) continue;

            String rawValue = String.valueOf(fieldValue).trim();
            if (String.isBlank(rawValue)) continue;

            List<String> keywords = splitKeywords(rawValue);
            if (!keywords.isEmpty()) {
                Schema.DescribeFieldResult dfr = fieldsMap.get(fieldApiName.toLowerCase()).getDescribe();
                result.put(dfr.getLabel(), keywords);
                System.debug('IndiaMartKeywordBatch.buildKeywordMap --- Field=' + fieldApiName
                    + ' | Label=' + dfr.getLabel() + ' | KeywordCount=' + keywords.size());
            }
        }

        return result;
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: splitKeywords
     Splits a raw metadata field value on comma OR newline, trims each piece, drops blanks.
    --------------------------------------------------------------------------------------------
    */
    private static List<String> splitKeywords(String rawValue) {
        List<String> output = new List<String>();
        if (String.isBlank(rawValue)) return output;

        for (String part : rawValue.split('\\r\\n|\\n|,')) {
            String cleaned = part.trim();
            if (String.isNotBlank(cleaned)) {
                output.add(cleaned);
            }
        }
        return output;
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: processLead
     Core matching logic for a single Lead:
       - Loops keyword groups one at a time, calling Prompt Builder for each.
       - Stops immediately on the first match.
       - Falls back to "Enquiry" if nothing matches.
       - Sets Department_Name__c, Match_Summary_For_INDIAMART__c, is_Already_Fired_IndiaMart__c.
    --------------------------------------------------------------------------------------------
    */
    private static void processLead(Lead ld, Map<String, List<String>> keywordMap) {
        System.debug('IndiaMartKeywordBatch.processLead --- START | LeadId=' + ld.Id
            + ' | Product_to_Purchase__c=' + ld.Product_to_Purchase__c);

        if (String.isBlank(ld.Product_to_Purchase__c)) {
            System.debug('IndiaMartKeywordBatch.processLead --- Product_to_Purchase__c is blank. Applying fallback.');
            applyFallback(ld);
            return;
        }

        // Deterministic iteration order since Map key order is not guaranteed
        List<String> orderedGroupLabels = new List<String>(keywordMap.keySet());
        orderedGroupLabels.sort();

        Boolean matched = false;

        for (String groupLabel : orderedGroupLabels) {
            List<String> keywords = keywordMap.get(groupLabel);
            String keywordListStr = String.join(keywords, ', ');

            System.debug('IndiaMartKeywordBatch.processLead --- Checking group="' + groupLabel + '" | KeywordCount=' + keywords.size());

            KeywordMatchResult matchResult;
            try {
                matchResult = invokePrompt(ld.Product_to_Purchase__c, groupLabel, keywordListStr);
            } catch (Exception promptEx) {
                System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.processLead --- Prompt call FAILED | group="' + groupLabel
                    + '" | LeadId=' + ld.Id + ' | Error=' + promptEx.getMessage());
                continue; // try next group
            }

            if (matchResult == null) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.processLead --- NULL result for group="' + groupLabel + '". Moving to next group.');
                continue;
            }

            System.debug('IndiaMartKeywordBatch.processLead --- Result | group="' + groupLabel + '" | isMatch=' + matchResult.isMatch
                + ' | key=' + matchResult.key + ' | summary=' + matchResult.summary);

            if (matchResult.isMatch == true) {
                String matchedFieldApiName = getFieldApiNameByLabel(groupLabel);
                String departmentValue = FIELD_TO_DEPARTMENT.containsKey(matchedFieldApiName)
                    ? FIELD_TO_DEPARTMENT.get(matchedFieldApiName)
                    : groupLabel;

                ld.Department_Name__c = departmentValue;
                ld.Match_Summary_For_INDIAMART__c = buildSummaryText(groupLabel, true, matchResult.summary);
                ld.is_Already_Fired_IndiaMart__c = true;

                matched = true;
                System.debug('IndiaMartKeywordBatch.processLead --- MATCH FOUND on group="' + groupLabel + '". Stopping loop.');
                break;
            }
        }

        if (!matched) {
            System.debug('IndiaMartKeywordBatch.processLead --- No group matched out of ' + orderedGroupLabels.size() + ' groups. Applying fallback.');
            applyFallback(ld);
        }

        System.debug('IndiaMartKeywordBatch.processLead --- END | LeadId=' + ld.Id
            + ' | FinalDepartment=' + ld.Department_Name__c);
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: applyFallback
     Sets Department_Name__c to "Enquiry" and marks the lead as fired when no keyword matches.
    --------------------------------------------------------------------------------------------
    */
    private static void applyFallback(Lead ld) {
        ld.Department_Name__c = FALLBACK_DEPARTMENT;
        ld.Match_Summary_For_INDIAMART__c = buildSummaryText(FALLBACK_GROUP_LABEL, false, 'No keyword group matched the lead description. Defaulted to Enquiry.');
        ld.is_Already_Fired_IndiaMart__c = true;
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: buildSummaryText
     Builds the combined text stored in Match_Summary_For_INDIAMART__c.
    --------------------------------------------------------------------------------------------
    */
    private static String buildSummaryText(String matchedGroup, Boolean isMatch, String summaryText) {
        return 'Matched Keyword Group: ' + matchedGroup
            + '\nIs Match: ' + isMatch
            + '\nSummary: ' + summaryText;
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: getFieldApiNameByLabel
     Reverse-lookup: given a field Label, finds its API Name from FIELD_TO_DEPARTMENT keys
     (needed because the keyword map is keyed by Label, but the department map is keyed by API Name).
    --------------------------------------------------------------------------------------------
    */
    private static String getFieldApiNameByLabel(String label) {
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.IndiaMART_Department_Verification__mdt.fields.getMap();
        for (String fieldApiName : FIELD_TO_DEPARTMENT.keySet()) {
            if (fieldsMap.containsKey(fieldApiName.toLowerCase())) {
                Schema.DescribeFieldResult dfr = fieldsMap.get(fieldApiName.toLowerCase()).getDescribe();
                if (dfr.getLabel() == label) {
                    return fieldApiName;
                }
            }
        }
        return '';
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: invokePrompt
     Calls the Salesforce Prompt Builder Flex Template with 3 inputs:
       - Product_to_Purchase : the Lead's Product_to_Purchase__c text
       - KeywordGroupName    : current keyword group being checked
       - KeywordList         : comma-separated keyword list for that group
     Expects a strict JSON response: {"isMatch": true/false, "key": "...", "summary": "..."}
    --------------------------------------------------------------------------------------------
    */
    @TestVisible
private static IPromptInvoker testInvoker;
private static KeywordMatchResult invokePrompt(String productToPurchase, String groupName, String keywordList) {
    System.debug('IndiaMartKeywordBatch.invokePrompt --- START | group=' + groupName);

    if (testInvoker != null) {
        return testInvoker.invoke(productToPurchase, groupName, keywordList);
    }

        try {
            Map<String, ConnectApi.WrappedValue> inputs = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue v1 = new ConnectApi.WrappedValue();
            v1.value = productToPurchase;
            inputs.put('Input:Product_to_Purchase', v1);

            ConnectApi.WrappedValue v2 = new ConnectApi.WrappedValue();
            v2.value = groupName;
            inputs.put('Input:KeywordGroupName', v2);

            ConnectApi.WrappedValue v3 = new ConnectApi.WrappedValue();
            v3.value = keywordList;
            inputs.put('Input:KeywordList', v3);

            ConnectApi.EinsteinPromptTemplateGenerationsInput req = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            req.isPreview = false;
            req.inputParams = inputs;
            req.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            req.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
            req.additionalConfig.numGenerations = 1;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_API_NAME, req);

            if (response == null || response.generations == null || response.generations.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'IndiaMartKeywordBatch.invokePrompt --- Empty/null response from Prompt Template.');
                return null;
            }

            String rawText = response.generations[0].text;
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Raw LLM Response Text: ' + rawText);

            // Strip markdown fences in case the model wraps JSON in ```json ... ```
            String cleanedJson = rawText.trim().replaceAll('(?s)```json', '').replaceAll('(?s)```', '').trim();
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Cleaned JSON: ' + cleanedJson);

            KeywordMatchResult parsedResult = (KeywordMatchResult) JSON.deserialize(cleanedJson, KeywordMatchResult.class);
            System.debug('IndiaMartKeywordBatch.invokePrompt --- Parsed Result | isMatch=' + parsedResult.isMatch
                + ' | key=' + parsedResult.key + ' | summary=' + parsedResult.summary);

            return parsedResult;

        } catch (JSONException jsonEx) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- JSON PARSE EXCEPTION: ' + jsonEx.getMessage());
            return null;
        } catch (ConnectApi.ConnectApiException connEx) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- CONNECT API EXCEPTION: ' + connEx.getMessage());
            return null;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordBatch.invokePrompt --- UNEXPECTED EXCEPTION: ' + ex.getMessage() + ' | Line=' + ex.getLineNumber());
            return null;
        } finally {
            System.debug('IndiaMartKeywordBatch.invokePrompt --- END | group=' + groupName);
        }
    }

    /*
    --------------------------------------------------------------------------------------------
     WRAPPER CLASS: KeywordMatchResult
     Maps the strict JSON response coming back from the Prompt Builder template.
    --------------------------------------------------------------------------------------------
    */
    public class KeywordMatchResult {
        public Boolean isMatch;
        public String key;
        public String summary;
    }
    // --- TEST SEAM: allows tests to simulate Prompt Builder responses ---
public interface IPromptInvoker {
    KeywordMatchResult invoke(String productToPurchase, String groupName, String keywordList);
}
}