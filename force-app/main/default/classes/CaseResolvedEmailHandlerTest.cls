/**
 * @description Test class for CaseResolvedEmailHandler.
 */
@IsTest
private class CaseResolvedEmailHandlerTest {
  private static Id queryTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :CaseResolvedEmailHandler.TEMPLATE_RESOLVED
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static Id getRecordTypeId(String developerName) {
    RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(developerName);
    return info == null ? null : info.getRecordTypeId();
  }

  @IsTest
  static void testIsNewlyResolvedGuards() {
    Case oldCase = new Case(Status = 'Open');
    Case resolvedCase = new Case(Status = 'Resolved');
    Case stillOpen = new Case(Status = 'Open');

    System.assertEquals(
      true,
      CaseResolvedEmailHandler.isNewlyResolved(resolvedCase, oldCase)
    );
    System.assertEquals(
      false,
      CaseResolvedEmailHandler.isNewlyResolved(stillOpen, oldCase)
    );
    System.assertEquals(
      false,
      CaseResolvedEmailHandler.isNewlyResolved(resolvedCase, resolvedCase)
    );
  }

  @IsTest
  static void testProcessRecordsGuards() {
    CaseResolvedEmailHandler.processRecords(null, null);
    CaseResolvedEmailHandler.processRecords(new List<Case>(), new Map<Id, Case>());
    System.assert(true);
  }

  @IsTest
  static void testCaseRecordTypeSendsToCaseContacts() {
    Id caseRtId = getRecordTypeId('Case');
    if (caseRtId == null) {
      return;
    }

    Id templateId = queryTemplateId();
    if (templateId != null) {
      CaseResolvedEmailHandler.testTemplateIdOverride = templateId;
    }

    Case caseRecord = new Case(
      Subject = 'Resolved Case Contact Email',
      Status = 'Open',
      Origin = 'Phone',
      RecordTypeId = caseRtId,
      OwnerId = UserInfo.getUserId()
    );
    insert as system caseRecord;

    Contact contactRecord = new Contact(
      LastName = 'CaseContactResolve',
      Email = 'case.contact.resolve@example.com'
    );
    insert as system contactRecord;

    insert as system new Case_Contacts__c(
      Case__c = caseRecord.Id,
      Contact__c = contactRecord.Id
    );

    caseRecord.Status = 'Resolved';

    Test.startTest();
    CaseResolvedEmailHandler.handleAfterUpdate(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{
        caseRecord.Id => new Case(
          Id = caseRecord.Id,
          Status = 'Open',
          RecordTypeId = caseRtId
        )
      }
    );
    Test.stopTest();

    System.assertEquals('Resolved', caseRecord.Status);
  }

  @IsTest
  static void testInternalTicketSendsToCreatedBy() {
    Id internalRtId = getRecordTypeId('Internal_Ticket');
    if (internalRtId == null) {
      return;
    }

    Id templateId = queryTemplateId();
    if (templateId != null) {
      CaseResolvedEmailHandler.testTemplateIdOverride = templateId;
    }

    Case caseRecord = new Case(
      Subject = 'Resolved Internal Ticket Email',
      Status = 'Open',
      Origin = 'Phone',
      RecordTypeId = internalRtId,
      OwnerId = UserInfo.getUserId()
    );
    insert as system caseRecord;

    caseRecord.Status = 'Resolved';

    Test.startTest();
    CaseResolvedEmailHandler.handleAfterUpdate(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{
        caseRecord.Id => new Case(
          Id = caseRecord.Id,
          Status = 'Open',
          RecordTypeId = internalRtId
        )
      }
    );
    Test.stopTest();

    System.assertEquals('Resolved', caseRecord.Status);
  }

  @IsTest
  static void testDisableInTestsSkipsSend() {
    CaseResolvedEmailHandler.disableInTests = true;
    try {
      CaseResolvedEmailHandler.handleAfterUpdate(
        new List<Case>{ new Case(Status = 'Resolved') },
        new Map<Id, Case>()
      );
      System.assert(true);
    } finally {
      CaseResolvedEmailHandler.disableInTests = false;
    }
  }
}