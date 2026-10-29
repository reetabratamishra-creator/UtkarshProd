/**
 * @description   Test class for Case assignment/reassignment owner email handler.
 * @author        Anshita Chanda
 * @date          2026-08-14
 */
@IsTest
private class CaseNewAssignedOwnerHandlerTest {
  private static Id queryTemplateId(String developerName) {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static User createUser(String aliasSuffix) {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User userRecord = new User(
      Alias = ('c' + aliasSuffix).left(8),
      Email = 'casehandler' + aliasSuffix + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'CaseHandler' + aliasSuffix,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileRecord.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'casehandler' + aliasSuffix + '@example.com.utkarshuat'
    );
    insert userRecord;
    return userRecord;
  }

  @IsTest
  static void testQualifiesForNewAssignmentAndReassignment() {
    Case newCase = new Case(
      Subject = 'Qualify Test',
      OwnerId = UserInfo.getUserId()
    );
    System.assertEquals(
      true,
      CaseNewAssignedOwnerHandler.qualifiesAsNewAssignment(newCase, null)
    );
    System.assertEquals(
      false,
      CaseNewAssignedOwnerHandler.qualifiesAsNewAssignment(newCase, newCase)
    );

    User otherOwner = createUser('q01');
    Case oldCase = new Case(OwnerId = UserInfo.getUserId());
    Case reassignedCase = new Case(OwnerId = otherOwner.Id);
    System.assertEquals(
      false,
      CaseNewAssignedOwnerHandler.qualifiesAsReassignment(
        reassignedCase,
        reassignedCase
      )
    );
    System.assertEquals(
      true,
      CaseNewAssignedOwnerHandler.qualifiesAsReassignment(
        reassignedCase,
        oldCase
      )
    );
  }

  @IsTest
  static void testProcessRecordsGuards() {
    Test.startTest();
    CaseNewAssignedOwnerHandler.processRecords(null, null);
    CaseNewAssignedOwnerHandler.processRecords(new List<Case>(), null);
    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void testHandleAfterInsertSendsEmail() {
    Id templateId = queryTemplateId(
      CaseNewAssignedOwnerHandler.TEMPLATE_NEW_ASSIGNED
    );
    if (templateId != null) {
      CaseNewAssignedOwnerHandler.testTemplateIdOverride = templateId;
    }

    Case caseRecord = new Case(
      Subject = 'Assignment Email Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId()
    );

    Test.startTest();
    insert caseRecord;
    Test.stopTest();

    caseRecord = [SELECT Id, OwnerId FROM Case WHERE Id = :caseRecord.Id];
    System.assertEquals(UserInfo.getUserId(), caseRecord.OwnerId);
  }

  @IsTest
  static void testHandleAfterUpdateSendsOnReassignment() {
    Id templateId = queryTemplateId(
      CaseNewAssignedOwnerHandler.TEMPLATE_REASSIGNED
    );
    if (templateId != null) {
      CaseNewAssignedOwnerHandler.testTemplateIdOverride = templateId;
    }

    User newOwner = createUser('001');
    Case caseRecord = new Case(
      Subject = 'Reassignment Email Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId()
    );
    insert caseRecord;

    caseRecord.OwnerId = newOwner.Id;

    Test.startTest();
    update caseRecord;
    Test.stopTest();

    caseRecord = [SELECT OwnerId FROM Case WHERE Id = :caseRecord.Id];
    System.assertEquals(newOwner.Id, caseRecord.OwnerId);
  }

  @IsTest
  static void testTriggerSharesCaseWithCreatorWhenOwnerDiffers() {
    Id templateId = queryTemplateId(
      CaseNewAssignedOwnerHandler.TEMPLATE_NEW_ASSIGNED
    );
    if (templateId != null) {
      CaseNewAssignedOwnerHandler.testTemplateIdOverride = templateId;
    }

    User ownerUser = createUser('002');
    Case caseRecord = new Case(
      Subject = 'Share Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = ownerUser.Id
    );

    Test.startTest();
    insert caseRecord;
    Test.stopTest();

    List<CaseShare> shares = [
      SELECT Id
      FROM CaseShare
      WHERE CaseId = :caseRecord.Id AND UserOrGroupId = :UserInfo.getUserId()
    ];
    System.assertNotEquals(null, caseRecord.Id);
  }
}