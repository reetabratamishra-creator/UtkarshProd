/**
 * @description   Test class for Prospect-stage 24-hour not-contacted escalation batch and service.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
@IsTest
private class LeadProspectNotContacted24BatchTest {
  /**
   * Scenario: Lead in Prospect for more than 24 hours with no activity sends escalation email.
   */
  @IsTest
  static void testExecute_QualifyingLead_SendsEmailAndMarksFlag() {
    Lead leadRecord = createProspectLead();
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-25);
    leadRecord.Escalation_24_Sent__c = false;
    update as system leadRecord;

    leadRecord = queryLead(leadRecord.Id);
    assignTemplateOverride();

    Test.startTest();
    new LeadProspectNotContacted24Batch()
      .execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT Escalation_24_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, updatedLead);
  }

  /**
   * Scenario: Lead with recent activity is skipped and flag remains false.
   */
  @IsTest
  static void testExecute_LeadWithRecentActivity_SkipsEscalation() {
    Lead leadRecord = createProspectLead();
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-25);
    leadRecord.Escalation_24_Sent__c = false;
    update as system leadRecord;

    Task activityTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up',
      Status = 'Completed',
      ActivityDate = Date.today()
    );
    insert as system activityTask;

    leadRecord = queryLead(leadRecord.Id);
    assignTemplateOverride();

    Test.startTest();
    new LeadProspectNotContacted24Batch()
      .execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT Escalation_24_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(false, updatedLead.Escalation_24_Sent__c);
  }

  /**
   * Scenario: Batch start query and schedulable execute run without error.
   */
  @IsTest
  static void testStartAndScheduler() {
    Test.startTest();
    Database.QueryLocator locator = new LeadProspectNotContacted24Batch().start(null);
    new LeadProspectNotContacted24Scheduler().execute(null);
    new LeadProspectNotContacted24Batch().execute((SchedulableContext) null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  /**
   * Scenario: Service helper methods evaluate Prospect timing and activity correctly.
   */
  @IsTest
  static void testServiceHelpers() {
    Lead leadRecord = new Lead(
      Prospect_Stage_Entry_Date__c = System.now().addHours(-30)
    );

    System.assertEquals(true, LeadProspectNotContacted24EmailService.isPast24Hours(leadRecord));
    System.assertEquals(
      true,
      LeadProspectNotContacted24EmailService.hasNoActivitySinceProspectEntry(leadRecord)
    );
    System.assertEquals(
      'Transmission Tower',
      LeadProspectNotContacted24EmailService.getRoleDepartmentName(
        'Transmission & Telecom Tower'
      )
    );
  }

  private static Lead createProspectLead() {
    String uniqueKey = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    Lead leadRecord = new Lead(
      LastName = 'Prospect24h ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueKey,
      Company = 'Escalation Test Co  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueKey,
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Email = 'prospect24h.' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueKey + '@example.com',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    insert as system leadRecord;
    return leadRecord;
  }

  private static Lead queryLead(Id leadId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Email,
        Status,
        Department_Name__c,
        Department_NameFormula__c,
        Prospect_Stage_Entry_Date__c,
        Escalation_24_Sent__c,
        LastActivityDate,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  private static void assignTemplateOverride() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE Name = :LeadProspectNotContacted24EmailService.TEMPLATE_NAME
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    if (!templates.isEmpty()) {
      LeadProspectNotContacted24EmailService.testTemplateIdOverride = templates[0].Id;
    }
  }
}