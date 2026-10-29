public class TenderAISummaryBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private static final String NAMED_CREDENTIAL = 'callout:tender247_Tender';
    private static final String ENDPOINT_PATH    = '/Utkarsh/api/tender-ai-summary/';

    // Picklist values on Tender_AI_Summary_status__c.
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAIL    = 'Fail';
    private static final String STATUS_NONE    = 'None';

    // Kept a little below the actual 131072 field max as a safety margin,
    // since Rich Text Area storage can add slight overhead for HTML-sensitive
    // characters (<, >, &) that might appear in the raw JSON.
    private static final Integer RTA_SAFE_LIMIT = 130000;

    // Stateful counters just for a clean finish() summary log - doesn't affect logic.
    private Integer totalProcessed = 0;
    private Integer totalFailed = 0;

    // Small holder so we can keep callout results in memory and only touch
    // the database (DML) after every callout in the scope has fired.
    private class CalloutResult {
        Id tenderId;
        Integer statusCode;
        String responseBody;
        Boolean success;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[TenderAISummaryBatch] START');

        // TEMP/TEST FILTER - swap back to the real filter below when done testing.
        /*return Database.getQueryLocator([
            SELECT Id, Tender_AI_Summary__c, External_Tender_Id__c, Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE External_Tender_Id__c = '102957580'
        ]);

        
        return Database.getQueryLocator([
            SELECT Id, Tender_AI_Summary__c, Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE CreatedDate = TODAY
              AND (Tender_AI_Summary_status__c IN :new List<String>{ STATUS_NONE, STATUS_FAIL }
                   OR Tender_AI_Summary_status__c = null)
              AND Tender_AI_Summary__c != null
        ]);
        */
        return Database.getQueryLocator([
            SELECT Id, Tender_AI_Summary__c, Tender_AI_Summary_status__c
            FROM Tender__c
            WHERE CreatedDate = TODAY
              AND (Tender_AI_Summary_status__c IN :new List<String>{ STATUS_NONE, STATUS_FAIL }
                   OR Tender_AI_Summary_status__c = null)
              AND Tender_AI_Summary__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {

        System.debug('[TenderAISummaryBatch] execute() - scope size = ' + scope.size());

        // ============================================================
        // PHASE 1: CALLOUTS ONLY. No DML of any kind allowed in here -
        // that is what was causing "uncommitted work pending" before,
        // since the old code deleted chunk records before this loop.
        // ============================================================
        List<CalloutResult> calloutResults = new List<CalloutResult>();

        for (sObject s : scope) {
            Tender__c tnd = (Tender__c) s;
            String rawValue = tnd.Tender_AI_Summary__c;

            CalloutResult cr = new CalloutResult();
            cr.tenderId = tnd.Id;

            if (String.isBlank(rawValue)) {
                // Nothing to call - mark as Fail so it doesn't get silently
                // stuck as 'None' forever with no record of why it was skipped.
                cr.success = false;
                cr.statusCode = null;
                cr.responseBody = 'SKIPPED: Tender_AI_Summary__c is blank';
                System.debug('[TenderAISummaryBatch] Skipping Tender ' + tnd.Id + ' - blank Tender_AI_Summary__c');
                calloutResults.add(cr);
                continue;
            }

            // Tender_AI_Summary__c stores the FULL upstream URL, not just the
            // token - e.g. "https://utkarshapi.tender247.com/Utkarsh/api/tender-ai-summary/<token>".
            // Extract just the token (the part after the LAST '/') and hit it
            // via the Named Credential, so we don't end up with the path
            // duplicated (which was causing 404s). Falls back to the raw value
            // as-is if no '/' is found, so a bare token would still work fine.
            String actualToken = rawValue;
            Integer lastSlash = rawValue.lastIndexOf('/');
            if (lastSlash >= 0 && lastSlash < rawValue.length() - 1) {
                actualToken = rawValue.substring(lastSlash + 1);
            }

            System.debug('[TenderAISummaryBatch] Tender ' + tnd.Id + ' - token = ' + actualToken);

            Integer statusCode;
            String responseBody;
            Boolean success = false;

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(NAMED_CREDENTIAL + ENDPOINT_PATH + actualToken);
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Accept', 'application/json');
                req.setTimeout(120000);

                Http http = new Http();
                HttpResponse res = http.send(req);
                statusCode   = res.getStatusCode();
                responseBody = res.getBody();

                System.debug('[TenderAISummaryBatch] Tender ' + tnd.Id
                              + ' - statusCode=' + statusCode
                              + ' responseLength=' + (responseBody == null ? 0 : responseBody.length()));

                if (statusCode == 200 && String.isNotBlank(responseBody)) {
                    success = true;
                }

            } catch (Exception e) {
                responseBody = 'EXCEPTION: ' + e.getMessage();
                System.debug('[TenderAISummaryBatch] EXCEPTION for Tender ' + tnd.Id + ': ' + e.getMessage());
            }

            cr.statusCode = statusCode;
            cr.responseBody = responseBody;
            cr.success = success;
            calloutResults.add(cr);

            if (success) {
                totalProcessed++;
            } else {
                totalFailed++;
            }
        }

        System.debug('[TenderAISummaryBatch] All callouts complete for this scope. Moving to DML phase.');

        // ============================================================
        // PHASE 2: DML ONLY. All callouts for this scope are done, so
        // it is now safe to run DML (delete/insert/update) plus any
        // logging flush that itself performs DML.
        // ============================================================

        // 2a. Delete existing chunk records for the tenders in this scope
        //     (safe now - no callout will run after this point).
        Set<Id> scopeIds = new Set<Id>();
        for (sObject s : scope) {
            scopeIds.add(s.Id);
        }

        List<Tender_AI_Summary_JSON__c> oldChunks = [
            SELECT Id FROM Tender_AI_Summary_JSON__c WHERE Tender__c IN :scopeIds
        ];
        System.debug('[TenderAISummaryBatch] Deleting ' + oldChunks.size() + ' old chunk record(s).');
        /*
        if (!oldChunks.isEmpty()) {
            delete oldChunks;
        }
*/
        if (!oldChunks.isEmpty()) {
    try {
        Database.delete(oldChunks, false);
    } catch (Exception e) {
        System.debug('[TenderAISummaryBatch] DELETE EXCEPTION: ' + e.getMessage());
    }
}

        // 2b. Build and insert new chunk records + build Tender__c status updates
        //     + log via IntegrationLogger, using the in-memory callout results.
        List<Tender_AI_Summary_JSON__c> chunksToInsert = new List<Tender_AI_Summary_JSON__c>();
        List<Tender__c> tendersToUpdate = new List<Tender__c>();

        for (CalloutResult cr : calloutResults) {
            Tender__c toUpdate = new Tender__c(Id = cr.tenderId);
            toUpdate.Tender_AI_Summary_status__c = cr.success ? STATUS_SUCCESS : STATUS_FAIL;
            tendersToUpdate.add(toUpdate);

            chunksToInsert.addAll(buildChunkRecords(cr.tenderId, cr.responseBody));

            try {
                IntegrationLogger.log(
                    'TenderAISummary',
                    null,
                    'tender-ai-summary',
                    null,
                    cr.responseBody,
                    cr.statusCode,
                    cr.success,
                    cr.success ? null : cr.responseBody,
                    cr.tenderId,
                    null
                );
            } catch (Exception logEx) {
                System.debug('[TenderAISummaryBatch] MAIN LOG FAILED for Tender ' + cr.tenderId + ': ' + logEx.getMessage());
            }
        
        }

        System.debug('[TenderAISummaryBatch] Inserting ' + chunksToInsert.size() + ' new chunk record(s).');
        if (!chunksToInsert.isEmpty()) {
            Database.SaveResult[] chunkResults = Database.insert(chunksToInsert, false);

            for (Integer i = 0; i < chunkResults.size(); i++) {
                if (chunkResults[i].isSuccess()) {
                    System.debug('[TenderAISummaryBatch] CHUNK INSERT SUCCESS - Id=' + chunkResults[i].getId()
                                 + ' Seq=' + chunksToInsert[i].Sequence_Number__c
                                 + ' Tender=' + chunksToInsert[i].Tender__c);
                } else {
                    String errMsg = '';
                    for (Database.Error err : chunkResults[i].getErrors()) {
                        System.debug('================ CHUNK INSERT ERROR ================');
                        System.debug('StatusCode : ' + err.getStatusCode());
                        System.debug('Message    : ' + err.getMessage());
                        System.debug('Fields     : ' + err.getFields());
                        System.debug('Seq        : ' + chunksToInsert[i].Sequence_Number__c);
                        System.debug('Tender     : ' + chunksToInsert[i].Tender__c);
                        errMsg += err.getStatusCode() + ': ' + err.getMessage() + ' Fields=' + err.getFields() + '; ';
                    }
                    try {
                        IntegrationLogger.log(
                            'TenderAISummaryChunkInsert',
                            null,
                            'tender-ai-summary-chunk-insert',
                            null,
                            errMsg,
                            null,
                            false,
                            errMsg,
                            chunksToInsert[i].Tender__c,
                            null
                        );
                    } catch (Exception logEx) {
                        System.debug('[TenderAISummaryBatch] LOG FAILED for chunk error: ' + logEx.getMessage());
                    }
                }
            }
        }

        System.debug('[TenderAISummaryBatch] Updating ' + tendersToUpdate.size() + ' Tender__c record(s).');
        if (!tendersToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(tendersToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    String errMsg = '';
                    for (Database.Error err : results[i].getErrors()) {
                        errMsg += err.getStatusCode() + ': ' + err.getMessage() + ' Fields=' + err.getFields() + '; ';
                    }
                    System.debug('[TenderAISummaryBatch] UPDATE FAILED for Tender '
                                 + tendersToUpdate[i].Id + ': ' + errMsg);
                    
                    try {
                        IntegrationLogger.log(
                            'TenderAISummaryTenderUpdate',
                            null,
                            'tender-ai-summary-tender-update',
                            null,
                            errMsg,
                            null,
                            false,
                            errMsg,
                            tendersToUpdate[i].Id,
                            null
                        );
                    } catch (Exception logEx) {
                        System.debug('[TenderAISummaryBatch] LOG FAILED for tender update error: ' + logEx.getMessage());
                    }
                } else {
                    System.debug('[TenderAISummaryBatch] UPDATE SUCCESS for Tender ' + tendersToUpdate[i].Id);
                }
            }
        }
        
        // Flush logger DML AFTER all callouts - same reasoning as above.
        //IntegrationLogger.flush();
        try {
            IntegrationLogger.flush();
        } catch (Exception e) {
            System.debug('[TenderAISummaryBatch] LOGGER FLUSH EXCEPTION: ' + e.getMessage());
        }
        System.debug('[TenderAISummaryBatch] execute() complete for this scope.');
    }

    /*public void finish(Database.BatchableContext bc) {
        System.debug('[TenderAISummaryBatch] FINISH - Processed=' + totalProcessed + ' Failed=' + totalFailed);
        IntegrationLogger.flush();
    }*/
    // ----------------------------------------------------------------------
    // METHOD: finish
    // Logs a summary of this run, flushes any remaining IntegrationLogger
    // entries, and then CHAINS into PolymerHDPEBatch - this guarantees the
    // Polymer/HDPE classification step (which needs today's freshly-fetched
    // AI Summary data) always runs AFTER the AI Summary fetch has fully
    // completed for this scheduled run, never in parallel with it.
    // <<< CHANGED >>> added Database.executeBatch(new PolymerHDPEBatch())
    // at the end - this is safe to call from inside finish(), since finish()
    // itself runs in its own async transaction (the "cannot start a batch
    // from a batch" restriction only applies to start()/execute()).
    // ----------------------------------------------------------------------
    public void finish(Database.BatchableContext bc) {
        System.debug('[TenderAISummaryBatch] FINISH - Processed=' + totalProcessed + ' Failed=' + totalFailed);
        IntegrationLogger.flush();

        System.debug('[TenderAISummaryBatch] Chaining into PolymerHDPEBatch now that AI Summary fetch is complete.');
        Database.executeBatch(new PolymerHDPEBatch(), 1);
    }

    // Splits the raw JSON into RTA_SAFE_LIMIT-sized pieces, one
    // Tender_AI_Summary_JSON__c child record per piece, sequenced from 1.
    private List<Tender_AI_Summary_JSON__c> buildChunkRecords(Id tenderId, String json) {
        List<Tender_AI_Summary_JSON__c> chunks = new List<Tender_AI_Summary_JSON__c>();

        if (String.isBlank(json)) {
            return chunks;
        }

        Integer seq = 1;
        Integer offset = 0;
        Integer len = json.length();

        while (offset < len) {
            Integer endIdx = Math.min(offset + RTA_SAFE_LIMIT, len);
            String piece = json.substring(offset, endIdx);

            chunks.add(new Tender_AI_Summary_JSON__c(
                Tender__c          = tenderId,
                Sequence_Number__c = seq,
                Ai_Summary_Json__c = piece
            ));

            System.debug('[TenderAISummaryBatch] Built chunk seq=' + seq
                         + ' for Tender=' + tenderId
                         + ' length=' + piece.length());

            offset = endIdx;
            seq++;
        }

        return chunks;
    }
}