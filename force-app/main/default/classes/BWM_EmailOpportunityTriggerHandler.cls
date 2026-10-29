/**
 * @description   Opportunity after-insert/update handler that enqueues auto email
 *                sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailOpportunityTriggerHandler {
  private static Set<Id> processedInsertIds = new Set<Id>();

  /**
   * @description After-insert Opportunity handler that enqueues nurture, dealer enquiry, and refer-to-dealer emails when enabled.
   * @param newOpportunities Newly inserted Opportunity records from the trigger context.
   */
  public static void handleAfterInsert(List<Opportunity> newOpportunities) {
    if (newOpportunities == null || newOpportunities.isEmpty()) {
      return;
    }

    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
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

    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Opportunity opportunityRecord : eligible) {
      if (opportunityRecord.StageName == BWM_EmailConstants.STAGE_NURTURE) {
        requests.add(
          new BWM_EmailRequest(
            opportunityRecord.Id,
            BWM_EmailConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE
          )
        );
      }

      if (isDealerEnquiryOpportunity(opportunityRecord)) {
        requests.add(
          new BWM_EmailRequest(
            opportunityRecord.Id,
            BWM_EmailConstants.TRIGGER_OPPORTUNITY_DEALER_ENQUIRY
          )
        );
      }

      if (
        opportunityRecord.Customer_Journey__c ==
        BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
      ) {
        requests.add(
          new BWM_EmailRequest(
            opportunityRecord.Id,
            BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
          )
        );
      }

      addClosedWonRequests(requests, opportunityRecord, null);
    }

    if (!requests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(requests);
    }
  }

  /**
   * @description After-update Opportunity handler that enqueues emails for lost-reason and refer-to-dealer changes when enabled.
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

    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      return;
    }

    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Opportunity opportunityRecord : newOpportunities) {
      Opportunity oldRecord = oldMap.get(opportunityRecord.Id);
      if (oldRecord == null) {
        continue;
      }

      addLostReasonChangeRequests(
        requests,
        opportunityRecord,
        oldRecord
      );
      addReferToDealerRequests(requests, opportunityRecord, oldRecord);
      addClosedWonRequests(requests, opportunityRecord, oldRecord);
    }

    if (!requests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(requests);
    }
  }

  /**
   * @description Adds an email request when Lost_Reason__c changes to a routable
   *              trigger, or when stage moves Nurture → Closed Lost with
   *              Not responding already set (that email resolves only after Closed Lost).
   * @param requests Mutable list of email requests to append to.
   * @param opportunityRecord Updated Opportunity record.
   * @param oldRecord Prior Opportunity version before the update.
   */
  private static void addLostReasonChangeRequests(
    List<BWM_EmailRequest> requests,
    Opportunity opportunityRecord,
    Opportunity oldRecord
  ) {
    if (String.isBlank(opportunityRecord.Lost_Reason__c)) {
      return;
    }

    Boolean lostReasonChanged =
      opportunityRecord.Lost_Reason__c != oldRecord.Lost_Reason__c;
    // Match journey UX: reason may be set on Nurture first, then stage moved to
    // Closed Lost. Re-resolve only that Not-responding Nurture path.
    Boolean nurtureNotRespondingMovedToClosedLost =
      !lostReasonChanged &&
      opportunityRecord.StageName == BWM_EmailConstants.STAGE_CLOSED_LOST &&
      oldRecord.StageName == BWM_EmailConstants.STAGE_NURTURE &&
      isNotRespondingLostReason(opportunityRecord.Lost_Reason__c);

    if (!lostReasonChanged && !nurtureNotRespondingMovedToClosedLost) {
      return;
    }

    String triggerPoint = BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
      opportunityRecord.StageName,
      oldRecord.StageName,
      opportunityRecord.Lost_Reason__c
    );
    if (String.isNotBlank(triggerPoint)) {
      requests.add(new BWM_EmailRequest(opportunityRecord.Id, triggerPoint));
    }
  }

  private static Boolean isNotRespondingLostReason(String lostReason) {
    Set<String> allowed = BWM_EmailConstants.OPP_LOST_REASONS_BY_GROUP.get(
      BWM_EmailConstants.OPP_LOST_GROUP_NOT_RESPONDING
    );
    return allowed != null && allowed.contains(lostReason);
  }

  /**
   * @description Adds a refer-to-dealer email request when Customer_Journey__c changes to Refer Dealer.
   * @param requests Mutable list of email requests to append to.
   * @param opportunityRecord Updated Opportunity record.
   * @param oldRecord Prior Opportunity version before the update.
   */
  private static void addReferToDealerRequests(
    List<BWM_EmailRequest> requests,
    Opportunity opportunityRecord,
    Opportunity oldRecord
  ) {
    if (
      opportunityRecord.Customer_Journey__c == oldRecord.Customer_Journey__c
    ) {
      return;
    }
    if (
      opportunityRecord.Customer_Journey__c !=
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    ) {
      return;
    }

    requests.add(
      new BWM_EmailRequest(
        opportunityRecord.Id,
        BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
      )
    );
  }

  /**
   * @description Adds a Closed Won thank-you email when stage newly becomes Closed Won
   *              and Customer Journey is Refer to Dealer or Direct Business.
   * @param requests Mutable list of email requests to append to.
   * @param opportunityRecord Updated Opportunity record.
   * @param oldRecord Prior Opportunity version before the update, or null on insert.
   */
  private static void addClosedWonRequests(
    List<BWM_EmailRequest> requests,
    Opportunity opportunityRecord,
    Opportunity oldRecord
  ) {
    if (oldRecord != null) {
      if (
        opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_WON ||
        oldRecord.StageName == BWM_EmailConstants.STAGE_CLOSED_WON
      ) {
        return;
      }
    } else if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_WON) {
      return;
    }

    if (
      opportunityRecord.Customer_Journey__c ==
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    ) {
      requests.add(
        new BWM_EmailRequest(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_CLOSED_WON_REFER_DEALER
        )
      );
      return;
    }

    if (
      opportunityRecord.Customer_Journey__c ==
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    ) {
      requests.add(
        new BWM_EmailRequest(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS
        )
      );
    }
  }

  /**
   * @description Returns true when the Opportunity is an Enquiry/Gen Tower dealer enquiry with phone or inbound-email source.
   * @param opportunityRecord Opportunity to evaluate.
   * @return True if dealer-enquiry email should fire; otherwise false.
   */
  @TestVisible
  private static Boolean isDealerEnquiryOpportunity(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    if (
      opportunityRecord.Department_Name__c != BWM_EmailConstants.DEPT_ENQUIRY &&
      !BWM_EmailConstants.GEN_TOWER_DEPARTMENTS.contains(
        opportunityRecord.Department_Name__c
      )
    ) {
      return false;
    }

    return BWM_EmailConstants.PHONE_OPPORTUNITY_SOURCES.contains(
        opportunityRecord.LeadSource
      ) ||
      opportunityRecord.LeadSource ==
      BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL;
  }
}