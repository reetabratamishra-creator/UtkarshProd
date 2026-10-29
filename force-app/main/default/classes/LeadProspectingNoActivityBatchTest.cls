/**
 * @description   Test class for LeadProspectingNoActivityBatch (consolidated emails).
 * @author        Anshita Chanda
 * @date          2026-10-23
 *
 * Compiles with NO change to LeadProspectingNoActivityBatch.
 * The private legacy methods (legacyExecutePerLead, legacyFinishSingleTransaction,
 * queueConsolidatedEmails, markSentFlags) are not called here because a test class cannot
 * reach private methods without @TestVisible.
 */
@IsTest
private class LeadProspectingNoActivityBatchTest {
  // Same fields as LeadProspectingNoActivityBatch.start()
  private static Lead queryLeadForBatch(Id leadId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Email,
        Owner.Name,
        Status,
        Department_Name__c,
        Department_NameFormula__c,
        Last_Prospecting_Activity__c,
        Prospecting_Escalation_24_Sent__c,
        Prospecting_Escalation_48_Sent__c,
        Prospecting_Escalation_72_Sent__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  private static Lead queryFlags(Id leadId) {
    return [
      SELECT
        Prospecting_Escalation_24_Sent__c,
        Prospecting_Escalation_48_Sent__c,
        Prospecting_Escalation_72_Sent__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  // execute() groups the leads, finish() sends + flags (same instance on purpose).
  private static void runBatchOn(List<Lead> leads) {
    LeadProspectingNoActivityBatch batch = new LeadProspectingNoActivityBatch();
    batch.execute(null, leads);
    batch.finish(null);
  }

  // ===========================================================================
  // LIVE FLOW
  // ===========================================================================

  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    LeadProspectingNoActivityBatch batch = new LeadProspectingNoActivityBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.execute(null, new List<Lead>()); // nothing to group
    batch.finish(null); // nothing to send, must not fail
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecute24HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'Prospecting24');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    runBatchOn(new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  @IsTest
  static void testExecute48And96HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'Prospecting96');
    leadRecord.Prospecting_Escalation_24_Sent__c = true;
    leadRecord.Prospecting_Escalation_48_Sent__c = false;
    leadRecord.Prospecting_Escalation_72_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-100)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    runBatchOn(new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_72_Sent__c); // 96h tier uses the _72_ checkbox
  }

  // A lead under 24h must not be escalated at all.
  @IsTest
  static void testNoEscalationBefore24Hours() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingNew');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    leadRecord.Prospecting_Escalation_48_Sent__c = false;
    leadRecord.Prospecting_Escalation_72_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-10)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    runBatchOn(new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  // No test override for the activity date: the batch falls back to Last_Prospecting_Activity__c.
  @IsTest
  static void testExecuteWithoutOverrideUsesLeadField() {
    EscalationMatrixTestUtil.prepareTestContext();
    LeadProspectingNoActivityBatch.clearTestLastProspectingActivityOverrides();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingField');

    Test.startTest();
    runBatchOn(new List<Lead>{ queryLeadForBatch(leadRecord.Id) });
    Test.stopTest();

    // a brand-new lead has no old activity, so nothing is escalated
    System.assertEquals(false, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }

  // Override map exists but holds a DIFFERENT lead: falls back to the lead field.
  @IsTest
  static void testOverrideMapWithoutThisLeadFallsBackToField() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead otherLead = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingOther');
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingNoOvr');
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      otherLead.Id,
      System.now().addHours(-100)
    );

    Test.startTest();
    runBatchOn(new List<Lead>{ queryLeadForBatch(leadRecord.Id) });
    Test.stopTest();

    System.assertEquals(false, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }

  // Two leads of the same owner end up in ONE consolidated email; both get flagged.
  @IsTest
  static void testLeadsOfSameOwnerAreConsolidated() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadOne = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingA');
    Lead leadTwo = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingB');
    leadOne.Prospecting_Escalation_24_Sent__c = false;
    leadTwo.Prospecting_Escalation_24_Sent__c = false;
    update as system new List<Lead>{ leadOne, leadTwo };
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadOne.Id,
      System.now().addHours(-30)
    );
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadTwo.Id,
      System.now().addHours(-30)
    );

    List<Lead> scope = new List<Lead>{
      queryLeadForBatch(leadOne.Id),
      queryLeadForBatch(leadTwo.Id)
    };

    Test.startTest();
    runBatchOn(scope);
    Test.stopTest();

    System.assertEquals(true, queryFlags(leadOne.Id).Prospecting_Escalation_24_Sent__c);
    System.assertEquals(true, queryFlags(leadTwo.Id).Prospecting_Escalation_24_Sent__c);
  }

  // NEW: no recipient resolved => addLeadToGroup() returns early, lead stays unflagged.
  // Real recipient lookup is used (no recipient override); the ED group is used because the
  // 'Utkarsh ED' role normally has no user in a test run. The expectation adapts if it does.
  @IsTest
  static void testLeadWithoutRecipientsIsSkipped() {
    EscalationMatrixTestUtil.prepareTestContext();
    EscalationMatrixEmailService.testRecipientOverrides = null;

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingNoRcpt');
    leadRecord.Prospecting_Escalation_24_Sent__c = true;
    leadRecord.Prospecting_Escalation_48_Sent__c = true;
    leadRecord.Prospecting_Escalation_72_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-100)
    );

    Integer edUsers = [
      SELECT COUNT()
      FROM User
      WHERE IsActive = TRUE AND UserRole.Name = 'Utkarsh ED' AND Email != NULL
    ];

    Test.startTest();
    runBatchOn(new List<Lead>{ queryLeadForBatch(leadRecord.Id) });
    Test.stopTest();

    System.assertEquals(
      edUsers > 0,
      queryFlags(leadRecord.Id).Prospecting_Escalation_72_Sent__c
    );
  }

  // If the email cannot be built, NO checkbox may be set (it must be retried next run).
  @IsTest
  static void testFlagNotSetWhenEmailCannotBeBuilt() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingFail');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    // Remove every test override, then tell the service the template does not exist,
    // so the consolidated email cannot be built.
    EscalationMatrixEmailService.clearTestState();
    EscalationMatrixEmailService.setTestTemplateId('Lead No Activity 24h Owner', null);

    Test.startTest();
    runBatchOn(new List<Lead>{ leadRecord });
    Test.stopTest();

    System.assertEquals(false, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }

  // Covers the sender batch itself (start / execute / finish of LeadProspectingConsolidatedEmailBatch).
  @IsTest
  static void testConsolidatedEmailBatchSetsFlag() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'ProspectingSender');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    leadRecord = queryLeadForBatch(leadRecord.Id);

    LeadProspectingConsolidatedEmailBatch.WorkItem item = new LeadProspectingConsolidatedEmailBatch.WorkItem();
    item.groupKey = 'test.recipient@example.com';
    item.templateName = 'Lead No Activity 24h Owner';
    item.recipientType = EscalationMatrixEmailService.RecipientGroup.OWNER;
    item.tierHours = 24;
    item.leads = new List<Lead>{ leadRecord };

    Map<Id, Long> hoursByLeadId = new Map<Id, Long>{ leadRecord.Id => 30 };

    Test.startTest();
    Database.executeBatch(
      new LeadProspectingConsolidatedEmailBatch(
        new List<LeadProspectingConsolidatedEmailBatch.WorkItem>{ item },
        hoursByLeadId
      ),
      10
    );
    Test.stopTest();

    System.assertEquals(true, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }
}