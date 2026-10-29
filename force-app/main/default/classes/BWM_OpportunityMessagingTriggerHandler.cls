/**
 * @description   Opportunity after-insert/update handler that enqueues WhatsApp/RCS/SMS
 *                journey messaging.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_OpportunityMessagingTriggerHandler {
  private static Set<Id> processedInsertIds = new Set<Id>();

  /**
   * @description After-insert Opportunity handler that enqueues nurture, dealer enquiry, and refer-to-dealer messaging when enabled.
   * @param newOpportunities Newly inserted Opportunity records from the trigger context.
   */
  public static void handleAfterInsert(List<Opportunity> newOpportunities) {
    if (newOpportunities == null || newOpportunities.isEmpty()) {
      return;
    }

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      return;
    }

    List<Opportunity> eligible = new List<Opportunity>();
    for (Opportunity opportunityRecord : newOpportunities) {
      if (opportunityRecord == null || opportunityRecord.Id == null) {
        continue;
      }
      if (processedInsertIds.contains(opportunityRecord.Id)) {
        continue;
      }
      processedInsertIds.add(opportunityRecord.Id);
      eligible.add(opportunityRecord);
    }

    if (eligible.isEmpty()) {
      return;
    }

    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();

    for (Opportunity opportunityRecord : eligible) {
      if (opportunityRecord.StageName == BWM_MessagingConstants.STAGE_NURTURE) {
        requests.add(
          new BWM_MessagingRequest(
            opportunityRecord.Id,
            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE
          )
        );
      }

      if (isDealerEnquiryOpportunity(opportunityRecord)) {
        requests.add(
          new BWM_MessagingRequest(
            opportunityRecord.Id,
            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_DEALER_ENQUIRY
          )
        );
      }

      if (
        opportunityRecord.Customer_Journey__c ==
        BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER &&
        isMasterOpportunityRecordType(opportunityRecord.RecordTypeId)
      ) {
        requests.add(
          new BWM_MessagingRequest(
            opportunityRecord.Id,
            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
          )
        );
      }

      addClosedWonRequests(requests, opportunityRecord, null);
    }

    if (!requests.isEmpty()) {
      BWM_MessagingEnqueueService.enqueue(requests);
    }
  }

  /**
   * @description After-update Opportunity handler that enqueues messaging for lost-reason and refer-to-dealer changes when enabled.
   * @param newOpportunities Updated Opportunity records from the trigger context.
   * @param oldMap Prior Opportunity versions keyed by Id.
   */
  public static void handleAfterUpdate(
    List<Opportunity> newOpportunities,
    Map<Id, Opportunity> oldMap
  ) {
    if (newOpportunities == null || newOpportunities.isEmpty()) {
      return;
    }

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      return;
    }

    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();

    for (Opportunity opportunityRecord : newOpportunities) {
      Opportunity oldRecord = oldMap.get(opportunityRecord.Id);
      if (oldRecord == null) {
        continue;
      }

      if (opportunityRecord.Lost_Reason__c != oldRecord.Lost_Reason__c) {
        String lostTrigger = BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
          opportunityRecord.StageName,
          oldRecord.StageName,
          opportunityRecord.Lost_Reason__c
        );
        if (String.isNotBlank(lostTrigger)) {
          requests.add(new BWM_MessagingRequest(opportunityRecord.Id, lostTrigger));
        }
      }

      if (
        opportunityRecord.Customer_Journey__c != oldRecord.Customer_Journey__c &&
        opportunityRecord.Customer_Journey__c ==
        BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER &&
        isMasterOpportunityRecordType(opportunityRecord.RecordTypeId)
      ) {
        requests.add(
          new BWM_MessagingRequest(
            opportunityRecord.Id,
            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
          )
        );
      }

      addClosedWonRequests(requests, opportunityRecord, oldRecord);
    }

    if (!requests.isEmpty()) {
      BWM_MessagingEnqueueService.enqueue(requests);
    }
  }

  /**
   * @description Adds a Closed Won thank-you journey when stage newly becomes Closed Won
   *              and Customer Journey is Refer to Dealer or Direct Business.
   * @param requests Mutable list of messaging requests to append to.
   * @param opportunityRecord Updated Opportunity record.
   * @param oldRecord Prior Opportunity version before the update, or null on insert.
   */
  private static void addClosedWonRequests(
    List<BWM_MessagingRequest> requests,
    Opportunity opportunityRecord,
    Opportunity oldRecord
  ) {
    if (oldRecord != null) {
      if (
        opportunityRecord.StageName != BWM_MessagingConstants.STAGE_CLOSED_WON ||
        oldRecord.StageName == BWM_MessagingConstants.STAGE_CLOSED_WON
      ) {
        return;
      }
    } else if (opportunityRecord.StageName != BWM_MessagingConstants.STAGE_CLOSED_WON) {
      return;
    }

    if (
      opportunityRecord.Customer_Journey__c ==
      BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER
    ) {
      requests.add(
        new BWM_MessagingRequest(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPP_CLOSED_WON_REFER_DEALER
        )
      );
      return;
    }

    if (
      opportunityRecord.Customer_Journey__c ==
      BWM_MessagingConstants.CUSTOMER_JOURNEY_DIRECT
    ) {
      requests.add(
        new BWM_MessagingRequest(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS
        )
      );
    }
  }

  /**
   * @description Returns true when the Opportunity qualifies as a dealer enquiry through existing department and source criteria.
   * @param opportunityRecord Opportunity to evaluate.
   * @return True if dealer-enquiry messaging should fire; otherwise false.
   */
  @TestVisible
  private static Boolean isDealerEnquiryOpportunity(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    if (
      opportunityRecord.Department_Name__c != BWM_MessagingConstants.DEPT_ENQUIRY &&
      !BWM_MessagingConstants.GEN_TOWER_DEPARTMENTS.contains(
        opportunityRecord.Department_Name__c
      )
    ) {
      return false;
    }

    return BWM_MessagingConstants.PHONE_OPPORTUNITY_SOURCES.contains(
        opportunityRecord.LeadSource
      ) ||
      opportunityRecord.LeadSource ==
      BWM_MessagingConstants.OPP_SOURCE_INBOUND_EMAIL;
  }

  @TestVisible
  private static Boolean isMasterOpportunityRecordType(Id recordTypeId) {
    if (recordTypeId == null) {
      return false;
    }

    Schema.RecordTypeInfo recordTypeInfo =
      Schema.SObjectType.Opportunity.getRecordTypeInfosById().get(recordTypeId);
    return recordTypeInfo != null &&
      recordTypeInfo.getDeveloperName() == 'Master_Opportunity';
  }
}