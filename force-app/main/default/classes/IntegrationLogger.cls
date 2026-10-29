/*
Owner - Ayantika
CLASS: IntegrationLogger

Creates a log record for every API call made by the integration.
Stores details like endpoint, request, response, status, Common Key, and Tender.
Stores the API response in the parent Integration_Log__c record.
Splits large JSON responses into smaller chunks and stores them in Integration_JSON_Log__c child records.
Keeps the sequence number of each JSON chunk so the original response order is maintained.
Uses log() to prepare and queue the log records.
Uses flush() to insert the parent logs and JSON child records in bulk.
If a log insert fails, it creates a failure log with the error details.
Handles logging errors separately so that logging failure does not stop the main integration process.
Overall, this class provides permanent tracking of API calls, responses, and errors for the Tender integration.
*/
public class IntegrationLogger {
    
    // Max characters allowed per Integration_JSON_Log__c.JSON_Details__c chunk.
    private static final Integer CHUNK_SIZE = 131072;
    
    // Max characters kept on the PARENT's Response_Body__c /
    // Response_Payload__c fields. Set this a little below the actual max
    // length configured on those fields in Setup, so the parent insert can
    // never fail with STRING_TOO_LONG. Full data is never lost - it's always
    // fully preserved, unchunked, in the Integration_JSON_Log__c children.
    private static final Integer PARENT_PREVIEW_LIMIT = 5000;
    
    // Fixed values constant across every callout in this integration.
    private static final String DEFAULT_HTTP_METHOD = 'POST';
    private static final String INTEGRATION_NAME     = 'Tender247';
    
    // Pairs a parent log record with the raw JSON it needs to be chunked into,
    // so parents can be inserted first (to get Ids) and children built after.
    private class PendingEntry {
        Integration_Log__c parent;
        String jsonBody;
        PendingEntry(Integration_Log__c parent, String jsonBody) {
            this.parent = parent;
            this.jsonBody = jsonBody;
        }
    }
    
    // Buffer so we only do bulk DML per flush() call, never one insert per log entry.
    private static List<PendingEntry> pendingEntries = new List<PendingEntry>();
    
    public static Integration_Log__c log(String stage, String productName, String endpoint,
                                         String requestBody, String responseBody,
                                         Integer statusCode, Boolean isSuccess, String errorMessage) {
                                             return log(stage, productName, endpoint, requestBody, responseBody,
                                                        statusCode, isSuccess, errorMessage, null, null);
                                         }
    
    public static Integration_Log__c log(String stage, String productName, String endpoint,
                                         String requestBody, String responseBody,
                                         Integer statusCode, Boolean isSuccess, String errorMessage,
                                         Id tenderId) {
                                             return log(stage, productName, endpoint, requestBody, responseBody,
                                                        statusCode, isSuccess, errorMessage, tenderId, null);
                                         }
    
    public static Integration_Log__c log(String stage, String productName, String endpoint,
                                         String requestBody, String responseBody,
                                         Integer statusCode, Boolean isSuccess, String errorMessage,
                                         Id tenderId, String commonKey) {
                                             return log(stage, productName, endpoint, requestBody, responseBody,
                                                        statusCode, isSuccess, errorMessage, tenderId, commonKey, null);
                                         }
    
    
    public static Integration_Log__c log(String stage, String productName, String endpoint,
                                         String requestBody, String responseBody,
                                         Integer statusCode, Boolean isSuccess, String errorMessage,
                                         Id tenderId, String commonKey, Integer mailType) {
                                             
                                             Integration_Log__c logRec = new Integration_Log__c();
                                             logRec.Stage__c          = stage;
                                             logRec.Product_Name__c   = productName;
                                             logRec.Endpoint__c       = endpoint;
                                             logRec.Request_Body__c   = requestBody;
                                             // truncated preview instead of full raw value, to
                                             // guarantee this field's length can never exceed its max and fail
                                             // the parent insert. Full value is preserved in the child chunks.
                                             logRec.Response_Body__c  = responseBody != null ? responseBody.abbreviate(PARENT_PREVIEW_LIMIT) : null;
                                             logRec.Status_Code__c    = statusCode;
                                             logRec.Is_Success__c     = isSuccess;
                                             logRec.Error_Message__c  = errorMessage;
                                             logRec.Tender__c         = tenderId;
                                             logRec.Common_Key__c     = commonKey;
                                             // stamps the MailType passed in (0=Whole-day, 1=Morning, 2=Noon).
                                             logRec.MailType__c       = mailType;
                                             
                                             logRec.Called_At__c            = System.now();
                                             logRec.Http_Method__c          = DEFAULT_HTTP_METHOD;
                                             logRec.Integration_Name__c     = INTEGRATION_NAME;
                                             logRec.Request_Payload__c      = requestBody;
                                             // same truncation as Response_Body__c above, same reason.
                                             logRec.Response_Payload__c     = responseBody != null ? responseBody.abbreviate(PARENT_PREVIEW_LIMIT) : null;
                                             logRec.Response_Http_Status__c = statusCode;
                                             logRec.Status__c               = isSuccess ? 'Success' : 'Failed';
                                             
                                             // Don't chunk yet - we need this parent's Id first, which we only get
                                             // after insert. Just queue it alongside the raw JSON for now.
                                             pendingEntries.add(new PendingEntry(logRec, responseBody));
                                             
                                             System.debug('[IntegrationLogger] Queued log for Stage=' + stage
                                                          + ' Product=' + productName + ' Tender=' + tenderId
                                                          + ' CommonKey=' + commonKey + ' Status=' + statusCode);
                                             
                                             // <<< NEW >>> return the queued record so callers can stamp extra
                                             // fields (e.g. Tender_Record_Count__c) onto it before flush() runs.
                                             return logRec;
                                         }
    
