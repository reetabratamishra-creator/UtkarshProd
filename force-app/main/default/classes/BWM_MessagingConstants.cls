/**
 * @description   Shared constants for messaging channels, trigger points, stages, and
 *                status values.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_MessagingConstants {
  public static final String NAMED_CREDENTIAL = 'callout:Blue_Waves_Messaging';
  public static final String CHANNEL_JOURNEY = 'Journey';
  public static final String CHANNEL_WHATSAPP = 'WhatsApp';
  public static final String CHANNEL_RCS = 'RCSMessage';
  public static final String CHANNEL_SMS = 'SMS';
  public static final String TRIGGER_LEAD_CREATE = 'Lead_Create';
  public static final String DEPT_MODE_ANY_PRODUCT = 'ANY_PRODUCT';
  public static final String DEPT_MODE_ENQUIRY_ONLY = 'ENQUIRY_ONLY';
  public static final String DEPT_MODE_SPECIFIC = 'SPECIFIC';
  public static final String DEPT_MODE_LIST = 'LIST';
  public static final String DEPT_ENQUIRY = 'Enquiry';
  public static final String STAGE_PROSPECT = 'Prospect';
  public static final String STAGE_PROSPECTING = 'Prospecting';
  public static final String STAGE_NURTURE = 'Nurture';
  public static final String STAGE_CLOSED_LOST = 'Closed Lost';
  public static final String STAGE_NEGOTIATION = 'Negotiation';
  public static final String STAGE_CLOSED_WON = 'Closed Won';
  public static final String STAGE_LOST = 'Lost';
  public static final String WHATSAPP_HEADER_DOCUMENT = 'DOCUMENT';
  public static final String WHATSAPP_HEADER_TEXT = 'TEXT';
  public static final String BROCHURE_PORTAL_HOST = 'portal.bluewavesmedia.in';
  public static final String DEFAULT_PORTAL_BROCHURE_URL =
    'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/corporate_brochure_2026(13).pdf';
  public static final String CORPORATE_BROCHURE_URL =
    'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/corporate_brochure_2026(13).pdf';
  public static final String CORPORATE_BROCHURE_URL_GEN =
    'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/corporate_brochure_2026.pdf';
  public static final String SUB_STAGE_ACTIVE = 'Active';
  public static final String SUB_STAGE_BUDGETARY = 'Budgetary';
  public static final String LOST_REASON_DETAILS_NOT_RECEIVED = 'Customer Details Not Received';
  public static final String OPP_LOST_NOT_RESPONDING = 'Not responding';
  public static final String OBJECT_TYPE_LEAD = 'Lead';
  public static final String OBJECT_TYPE_OPPORTUNITY = 'Opportunity';
  public static final String OBJECT_TYPE_ACCOUNT = 'Account';
  public static final String OBJECT_TYPE_CONTACT = 'Contact';
  public static final String OBJECT_TYPE_OFFLINE_CAMPAIGN = 'Offline_Campaign__c';
  public static final String RECIPIENT_CUSTOMER = 'Customer';
  public static final String RECIPIENT_DEALER = 'Dealer';
  public static final String RECIPIENT_OWNER = 'Owner';
  public static final String FIELD_OPPORTUNITY_LINK = 'OPPORTUNITY_LINK';
  public static final String CUSTOMER_JOURNEY_REFER_DEALER = 'Refer to Dealer';
  public static final String CUSTOMER_JOURNEY_DIRECT = 'Direct Business';
  public static final String OPP_SOURCE_INBOUND_EMAIL = 'INBOUND EMAIL';
  public static final String OPP_SOURCE_OUTBOUND_PHONE = 'OUTBOUND PHONE CALL';
  public static final String OPP_SOURCE_INBOUND_PHONE = 'INBOUND PHONE CALL';
  public static final String LOG_STATUS_SENT = 'Sent';
  public static final String LOG_STATUS_FAILED = 'Failed';
  public static final String LOG_STATUS_SKIPPED = 'Skipped';
  public static final String LOG_CHANNEL_JOURNEY = 'Journey';
  public static final String LOG_CHANNEL_WHATSAPP = 'WhatsApp';
  public static final String LOG_CHANNEL_RCS = 'RCS';
  public static final String LOG_CHANNEL_SMS = 'SMS';
  public static final String FALLBACK_CONTACT_EMAIL = 'customersupport@utkarshindia.in';
  public static final String FIELD_WHATSAPP_PRODUCT_BRIEF = 'WHATSAPP_PRODUCT_BRIEF';
  public static final String FIELD_EMPTY = 'EMPTY';
  public static final String FIELD_CORPORATE_SUPPORT_PHONE_1 = 'CORPORATE_SUPPORT_PHONE_1';
  public static final String FIELD_CORPORATE_SUPPORT_PHONE_2 = 'CORPORATE_SUPPORT_PHONE_2';
  public static final String FIELD_CORPORATE_SUPPORT_NAME_1 = 'CORPORATE_SUPPORT_NAME_1';
  public static final String FIELD_CORPORATE_SUPPORT_NAME_2 = 'CORPORATE_SUPPORT_NAME_2';
  public static final String FIELD_CORPORATE_SUPPORT_EMAIL_1 = 'CORPORATE_SUPPORT_EMAIL_1';
  public static final String FIELD_CORPORATE_SUPPORT_EMAIL_2 = 'CORPORATE_SUPPORT_EMAIL_2';
  public static final String CORPORATE_SUPPORT_NAME_1_DEFAULT = 'Rudra Narayan Chakraborty';
  public static final String CORPORATE_SUPPORT_NAME_2_DEFAULT = 'Bhagyashree Raysingh';
  public static final String FIELD_CRM_USER_NAME = 'CRM_User_Name_Formula__c';
  public static final String FIELD_CRM_USER_PHONE = 'CRM_User_Contact_No_Formula__c';
  public static final String FIELD_CRM_USER_EMAIL = 'CRM_User_Email_Formula__c';
  public static final String FIELD_LOCATION = 'LOCATION';
  public static final String BROCHURE_ATTACH_NONE = 'None';
  public static final String BROCHURE_ATTACH_CORPORATE = 'Corporate';
  public static final String BROCHURE_ATTACH_DEPARTMENT = 'Department';

  public static final String TRIGGER_LEAD_TASK_CALLBACK_PROSPECT = 'Lead_Task_Callback_Prospect';
  public static final String TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT = 'Lead_Task_Lost_DetailsNotReceived_Prospect';
  public static final String TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING = 'Lead_Task_Callback_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING = 'Lead_Task_Lost_DetailsNotReceived_Prospecting';
  public static final String TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING = 'Lead_Task_Lost_NotResponding_Prospecting';
  public static final String TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING =
    'Lead_Details_Not_Received_Prospecting';
  public static final String TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE =
    'Opportunity_Details_Not_Received_Nurture';
  public static final String TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE = 'Opportunity_Task_Callback_Nurture';
  public static final String TRIGGER_OPPORTUNITY_QUALIFY_NURTURE = 'Opportunity_Qualify_Nurture';
  public static final String TRIGGER_OPP_LOST_DETAILS_NURTURE = 'Opportunity_Lost_DetailsNotReceived_Nurture';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE = 'Opportunity_Lost_NotResponding_Nurture';
  public static final String TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION =
    'Opportunity_Lost_NotResponding_Negotiation';
  public static final String TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS = 'Opportunity_Negotiation_Stale_30_Days';
  public static final String TRIGGER_OPPORTUNITY_REFER_TO_DEALER = 'Opportunity_Refer_To_Dealer';
  public static final String TRIGGER_OPP_CLOSED_WON_REFER_DEALER =
    'Opportunity_ClosedWon_ReferDealer';
  public static final String TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS =
    'Opportunity_ClosedWon_DirectBusiness';
  public static final String TRIGGER_OPPORTUNITY_DEALER_ENQUIRY = 'Opportunity_Dealer_Enquiry';
  public static final String TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER = 'Opportunity_Quote_Expiry_Reminder';
  public static final String TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER =
    'Opportunity_Send_Quote_To_Customer';
  public static final String TRIGGER_LEAD_CAMPAIGN = 'Lead_Campaign';
  public static final String TRIGGER_OPPORTUNITY_CAMPAIGN = 'Opportunity_Campaign';
  public static final String TRIGGER_ACCOUNT_CAMPAIGN = 'Account_Campaign';
  public static final String TRIGGER_CONTACT_CAMPAIGN = 'Contact_Campaign';
  public static final String TRIGGER_OFFLINE_CAMPAIGN = 'Offline_Campaign';
  public static final String CAMPAIGN_OWNER_CRM_MATCH_PHONE = '+91 33 4190 0001';
  public static final String CAMPAIGN_OWNER_CRM_MATCH_EMAIL = 'info@utkarshindia.in';
  public static final String JOURNEY_PROSPECT_ENQ_DEPT = 'prospect_enq_dept';

  /** Product / department-wise WhatsApp journeys (_dept). */
  public static final Set<String> PRODUCT_DEPARTMENTS = new Set<String>{
    'High Mast & Polygonal',
    'Crash Barrier',
    'Steel Pipes',
    'Polymer',
    'HDPE',
    'Solar Structure',
    'Steel Tubular Poles'
  };

  /** Tower / structure departments used by general (_gen) journeys (+ Enquiry). */
  public static final Set<String> GEN_TOWER_DEPARTMENTS = new Set<String>{
    DEPT_ENQUIRY,
    'Transmission & Telecom Tower',
    'Pre Engineering Building',
    'Railway Electrification Structure'
  };

  /** Enquiry + tower departments for Prospect gen auto-connect. */
  public static final Set<String> GEN_ENQUIRY_TOWER_DEPARTMENTS = new Set<String>{
    DEPT_ENQUIRY,
    'Transmission & Telecom Tower',
    'Pre Engineering Building',
    'Railway Electrification Structure'
  };

  public static final String GEN_ENQUIRY_TOWER_DEPARTMENTS_CSV =
    'Enquiry,Transmission & Telecom Tower,Pre Engineering Building,Railway Electrification Structure';

  public static final String GEN_TOWER_DEPARTMENTS_CSV =
    'Enquiry,Transmission & Telecom Tower,Pre Engineering Building,Railway Electrification Structure';

  public static final Set<String> PHONE_OPPORTUNITY_SOURCES = new Set<String>{
    OPP_SOURCE_OUTBOUND_PHONE,
    OPP_SOURCE_INBOUND_PHONE
  };

  public static final Set<String> OPP_LOST_DETAILS_NOT_RECEIVED = new Set<String>{
    'Customer details not received',
    LOST_REASON_DETAILS_NOT_RECEIVED
  };

  public static final Set<String> LEAD_LOST_NOT_RESPONDING = new Set<String>{
    OPP_LOST_NOT_RESPONDING,
    'Not Responding'
  };
}