public with sharing class PolymerHDPEBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    //private Map<String, PolymerHDPEKeywordService.KeywordConfig> keywordMap;
    @TestVisible private Map<String, PolymerHDPEKeywordService.KeywordConfig> keywordMap;
    private static final Integer SUMMARY_MAX_LEN = 131072; // Long Text Area hard cap
    
    // Heap guard for Gemini file callouts (see Edit 2 below)
        private static final Integer HEAP_SAFETY_MULTIPLIER   = 4;                 // base64 + JSON body overhead
    private static final Integer MAX_FILE_BYTES_FOR_GEMINI = 2 * 1024 * 1024;  // 2MB hard cap, tune as needed

    // Loads the Polymer/HDPE keyword configs ONCE per batch job execution
    // (not per chunk/per Tender) to minimize repeated SOQL against Custom
    // Metadata across execute() calls.
    //private Map<String, Id> ownerMap = new Map<String, Id>();
    @TestVisible private Map<String, Id> ownerMap = new Map<String, Id>();
    @TestVisible private static List<String> dmlErrors = new List<String>();

    public PolymerHDPEBatch() {
        this.keywordMap = PolymerHDPEKeywordService.getPolymerKeywords();
        
        for (Tender_Polymer_HDPE_Owner_Assignment__mdt m : [
            SELECT DeveloperName, Owner__c
            FROM Tender_Polymer_HDPE_Owner_Assignment__mdt
        ]) {
            if (String.isNotBlank(m.Owner__c)) {
                ownerMap.put(m.DeveloperName, (Id) m.Owner__c);
            }
        }
    }
    
    /*
     public PolymerHDPEBatch() {
        this.keywordMap = PolymerHDPEKeywordService.getPolymerKeywords();
    }
    */

    // ----------------------------------------------------------------------
    // METHOD: start
    // Selects today's merged Tenders that still need Department_Name__c
    // resolved and have not already reached a finalized Stage. Also pulls
    // related documents (for Step 2 fallback) and Tender_Description__c
    // (new - required as a Step 1 input, was NOT queried before).
    // ----------------------------------------------------------------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[PolymerHDPEBatch] START');
        return Database.getQueryLocator([
            SELECT Id, Name, MergeProduct__c, Product_Name__c, Tender_Description__c,
                   Is_checked_Polymer_HDPE__c, Reading_Polymer_HDPE_summary__c,
                   (
                       SELECT Id, Name__c, Type__c, Download_URL__c, Download_URL_Text__c, Document_Id__c, CreatedDate
                       FROM Tender_Docoment_Details__r
                       ORDER BY CreatedDate DESC)
            FROM Tender__c
            WHERE MergeProduct__c = true AND Department_Name__c = null AND CreatedDate = TODAY AND Polymer_HDPE_Stage_Check__c NOT IN (
    'Matched',
    'Checked - No Match',
    'No Supported Files')
        ]);
    }

    // ----------------------------------------------------------------------
    // METHOD: execute
    // Runs Step 1 (Prompt Builder) then, only if needed, Step 2 (document
    // fallback via Gemini) for every Tender in this chunk, then bulk-updates
    // all resulting Tender__c records and flushes IntegrationLogger.
    // ----------------------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<Tender__c> scope) {

        // New department-based keys ("Polymer" / "HDPE") from the updated
        // PolymerHDPEKeywordService - replaces the old Label-based keys.
        PolymerHDPEKeywordService.KeywordConfig polymerCfg = keywordMap != null ? keywordMap.get('Polymer') : null;
        PolymerHDPEKeywordService.KeywordConfig hdpeCfg    = keywordMap != null ? keywordMap.get('HDPE')    : null;

        List<Tender__c> toUpdate = new List<Tender__c>();

        for (Tender__c t : scope) {

            String  summary        = '=== Polymer/HDPE Check for Tender: ' + t.Name + ' (Id: ' + t.Id + ') ===\n';
            summary += 'Started: ' + System.now().format() + '\n\n';
            String  matchedProduct = null;
            Boolean properlyChecked = false;
            String  stageStatus     = 'Failed - Unexpected Error';

            try {
                if (polymerCfg == null && hdpeCfg == null) {
                    summary += 'FAILED: Could not load "Polymer_Relevant" / "HDPE_Relevant" metadata records from Tender_Key_words_Final__mdt. Aborting this record.\n';
                    System.debug('[PolymerHDPEBatch] keyword metadata missing for Tender Id: ' + t.Id);
                    toUpdate.add(buildUpdateRecord(t.Id, 'HDPE', summary, false, 'Failed - Config Error'));
                    continue;
                }

                // ============================================================
                // STEP 1: Try to resolve the department from the merged AI
                // Summary + Description via the native Prompt Builder Flex
                // Template, BEFORE touching any documents at all.
                // ============================================================
                PolymerHDPEPromptService.MergedSummaryResult mergedSummary =
                    PolymerHDPEPromptService.mergeAiSummary(t.Id);

                if (mergedSummary.wasTruncated) {
                    summary += 'NOTE: AI Summary was larger than the safe prompt limit and was truncated before being sent to the Prompt Template.\n';
                }

                PolymerHDPEPromptService.PromptResult promptResult = PolymerHDPEPromptService.checkDepartment(
                    t, mergedSummary.mergedText, mergedSummary.wasTruncated, polymerCfg, hdpeCfg
                );

                if (!promptResult.fired) {
                    summary += 'STEP 1 SKIPPED: No AI Summary and no Tender_Description__c available - nothing to send to the Prompt Template.\n';
                } else if (promptResult.hadError) {
                    summary += 'STEP 1 ERROR: Prompt Template call failed - ' + promptResult.errorMessage + '\n';
                } else if (promptResult.parseFailed) {
                    summary += 'STEP 1 WARNING: Prompt Template response could not be parsed as JSON. Treating as no match. Raw response logged separately in Integration_Log__c.\n';
                } else if (promptResult.matchedDepartment != null) {
                    // ---- RESOLVED IN STEP 1 - finalize this Tender now, skip Step 2 entirely ----
                    summary += 'STEP 1 MATCH: Department resolved as "' + promptResult.matchedDepartment
                              + '" from AI Summary/Description via Prompt Template.\n';
                    summary += 'Reasoning: ' + promptResult.reasoning + '\n';
                    summary += '\nFINAL RESULT: SUCCESS (Step 1 - AI Summary/Description Prompt). Product Name updated to "'
                              + promptResult.matchedDepartment + '".\n';

                    toUpdate.add(buildUpdateRecord(t.Id, promptResult.matchedDepartment, summary, true, 'Matched'));
                    continue; // move to next Tender - Step 2 not needed
                } else {
                    summary += 'STEP 1: No department matched from AI Summary/Description. Falling back to document analysis (Step 2).\n';
                }

                // ============================================================
                // STEP 2 (FALLBACK): Only reached if Step 1 did not resolve a
                // department. Existing document-based Gemini check, unchanged
                // in structure, updated only to use the new keyword configs
                // and matchedDepartment-based result shape.
                // ============================================================
                List<Tender_Docoment_Details__c> docs = t.Tender_Docoment_Details__r;

                if (docs == null || docs.isEmpty()) {
                    summary += 'No Tender_Docoment_Details__c child records found. Nothing to process.\n';
                    summary += 'FINAL RESULT: No documents to analyze. Defaulting to HDPE.\n';
                    System.debug('[PolymerHDPEBatch] no child documents for Tender Id: ' + t.Id);
                    toUpdate.add(buildUpdateRecord(t.Id, 'HDPE', summary, false, 'Failed - No Documents'));
                    continue;
                }

                Boolean matchFound = false;
                Boolean hadProcessingError = false;
                Boolean anySupportedFileFound = false;
                for (Tender_Docoment_Details__c d : docs) {

                    if (matchFound) break;

                    String fileLabel = String.isNotBlank(d.Name__c) ? d.Name__c : ('DocId:' + d.Document_Id__c);

                    PolymerHDPEFileUtil.SupportCheck sc = PolymerHDPEFileUtil.checkSupport(d.Name__c);

                    if (!sc.isSupported) {
                        summary += 'SKIPPED "' + fileLabel + '" (Type: ' + d.Type__c + ') - Reason: ' + sc.reason + '\n';
                        System.debug('[PolymerHDPEBatch] unsupported file skipped - ' + fileLabel);
                        continue;
                    }

                    anySupportedFileFound = true;

                    String effectiveUrl = String.isNotBlank(d.Download_URL__c)
                        ? d.Download_URL__c
                        : d.Download_URL_Text__c;

                    if (String.isBlank(effectiveUrl)) {
                        summary += 'SKIPPED "' + fileLabel + '" - Reason: Both Download_URL__c and Download_URL_Text__c are blank.\n';
                        System.debug('[PolymerHDPEBatch] blank download URL for file - ' + fileLabel);
                        continue;
                    }

                    Blob fileBytes = null;
                    try {
                        HttpRequest req = new HttpRequest();
                        req.setEndpoint(effectiveUrl);
                        req.setMethod('GET');
                        req.setTimeout(120000);

                        Http         http = new Http();
                        HttpResponse res  = http.send(req);

                        System.debug('[PolymerHDPEBatch] download status ' + res.getStatusCode() + ' for file - ' + fileLabel);

                        if (res.getStatusCode() != 200) {
                            summary += 'ERROR downloading "' + fileLabel + '" - HTTP Status: ' + res.getStatusCode() + '. Skipping to next file.\n';
                            hadProcessingError = true;
                            continue;
                        }
                        fileBytes = res.getBodyAsBlob();

                    } catch (Exception de) {
                        summary += 'ERROR downloading "' + fileLabel + '" - Exception: ' + de.getMessage() + '. Skipping to next file.\n';
                        System.debug('[PolymerHDPEBatch] download exception for file ' + fileLabel + ' - ' + de.getMessage());
                        hadProcessingError = true;
                        continue;
                    }

                    /*
                     if (fileBytes == null || fileBytes.size() == 0) {
                        summary += 'SKIPPED "' + fileLabel + '" - Downloaded content is empty.\n';
                        System.debug('[PolymerHDPEBatch] empty content for file - ' + fileLabel);
                        hadProcessingError = true;
                        continue;
                    }

                    summary += 'READING "' + fileLabel + '" (Type: ' + d.Type__c + ', MIME: ' + sc.mimeType + ', Size: ' + fileBytes.size() + ' bytes)\n';
                    System.debug('[PolymerHDPEBatch] sending file to Gemini - ' + fileLabel + ' (' + fileBytes.size() + ' bytes)');

                    PolymerHDPEGeminiService.MatchResult mr = PolymerHDPEGeminiService.checkFile(
                        fileBytes, sc.mimeType, fileLabel, t.Id, polymerCfg, hdpeCfg
                    );
                    */
                                        if (fileBytes == null || fileBytes.size() == 0) {
                        summary += 'SKIPPED "' + fileLabel + '" - Downloaded content is empty.\n';
                        System.debug('[PolymerHDPEBatch] empty content for file - ' + fileLabel);
                        hadProcessingError = true;
                        continue;
                    }

                    // ---- NEW: heap guard before base64/JSON/Gemini callout ----
                    Integer heapRemaining   = Limits.getLimitHeapSize() - Limits.getHeapSize();
                    Integer estimatedNeeded = fileBytes.size() * HEAP_SAFETY_MULTIPLIER;

                    if (fileBytes.size() > MAX_FILE_BYTES_FOR_GEMINI || estimatedNeeded > heapRemaining) {
                        summary += 'SKIPPED "' + fileLabel + '" - File too large to safely analyze (size: '
                            + fileBytes.size() + ' bytes, heap remaining: ' + heapRemaining + '). Defaulting to no-match for this file.\n';

                        IntegrationLogger.log(
                            'PolymerHDPEFileCheck', 'Gemini', 'gemini-2.5-flash:generateContent',
                            null, null, null, false,
                            'Skipped - file too large for heap (' + fileBytes.size() + ' bytes): ' + fileLabel,
                            t.Id
                        );

                        fileBytes = null;
                        matchedProduct = 'HDPE';
                        continue;
                    }
                    // ---- END heap guard ----

                    summary += 'READING "' + fileLabel + '" (Type: ' + d.Type__c + ', MIME: ' + sc.mimeType + ', Size: ' + fileBytes.size() + ' bytes)\n';
                    System.debug('[PolymerHDPEBatch] sending file to Gemini - ' + fileLabel + ' (' + fileBytes.size() + ' bytes)');

                    PolymerHDPEGeminiService.MatchResult mr = PolymerHDPEGeminiService.checkFile(
                        fileBytes, sc.mimeType, fileLabel, t.Id, polymerCfg, hdpeCfg
                    );

                    if (mr.hadError) {
                        summary += 'ERROR analyzing "' + fileLabel + '" via Gemini: ' + mr.errorMessage + '. Skipping to next file.\n';
                        System.debug('[PolymerHDPEBatch] Gemini error for file ' + fileLabel + ' - ' + mr.errorMessage);
                        hadProcessingError = true;
                        continue;
                    }

                    System.debug('[PolymerHDPEBatch] Gemini result for ' + fileLabel + ' - matchedDepartment=' + mr.matchedDepartment);

                    if (mr.matchedDepartment != null) {
                        matchedProduct = mr.matchedDepartment;
                        matchFound     = true;
                        summary += 'MATCH in "' + fileLabel + '": Department = "' + matchedProduct + '".\n';
                        summary += 'Reasoning: ' + mr.reasoning + '\n';
                    } else {
                        summary += 'No match in "' + fileLabel + '" (neither Polymer nor HDPE). Reasoning: ' + mr.reasoning + '. Moving to next file.\n';
                        matchedProduct = 'HDPE';
                    }
                }

                if (matchFound) {
                    summary += '\nFINAL RESULT: SUCCESS (Step 2 - Document Analysis). Product Name updated to "' + matchedProduct + '".\n';
                    properlyChecked = true;
                    stageStatus     = 'Matched';
                } else if (hadProcessingError) {
                    summary += '\nFINAL RESULT: No product matched, but one or more files FAILED to be analyzed properly (Gemini/download error). Defaulting to HDPE.\n';
                    properlyChecked = false;
                    stageStatus     = 'Failed - Will Retry';
                    matchedProduct  = 'HDPE';
                } else if (!anySupportedFileFound) {
                    summary += '\nFINAL RESULT: No supported file types found to analyze (only unsupported formats present). Defaulting to HDPE.\n';
                    properlyChecked = true;
                    stageStatus     = 'No Supported Files';
                    matchedProduct  = 'HDPE';
                } else {
                    summary += '\nFINAL RESULT: No product matched after checking all supported files properly (Step 1 and Step 2 both exhausted). Defaulting to HDPE.\n';
                    properlyChecked = true;
                    stageStatus     = 'Checked - No Match';
                    matchedProduct  = 'HDPE';
                }

                System.debug('[PolymerHDPEBatch] Tender ' + t.Id + ' - matchFound=' + matchFound + ', hadProcessingError=' + hadProcessingError + ', anySupportedFileFound=' + anySupportedFileFound + ', properlyChecked=' + properlyChecked + ', stageStatus=' + stageStatus + ', matchedProduct=' + matchedProduct);

            } catch (Exception ex) {
                summary += '\nUNEXPECTED ERROR while processing this Tender: ' + ex.getMessage() + '\n';
                System.debug('[PolymerHDPEBatch] record-level error for ' + t.Id + ': ' + ex.getMessage() + ' | ' + ex.getStackTraceString());
                properlyChecked = false;
                stageStatus     = 'Failed - Unexpected Error';
                matchedProduct  = 'HDPE';
            }

            toUpdate.add(buildUpdateRecord(t.Id, matchedProduct, summary, properlyChecked, stageStatus));
        }

        /*if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('[PolymerHDPEBatch] DML FAILED for Tender Id: ' + toUpdate[i].Id + ' | Errors: ' + results[i].getErrors());
                }
            }
        }*/
        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    String err = 'Tender ' + toUpdate[i].Id + ' : ' + results[i].getErrors();
                    System.debug('[PolymerHDPEBatch] DML FAILED ' + err);
                    dmlErrors.add(err);
                }
            }
        }

        // Flush every Step 1 (Prompt Builder) and Step 2 (Gemini file check)
        // log queued up during this chunk's processing, so nothing is lost
        // even though this is an unattended scheduled run.
        IntegrationLogger.flush();
    }

    // ----------------------------------------------------------------------
    // METHOD: finish
    // Final safety-net flush in case anything was queued but not yet
    // committed (should normally be empty since execute() already flushes).
    // ----------------------------------------------------------------------
    public void finish(Database.BatchableContext bc) {
        System.debug('[PolymerHDPEBatch] FINISHED.');
        IntegrationLogger.flush();
    }

    // ----------------------------------------------------------------------
    // METHOD: buildUpdateRecord
    // Builds the Tender__c update sObject for one Tender's final outcome.
    // Unchanged structurally from before - matchedProduct now always comes
    // from either the Prompt Template's JSON output, the Gemini file check's
    // matchedDepartment, or the hardcoded "HDPE" default fallback.
    // ----------------------------------------------------------------------
    /*
     private static Tender__c buildUpdateRecord(Id tenderId, String matchedProduct, String summary, Boolean properlyChecked, String stageStatus) {
        System.debug('[PolymerHDPEBatch] buildUpdateRecord - Tender Id: ' + tenderId + ', matchedProduct: ' + matchedProduct + ', properlyChecked: ' + properlyChecked + ', stageStatus: ' + stageStatus);
        Tender__c upd = new Tender__c(
            Id                                = tenderId,
            Is_checked_Polymer_HDPE__c       = properlyChecked,
            Reading_Polymer_HDPE_summary__c  = truncateSummary(summary),
            Polymer_HDPE_Stage_Check__c      = stageStatus
        );
        if (matchedProduct != null) {
            //upd.Product_Name__c    = matchedProduct;
            upd.Department_Name__c = matchedProduct;
            System.debug('[PolymerHDPEBatch] Department_Name__c set to "' + matchedProduct + '" for Tender Id: ' + tenderId);
        }
        return upd;
    }
    */
    private Tender__c buildUpdateRecord(Id tenderId, String matchedProduct, String summary, Boolean properlyChecked, String stageStatus) {
        System.debug('[PolymerHDPEBatch] buildUpdateRecord - Tender Id: ' + tenderId + ', matchedProduct: ' + matchedProduct + ', properlyChecked: ' + properlyChecked + ', stageStatus: ' + stageStatus);
        Tender__c upd = new Tender__c(
            Id                              = tenderId,
            Is_checked_Polymer_HDPE__c      = properlyChecked,
            Reading_Polymer_HDPE_summary__c = truncateSummary(summary),
            Polymer_HDPE_Stage_Check__c     = stageStatus
        );
        if (matchedProduct != null) {
            upd.Product_Name__c    = matchedProduct;
            upd.Department_Name__c = matchedProduct;
            
            Id ownerId = ownerMap.get(matchedProduct); // 'Polymer' ba 'HDPE'
            if (ownerId != null) {
                upd.OwnerId = ownerId;
            }
        }
        return upd;
    }

    // ----------------------------------------------------------------------
    // METHOD: truncateSummary
    // Keeps the readable summary log within the Long Text Area's hard
    // character cap. Unchanged from before.
    // ----------------------------------------------------------------------
    private static String truncateSummary(String summary) {
        if (summary.length() > SUMMARY_MAX_LEN) {
            return summary.substring(0, SUMMARY_MAX_LEN - 30) + '\n...[TRUNCATED - see logs]';
        }
        return summary;
    }
}