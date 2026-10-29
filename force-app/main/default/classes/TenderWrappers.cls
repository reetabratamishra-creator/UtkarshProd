/*
Owner - Ayantika
CLASS: TenderWrappers

Defines wrapper classes to store and handle API response data.
CountResponse handles the response from the Tender Listing Data Count API (Endpoint 1).
ListingResponse handles the Tender Listing Data API (Endpoint 2) and Probable Bidders API (Endpoint 3).
TenderRecord stores the main tender information like tender ID, value, deadline, authority, location, documents, and probable bidders.
LocationInfo stores the tender's country, state, and city.
DocumentInfo stores tender document details like document ID, name, download link, and type.
ContactDetailsResponse handles the response from the Probable Bidder Contact Details API (Endpoint 4).
ContactDetailData stores bidder contact information like name, phone, email, PAN, GST, address, and vendor details.
Overall, this class converts API JSON responses into Apex objects so the integration code can easily use the data.
================================================================================
*/
public class TenderWrappers {
    
    // ---------------------------------------------------------------------
    // Used by: Tender Listing Data Count API (Endpoint 1)
    // ---------------------------------------------------------------------
    public class CountResponse {
        public Boolean Success;
        public String Message;
        public Integer TotalRecord;
        public List<CountData> Data;
        public Integer StatusCode;
    }
    public class CountData {
        public Integer count;
    }
    
    // ---------------------------------------------------------------------
    // Used by: Tender Listing Data API (Endpoint 2) AND
    //          Probable Bidders TenderId Wise API (Endpoint 3)
    // (Endpoint 3 returns the same tender fields + an extra probable_bidder list)
    // ---------------------------------------------------------------------
    public class ListingResponse {
        public Boolean Success;
        public String Message;
        public Integer TotalRecord;
        public List<TenderRecord> Data;
        public Integer StatusCode;
    }
    
    public class TenderRecord {
        public Long tenderid;
        public String sourcetenderid;
        public Decimal value;
        public String biddeadline;
        public Decimal emd;
        public Decimal documentcost;
        public String authority;
        public String currencyCode;
        public String tenderdetails;
        public String tenderdescription;
        public String prebidmeetingdate;
        public String datecreated;
        public String corrigenduminfo;
        public List<String> sector;
        public String sourceurl;
        public Boolean isupdated;
        public List<String> subindustry;
        public String completionofwork;
        public String ai_summary;
        public List<LocationInfo> location;
        public List<String> probable_bidder; // only present in Endpoint 3 response
        public List<DocumentInfo> documents;
        public String zipdocumentdownload;
    }
    
    public class LocationInfo {
        public Long tenderid;
        public String country;
        public String state;
        public String city;
    }
    
    public class DocumentInfo {
        public Long documentid;
        public String name;
        public String downloadLink;
        public String type;
    }
    
    // ---------------------------------------------------------------------
    // Used by: Probable Bidder Contact Details API (Endpoint 4)
    // ---------------------------------------------------------------------
    public class ContactDetailsResponse {
        public Boolean Success;
        public String Message;
        public Integer TotalRecord;
        public List<ContactDetailData> Data;
        public Integer StatusCode;
    }
    public class ContactDetailData {
        public String bidder_name;
        public String contact_number;
        public String email_id;
        public String pan_no;
        public String vendorcode;
        public String seller_id;
        public String gem_id;
        public String msme_number;
        public String category;
        public String branch_name;
        public String address;
        public String pincode;
        public String gst_number;
        public String phone_number;
        public String alternate_email_id;
        public String designation;
    }
}