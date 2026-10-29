/*
================================================================================
CLASS: ResultWinnerBidderContactBatch  (Stage 3A) - FIXED VERSION
--------------------------------------------------------------------------------
SCENARIO / OWNER: Ayantika

FIX 1 (DML rows per transaction): start() now pre-calls the Count API once
per product, generates the Result Common Key once per product, and flattens
the work into ONE SCOPE ITEM PER PAGE (not per product). This means the
batch's own scope size (set when calling Database.executeBatch(new
ResultWinnerBidderContactBatch(), N)) directly bounds how many pages -
and therefore how many bidder rows / DML rows / callouts - are processed
per transaction. Pick N so that N * 50 * (avg bidders/tender) stays well
under 10,000 DML rows.

FIX 2 (callout-after-DML): IntegrationLogger.flush() has been moved OUT of
the per-product loop inside start(). Previously, each product's Count API
callout was immediately followed by flush() (which does DML to insert the
log), and then the NEXT product's Count API callout happened in the SAME
transaction - a callout after DML in the same transaction throws:
"You have uncommitted work pending. Please commit or rollback
before calling out."
Fix: ALL products' Count API callouts happen first (Pass 1), and only
after every product is done is flush() called once (Pass 2) to insert
all queued Count API logs in a single DML operation. IntegrationLogger.log()
only queues the log in memory - it does not do DML until flush() runs.

Everything else (Tender match, Bidder match, chunkedUpdate as a secondary
safety net, winner collection into a Stateful map, chaining Stage 3B from
finish()) is unchanged from the previous version.
================================================================================
*/
public class ResultWinnerBidderContactBatch implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    
    private static final String RESULT_NAMED_CREDENTIAL = 'callout:tender247_Result';
    private static final Integer RECORDS_PER_PAGE = 50;
    private static final Integer DML_CHUNK_SIZE = 8000; // secondary safety net only
    
    // Delimiter for encoding scope items - must never appear in a product name.
    private static final String DELIM = '||';
    
    // Stateful - persists across EVERY execute() call in this job.
    private Map<Id, String> winnerBidderProductMap = new Map<Id, String>();
    
    // Stateful per-product running summary counts (since a product's pages
    // are now spread across multiple execute() calls instead of one).
    private Map<String, Set<String>> matchedTenderIdsByProduct   = new Map<String, Set<String>>();
    private Map<String, Set<String>> unmatchedTenderIdsByProduct = new Map<String, Set<String>>();
    private Map<String, Integer> matchedBidderCountByProduct     = new Map<String, Integer>();
    private Map<String, Integer> unmatchedBidderCountByProduct   = new Map<String, Integer>();
    private Map<String, Integer> winnerCountByProduct            = new Map<String, Integer>();
    private Map<String, String>  commonKeyByProduct              = new Map<String, String>();
    private Map<String, Integer> newBidderCreatedCountByProduct  = new Map<String, Integer>();
    
    // start(): fetch products, call Count API for every product (Pass 1 -
    // ALL callouts), generate the Result Common Key once per product,
    // flatten into ONE SCOPE ITEM PER PAGE, then flush ALL queued Count
    // API logs in one shot (Pass 2 - ALL DML) so no callout ever follows
    // a DML statement within this method.
    public Iterable<String> start(Database.BatchableContext bc) {
        Set<String> resultProductNames = new Set<String>();
        
        for (Tender_Product_Mapping__mdt mdt : [
            SELECT Result_Product_Name__c
            FROM Tender_Product_Mapping__mdt
            WHERE Result_Product_Name__c != null
        ]) {
            resultProductNames.add(mdt.Result_Product_Name__c);
        }
        
        System.debug('[ResultWinnerBidderContactBatch] Loaded ' + resultProductNames.size()
                     + ' distinct Result product name(s) from Tender_Product_Mapping__mdt.');
        
        List<String> pageWorkItems = new List<String>();
        
        // ---- PASS 1: ALL CALLOUTS (Count API for every product) ----
        for (String productName : resultProductNames) {
            String resultCommonKey = generateResultCommonKey(productName);
            commonKeyByProduct.put(productName, resultCommonKey);
            
            //Integer totalCount = callResultCountApi(productName, resultCommonKey);
            // NOTE: IntegrationLogger.flush() intentionally NOT called here -
            // see FIX 2 in header comment.
            Integer totalCount;
            try {
                totalCount = callResultCountApi(productName, resultCommonKey);
            } catch (Exception e) {
                System.debug('[ResultWinnerBidderContactBatch] Count API failed for product ' + productName + ': ' + e.getMessage());
                continue;
            }
            
            if (totalCount == null || totalCount <= 0) {
                continue;
            }
            
            Integer totalPages = (Integer) Math.ceil(Decimal.valueOf(totalCount) / RECORDS_PER_PAGE);
            
            for (Integer page = 1; page <= totalPages; page++) {
                pageWorkItems.add(productName + DELIM + resultCommonKey + DELIM + page);
            }
        }
        
        // ---- PASS 2: ALL DML (insert every queued Count API log at once) ----
        IntegrationLogger.flush();
        
        System.debug('[ResultWinnerBidderContactBatch] Built ' + pageWorkItems.size()
                     + ' page-level work item(s) across all products.');
        
        return pageWorkItems;
    }
    
    // execute(): scope is a list of INDIVIDUAL PAGES (possibly spanning
    // different products). Batch scope size (set at executeBatch call time)
    // directly bounds callouts and DML rows processed per transaction.
    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String workItem : scope) {
            //List<String> parts = workItem.split(java.util.regex.Pattern.quote(DELIM));
            List<String> parts = workItem.split('\\|\\|');
            String productName     = parts[0];
            String resultCommonKey = parts[1];
            Integer pageNo         = Integer.valueOf(parts[2]);
            
            List<ResultWrappers.ResultRecord> pageRecords = callResultListingApi(productName, pageNo, resultCommonKey);
            if (pageRecords == null || pageRecords.isEmpty()) {
                continue;
            }
            
            Map<String, Object> pageResult = processPageRecords(pageRecords, productName);
            
            mergeSet(matchedTenderIdsByProduct, productName, (Set<String>) pageResult.get('matchedTenderIds'));
            mergeSet(unmatchedTenderIdsByProduct, productName, (Set<String>) pageResult.get('unmatchedTenderIds'));
            addCount(matchedBidderCountByProduct, productName, (Integer) pageResult.get('matchedBidderCount'));
            addCount(unmatchedBidderCountByProduct, productName, (Integer) pageResult.get('unmatchedBidderCount'));
            addCount(winnerCountByProduct, productName, (Integer) pageResult.get('winnerCount'));
            addCount(newBidderCreatedCountByProduct, productName, (Integer) pageResult.get('newBidderCreatedCount'));
        }
        
        // All of this scope's Listing API callouts are done above; flush
        // (DML) happens once at the end of execute() - never before a
        // callout later in the same call, since this is the last statement.
        IntegrationLogger.flush();
    }
    
    // finish(): write one summary log per product (aggregated across
    // potentially many execute() calls), then chain Stage 3B with every
    // winner collected across the whole job.
    public void finish(Database.BatchableContext bc) {
        /*for (String productName : commonKeyByProduct.keySet()) {
String resultCommonKey = commonKeyByProduct.get(productName);

Set<String> matchedT   = matchedTenderIdsByProduct.containsKey(productName) ? matchedTenderIdsByProduct.get(productName) : new Set<String>();
Set<String> unmatchedT = unmatchedTenderIdsByProduct.containsKey(productName) ? unmatchedTenderIdsByProduct.get(productName) : new Set<String>();
Integer matchedB   = matchedBidderCountByProduct.containsKey(productName) ? matchedBidderCountByProduct.get(productName) : 0;
Integer unmatchedB = unmatchedBidderCountByProduct.containsKey(productName) ? unmatchedBidderCountByProduct.get(productName) : 0;
Integer winners    = winnerCountByProduct.containsKey(productName) ? winnerCountByProduct.get(productName) : 0;

IntegrationLogger.log(
'ResultProcessingSummary',
productName,
'result-listing-data (internal summary)',
null,
'Out of all Result records fetched today for "' + productName + '": '
+ matchedT.size() + ' tender(s) matched an existing Tender__c record, '
+ unmatchedT.size() + ' tender(s) had no match in Salesforce and were skipped. '
+ 'Among matched tenders: ' + matchedB + ' bidder(s) matched an existing Bidders__c record '
+ '(and were updated with result data), '
+ unmatchedB + ' bidder(s) had no matching Bidders__c record and were skipped. '
+ 'Of the matched bidders, ' + winners + ' were confirmed WINNERS '
+ '(winner_bidder=true AND aoc_status=true) and were sent for Contact Detail lookup in Stage 3B.',
null,
true,
null,
null, resultCommonKey
);
}
IntegrationLogger.flush();*/
        for (String productName : commonKeyByProduct.keySet()) {
            String resultCommonKey = commonKeyByProduct.get(productName);
            
            Set<String> matchedT   = matchedTenderIdsByProduct.containsKey(productName) ? matchedTenderIdsByProduct.get(productName) : new Set<String>();
            Set<String> unmatchedT = unmatchedTenderIdsByProduct.containsKey(productName) ? unmatchedTenderIdsByProduct.get(productName) : new Set<String>();
            Integer matchedB   = matchedBidderCountByProduct.containsKey(productName) ? matchedBidderCountByProduct.get(productName) : 0;
            Integer unmatchedB = unmatchedBidderCountByProduct.containsKey(productName) ? unmatchedBidderCountByProduct.get(productName) : 0;
            Integer winners    = winnerCountByProduct.containsKey(productName) ? winnerCountByProduct.get(productName) : 0;
            // ---- NEW ----
            Integer newBidderCreated = newBidderCreatedCountByProduct.containsKey(productName) ? newBidderCreatedCountByProduct.get(productName) : 0;
            
            Integration_Log__c summaryLog = IntegrationLogger.log(
                'ResultProcessingSummary',
                productName,
                'result-listing-data (internal summary)',
                null,
                'Out of all Result records fetched today for "' + productName + '": '
                + matchedT.size() + ' tender(s) matched an existing Tender__c record, '
                + unmatchedT.size() + ' tender(s) had no match in Salesforce and were skipped. '
                + 'Among matched tenders: ' + matchedB + ' bidder(s) matched an existing Bidders__c record '
                + '(and were updated with result data), '
                + unmatchedB + ' bidder(s) had no matching Bidders__c record and were skipped. '
                + 'Of the matched bidders, ' + winners + ' were confirmed WINNERS '
                + '(winner_bidder=true AND aoc_status=true) and were sent for Contact Detail lookup in Stage 3B.',
                null,
                true,
                null,
                null, resultCommonKey
            );
            
            // ---- NEW: stamp all 6 fields ----
            summaryLog.Matched_Tender_Count_Result__c      = matchedT.size();
            summaryLog.Unmatched_Tender_Count_Result__c    = unmatchedT.size();
            summaryLog.Matched_Bidder_Count_Result__c      = matchedB;
            summaryLog.Unmatched_Bidder_Count_Result__c    = unmatchedB;
            summaryLog.Winner_Bidder_Count_Result__c       = winners;
            summaryLog.New_Bidder_Created_Count_Result__c  = newBidderCreated;
        }
        IntegrationLogger.flush();
        
        System.debug('[ResultWinnerBidderContactBatch] FINISH - Total winner Bidder(s) collected: '
                     + winnerBidderProductMap.size());
        
        if (!winnerBidderProductMap.isEmpty()) {
            Database.executeBatch(new ResultWinnerContactBatch(winnerBidderProductMap), 25);
        }
    }
    
    // Processes ONE page's Result records: tender match -> bidder match ->
    // chunked update (safety net) -> winner collection -> Tender__c result
    // field update -> returns counts.
    /*private Map<String, Object> processPageRecords(List<ResultWrappers.ResultRecord> pageRecords, String productName) {

List<Map<String, Object>> pageBidderEntries = new List<Map<String, Object>>();
for (ResultWrappers.ResultRecord rec : pageRecords) {
if (rec.bidderdetails == null) {
continue;
}
for (ResultWrappers.BidderDetail bd : rec.bidderdetails) {
if (String.isNotBlank(bd.bidderName)) {
pageBidderEntries.add(new Map<String, Object>{
'tenderid' => rec.tenderid,
'bidderDetail' => bd
});
}
}
}

Set<String> matchedTenderIds = new Set<String>();
Set<String> unmatchedTenderIds = new Set<String>();
Integer matchedBidderCount = 0;
Integer unmatchedBidderCount = 0;
Integer winnerCount = 0;
Integer newBidderCreatedCount = 0; 

if (pageBidderEntries.isEmpty()) {
return new Map<String, Object>{
'matchedTenderIds' => matchedTenderIds,
'unmatchedTenderIds' => unmatchedTenderIds,
'matchedBidderCount' => matchedBidderCount,
'unmatchedBidderCount' => unmatchedBidderCount,
'winnerCount' => winnerCount,
'newBidderCreatedCount' => newBidderCreatedCount
};
}

Set<String> pageTenderIdStrs = new Set<String>();
for (Map<String, Object> w : pageBidderEntries) {
pageTenderIdStrs.add(String.valueOf(w.get('tenderid')));
}


Map<String, Tender__c> tenderByExtId = new Map<String, Tender__c>();
if (!pageTenderIdStrs.isEmpty()) {
for (Tender__c t : [
SELECT Id, External_Tender_Id__c, Common_Key__c, Department_Name__c, OwnerId
FROM Tender__c
WHERE External_Tender_Id__c IN :pageTenderIdStrs
]) {
tenderByExtId.put(t.External_Tender_Id__c, t);
}
}

matchedTenderIds.addAll(tenderByExtId.keySet());
unmatchedTenderIds.addAll(pageTenderIdStrs);
unmatchedTenderIds.removeAll(tenderByExtId.keySet());

if (!unmatchedTenderIds.isEmpty()) {
System.debug('[ResultWinnerBidderContactBatch] No matching Tender__c for tenderid(s): '
+ unmatchedTenderIds + ' - skipping those Result records entirely.');
}

// ---- Tender__c result-field update: for every Result record whose
// tenderid matched a Tender__c above, copy the Result-level fields
// onto that Tender__c. Uses the same tenderByExtId map - no extra query.
List<Tender__c> tendersToUpdate = new List<Tender__c>();
for (ResultWrappers.ResultRecord rec : pageRecords) {
String recTenderIdStr = String.valueOf(rec.tenderid);
Tender__c matchedTender = tenderByExtId.get(recTenderIdStr);
if (matchedTender == null) {
continue;
}

Tender__c tUpd = new Tender__c(Id = matchedTender.Id);
tUpd.Bidaward_Id_from_Result__c = String.valueOf(rec.bidawardid);
tUpd.Source_Bidaward_Id__c             = rec.sourcebidawardid;
tUpd.Posting_Date__c                   = parseResultDate(rec.postingdate);
tUpd.Tender_Result_Value__c            = rec.value;
tUpd.Result_Created_Date__c            = parseResultDate(rec.datecreated);
tUpd.AOC_Description__c                = rec.aocdescription;
tUpd.Contract_Date__c                  = parseResultDate(rec.contractdate);
tUpd.Financialbid_Evaluation_Date__c   = parseResultDate(rec.financialbidevaluationdate);
tUpd.Technicalbid_Evaluation_Date__c   = parseResultDate(rec.technicalbidevaluationdate);
tUpd.AOC_Updation_Date__c              = parseResultDate(rec.aocupdationdate);
tUpd.Organization_Name__c              = rec.organization_name;
tUpd.Result_Category__c                = (rec.category != null && !rec.category.isEmpty())
? String.join(rec.category, ';')
: null;

// Truncated Text(255) versions of the two long-text Result fields above.
String resultCategoryJoined = (rec.category != null && !rec.category.isEmpty())
? String.join(rec.category, ';')
: null;
tUpd.Result_Category_Text__c = truncate240WithEllipsis(resultCategoryJoined);
tUpd.AOC_Description_Text__c = truncate240WithEllipsis(rec.aocdescription);

// ---- FIX 4: Tender_Stage_Bidder_Wise__c - date-presence stage logic. (UNCHANGED)
// Only set the field when one of the defined combinations matches;
// otherwise leave it untouched so the existing value is preserved.
//Boolean hasTechDate = String.isNotBlank(rec.technicalbidevaluationdate);
//Boolean hasFinDate  = String.isNotBlank(rec.financialbidevaluationdate);
//Boolean hasAocDate  = String.isNotBlank(rec.aocupdationdate);

// ---- NEW: Tender_Stage_Bidder_Wise__c - driven purely by rec.resultstage ----
if (rec.resultstage == 1) {
tUpd.Tender_Stage_Bidder_Wise__c = 'Technical Evaluation Done';
} else if (rec.resultstage == 2) {
tUpd.Tender_Stage_Bidder_Wise__c = 'Financial Evaluation Done';
} else if (rec.resultstage == 3) {
tUpd.Tender_Stage_Bidder_Wise__c = 'AOC Done';
}
// else: resultstage null/not 1-2-3 - Tender_Stage_Bidder_Wise__c left unset,
// existing value preserved (per confirmed requirement).

// ---- NEW: store raw resultstage number on Tender__c ----
tUpd.ResultStage__c = rec.resultstage;

tendersToUpdate.add(tUpd);
}


if (!tendersToUpdate.isEmpty()) {
try {
Database.SaveResult[] tenderUpdateResults = Database.update(tendersToUpdate, false);
for (Integer i = 0; i < tenderUpdateResults.size(); i++) {
Database.SaveResult res = tenderUpdateResults[i];
if (!res.isSuccess()) {
System.debug('[ResultWinnerBidderContactBatch] Tender__c result-field UPDATE FAILED: ' + res.getErrors());
continue;
}

Id updatedTenderId = tendersToUpdate[i].Id;
String tenderCommonKey = null;
for (Tender__c t : tenderByExtId.values()) {
if (t.Id == updatedTenderId) {
tenderCommonKey = t.Common_Key__c;
break;
}
}

IntegrationLogger.log(
'TenderResultUpdated', productName,
'result-listing-data (tender update)', null,
'Tender__c ' + updatedTenderId + ' updated successfully with Result data.',
null, true, null,
updatedTenderId, tenderCommonKey + 'result'
);
}
} catch (Exception e) {
IntegrationLogger.log(
'TenderResultUpdateFailed', productName,
'result-listing-data (tender update)', null, e.getMessage(),
null, false, e.getMessage()
);
}
}

List<Map<String, Object>> matchedTenderEntries = new List<Map<String, Object>>();
for (Map<String, Object> w : pageBidderEntries) {
String tenderIdStr = String.valueOf(w.get('tenderid'));
if (tenderByExtId.containsKey(tenderIdStr)) {
matchedTenderEntries.add(w);
}
}

Set<String> keys = new Set<String>();
for (Map<String, Object> w : matchedTenderEntries) {
ResultWrappers.BidderDetail bd = (ResultWrappers.BidderDetail) w.get('bidderDetail');
keys.add(String.valueOf(w.get('tenderid')) + '-' + bd.bidderName);
}

Map<String, Bidders__c> bidderByKey = new Map<String, Bidders__c>();
if (!keys.isEmpty()) {
for (Bidders__c b : [
SELECT Id, Bidder_Unique_Key__c, Tender__c
FROM Bidders__c
WHERE Bidder_Unique_Key__c IN :keys
]) {
bidderByKey.put(b.Bidder_Unique_Key__c, b);
}
}

List<Bidders__c> biddersToUpdate = new List<Bidders__c>();

// ---- NEW: context/collections for new-bidder creation + Project/Opportunity cascade ----
List<Map<String, Object>> newBidderContext = new List<Map<String, Object>>();
List<Bidders__c> newBiddersToInsert = new List<Bidders__c>();

for (Map<String, Object> w : matchedTenderEntries) {
String tenderIdStr = String.valueOf(w.get('tenderid'));
ResultWrappers.BidderDetail bd = (ResultWrappers.BidderDetail) w.get('bidderDetail');
String key = tenderIdStr + '-' + bd.bidderName;

Bidders__c matched = bidderByKey.get(key);
if (matched == null) {
// ===== ORIGINAL =====
// unmatchedBidderCount++;
// System.debug('[ResultWinnerBidderContactBatch] No matching Bidders__c for key: ' + key
//              + ' - skipping (no update, no contact call).');
// continue;
// ===== END ORIGINAL =====

// ---- NEW: create a new Bidders__c under the matched Tender ----
unmatchedBidderCount++; // kept - bidder still had no prior Bidders__c match

Tender__c matchedTenderForNewBidder = tenderByExtId.get(tenderIdStr);

Bidders__c newBidder = new Bidders__c();
newBidder.Tender__c             = matchedTenderForNewBidder.Id;
if (matchedTenderForNewBidder.OwnerId != null) { newBidder.OwnerId = matchedTenderForNewBidder.OwnerId; } // <<< OWNER CHANGE >>>


newBidder.Bidder_Name__c        = bd.bidderName;
newBidder.Product_Name__c       = productName;
newBidder.Common_Key__c         = matchedTenderForNewBidder.Common_Key__c;
newBidder.Source_Tender_Id__c   = tenderIdStr;
newBidder.External_Tender_Id__c = tenderIdStr;
newBidder.Bidder_Unique_Key__c  = key;
newBidder.Awarded_Value__c      = bd.awardedValue;
newBidder.Bid_Value__c          = bd.bidValue;
newBidder.Bid_Rank__c           = bd.bidRank;
newBidder.Technical_Status__c   = bd.technical_status;
newBidder.Financial_Status__c   = bd.financial_status;
newBidder.AOC_Status__c         = bd.aoc_status;
newBidder.Is_Winner__c          = bd.winner_bidder;
newBidder.Result_Stage__c       = bd.resultstage;
// NOTE/ASSUMPTION: no per-bidder created-date available on
// bidderdetails - defaulting to today(). Flag if this should
// instead use rec.datecreated from the parent Result record.
newBidder.Result_Created_Date__c = Date.today();

// ---- NEW: mark this bidder as created by the Result flow ----
newBidder.New_bidder_from_result__c = true;

// Same status-based stage logic as the matched-bidder path (FIX 5)
if (bd.winner_bidder == true && bd.aoc_status == true) {

// Same status-based stage logic as the matched-bidder path (FIX 5)
//if (bd.winner_bidder == true && bd.aoc_status == true) {
newBidder.Bidder_Stage__c = 'Winner Bidder';
} else if (bd.aoc_status == true && bd.financial_status == true && bd.technical_status == true) {
newBidder.Bidder_Stage__c = 'AOC Done';
} else if (bd.financial_status == true && bd.technical_status == true) {
newBidder.Bidder_Stage__c = 'Financial Evaluation Done';
} else if (bd.technical_status == true) {
newBidder.Bidder_Stage__c = 'Technical Evaluation Done';
} else {
newBidder.Bidder_Stage__c = 'Possible Participant - Probable Bidder';
}

newBiddersToInsert.add(newBidder);
newBidderContext.add(new Map<String, Object>{
'tenderId'  => matchedTenderForNewBidder.Id,
'commonKey' => matchedTenderForNewBidder.Common_Key__c,
'deptName'  => matchedTenderForNewBidder.Department_Name__c,
'ownerId'   => matchedTenderForNewBidder.OwnerId
});

continue;
}

matchedBidderCount++;

matched.Awarded_Value__c      = bd.awardedValue;
matched.Bid_Value__c          = bd.bidValue;
//matched.Bid_Rank__c           = bd.bidRank;
matched.Bid_Rank__c = bd.bidRank;
matched.Technical_Status__c   = bd.technical_status;
matched.Financial_Status__c   = bd.financial_status;
matched.AOC_Status__c         = bd.aoc_status;
matched.Is_Winner__c          = bd.winner_bidder;
matched.Result_Stage__c       = bd.resultstage;

// ---- FIX 5: Bidder_Stage__c - status-based stage logic. (UNCHANGED)
// Does NOT change the existing winner-collection logic below,
// which still only depends on winner_bidder == true && aoc_status == true.
if (bd.winner_bidder == true && bd.aoc_status == true) {
matched.Bidder_Stage__c = 'Winner Bidder';
} else if (bd.aoc_status == true && bd.financial_status == true && bd.technical_status == true) {
matched.Bidder_Stage__c = 'AOC Done';
} else if (bd.financial_status == true && bd.technical_status == true) {
matched.Bidder_Stage__c = 'Financial Evaluation Done';
} else if (bd.technical_status == true) {
matched.Bidder_Stage__c = 'Technical Evaluation Done';
} else {
matched.Bidder_Stage__c = 'Possible Participant - Probable Bidder';
}

biddersToUpdate.add(matched);

if (bd.winner_bidder == true && bd.aoc_status == true) {
winnerBidderProductMap.put(matched.Id, productName);
winnerCount++;
}
}

if (!biddersToUpdate.isEmpty()) {
chunkedUpdate(biddersToUpdate); // secondary safety net only now
}

// ================== NEW: new-bidder insert + Project/Opportunity cascade ==================
// All bulkified per page. No callouts in this block, so ordering relative to
// the page's Listing API callout (already completed earlier in execute()) is safe.
if (!newBiddersToInsert.isEmpty()) {

Database.SaveResult[] newBidderInsertResults = Database.insert(newBiddersToInsert, false);
//Integer newBidderCreatedCount = 0;
for (Integer i = 0; i < newBidderInsertResults.size(); i++) {
if (!newBidderInsertResults[i].isSuccess()) {
System.debug('[ResultWinnerBidderContactBatch] New Bidders__c INSERT FAILED: '
+ newBidderInsertResults[i].getErrors());

} else {
newBidderCreatedCount++; // ---- NEW ----
}
}

// Winner collection for successfully-created new bidders (same criteria as matched path)
for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
if (newBidderInsertResults[i].isSuccess()
&& newBiddersToInsert[i].Is_Winner__c == true
&& newBiddersToInsert[i].AOC_Status__c == true) {
winnerBidderProductMap.put(newBiddersToInsert[i].Id, productName);
winnerCount++;
}
}

// ---- Resolve Project__c per Tender (bulk query) ----
Set<Id> tenderIdsForProject = new Set<Id>();
for (Map<String, Object> ctx : newBidderContext) {
tenderIdsForProject.add((Id) ctx.get('tenderId'));
}

Map<Id, Id>   projectIdByTenderId = new Map<Id, Id>();
Map<Id, Date> projectEndDateById  = new Map<Id, Date>();
if (!tenderIdsForProject.isEmpty()) {
for (Project__c proj : [
SELECT Id, Tender__c, Project_End_Date__c
FROM Project__c
WHERE Tender__c IN :tenderIdsForProject
]) {
projectIdByTenderId.put(proj.Tender__c, proj.Id);
projectEndDateById.put(proj.Id, proj.Project_End_Date__c);
}
}

// ---- Set Bidders__c.Project__c where a Project was resolved ----
List<Bidders__c> newBiddersToUpdateProject = new List<Bidders__c>();
Set<Id> distinctProjectIds = new Set<Id>();

for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
if (!newBidderInsertResults[i].isSuccess()) {
continue;
}
Id tenderIdForThisBidder = (Id) newBidderContext[i].get('tenderId');
Id resolvedProjectId = projectIdByTenderId.get(tenderIdForThisBidder);
if (resolvedProjectId == null) {
continue; // no Project for this Tender - skip Project link + Opportunity cascade
}

Bidders__c projUpd = new Bidders__c(Id = newBiddersToInsert[i].Id);
projUpd.Project__c = resolvedProjectId;
newBiddersToUpdateProject.add(projUpd);

newBidderContext[i].put('projectId', resolvedProjectId);
distinctProjectIds.add(resolvedProjectId);
}

if (!newBiddersToUpdateProject.isEmpty()) {
Database.SaveResult[] projUpdResults = Database.update(newBiddersToUpdateProject, false);
for (Database.SaveResult r : projUpdResults) {
if (!r.isSuccess()) {
System.debug('[ResultWinnerBidderContactBatch] Bidders__c.Project__c UPDATE FAILED: ' + r.getErrors());
}
}
}

// ---- Resolve parent Opportunity per Project (bulk query) ----
Map<Id, List<Opportunity>> parentOppsByProject = new Map<Id, List<Opportunity>>();
if (!distinctProjectIds.isEmpty()) {
for (Opportunity opp : [
SELECT Id, Project__c
FROM Opportunity
WHERE Project__c IN :distinctProjectIds
AND isParent__c = true
AND Stage__c != 'Closed Won'
]) {
if (!parentOppsByProject.containsKey(opp.Project__c)) {
parentOppsByProject.put(opp.Project__c, new List<Opportunity>());
}
parentOppsByProject.get(opp.Project__c).add(opp);
}
}

// ---- Create Bidder Opportunity per eligible new bidder ----
List<Opportunity> bidderOpportunitiesToInsert = new List<Opportunity>();

for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
if (!newBidderInsertResults[i].isSuccess()) {
continue;
}
Object projectIdObj = newBidderContext[i].get('projectId');
if (projectIdObj == null) {
continue; // no Project resolved for this bidder
}
Id projectId = (Id) projectIdObj;

List<Opportunity> candidateParents = parentOppsByProject.get(projectId);
if (candidateParents == null || candidateParents.size() != 1) {
IntegrationLogger.log(
'BidderOpportunitySkipped', productName,
'project-opportunity-resolution', null,
'Skipped Bidder Opportunity for Bidder ' + newBiddersToInsert[i].Bidder_Name__c
+ ' (Bidders__c Id: ' + newBiddersToInsert[i].Id + ') under Project ' + projectId
+ ' - found ' + (candidateParents == null ? 0 : candidateParents.size())
+ ' qualifying parent Opportunity(ies), expected exactly 1.',
null, false, null,
(Id) newBidderContext[i].get('tenderId'),
(String) newBidderContext[i].get('commonKey')
);
continue;
}

Opportunity parentOpp = candidateParents[0];
String deptName = (String) newBidderContext[i].get('deptName');

Opportunity bidderOpp = new Opportunity();
bidderOpp.Name                  = deptName + '_' + newBiddersToInsert[i].Bidder_Name__c;
bidderOpp.CloseDate             = projectEndDateById.get(projectId);
// ASSUMPTION/OPEN: standard StageName is required on Opportunity insert but
// was never specified for this flow - defaulting to 'Nurture'. Confirm before deploy.
bidderOpp.StageName             = 'Nurture';
bidderOpp.Parent_Opportunity__c = parentOpp.Id;
bidderOpp.Project__c            = projectId;
bidderOpp.Tender__c             = (Id) newBidderContext[i].get('tenderId');
bidderOpp.Bidder__c             = newBiddersToInsert[i].Id;
bidderOpp.Department_Name__c    = deptName;

Object ownerIdObj = newBidderContext[i].get('ownerId'); // <<< OWNER CHANGE >>>
if (ownerIdObj != null) { bidderOpp.OwnerId = (Id) ownerIdObj; }
bidderOpportunitiesToInsert.add(bidderOpp);
}

if (!bidderOpportunitiesToInsert.isEmpty()) {
Database.SaveResult[] oppInsertResults = Database.insert(bidderOpportunitiesToInsert, false);
for (Database.SaveResult r : oppInsertResults) {
if (!r.isSuccess()) {
System.debug('[ResultWinnerBidderContactBatch] Bidder Opportunity INSERT FAILED: ' + r.getErrors());
}
}
}
}
// ================== END NEW ==================

return new Map<String, Object>{
'matchedTenderIds' => matchedTenderIds,
'unmatchedTenderIds' => unmatchedTenderIds,
'matchedBidderCount' => matchedBidderCount,
'unmatchedBidderCount' => unmatchedBidderCount,
'winnerCount' => winnerCount,
'newBidderCreatedCount' => newBidderCreatedCount
};
}*/
    // Processes ONE page's Result records: tender match -> bidder match ->
    // chunked update (safety net) -> winner collection -> Tender__c result
    // field update -> returns counts.
    //
    // ---- NEW (RETRY LOGIC) ----
    // Two additions for the 11 AM / 2:30 PM same-day retry requirement:
    //   1. FILTER: a matched Tender is skipped from tendersToUpdate entirely if
    //      its Result_Fired_Date_Time__c is already stamped with TODAY's date -
    //      meaning it was already successfully updated earlier today, so the
    //      2:30 PM run must not re-touch it.
    //   2. STAMP: right after a Tender's field update succeeds (same spot
    //      TenderResultUpdated is logged), Result_Fired_Date_Time__c is set to
    //      now, and Result_Fired_Date_Time_Summary__c has the new timestamp
    //      appended (skipped only if appending would exceed 130000 chars).
    //   This is a SECOND Database.update, issued after the original tender
    //   update's results are known, since we only know success per-record
    //   after that first DML returns.
    private Map<String, Object> processPageRecords(List<ResultWrappers.ResultRecord> pageRecords, String productName) {
        
        List<Map<String, Object>> pageBidderEntries = new List<Map<String, Object>>();
        for (ResultWrappers.ResultRecord rec : pageRecords) {
            if (rec.bidderdetails == null) {
                continue;
            }
            for (ResultWrappers.BidderDetail bd : rec.bidderdetails) {
                if (String.isNotBlank(bd.bidderName)) {
                    pageBidderEntries.add(new Map<String, Object>{
                        'tenderid' => rec.tenderid,
                            'bidderDetail' => bd
                            });
                }
            }
        }
        
        Set<String> matchedTenderIds = new Set<String>();
        Set<String> unmatchedTenderIds = new Set<String>();
        Integer matchedBidderCount = 0;
        Integer unmatchedBidderCount = 0;
        Integer winnerCount = 0;
        Integer newBidderCreatedCount = 0;
        
        if (pageBidderEntries.isEmpty()) {
            return new Map<String, Object>{
                'matchedTenderIds' => matchedTenderIds,
                    'unmatchedTenderIds' => unmatchedTenderIds,
                    'matchedBidderCount' => matchedBidderCount,
                    'unmatchedBidderCount' => unmatchedBidderCount,
                    'winnerCount' => winnerCount,
                    'newBidderCreatedCount' => newBidderCreatedCount
                    };
                        }
        
        Set<String> pageTenderIdStrs = new Set<String>();
        for (Map<String, Object> w : pageBidderEntries) {
            pageTenderIdStrs.add(String.valueOf(w.get('tenderid')));
        }
        
        // ---- NEW (RETRY LOGIC): Result_Fired_Date_Time__c and
        // Result_Fired_Date_Time_Summary__c added to SELECT so the filter (below)
        // and the stamp step both have the values they need, with no extra query.
        Map<String, Tender__c> tenderByExtId = new Map<String, Tender__c>();
        if (!pageTenderIdStrs.isEmpty()) {
            for (Tender__c t : [
                SELECT Id, External_Tender_Id__c, Common_Key__c, Department_Name__c, OwnerId,
                Result_Fired_Date_Time__c, Result_Fired_Date_Time_Summary__c
                FROM Tender__c
                WHERE External_Tender_Id__c IN :pageTenderIdStrs
            ]) {
                tenderByExtId.put(t.External_Tender_Id__c, t);
            }
        }
        
        matchedTenderIds.addAll(tenderByExtId.keySet());
        unmatchedTenderIds.addAll(pageTenderIdStrs);
        unmatchedTenderIds.removeAll(tenderByExtId.keySet());
        
        if (!unmatchedTenderIds.isEmpty()) {
            System.debug('[ResultWinnerBidderContactBatch] No matching Tender__c for tenderid(s): '
                         + unmatchedTenderIds + ' - skipping those Result records entirely.');
        }
        
        // ---- Tender__c result-field update: for every Result record whose
        // tenderid matched a Tender__c above, copy the Result-level fields
        // onto that Tender__c. Uses the same tenderByExtId map - no extra query.
        List<Tender__c> tendersToUpdate = new List<Tender__c>();
        for (ResultWrappers.ResultRecord rec : pageRecords) {
            String recTenderIdStr = String.valueOf(rec.tenderid);
            Tender__c matchedTender = tenderByExtId.get(recTenderIdStr);
            if (matchedTender == null) {
                continue;
            }
            
            // ---- NEW (RETRY LOGIC): FILTER ----
            // If this Tender already has a successful Result fire stamped today,
            // skip it entirely on this run - don't rebuild tUpd, don't re-update,
            // don't re-stamp. This is what makes the 2:30 PM run only touch the
            // Tenders the 11 AM run failed on (or never reached).
            if (isFiredToday(matchedTender.Result_Fired_Date_Time__c)) {
                continue;
            }
            
            Tender__c tUpd = new Tender__c(Id = matchedTender.Id);
            tUpd.Bidaward_Id_from_Result__c = String.valueOf(rec.bidawardid);
            tUpd.Source_Bidaward_Id__c             = rec.sourcebidawardid;
            tUpd.Posting_Date__c                   = parseResultDate(rec.postingdate);
            tUpd.Tender_Result_Value__c            = rec.value;
            tUpd.Result_Created_Date__c            = parseResultDate(rec.datecreated);
            tUpd.AOC_Description__c                = rec.aocdescription;
            tUpd.Contract_Date__c                  = parseResultDate(rec.contractdate);
            tUpd.Financialbid_Evaluation_Date__c   = parseResultDate(rec.financialbidevaluationdate);
            tUpd.Technicalbid_Evaluation_Date__c   = parseResultDate(rec.technicalbidevaluationdate);
            tUpd.AOC_Updation_Date__c              = parseResultDate(rec.aocupdationdate);
            tUpd.Organization_Name__c              = rec.organization_name;
            tUpd.Result_Category__c                = (rec.category != null && !rec.category.isEmpty())
                ? String.join(rec.category, ';')
                : null;
            
            // Truncated Text(255) versions of the two long-text Result fields above.
            String resultCategoryJoined = (rec.category != null && !rec.category.isEmpty())
                ? String.join(rec.category, ';')
                : null;
            tUpd.Result_Category_Text__c = truncate240WithEllipsis(resultCategoryJoined);
            tUpd.AOC_Description_Text__c = truncate240WithEllipsis(rec.aocdescription);
            
            // ---- NEW: Tender_Stage_Bidder_Wise__c - driven purely by rec.resultstage ----
            if (rec.resultstage == 1) {
                tUpd.Tender_Stage_Bidder_Wise__c = 'Technical Evaluation Done';
            } else if (rec.resultstage == 2) {
                tUpd.Tender_Stage_Bidder_Wise__c = 'Financial Evaluation Done';
            } else if (rec.resultstage == 3) {
                tUpd.Tender_Stage_Bidder_Wise__c = 'AOC Done';
            }
            // else: resultstage null/not 1-2-3 - Tender_Stage_Bidder_Wise__c left unset,
            // existing value preserved (per confirmed requirement).
            
            // ---- NEW: store raw resultstage number on Tender__c ----
            tUpd.ResultStage__c = rec.resultstage;
            
            tendersToUpdate.add(tUpd);
        }
        
        if (!tendersToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] tenderUpdateResults = Database.update(tendersToUpdate, false);
                
                // ---- NEW (RETRY LOGIC): STAMP ----
                // Collected here, then updated in a SEPARATE Database.update call
                // right after this loop - we only know per-record success after
                // tenderUpdateResults comes back, so it can't be part of the same DML.
                List<Tender__c> tendersToStamp = new List<Tender__c>();
                
                for (Integer i = 0; i < tenderUpdateResults.size(); i++) {
                    Database.SaveResult res = tenderUpdateResults[i];
                    if (!res.isSuccess()) {
                        System.debug('[ResultWinnerBidderContactBatch] Tender__c result-field UPDATE FAILED: ' + res.getErrors());
                        continue;
                    }
                    
                    /*
                    Id updatedTenderId = tendersToUpdate[i].Id;
                    String tenderCommonKey = null;
                    Tender__c matchedTenderForStamp = null;
                    for (Tender__c t : tenderByExtId.values()) {
                        if (t.Id == updatedTenderId) {
                            tenderCommonKey = t.Common_Key__c;
                            matchedTenderForStamp = t;
                            break;
                        }
}*/
                    Id updatedTenderId = tendersToUpdate[i].Id;
                    String tenderCommonKey = null;
                    Tender__c matchedTenderForStamp = null;
                    for (Tender__c cachedTender : tenderByExtId.values()) {
                        if (cachedTender.Id == updatedTenderId) {
                            tenderCommonKey = cachedTender.Common_Key__c;
                            matchedTenderForStamp = cachedTender;
                            break;
                        }
                    }
                    
                    IntegrationLogger.log(
                        'TenderResultUpdated', productName,
                        'result-listing-data (tender update)', null,
                        'Tender__c ' + updatedTenderId + ' updated successfully with Result data.',
                        null, true, null,
                        updatedTenderId, tenderCommonKey + 'result'
                    );
                    
                    // ---- NEW (RETRY LOGIC): build the stamp record for this Tender ----
                    Datetime fireNow = Datetime.now();
                    Tender__c stampUpd = new Tender__c(Id = updatedTenderId);
                    stampUpd.Result_Fired_Date_Time__c = fireNow;
                    
                    String existingSummary = (matchedTenderForStamp != null)
                        ? matchedTenderForStamp.Result_Fired_Date_Time_Summary__c
                        : null;
                    String entry = String.valueOf(fireNow);
                    String newSummary = String.isBlank(existingSummary)
                        ? entry
                        : existingSummary + ' , ' + entry;
                    
                    // Skip the append (leave Summary as-is) if it would exceed 130000
                    // chars - the discrete Result_Fired_Date_Time__c is still stamped
                    // regardless via stampUpd above.
                    if (newSummary.length() <= 130000) {
                        stampUpd.Result_Fired_Date_Time_Summary__c = newSummary;
                    }
                    
                    tendersToStamp.add(stampUpd);
                }
                
                // ---- NEW (RETRY LOGIC): second DML - stamp every successfully
                // updated Tender from this page in one shot.
                if (!tendersToStamp.isEmpty()) {
                    Database.SaveResult[] stampResults = Database.update(tendersToStamp, false);
                    for (Database.SaveResult sRes : stampResults) {
                        if (!sRes.isSuccess()) {
                            System.debug('[ResultWinnerBidderContactBatch] Result_Fired_Date_Time stamp UPDATE FAILED: ' + sRes.getErrors());
                        }
                    }
                }
                
            } catch (Exception e) {
                IntegrationLogger.log(
                    'TenderResultUpdateFailed', productName,
                    'result-listing-data (tender update)', null, e.getMessage(),
                    null, false, e.getMessage()
                );
            }
        }
        
        List<Map<String, Object>> matchedTenderEntries = new List<Map<String, Object>>();
        for (Map<String, Object> w : pageBidderEntries) {
            String tenderIdStr = String.valueOf(w.get('tenderid'));
            if (tenderByExtId.containsKey(tenderIdStr)) {
                matchedTenderEntries.add(w);
            }
        }
        
        Set<String> keys = new Set<String>();
        for (Map<String, Object> w : matchedTenderEntries) {
            ResultWrappers.BidderDetail bd = (ResultWrappers.BidderDetail) w.get('bidderDetail');
            keys.add(String.valueOf(w.get('tenderid')) + '-' + bd.bidderName);
        }
        
        Map<String, Bidders__c> bidderByKey = new Map<String, Bidders__c>();
        if (!keys.isEmpty()) {
            for (Bidders__c b : [
                SELECT Id, Bidder_Unique_Key__c, Tender__c
                FROM Bidders__c
                WHERE Bidder_Unique_Key__c IN :keys
            ]) {
                bidderByKey.put(b.Bidder_Unique_Key__c, b);
            }
        }
        
        List<Bidders__c> biddersToUpdate = new List<Bidders__c>();
        List<Map<String, Object>> newBidderContext = new List<Map<String, Object>>();
        List<Bidders__c> newBiddersToInsert = new List<Bidders__c>();
        
        for (Map<String, Object> w : matchedTenderEntries) {
            String tenderIdStr = String.valueOf(w.get('tenderid'));
            ResultWrappers.BidderDetail bd = (ResultWrappers.BidderDetail) w.get('bidderDetail');
            String key = tenderIdStr + '-' + bd.bidderName;
            
            Bidders__c matched = bidderByKey.get(key);
            if (matched == null) {
                unmatchedBidderCount++;
                
                Tender__c matchedTenderForNewBidder = tenderByExtId.get(tenderIdStr);
                
                Bidders__c newBidder = new Bidders__c();
                newBidder.Tender__c             = matchedTenderForNewBidder.Id;
                if (matchedTenderForNewBidder.OwnerId != null) { newBidder.OwnerId = matchedTenderForNewBidder.OwnerId; }
                
                newBidder.Bidder_Name__c        = bd.bidderName;
                newBidder.Product_Name__c       = productName;
                newBidder.Common_Key__c         = matchedTenderForNewBidder.Common_Key__c;
                newBidder.Source_Tender_Id__c   = tenderIdStr;
                newBidder.External_Tender_Id__c = tenderIdStr;
                newBidder.Bidder_Unique_Key__c  = key;
                newBidder.Awarded_Value__c      = bd.awardedValue;
                newBidder.Bid_Value__c          = bd.bidValue;
                newBidder.Bid_Rank__c           = bd.bidRank;
                newBidder.Technical_Status__c   = bd.technical_status;
                newBidder.Financial_Status__c   = bd.financial_status;
                newBidder.AOC_Status__c         = bd.aoc_status;
                newBidder.Is_Winner__c          = bd.winner_bidder;
                newBidder.Result_Stage__c       = bd.resultstage;
                newBidder.Result_Created_Date__c = Date.today();
                newBidder.New_bidder_from_result__c = true;
                
                if (bd.winner_bidder == true && bd.aoc_status == true) {
                    newBidder.Bidder_Stage__c = 'Winner Bidder';
                } else if (bd.aoc_status == true && bd.financial_status == true && bd.technical_status == true) {
                    newBidder.Bidder_Stage__c = 'AOC Done';
                } else if (bd.financial_status == true && bd.technical_status == true) {
                    newBidder.Bidder_Stage__c = 'Financial Evaluation Done';
                } else if (bd.technical_status == true) {
                    newBidder.Bidder_Stage__c = 'Technical Evaluation Done';
                } else {
                    newBidder.Bidder_Stage__c = 'Possible Participant - Probable Bidder';
                }
                
                newBiddersToInsert.add(newBidder);
                newBidderContext.add(new Map<String, Object>{
                    'tenderId'  => matchedTenderForNewBidder.Id,
                        'commonKey' => matchedTenderForNewBidder.Common_Key__c,
                        'deptName'  => matchedTenderForNewBidder.Department_Name__c,
                        'ownerId'   => matchedTenderForNewBidder.OwnerId
                        });
                
                continue;
            }
            
            matchedBidderCount++;
            
            matched.Awarded_Value__c      = bd.awardedValue;
            matched.Bid_Value__c          = bd.bidValue;
            matched.Bid_Rank__c = bd.bidRank;
            matched.Technical_Status__c   = bd.technical_status;
            matched.Financial_Status__c   = bd.financial_status;
            matched.AOC_Status__c         = bd.aoc_status;
            matched.Is_Winner__c          = bd.winner_bidder;
            matched.Result_Stage__c       = bd.resultstage;
            
            if (bd.winner_bidder == true && bd.aoc_status == true) {
                matched.Bidder_Stage__c = 'Winner Bidder';
            } else if (bd.aoc_status == true && bd.financial_status == true && bd.technical_status == true) {
                matched.Bidder_Stage__c = 'AOC Done';
            } else if (bd.financial_status == true && bd.technical_status == true) {
                matched.Bidder_Stage__c = 'Financial Evaluation Done';
            } else if (bd.technical_status == true) {
                matched.Bidder_Stage__c = 'Technical Evaluation Done';
            } else {
                matched.Bidder_Stage__c = 'Possible Participant - Probable Bidder';
            }
            
            biddersToUpdate.add(matched);
            
            if (bd.winner_bidder == true && bd.aoc_status == true) {
                winnerBidderProductMap.put(matched.Id, productName);
                winnerCount++;
            }
        }
        
        if (!biddersToUpdate.isEmpty()) {
            chunkedUpdate(biddersToUpdate);
        }
        
        if (!newBiddersToInsert.isEmpty()) {
            
            Database.SaveResult[] newBidderInsertResults = Database.insert(newBiddersToInsert, false);
            for (Integer i = 0; i < newBidderInsertResults.size(); i++) {
                if (!newBidderInsertResults[i].isSuccess()) {
                    System.debug('[ResultWinnerBidderContactBatch] New Bidders__c INSERT FAILED: '
                                 + newBidderInsertResults[i].getErrors());
                } else {
                    newBidderCreatedCount++;
                }
            }
            
            for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
                if (newBidderInsertResults[i].isSuccess()
                    && newBiddersToInsert[i].Is_Winner__c == true
                    && newBiddersToInsert[i].AOC_Status__c == true) {
                        winnerBidderProductMap.put(newBiddersToInsert[i].Id, productName);
                        winnerCount++;
                    }
            }
            
            Set<Id> tenderIdsForProject = new Set<Id>();
            for (Map<String, Object> ctx : newBidderContext) {
                tenderIdsForProject.add((Id) ctx.get('tenderId'));
            }
            
            Map<Id, Id>   projectIdByTenderId = new Map<Id, Id>();
            Map<Id, Date> projectEndDateById  = new Map<Id, Date>();
            if (!tenderIdsForProject.isEmpty()) {
                for (Project__c proj : [
                    SELECT Id, Tender__c, Project_End_Date__c
                    FROM Project__c
                    WHERE Tender__c IN :tenderIdsForProject
                ]) {
                    projectIdByTenderId.put(proj.Tender__c, proj.Id);
                    projectEndDateById.put(proj.Id, proj.Project_End_Date__c);
                }
            }
            
            List<Bidders__c> newBiddersToUpdateProject = new List<Bidders__c>();
            Set<Id> distinctProjectIds = new Set<Id>();
            
            for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
                if (!newBidderInsertResults[i].isSuccess()) {
                    continue;
                }
                Id tenderIdForThisBidder = (Id) newBidderContext[i].get('tenderId');
                Id resolvedProjectId = projectIdByTenderId.get(tenderIdForThisBidder);
                if (resolvedProjectId == null) {
                    continue;
                }
                
                Bidders__c projUpd = new Bidders__c(Id = newBiddersToInsert[i].Id);
                projUpd.Project__c = resolvedProjectId;
                newBiddersToUpdateProject.add(projUpd);
                
                newBidderContext[i].put('projectId', resolvedProjectId);
                distinctProjectIds.add(resolvedProjectId);
            }
            
            if (!newBiddersToUpdateProject.isEmpty()) {
                Database.SaveResult[] projUpdResults = Database.update(newBiddersToUpdateProject, false);
                for (Database.SaveResult r : projUpdResults) {
                    if (!r.isSuccess()) {
                        System.debug('[ResultWinnerBidderContactBatch] Bidders__c.Project__c UPDATE FAILED: ' + r.getErrors());
                    }
                }
            }
            
            Map<Id, List<Opportunity>> parentOppsByProject = new Map<Id, List<Opportunity>>();
            if (!distinctProjectIds.isEmpty()) {
                for (Opportunity opp : [
                    SELECT Id, Project__c
                    FROM Opportunity
                    WHERE Project__c IN :distinctProjectIds
                    AND isParent__c = true
                    AND Stage__c != 'Closed Won'
                ]) {
                    if (!parentOppsByProject.containsKey(opp.Project__c)) {
                        parentOppsByProject.put(opp.Project__c, new List<Opportunity>());
                    }
                    parentOppsByProject.get(opp.Project__c).add(opp);
                }
            }
            
            List<Opportunity> bidderOpportunitiesToInsert = new List<Opportunity>();
            
            for (Integer i = 0; i < newBiddersToInsert.size(); i++) {
                if (!newBidderInsertResults[i].isSuccess()) {
                    continue;
                }
                Object projectIdObj = newBidderContext[i].get('projectId');
                if (projectIdObj == null) {
                    continue;
                }
                Id projectId = (Id) projectIdObj;
                
                List<Opportunity> candidateParents = parentOppsByProject.get(projectId);
                if (candidateParents == null || candidateParents.size() != 1) {
                    IntegrationLogger.log(
                        'BidderOpportunitySkipped', productName,
                        'project-opportunity-resolution', null,
                        'Skipped Bidder Opportunity for Bidder ' + newBiddersToInsert[i].Bidder_Name__c
                        + ' (Bidders__c Id: ' + newBiddersToInsert[i].Id + ') under Project ' + projectId
                        + ' - found ' + (candidateParents == null ? 0 : candidateParents.size())
                        + ' qualifying parent Opportunity(ies), expected exactly 1.',
                        null, false, null,
                        (Id) newBidderContext[i].get('tenderId'),
                        (String) newBidderContext[i].get('commonKey')
                    );
                    continue;
                }
                
                Opportunity parentOpp = candidateParents[0];
                String deptName = (String) newBidderContext[i].get('deptName');
                
                Opportunity bidderOpp = new Opportunity();
                bidderOpp.Name                  = deptName + '_' + newBiddersToInsert[i].Bidder_Name__c;
                bidderOpp.CloseDate             = projectEndDateById.get(projectId);
                bidderOpp.StageName             = 'Nurture';
                bidderOpp.Parent_Opportunity__c = parentOpp.Id;
                bidderOpp.Project__c            = projectId;
                bidderOpp.Tender__c             = (Id) newBidderContext[i].get('tenderId');
                bidderOpp.Bidder__c             = newBiddersToInsert[i].Id;
                bidderOpp.Department_Name__c    = deptName;
                
                Object ownerIdObj = newBidderContext[i].get('ownerId');
                if (ownerIdObj != null) { bidderOpp.OwnerId = (Id) ownerIdObj; }
                bidderOpportunitiesToInsert.add(bidderOpp);
            }
            
            if (!bidderOpportunitiesToInsert.isEmpty()) {
                Database.SaveResult[] oppInsertResults = Database.insert(bidderOpportunitiesToInsert, false);
                for (Database.SaveResult r : oppInsertResults) {
                    if (!r.isSuccess()) {
                        System.debug('[ResultWinnerBidderContactBatch] Bidder Opportunity INSERT FAILED: ' + r.getErrors());
                    }
                }
            }
        }
        
        return new Map<String, Object>{
            'matchedTenderIds' => matchedTenderIds,
                'unmatchedTenderIds' => unmatchedTenderIds,
                'matchedBidderCount' => matchedBidderCount,
                'unmatchedBidderCount' => unmatchedBidderCount,
                'winnerCount' => winnerCount,
                'newBidderCreatedCount' => newBidderCreatedCount
                };
                    }
    
    // ---- NEW (RETRY LOGIC): helper used by the filter above -----
    // Returns true only if the given DateTime is non-null AND its date portion
    // equals today's date - meaning this Tender was already successfully
    // fired by the Result flow earlier today, so it should be skipped on any
    // later same-day run (e.g. the 2:30 PM retry).
    private Boolean isFiredToday(Datetime firedDateTime) {
        if (firedDateTime == null) {
            return false;
        }
        return firedDateTime.date() == Date.today();
    }
    private void chunkedUpdate(List<Bidders__c> records) {
        for (Integer start = 0; start < records.size(); start += DML_CHUNK_SIZE) {
            Integer endIdx = Math.min(start + DML_CHUNK_SIZE, records.size());
            List<Bidders__c> chunk = new List<Bidders__c>();
            for (Integer i = start; i < endIdx; i++) {
                chunk.add(records[i]);
            }
            try {
                Database.SaveResult[] updateResults = Database.update(chunk, false);
                for (Database.SaveResult res : updateResults) {
                    if (!res.isSuccess()) {
                        System.debug('[ResultWinnerBidderContactBatch] Bidders__c UPDATE FAILED: ' + res.getErrors());
                    }
                }
            } catch (Exception e) {
                IntegrationLogger.log(
                    'BidderUpdateChunkFailed', null,
                    'bidder-update-chunk-' + start, null, e.getMessage(),
                    null, false, e.getMessage()
                );
            }
        }
    }
    
    // Safely truncates a string to 240 chars and appends '...' if it was cut,
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
    
    private String generateResultCommonKey(String productName) {
        Date resultDate = Date.today();//Date.today().addDays(-1);
        String dateStr = String.valueOf(resultDate.day()).leftPad(2, '0')
            + String.valueOf(resultDate.month()).leftPad(2, '0')
            + String.valueOf(resultDate.year());
        Integer randNum = Integer.valueOf(Math.floor(Math.random() * 900000)) + 100000;
        return productName + '-' + dateStr + '-' + String.valueOf(randNum) + '-Result';
    }
    
    private String formatResultApiDate() {
        Date resultDate = Date.today();//Date.today().addDays(-1);
        return String.valueOf(resultDate.year())
            + '-' + String.valueOf(resultDate.month()).leftPad(2, '0')
            + '-' + String.valueOf(resultDate.day()).leftPad(2, '0');
    }
    
    // Safely parses a Result API date string ("yyyy-MM-dd") into a Date.
    // Returns null for blank/empty strings or unparseable values, so a bad
    // or missing date from the API never fails the whole Tender__c update.
    private Date parseResultDate(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }
        try {
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            System.debug('[ResultWinnerBidderContactBatch] Could not parse date: ' + dateStr + ' - ' + e.getMessage());
            return null;
        }
    }
    
    private Integer callResultCountApi(String productName, String resultCommonKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(RESULT_NAMED_CREDENTIAL + '/Utkarsh/api/result-listing-data-count');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        
        Map<String, Object> payload = new Map<String, Object>{
            'Date' => formatResultApiDate(), 'ResultIds' => '', 'ProductName' => productName
                };
                    String body = JSON.serialize(payload);
        req.setBody(body);
        
        Integer statusCode; String responseBody; Boolean success = false; Integer count = null;
        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            if (statusCode == 200) {
                ResultWrappers.CountResponse parsed =
                    (ResultWrappers.CountResponse) JSON.deserialize(responseBody, ResultWrappers.CountResponse.class);
                if (parsed.Success && parsed.Data != null && !parsed.Data.isEmpty()) {
                    count = parsed.Data[0].count;
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
        }
        
        IntegrationLogger.log('ResultCount', productName, 'result-listing-data-count', body, responseBody,
                              statusCode, success, success ? null : responseBody, null, resultCommonKey);
        return count;
    }
    
    private List<ResultWrappers.ResultRecord> callResultListingApi(String productName, Integer pageNo, String resultCommonKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(RESULT_NAMED_CREDENTIAL + '/Utkarsh/api/result-listing-data');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        
        Map<String, Object> payload = new Map<String, Object>{
            'Date' => formatResultApiDate(), 'ResultIds' => '', 'ProductName' => productName,
                'page_no' => pageNo, '_record_per_page' => RECORDS_PER_PAGE
                };
                    String body = JSON.serialize(payload);
        req.setBody(body);
        
        Integer statusCode; String responseBody; Boolean success = false;
        List<ResultWrappers.ResultRecord> records = null;
        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            if (statusCode == 200) {
                ResultWrappers.ListingResponse parsed =
                    (ResultWrappers.ListingResponse) JSON.deserialize(responseBody, ResultWrappers.ListingResponse.class);
                if (parsed.Success) {
                    records = parsed.Data;
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
        }
        
        IntegrationLogger.log('ResultListing', productName, 'result-listing-data (page ' + pageNo + ')', body,
                              responseBody, statusCode, success, success ? null : responseBody, null, resultCommonKey);
        return records;
    }
    
    private void mergeSet(
        Map<String, Set<String>> targetMap,
        String key,
        Set<String> toAdd
    ) {
        if (toAdd == null) {
            return;
        }
        
        if (!targetMap.containsKey(key)) {
            targetMap.put(key, new Set<String>());
        }
        
        targetMap.get(key).addAll(toAdd);
    }
    
    private void addCount(
        Map<String, Integer> targetMap,
        String key,
        Integer toAdd
    ) {
        if (toAdd == null) {
            return;
        }
        
        Integer current = targetMap.containsKey(key)
            ? targetMap.get(key)
            : 0;
        
        targetMap.put(key, current + toAdd);
    }
    @TestVisible
    public Map<String, Object> testProcessPageRecords(List<ResultWrappers.ResultRecord> pageRecords, String productName) {
        return processPageRecords(pageRecords, productName);
    }
    
    @TestVisible
    public Map<Id, String> testGetWinnerMap() {
        return winnerBidderProductMap;
    }
    
    
}