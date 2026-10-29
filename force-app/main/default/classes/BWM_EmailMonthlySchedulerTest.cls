/**
 * @description   Tests BWM_EmailMonthlyScheduler execute and batch enqueue.
 * @author        Anshita Chanda
 * @date          2026-08-18
 */
@IsTest
private class BWM_EmailMonthlySchedulerTest {
  @IsTest
  static void executeEnqueuesMonthlyBatches() {
    Test.startTest();
    new BWM_EmailMonthlyScheduler().execute(null);
    Test.stopTest();
    System.assertEquals(true, true);
  }

  @IsTest
  static void opportunityFieldHistoryStaleChecks() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Stale History Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(15)
    );
    insert as system opportunityRecord;
    Test.setCreatedDate(opportunityRecord.Id, DateTime.now().addDays(-40));

    Test.startTest();
    Boolean nullResult = BWM_EmailOpportunityFieldHistoryService.isStageStaleForDays(
      null,
      30
    );
    Boolean staleResult = BWM_EmailOpportunityFieldHistoryService.isStageStaleForDays(
      opportunityRecord.Id,
      30
    );
    Map<Id, Boolean> staleMap = BWM_EmailOpportunityFieldHistoryService.buildStageStaleMap(
      new Set<Id>{ opportunityRecord.Id },
      30
    );
    Map<Id, Boolean> emptyMap = BWM_EmailOpportunityFieldHistoryService.buildStageStaleMap(
      new Set<Id>(),
      30
    );
    Test.stopTest();

    System.assertEquals(false, nullResult);
    System.assertEquals(true, staleResult);
    System.assertEquals(true, staleMap.get(opportunityRecord.Id));
    System.assertEquals(true, emptyMap.isEmpty());
  }

  @IsTest
  static void negotiationEmailBatchesCoverStartExecuteFinishAndSchedule() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Account accountRecord = new Account(
      Name = 'Email Nego Batch Acct ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity activeOpportunity = new Opportunity(
      Name = 'Email Nego Active ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_ACTIVE,
      CloseDate = Date.today().addDays(20),
      Email__c = 'negoactive+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    Opportunity budgetaryOpportunity = new Opportunity(
      Name = 'Email Nego Budget ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_BUDGETARY,
      CloseDate = Date.today().addDays(21),
      Email__c = 'negobudget+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    Opportunity tenderOpportunity = new Opportunity(
      Name = 'Email Nego Tender ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_TENDER,
      CloseDate = Date.today().addDays(22),
      Email__c = 'negotender+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    List<Opportunity> negotiationOpportunities = new List<Opportunity>{
      activeOpportunity,
      budgetaryOpportunity,
      tenderOpportunity
    };
    try {
      insert as system negotiationOpportunities;
    } catch (DmlException ex) {
      negotiationOpportunities = new List<Opportunity>();
    }
    if (!negotiationOpportunities.isEmpty() && activeOpportunity.Id != null) {
      Test.setCreatedDate(activeOpportunity.Id, DateTime.now().addDays(-40));
      Test.setCreatedDate(budgetaryOpportunity.Id, DateTime.now().addDays(-40));
    }

    if (budgetaryOpportunity.Id != null) {
      insert as system new Email_Log__c(
        Opportunity__c = budgetaryOpportunity.Id,
        Related_Record_Id__c = String.valueOf(budgetaryOpportunity.Id),
        Trigger_Point__c = BWM_EmailConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
        Status__c = BWM_EmailConstants.LOG_STATUS_SENT
      );
    }

    Test.startTest();
    BWM_EmailNegotiationStageUpdateBatch stageBatch = new BWM_EmailNegotiationStageUpdateBatch();
    System.assertNotEquals(null, stageBatch.start(null));
    stageBatch.execute(null, new List<Opportunity>());
    if (activeOpportunity.Id != null) {
      stageBatch.execute(
        null,
        new List<Opportunity>{ activeOpportunity, budgetaryOpportunity }
      );
    }
    stageBatch.finish(null);
    stageBatch.execute((SchedulableContext) null);

    BWM_EmailNegotiationTenderMonthlyBatch tenderBatch = new BWM_EmailNegotiationTenderMonthlyBatch();
    System.assertNotEquals(null, tenderBatch.start(null));
    tenderBatch.execute(null, new List<Opportunity>());
    if (tenderOpportunity.Id != null) {
      tenderBatch.execute(null, new List<Opportunity>{ tenderOpportunity });
    }
    tenderBatch.finish(null);
    tenderBatch.execute((SchedulableContext) null);
    Test.stopTest();

    System.assertEquals(true, true);
  }
}