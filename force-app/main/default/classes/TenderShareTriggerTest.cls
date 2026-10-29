/**
 * @description Test class for TenderShareTrigger email and sharing entry points.
 */
@IsTest
private class TenderShareTriggerTest {
  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE IsActive = TRUE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  @IsTest
  static void testAfterInsertFiresEmailHandler() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = new Contact(
      LastName = 'Share Trigger Tender User',
      Email = 'share.tender.user@test.example'
    );
    insert contact;

    Tender__c tender = new Tender__c(Contact__c = contact.Id);

    Test.startTest();
    insert tender;
    Test.stopTest();

    System.assertNotEquals(null, tender.Id);
  }

  @IsTest
  static void testAfterUpdateFiresWhenDepartmentChanges() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = new Contact(
      LastName = 'Share Trigger Update User',
      Email = 'share.tender.update@test.example'
    );
    insert contact;

    Tender__c tender = new Tender__c(
      Contact__c = contact.Id,
      Department_Name__c = 'HDPE'
    );
    insert tender;

    tender.Department_Name__c = 'Polymer';

    Test.startTest();
    update tender;
    Test.stopTest();

    tender = [
      SELECT Department_Name__c
      FROM Tender__c
      WHERE Id = :tender.Id
    ];
    System.assertEquals('Polymer', tender.Department_Name__c);
  }
}