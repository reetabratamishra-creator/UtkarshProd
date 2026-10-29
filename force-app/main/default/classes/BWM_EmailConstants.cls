/**
 * @description   Shared constants for email named credentials, statuses, and trigger
 *                points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_EmailConstants {
  public static final String NAMED_CREDENTIAL = 'callout:Infobip_Email';
  public static final String SENDER_CENTRAL = 'Central';
  public static final String SENDER_OWNER = 'Owner';
  public static final String RECIPIENT_CUSTOMER = 'Customer';
  public static final String RECIPIENT_DEALER = 'Dealer';
  public static final String RECIPIENT_OWNER = 'Owner';
  public static final String FALLBACK_CONTACT_EMAIL = 'customersupport@utkarshindia.in';
  public static final String OBJECT_LEAD = 'Lead';
  public static final String OBJECT_OPPORTUNITY = 'Opportunity';
  public static final String OBJECT_ACCOUNT = 'Account';
  public static final String LOG_STATUS_SENT = 'Sent';
  public static final String LOG_STATUS_FAILED = 'Failed';
  public static final String LOG_STATUS_SKIPPED = 'Skipped';
  public static final String LOG_STATUS_SCHEDULED = 'Scheduled';
  public static final String SCHEDULE_STATUS_PENDING = 'Pending';
  public static final String SCHEDULE_STATUS_SENT = 'Sent';
  public static final String SCHEDULE_STATUS_CANCELLED = 'Cancelled';
  public static final String SCHEDULE_STATUS_FAILED = 'Failed';
  public static final String DEPT_MODE_ANY_PRODUCT = 'ANY_PRODUCT';
  public static final String DEPT_MODE_ENQUIRY_ONLY = 'ENQUIRY_ONLY';
  public static final String DEPT_MODE_PRODUCT_DEPT = 'PRODUCT_DEPT';
  public static final String DEPT_MODE_GEN_TOWER = 'GEN_TOWER';
  public static final String DEPT_MODE_GEN_ENQUIRY_TOWER = 'GEN_ENQUIRY_TOWER';
  public static final String DEPT_MODE_ALL = 'ALL';
  public static final String DEPT_ENQUIRY = 'Enquiry';
  public static final String STAGE_PROSPECT = 'Prospect';
  public static final String STAGE_PROSPECTING = 'Prospecting';
  public static final String STAGE_NURTURE = 'Nurture';
  public static final String STAGE_CLOSED_LOST = 'Closed Lost';
  public static final String STAGE_NEGOTIATION = 'Negotiation';
  public static final String STAGE_CLOSED_WON = 'Closed Won';
  public static final String CUSTOMER_JOURNEY_DIRECT = 'Direct Business';
  public static final String CUSTOMER_JOURNEY_REFER_DEALER = 'Refer to Dealer';
  public static final String SUB_STAGE_TENDER = 'Tender';
  public static final String SUB_STAGE_ACTIVE = 'Active';
  public static final String SUB_STAGE_BUDGETARY = 'Budgetary';
  public static final String LOST_REASON_DETAILS_NOT_RECEIVED = 'Customer Details Not Received';
  public static final String LOST_GROUP_OPERATIONAL = 'OPERATIONAL';
  public static final String LOST_GROUP_DETAILS_NOT_RECEIVED = 'DETAILS_NOT_RECEIVED';
  public static final String LOST_GROUP_PURCHASED_OTHER_BRAND = 'PURCHASED_OTHER_BRAND';
  public static final String LOST_GROUP_FUTURE_PROSPECT = 'FUTURE_PROSPECT';
  public static final String LOST_GROUP_PRICE_OR_EXISTING = 'PRICE_OR_EXISTING';
  public static final String LOST_GROUP_NOT_RESPONDING = 'NOT_RESPONDING';
  public static final String OPP_LOST_GROUP_NOT_RESPONDING = 'OPP_NOT_RESPONDING';
  public static final String OPP_LOST_GROUP_OPERATIONAL = 'OPP_OPERATIONAL';
  public static final String OPP_LOST_GROUP_DETAILS_NOT_RECEIVED = 'OPP_DETAILS_NOT_RECEIVED';
  public static final String OPP_LOST_GROUP_RATE_OR_PURCHASED = 'OPP_RATE_OR_PURCHASED';
  public static final String OPP_LOST_GROUP_FUTURE_OR_TENDER = 'OPP_FUTURE_OR_TENDER';
  public static final String OPP_LOST_GROUP_PRICE_OR_EXISTING = 'OPP_PRICE_OR_EXISTING';
  public static final String OPP_SOURCE_INBOUND_EMAIL = 'INBOUND EMAIL';
  public static final String OPP_SOURCE_OUTBOUND_PHONE = 'OUTBOUND PHONE CALL';
  public static final String OPP_SOURCE_INBOUND_PHONE = 'INBOUND PHONE CALL';

  public static final String LEAD_SOURCE_EXOTEL = 'Exotel';
  public static final String TRIGGER_LEAD_CREATE = 'Email_Lead_Create';
  public static final String TRIGGER_LEAD_TASK_CALLBACK_PROSPECT = 'Email_Lead_Task_Callback_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT = 'Email_Lead_Task_Lost_DetailsNotReceived_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_OPERATIONAL_PROSPECT = 'Email_Lead_Task_Lost_Operational_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_PURCHASED_PROSPECT = 'Email_Lead_Task_Lost_PurchasedOtherBrand_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECT = 'Email_Lead_Task_Lost_FutureProspect_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_PRICE_PROSPECT = 'Email_Lead_Task_Lost_PriceOrExisting_Prospect';
  public static final String TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING = 'Email_Lead_Task_Callback_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING = 'Email_Lead_Task_Lost_DetailsNotReceived_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED = 'Email_Lead_Task_Lost_DetailsNotReceived_Prospecting_Delayed_24h';
  public static final String TRIGGER_LEAD_TASK_LOST_OPERATIONAL_PROSPECTING = 'Email_Lead_Task_Lost_Operational_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_PURCHASED_PROSPECTING = 'Email_Lead_Task_Lost_PurchasedOtherBrand_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECTING = 'Email_Lead_Task_Lost_FutureProspect_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_PRICE_PROSPECTING = 'Email_Lead_Task_Lost_PriceOrExisting_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING = 'Email_Lead_Task_Lost_NotResponding_Prospecting';
  public static final String TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING =
    'Email_Lead_Details_Not_Received_Prospecting';
  public static final String TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE =
    'Email_Opportunity_Details_Not_Received_Nurture';
  public static final String TRIGGER_OPPORTUNITY_QUALIFY_NURTURE = 'Email_Opportunity_Qualify_Nurture';
  public static final String TRIGGER_OPPORTUNITY_DEALER_ENQUIRY = 'Email_Opportunity_Dealer_Enquiry';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE = 'Email_Opp_Lost_NotResponding_Nurture';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST = 'Email_Opp_Lost_NotResponding_Nurture_Lost';
  public static final String TRIGGER_OPP_LOST_OPERATIONAL_NURTURE = 'Email_Opp_Lost_Operational_Nurture';
  public static final String TRIGGER_OPP_LOST_DETAILS_NURTURE = 'Email_Opp_Lost_DetailsNotReceived_Nurture';
  public static final String TRIGGER_OPP_LOST_DETAILS_NURTURE_DELAYED = 'Email_Opp_Lost_DetailsNotReceived_Nurture_Delayed_48h';
  public static final String TRIGGER_OPP_LOST_RATE_OTHER_NURTURE = 'Email_Opp_Lost_RateOther_Nurture';
  public static final String TRIGGER_OPP_LOST_FUTURE_TENDER_NURTURE = 'Email_Opp_Lost_FutureTender_Nurture';
  public static final String TRIGGER_OPP_LOST_PRICE_NURTURE = 'Email_Opp_Lost_PriceEnquiry_Nurture';
  public static final String TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE = 'Email_Opp_Negotiation_Tender_Update';
  public static final String TRIGGER_OPP_NEGOTIATION_STAGE_UPDATE = 'Email_Opp_Negotiation_Stage_Update';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION = 'Email_Opp_Lost_NotResponding_Negotiation';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION_LOST = 'Email_Opp_Lost_NotResponding_Negotiation_Lost';
  public static final String TRIGGER_OPP_LOST_OPERATIONAL_NEGOTIATION = 'Email_Opp_Lost_Operational_Negotiation';
  public static final String TRIGGER_OPP_LOST_RATE_OTHER_NEGOTIATION = 'Email_Opp_Lost_RateOther_Negotiation';
  public static final String TRIGGER_OPP_LOST_FUTURE_TENDER_NEGOTIATION = 'Email_Opp_Lost_FutureTender_Negotiation';
  public static final String TRIGGER_OPP_LOST_PRICE_NEGOTIATION = 'Email_Opp_Lost_PriceEnquiry_Negotiation';
  public static final String TRIGGER_OPP_CLOSED_WON_REFER_DEALER = 'Email_Opp_ClosedWon_ReferDealer';
  public static final String TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS = 'Email_Opp_ClosedWon_DirectBusiness';
  public static final String TRIGGER_OPPORTUNITY_REFER_TO_DEALER = 'Email_Opportunity_Refer_To_Dealer';
  public static final String TRIGGER_DEALER_MONTHLY_UPDATE = 'Email_Dealer_Monthly_Update';
  public static final String TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS = 'Email_Opportunity_Negotiation_Stale_30_Days';
  public static final String TRIGGER_OPP_TASK_CALLBACK_NEGOTIATION = 'Email_Opp_Task_Callback_Negotiation';
  public static final String TRIGGER_OPP_TASK_CALLBACK_NURTURE = 'Email_Opp_Task_Callback_Nurture';
  public static final String TRIGGER_OPPORTUNITY_DEALER_OFFLINE_CREATE = 'Email_Opportunity_Dealer_Offline_Create';
  public static final String TRIGGER_OPP_QUOTE_EXPIRY_REMINDER = 'Email_Opp_Quote_Expiry_Reminder';

  public static final String BROCHURE_ATTACH_NONE = 'None';
  public static final String BROCHURE_ATTACH_CORPORATE = 'Corporate';
  public static final String BROCHURE_ATTACH_DEPARTMENT = 'Department';
  public static final String BROCHURE_ATTACH_DEALER_MONTHLY = 'DealerMonthlyOpportunityList';
  public static final String DEALER_OPPORTUNITY_RECORD_TYPE = 'Dealer_Opportunity';
  public static final String DEFAULT_CORPORATE_BROCHURE_RESOURCE = 'Corporate_Brochure_2026_pdf';
  public static final String PRODUCT_BRIEF_PLACEHOLDER = '{#product_brief#}';
  public static final String FIELD_PRODUCT_BRIEF = 'PRODUCT_BRIEF';
  public static final String TEMPLATE_DEALER_SALES_ASSIGN = 'Dealer_sales_assign';
  public static final String TEMPLATE_NEGOTIATION_LOST_FUTURE_TENDER_DEPT = 'Negotiation_lost_future_tender_dept';
  public static final String TEMPLATE_NEGOTIATION_LOST_FUTURE_TENDER_GEN = 'Negotiation_lost_future_tender_gen';
  public static final String PRODUCT_BRIEF_MERGE_TOKEN = '{{Product_Brief}}';
  public static final Integer EMAIL_ATTACHMENT_BINARY_LIMIT_BYTES = 3145728;

  // Email PRODUCT_DEPT templates (_dept) — specific product departments only.
  public static final Set<String> PRODUCT_DEPARTMENTS = new Set<String>{
    'High Mast & Polygonal',
    'Crash Barrier',
    'Steel Pipes',
    'Polymer',
    'HDPE',
    'Solar Structure',
    'Steel Tubular Poles'
  };

  // Tower / structure departments used by many _gen templates (+ Enquiry).
  public static final Set<String> GEN_TOWER_DEPARTMENTS = new Set<String>{
    DEPT_ENQUIRY,
    'Transmission & Telecom Tower',
    'Pre Engineering Building',
    'Railway Electrification Structure'
  };

  // Enquiry + tower departments (Prospect_Enq_gen and similar).
  public static final Set<String> GEN_ENQUIRY_TOWER_DEPARTMENTS = new Set<String>{
    DEPT_ENQUIRY,
    'Transmission & Telecom Tower',
    'Pre Engineering Building',
    'Railway Electrification Structure'
  };
  public static final Set<String> PHONE_OPPORTUNITY_SOURCES = new Set<String>{
    OPP_SOURCE_OUTBOUND_PHONE,
    OPP_SOURCE_INBOUND_PHONE
  };

  public static final Map<String, Set<String>> LOST_REASONS_BY_GROUP = new Map<String, Set<String>>{
    LOST_GROUP_OPERATIONAL => new Set<String>{
      'Minimum Quantity Not Met',
      'Out of Service Area',
      'Internal Problem'
    },
    LOST_GROUP_DETAILS_NOT_RECEIVED => new Set<String>{
      LOST_REASON_DETAILS_NOT_RECEIVED,
      'Customer details not received'
    },
    LOST_GROUP_PURCHASED_OTHER_BRAND => new Set<String>{
      'Purchase from Other Brand'
    },
    LOST_GROUP_FUTURE_PROSPECT => new Set<String>{ 'Future Prospect' },
    LOST_GROUP_PRICE_OR_EXISTING => new Set<String>{
      'Price Enquiry',
      'Existing Customer'
    },
    LOST_GROUP_NOT_RESPONDING => new Set<String>{
      'Not Responding',
      'Not responding'
    }
  };

  public static final Map<String, Set<String>> OPP_LOST_REASONS_BY_GROUP = new Map<String, Set<String>>{
    OPP_LOST_GROUP_NOT_RESPONDING => new Set<String>{
      'Not responding',
      'Not Responding'
    },
    OPP_LOST_GROUP_OPERATIONAL => new Set<String>{
      'Min qty not met',
      'Minimum Quantity Not Met',
      'Minimum Quantity not met',
      'Out of service area',
      'Out of Service Area',
      'Internal problem',
      'Internal Problem'
    },
    OPP_LOST_GROUP_DETAILS_NOT_RECEIVED => new Set<String>{
      'Customer details not received',
      'Customer Details Not Received'
    },
    OPP_LOST_GROUP_RATE_OR_PURCHASED => new Set<String>{
      'Rate Issue',
      'Purchased from other brand',
      'Purchased from Other Brands',
      'Purchase from Other Brand'
    },
    OPP_LOST_GROUP_FUTURE_OR_TENDER => new Set<String>{
      'Future Prospect',
      'Tender lost'
    },
    OPP_LOST_GROUP_PRICE_OR_EXISTING => new Set<String>{
      'Price enquiry',
      'Price Enquiry',
      'Price',
      'Existing customer',
      'Existing Customer'
    }
  };
}