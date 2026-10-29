/**
 * @description Sends a one-time 36-hour no-update reminder email to the Case owner
 *              and creator (when different). Uses a sent flag and a lookback window
 *              so stale historical Cases are not re-emailed every schedule run.
 * @author Anshita Chanda
 * @date 2026-08-24
 */
public without sharing class CaseNoUpdate36hBatch implements Database.Batchable<SObject>, Schedulable {
  @TestVisible
  private static final Integer BATCH_SIZE = 50;

  @TestVisible
  private static final Integer STALE_HOURS = 36;

  @TestVisible
  private static final Integer LOOKBACK_DAYS = 60;

  @TestVisible
  private static final Integer BACKLOG_UPDATE_LIMIT = 10000;

  private static final String TEMPLATE_DEVELOPER_NAME = 'Case_No_Update_36h';
  private static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

  @TestVisible
  private static Id testTemplateIdOverride;

  @TestVisible
  private static Id testOrgWideEmailAddressIdOverride;

  @TestVisible
  private static Boolean testSimulateSuccessfulSend = false;

  @TestVisible
  private static Boolean testForceMissingTemplate = false;

  @TestVisible
  private static Boolean testUsePlainMessage = false;

  private static Id cachedTemplateId;
  private static EmailTemplate cachedTemplateRecord;
  private static Boolean templateResolved = false;
  private static Id cachedOrgWideEmailAddressId;
  private static Boolean orgWideEmailResolved = false;
  private static String lastSendFailureMessage;

  public class EmailSendException extends Exception {
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseNoUpdate36hBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime staleCutoff = System.now().addHours(-STALE_HOURS);
    Datetime lookbackStart = System.now().addDays(-LOOKBACK_DAYS);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          OwnerId,
          CreatedById,
          Owner.Email,
          CreatedBy.Email,
          No_Update_36h_Sent__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND No_Update_36h_Sent__c = FALSE
          AND LastModifiedDate <= :staleCutoff
          AND CreatedDate >= :lookbackStart
          AND (Owner.Email != NULL OR CreatedBy.Email != NULL)
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    lastSendFailureMessage = null;
    List<Case> casesToUpdate = processScope(scope);
    persistSentFlagRecords(casesToUpdate);
    // Do not throw after emails were sent. An uncaught batch exception rolls back
    // the sent flags, so the same Cases are emailed again on the next run.
    if (String.isNotBlank(lastSendFailureMessage) && casesToUpdate.isEmpty()) {
      throw new EmailSendException(lastSendFailureMessage);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  /**
   * @description One-time helper to mark historical Cases outside the lookback
   *              window so they are not emailed when the batch is enabled.
   * @return Number of Cases updated.
   */
  public static Integer runBacklogCleanup() {
    Datetime lookbackStart = System.now().addDays(-LOOKBACK_DAYS);
    List<Case> staleCases = [
      SELECT Id
      FROM Case
      WHERE
        IsClosed = FALSE
        AND No_Update_36h_Sent__c = FALSE
        AND CreatedDate < :lookbackStart
      LIMIT :BACKLOG_UPDATE_LIMIT
    ];

    if (staleCases.isEmpty()) {
      return 0;
    }

    for (Case caseRecord : staleCases) {
      caseRecord.No_Update_36h_Sent__c = true;
    }

    persistSentFlagRecords(staleCases);
    return staleCases.size();
  }

  /**
   * @description Builds deduplicated recipient emails, sends them, and returns Cases
   *              whose No_Update_36h_Sent__c flag should be set after a successful send.
   */
  @TestVisible
  static List<Case> processScope(List<Case> scope) {
    List<Case> casesToUpdate = new List<Case>();
    if (scope == null || scope.isEmpty()) {
      return casesToUpdate;
    }

    Id templateId = resolveTemplateId();
    Id orgWideEmailAddressId = resolveOrgWideEmailAddressId();
    if (templateId == null || orgWideEmailAddressId == null) {
      String skipReason =
        'CaseNoUpdate36hBatch skipped send: template or org-wide address was not found. ' +
        'Template=' +
        TEMPLATE_DEVELOPER_NAME +
        ', OrgWide=' +
        ORG_WIDE_SENDER_EMAIL;
      System.debug(LoggingLevel.ERROR, skipReason);
      lastSendFailureMessage = skipReason;
      return casesToUpdate;
    }

    List<EmailRequest> emailRequests = new List<EmailRequest>();
    for (Case caseRecord : scope) {
      if (caseRecord == null || caseRecord.No_Update_36h_Sent__c == true) {
        continue;
      }
      emailRequests.addAll(buildEmailRequests(caseRecord, templateId, orgWideEmailAddressId));
    }

    Set<Id> successfulCaseIds = sendEmailRequests(emailRequests);
    for (Id caseId : successfulCaseIds) {
      casesToUpdate.add(new Case(Id = caseId, No_Update_36h_Sent__c = true));
    }

    return casesToUpdate;
  }

  @TestVisible
  private class EmailRequest {
    Id caseId;
    Messaging.SingleEmailMessage message;

    EmailRequest(Id caseId, Messaging.SingleEmailMessage message) {
      this.caseId = caseId;
      this.message = message;
    }
  }

  private static List<EmailRequest> buildEmailRequests(
    Case caseRecord,
    Id templateId,
    Id orgWideEmailAddressId
  ) {
    List<EmailRequest> requests = new List<EmailRequest>();
    Set<Id> recipientUserIds = new Set<Id>();
    Set<String> recipientEmails = new Set<String>();

    addRecipientRequest(
      requests,
      caseRecord,
      caseRecord.OwnerId,
      caseRecord.Owner == null ? null : caseRecord.Owner.Email,
      templateId,
      orgWideEmailAddressId,
      recipientUserIds,
      recipientEmails
    );
    addRecipientRequest(
      requests,
      caseRecord,
      caseRecord.CreatedById,
      caseRecord.CreatedBy == null ? null : caseRecord.CreatedBy.Email,
      templateId,
      orgWideEmailAddressId,
      recipientUserIds,
      recipientEmails
    );

    return requests;
  }

  private static void addRecipientRequest(
    List<EmailRequest> requests,
    Case caseRecord,
    Id userId,
    String email,
    Id templateId,
    Id orgWideEmailAddressId,
    Set<Id> recipientUserIds,
    Set<String> recipientEmails
  ) {
    if (caseRecord == null || userId == null || String.isBlank(email)) {
      return;
    }

    String normalizedEmail = email.trim().toLowerCase();
    if (
      recipientUserIds.contains(userId) ||
      recipientEmails.contains(normalizedEmail)
    ) {
      return;
    }

    recipientUserIds.add(userId);
    recipientEmails.add(normalizedEmail);

    if (Test.isRunningTest() && testSimulateSuccessfulSend) {
      Messaging.SingleEmailMessage testMessage = new Messaging.SingleEmailMessage();
      testMessage.setToAddresses(new List<String>{ email.trim() });
      testMessage.setSubject('Case no-update test');
      testMessage.setPlainTextBody('Case no-update test');
      testMessage.setSaveAsActivity(false);
      requests.add(new EmailRequest(caseRecord.Id, testMessage));
      return;
    }

    if (Test.isRunningTest() && testUsePlainMessage) {
      Messaging.SingleEmailMessage plainMessage = new Messaging.SingleEmailMessage();
      plainMessage.setToAddresses(new List<String>{ email.trim() });
      plainMessage.setSubject('Case no-update send path');
      plainMessage.setPlainTextBody('Case no-update send path');
      plainMessage.setSaveAsActivity(false);
      requests.add(new EmailRequest(caseRecord.Id, plainMessage));
      return;
    }

    Messaging.SingleEmailMessage message = buildUserRecipientMessage(
      templateId,
      userId,
      caseRecord.Id,
      email.trim(),
      orgWideEmailAddressId
    );
    if (message == null) {
      return;
    }
    requests.add(new EmailRequest(caseRecord.Id, message));
  }

  /**
   * Salesforce does not allow WhatId when TargetObjectId is a User.
   * Lightning templates are rendered with classic merge syntax, matching
   * CaseSLAEscalationEmailService, then sent to the User email address.
   */
  private static Messaging.SingleEmailMessage buildUserRecipientMessage(
    Id templateId,
    Id userId,
    Id caseId,
    String recipientEmail,
    Id orgWideEmailAddressId
  ) {
    if (
      templateId == null ||
      userId == null ||
      caseId == null ||
      String.isBlank(recipientEmail)
    ) {
      return null;
    }

    EmailTemplate templateRecord = resolveTemplateRecord();
    if (templateRecord == null) {
      return null;
    }

    Messaging.SingleEmailMessage message;
    try {
      if (isLightningTemplate(templateRecord)) {
        message = renderLightningTemplate(
          templateRecord,
          userId,
          caseId
        );
      } else {
        message = Messaging.renderStoredEmailTemplate(templateId, userId, caseId);
      }
    } catch (Exception ex) {
      String renderError =
        'CaseNoUpdate36hBatch template render failed for Case ' +
        caseId +
        ': ' +
        ex.getMessage();
      System.debug(LoggingLevel.ERROR, renderError);
      lastSendFailureMessage = appendError(lastSendFailureMessage, renderError);
      return null;
    }

    if (message == null) {
      String renderError =
        'CaseNoUpdate36hBatch template render failed for Case ' +
        caseId +
        ': empty Lightning template body';
      System.debug(LoggingLevel.ERROR, renderError);
      lastSendFailureMessage = appendError(lastSendFailureMessage, renderError);
      return null;
    }

    message.setTargetObjectId(null);
    message.setToAddresses(new List<String>{ recipientEmail });
    message.setSaveAsActivity(false);
    message.setTreatTargetObjectAsRecipient(false);
    if (orgWideEmailAddressId != null) {
      message.setOrgWideEmailAddressId(orgWideEmailAddressId);
    }
    return message;
  }

  @TestVisible
  private static Messaging.SingleEmailMessage renderLightningTemplate(
    EmailTemplate templateRecord,
    Id userId,
    Id caseId
  ) {
    String subject = convertLightningMergeSyntax(templateRecord.Subject);
    String html = convertLightningMergeSyntax(templateRecord.HtmlValue);
    List<String> bodies = new List<String>();
    Boolean hasSubject = String.isNotBlank(subject);
    Boolean hasHtml = String.isNotBlank(html);
    if (hasSubject) {
      bodies.add(subject);
    }
    if (hasHtml) {
      bodies.add(html);
    }
    if (bodies.isEmpty()) {
      return null;
    }

    List<Messaging.RenderEmailTemplateBodyResult> results = Messaging.renderEmailTemplate(
      String.valueOf(userId),
      String.valueOf(caseId),
      bodies
    );

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    Integer resultIndex = 0;
    if (hasSubject) {
      if (!results[resultIndex].getSuccess()) {
        return null;
      }
      message.setSubject(results[resultIndex].getMergedBody());
      resultIndex++;
    }
    if (hasHtml) {
      if (!results[resultIndex].getSuccess()) {
        return null;
      }
      message.setHtmlBody(results[resultIndex].getMergedBody());
    }
    return message;
  }

  private static Boolean isLightningTemplate(EmailTemplate templateRecord) {
    return templateRecord != null &&
      (templateRecord.UiType == 'SFX' ||
        (String.isNotBlank(templateRecord.HtmlValue) &&
        templateRecord.HtmlValue.contains('{{{')));
  }

  @TestVisible
  private static String convertLightningMergeSyntax(String value) {
    if (String.isBlank(value)) {
      return value;
    }
    return value
      .replace('{{{Case.Owner.FirstName}}}', '{!Case.Case_Owner_Formula__c}')
      .replace('{{{Case.Owner.Name}}}', '{!Case.Case_Owner_Formula__c}')
      .replace('{{{Case.CreatedBy.FirstName}}}', '{!Case.Case_Created_By_formula__c}')
      .replaceAll('\\{\\{\\{', '{!')
      .replaceAll('\\}\\}\\}', '}')
      .replace('{!Case.Owner.FirstName}', '{!Case.Case_Owner_Formula__c}')
      .replace('{!Case.Owner.Name}', '{!Case.Case_Owner_Formula__c}')
      .replace('{!Case.OwnerFullName}', '{!Case.Case_Owner_Formula__c}')
      .replace('{!Case.CreatedBy.FirstName}', '{!Case.Case_Created_By_formula__c}');
  }

  private static Set<Id> sendEmailRequests(List<EmailRequest> emailRequests) {
    Set<Id> successfulCaseIds = new Set<Id>();
    if (emailRequests == null || emailRequests.isEmpty()) {
      return successfulCaseIds;
    }

    if (Test.isRunningTest() && testSimulateSuccessfulSend) {
      for (EmailRequest request : emailRequests) {
        successfulCaseIds.add(request.caseId);
      }
      return successfulCaseIds;
    }

    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    List<Id> caseIdsByMessage = new List<Id>();
    for (EmailRequest request : emailRequests) {
      messages.add(request.message);
      caseIdsByMessage.add(request.caseId);
    }

    Integer index = 0;
    while (index < messages.size()) {
      List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
      List<Id> caseIdChunk = new List<Id>();
      while (index < messages.size() && chunk.size() < 10) {
        chunk.add(messages[index]);
        caseIdChunk.add(caseIdsByMessage[index]);
        index++;
      }

      try {
        Messaging.SendEmailResult[] results = Messaging.sendEmail(chunk, false);
        for (Integer resultIndex = 0; resultIndex < results.size(); resultIndex++) {
          if (resultIndex >= caseIdChunk.size()) {
            continue;
          }
          if (results[resultIndex].isSuccess()) {
            successfulCaseIds.add(caseIdChunk[resultIndex]);
            continue;
          }
          String sendError =
            'CaseNoUpdate36hBatch send failed for Case ' +
            caseIdChunk[resultIndex] +
            ': ' +
            formatSendErrors(results[resultIndex].getErrors());
          System.debug(LoggingLevel.ERROR, sendError);
          lastSendFailureMessage = appendError(lastSendFailureMessage, sendError);
        }
      } catch (Exception ex) {
        if (isEmailLimitExceeded(ex)) {
          String limitError =
            'CaseNoUpdate36hBatch stopped after email limit: ' + ex.getMessage();
          System.debug(LoggingLevel.ERROR, limitError);
          lastSendFailureMessage = appendError(lastSendFailureMessage, limitError);
          break;
        }
        System.debug(
          LoggingLevel.ERROR,
          'CaseNoUpdate36hBatch send exception: ' + ex.getMessage()
        );
        throw ex;
      }
    }

    return successfulCaseIds;
  }

  /**
   * Marks Cases as already emailed so the next schedule run will skip them.
   * Uses the same lookup-filter retry as the batch flag save.
   */
  public static void markCasesAlreadySent(List<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }
    List<Case> records = new List<Case>();
    for (Id caseId : caseIds) {
      if (caseId != null) {
        records.add(new Case(Id = caseId, No_Update_36h_Sent__c = true));
      }
    }
    persistSentFlagRecords(records);
  }

  /**
   * Lookup filters on Case.ContactId / Case.Order__c re-validate on any update.
   * If Contact or Order no longer belongs to the Case Account, the sent-flag
   * update would fail and the same Case would be emailed again.
   */
  @TestVisible
  static void persistSentFlagRecords(List<Case> casesToUpdate) {
    if (casesToUpdate == null || casesToUpdate.isEmpty()) {
      return;
    }

    Database.SaveResult[] saveResults = Database.update(casesToUpdate, false);
    List<Id> lookupFilterFailedIds = new List<Id>();
    for (Integer i = 0; i < saveResults.size(); i++) {
      if (saveResults[i].isSuccess()) {
        continue;
      }
      Id recordId = i < casesToUpdate.size() ? casesToUpdate[i].Id : null;
      if (recordId != null && isLookupFilterFailure(saveResults[i].getErrors())) {
        lookupFilterFailedIds.add(recordId);
        continue;
      }
      logSaveFailure(recordId, saveResults[i].getErrors());
    }

    if (!lookupFilterFailedIds.isEmpty()) {
      retrySentFlagsClearingInvalidLookups(lookupFilterFailedIds);
    }
  }

  @TestVisible
  private static void retrySentFlagsClearingInvalidLookups(List<Id> caseIds) {
    List<Case> existingCases = [
      SELECT
        Id,
        AccountId,
        ContactId,
        Contact.AccountId,
        Order__c,
        Order__r.AccountId
      FROM Case
      WHERE Id IN :caseIds
    ];
    List<Case> retryRecords = new List<Case>();
    for (Case existing : existingCases) {
      Case retryRecord = new Case(Id = existing.Id, No_Update_36h_Sent__c = true);
      if (isMismatchedAccountLookup(existing.AccountId, existing.ContactId, existing.Contact)) {
        retryRecord.ContactId = null;
      }
      if (
        existing.Order__c != null &&
        (existing.Order__r == null || existing.Order__r.AccountId != existing.AccountId)
      ) {
        retryRecord.Order__c = null;
      }
      retryRecords.add(retryRecord);
    }

    if (retryRecords.isEmpty()) {
      return;
    }

    Database.SaveResult[] retryResults = Database.update(retryRecords, false);
    for (Integer i = 0; i < retryResults.size(); i++) {
      if (retryResults[i].isSuccess()) {
        continue;
      }
      Id recordId = i < retryRecords.size() ? retryRecords[i].Id : null;
      logSaveFailure(recordId, retryResults[i].getErrors());
    }
  }

  @TestVisible
  private static Boolean isMismatchedAccountLookup(
    Id caseAccountId,
    Id lookupId,
    Contact relatedContact
  ) {
    if (lookupId == null) {
      return false;
    }
    if (caseAccountId == null || relatedContact == null) {
      return true;
    }
    return relatedContact.AccountId != caseAccountId;
  }

  @TestVisible
  private static Boolean isLookupFilterFailure(Database.Error[] errors) {
    if (errors == null || errors.isEmpty()) {
      return false;
    }
    for (Database.Error error : errors) {
      if (error.getStatusCode() == StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION) {
        return true;
      }
    }
    return false;
  }

  private static void logSaveFailure(Id recordId, Database.Error[] errors) {
    String dmlError =
      'CaseNoUpdate36hBatch flag update failed for Case ' +
      String.valueOf(recordId) +
      ': ' +
      formatDatabaseErrors(errors);
    System.debug(LoggingLevel.ERROR, dmlError);
    lastSendFailureMessage = appendError(lastSendFailureMessage, dmlError);
  }

  private static Id resolveTemplateId() {
    EmailTemplate templateRecord = resolveTemplateRecord();
    return templateRecord == null ? null : templateRecord.Id;
  }

  private static EmailTemplate resolveTemplateRecord() {
    if (Test.isRunningTest() && testForceMissingTemplate) {
      return null;
    }

    Id overrideTemplateId = Test.isRunningTest() ? testTemplateIdOverride : null;
    if (templateResolved && cachedTemplateRecord != null) {
      if (overrideTemplateId == null || cachedTemplateRecord.Id == overrideTemplateId) {
        return cachedTemplateRecord;
      }
    }
    if (templateResolved && overrideTemplateId == null) {
      return cachedTemplateRecord;
    }

    List<EmailTemplate> templates;
    if (overrideTemplateId != null) {
      templates = [
        SELECT Id, Subject, HtmlValue, Body, UiType
        FROM EmailTemplate
        WHERE Id = :overrideTemplateId
        LIMIT 1
      ];
    } else {
      templates = [
        SELECT Id, Subject, HtmlValue, Body, UiType
        FROM EmailTemplate
        WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
        LIMIT 1
      ];
    }

    cachedTemplateRecord = templates.isEmpty() ? null : templates[0];
    cachedTemplateId = cachedTemplateRecord == null ? null : cachedTemplateRecord.Id;
    templateResolved = true;
    return cachedTemplateRecord;
  }

  private static Id resolveOrgWideEmailAddressId() {
    if (Test.isRunningTest() && testOrgWideEmailAddressIdOverride != null) {
      return testOrgWideEmailAddressIdOverride;
    }

    if (orgWideEmailResolved) {
      return cachedOrgWideEmailAddressId;
    }

    List<OrgWideEmailAddress> orgWideAddresses = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = :ORG_WIDE_SENDER_EMAIL
      LIMIT 1
    ];
    cachedOrgWideEmailAddressId = orgWideAddresses.isEmpty()
      ? null
      : orgWideAddresses[0].Id;
    orgWideEmailResolved = true;
    return cachedOrgWideEmailAddressId;
  }

  @TestVisible
  private static String formatSendErrors(Messaging.SendEmailError[] errors) {
    if (errors == null || errors.isEmpty()) {
      return 'Unknown send error';
    }
    List<String> parts = new List<String>();
    for (Messaging.SendEmailError error : errors) {
      parts.add(String.valueOf(error.getStatusCode()) + ' ' + error.getMessage());
    }
    return String.join(parts, '; ');
  }

  @TestVisible
  private static String formatDatabaseErrors(Database.Error[] errors) {
    if (errors == null || errors.isEmpty()) {
      return 'Unknown DML error';
    }
    List<String> parts = new List<String>();
    for (Database.Error error : errors) {
      String fieldNames = '';
      if (error.getFields() != null && !error.getFields().isEmpty()) {
        fieldNames = ' [' + String.join(error.getFields(), ',') + ']';
      }
      parts.add(String.valueOf(error.getStatusCode()) + ' ' + error.getMessage() + fieldNames);
    }
    return String.join(parts, '; ');
  }

  @TestVisible
  private static String appendError(String existing, String nextError) {
    if (String.isBlank(nextError)) {
      return existing;
    }
    if (String.isBlank(existing)) {
      return nextError;
    }
    return existing + ' | ' + nextError;
  }

  private static Boolean isEmailLimitExceeded(Exception ex) {
    if (ex == null || String.isBlank(ex.getMessage())) {
      return false;
    }

    String message = ex.getMessage().toUpperCase();
    return message.contains('SINGLE_EMAIL_LIMIT_EXCEEDED') ||
      message.contains('EMAIL LIMIT EXCEEDED');
  }

  @TestVisible
  static void clearTestState() {
    testTemplateIdOverride = null;
    testOrgWideEmailAddressIdOverride = null;
    testSimulateSuccessfulSend = false;
    testForceMissingTemplate = false;
    testUsePlainMessage = false;
    lastSendFailureMessage = null;
    cachedTemplateId = null;
    cachedTemplateRecord = null;
    templateResolved = false;
    cachedOrgWideEmailAddressId = null;
    orgWideEmailResolved = false;
  }
}