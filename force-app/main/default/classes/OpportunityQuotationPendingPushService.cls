/**
 * @description   Sends push notifications when an open Opportunity has no related Quote.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityQuotationPendingPushService {
  public static final String NOTIF_TYPE = 'Opportunity_Quotation_Pending_Push_Notification';
  public static final String NOTIFICATION_TITLE = 'Quotation Pending';

  /**
   * @description Sends quotation-pending push notifications to Opportunity Owners.
   */
  public static void processOpportunities(List<Opportunity> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    Set<Id> opportunityIds = new Map<Id, Opportunity>(scope).keySet();
    Set<Id> opportunityIdsWithQuotes = new Set<Id>();

    for (Quote quoteRecord : [
      SELECT OpportunityId
      FROM Quote
      WHERE OpportunityId IN :opportunityIds
    ]) {
      opportunityIdsWithQuotes.add(quoteRecord.OpportunityId);
    }

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    for (Opportunity opportunityRecord : scope) {
      if (
        opportunityRecord.Quotation_Pending_Push_Sent__c == true ||
        opportunityRecord.OwnerId == null ||
        opportunityIdsWithQuotes.contains(opportunityRecord.Id)
      ) {
        continue;
      }

      String body =
        'Quotation creation pending for this opportunity. Click below ' +
        opportunityRecord.Name;

      if (
        CrmPushNotificationService.send(
          opportunityRecord.OwnerId,
          opportunityRecord.Id,
          NOTIFICATION_TITLE,
          body,
          NOTIF_TYPE
        )
      ) {
        opportunitiesToUpdate.add(
          new Opportunity(
            Id = opportunityRecord.Id,
            Quotation_Pending_Push_Sent__c = true
          )
        );
      }
    }

    updateOpportunitiesAllowPartial(opportunitiesToUpdate);
  }

  @TestVisible
  private static void updateOpportunitiesAllowPartial(
    List<Opportunity> opportunitiesToUpdate
  ) {
    if (opportunitiesToUpdate == null || opportunitiesToUpdate.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = Database.update(opportunitiesToUpdate, false);
    for (Integer index = 0; index < results.size(); index++) {
      if (results[index].isSuccess()) {
        continue;
      }
      String errorMessage = results[index].getErrors().isEmpty()
        ? 'Unknown error'
        : results[index].getErrors()[0].getMessage();
      System.debug(
        LoggingLevel.WARN,
        'Opportunity quotation push flag update failed for ' +
          opportunitiesToUpdate[index].Id +
          ': ' +
          errorMessage
      );
    }
  }

  @TestVisible
  static void clearTestState() {
    CrmPushNotificationService.clearTestState();
  }
}