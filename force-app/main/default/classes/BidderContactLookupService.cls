/*
================================================================================
CLASS: BidderContactLookupService
--------------------------------------------------------------------------------
SCENARIO / OWNER: Ayantika

Backs the "Fetch Contact" button on the Bidders__c record detail page
(PART 4 of the requirement doc).

fetchContactDetails(bidderId):
  - Pulls the Bidder's stored name directly from the record (no chained
    Endpoint 3 call needed).
  - Calls Endpoint 4 (Probable Bidder Contact Details) with that name.
  - REPLACE LOGIC: deletes any existing Bidders_Contact_Details__c record(s)
    already linked to this Bidder, then inserts the fresh result - so
    re-clicking the button never appends/duplicates, it always replaces.

runForBidderName(...) is kept as-is for manual Execute Anonymous use
(unrelated to the button, e.g. ad-hoc lookups by name).
================================================================================
*/
/*public class BidderContactLookupService {

    private static final String TENDER_NAMED_CREDENTIAL = 'callout:tender247_Tender';

    // Entry point for the "Fetch Contact" button on Bidders__c. Returns a
    // simple status message the LWC can show as a toast.
    @AuraEnabled
    public static String fetchContactDetails(Id bidderId) {
        try{
        List<Bidders__c> bidders = [
            SELECT Id, Bidder_Name__c, Tender__c, External_Tender_Id__c, OwnerId
            FROM Bidders__c
            WHERE Id = :bidderId
            LIMIT 1
        ];

        if (bidders.isEmpty()) {
            return 'Bidder record not found for Id: ' + bidderId;
        }

        Bidders__c bidder = bidders[0];

        if (String.isBlank(bidder.Bidder_Name__c)) {
            return 'This Bidder record has no name stored - cannot fetch contact details.';
        }

        ResultWrappers.ContactDetailData contact = callContactDetailsApi(bidder.Bidder_Name__c);
        if (contact == null) {
            return 'No contact details were returned for "' + bidder.Bidder_Name__c + '".';
        }

        List<Bidders_Contact_Details__c> existing = [
            SELECT Id FROM Bidders_Contact_Details__c
            WHERE Bidders__c = :bidderId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }

        Bidders_Contact_Details__c c = new Bidders_Contact_Details__c();
        c.Bidders__c            = bidder.Id;
        c.Tender__c             = bidder.Tender__c;
        c.Source_Tender_Id__c   = bidder.External_Tender_Id__c;
        c.Contact_Unique_Key__c = bidder.External_Tender_Id__c + '-' + bidder.Bidder_Name__c;
        if (bidder.OwnerId != null) { c.OwnerId = bidder.OwnerId; }

        c.Name                  = contact.bidder_name;
        c.Contact_Number__c     = contact.contact_number;
        c.Email__c              = contact.email_id;
        c.PAN_No__c             = contact.pan_no;
        c.Vendorcode__c         = contact.vendorcode;
        c.Seller_Id__c          = contact.seller_id;
        c.Gem_Id__c             = contact.gem_id;
        c.Msme_Number__c        = contact.msme_number;
        c.Category__c           = contact.category;
        c.Branch_Name__c        = contact.branch_name;
        c.Address__c            = contact.address;
        c.Pincode__c            = contact.pincode;
        c.Gst_Number__c         = contact.gst_number;
        c.Alternate_Phone__c    = contact.phone_number;
        c.Alternate_Email__c    = contact.alternate_email_id;
        c.Designation__c        = contact.designation;

        insert c;

        return 'Contact details fetched and saved for "' + bidder.Bidder_Name__c + '".';
        } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        throw new AuraHandledException('Fetch Contact Details failed: ' + e.getMessage());
    }
    }

    // Shared callout logic used by both fetchContactDetails() and runForBidderName().
    private static ResultWrappers.ContactDetailData callContactDetailsApi(String bidderName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TENDER_NAMED_CREDENTIAL + '/Utkarsh/api/probable-bidders-contact-details');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> payload = new Map<String, Object>{ 'ProbableBidderName' => bidderName };
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

        IntegrationLogger.log('ProbableBidderContact', 'Manual', 'probable-bidders-contact-details',
            body, responseBody, statusCode, success, success ? null : responseBody);
        IntegrationLogger.flush();

        return contact;
    }

    // Manual Execute Anonymous entry point - unrelated to the button, kept
    // for ad-hoc lookups by name (optionally linked to a tender).
    public static void runForBidderName(String bidderName) {
        runForBidderName(bidderName, null);
    }

    public static void runForBidderName(String bidderName, String tenderIdStr) {
        if (String.isBlank(bidderName)) {
            System.debug('[BidderContactLookupService] bidderName is required.');
            return;
        }

        ResultWrappers.ContactDetailData contact = callContactDetailsApi(bidderName);
        if (contact == null) {
            System.debug('[BidderContactLookupService] No contact details returned for: ' + bidderName);
            return;
        }

        Bidders_Contact_Details__c c = new Bidders_Contact_Details__c();

        if (String.isNotBlank(tenderIdStr)) {
    String key = tenderIdStr + '-' + bidderName;

    List<Bidders__c> matches = [
        SELECT Id, Tender__c, OwnerId
        FROM Bidders__c
        WHERE Bidder_Unique_Key__c = :key
        LIMIT 1
    ];

    if (!matches.isEmpty()) {
        c.Bidders__c = matches[0].Id;
        c.Tender__c = matches[0].Tender__c;

        if (matches[0].OwnerId != null) {
            c.OwnerId = matches[0].OwnerId;
        }
    }

    c.Contact_Unique_Key__c = key;
    c.Source_Tender_Id__c = tenderIdStr;
}

        c.Name                  = contact.bidder_name;
        c.Contact_Number__c     = contact.contact_number;
        c.Email__c              = contact.email_id;
        c.PAN_No__c             = contact.pan_no;
        c.Vendorcode__c         = contact.vendorcode;
        c.Seller_Id__c          = contact.seller_id;
        c.Gem_Id__c             = contact.gem_id;
        c.Msme_Number__c        = contact.msme_number;
        c.Category__c           = contact.category;
        c.Branch_Name__c        = contact.branch_name;
        c.Address__c            = contact.address;
        c.Pincode__c            = contact.pincode;
        c.Gst_Number__c         = contact.gst_number;
        c.Alternate_Phone__c    = contact.phone_number;
        c.Alternate_Email__c    = contact.alternate_email_id;
        c.Designation__c        = contact.designation;

        insert c;
        System.debug('[BidderContactLookupService] Stored contact details for: ' + bidderName);
    }

}*/
/*
================================================================================
CLASS: BidderContactLookupService
--------------------------------------------------------------------------------
SCENARIO / OWNER: Ayantika

Backs the "Fetch Contact" button on the Bidders__c record detail page
(PART 4 of the requirement doc).

fetchContactDetails(bidderId):
  - Pulls the Bidder's stored name directly from the record (no chained
    Endpoint 3 call needed).
  - Calls Endpoint 4 (Probable Bidder Contact Details) with that name.
  - REPLACE LOGIC: deletes any existing Bidders_Contact_Details__c record(s)
    already linked to this Bidder, then inserts the fresh result - so
    re-clicking the button never appends/duplicates, it always replaces.

runForBidderName(...) is kept as-is for manual Execute Anonymous use
(unrelated to the button, e.g. ad-hoc lookups by name).

NOTE: DML on Bidders_Contact_Details__c is run in SYSTEM_MODE (via
Database.insert/delete with AccessLevel.SYSTEM_MODE) because this service
must work regardless of the running user's object/field permissions on
that object. If you'd rather fix this via permissions instead of code,
grant Create/Delete on Bidders_Contact_Details__c (and Edit/Read on its
fields) to the relevant Permission Set instead of relying on this.
================================================================================
*/
public class BidderContactLookupService {

