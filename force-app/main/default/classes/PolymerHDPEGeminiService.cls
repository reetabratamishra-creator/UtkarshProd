/*public with sharing class PolymerHDPEGeminiService {

    public class MatchResult {
        public Boolean excludedMatched = false;
        public Boolean relevantMatched = false;
        public String  reasoning       = '';
        public Boolean hadError        = false;
        public String  errorMessage    = '';
    }

    public static MatchResult checkFile(
        Blob   fileBytes,
        String mimeType,
        String fileName,
        PolymerHDPEKeywordService.KeywordConfig excludedCfg,
        PolymerHDPEKeywordService.KeywordConfig relevantCfg
    ) {
        MatchResult result = new MatchResult();

        try {
            String prompt     = buildPrompt(fileName, excludedCfg, relevantCfg);
            String base64Data = EncodingUtil.base64Encode(fileBytes);

            List<Object> parts = new List<Object>();
            parts.add(new Map<String, Object>{ 'text' => prompt });
            parts.add(new Map<String, Object>{
                'inline_data' => new Map<String, Object>{
                    'mime_type' => mimeType,
                    'data'      => base64Data
                }
            });

            Map<String, Object> body = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{ 'parts' => parts }
                },
                'generationConfig' => new Map<String, Object>{
                    'temperature'      => 0.1,
                    'responseMimeType' => 'application/json'
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Gemini/v1beta/models/gemini-2.5-flash:generateContent');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(body));

            Http         http = new Http();
            HttpResponse res  = http.send(req);

            System.debug('Gemini Polymer/HDPE check status: ' + res.getStatusCode() + ' for file: ' + fileName);

            if (res.getStatusCode() != 200) {
                result.hadError     = true;
                result.errorMessage = 'Gemini call failed - Status: ' + res.getStatusCode()
                    + ' | Body: ' + (res.getBody() != null ? res.getBody().left(300) : '');
                return result;
            }

            String text = extractText(res.getBody());
            if (String.isBlank(text)) {
                result.hadError     = true;
                result.errorMessage = 'Empty/unreadable Gemini response for file: ' + fileName;
                return result;
            }

            Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(text);
            } catch (Exception pe) {
                result.hadError     = true;
                result.errorMessage = 'Could not parse Gemini JSON for file "' + fileName + '": ' + pe.getMessage();
                return result;
            }

            result.excludedMatched = parsed.containsKey('excludedMatched') && parsed.get('excludedMatched') == true;
            result.relevantMatched = parsed.containsKey('relevantMatched') && parsed.get('relevantMatched') == true;
            result.reasoning       = parsed.containsKey('reasoning') ? String.valueOf(parsed.get('reasoning')) : '';

        } catch (Exception e) {
            result.hadError     = true;
            result.errorMessage = 'Exception in checkFile for "' + fileName + '": ' + e.getMessage();
            System.debug('PolymerHDPEGeminiService ERROR: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }

        return result;
    }

    private static String buildPrompt(
        String fileName,
        PolymerHDPEKeywordService.KeywordConfig excludedCfg,
        PolymerHDPEKeywordService.KeywordConfig relevantCfg
    ) {
        String prompt = 'You are a Tender Document Analyzer. Your ONLY task here is to decide between two outcomes: Polymer-Excluded (product is HDPE) or Polymer-Relevant (product is Polymer). Ignore all other categories.\n\n';
        prompt += 'File being analyzed: ' + fileName + '\n\n';

        prompt += '--- POLYMER EXCLUDED CRITERIA (check this FIRST) ---\n';
        if (excludedCfg != null) {
            if (String.isNotBlank(excludedCfg.negativeKeywords)) {
                prompt += 'If ANY of these keywords/phrases are present in the document, it is EXCLUDED (product = HDPE): '
                    + excludedCfg.negativeKeywords + '\n';
            }
            if (String.isNotBlank(excludedCfg.schemaPrompt)) {
                prompt += 'Additional instruction: ' + excludedCfg.schemaPrompt + '\n';
            }
        } else {
            prompt += '(No Excluded criteria configured)\n';
        }

        prompt += '\n--- POLYMER RELEVANT CRITERIA (check ONLY if NOT excluded) ---\n';
        if (relevantCfg != null) {
            if (String.isNotBlank(relevantCfg.positiveKeywords)) {
                prompt += 'If ANY of these keywords/phrases are present in the document, it is RELEVANT (product = Polymer): '
                    + relevantCfg.positiveKeywords + '\n';
            }
            if (String.isNotBlank(relevantCfg.schemaPrompt)) {
                prompt += 'Additional instruction: ' + relevantCfg.schemaPrompt + '\n';
            }
        } else {
            prompt += '(No Relevant criteria configured)\n';
        }

        prompt += '\n--- INSTRUCTIONS ---\n';
        prompt += 'Read the attached document carefully.\n';
        prompt += 'Step 1: Check the Excluded criteria. If matched, set excludedMatched=true and relevantMatched=false, and stop.\n';
        prompt += 'Step 2: If NOT excluded, check the Relevant criteria. If matched, set relevantMatched=true.\n';
        prompt += 'Step 3: If neither matched, set both to false.\n';
        prompt += 'Return ONLY a valid JSON object. No markdown. No explanation outside the JSON.\n\n';
        prompt += '{\n';
        prompt += '  "excludedMatched": true/false,\n';
        prompt += '  "relevantMatched": true/false,\n';
        prompt += '  "reasoning": "<brief explanation - which specific keyword(s) or content led to this decision, or why neither matched>"\n';
        prompt += '}';

        return prompt;
    }

    private static String extractText(String responseBody) {
        try {
            Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> candidates  = (List<Object>) resp.get('candidates');
            if (candidates == null || candidates.isEmpty()) return null;

            Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
            if (firstCandidate == null) return null;

            Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
            if (content == null) return null;

            List<Object> parts = (List<Object>) content.get('parts');
            if (parts == null || parts.isEmpty()) return null;

            Map<String, Object> firstPart = (Map<String, Object>) parts[0];
            if (firstPart == null) return null;

            return (String) firstPart.get('text');

        } catch (Exception e) {
            System.debug('extractText error: ' + e.getMessage());
            return null;
        }
    }
}*/
/*
================================================================================
CLASS: PolymerHDPEGeminiService
--------------------------------------------------------------------------------
WHY THIS CLASS EXISTS:
STEP 2 (fallback) of the Polymer/HDPE classification flow. Only called when
Step 1 (Prompt Builder / AI Summary check, see PolymerHDPEPromptService) was
NOT able to resolve a department. Downloads a single Tender document (already
fetched as a Blob by the caller) and asks Gemini to decide if it matches the
Polymer keyword set or the HDPE keyword set.

<<< CHANGED >>>
- Removed the old "Excluded vs Relevant" dual-criteria design entirely.
  There is no more excludedMatched/relevantMatched pair - Gemini is now asked
  to check TWO POSITIVE keyword sets (Polymer, then HDPE) using the exact same
  priority rule used in Step 1's Prompt Builder template: Polymer is checked
  FIRST: if it matches, HDPE is not even considered. Only if Polymer does NOT
  match does HDPE get checked.
- MatchResult now exposes a single matchedDepartment string ("Polymer" /
  "HDPE" / null) instead of two booleans, so calling code can write it
  directly to Tender__c.Product_Name__c / Department_Name__c without any
  extra branching.
- checkFile() now requires a tenderId parameter and logs every single call
  (success, no-match, or error) via IntegrationLogger, under stage
  "PolymerHDPEFileCheck". This did NOT happen before - file-check callouts to
  Gemini were previously invisible in Integration_Log__c.
================================================================================
*/
public with sharing class PolymerHDPEGeminiService {

    private static final String STAGE_NAME = 'PolymerHDPEFileCheck';

    // Result of analyzing ONE file against the Polymer/HDPE keyword configs.
    public class MatchResult {
        public String  matchedDepartment = null;   // "Polymer" / "HDPE" / null (no match)
        public String  reasoning         = '';
        public Boolean hadError          = false;
        public String  errorMessage      = '';
    }

    // ----------------------------------------------------------------------
    // METHOD: checkFile
    // Sends one downloaded file (as Blob) to Gemini along with a prompt built
    // from the Polymer and HDPE "Relevant" keyword configs, asks it to decide
    // which department (if any) the file belongs to, parses the JSON result,
    // and logs the outcome via IntegrationLogger before returning to caller.
    // tenderId is required purely for logging/traceability - it plays no
    // role in the actual Gemini call itself.
    // ----------------------------------------------------------------------
    public static MatchResult checkFile(
        Blob   fileBytes,
        String mimeType,
        String fileName,
        Id     tenderId,
        PolymerHDPEKeywordService.KeywordConfig polymerCfg,
        PolymerHDPEKeywordService.KeywordConfig hdpeCfg
    ) {
        MatchResult result = new MatchResult();
        Integer statusCode = null;
        String  rawResponseForLog = null;

        try {
            String prompt     = buildPrompt(fileName, polymerCfg, hdpeCfg);
            String base64Data = EncodingUtil.base64Encode(fileBytes);

            List<Object> parts = new List<Object>();
            parts.add(new Map<String, Object>{ 'text' => prompt });
            parts.add(new Map<String, Object>{
                'inline_data' => new Map<String, Object>{
                    'mime_type' => mimeType,
                    'data'      => base64Data
                }
            });

            Map<String, Object> body = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{ 'parts' => parts }
                },
                'generationConfig' => new Map<String, Object>{
                    'temperature'      => 0.1,
                    'responseMimeType' => 'application/json'
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Gemini/v1beta/models/gemini-2.5-flash:generateContent');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(body));

            Http         http = new Http();
            HttpResponse res  = http.send(req);
            statusCode = res.getStatusCode();
            rawResponseForLog = res.getBody();

            System.debug('[PolymerHDPEGeminiService] status=' + statusCode + ' file=' + fileName);

            if (statusCode != 200) {
                result.hadError     = true;
                result.errorMessage = 'Gemini call failed - Status: ' + statusCode
                    + ' | Body: ' + (res.getBody() != null ? res.getBody().left(300) : '');

                IntegrationLogger.log(STAGE_NAME, result.errorMessage != null ? 'Gemini' : 'Gemini',
                    'gemini-2.5-flash:generateContent', prompt, rawResponseForLog,
                    statusCode, false, result.errorMessage, tenderId);
                return result;
            }

            String text = extractText(res.getBody());
            if (String.isBlank(text)) {
                result.hadError     = true;
                result.errorMessage = 'Empty/unreadable Gemini response for file: ' + fileName;

                IntegrationLogger.log(STAGE_NAME, 'Gemini', 'gemini-2.5-flash:generateContent',
                    prompt, rawResponseForLog, statusCode, false, result.errorMessage, tenderId);
                return result;
            }

            Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(text);
            } catch (Exception pe) {
                result.hadError     = true;
                result.errorMessage = 'Could not parse Gemini JSON for file "' + fileName + '": ' + pe.getMessage();

                IntegrationLogger.log(STAGE_NAME, 'Gemini', 'gemini-2.5-flash:generateContent',
                    prompt, rawResponseForLog, statusCode, false, result.errorMessage, tenderId);
                return result;
            }

            // matchedDepartment is expected to be "Polymer", "HDPE", or "None".
            String dept = parsed.containsKey('matchedDepartment')
                ? String.valueOf(parsed.get('matchedDepartment'))
                : null;

            if (dept == 'Polymer' || dept == 'HDPE') {
                result.matchedDepartment = dept;
            }
            result.reasoning = parsed.containsKey('reasoning') ? String.valueOf(parsed.get('reasoning')) : '';

            // Successful call - log it as success regardless of whether a
            // department was actually matched (a clean "None" is still a
            // successful, well-formed callout - only actual errors are
            // logged as failures).
            IntegrationLogger.log(STAGE_NAME, 'Gemini', 'gemini-2.5-flash:generateContent',
                prompt, rawResponseForLog, statusCode, true,
                (result.matchedDepartment == null ? 'No department matched for file: ' + fileName : null),
                tenderId);

        } catch (Exception e) {
            result.hadError     = true;
            result.errorMessage = 'Exception in checkFile for "' + fileName + '": ' + e.getMessage();
            System.debug('[PolymerHDPEGeminiService] ERROR: ' + e.getMessage() + ' | ' + e.getStackTraceString());

            IntegrationLogger.log(STAGE_NAME, 'Gemini', 'gemini-2.5-flash:generateContent',
                null, rawResponseForLog, statusCode, false, result.errorMessage, tenderId);
        }

        return result;
    }

    // ----------------------------------------------------------------------
    // METHOD: buildPrompt
    // Builds the Gemini prompt text for a single file. Checks Polymer
    // keywords FIRST (matching the same priority used in the Step 1 Prompt
    // Builder template) - only if Polymer does not match does it consider
    // HDPE. No "Excluded" criteria exist anymore.
    // ----------------------------------------------------------------------
    private static String buildPrompt(
        String fileName,
        PolymerHDPEKeywordService.KeywordConfig polymerCfg,
        PolymerHDPEKeywordService.KeywordConfig hdpeCfg
    ) {
        String prompt = 'You are a Tender Document Analyzer. Your ONLY task is to decide whether this document belongs to the "Polymer" department or the "HDPE" department, or neither.\n\n';
        prompt += 'File being analyzed: ' + fileName + '\n\n';

        prompt += '--- STEP 1: Check POLYMER keywords FIRST ---\n';
        if (polymerCfg != null && String.isNotBlank(polymerCfg.positiveKeywords)) {
            prompt += 'If ANY of these keywords/phrases are present in the document, matchedDepartment = "Polymer" and STOP (do not check HDPE): '
                + polymerCfg.positiveKeywords + '\n';
            if (String.isNotBlank(polymerCfg.schemaPrompt)) {
                prompt += 'Additional instruction: ' + polymerCfg.schemaPrompt + '\n';
            }
        } else {
            prompt += '(No Polymer keyword configuration available)\n';
        }

        prompt += '\n--- STEP 2: Only if Polymer did NOT match, check HDPE keywords ---\n';
        if (hdpeCfg != null && String.isNotBlank(hdpeCfg.positiveKeywords)) {
            prompt += 'If ANY of these keywords/phrases are present in the document, matchedDepartment = "HDPE": '
                + hdpeCfg.positiveKeywords + '\n';
            if (String.isNotBlank(hdpeCfg.schemaPrompt)) {
                prompt += 'Additional instruction: ' + hdpeCfg.schemaPrompt + '\n';
            }
        } else {
            prompt += '(No HDPE keyword configuration available)\n';
        }

        prompt += '\n--- STEP 3: If neither matched ---\n';
        prompt += 'Set matchedDepartment = "None".\n';

        prompt += '\nReturn ONLY a valid JSON object. No markdown. No explanation outside the JSON.\n\n';
        prompt += '{\n';
        prompt += '  "matchedDepartment": "Polymer" | "HDPE" | "None",\n';
        prompt += '  "reasoning": "<brief explanation - which specific keyword(s) or content led to this decision, or why neither matched>"\n';
        prompt += '}';

        return prompt;
    }

    // ----------------------------------------------------------------------
    // METHOD: extractText
    // Pulls the plain text out of Gemini's raw response envelope
    // (candidates[0].content.parts[0].text). Unchanged from before.
    // ----------------------------------------------------------------------
    private static String extractText(String responseBody) {
        try {
            Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> candidates  = (List<Object>) resp.get('candidates');
            if (candidates == null || candidates.isEmpty()) return null;

            Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
            if (firstCandidate == null) return null;

            Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
            if (content == null) return null;

            List<Object> parts = (List<Object>) content.get('parts');
            if (parts == null || parts.isEmpty()) return null;

            Map<String, Object> firstPart = (Map<String, Object>) parts[0];
            if (firstPart == null) return null;

            return (String) firstPart.get('text');

        } catch (Exception e) {
            System.debug('[PolymerHDPEGeminiService] extractText error: ' + e.getMessage());
            return null;
        }
    }
}