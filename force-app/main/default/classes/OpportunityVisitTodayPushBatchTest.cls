/**
 * @description   Test class for visit-today Opportunity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
@IsTest
private class OpportunityVisitTodayPushBatchTest {
  @IsTest
  static void testProcessVisitScheduledToday() {
    OpportunityVisitTodayPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Visit Today Opp');
    Task_Log__c visitRecord = new Task_Log__c(
      Opportunity__c = opportunityRecord.Id,
      Schedule_Date__c = Date.today(),
      Is_schedule__c = true,
      Visit_Type__c = resolveVisitType()
    );
    insert visitRecord;

    visitRecord = [
      SELECT
        Id,
        Opportunity__c,
        Opportunity__r.OwnerId,
        Opportunity__r.Name,
        Today_Visit_Push_Sent_On__c
      FROM Task_Log__c
      WHERE Id = :visitRecord.Id
    ];

    Test.startTest();
    OpportunityVisitTodayPushService.processVisits(
      new List<Task_Log__c>{ visitRecord }
    );
    OpportunityVisitTodayPushService.processVisits(null);
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      opportunityRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assertEquals(
      visitRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );

    visitRecord = [
      SELECT Today_Visit_Push_Sent_On__c
      FROM Task_Log__c
      WHERE Id = :visitRecord.Id
    ];
    System.assertEquals(Date.today(), visitRecord.Today_Visit_Push_Sent_On__c);
  }

  @IsTest
  static void testBatchStartAndExecute() {
    Opportunity opportunityRecord = createOpportunity('Visit Batch Opp');
    Task_Log__c visitRecord = new Task_Log__c(
      Opportunity__c = opportunityRecord.Id,
      Schedule_Date__c = Date.today(),
      Is_schedule__c = true,
      Visit_Type__c = resolveVisitType()
    );
    insert visitRecord;

    visitRecord = [
      SELECT
        Id,
        Opportunity__c,
        Opportunity__r.OwnerId,
        Opportunity__r.Name,
        Today_Visit_Push_Sent_On__c
      FROM Task_Log__c
      WHERE Id = :visitRecord.Id
    ];

    Test.startTest();
    OpportunityVisitTodayPushBatch batch = new OpportunityVisitTodayPushBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(null, new List<Task_Log__c>{ visitRecord });
    batch.finish(null);
    batch.execute(null);
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

  private static String resolveVisitType() {
    List<Schema.PicklistEntry> entries = Task_Log__c.Visit_Type__c.getDescribe()
      .getPicklistValues();
    return entries.isEmpty() ? 'Follow up' : entries[0].getValue();
  }
}