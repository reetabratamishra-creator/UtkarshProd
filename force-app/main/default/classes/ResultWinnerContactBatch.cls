/*
================================================================================
CLASS: ResultWinnerContactBatch
--------------------------------------------------------------------------------
SCENARIO / OWNER: Ayantika

Stage 3B of the daily integration - chained from ResultWinnerBidderContactBatch
(Stage 3A) finish(), running in a SEPARATE transaction with its own fresh
100-callout budget. This is the bulk-safety fix for the callout-limit risk:
previously, Contact API calls were made in the SAME transaction as the Result
Listing API calls, which could exceed 100 callouts/transaction on a large
product and roll back the entire product's processing.

For every winner Bidders__c collected by Stage 3A (across every product
processed in that run):
  1. Calls the Probable Bidder Contact Details API for that bidder's name.
  2. Creates a Bidders_Contact_Details__c record with the response, linked to
     BOTH the existing winner Bidders__c and its existing (already-matched)
     Tender__c.
  3. Creates an Integration Log for every Contact API call, using the
     matched Tender's own Id + Common_Key__c (e.g. "...Tender-1") - this
     traces the log back through Product -> Tender -> Winner Bidder, per the
     Result API business requirement.

Batch scope size is 25 - keeps callouts per execute() call (25, one per
bidder) well under the 100-callout governor limit, even combined with the
Integration_Log__c/Integration_JSON_Log__c DML done in the same execute()
after all callouts (logs are only inserted via IntegrationLogger.flush()
AFTER all of this scope's callouts are done, so callouts are never
interleaved with DML in a way that violates "no callout after DML").

NOTE: Duplicate-checking against previously stored Bidders_Contact_Details__c
records is intentionally NOT done - a Bidder can have multiple contact
records over time, so every winner gets a fresh contact record inserted on
every run.

Named Credential: 'callout:tender247_Tender' (Contact endpoint lives here,
same as ProbableBidderBatch's contact-details call).
================================================================================
*/
public class ResultWinnerContactBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private static final String TENDER_NAMED_CREDENTIAL = 'callout:tender247_Tender';

    // Passed in from ResultWinnerBidderContactBatch.finish() - Bidders__c Id -> Product Name
    private Map<Id, String> winnerBidderProductMap;

    public ResultWinnerContactBatch(Map<Id, String> winnerBidderProductMap) {
        this.winnerBidderProductMap = winnerBidderProductMap;
    }

    // Queries the actual winner Bidders__c records, along with their matched
    // Tender's Id + Common_Key__c (via the Tender__c lookup relationship),
    // for the tracing requirement in Step 10 of the Result API doc.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[ResultWinnerContactBatch] START - processing ' + winnerBidderProductMap.size() + ' winner bidder(s)');
        return Database.getQueryLocator([
            SELECT Id, Bidder_Name__c, External_Tender_Id__c,
                   Tender__c, Tender__r.Id, Tender__r.Common_Key__c, OwnerId
            FROM Bidders__c
            WHERE Id IN :winnerBidderProductMap.keySet()
        ]);
    }

    // ALL callouts (Contact API) happen first for this scope, then ALL DML
    // (Bidders_Contact_Details__c insert + IntegrationLogger.flush()) happens
    // after - same callout-before-DML ordering convention as ProbableBidderBatch.
    public void execute(Database.BatchableContext bc, List<sObject> scope) {

        List<Bidders_Contact_Details__c> contactsToInsert = new List<Bidders_Contact_Details__c>();

        // ---- PASS 1: ALL CALLOUTS ----
        for (sObject s : scope) {
            Bidders__c winner = (Bidders__c) s;
            String productName = winnerBidderProductMap.containsKey(winner.Id)
                ? winnerBidderProductMap.get(winner.Id)
                : null;

            ResultWrappers.ContactDetailData contact = callContactDetailsApi(winner, productName);
            if (contact == null) {
                continue;
            }

            Bidders_Contact_Details__c c = new Bidders_Contact_Details__c();
            c.Bidders__c                = winner.Id;
            c.Tender__c                 = winner.Tender__c;
            c.Name                      = contact.bidder_name;
            c.Contact_Number__c         = contact.contact_number;
            c.Email__c                  = contact.email_id;
            c.Pan_No__c                 = contact.pan_no;
            c.Vendorcode__c             = contact.vendorcode;
            c.Seller_Id__c              = contact.seller_id;
            c.Gem_Id__c                 = contact.gem_id;
            c.Msme_Number__c            = contact.msme_number;
            c.Category__c               = contact.category;
            c.Branch_Name__c            = contact.branch_name;
            c.Address__c                = contact.address;
            c.Pincode__c                = contact.pincode;
            c.GST_Number__c             = contact.gst_number;
            c.Alternate_Phone__c        = contact.phone_number;
            c.Alternate_Email__c        = contact.alternate_email_id;
            c.Designation__c            = contact.designation;
            c.Source_Tender_Id__c       = winner.External_Tender_Id__c;
            c.Contact_Unique_Key__c     = winner.External_Tender_Id__c + '-' + winner.Bidder_Name__c;
            if (winner.OwnerId != null) { c.OwnerId = winner.OwnerId; }

            contactsToInsert.add(c);
        }

        // ---- PASS 2: ALL DML ----
        if (!contactsToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(contactsToInsert, false);
            for (Database.SaveResult res : insertResults) {
                if (!res.isSuccess()) {
                    System.debug('[ResultWinnerContactBatch] Contact INSERT FAILED: ' + res.getErrors());
                }
            }
        }

        IntegrationLogger.flush();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('[ResultWinnerContactBatch] FINISH');
    }

    // Calls the Probable Bidder Contact Details API for one winning bidder.
    // Logs against the MATCHED TENDER's own Id + Common_Key__c (e.g. "...Tender-1"),
    // so this log traces back through Product -> Tender -> Winner Bidder.
    private ResultWrappers.ContactDetailData callContactDetailsApi(Bidders__c winner, String productName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TENDER_NAMED_CREDENTIAL + '/Utkarsh/api/probable-bidders-contact-details');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> payload = new Map<String, Object>{ 'ProbableBidderName' => winner.Bidder_Name__c };
        String body = JSON.serialize(payload);
        req.setBody(body);

        Integer statusCode; String responseBody; Boolean success = false;
        ResultWrappers.ContactDetailData contact = null;
        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            if (statusCode == 200) {
                ResultWrappers.ContactDetailsResponse parsed =
                    (ResultWrappers.ContactDetailsResponse) JSON.deserialize(responseBody, ResultWrappers.ContactDetailsResponse.class);
                if (parsed.Success && parsed.Data != null && !parsed.Data.isEmpty()) {
                    contact = parsed.Data[0];
                    success = true;
                }
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
        }

        IntegrationLogger.log('ProbableBidderContact', productName, 'probable-bidders-contact-details',
            body, responseBody, statusCode, success, success ? null : responseBody,
            winner.Tender__r.Id, winner.Tender__r.Common_Key__c);

        return contact;
    }
}