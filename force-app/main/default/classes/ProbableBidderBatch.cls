/*
Owner - Ayantika
CLASS: ProbableBidderBatch


Runs as Stage 2 of the daily Tender integration after TenderListingBatch finishes.
Takes the Tender IDs and Product Names received from Stage 1.
Calls the Probable Bidders (Tender ID Wise) API for each Tender.
Gets the probable bidder names from the API response.
Creates a unique key using Tender ID + Bidder Name to avoid duplicate bidder records.
Checks existing Bidders__c records before creating new ones.
Creates new Bidders__c records and links them to the related Tender.
Creates the Bidder Common Key using the Tender's Common Key + Bidder number.
Copies the Tender Owner to the newly created Bidder record.
Creates an Integration Log for each newly created Bidder.
Uses two passes: first all API callouts, then SOQL/DML, to avoid Salesforce callout/DML errors.
Overall, this class fetches probable bidders for each Tender and creates unique Bidders__c records linked to those Tenders.
*/
public class ProbableBidderBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    private static final String NAMED_CREDENTIAL = 'callout:tender247_Tender';
    
    // Passed in from TenderListingBatch.finish() - Tender Id -> Product Name
    private Map<Id, String> tenderProductMap;
    
    // Stateful so Stage 3 (Contact Details) can be kicked off in finish()
    // with only the Bidders__c records that were newly created in this run.
    private Set<Id> newAccountIds = new Set<Id>();
    
    public ProbableBidderBatch(Map<Id, String> tenderProductMap) {
        this.tenderProductMap = tenderProductMap;
    }
    
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[ProbableBidderBatch] START - processing ' + tenderProductMap.size() + ' tender(s)');
        return Database.getQueryLocator([
            SELECT Id, Name, Common_Key__c, Product_Name__c, External_Tender_Id__c, Source_Tender_Id__c, OwnerId
            FROM Tender__c
            WHERE Id IN :tenderProductMap.keySet()
        ]);
    }
    
    // PASS 1 makes every "Probable Bidders" callout for the scope (no DML).
    // PASS 2 then does bulk dedupe-check + bulk per-tender existing-count +
    // one bulk insert for the whole scope (no more callouts) - required
    // because Salesforce does not allow a callout after DML in the same
    // transaction. PASS 2 is wrapped so an unexpected failure there still
    // flushes PASS 1's queued logs.
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        
        Map<Id, List<String>> bidderNamesByTender = new Map<Id, List<String>>();
        Map<Id, Tender__c> tenderById = new Map<Id, Tender__c>();
        
        // ---- PASS 1: ALL CALLOUTS, NO DML ----
        for (sObject s : scope) {
            Tender__c tnd = (Tender__c) s;
            tenderById.put(tnd.Id, tnd);
            
            String productName = tenderProductMap.containsKey(tnd.Id)
                ? tenderProductMap.get(tnd.Id)
                : tnd.Product_Name__c;
            
            List<String> bidderNames = callProbableBidderApi(tnd, productName);
            if (bidderNames != null && !bidderNames.isEmpty()) {
                bidderNamesByTender.put(tnd.Id, bidderNames);
            }
        }
        
        // ---- PASS 2: ALL DML, NO MORE CALLOUTS ----
        try {
            
            // orderedKeys preserves the order bidders were discovered in, so
            // Bidder-N numbering is assigned in a predictable order (Sets in
            // Apex don't guarantee iteration order).
            List<String> orderedKeys = new List<String>();
            Set<String> allUniqueKeys = new Set<String>();
            Map<String, Id> keyToTenderId = new Map<String, Id>();
            Map<String, String> keyToBidderName = new Map<String, String>();
            
            for (Id tenderId : bidderNamesByTender.keySet()) {
                Tender__c tnd = tenderById.get(tenderId);
                for (String name : bidderNamesByTender.get(tenderId)) {
                    if (String.isBlank(name)) continue;
                    String key = tnd.External_Tender_Id__c + '-' + name;
                    if (!allUniqueKeys.contains(key)) {
                        allUniqueKeys.add(key);
                        orderedKeys.add(key);
                        keyToTenderId.put(key, tenderId);
                        keyToBidderName.put(key, name);
                    }
                }
            }
            
            // Dedup check - never create a duplicate Bidders__c for the same
            // bidder on the same tender.
            Set<String> existingKeys = new Set<String>();
            if (!allUniqueKeys.isEmpty()) {
                for (Bidders__c b : [
                    SELECT Bidder_Unique_Key__c
                    FROM Bidders__c
                    WHERE Bidder_Unique_Key__c IN :allUniqueKeys
                ]) {
                    existingKeys.add(b.Bidder_Unique_Key__c);
                }
            }
            
            // Per-tender EXISTING bidder count - this is the starting point for
            // this run's "-Bidder-N" numbering, so a new bidder never re-uses a
            // suffix already used for that tender in an earlier run.
            Map<Id, Integer> bidderCounterByTender = new Map<Id, Integer>();
            if (!tenderById.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT Tender__c tid, COUNT(Id) cnt
                    FROM Bidders__c
                    WHERE Tender__c IN :tenderById.keySet()
                    GROUP BY Tender__c
                ]) {
                    bidderCounterByTender.put((Id) ar.get('tid'), (Integer) ar.get('cnt'));
                }
            }
            
            List<Bidders__c> biddersToInsert = new List<Bidders__c>();
            
            for (String key : orderedKeys) {
                if (existingKeys.contains(key)) continue;
                
                Id tenderId = keyToTenderId.get(key);
                Tender__c tnd = tenderById.get(tenderId);
                String name = keyToBidderName.get(key);
                String productName = tenderProductMap.containsKey(tenderId)
                    ? tenderProductMap.get(tenderId)
                    : tnd.Product_Name__c;
                
                // Bidder's Common Key is built off the TENDER'S OWN Common_Key__c
                // (e.g. "...-Tender-1"), and the "-Bidder-N" sequence restarts
                // per tender, continuing from that tender's existing bidder count.
                Integer nextSeq = (bidderCounterByTender.containsKey(tenderId) ? bidderCounterByTender.get(tenderId) : 0) + 1;
                bidderCounterByTender.put(tenderId, nextSeq);
                
                String bidderCommonKey = tnd.Common_Key__c + '-Bidder-' + nextSeq;

                Bidders__c b = new Bidders__c();
                b.Name                  = name.length() > 80 ? name.substring(0, 80) : name;
                b.Bidder_Name__c        = name;
                b.Tender__c             = tenderId;
                b.Product_Name__c       = productName;
                b.Common_Key__c         = bidderCommonKey;
                b.External_Tender_Id__c = tnd.External_Tender_Id__c;
                b.Source_Tender_Id__c   = tnd.Source_Tender_Id__c;
                b.Bidder_Unique_Key__c  = key;
                if (tnd.OwnerId != null) { b.OwnerId = tnd.OwnerId; } // <<< OWNER CHANGE >>>
                biddersToInsert.add(b);
            }
            
            if (!biddersToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(biddersToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    Database.SaveResult res = results[i];
                    Bidders__c insertedRec = biddersToInsert[i];
                    
                    if (res.isSuccess()) {
                        newAccountIds.add(res.getId());
                        
                        // One Integration Log entry per newly created Bidder, keyed
                        // with the EXACT SAME Common_Key__c stamped on the Bidders__c.
                        IntegrationLogger.log(
                            'BidderCreated',
                            insertedRec.Product_Name__c,
                            'probable-bidders-tenderIdWise (bidder-created)',
                            null,
                            'Bidder_Name=' + insertedRec.Bidder_Name__c,
                            null, true, null,
                            insertedRec.Tender__c, insertedRec.Common_Key__c
                        );
                    } else {
                        System.debug('[ProbableBidderBatch] Bidders__c INSERT FAILED: ' + res.getErrors());
                    }
                }
            }
            
            // Logs queued during PASS 1's callouts (+ BidderCreated logs above) are
            // flushed once, here, after all DML above.
            IntegrationLogger.flush();
            
        } catch (Exception pass2Ex) {
            // PASS 2 failed unexpectedly - flush PASS 1's queued logs so they
            // aren't lost, and log this failure itself.
            IntegrationLogger.log(
                'BidderPass2Failed',
                null,
                'probable-bidder-pass2-dedupe-insert',
                null,
                pass2Ex.getMessage(),
                null,
                false,
                pass2Ex.getMessage()
            );
            IntegrationLogger.flush();
        }
    }
    
    // Kicks off Stage 3 (Contact Details) with the newly created Bidders__c
    // records, if/when that class exists.
    public void finish(Database.BatchableContext bc) {
        System.debug('[ProbableBidderBatch] FINISH - Total new Bidders__c record(s) this run: ' + newAccountIds.size());

        try {
            if (
                tenderProductMap != null &&
                !tenderProductMap.isEmpty() &&
                !Test.isRunningTest()
            ) {
                TenderNewTenderAlertEmailQueueable.enqueue(tenderProductMap.keySet());
            }
        } catch (Exception emailEx) {
            System.debug(
                LoggingLevel.ERROR,
                '[ProbableBidderBatch] New tender email enqueue failed: ' + emailEx.getMessage()
            );
        }
    }
    
    // Calls the Probable Bidders (Tender ID Wise) API for ONE tender and
    // returns just the probable_bidder[] names - every other field in the
    // response duplicates what Stage 1 already stored on Tender__c and is
    // intentionally ignored here.
    private List<String> callProbableBidderApi(Tender__c tnd, String productName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/Utkarsh/api/probable-bidders-tenderIdWise');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        
        Map<String, Object> payload = new Map<String, Object>{
            'TenderId'    => tnd.External_Tender_Id__c,
                'ProductName' => productName
                };
                    String body = JSON.serialize(payload);
        req.setBody(body);
        
        System.debug('[ProbableBidderBatch] Request for Tender ' + tnd.External_Tender_Id__c + ': ' + body);
        
        Integer statusCode;
        String responseBody;
        Boolean success = false;
        List<String> bidderNames = null;
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            statusCode   = res.getStatusCode();
            responseBody = res.getBody();
            
            System.debug('[ProbableBidderBatch] Status: ' + statusCode);
            
            if (statusCode == 200) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                Boolean apiSuccess = (Boolean) parsed.get('Success');
                
                if (apiSuccess) {
                    List<Object> data = (List<Object>) parsed.get('Data');
                    if (data != null && !data.isEmpty()) {
                        Map<String, Object> rec = (Map<String, Object>) data[0];
                        List<Object> rawBidders = (List<Object>) rec.get('probable_bidder');
                        if (rawBidders != null) {
                            bidderNames = new List<String>();
                            for (Object o : rawBidders) {
                                if (o != null) {
                                    bidderNames.add(String.valueOf(o));
                                }
                            }
                        }
                    }
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
            System.debug('[ProbableBidderBatch] EXCEPTION: ' + e.getMessage());
        }
        
        IntegrationLogger.log(
            'ProbableBidder',
            productName,
            'probable-bidders-tenderIdWise',
            body,
            responseBody,
            statusCode,
            success,
            success ? null : responseBody,
            tnd.Id,
            tnd.Common_Key__c
        );
        
        return bidderNames;
    }
}