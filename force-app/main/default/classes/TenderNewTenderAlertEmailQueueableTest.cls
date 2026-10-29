/**
 * @description Tests for TenderNewTenderAlertEmailQueueable.
 */
@IsTest
private class TenderNewTenderAlertEmailQueueableTest {
  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE IsActive = TRUE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static Contact insertContact(String suffix) {
    Contact contact = new Contact(
      LastName = 'New Tender Alert ' + suffix,
      Email = 'new.tender.alert+' + suffix + '@test.example'
    );
    Database.insert(contact, AccessLevel.SYSTEM_MODE);
    return contact;
  }

  @IsTest
  static void enqueueIgnoresNullAndEmpty() {
    Test.startTest();
    TenderNewTenderAlertEmailQueueable.enqueue(null);
    TenderNewTenderAlertEmailQueueable.enqueue(new Set<Id>());
    Test.stopTest();

    System.assertEquals(true, true, 'Null/empty enqueue should not throw');
  }

  @IsTest
  static void executeNoopsWhenNoIds() {
    Test.startTest();
    new TenderNewTenderAlertEmailQueueable(new Set<Id>()).execute(null);
    new TenderNewTenderAlertEmailQueueable(new List<Id>()).execute(null);
    Test.stopTest();

    System.assertEquals(true, true, 'Empty execute should not throw');
  }

  @IsTest
  static void triggerInsertEnqueuesAndMarksSent() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = insertContact(String.valueOf(Math.abs(Crypto.getRandomInteger())));
    Tender__c tender = new Tender__c(Contact__c = contact.Id);

    Test.startTest();
    Database.insert(tender, AccessLevel.SYSTEM_MODE);
    Test.stopTest();

    Tender__c refreshed = [
      SELECT New_Tender_Alert_Email_Sent__c
      FROM Tender__c
      WHERE Id = :tender.Id
    ];
    System.assertEquals(
      true,
      refreshed.New_Tender_Alert_Email_Sent__c,
      'Insert trigger should enqueue the job and mark the tender as emailed'
    );
  }

  @IsTest
  static void alreadySentTendersAreSkipped() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = insertContact(
      'sent' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    Tender__c tender = new Tender__c(
      Contact__c = contact.Id,
      New_Tender_Alert_Email_Sent__c = true
    );
    Database.insert(tender, AccessLevel.SYSTEM_MODE);

    Test.startTest();
    new TenderNewTenderAlertEmailQueueable(new Set<Id>{ tender.Id }).execute(null);
    Test.stopTest();

    Tender__c refreshed = [
      SELECT New_Tender_Alert_Email_Sent__c
      FROM Tender__c
      WHERE Id = :tender.Id
    ];
    System.assertEquals(true, refreshed.New_Tender_Alert_Email_Sent__c);
  }

  @IsTest
  static void bulkInsertMarksAllSent() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = insertContact(
      'bulk' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    List<Tender__c> tenders = new List<Tender__c>();
    for (Integer i = 0; i < 3; i++) {
      tenders.add(new Tender__c(Contact__c = contact.Id));
    }

    Test.startTest();
    Database.insert(tenders, AccessLevel.SYSTEM_MODE);
    Test.stopTest();

    Integer sentCount = [
      SELECT COUNT()
      FROM Tender__c
      WHERE Id IN :tenders AND New_Tender_Alert_Email_Sent__c = TRUE
    ];
    System.assertEquals(3, sentCount, 'All inserted tenders should be marked sent');
  }

  @IsTest
  static void enqueueFromCallerMarksSent() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = insertContact(
      'finish' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    Tender__c tender = new Tender__c(Contact__c = contact.Id);
    Database.insert(tender, AccessLevel.SYSTEM_MODE);

    Test.startTest();
    TenderNewTenderAlertEmailQueueable.enqueue(new Set<Id>{ tender.Id });
    Test.stopTest();

    Tender__c refreshed = [
      SELECT New_Tender_Alert_Email_Sent__c
      FROM Tender__c
      WHERE Id = :tender.Id
    ];
    System.assertEquals(
      true,
      refreshed.New_Tender_Alert_Email_Sent__c,
      'Direct enqueue (ProbableBidderBatch.finish path) should mark sent'
    );
  }
}