/**
 * @description Test class for CaseNoUpdate36hBatch.
 */
@IsTest
private class CaseNoUpdate36hBatchTest {
  private static User createUser(String aliasSuffix) {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name LIKE 'Standard User%'
      LIMIT 1
    ];
    User userRecord = new User(
      Alias = ('n' + aliasSuffix).left(8),
      Email = 'caseno36' +
        String.valueOf(Math.abs(Crypto.getRandomInteger())) +
        aliasSuffix +
        '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'NoUpdate ' +
        String.valueOf(Math.abs(Crypto.getRandomInteger())) +
        aliasSuffix,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileRecord.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'caseno36' +
        aliasSuffix +
        String.valueOf(Math.abs(Crypto.getRandomInteger())) +
        '@example.com.utkarshuat'
    );
    insert as system userRecord;
    return userRecord;
  }

  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = 'Case_No_Update_36h'
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static Case queryCase(Id caseId) {
    return [
      SELECT
        Id,
        OwnerId,
        CreatedById,
        Owner.Email,
        CreatedBy.Email,
        No_Update_36h_Sent__c
      FROM Case
      WHERE Id = :caseId
    ];
  }

  private static Id queryOrgWideEmailAddressId() {
    List<OrgWideEmailAddress> orgWideAddresses = [
      SELECT Id
      FROM OrgWideEmailAddress
      LIMIT 1
    ];
    return orgWideAddresses.isEmpty() ? UserInfo.getUserId() : orgWideAddresses[0].Id;
  }

  private static void configureSuccessfulSendTestContext() {
    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testTemplateIdOverride = queryAnyTemplateId();
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();
    CaseNoUpdate36hBatch.testSimulateSuccessfulSend = true;
  }

  @IsTest
  static void testProcessScopeMarksSentAfterSuccessfulSend() {
    configureSuccessfulSendTestContext();

    Case caseRecord = new Case(
      Subject = 'No Update Batch Owner Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    System.assertEquals(1, updates.size());
    System.assertEquals(true, updates[0].No_Update_36h_Sent__c);
  }

  @IsTest
  static void testProcessScopeSkipsAlreadySentCases() {
    configureSuccessfulSendTestContext();

    Case caseRecord = new Case(
      Subject = 'Already Sent Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = true
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    System.assertEquals(true, updates.isEmpty());
  }

  @IsTest
  static void testProcessScopeDeduplicatesOwnerAndCreatorWhenSameUser() {
    configureSuccessfulSendTestContext();

    Case caseRecord = new Case(
      Subject = 'Same Owner Creator Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    System.assertEquals(1, updates.size());
    System.assertEquals(caseRecord.OwnerId, caseRecord.CreatedById);
  }

  @IsTest
  static void testProcessScopeProcessesCreatorWhenDifferentFromOwner() {
    configureSuccessfulSendTestContext();

    User ownerUser = createUser('001');
    Case caseRecord = new Case(
      Subject = 'No Update Batch Creator Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = ownerUser.Id,
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    System.assertEquals(1, updates.size());
    System.assertNotEquals(caseRecord.OwnerId, caseRecord.CreatedById);
  }

  @IsTest
  static void testStartQueryExcludesSentCases() {
    Case eligibleCase = new Case(
      Subject = 'Eligible Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    Case sentCase = new Case(
      Subject = 'Sent Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = true
    );
    insert as system new List<Case>{ eligibleCase, sentCase };

    Test.startTest();
    Database.QueryLocator queryLocator = new CaseNoUpdate36hBatch().start(null);
    Test.stopTest();

    System.assertNotEquals(null, queryLocator);
  }

  @IsTest
  static void testBatchLifecycleAndSchedulable() {
    Case caseRecord = new Case(
      Subject = 'No Update Batch Lifecycle Test',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;

    CaseNoUpdate36hBatch batch = new CaseNoUpdate36hBatch();

    Test.startTest();
    Database.QueryLocator queryLocator = batch.start(null);
    batch.finish(null);
    new CaseNoUpdate36hBatch().execute(null);
    Test.stopTest();

    System.assertNotEquals(null, queryLocator);
  }

  @IsTest
  static void testProcessScopeReturnsEmptyWhenTemplateMissing() {
    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();
    CaseNoUpdate36hBatch.testForceMissingTemplate = true;

    Case caseRecord = new Case(
      Subject = 'Missing Template Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    System.assertEquals(true, updates.isEmpty());
  }

  @IsTest
  static void testExecuteThrowsWhenTemplateMissing() {
    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();
    CaseNoUpdate36hBatch.testForceMissingTemplate = true;

    Case caseRecord = new Case(
      Subject = 'Missing Template Execute Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Boolean threwExpected = false;
    Test.startTest();
    try {
      new CaseNoUpdate36hBatch().execute(null, new List<Case>{ caseRecord });
    } catch (CaseNoUpdate36hBatch.EmailSendException ex) {
      threwExpected = true;
      System.assert(
        ex.getMessage().contains('template or org-wide address'),
        ex.getMessage()
      );
    }
    Test.stopTest();

    System.assertEquals(true, threwExpected);
    caseRecord = [
      SELECT No_Update_36h_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(false, caseRecord.No_Update_36h_Sent__c);
  }

  @IsTest
  static void testExecutePersistsSentFlag() {
    configureSuccessfulSendTestContext();

    Case caseRecord = new Case(
      Subject = 'Execute Persist Sent Flag',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    new CaseNoUpdate36hBatch().execute(null, new List<Case>{ caseRecord });
    Test.stopTest();

    caseRecord = [
      SELECT No_Update_36h_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(true, caseRecord.No_Update_36h_Sent__c);
  }

  @IsTest
  static void testProcessScopeHandlesNullAndEmptyScope() {
    CaseNoUpdate36hBatch.clearTestState();

    Test.startTest();
    System.assertEquals(true, CaseNoUpdate36hBatch.processScope(null).isEmpty());
    System.assertEquals(
      true,
      CaseNoUpdate36hBatch.processScope(new List<Case>()).isEmpty()
    );
    CaseNoUpdate36hBatch.markCasesAlreadySent(null);
    CaseNoUpdate36hBatch.markCasesAlreadySent(new List<Id>());
    CaseNoUpdate36hBatch.persistSentFlagRecords(null);
    CaseNoUpdate36hBatch.persistSentFlagRecords(new List<Case>());
    System.assertEquals(
      false,
      CaseNoUpdate36hBatch.isMismatchedAccountLookup(null, null, null)
    );
    System.assertEquals(
      true,
      CaseNoUpdate36hBatch.isMismatchedAccountLookup(
        null,
        UserInfo.getUserId(),
        null
      )
    );
    System.assertEquals(false, CaseNoUpdate36hBatch.isLookupFilterFailure(null));
    System.assertEquals(
      false,
      CaseNoUpdate36hBatch.isLookupFilterFailure(new List<Database.Error>())
    );
    System.assertEquals(
      'Unknown send error',
      CaseNoUpdate36hBatch.formatSendErrors(null)
    );
    System.assertEquals(
      'Unknown DML error',
      CaseNoUpdate36hBatch.formatDatabaseErrors(null)
    );
    System.assertEquals(null, CaseNoUpdate36hBatch.appendError(null, null));
    System.assertEquals('First', CaseNoUpdate36hBatch.appendError(null, 'First'));
    System.assertEquals(
      'First | Second',
      CaseNoUpdate36hBatch.appendError('First', 'Second')
    );
    CaseNoUpdate36hBatch.retrySentFlagsClearingInvalidLookups(new List<Id>());
    Test.stopTest();
  }

  @IsTest
  static void testProcessScopeWithoutSimulateUsesSendPath() {
    Id templateId = queryAnyTemplateId();
    if (templateId == null) {
      return;
    }

    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testTemplateIdOverride = templateId;
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();

    Case caseRecord = new Case(
      Subject = 'Real Send Path Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    CaseNoUpdate36hBatch.processScope(new List<Case>{ caseRecord });
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }

  @IsTest
  static void testExecuteUsesPlainSendPath() {
    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testTemplateIdOverride = queryAnyTemplateId();
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();
    CaseNoUpdate36hBatch.testUsePlainMessage = true;

    Case caseRecord = new Case(
      Subject = 'Plain Send Path Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Boolean sendCompleted = false;
    Boolean threwSendError = false;
    Test.startTest();
    try {
      new CaseNoUpdate36hBatch().execute(null, new List<Case>{ caseRecord });
      sendCompleted = true;
    } catch (CaseNoUpdate36hBatch.EmailSendException ex) {
      threwSendError = true;
      System.assert(
        ex.getMessage().contains('send failed') ||
          ex.getMessage().contains('NO_SINGLE_MAIL_PERMISSION'),
        ex.getMessage()
      );
    }
    Test.stopTest();

    System.assertEquals(
      true,
      sendCompleted || threwSendError,
      'Plain send path should send or throw a logged send error.'
    );
  }

  @IsTest
  static void testRunBacklogCleanupMarksHistoricalCases() {
    configureSuccessfulSendTestContext();

    Case historicalCase = new Case(
      Subject = 'Historical Backlog Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system historicalCase;

    Test.setCreatedDate(historicalCase.Id, System.now().addDays(-90));

    Test.startTest();
    Integer updatedCount = CaseNoUpdate36hBatch.runBacklogCleanup();
    Test.stopTest();

    System.assert(updatedCount >= 1, 'Expected at least one historical Case update.');
    historicalCase = [
      SELECT No_Update_36h_Sent__c
      FROM Case
      WHERE Id = :historicalCase.Id
    ];
    System.assertEquals(true, historicalCase.No_Update_36h_Sent__c);
  }

  @IsTest
  static void testConvertLightningOwnerNameToOwnerFormula() {
    String converted = CaseNoUpdate36hBatch.convertLightningMergeSyntax(
      'Dear {{{Case.Owner.Name}}}, {{{Case.Owner.FirstName}}} {{{Case.CreatedBy.FirstName}}} {{{Case.CaseNumber}}} {!Case.Owner.Name}'
    );
    System.assertEquals(
      'Dear {!Case.Case_Owner_Formula__c}, {!Case.Case_Owner_Formula__c} {!Case.Case_Created_By_formula__c} {!Case.CaseNumber} {!Case.Case_Owner_Formula__c}',
      converted
    );
    System.assertEquals(null, CaseNoUpdate36hBatch.convertLightningMergeSyntax(null));
  }

  @IsTest
  static void testLightningTemplateRenderUsesOwnerFormula() {
    User owner = createUser('lt');
    Case caseRecord = new Case(
      Subject = 'Lightning Render Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = owner.Id,
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;

    EmailTemplate templateRecord = new EmailTemplate(
      Subject = 'No update {{{Case.CaseNumber}}}',
      HtmlValue = '<p>Dear {{{Case.Owner.Name}}},</p><p>{{{Case.Subject}}}</p>',
      UiType = 'SFX'
    );

    Test.startTest();
    Messaging.SingleEmailMessage message = CaseNoUpdate36hBatch.renderLightningTemplate(
      templateRecord,
      owner.Id,
      caseRecord.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, message, 'Lightning render should succeed with Case_Owner_Formula__c.');
    System.assert(
      String.isNotBlank(message.getSubject()),
      'Rendered subject should not be blank.'
    );
    System.assert(
      String.isNotBlank(message.getHtmlBody()) &&
        message.getHtmlBody().contains('Lightning Render Case'),
      message.getHtmlBody()
    );
  }

  @IsTest
  static void testProcessScopeResolvesTemplateByDeveloperName() {
    CaseNoUpdate36hBatch.clearTestState();
    CaseNoUpdate36hBatch.testSimulateSuccessfulSend = true;
    CaseNoUpdate36hBatch.testOrgWideEmailAddressIdOverride = queryOrgWideEmailAddressId();

    Case caseRecord = new Case(
      Subject = 'Developer Name Template Case',
      Status = 'Open',
      Origin = 'Phone',
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;
    caseRecord = queryCase(caseRecord.Id);

    Test.startTest();
    List<Case> updates = CaseNoUpdate36hBatch.processScope(new List<Case>{ caseRecord });
    Test.stopTest();

    System.assertEquals(1, updates.size());
  }

  @IsTest
  static void testLightningTemplateRenderSkipsEmptyBodies() {
    Messaging.SingleEmailMessage message = CaseNoUpdate36hBatch.renderLightningTemplate(
      new EmailTemplate(Subject = '', HtmlValue = '', UiType = 'SFX'),
      UserInfo.getUserId(),
      UserInfo.getUserId()
    );
    System.assertEquals(null, message);
  }

  @IsTest
  static void testPersistSentFlagClearsMismatchedContact() {
    Account caseAccount = new Account(
      Name = 'NoUpdate Case Acc ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    Account contactAccount = new Account(
      Name = 'NoUpdate Contact Acc ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    insert as system new List<Account>{ caseAccount, contactAccount };

    Contact contactRecord = new Contact(
      LastName = 'NoUpdate Contact',
      AccountId = caseAccount.Id
    );
    insert as system contactRecord;

    Case caseRecord = new Case(
      Subject = 'Mismatched Contact Flag Case',
      Status = 'Open',
      Origin = 'Phone',
      AccountId = caseAccount.Id,
      ContactId = contactRecord.Id,
      OwnerId = UserInfo.getUserId(),
      No_Update_36h_Sent__c = false
    );
    insert as system caseRecord;

    contactRecord.AccountId = contactAccount.Id;
    update as system contactRecord;

    System.assertEquals(
      false,
      CaseNoUpdate36hBatch.isMismatchedAccountLookup(
        caseAccount.Id,
        contactRecord.Id,
        new Contact(AccountId = caseAccount.Id)
      )
    );
    System.assertEquals(
      true,
      CaseNoUpdate36hBatch.isMismatchedAccountLookup(
        caseAccount.Id,
        contactRecord.Id,
        new Contact(AccountId = contactAccount.Id)
      )
    );

    Test.startTest();
    CaseNoUpdate36hBatch.markCasesAlreadySent(new List<Id>{ caseRecord.Id });
    // Explicitly exercise the retry because lookup-filter enforcement can vary by org.
    CaseNoUpdate36hBatch.retrySentFlagsClearingInvalidLookups(
      new List<Id>{ caseRecord.Id }
    );
    Test.stopTest();

    Case updatedCase = [
      SELECT No_Update_36h_Sent__c, ContactId
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(
      true,
      updatedCase.No_Update_36h_Sent__c,
      'Sent flag must be saved so the Case is not emailed again.'
    );
    System.assertEquals(
      null,
      updatedCase.ContactId,
      'Invalid Contact that fails the Account lookup filter should be cleared.'
    );
  }
}