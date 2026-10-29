/**
 * @description   Sends a custom push notification when an Opportunity is marked Closed Won.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class OpportunityWonPushNotificationService {
  private static final String NOTIF_TYPE = 'MasterOpportunity_Creation';
  private static final String NOTIFICATION_TITLE = 'Opportunity Marked WON';

  /**
   * @description Sends push notifications when Opportunities transition to Closed Won.
   */
  public static void sendForNewlyClosedWonOpportunities(
    List<Opportunity> newOpportunities,
    Map<Id, Opportunity> oldMap
  ) {
    if (newOpportunities == null || newOpportunities.isEmpty() || oldMap == null) {
      return;
    }

    Set<Id> opportunityIds = new Set<Id>();
    for (Opportunity opportunityRecord : newOpportunities) {
      Opportunity oldRecord = oldMap.get(opportunityRecord.Id);
      if (isNewlyClosedWon(opportunityRecord, oldRecord)) {
        opportunityIds.add(opportunityRecord.Id);
      }
    }

    if (opportunityIds.isEmpty()) {
      return;
    }

    List<Opportunity> opportunityRecords = [
      SELECT
        Id,
        Name,
        StageName,
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ];

    for (Opportunity opportunityRecord : opportunityRecords) {
      sendToHodAndCrmHead(opportunityRecord);
    }
  }

  @TestVisible
  static Boolean isNewlyClosedWon(
    Opportunity opportunityRecord,
    Opportunity oldRecord
  ) {
    return opportunityRecord != null &&
      oldRecord != null &&
      opportunityRecord.StageName == BWM_EmailConstants.STAGE_CLOSED_WON &&
      oldRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_WON;
  }

  private static void sendToHodAndCrmHead(Opportunity opportunityRecord) {
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveOpportunityHodAndCrmHeadUserIds(
      opportunityRecord
    );
    if (recipientUserIds.isEmpty()) {
      return;
    }

    String body =
      'An Opportunity has been marked WON. ' +
      opportunityRecord.Name +
      '.';

    CrmPushNotificationService.sendToUsers(
      recipientUserIds,
      opportunityRecord.Id,
      NOTIFICATION_TITLE,
      body,
      NOTIF_TYPE
    );
  }

  @TestVisible
  static void clearTestState() {
    CrmPushRecipientService.clearTestState();
    CrmPushNotificationService.clearTestState();
  }
}