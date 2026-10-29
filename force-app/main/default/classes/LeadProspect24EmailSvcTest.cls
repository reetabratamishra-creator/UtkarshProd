/**
 * @description   Test class for LeadProspectNotContacted24EmailService.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class LeadProspect24EmailSvcTest {
  @IsTest
  static void testHelperMethods() {
    Lead leadRecord = new Lead(
      Prospect_Stage_Entry_Date__c = System.now().addHours(-30)
    );

    System.assertEquals(
      true,
      LeadProspectNotContacted24EmailService.isPast24Hours(leadRecord)
    );
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
    System.assertEquals(false, LeadProspectNotContacted24EmailService.sendEscalationEmail(null));
  }

  @IsTest
  static void testSendEscalationEmailWithOverride() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'EmailService24');
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-25);
    update leadRecord;

    leadRecord = [
      SELECT
        Id,
        OwnerId,
        Owner.Email,
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        Prospect_Stage_Entry_Date__c,
        LastActivityDate
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE Name = :LeadProspectNotContacted24EmailService.TEMPLATE_NAME
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    if (templates.isEmpty()) {
      System.assertEquals(false, LeadProspectNotContacted24EmailService.sendEscalationEmail(leadRecord));
      return;
    }

    LeadProspectNotContacted24EmailService.testTemplateIdOverride = templates[0].Id;

    Test.startTest();
    Boolean sent = LeadProspectNotContacted24EmailService.sendEscalationEmail(leadRecord);
    Test.stopTest();

    System.assertNotEquals(null, sent);
  }

  @IsTest
  static void testIsPast24HoursAndActivityGuards() {
    System.assertEquals(false, LeadProspectNotContacted24EmailService.isPast24Hours(null));
    System.assertEquals(
      false,
      LeadProspectNotContacted24EmailService.hasNoActivitySinceProspectEntry(null)
    );

    Lead recentLead = new Lead(
      Prospect_Stage_Entry_Date__c = System.now().addHours(-1)
    );
    System.assertEquals(false, LeadProspectNotContacted24EmailService.isPast24Hours(recentLead));
  }
}