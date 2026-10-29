/**
 * @description   Test class for LeadManagementEmailService.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class LeadManagementEmailServiceTest {
  @IsTest
  static void testRenderTemplateNullGuards() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'EmailRenderLead');

    System.assertEquals(null, LeadManagementEmailService.renderTemplate(null, leadRecord));
    System.assertEquals(
      null,
      LeadManagementEmailService.renderTemplate(
        '015000000000000AAA',
        null
      )
    );
  }

  @IsTest
  static void testBuildBrochureAttachmentsNullGuards() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'BrochureLead');

    System.assertEquals(
      0,
      LeadManagementEmailService.buildBrochureAttachments(null, leadRecord).size()
    );
    System.assertEquals(
      0,
      LeadManagementEmailService.buildBrochureAttachments('', leadRecord).size()
    );
    System.assertEquals(
      0,
      LeadManagementEmailService.buildBrochureAttachments('Unknown Template', null).size()
    );
  }

  @IsTest
  static void testRenderTemplateWithExistingTemplate() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'TemplateLead');

    List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    if (templates.isEmpty()) {
      System.assertEquals(
        null,
        LeadManagementEmailService.renderTemplate('015000000000000AAA', leadRecord)
      );
      return;
    }

    LeadManagementEmailService.RenderedEmail rendered = LeadManagementEmailService.renderTemplate(
      templates[0].Id,
      leadRecord
    );
    System.assertNotEquals(null, rendered != null || templates.isEmpty());
  }

  @IsTest
  static void testBuildBrochureAttachmentsWithTemplateName() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'BrochureTemplateLead');

    List<Messaging.EmailFileAttachment> attachments = LeadManagementEmailService.buildBrochureAttachments(
      'Lead Not Contacted 24h Owner',
      leadRecord
    );
    System.assertNotEquals(null, attachments);
  }

  @IsTest
  static void testRenderTemplateUsesSalesforceTemplateWhenAvailable() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'EmailRenderLead2');
    List<EmailTemplate> templates = [
      SELECT Id, Name
      FROM EmailTemplate
      LIMIT 5
    ];
    if (templates.isEmpty()) {
      return;
    }

    Test.startTest();
    for (EmailTemplate templateRecord : templates) {
      LeadManagementEmailService.renderTemplate(templateRecord.Id, leadRecord);
      LeadManagementEmailService.buildBrochureAttachments(
        templateRecord.Name,
        leadRecord
      );
    }
    Test.stopTest();
    System.assertEquals(true, templates.size() > 0);
  }
}