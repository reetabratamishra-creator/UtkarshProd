/*
Owner - Ayantika
CLASS: TenderListingBatch

Runs as Stage 1 of the daily Tender integration.
Runs for each Product configured in Tender_Product_Mapping__mdt.
Calls the Tender Listing Data Count API to get the total number of Tenders.
Calculates the required number of pages and calls the Tender Listing Data API for each page.
Checks whether the Tender already exists using External_Tender_Id__c.
Skips existing Tenders if there is no corrigendum/update.
Creates new Tenders and updates existing Tenders when there is a genuine corrigendum.
Generates and assigns the Common Key for newly created Tenders.
Creates/updates Tender_Docoment_Details__c records from the Tender documents.
Sends document insertion to TenderDocumentInsertQueueable to manage the DML limit.
Creates Integration Logs for API calls and Tender processing.
For newly created or corrigendum-updated Tenders, starts Stage 2: ProbableBidderBatch in finish().
Overall, this class fetches Tenders from the API, creates/updates them in Salesforce, handles documents and logs, and then starts the Probable Bidder process.
*/

public class TenderListingBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    private static final String NAMED_CREDENTIAL = 'callout:tender247_Tender';
    private static final Integer RECORDS_PER_PAGE = Integer.valueOf(System.Label.Tender_RECORDS_PER_PAGE);
    private static final Integer DOC_INSERT_CHUNK_SIZE = 8000; // chunk size handed to each Queueable job
    
    // MailType values per Tender247 update: 0=Whole-day, 1=Morning, 2=Noon
    private Integer mailType;
    
    private Set<Id> newTenderIds = new Set<Id>();
    private Map<Id, String> newTenderProductMap = new Map<Id, String>();
    private Map<Id, String> mergeProductTenderMap = new Map<Id, String>();
    
    // Default constructor - defaults to Whole-day data (MailType = 0) for backward compatibility.
    public TenderListingBatch() {
        this.mailType = 0;
    }
    
    // Preferred constructor - called by TenderBatchScheduler with 1 (Morning) or 2 (Noon).
    public TenderListingBatch(Integer mailType) {
        this.mailType = mailType;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [SELECT Id, Tender_Product_Name__c, MergeProduct__c, Real_Product_Name__c, Owner_ID__c
             FROM Tender_Product_Mapping__mdt]
        );
    }
    
    // Runs once per Product (scope size = 1). Fetches count -> all pages ->
    // applies corrigendum skip logic -> upserts. Wrapped in a try/catch per
    // product so one failing product never blocks the rest of the batch.
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        
        for (sObject s : scope) {
            Tender_Product_Mapping__mdt product = (Tender_Product_Mapping__mdt) s;
            String productName = product.Tender_Product_Name__c;
            Boolean isMergeProduct = (product.MergeProduct__c == true);
            String departmentName = product.Real_Product_Name__c; // null if not set on the mdt record
            Id ownerId = String.isNotBlank(product.Owner_ID__c) ? (Id) product.Owner_ID__c : null; // <<< OWNER CHANGE >>>
            // ONE Base Common Key per Product per run - carried through Count,
            // every Listing page, and used as the prefix for every Tender-N key
            // for brand-new tenders created below.
            String baseCommonKey = generateBaseCommonKey(productName);
            Integer tenderSequence = 0; // increments ONLY for brand-new tenders this run
            
            System.debug('[TenderListingBatch] Processing Product: ' + productName
                         + ' | MailType=' + mailType + ' | BaseCommonKey=' + baseCommonKey);
            
            try {
                
                Integer totalCount = callCountApi(productName, baseCommonKey);
                if (totalCount == null || totalCount <= 0) {
                    IntegrationLogger.flush();
                    continue;
                }
                
                Integer totalPages = (Integer) Math.ceil(Decimal.valueOf(totalCount) / RECORDS_PER_PAGE);
                
                List<TenderWrappers.TenderRecord> allRecords = new List<TenderWrappers.TenderRecord>();
                
                for (Integer page = 1; page <= totalPages; page++) {
                    
                    // Each page call is isolated so a timeout on one page doesn't
                    // discard pages already fetched for this product.
                    try {
                        List<TenderWrappers.TenderRecord> pageRecords = callListingApi(productName, page, baseCommonKey);
                        if (pageRecords != null) {
                            allRecords.addAll(pageRecords);
                        }
                    } catch (Exception pageEx) {
                        IntegrationLogger.log(
                            'ListingPageFailed', productName,
                            'tender-listing-data (page ' + page + ')',
                            null, pageEx.getMessage(), null, false, pageEx.getMessage(),
                            null, baseCommonKey
                        );
                        IntegrationLogger.flush();
                        break;
                    }
                }
                
                // Build Tender__c candidates from the fetched API records.
                // Common_Key__c / Base_Common_Key__c are intentionally NOT set here -
                // they're assigned further below, only for tenders confirmed to be
                // brand-new (see corrigendum skip logic block).
                List<Tender__c> tendersToUpsert = new List<Tender__c>();
                List<TenderWrappers.TenderRecord> recordsForUpsert = new List<TenderWrappers.TenderRecord>();
                
                for (Integer i = 0; i < allRecords.size(); i++) {
                    //Tender__c t = mapToTenderRecord(allRecords[i], productName, isMergeProduct);
                    Tender__c t = mapToTenderRecord(allRecords[i], productName, isMergeProduct, departmentName, ownerId); // <<< OWNER CHANGE >>>
                    tendersToUpsert.add(t);
                    recordsForUpsert.add(allRecords[i]);
                }
                
                // Corrigendum skip logic: existing tenders only carry forward if
                // Corrigendum_Info__c = true; brand-new tenders always go through.
                Set<String> fetchedExtIds = new Set<String>();
                for (Tender__c t : tendersToUpsert) {
                    if (String.isNotBlank(t.External_Tender_Id__c)) {
                        fetchedExtIds.add(t.External_Tender_Id__c);
                    }
                }
                
                // Also pull each existing tender's CURRENT Common_Key__c so that if it
                // gets updated via corrigendum, we can still log against its ORIGINAL
                // key instead of generating a new Tender-N for it.
                Map<String, String> existingExtIdToCommonKey = new Map<String, String>();
                if (!fetchedExtIds.isEmpty()) {
                    for (Tender__c existing : [
                        SELECT External_Tender_Id__c, Common_Key__c
                        FROM Tender__c
                        WHERE External_Tender_Id__c IN :fetchedExtIds
                    ]) {
                        existingExtIdToCommonKey.put(existing.External_Tender_Id__c, existing.Common_Key__c);
                    }
                }
                Set<String> existingExtIds = existingExtIdToCommonKey.keySet();
                
                List<Tender__c> filteredTendersToUpsert = new List<Tender__c>();
                List<TenderWrappers.TenderRecord> filteredRecordsForUpsert = new List<TenderWrappers.TenderRecord>();
                Integer skippedNoOpCount = 0;
                List<String> skippedExtIds = new List<String>();   
                List<String> skippedReasons = new List<String>();
                for (Integer i = 0; i < tendersToUpsert.size(); i++) {
                    Tender__c t = tendersToUpsert[i];
                    Boolean isExisting = String.isNotBlank(t.External_Tender_Id__c)
                        && existingExtIds.contains(t.External_Tender_Id__c);
                    
                    if (isExisting && t.Corrigendum_Info__c != true) {
                        skippedNoOpCount++;
                        continue;
                    }
                    
                    // Brand-new tender -> assign this run's next Tender-N key.
                    // Existing (corrigendum) tender -> leave Common_Key__c /
                    // Base_Common_Key__c untouched so the upsert preserves whatever
                    // was stamped when the tender was FIRST created.
                    if (!isExisting) {
                        tenderSequence++;
                        t.Common_Key__c = baseCommonKey + '-Tender-' + tenderSequence;
                        t.Base_Common_Key__c = baseCommonKey;
                    }
                    
                    filteredTendersToUpsert.add(t);
                    filteredRecordsForUpsert.add(recordsForUpsert[i]);
                }
                
                tendersToUpsert = filteredTendersToUpsert;
                recordsForUpsert = filteredRecordsForUpsert;
                
                Integer createdCount = 0;
                Integer updatedCount = 0;
                List<String> createdExtIds = new List<String>();  // NEW
                Integer failedCount = 0;
                List<String> failedExtIds = new List<String>();
                List<String> updatedExtIds = new List<String>();  // NEW
                
                if (!tendersToUpsert.isEmpty()) {
                    TenderNotificationHandler.skipNewTenderNotification = true;
                    Database.UpsertResult[] results;
                    
                    try {
                        results = 
                            Database.upsert(tendersToUpsert, Tender__c.External_Tender_Id__c, false);
                    } finally {
                        TenderNotificationHandler.skipNewTenderNotification = false;
                    }
                    
                    List<Tender_Docoment_Details__c> docDetailsToInsert = new List<Tender_Docoment_Details__c>();
                    List<Id> updatedTenderIdsForDocRefresh = new List<Id>();
                    Set<Id> notificationTenderIds = new Set<Id>();
                    
                    for (Integer i = 0; i < results.size(); i++) {
                        Database.UpsertResult res = results[i];
                        
                        if (!res.isSuccess()) {
                            String errMsg = '';
                            for (Database.Error err : res.getErrors()) {
                                errMsg += err.getStatusCode() + ': ' + err.getMessage()
                                    + ' | Fields: ' + err.getFields() + '; ';
                            }
                            System.debug('[TenderListingBatch] UPSERT FAILED: ' + errMsg);
                            
                            String failedRecordJson = JSON.serializePretty(recordsForUpsert[i]);
                            
                            IntegrationLogger.log(
                                'TenderUpsertFailed',
                                productName,
                                'tender-listing-data (upsert-failed)',
                                null,
                                failedRecordJson,   
                                null,
                                false,
                                errMsg,            
                                null,
                                baseCommonKey
                            );
                            
                            failedCount++;
                            failedExtIds.add(tendersToUpsert[i].External_Tender_Id__c);
                            continue;
                        }
                        
                        Boolean isNewTender = res.isCreated();
                        String extId = tendersToUpsert[i].External_Tender_Id__c;
                        
                        if (isNewTender) {
                            createdCount++;
                            newTenderIds.add(res.getId());
                            createdExtIds.add(extId);  
                            newTenderProductMap.put(res.getId(), productName);
                            notificationTenderIds.add(res.getId());
                            
                            // One Integration Log entry per newly created Tender, keyed
                            // with the EXACT SAME Common_Key__c stamped on the Tender__c.
                            IntegrationLogger.log(
                                'TenderCreated', productName,
                                'tender-listing-data (tender-created)',
                                null,
                                'External_Tender_Id=' + extId,
                                null, true, null,
                                res.getId(), tendersToUpsert[i].Common_Key__c, mailType
                            );
                            
                        } else {
                            updatedCount++;
                            updatedExtIds.add(extId);
                            updatedTenderIdsForDocRefresh.add(res.getId());
                            
                            if (tendersToUpsert[i].Corrigendum_Info__c == true) {
                                newTenderProductMap.put(res.getId(), productName);
                                
                                // Updated (corrigendum) tender - log against its ORIGINAL
                                // Common_Key__c, not a new Tender-N.
                                IntegrationLogger.log(
                                    'TenderUpdated', productName,
                                    'tender-listing-data (tender-updated)',
                                    null,
                                    'External_Tender_Id=' + extId,
                                    null, true, null,
                                    res.getId(), existingExtIdToCommonKey.get(extId)
                                );
                            }
                        }
                        
                        if (isMergeProduct) {
                            mergeProductTenderMap.put(res.getId(), productName);
                        }
                        
                        List<TenderWrappers.DocumentInfo> docs = recordsForUpsert[i].documents;
                        if (docs != null && !docs.isEmpty()) {
                            for (TenderWrappers.DocumentInfo d : docs) {
                                Tender_Docoment_Details__c docDetail = new Tender_Docoment_Details__c();
                                docDetail.Tender__c        = res.getId();
                                docDetail.Document_Id__c   = d.documentid != null ? String.valueOf(d.documentid) : null;
                                docDetail.Name__c          = d.name;
                                docDetail.Type__c          = d.type;
                                //docDetail.Download_URL__c  = d.downloadLink;
                                docDetail.Download_URL_Text__c  = d.downloadLink;
                                if (ownerId != null) { docDetail.OwnerId = ownerId; } // <<< OWNER CHANGE >>>
                                docDetailsToInsert.add(docDetail);
                            }
                        }
                    }
                    
                    // Wipe stale doc children for updated tenders before inserting the current set.
                    if (!updatedTenderIdsForDocRefresh.isEmpty()) {
                        List<Tender_Docoment_Details__c> oldDocs = [
                            SELECT Id FROM Tender_Docoment_Details__c
                            WHERE Tender__c IN :updatedTenderIdsForDocRefresh
                        ];
                        if (!oldDocs.isEmpty()) {
                            delete oldDocs;
                        }
                    }
                    
                    // <<< CHANGED >>>
                    // Document rows are still built and chunked exactly as before
                    // (8000 rows per chunk), but each chunk is now handed off to a
                    // Queueable job instead of being inserted directly here. This
                    // keeps document DML out of this execute() transaction's
                    // 10,000-row DML budget, which it was previously sharing with
                    // the Tender__c upsert and Integration_Log__c inserts above.
                    
                    Boolean pushNotificationEnabled = false;
                    try {
                        Tender_Trigger_Controll__mdt setting =
                            Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');
                        pushNotificationEnabled = (setting != null && setting.Push_Notification_For_New_Tender__c == true);
                    } catch (Exception mdtEx) {
                        System.debug('[TenderListingBatch] Failed to read Tender_Trigger_Controll__mdt: ' + mdtEx.getMessage());
                    }
                    
                    if (pushNotificationEnabled && !notificationTenderIds.isEmpty()) {
                        System.enqueueJob(
                            new TenderNewTenderNotificationQueueable(
                                notificationTenderIds, docDetailsToInsert, productName, DOC_INSERT_CHUNK_SIZE
                            )
                        );
                    } else if (!docDetailsToInsert.isEmpty()) {
                        // Notification off ase, ba notun tender nei - sudhu doc-insert.
                        System.enqueueJob(
                            new TenderDocumentInsertQueueable(
                                docDetailsToInsert, 0, DOC_INSERT_CHUNK_SIZE, productName
                            )
                        );
                    }
                    
                    // <<< END CHANGED >>>
                }
                
                // One summary log per product per run (instead of one row per tender).
                /*IntegrationLogger.log(
'TenderUpsertSummary',
productName,
'tender-upsert-summary (internal)',
null,
'Created=' + createdCount + ', Updated=' + updatedCount + ', SkippedNoOp=' + skippedNoOpCount,
null,
true,
null,
null, baseCommonKey
);*/
                String summaryDetails =
                    'Created=' + createdCount + ' [' + String.join(createdExtIds, ',') + ']' +
                    ', Updated=' + updatedCount + ' [' + String.join(updatedExtIds, ',') + ']' +
                    ', SkippedNoOp=' + skippedNoOpCount +
                    ', Failed=' + failedCount + ' [' + String.join(failedExtIds, ',') + ']';
                
                // <<< CHANGED >>> capture the returned Integration_Log__c so we can stamp
                // Tender_Record_Create__c / Tender_Record_Update__c / Tender_Record_Skipped__c
                // on this exact "tender-upsert-summary (internal)" log record.
                Integration_Log__c summaryLog = IntegrationLogger.log(
                    'TenderUpsertSummary',
                    productName,
                    'tender-upsert-summary (internal)',
                    null,
                    summaryDetails,
                    null,
                    true,
                    null,
                    null, baseCommonKey , mailType
                );
                
                if (summaryLog != null) {
                    summaryLog.Tender_Record_Create__c  = createdCount;
                    summaryLog.Tender_Record_Update__c  = updatedCount;
                    summaryLog.Tender_Record_Skipped__c = skippedNoOpCount;
                }
                
                IntegrationLogger.flush();
                
            } catch (Exception productEx) {
                // Catches anything unexpected for this product so it gets logged
                // instead of silently rolling back, and the batch moves to the next product.
                IntegrationLogger.log(
                    'ProductProcessingFailed', productName,
                    'execute()', null, productEx.getMessage(),
                    null, false, productEx.getMessage(),
                    null, baseCommonKey
                );
                IntegrationLogger.flush();
            }
        }
    }
    
    
    public void finish(Database.BatchableContext bc) {
        System.debug('[TenderListingBatch] New/updated tenders for Stage 2: '
                     + newTenderProductMap.size()
                     + ' | Merge-product tenders: '
                     + mergeProductTenderMap.size());
        
        if (!newTenderProductMap.isEmpty() && !Test.isRunningTest()) {
            Database.executeBatch(
                new ProbableBidderBatch(newTenderProductMap),
                10
            );
        }
    }
    
    // Generates ONE Base Common Key per Product per run: {ProductName}-{ddMMyyyy}-{6DigitRandom}.
    // Reused as-is for the Count call and every Listing page call, and stored on every
    // brand-new Tender__c (Base_Common_Key__c) so Stage 2 can build matching Bidder-N keys later.
    private String generateBaseCommonKey(String productName) {
        Date d = Date.today();
        String dateStr = String.valueOf(d.day()).leftPad(2, '0')
            + String.valueOf(d.month()).leftPad(2, '0')
            + String.valueOf(d.year());
        Integer randNum = Integer.valueOf(Math.floor(Math.random() * 900000)) + 100000; // 100000-999999
        return productName + '-' + dateStr + '-' + String.valueOf(randNum);
    }
    
    // Calls the Tender Listing Data Count API for a product; returns total tender count.
    private Integer callCountApi(String productName, String baseCommonKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/Utkarsh/api/tender-listing-data-count');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        
        Map<String, Object> payload = new Map<String, Object>{
            'Date'        => Date.today(),
                'TenderIds'   => '',
                'ProductName' => productName,
                'MailType'    => mailType
                };
                    String body = formatDateAndSerialize(payload);
        req.setBody(body);
        
        Integer statusCode;
        String responseBody;
        Boolean success = false;
        Integer count = null;
        
        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            
            if (statusCode == 200) {
                TenderWrappers.CountResponse parsed =
                    (TenderWrappers.CountResponse) JSON.deserialize(responseBody, TenderWrappers.CountResponse.class);
                if (parsed.Success && parsed.Data != null && !parsed.Data.isEmpty()) {
                    count = parsed.Data[0].count;
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
        }
        
        // <<< CHANGED >>> capture the returned Integration_Log__c so we can
        // stamp Tender_Record_Count__c on this "tender-listing-data-count" log record.
        Integration_Log__c countLog = IntegrationLogger.log('Count', productName, 'tender-listing-data-count', body, responseBody,
                                                            statusCode, success, success ? null : responseBody, null, baseCommonKey,mailType);
        
        if (countLog != null) {
            countLog.Tender_Record_Count__c = count;
        }
        
        return count;
        
    }
    
    // Calls the Tender Listing Data API for one page of a product; returns that page's tender records.
    private List<TenderWrappers.TenderRecord> callListingApi(String productName, Integer pageNo, String baseCommonKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/Utkarsh/api/tender-listing-data');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        
        Map<String, Object> payload = new Map<String, Object>{
            'Date'             => Date.today(),
                'TenderIds'        => '',
                'ProductName'      => productName,
                'page_no'          => pageNo,
                '_record_per_page' => RECORDS_PER_PAGE,
                'MailType'         => mailType
                };
                    String body = formatDateAndSerialize(payload);
        req.setBody(body);
        
        Integer statusCode;
        String responseBody;
        Boolean success = false;
        List<TenderWrappers.TenderRecord> records = null;
        
        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            
            if (statusCode == 200) {
                TenderWrappers.ListingResponse parsed =
                    (TenderWrappers.ListingResponse) JSON.deserialize(responseBody, TenderWrappers.ListingResponse.class);
                if (parsed.Success) {
                    records = parsed.Data;
                    backfillCurrency(records, responseBody);
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
        }
        
        IntegrationLogger.log('Listing', productName, 'tender-listing-data (page ' + pageNo + ')', body,
                              responseBody, statusCode, success, success ? null : responseBody, null, baseCommonKey,mailType);
        
        return records;
    }
    
    // Fills TenderRecord.currencyCode from the raw JSON's "currency" key -
    // JSON.deserialize can't auto-map it since "currency" is a reserved identifier here.
    private void backfillCurrency(List<TenderWrappers.TenderRecord> records, String responseBody) {
        if (records == null || records.isEmpty()) {
            return;
        }
        try {
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> rawData = (List<Object>) raw.get('Data');
            if (rawData == null) {
                return;
            }
            Integer count = Math.min(records.size(), rawData.size());
            for (Integer i = 0; i < count; i++) {
                Map<String, Object> rawRec = (Map<String, Object>) rawData[i];
                records[i].currencyCode = (String) rawRec.get('currency');
            }
        } catch (Exception e) {
            System.debug('[TenderListingBatch] backfillCurrency failed: ' + e.getMessage());
        }
    }
    
    private Tender__c mapToTenderRecord(TenderWrappers.TenderRecord rec, String productName, Boolean isMergeProduct, String departmentName, Id ownerId) { // <<< OWNER CHANGE >>>
        
        Tender__c t = new Tender__c();
        
        t.External_Tender_Id__c    = rec.tenderid != null ? String.valueOf(rec.tenderid) : null;
        t.Source_Tender_Id__c      = rec.sourcetenderid;
        t.Product_Name__c          = productName;
        t.MergeProduct__c = isMergeProduct;
        t.Department_Name__c = String.isNotBlank(departmentName) ? departmentName : null;
        if (ownerId != null) { t.OwnerId = ownerId; } // <<< OWNER CHANGE >>>
        t.Tender_Value__c          = rec.value != null ? String.valueOf(rec.value) : null;
        //t.EMD__c                   = rec.emd != null ? String.valueOf(rec.emd) : null;
        //t.Document_Cost__c         = rec.documentcost != null ? String.valueOf(rec.documentcost) : null;
        t.EMD__c                   = rec.emd;
        t.Document_Cost__c         = rec.documentcost;
        
        t.Biddead_Line__c       = parseDateSafe(rec.biddeadline);
        t.MailType__c = mailType;
        // Authority is plain text - no Account lookup.
        t.Authority_T__c           = rec.authority;
        
        t.Currency__c              = rec.currencyCode;
        t.Tender_Details__c        = rec.tenderdetails;
        t.Tender_Description__c    = rec.tenderdescription;
        t.Pre_Bid_Meeting_Date__c  = parseDateSafe(rec.prebidmeetingdate);
        t.Tender_Start_date__c     = parseDateSafe(rec.datecreated);
        t.Corrigendum_Info__c      = 'true'.equalsIgnoreCase(rec.corrigenduminfo);
        //t.Sector__c                = rec.sector != null ? String.join(rec.sector, '; ') : null;
        //t.Source_URL__c            = rec.sourceurl;
        t.Source_URL_in_Text__c            = rec.sourceurl;
        t.is_Updated__c            = rec.isupdated != null ? rec.isupdated : false;
        t.Sub_Industry__c          = rec.subindustry != null ? String.join(rec.subindustry, '; ') : null;
        t.Completion_Of_Work__c    = rec.completionofwork;
        t.Tender_AI_Summary__c     = rec.ai_summary;
        //t.Zip_Document_Download__c = rec.zipdocumentdownload;
        t.Zip_Document_Download_Text__c = rec.zipdocumentdownload;
        t.MergeProduct__c          = isMergeProduct;
        
        
        //Creating duplicate Text(255) variables - For repoart , shows like (240 chars)...
        t.Tender_Description_Text__c = truncate240WithEllipsis(rec.tenderdescription);
        t.Tender_Details_Text__c     = truncate240WithEllipsis(rec.tenderdetails);
        t.Sector_Text__c             = truncate240WithEllipsis(t.Sector__c); // reuse the already-joined string
        t.Sub_Industry_Text__c       = truncate240WithEllipsis(t.Sub_Industry__c);
        t.Zip_Document_Download_Text2__c = truncate240WithEllipsis(rec.zipdocumentdownload);
        t.Source_URL_in_Text2__c     = truncate240WithEllipsis(rec.sourceurl);
        
        
        if (rec.location != null && !rec.location.isEmpty()) {
            TenderWrappers.LocationInfo loc = rec.location[0];
            t.City__c    = loc.city;
            t.State__c   = loc.state;
            t.Country__c = loc.country;
        }
        
        return t;
    }
    
    // Safely parses a date string (yyyy-MM-dd, or longer with a time component) into a Date.
    private Date parseDateSafe(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }
        try {
            return Date.valueOf(dateStr.length() > 10 ? dateStr.substring(0, 10) : dateStr);
        } catch (Exception e) {
            return null;
        }
    }
    
    
    // keeping the total length within a 255-char Text field (240 + 3 = 243, well under 255).
    private String truncate240WithEllipsis(String val) {
        if (String.isBlank(val)) {
            return val;
        }
        if (val.length() <= 240) {
            return val;
        }
        return val.substring(0, 240) + '...';
    }
    
    // Serializes the payload, formatting Date as yyyy-MM-dd (API requirement).
    private String formatDateAndSerialize(Map<String, Object> payload) {
        Map<String, Object> clone = payload.clone();
        Date d = Date.today();
        String isoDate = String.valueOf(d.year())
            + '-' + String.valueOf(d.month()).leftPad(2, '0')
            + '-' + String.valueOf(d.day()).leftPad(2, '0');
        clone.put('Date', isoDate);
        return JSON.serialize(clone);
    }
}