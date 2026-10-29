/**
 * @description   Test class for OpportunityNurtureBudgetaryMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppNurtureBudgetMatrixBtTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    Database.QueryLocator locator = new OpportunityNurtureBudgetaryMatrixBatch().start(null);
    new OpportunityNurtureBudgetaryMatrixBatch().finish(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteBudgetaryNurtureEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Budgetary Nurture Opp',
      true,
      null
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 22);
    opportunityRecord.NurtureEscalation48Sent__c = false;
    opportunityRecord.NurtureEscalation60Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryBudgetaryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityNurtureBudgetaryMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT NurtureEscalation48Sent__c, NurtureEscalation60Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.NurtureEscalation48Sent__c);
    System.assertEquals(true, updatedOpp.NurtureEscalation60Sent__c);
  }
}