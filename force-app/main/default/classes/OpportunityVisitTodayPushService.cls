/**
 * @description   Sends push notifications for Opportunity visits scheduled today.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityVisitTodayPushService {
  public static final String NOTIF_TYPE = 'Opportunity_Visit_Today_Push_Notification';
  public static final String NOTIFICATION_TITLE = 'Customer Visit Today';
  public static final String NOTIFICATION_BODY =
    'You have a Customer Visit scheduled today. Click below. Visit Page';

  /**
   * @description Sends visit-today push notifications to Opportunity Owners.
   */
  public static void processVisits(List<Task_Log__c> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    Date today = Date.today();
    List<Task_Log__c> visitsToUpdate = new List<Task_Log__c>();

    for (Task_Log__c visitRecord : scope) {
      if (
        visitRecord.Opportunity__c == null ||
        visitRecord.Opportunity__r == null ||
        visitRecord.Opportunity__r.OwnerId == null ||
        visitRecord.Today_Visit_Push_Sent_On__c == today
      ) {
        continue;
      }

      if (
        CrmPushNotificationService.send(
          visitRecord.Opportunity__r.OwnerId,
          visitRecord.Id,
          NOTIFICATION_TITLE,
          NOTIFICATION_BODY,
          NOTIF_TYPE
        )
      ) {
        visitsToUpdate.add(
          new Task_Log__c(
            Id = visitRecord.Id,
            Today_Visit_Push_Sent_On__c = today
          )
        );
      }
    }

    updateVisitsAllowPartial(visitsToUpdate);
  }

  @TestVisible
  private static void updateVisitsAllowPartial(List<Task_Log__c> visitsToUpdate) {
    if (visitsToUpdate == null || visitsToUpdate.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = Database.update(visitsToUpdate, false);
    for (Integer index = 0; index < results.size(); index++) {
      if (results[index].isSuccess()) {
        continue;
      }
      String errorMessage = results[index].getErrors().isEmpty()
        ? 'Unknown error'
        : results[index].getErrors()[0].getMessage();
      System.debug(
        LoggingLevel.WARN,
        'Visit today push flag update failed for ' +
          visitsToUpdate[index].Id +
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