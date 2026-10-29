/**
 * @description   Sends push notifications for Opportunity events scheduled today.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityEventTodayPushService {
  public static final String NOTIF_TYPE = 'Opportunity_Event_Today_Push_Notification';
  public static final String NOTIFICATION_TITLE = 'Event Scheduled Today';
  public static final String NOTIFICATION_BODY =
    'You have an Event Scheduled today. Click below. Event Page';

  /**
   * @description Sends event-today push notifications to Opportunity Owners.
   */
  public static void processEvents(List<Event> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    Set<Id> opportunityIds = new Set<Id>();
    for (Event eventRecord : scope) {
      if (eventRecord.WhatId != null && isOpportunityId(eventRecord.WhatId)) {
        opportunityIds.add(eventRecord.WhatId);
      }
    }

    Map<Id, Opportunity> opportunitiesById = opportunityIds.isEmpty()
      ? new Map<Id, Opportunity>()
      : new Map<Id, Opportunity>(
          [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE Id IN :opportunityIds
          ]
        );

    Date today = Date.today();
    List<Event> eventsToUpdate = new List<Event>();

    for (Event eventRecord : scope) {
      Opportunity opportunityRecord = opportunitiesById.get(eventRecord.WhatId);
      if (
        opportunityRecord == null ||
        opportunityRecord.OwnerId == null ||
        eventRecord.Today_Event_Push_Sent_On__c == today
      ) {
        continue;
      }

      if (
        CrmPushNotificationService.send(
          opportunityRecord.OwnerId,
          eventRecord.Id,
          NOTIFICATION_TITLE,
          NOTIFICATION_BODY,
          NOTIF_TYPE
        )
      ) {
        eventsToUpdate.add(
          new Event(
            Id = eventRecord.Id,
            Today_Event_Push_Sent_On__c = today
          )
        );
      }
    }

    updateEventsAllowPartial(eventsToUpdate);
  }

  @TestVisible
  private static Boolean isOpportunityId(Id recordId) {
    return recordId != null &&
      String.valueOf(recordId).startsWith(
        Opportunity.sObjectType.getDescribe().getKeyPrefix()
      );
  }

  @TestVisible
  private static void updateEventsAllowPartial(List<Event> eventsToUpdate) {
    if (eventsToUpdate == null || eventsToUpdate.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = Database.update(eventsToUpdate, false);
    for (Integer index = 0; index < results.size(); index++) {
      if (results[index].isSuccess()) {
        continue;
      }
      String errorMessage = results[index].getErrors().isEmpty()
        ? 'Unknown error'
        : results[index].getErrors()[0].getMessage();
      System.debug(
        LoggingLevel.WARN,
        'Event today push flag update failed for ' +
          eventsToUpdate[index].Id +
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