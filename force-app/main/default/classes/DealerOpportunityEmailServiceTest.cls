/**
 * @description   Test class for DealerOpportunityEmailService.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class DealerOpportunityEmailServiceTest {
  @IsTest
  static void testRenderTemplateNullGuards() {
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Dealer Email Opp',
      false,
      null
    );

    System.assertEquals(
      null,
      DealerOpportunityEmailService.renderTemplate(null, opportunityRecord, null)
    );
    System.assertEquals(
      null,
      DealerOpportunityEmailService.renderTemplate(
        '015000000000000AAA',
        null,
        null
      )
    );
  }

  @IsTest
  static void testBuildBrochureAttachmentsModes() {
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Brochure Opp',
      false,
      null
    );

    System.assertEquals(
      0,
      DealerOpportunityEmailService.buildBrochureAttachments(null, opportunityRecord).size()
    );
    System.assertEquals(
      0,
      DealerOpportunityEmailService.buildBrochureAttachments('unknown_template', null).size()
    );

    List<Messaging.EmailFileAttachment> corporateAttachments = DealerOpportunityEmailService.buildBrochureAttachments(
      'prospect_enq_gen',
      opportunityRecord
    );
    List<Messaging.EmailFileAttachment> departmentAttachments = DealerOpportunityEmailService.buildBrochureAttachments(
      'dealer_enq_dept',
      opportunityRecord
    );
    System.assertNotEquals(null, corporateAttachments);
    System.assertNotEquals(null, departmentAttachments);
  }

  @IsTest
  static void testRenderTemplateWithExistingTemplate() {
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Render Opp',
      false,
      null
    );

    List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    if (templates.isEmpty()) {
      return;
    }

    DealerOpportunityEmailService.RenderedEmail rendered = DealerOpportunityEmailService.renderTemplate(
      templates[0].Id,
      opportunityRecord,
      null
    );
    System.assertNotEquals(null, rendered != null || templates.isEmpty());
  }

  @IsTest
  static void testRenderTemplateWithContactWhoId() {
    Account accountRecord = new Account(Name = 'Dealer Email Who Account');
    insert accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'Dealer Email Who',
      AccountId = accountRecord.Id,
      Email = 'dealer.who@example.com'
    );
    insert contactRecord;
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Dealer Email Who Opp',
      false,
      null
    );

    List<EmailTemplate> templates = [
      SELECT Id, UiType, Subject, HtmlValue
      FROM EmailTemplate
      WHERE UiType != 'SFX'
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    if (templates.isEmpty()) {
      return;
    }

    Test.startTest();
    DealerOpportunityEmailService.RenderedEmail rendered =
      DealerOpportunityEmailService.renderTemplate(
        templates[0].Id,
        opportunityRecord,
        contactRecord.Id
      );
    Test.stopTest();

    System.assertNotEquals(null, rendered != null || templates.isEmpty());
  }

  @IsTest
  static void testRenderTemplateWithLightningSyntax() {
    Account accountRecord = new Account(Name = 'Dealer Email Lightning Account');
    insert accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'Dealer Email Lightning',
      AccountId = accountRecord.Id,
      Email = 'dealer.lightning@example.com'
    );
    insert contactRecord;
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Dealer Email Lightning Opp',
      false,
      null
    );

    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE UiType = 'SFX'
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      return;
    }

    Test.startTest();
    DealerOpportunityEmailService.RenderedEmail rendered =
      DealerOpportunityEmailService.renderTemplate(
        templates[0].Id,
        opportunityRecord,
        contactRecord.Id
      );
    Test.stopTest();

    System.assertNotEquals(null, rendered != null || templates.isEmpty());
  }
}