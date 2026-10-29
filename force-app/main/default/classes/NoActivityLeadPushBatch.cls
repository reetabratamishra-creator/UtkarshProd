/**
 * @description   Hourly batch for Prospecting Lead 24-hour no-activity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class NoActivityLeadPushBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff24 = System.now().addHours(-24);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Last_Prospecting_Activity__c,
          Prospecting_No_Activity_Push_24_Sent__c
        FROM Lead
        WHERE
          Status = 'Prospecting'
          AND IsConverted = FALSE
          AND Last_Prospecting_Activity__c != NULL
          AND Last_Prospecting_Activity__c <= :cutoff24
          AND Prospecting_No_Activity_Push_24_Sent__c = FALSE
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Lead> scope) {
    NoActivityPushNotificationService.processLeads(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}