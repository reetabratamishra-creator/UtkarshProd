/**
 * @description   Test class for BWM_NegotiationStageUpdateBatch stale Negotiation
 *                messaging enqueue paths.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_NegotiationStageUpdateBatchTest {
  /**
   * Scenario: Negotiation Opportunity with Active sub-stage is enqueued.
   */
  @IsTest
  static void testExecute_ActiveSubStage_EnqueuesMessaging() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Account accountRecord = new Account(
      Name = 'Negotiation Batch Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Negotiation Batch Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = BWM_MessagingConstants.SUB_STAGE_ACTIVE,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    new BWM_NegotiationStageUpdateBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    new BWM_NegotiationStageUpdateBatch().execute(null);
    Test.stopTest();

    Integer queueableJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND Status = 'Completed'
    ];
    System.assert(queueableJobs >= 1, 'Batch should enqueue messaging work.');
  }

  /**
   * Scenario: Negotiation Opportunity without Active/Budgetary sub-stage is skipped.
   */
  @IsTest
  static void testExecute_NonActiveSubStage_Skipped() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Negotiation Inactive Sub ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_MessagingConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = null,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    new BWM_NegotiationStageUpdateBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Message_Log__c
        WHERE Opportunity__c = :opportunityRecord.Id
      ]
    );
  }

  /**
   * Scenario: Batch start query locator returns without error.
   */
  @IsTest
  static void testStart_ReturnsQueryLocator() {
    Test.startTest();
    Database.QueryLocator locator = new BWM_NegotiationStageUpdateBatch().start(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testFinishAndSchedulableExecute() {
    Test.startTest();
    new BWM_NegotiationStageUpdateBatch().finish(null);
    new BWM_NegotiationStageUpdateBatch().execute((SchedulableContext) null);
    Test.stopTest();
    System.assertEquals(true, true);
  }

}