    private static final String TENDER_NAMED_CREDENTIAL = 'callout:tender247_Tender';

    // Entry point for the "Fetch Contact" button on Bidders__c. Returns a
    // simple status message the LWC can show as a toast.
    @AuraEnabled
    public static String fetchContactDetails(Id bidderId) {
        try{
        List<Bidders__c> bidders = [
            SELECT Id, Bidder_Name__c, Tender__c, External_Tender_Id__c, OwnerId
            FROM Bidders__c
            WHERE Id = :bidderId
            LIMIT 1
        ];

        if (bidders.isEmpty()) {
            return 'Bidder record not found for Id: ' + bidderId;
        }

        Bidders__c bidder = bidders[0];

        if (String.isBlank(bidder.Bidder_Name__c)) {
            return 'This Bidder record has no name stored - cannot fetch contact details.';
        }

        ResultWrappers.ContactDetailData contact = callContactDetailsApi(bidder.Bidder_Name__c);
        if (contact == null) {
            return 'No contact details were returned for "' + bidder.Bidder_Name__c + '".';
        }

        List<Bidders_Contact_Details__c> existing = [
            SELECT Id FROM Bidders_Contact_Details__c
            WHERE Bidders__c = :bidderId
        ];
        if (!existing.isEmpty()) {
            Database.delete(existing, System.AccessLevel.SYSTEM_MODE);
        }

        Bidders_Contact_Details__c c = new Bidders_Contact_Details__c();
        c.Bidders__c            = bidder.Id;
        c.Tender__c             = bidder.Tender__c;
        c.Source_Tender_Id__c   = bidder.External_Tender_Id__c;
        c.Contact_Unique_Key__c = bidder.External_Tender_Id__c + '-' + bidder.Bidder_Name__c;
        if (bidder.OwnerId != null) { c.OwnerId = bidder.OwnerId; }

        c.Name                  = contact.bidder_name;
        c.Contact_Number__c     = contact.contact_number;
        c.Email__c              = contact.email_id;
        c.PAN_No__c             = contact.pan_no;
        c.Vendorcode__c         = contact.vendorcode;
        c.Seller_Id__c          = contact.seller_id;
        c.Gem_Id__c             = contact.gem_id;
        c.Msme_Number__c        = contact.msme_number;
        c.Category__c           = contact.category;
        c.Branch_Name__c        = contact.branch_name;
        c.Address__c            = contact.address;
        c.Pincode__c            = contact.pincode;
        c.Gst_Number__c         = contact.gst_number;
        c.Alternate_Phone__c    = contact.phone_number;
        c.Alternate_Email__c    = contact.alternate_email_id;
        c.Designation__c        = contact.designation;

        Database.insert(c, System.AccessLevel.SYSTEM_MODE);

        return 'Contact details fetched and saved for "' + bidder.Bidder_Name__c + '".';
        } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        throw new AuraHandledException('Fetch Contact Details failed: ' + e.getMessage());
    }
    }

    // Shared callout logic used by both fetchContactDetails() and runForBidderName().
    private static ResultWrappers.ContactDetailData callContactDetailsApi(String bidderName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TENDER_NAMED_CREDENTIAL + '/Utkarsh/api/probable-bidders-contact-details');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> payload = new Map<String, Object>{ 'ProbableBidderName' => bidderName };
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

        IntegrationLogger.log('ProbableBidderContact', 'Manual', 'probable-bidders-contact-details',
            body, responseBody, statusCode, success, success ? null : responseBody);
        IntegrationLogger.flush();

        return contact;
    }

    // Manual Execute Anonymous entry point - unrelated to the button, kept
    // for ad-hoc lookups by name (optionally linked to a tender).
    public static void runForBidderName(String bidderName) {
        runForBidderName(bidderName, null);
    }

    public static void runForBidderName(String bidderName, String tenderIdStr) {
        if (String.isBlank(bidderName)) {
            System.debug('[BidderContactLookupService] bidderName is required.');
            return;
        }

        ResultWrappers.ContactDetailData contact = callContactDetailsApi(bidderName);
        if (contact == null) {
            System.debug('[BidderContactLookupService] No contact details returned for: ' + bidderName);
            return;
        }

        Bidders_Contact_Details__c c = new Bidders_Contact_Details__c();

        if (String.isNotBlank(tenderIdStr)) {
            String key = tenderIdStr + '-' + bidderName;

            List<Bidders__c> matches = [
                SELECT Id, Tender__c, OwnerId
                FROM Bidders__c
                WHERE Bidder_Unique_Key__c = :key
                LIMIT 1
            ];

            if (!matches.isEmpty()) {
                c.Bidders__c = matches[0].Id;
                c.Tender__c = matches[0].Tender__c;

                if (matches[0].OwnerId != null) {
                    c.OwnerId = matches[0].OwnerId;
                }
            }

            c.Contact_Unique_Key__c = key;
            c.Source_Tender_Id__c = tenderIdStr;
        }

        c.Name                  = contact.bidder_name;
        c.Contact_Number__c     = contact.contact_number;
        c.Email__c              = contact.email_id;
        c.PAN_No__c             = contact.pan_no;
        c.Vendorcode__c         = contact.vendorcode;
        c.Seller_Id__c          = contact.seller_id;
        c.Gem_Id__c             = contact.gem_id;
        c.Msme_Number__c        = contact.msme_number;
        c.Category__c           = contact.category;
        c.Branch_Name__c        = contact.branch_name;
        c.Address__c            = contact.address;
        c.Pincode__c            = contact.pincode;
        c.Gst_Number__c         = contact.gst_number;
        c.Alternate_Phone__c    = contact.phone_number;
        c.Alternate_Email__c    = contact.alternate_email_id;
        c.Designation__c        = contact.designation;

        Database.insert(c, System.AccessLevel.SYSTEM_MODE);
        System.debug('[BidderContactLookupService] Stored contact details for: ' + bidderName);
    }
}