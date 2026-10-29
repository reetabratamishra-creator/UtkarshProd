/*
================================================================================
CLASS: ContactDetailsBatch  (STAGE 3 of 3 - FINAL STAGE)
--------------------------------------------------------------------------------
WHY THIS CLASS EXISTS:
Stage 2 (ProbableBidderBatch) already created a lightweight STUB Account for
every new bidder name (Name + Bidder_Unique_Key__c + Contact_Fetched__c =
false). This class queries exactly those stub Accounts, calls the Contact
Details API for each one, fills in the full contact info, and marks
Contact_Fetched__c = true so it's never processed again.

DUPLICATE PREVENTION:
  - Stage 2 already guarantees only ONE stub Account exists per unique bidder
    name (it checks existing Accounts before creating stubs). So each row
    returned by start() here is a distinct bidder - no in-batch deduping
    is needed in this class.
  - Because we UPDATE the same Account record (never insert a new one),
    re-running this batch can never create duplicate Accounts.

GOVERNOR LIMIT DESIGN:
  - Batch SCOPE SIZE = 10 (set by ProbableBidderBatch.finish()). This means
    execute() makes at most 10 callouts per transaction - well under the
    100-callout-per-transaction limit.
  - All Account updates happen via ONE bulk DML statement per chunk, never
    per-record.
================================================================================
*/
public class ContactDetailsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    private static final String NAMED_CREDENTIAL = 'callout:tender247_Tender';

    // -----------------------------------------------------------------
    // START: get every stub Account still waiting for contact details
    // -----------------------------------------------------------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('[ContactDetailsBatch] START - querying stub Accounts awaiting contact details');
        return Database.getQueryLocator([
            SELECT Id, Name, Bidder_Unique_Key__c
            FROM Account
            WHERE Contact_Fetched__c = false
        ]);
    }

    // -----------------------------------------------------------------
    // EXECUTE: runs once per chunk of stub Accounts (scope size = 10)
    // -----------------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<sObject> scope) {

        List<Account> accountsToUpdate = new List<Account>();

        /*for (sObject s : scope) {
            Account stub = (Account) s;
            String bidderName = stub.Bidder_Unique_Key__c;

            System.debug('=====================================================');
            System.debug('[ContactDetailsBatch] Fetching contact details for bidder: ' + bidderName);

            TenderWrappers.ContactDetailData contact = callContactDetailsApi(bidderName);

            Account updated = new Account(Id = stub.Id);
            updated.Contact_Fetched__c = true; // mark processed regardless of outcome

            if (contact != null) {
                populateContactFields(updated, contact, bidderName);
            } else {
                System.debug('[ContactDetailsBatch] No contact details available for: ' + bidderName);
            }

            accountsToUpdate.add(updated);
        }

        // ---- Bulk update: ONE DML statement for this entire chunk ----
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            System.debug('[ContactDetailsBatch] Updated ' + accountsToUpdate.size() + ' Account(s) this chunk.');
        }

        IntegrationLogger.flush();*/
    }

    // -----------------------------------------------------------------
    // FINISH: pipeline fully complete for this run (8am or 3pm)
    // -----------------------------------------------------------------
    public void finish(Database.BatchableContext bc) {
        System.debug('[ContactDetailsBatch] FINISH - Stage 3 complete. Full daily pipeline finished.');
    }

    // ===================================================================
    // PRIVATE HELPERS
    // ===================================================================
    /*private TenderWrappers.ContactDetailData callContactDetailsApi(String bidderName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/Utkarsh/api/probable-bidders-contact-details');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> payload = new Map<String, Object>{
            'ProbableBidderName' => bidderName
        };
        String body = JSON.serialize(payload);
        req.setBody(body);

        System.debug('[ContactDetailsBatch] CONTACT DETAILS API Request: ' + body);

        Integer statusCode;
        String responseBody;
        Boolean success = false;
        TenderWrappers.ContactDetailData contact = null;

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();

            System.debug('[ContactDetailsBatch] Status: ' + statusCode + ' for bidder: ' + bidderName);

            if (statusCode == 200) {
                TenderWrappers.ContactDetailsResponse parsed =
                    (TenderWrappers.ContactDetailsResponse) JSON.deserialize(
                        responseBody, TenderWrappers.ContactDetailsResponse.class
                    );
                if (parsed.Success && parsed.Data != null && !parsed.Data.isEmpty()) {
                    contact = parsed.Data[0];
                } else {
                    // "No contact detail found." is a valid, successful response - just no data.
                    System.debug('[ContactDetailsBatch] No contact detail found for: ' + bidderName);
                }
                success = true;
            }
        } catch (Exception e) {
            responseBody = 'EXCEPTION: ' + e.getMessage();
            System.debug('[ContactDetailsBatch] EXCEPTION: ' + e.getMessage());
        }

        IntegrationLogger.log('ContactDetails', null,
            'probable-bidders-contact-details', body, responseBody, statusCode, success,
            success ? null : responseBody);

        return contact;
    }

    private void populateContactFields(Account acc, TenderWrappers.ContactDetailData contact, String bidderName) {
        // Only overwrite Name if the API gave us one; otherwise keep the stub's name
        if (String.isNotBlank(contact.bidder_name)) {
            acc.Name = contact.bidder_name;
        }
        acc.Phone                = contact.contact_number;
        acc.Email__c             = contact.email_id;
        acc.PAN_Number__c        = contact.pan_no;
        acc.Vendor_Code__c       = contact.vendorcode;
        acc.Seller_Id__c         = contact.seller_id;
        acc.GEM_Id__c            = contact.gem_id;
        acc.MSME_Number__c       = contact.msme_number;
        acc.Bidder_Category__c   = contact.category;
        acc.Branch_Name__c       = contact.branch_name;
        acc.BillingStreet        = contact.address;
        acc.BillingPostalCode    = contact.pincode;
        acc.GST_Number__c        = contact.gst_number;
        acc.Alternate_Email__c   = contact.alternate_email_id;
        acc.Designation__c       = contact.designation;
    }*/
}