/**
 * @description   Test class for OpportunityQuotationPendingMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppQuotePendingMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    Database.QueryLocator locator = new OpportunityQuotationPendingMatrixBatch().start(null);
    new OpportunityQuotationPendingMatrixBatch().finish(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecute48HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Quotation Pending Opp',
      false,
      null
    );
    opportunityRecord.Nurture_Stage_Entry_Date__c = System.now().addHours(-50);
    opportunityRecord.Nurture_Escalation_48_Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityQuotationPendingMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT Nurture_Escalation_48_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.Nurture_Escalation_48_Sent__c);
  }

  @IsTest
  static void testExecute60And72HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Quotation Pending 72h Opp',
      false,
      null
    );
    opportunityRecord.Nurture_Stage_Entry_Date__c = System.now().addHours(-80);
    opportunityRecord.Nurture_Escalation_48_Sent__c = true;
    opportunityRecord.Nurture_Escalation_60_Sent__c = false;
    opportunityRecord.Nurture_Escalation_72_Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityQuotationPendingMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT Nurture_Escalation_60_Sent__c, Nurture_Escalation_72_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.Nurture_Escalation_60_Sent__c);
    System.assertEquals(true, updatedOpp.Nurture_Escalation_72_Sent__c);
  }

  @IsTest
  static void testSkipsWhenQuoteExists() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Quoted Opp',
      false,
      null
    );
    opportunityRecord.Nurture_Stage_Entry_Date__c = System.now().addHours(-50);
    opportunityRecord.Nurture_Escalation_48_Sent__c = false;
    update opportunityRecord;

    insert new Quote(Name = 'Test Quote', OpportunityId = opportunityRecord.Id);

    opportunityRecord = EscalationMatrixTestUtil.queryOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityQuotationPendingMatrixBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT Nurture_Escalation_48_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(false, updatedOpp.Nurture_Escalation_48_Sent__c);
  }
}