    // Call this ONCE at the end of every execute()/finish() to flush all queued
    // logs. Inserts parents first, then chunks each one's JSON into child
    // Integration_JSON_Log__c records and bulk inserts those too.
    public static void flush() {
        if (pendingEntries.isEmpty()) {
            return;
        }
        
        try {
            List<Integration_Log__c> parents = new List<Integration_Log__c>();
            for (PendingEntry pe : pendingEntries) {
                parents.add(pe.parent);
            }
            // partial-success insert instead of all-or-nothing
            // "insert parents;" - so one bad record no longer drops every log
            // for the product/run. Any failure is captured below instead of
            // being silently lost.
            Database.SaveResult[] parentResults = Database.insert(parents, false);
            
            List<Integration_JSON_Log__c> children = new List<Integration_JSON_Log__c>();
            List<Integration_Log__c> failureLogs = new List<Integration_Log__c>();
            
            for (Integer i = 0; i < parentResults.size(); i++) {
                Database.SaveResult res = parentResults[i];
                PendingEntry pe = pendingEntries[i];
                
                if (res.isSuccess()) {
                    if (String.isNotBlank(pe.jsonBody)) {
                        List<String> chunks = chunkString(pe.jsonBody, CHUNK_SIZE);
                        for (Integer c = 0; c < chunks.size(); c++) {
                            Integration_JSON_Log__c child = new Integration_JSON_Log__c();
                            child.Integration_Log__c = res.getId();
                            child.JSON_Details__c    = chunks[c];
                            child.Sequence__c        = c + 1;
                            children.add(child);
                        }
                    }
                } else {
                    // capture the real reason this parent failed,
                    // as a small guaranteed-safe record (no large fields), instead
                    // of just a debug line nobody sees on an unattended run.
                    String errMsg = '';
                    for (Database.Error err : res.getErrors()) {
                        errMsg += err.getStatusCode() + ': ' + err.getMessage() + ' | Fields: ' + err.getFields() + '; ';
                    }
                    System.debug('[IntegrationLogger] PARENT INSERT FAILED: ' + errMsg);
                    
                    Integration_Log__c fallback = new Integration_Log__c();
                    fallback.Stage__c            = 'LOG_INSERT_FAILED';
                    fallback.Product_Name__c     = pe.parent.Product_Name__c;
                    fallback.Endpoint__c         = pe.parent.Endpoint__c;
                    fallback.Error_Message__c    = errMsg.abbreviate(255);
                    fallback.Status__c           = 'Failed';
                    fallback.Called_At__c        = System.now();
                    fallback.Integration_Name__c = INTEGRATION_NAME;
                    failureLogs.add(fallback);
                }
            }
            
            if (!failureLogs.isEmpty()) {
                Database.insert(failureLogs, false);
            }
            
            if (!children.isEmpty()) {
                Database.insert(children, false);
            }
            
            System.debug('[IntegrationLogger] Flushed ' + parents.size() + ' log record(s) and '
                         + children.size() + ' JSON chunk record(s).');
            
        } catch (Exception e) {
            System.debug('[IntegrationLogger] FAILED to insert logs: ' + e.getMessage());
        } finally {
            pendingEntries.clear();
        }
    }
    
    // Splits str into a list of substrings, each at most size characters long -
    // one substring per child Integration_JSON_Log__c record.
    private static List<String> chunkString(String str, Integer size) {
        List<String> result = new List<String>();
        Integer len = str.length();
        Integer pos = 0;
        while (pos < len) {
            Integer endPos = Math.min(pos + size, len);
            result.add(str.substring(pos, endPos));
            pos = endPos;
        }
        return result;
    }
}