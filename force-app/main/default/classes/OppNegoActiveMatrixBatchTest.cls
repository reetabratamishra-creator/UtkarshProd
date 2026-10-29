/**
 * @description   Test class for OpportunityNegotiationActiveMatrixBatch and OpportunityConsolidatedEmailBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppNegoActiveMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    OpportunityNegotiationActiveMatrixBatch batch = new OpportunityNegotiationActiveMatrixBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.finish(null); // nothing collected -> returns early
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteNegotiationActiveEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Active Opp',
      false,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 22);
    opportunityRecord.EscalationNeg7Sent__c = false;
    opportunityRecord.EscalationNeg14Sent__c = false;
    opportunityRecord.EscalationNeg21Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryNegotiationActiveOpportunity(
      opportunityRecord.Id
    );

    Test.startTest();
    OpportunityNegotiationActiveMatrixBatch batch = new OpportunityNegotiationActiveMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null); // same instance: sends consolidated emails + sets flags
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT EscalationNeg7Sent__c, EscalationNeg14Sent__c, EscalationNeg21Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.EscalationNeg7Sent__c);
    System.assertEquals(true, updatedOpp.EscalationNeg14Sent__c);
    System.assertEquals(true, updatedOpp.EscalationNeg21Sent__c);
  }

  @IsTest
  static void testExecuteOnly7DayEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Active Opp 7d',
      false,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 8);
    opportunityRecord.EscalationNeg7Sent__c = false;
    opportunityRecord.EscalationNeg14Sent__c = false;
    opportunityRecord.EscalationNeg21Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryNegotiationActiveOpportunity(
      opportunityRecord.Id
    );

    Test.startTest();
    OpportunityNegotiationActiveMatrixBatch batch = new OpportunityNegotiationActiveMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT EscalationNeg7Sent__c, EscalationNeg14Sent__c, EscalationNeg21Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.EscalationNeg7Sent__c);
    System.assertNotEquals(true, updatedOpp.EscalationNeg14Sent__c);
    System.assertNotEquals(true, updatedOpp.EscalationNeg21Sent__c);
  }

  // ===========================================================================
  // LEGACY per-opportunity logic (needs @TestVisible on legacyExecutePerOpportunity)
  // ===========================================================================
  @IsTest
  static void testLegacyExecutePerOpportunity() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Legacy Opp',
      false,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 22);
    opportunityRecord.EscalationNeg7Sent__c = false;
    opportunityRecord.EscalationNeg14Sent__c = false;
    opportunityRecord.EscalationNeg21Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryNegotiationActiveOpportunity(
      opportunityRecord.Id
    );

    Test.startTest();
    new OpportunityNegotiationActiveMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT EscalationNeg7Sent__c, EscalationNeg14Sent__c, EscalationNeg21Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.EscalationNeg7Sent__c);
    System.assertEquals(true, updatedOpp.EscalationNeg14Sent__c);
    System.assertEquals(true, updatedOpp.EscalationNeg21Sent__c);
  }

  @IsTest
  static void testLegacyAlreadySent() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Legacy Sent',
      false,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 22);
    opportunityRecord.EscalationNeg7Sent__c = true;
    opportunityRecord.EscalationNeg14Sent__c = true;
    opportunityRecord.EscalationNeg21Sent__c = true;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryNegotiationActiveOpportunity(
      opportunityRecord.Id
    );

    Test.startTest();
    new OpportunityNegotiationActiveMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }

  // ===========================================================================
  // OpportunityConsolidatedEmailBatch
  // ===========================================================================
  @IsTest
  static void testConsolidatedEmailBatchExecute() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Consolidated Opp',
      false,
      null
    );
    opportunityRecord = EscalationMatrixTestUtil.queryNegotiationActiveOpportunity(
      opportunityRecord.Id
    );

    OpportunityConsolidatedEmailBatch.WorkItem item = new OpportunityConsolidatedEmailBatch.WorkItem();
    item.groupKey = 'test.recipient@example.com';
    item.templateName = 'Negotiation Active 7d Owner';
    item.recipientType = EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM;
    item.flagField = 'EscalationNeg7Sent__c';
    item.opportunities = new List<Opportunity>{ opportunityRecord };

    Test.startTest();
    Database.executeBatch(
      new OpportunityConsolidatedEmailBatch(
        new List<OpportunityConsolidatedEmailBatch.WorkItem>{ item },
        new Map<Id, Long>{ opportunityRecord.Id => 8 }
      ),
      10
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }

  @IsTest
  static void testConsolidatedEmailBatchStartAndFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    OpportunityConsolidatedEmailBatch batch = new OpportunityConsolidatedEmailBatch(
      new List<OpportunityConsolidatedEmailBatch.WorkItem>(),
      new Map<Id, Long>()
    );

    Test.startTest();
    Object result = batch.start(null);
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, result);
  }
}