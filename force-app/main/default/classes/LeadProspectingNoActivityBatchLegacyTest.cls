/**
 * @description   Covers the legacy methods of LeadProspectingNoActivityBatch:
 *                legacyExecutePerLead, legacyFinishSingleTransaction,
 *                queueConsolidatedEmails and markSentFlags.
 * @author        Anshita Chanda
 * @date          2026-10-23
 *
 * REQUIRES one change in LeadProspectingNoActivityBatch before this class can be saved:
 * add @TestVisible directly above these two methods
 *     @TestVisible
 *     private void legacyExecutePerLead(List<Lead> scope) { ... }
 *
 *     @TestVisible
 *     private void legacyFinishSingleTransaction() { ... }
 * (queueConsolidatedEmails and markSentFlags are covered through the second one.)
 *
 * It is a SEPARATE class on purpose, so LeadProspectingNoActivityBatchTest keeps compiling
 * whether or not this one is deployed.
 */
@IsTest
private class LeadProspectingNoActivityBatchLegacyTest {
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

  // Original per-lead logic, 24h tier.
  @IsTest
  static void testLegacyExecutePerLead24Hour() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'Legacy24');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    new LeadProspectingNoActivityBatch().legacyExecutePerLead(new List<Lead>{ leadRecord });
    Test.stopTest();

    System.assertEquals(true, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }

  // Original per-lead logic, 48h and 96h tiers.
  @IsTest
  static void testLegacyExecutePerLead48And96Hour() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'Legacy96');
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
    new LeadProspectingNoActivityBatch().legacyExecutePerLead(new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  // Lead below 24h: legacyExecutePerLead sends nothing and flags nothing.
  @IsTest
  static void testLegacyExecutePerLeadBefore24Hours() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'LegacyNew');
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-5)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    new LeadProspectingNoActivityBatch().legacyExecutePerLead(new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  // First consolidated version (single transaction): also covers queueConsolidatedEmails()
  // and markSentFlags() for the 24h, 48h and 96h tiers.
  @IsTest
  static void testLegacyFinishSingleTransaction() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'LegacyFinish');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    leadRecord.Prospecting_Escalation_48_Sent__c = false;
    leadRecord.Prospecting_Escalation_72_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-100)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    LeadProspectingNoActivityBatch batch = new LeadProspectingNoActivityBatch();
    batch.execute(null, new List<Lead>{ leadRecord }); // fills the 24h / 48h / 96h groups
    batch.legacyFinishSingleTransaction(); // sends + flags in one transaction
    Test.stopTest();

    Lead updatedLead = queryFlags(leadRecord.Id);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(true, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  // markSentFlags(): when the email cannot be built, the group is skipped (continue branch)
  // and no checkbox is set.
  @IsTest
  static void testLegacyFinishDoesNotFlagWhenEmailFails() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'LegacyNoFlag');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = queryLeadForBatch(leadRecord.Id);

    Test.startTest();
    LeadProspectingNoActivityBatch batch = new LeadProspectingNoActivityBatch();
    batch.execute(null, new List<Lead>{ leadRecord });

    // Template cannot be found any more -> email not built -> send not successful.
    EscalationMatrixEmailService.clearTestState();
    EscalationMatrixEmailService.setTestTemplateId('Lead No Activity 24h Owner', null);

    batch.legacyFinishSingleTransaction();
    Test.stopTest();

    System.assertEquals(false, queryFlags(leadRecord.Id).Prospecting_Escalation_24_Sent__c);
  }

  // queueConsolidatedEmails() catch block: lead queried WITHOUT Owner.Name makes the digest
  // table builder fail; the error must be swallowed and must not abort the method.
  @IsTest
  static void testLegacyFinishSwallowsEmailException() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'LegacyCatch');
    leadRecord.Prospecting_Escalation_24_Sent__c = false;
    update as system leadRecord;
    LeadProspectingNoActivityBatch.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    Lead incompleteLead = [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Email,
        Department_NameFormula__c,
        Last_Prospecting_Activity__c,
        Prospecting_Escalation_24_Sent__c,
        Prospecting_Escalation_48_Sent__c,
        Prospecting_Escalation_72_Sent__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    Test.startTest();
    LeadProspectingNoActivityBatch batch = new LeadProspectingNoActivityBatch();
    batch.execute(null, new List<Lead>{ incompleteLead });
    batch.legacyFinishSingleTransaction();
    Test.stopTest();

    // Reaching this line proves the exception did not abort the method.
    System.assertNotEquals(null, queryFlags(leadRecord.Id));
  }
}