/*
================================================================================
CLASS: ResultWrappers
--------------------------------------------------------------------------------
Typed wrappers for the Result API (result-listing-data-count, result-listing-data).
Fully separate from TenderWrappers since Result and Tender APIs use different
product name lists and response shapes.
resultstage (NEW field per Tender247 update): 1=Technical, 2=Financial, 3=AOC
================================================================================
*/
public class ResultWrappers {

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

    public class ListingResponse {
        public Boolean Success;
        public String Message;
        public Integer TotalRecord;
        public List<ResultRecord> Data;
        public Integer StatusCode;
    }

    public class ResultRecord {
        public Long bidawardid;
        public String sourcebidawardid;
        public String postingdate;
        public Decimal value;
        public String datecreated;
        public Long tenderid;
        public String aocdescription;
        public String contractdate;
        public String financialbidevaluationdate;
        public String technicalbidevaluationdate;
        public String aocupdationdate;
        public String organization_name;
        public List<String> category;
    public Integer resultstage;          // <-- ADD THIS: record-level stage (1=Technical, 2=Financial, 3=AOC)

        public List<BidderDetail> bidderdetails;
        public List<ResultLocation> location;
        public List<ResultDocument> documents;
    }

    public class BidderDetail {
        public Long bidderId;
        public String bidderName;
        public Decimal awardedValue;
        public Decimal bidValue;
        public Boolean technical_status;
        public Boolean financial_status;
        public Boolean aoc_status;
        public Boolean winner_bidder;
        public String bidRank;
        public String createddate;
        public Integer resultstage; // NEW: 1=Technical, 2=Financial, 3=AOC
    }

    public class ResultLocation {
        public Long bidawardid;
        public String country;
        public String state;
        public String city;
    }

    public class ResultDocument {
        public Long documentid;
        public String name;
        public String downloadLink;
        public String type;
    }

    // Reused for Contact Details response (same shape as Tender API's contact endpoint)
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