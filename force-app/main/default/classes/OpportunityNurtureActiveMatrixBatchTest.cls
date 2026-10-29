/**
 * @description   Test class for OpportunityNurtureActiveMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OpportunityNurtureActiveMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    Database.QueryLocator locator = new OpportunityNurtureActiveMatrixBatch().start(null);
    new OpportunityNurtureActiveMatrixBatch().finish(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteActiveNurtureEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Active Nurture Opp',
      false,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 5);
    opportunityRecord.Active_Task_Escalation_72_Sent__c = false;
    opportunityRecord.Active_Task_Escalation_96_Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryActiveNurtureOpportunity(
      opportunityRecord.Id
    );

    Test.startTest();
    new OpportunityNurtureActiveMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT Active_Task_Escalation_72_Sent__c, Active_Task_Escalation_96_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.Active_Task_Escalation_72_Sent__c);
    System.assertEquals(true, updatedOpp.Active_Task_Escalation_96_Sent__c);
  }
}