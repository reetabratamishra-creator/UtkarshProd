/**
 * @description   Test class for event-today Opportunity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
@IsTest
private class OpportunityEventTodayPushBatchTest {
  @IsTest
  static void testProcessEventScheduledToday() {
    OpportunityEventTodayPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Event Today Opp');
    Event eventRecord = new Event(
      WhatId = opportunityRecord.Id,
      Subject = 'Customer Meeting',
      StartDateTime = Datetime.now().addHours(2),
      EndDateTime = Datetime.now().addHours(3),
      ActivityDate = Date.today()
    );
    insert eventRecord;

    eventRecord = [
      SELECT Id, WhatId, ActivityDate, Today_Event_Push_Sent_On__c
      FROM Event
      WHERE Id = :eventRecord.Id
    ];

    Test.startTest();
    OpportunityEventTodayPushService.processEvents(
      new List<Event>{ eventRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      opportunityRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assertEquals(
      eventRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );

    eventRecord = [
      SELECT Today_Event_Push_Sent_On__c
      FROM Event
      WHERE Id = :eventRecord.Id
    ];
    System.assertEquals(Date.today(), eventRecord.Today_Event_Push_Sent_On__c);
  }

  @IsTest
  static void testBatchStartAndExecute() {
    Opportunity opportunityRecord = createOpportunity('Event Batch Opp');
    Event eventRecord = new Event(
      WhatId = opportunityRecord.Id,
      Subject = 'Batch Meeting',
      StartDateTime = Datetime.now().addHours(2),
      EndDateTime = Datetime.now().addHours(3),
      ActivityDate = Date.today()
    );
    insert eventRecord;

    eventRecord = [
      SELECT Id, WhatId, ActivityDate, Today_Event_Push_Sent_On__c
      FROM Event
      WHERE Id = :eventRecord.Id
    ];

    Test.startTest();
    OpportunityEventTodayPushBatch batch = new OpportunityEventTodayPushBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(null, new List<Event>{ eventRecord });
    batch.finish(null);
    batch.execute(null);
    OpportunityEventTodayPushService.processEvents(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  private static Opportunity createOpportunity(String name) {
    Account accountRecord = new Account(Name = name + ' Account');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30)
    );
    insert opportunityRecord;

    return [
      SELECT Id, OwnerId
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
  }
}