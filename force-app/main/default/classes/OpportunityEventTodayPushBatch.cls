/**
 * @description   Daily batch for Opportunity event-today push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityEventTodayPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new OpportunityEventTodayPushBatch(), 50);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Date today = Date.today();

    return Database.getQueryLocator(
      [
        SELECT Id, WhatId, ActivityDate, Today_Event_Push_Sent_On__c
        FROM Event
        WHERE
          WhatId != NULL
          AND ActivityDate = :today
          AND (
            Today_Event_Push_Sent_On__c = NULL
            OR Today_Event_Push_Sent_On__c != :today
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Event> scope) {
    OpportunityEventTodayPushService.processEvents(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}