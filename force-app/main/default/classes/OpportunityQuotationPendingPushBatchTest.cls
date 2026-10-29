/**
 * @description   Test class for quotation-pending Opportunity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
@IsTest
private class OpportunityQuotationPendingPushBatchTest {
  @IsTest
  static void testProcessOpportunityWithoutQuote() {
    OpportunityQuotationPendingPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Quote Pending Opp');
    opportunityRecord = [
      SELECT Id, Name, OwnerId, Quotation_Pending_Push_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    OpportunityQuotationPendingPushService.processOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      opportunityRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(opportunityRecord.Name)
    );

    opportunityRecord = [
      SELECT Quotation_Pending_Push_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, opportunityRecord.Quotation_Pending_Push_Sent__c);
  }

  @IsTest
  static void testSkipsOpportunityWithQuote() {
    OpportunityQuotationPendingPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Quoted Opp');
    insert new Quote(
      Name = 'Test Quote',
      OpportunityId = opportunityRecord.Id
    );

    opportunityRecord = [
      SELECT Id, Name, OwnerId, Quotation_Pending_Push_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    OpportunityQuotationPendingPushService.processOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    OpportunityQuotationPendingPushService.processOpportunities(null);
    Test.stopTest();

    System.assertEquals(
      true,
      CrmPushNotificationService.testSentRequests == null ||
        CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }

  @IsTest
  static void testBatchStartAndScheduler() {
    Opportunity opportunityRecord = createOpportunity('Quote Batch Opp');
    opportunityRecord = [
      SELECT Id, Name, OwnerId, Quotation_Pending_Push_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    OpportunityQuotationPendingPushBatch batch = new OpportunityQuotationPendingPushBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(null, new List<Opportunity>{ opportunityRecord });
    batch.finish(null);
    batch.execute(null);
    new OpportunityDailyPushScheduler().execute(null);
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
    return opportunityRecord;
  }
}