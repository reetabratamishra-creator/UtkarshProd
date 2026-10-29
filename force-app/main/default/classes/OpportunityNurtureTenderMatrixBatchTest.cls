/**
 * @description   Test class for OpportunityNurtureTenderMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OpportunityNurtureTenderMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    Database.QueryLocator locator = new OpportunityNurtureTenderMatrixBatch().start(null);
    new OpportunityNurtureTenderMatrixBatch().finish(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteTenderNurtureEscalation() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Tender Nurture Opp',
      false,
      tenderRecordTypeId
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 22);
    opportunityRecord.TenderEsc15Sent__c = false;
    opportunityRecord.TenderEsc21Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityNurtureTenderMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT TenderEsc15Sent__c, TenderEsc21Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.TenderEsc15Sent__c);
    System.assertEquals(true, updatedOpp.TenderEsc21Sent__c);
  }
}