/**
 * @description   Test class for OpportunityNegotiationTenderMatrixBatch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppNegoTenderMatrixBatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    OpportunityNegotiationTenderMatrixBatch batch = new OpportunityNegotiationTenderMatrixBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.finish(null); // nothing collected -> returns early
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecuteNegotiationTenderEscalation() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Tender Opp',
      false,
      tenderRecordTypeId
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.TenderEsc15Sent__c = false;
    opportunityRecord.TenderEsc21Sent__c = false;
    opportunityRecord.TenderEsc30Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    OpportunityNegotiationTenderMatrixBatch batch = new OpportunityNegotiationTenderMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null); // same instance: sends consolidated emails + sets flags
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT TenderEsc15Sent__c, TenderEsc21Sent__c, TenderEsc30Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.TenderEsc15Sent__c);
    System.assertEquals(true, updatedOpp.TenderEsc21Sent__c);
    System.assertEquals(true, updatedOpp.TenderEsc30Sent__c);
  }

  @IsTest
  static void testExecuteOnly30DayEscalation() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Tender Opp 30d',
      false,
      tenderRecordTypeId
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 31);
    opportunityRecord.TenderEsc15Sent__c = false;
    opportunityRecord.TenderEsc21Sent__c = false;
    opportunityRecord.TenderEsc30Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    OpportunityNegotiationTenderMatrixBatch batch = new OpportunityNegotiationTenderMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT TenderEsc15Sent__c, TenderEsc21Sent__c, TenderEsc30Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.TenderEsc15Sent__c);
    System.assertNotEquals(true, updatedOpp.TenderEsc21Sent__c);
    System.assertNotEquals(true, updatedOpp.TenderEsc30Sent__c);
  }

  @IsTest
  static void testExecuteWithoutActivityUsesLastModifiedDate() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    // No old activity set -> falls back to LastModifiedDate (0 days) -> nothing qualifies
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Tender No Activity',
      false,
      tenderRecordTypeId
    );
    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    OpportunityNegotiationTenderMatrixBatch batch = new OpportunityNegotiationTenderMatrixBatch();
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT TenderEsc15Sent__c, TenderEsc21Sent__c, TenderEsc30Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertNotEquals(true, updatedOpp.TenderEsc15Sent__c);
    System.assertNotEquals(true, updatedOpp.TenderEsc21Sent__c);
    System.assertNotEquals(true, updatedOpp.TenderEsc30Sent__c);
  }

  // ===========================================================================
  // LEGACY per-opportunity logic (needs @TestVisible on legacyExecutePerOpportunity)
  // ===========================================================================
  @IsTest
  static void testLegacyExecutePerOpportunity() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Tender Legacy Opp',
      false,
      tenderRecordTypeId
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.TenderEsc15Sent__c = false;
    opportunityRecord.TenderEsc21Sent__c = false;
    opportunityRecord.TenderEsc30Sent__c = false;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityNegotiationTenderMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT TenderEsc15Sent__c, TenderEsc21Sent__c, TenderEsc30Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.TenderEsc15Sent__c);
    System.assertEquals(true, updatedOpp.TenderEsc21Sent__c);
    System.assertEquals(true, updatedOpp.TenderEsc30Sent__c);
  }

  @IsTest
  static void testLegacyAlreadySent() {
    Id tenderRecordTypeId = EscalationMatrixTestUtil.getTenderRecordTypeId();
    if (tenderRecordTypeId == null) {
      return;
    }

    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Negotiation Tender Legacy Sent',
      false,
      tenderRecordTypeId
    );
    EscalationMatrixTestUtil.setOldOpportunityActivity(opportunityRecord.Id, 61);
    opportunityRecord.TenderEsc15Sent__c = true;
    opportunityRecord.TenderEsc21Sent__c = true;
    opportunityRecord.TenderEsc30Sent__c = true;
    update opportunityRecord;

    opportunityRecord = EscalationMatrixTestUtil.queryTenderOpportunity(opportunityRecord.Id);

    Test.startTest();
    new OpportunityNegotiationTenderMatrixBatch()
      .legacyExecutePerOpportunity(new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }
}