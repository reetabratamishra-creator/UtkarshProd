/**
 * @description   Daily batch for Opportunity visit-today push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityVisitTodayPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new OpportunityVisitTodayPushBatch(), 50);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Date today = Date.today();

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Opportunity__c,
          Opportunity__r.OwnerId,
          Opportunity__r.Name,
          Schedule_Date__c,
          Is_schedule__c,
          Logged_At__c,
          Today_Visit_Push_Sent_On__c
        FROM Task_Log__c
        WHERE
          Opportunity__c != NULL
          AND Is_schedule__c = TRUE
          AND Logged_At__c = NULL
          AND Schedule_Date__c = :today
          AND (
            Today_Visit_Push_Sent_On__c = NULL
            OR Today_Visit_Push_Sent_On__c != :today
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Task_Log__c> scope) {
    OpportunityVisitTodayPushService.processVisits(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}