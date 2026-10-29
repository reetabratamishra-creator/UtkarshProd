/*
================================================================================
CLASS: PolymerHDPEPromptService
--------------------------------------------------------------------------------
WHY THIS CLASS EXISTS:
Implements STEP 1 of the Polymer/HDPE classification flow - the PRIMARY check,
which runs BEFORE the document-based Gemini fallback (PolymerHDPEGeminiService).

This step uses the native Salesforce Prompt Builder Flex Template
"Find_Polymer_OR_HDPE_from_AI_Summary" to try to determine the department
directly from:
  - the Tender's merged AI Summary JSON (Tender_AI_Summary_JSON__c chunks,
    joined back into one string), and/or
  - the Tender's Description (Tender_Description__c)
without needing to download and analyze any documents at all. This is faster
and cheaper than the file-based fallback, so it is always tried first.

INPUT AVAILABILITY RULES (business-approved matrix):
  - AI Summary present + Description present -> fire prompt with both
  - AI Summary missing + Description present -> fire prompt with Description only
  - AI Summary present + Description missing -> fire prompt with Summary only
  - AI Summary missing + Description missing -> DO NOT fire the prompt at all;
    caller must go straight to Step 2 (document fallback)

ERROR HANDLING RULES (business-approved):
  - If the Prompt Template returns "No Match" -> caller falls back to Step 2.
  - If the Prompt Template's response cannot be parsed as valid JSON -> this
    is treated EXACTLY like "No Match" for flow purposes (caller falls back
    to Step 2), but the raw malformed response text is captured separately
    (parseFailed = true, rawResponse populated) so it can be distinguished
    from a genuine "No Match" decision when reviewing Integration_Log__c
    later. The log entry's Error_Message__c is prefixed "PROMPT_PARSE_FAILED:"
    for exactly this reason.

TRUNCATION SAFETY:
  - The merged AI Summary can be very large (multiple ~130,000-char chunks
    joined together). To guarantee the Prompt Builder callout can NEVER blow
    up on an oversized payload, mergeAiSummary() caps the merged text at
    SUMMARY_SAFE_LIMIT characters. If truncation occurs, wasTruncated is set
    true so the caller can note it in the Tender's readable summary log.

LOGGING:
  - Every attempt (fired + matched, fired + no-match, fired + parse-failed,
    fired + call-error, or not-fired-due-to-no-input) is logged via
    IntegrationLogger under stage "PolymerHDPESummaryPrompt", linked to the
    Tender__c Id, so unattended runs remain fully auditable.

<<< NOTE ON ConnectApi USAGE >>>
The exact ConnectApi class/method signature for invoking a Flex Prompt
Template can vary slightly between Salesforce API versions. The call below
uses the standard ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()
pattern. If your org's API version exposes a different signature (e.g. a
generated Invocable Apex class from Prompt Builder, or a newer
GenAiPromptTemplate-based API), swap out ONLY the body of
invokePromptTemplate() - nothing else in this class needs to change.
================================================================================
*/
public with sharing class PolymerHDPEPromptService {

    // Must match the API Name of the Flex Prompt Template built in
    // Setup -> Prompt Builder.
    private static final String PROMPT_TEMPLATE_API_NAME = 'Find_Polymer_OR_HDPE_from_AI_Summary';

    private static final String STAGE_NAME = 'PolymerHDPESummaryPrompt';
       @TestVisible private static String  testOverrideResponse = null;
   @TestVisible private static Boolean testShouldThrow      = false;

    // Safety cap on the merged AI Summary text sent into the prompt, so a
    // very large multi-chunk summary can never cause an oversized-payload
    // exception on the LLM callout. Chosen comfortably under typical LLM
    // input limits while still giving the model plenty of context.
    private static final Integer SUMMARY_SAFE_LIMIT = 45000;

    // ------------------------------------------------------------------
    // Result of merging the Tender_AI_Summary_JSON__c chunk records for
    // one Tender back into a single string.
    // ------------------------------------------------------------------
    public class MergedSummaryResult {
        public String  mergedText   = null;   // null if no chunk records exist at all
        public Boolean wasTruncated = false;   // true if the merged text exceeded SUMMARY_SAFE_LIMIT and was cut down
    }

    // ------------------------------------------------------------------
    // Result of attempting the Step 1 Prompt Builder classification for
    // one Tender.
    // ------------------------------------------------------------------
    public class PromptResult {
        public Boolean fired             = false;  // false = prompt was never called (no summary AND no description)
        public String  matchedDepartment = null;    // "Polymer" / "HDPE" / null
        public String  reasoning         = '';
        public Boolean parseFailed       = false;   // true = model responded but output wasn't valid JSON
        public String  rawResponse       = null;    // raw model output, populated mainly when parseFailed = true
        public Boolean hadError          = false;   // true = the callout itself failed (exception / non-success)
        public String  errorMessage      = '';
    }

    // ----------------------------------------------------------------------
    // METHOD: mergeAiSummary
    // Queries all Tender_AI_Summary_JSON__c child records for the given
    // Tender, ordered by Sequence_Number__c, and concatenates their
    // Ai_Summary_Json__c values back into a single string (undoing the
    // chunking that TenderAISummaryBatch performed on insert). Applies a
    // safe truncation cap before returning, so callers never need to worry
    // about oversized text downstream.
    // ----------------------------------------------------------------------
    public static MergedSummaryResult mergeAiSummary(Id tenderId) {
        MergedSummaryResult result = new MergedSummaryResult();

        List<Tender_AI_Summary_JSON__c> chunks = [
            SELECT Ai_Summary_Json__c, Sequence_Number__c
            FROM Tender_AI_Summary_JSON__c
            WHERE Tender__c = :tenderId
            ORDER BY Sequence_Number__c ASC
        ];

        if (chunks.isEmpty()) {
            System.debug('[PolymerHDPEPromptService] No AI Summary chunks found for Tender ' + tenderId);
            return result; // mergedText stays null - caller treats this as "no AI summary available"
        }

        String merged = '';
        for (Tender_AI_Summary_JSON__c c : chunks) {
            if (String.isNotBlank(c.Ai_Summary_Json__c)) {
                merged += c.Ai_Summary_Json__c;
            }
        }

        if (String.isBlank(merged)) {
            System.debug('[PolymerHDPEPromptService] AI Summary chunks existed but were all blank for Tender ' + tenderId);
            return result;
        }

        if (merged.length() > SUMMARY_SAFE_LIMIT) {
            merged = merged.substring(0, SUMMARY_SAFE_LIMIT);
            result.wasTruncated = true;
            System.debug('[PolymerHDPEPromptService] Merged AI Summary truncated to '
                         + SUMMARY_SAFE_LIMIT + ' chars for Tender ' + tenderId);
        }

        result.mergedText = merged;
        return result;
    }

    // ----------------------------------------------------------------------
    // METHOD: checkDepartment
    // Main entry point for Step 1. Decides (per the approved input-
    // availability matrix) whether to fire the Prompt Template at all, fires
    // it if appropriate, parses the JSON response, and logs the outcome.
    // Never throws - all failure paths are captured on the returned
    // PromptResult so PolymerHDPEBatch can safely decide to fall back to
    // Step 2 (document check) without any try/catch of its own.
    // ----------------------------------------------------------------------
    public static PromptResult checkDepartment(
        Tender__c tender,
        String    mergedAiSummary,
        Boolean   summaryWasTruncated,
        PolymerHDPEKeywordService.KeywordConfig polymerCfg,
        PolymerHDPEKeywordService.KeywordConfig hdpeCfg
    ) {
        PromptResult result = new PromptResult();

        Boolean hasSummary     = String.isNotBlank(mergedAiSummary);
        Boolean hasDescription = String.isNotBlank(tender.Tender_Description__c);

        // Approved matrix: if BOTH are missing, do not fire the prompt at
        // all - go straight to Step 2 in the caller.
        if (!hasSummary && !hasDescription) {
            result.fired = false;
            System.debug('[PolymerHDPEPromptService] Skipping Step 1 for Tender ' + tender.Id
                         + ' - no AI Summary and no Description available.');

            IntegrationLogger.log(STAGE_NAME, 'PromptBuilder', PROMPT_TEMPLATE_API_NAME,
                null, null, null, false,
                'SKIPPED: No AI Summary and no Tender_Description__c available - Step 1 not attempted.',
                tender.Id);
            return result;
        }

        result.fired = true;

        String requestPayloadForLog = null;

        try {
            requestPayloadForLog = 'tenderName=' + tender.Name
                + ' | hasSummary=' + hasSummary + (summaryWasTruncated ? ' (TRUNCATED)' : '')
                + ' | hasDescription=' + hasDescription;

            String rawModelText = invokePromptTemplate(
                tender.Name,
                hasDescription ? tender.Tender_Description__c : '',
                hasSummary ? mergedAiSummary : '',
                polymerCfg != null ? polymerCfg.positiveKeywords : '',
                hdpeCfg    != null ? hdpeCfg.positiveKeywords    : ''
            );

            if (String.isBlank(rawModelText)) {
                result.hadError     = true;
                result.errorMessage = 'Prompt Builder returned an empty response.';

                IntegrationLogger.log(STAGE_NAME, 'PromptBuilder', PROMPT_TEMPLATE_API_NAME,
                    requestPayloadForLog, rawModelText, null, false, result.errorMessage, tender.Id);
                return result;
            }

            // Strip markdown code fences (```json ... ```) in case the model wraps
// the JSON, same pattern used in IndiaMartKeywordBatch.invokePrompt().
String cleanedJson = rawModelText.trim()
    .replaceAll('(?s)^```json', '')
    .replaceAll('(?s)^```', '')
    .replaceAll('(?s)```$', '')
    .trim();

Map<String, Object> parsed;
try {
    parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
} catch (Exception pe) {
    result.rawResponse = rawModelText; // keep original for debugging
    /*Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(rawModelText);
            } catch (Exception pe) {*/
                result.parseFailed = true;
                result.rawResponse = rawModelText;

                IntegrationLogger.log(STAGE_NAME, 'PromptBuilder', PROMPT_TEMPLATE_API_NAME,
                    requestPayloadForLog, rawModelText, null, false,
                    'PROMPT_PARSE_FAILED: ' + pe.getMessage() + ' | RawResponse: ' + rawModelText.abbreviate(1000),
                    tender.Id);
                return result;
            }

            String dept = parsed.containsKey('department') ? String.valueOf(parsed.get('department')) : null;
            result.reasoning = parsed.containsKey('reasoning') ? String.valueOf(parsed.get('reasoning')) : '';

            if (dept == 'Polymer' || dept == 'HDPE') {
                result.matchedDepartment = dept;
            }
            // dept == 'No Match' (or anything else unexpected) simply leaves
            // matchedDepartment as null, which the caller treats as "not resolved".

            IntegrationLogger.log(STAGE_NAME, 'PromptBuilder', PROMPT_TEMPLATE_API_NAME,
                requestPayloadForLog, rawModelText, null, true,
                (result.matchedDepartment == null ? 'No department matched from AI Summary/Description.' : null),
                tender.Id);

        } catch (Exception e) {
            result.hadError     = true;
            result.errorMessage = 'Exception invoking Prompt Template for Tender ' + tender.Id + ': ' + e.getMessage();
            System.debug('[PolymerHDPEPromptService] ERROR: ' + e.getMessage() + ' | ' + e.getStackTraceString());

            IntegrationLogger.log(STAGE_NAME, 'PromptBuilder', PROMPT_TEMPLATE_API_NAME,
                requestPayloadForLog, null, null, false, result.errorMessage, tender.Id);
        }

        return result;
    }

    // ----------------------------------------------------------------------
    // METHOD: invokePromptTemplate
    // Fires the native Salesforce Flex Prompt Template
    // "Find_Polymer_OR_HDPE_from_AI_Summary" via ConnectApi, passing the five
    // input variables it expects (tenderName, tenderDescription,
    // aiSummaryMerged, polymerKeywords, hdpeKeywords), and returns the raw
    // text the model generated (expected to be a JSON string per the
    // template's own instructions).
    //
    // NOTE: If your org's Salesforce API version uses a different ConnectApi
    // shape for Prompt Template invocation, this is the ONLY method that
    // needs to change - everything else in this class is version-agnostic.
    // ----------------------------------------------------------------------
    /*private static String invokePromptTemplate(
    String tenderName,
    String tenderDescription,
    String aiSummaryMerged,
    String polymerKeywords,
    String hdpeKeywords
) {
    Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

    ConnectApi.WrappedValue vTenderName = new ConnectApi.WrappedValue();
    vTenderName.value = tenderName;
    inputParams.put('Input:tenderName', vTenderName);

    ConnectApi.WrappedValue vDescription = new ConnectApi.WrappedValue();
    vDescription.value = tenderDescription;
    inputParams.put('Input:tenderDescription', vDescription);

    ConnectApi.WrappedValue vSummary = new ConnectApi.WrappedValue();
    vSummary.value = aiSummaryMerged;
    inputParams.put('Input:aiSummaryMerged', vSummary);

    ConnectApi.WrappedValue vPolymerKw = new ConnectApi.WrappedValue();
    vPolymerKw.value = polymerKeywords;
    inputParams.put('Input:polymerKeywords', vPolymerKw);

    ConnectApi.WrappedValue vHdpeKw = new ConnectApi.WrappedValue();
    vHdpeKw.value = hdpeKeywords;
    inputParams.put('Input:hdpeKeywords', vHdpeKw);

    ConnectApi.EinsteinPromptTemplateGenerationsInput genInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    genInput.isPreview = false;
    genInput.inputParams = inputParams;
    genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
    genInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
    genInput.additionalConfig.numGenerations = 1;

    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation genResponse =
        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_API_NAME, genInput);

    if (genResponse == null
        || genResponse.generations == null
        || genResponse.generations.isEmpty()) {
        return null;
    }

    return genResponse.generations[0].text;
}*/
           // ----------------------------------------------------------------------
    // METHOD: invokePromptTemplate
    // Fires the native Salesforce Flex Prompt Template
    // "Find_Polymer_OR_HDPE_from_AI_Summary" via ConnectApi, passing the five
    // input variables it expects (tenderName, tenderDescription,
    // aiSummaryMerged, polymerKeywords, hdpeKeywords), and returns the raw
    // text the model generated (expected to be a JSON string per the
    // template's own instructions).
    //
    // NOTE: If your org's Salesforce API version uses a different ConnectApi
    // shape for Prompt Template invocation, this is the ONLY method that
    // needs to change - everything else in this class is version-agnostic.
    // ----------------------------------------------------------------------
    private static String invokePromptTemplate(
        String tenderName,
        String tenderDescription,
        String aiSummaryMerged,
        String polymerKeywords,
        String hdpeKeywords
    ) {
        // Input-building is pure object construction (no DML, no callout),
        // so it's safe to run unconditionally - including in test context.
        // Keeping this OUTSIDE the Test.isRunningTest() seam means every
        // existing checkDepartment() test also exercises this logic,
        // instead of it being permanently uncovered dead code.
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

        ConnectApi.WrappedValue vTenderName = new ConnectApi.WrappedValue();
        vTenderName.value = tenderName;
        inputParams.put('Input:tenderName', vTenderName);

        ConnectApi.WrappedValue vDescription = new ConnectApi.WrappedValue();
        vDescription.value = tenderDescription;
        inputParams.put('Input:tenderDescription', vDescription);

        ConnectApi.WrappedValue vSummary = new ConnectApi.WrappedValue();
        vSummary.value = aiSummaryMerged;
        inputParams.put('Input:aiSummaryMerged', vSummary);

        ConnectApi.WrappedValue vPolymerKw = new ConnectApi.WrappedValue();
        vPolymerKw.value = polymerKeywords;
        inputParams.put('Input:polymerKeywords', vPolymerKw);

        ConnectApi.WrappedValue vHdpeKw = new ConnectApi.WrappedValue();
        vHdpeKw.value = hdpeKeywords;
        inputParams.put('Input:hdpeKeywords', vHdpeKw);

        ConnectApi.EinsteinPromptTemplateGenerationsInput genInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        genInput.isPreview = false;
        genInput.inputParams = inputParams;
        genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        genInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
        genInput.additionalConfig.numGenerations = 1;

        // ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate() cannot
        // be exercised in an Apex test context - it will throw. This seam
        // short-circuits BEFORE the actual callout, returning the test's
        // canned response (or throwing a simulated failure) instead. Only
        // the live-callout code below this block is genuinely uncoverable
        // by unit tests.
        if (Test.isRunningTest()) {
            if (testShouldThrow) {
                throw new CalloutException('Simulated Prompt Template failure');
            }
            return testOverrideResponse;
        }

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation genResponse =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_API_NAME, genInput);

        if (genResponse == null
            || genResponse.generations == null
            || genResponse.generations.isEmpty()) {
            return null;
        }

        return genResponse.generations[0].text;
    }
}