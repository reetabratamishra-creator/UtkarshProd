/**
 * @description   Test class for OppNegoBudgetaryMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppNegoBudgetaryMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    OppNegoBudgetaryMatrixBatch batch = new OppNegoBudgetaryMatrixBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.finish(null); // nothing collected -> returns early
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteNegotiationBudgetaryEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Budgetary Opp',
      true,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.NurtureEscalation48Sent__c = false;
    opportunityRecord.NurtureEscalation60Sent__c = false;
    opportunityRecord.NurtureEscalation72Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    OppNegoBudgetaryMatrixBatch batch = new OppNegoBudgetaryMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null); // same instance: sends consolidated emails + sets flags
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT NurtureEscalation48Sent__c, NurtureEscalation60Sent__c, NurtureEscalation72Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.NurtureEscalation48Sent__c);
    System.assertEquals(true, updatedOpp.NurtureEscalation60Sent__c);
    System.assertEquals(true, updatedOpp.NurtureEscalation72Sent__c);
  }

  @IsTest
  static void testExecuteOnly30DayEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Budgetary Opp 30d',
      true,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 31);
    opportunityRecord.NurtureEscalation48Sent__c = false;
    opportunityRecord.NurtureEscalation60Sent__c = false;
    opportunityRecord.NurtureEscalation72Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    OppNegoBudgetaryMatrixBatch batch = new OppNegoBudgetaryMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT NurtureEscalation48Sent__c, NurtureEscalation60Sent__c, NurtureEscalation72Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.NurtureEscalation48Sent__c);
    System.assertNotEquals(true, updatedOpp.NurtureEscalation60Sent__c);
    System.assertNotEquals(true, updatedOpp.NurtureEscalation72Sent__c);
  }

  @IsTest
  static void testExecuteWithoutActivityUsesLastModifiedDate() {
    EscalationMatrixTestUtil.prepareTestContext();

    // No old activity set -> falls back to LastModifiedDate (0 days) -> nothing qualifies
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Budgetary No Activity',
      true,
      null
    );
    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    OppNegoBudgetaryMatrixBatch batch = new OppNegoBudgetaryMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT NurtureEscalation48Sent__c, NurtureEscalation60Sent__c, NurtureEscalation72Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertNotEquals(true, updatedOpp.NurtureEscalation48Sent__c);
    System.assertNotEquals(true, updatedOpp.NurtureEscalation60Sent__c);
    System.assertNotEquals(true, updatedOpp.NurtureEscalation72Sent__c);
  }

  // ===========================================================================
  // LEGACY per-opportunity logic (needs @TestVisible on legacyExecutePerOpportunity)
  // ===========================================================================
  @IsTest
  static void testLegacyExecutePerOpportunity() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Budgetary Legacy Opp',
      true,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.NurtureEscalation48Sent__c = false;
    opportunityRecord.NurtureEscalation60Sent__c = false;
    opportunityRecord.NurtureEscalation72Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OppNegoBudgetaryMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT NurtureEscalation48Sent__c, NurtureEscalation60Sent__c, NurtureEscalation72Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.NurtureEscalation48Sent__c);
    System.assertEquals(true, updatedOpp.NurtureEscalation60Sent__c);
    System.assertEquals(true, updatedOpp.NurtureEscalation72Sent__c);
  }

  @IsTest
  static void testLegacyAlreadySent() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Budgetary Legacy Sent',
      true,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.NurtureEscalation48Sent__c = true;
    opportunityRecord.NurtureEscalation60Sent__c = true;
    opportunityRecord.NurtureEscalation72Sent__c = true;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OppNegoBudgetaryMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }
}