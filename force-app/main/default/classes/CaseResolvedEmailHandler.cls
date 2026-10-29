/**
 * @description Sends Case Resolved email using Case_Resolved_Creator.
 *              Case RT → Case_Contacts__c emails; Internal Ticket → CreatedBy email.
 * @author      Anshita Chanda
 * @date        2026-09-23
 */
public without sharing class CaseResolvedEmailHandler {
  public static final String TEMPLATE_RESOLVED = 'Case_Resolved_Creator';
  public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';
  private static final String CASE_RECORD_TYPE_DEV_NAME = 'Case';
  private static final String INTERNAL_TICKET_RT_DEV_NAME = 'Internal_Ticket';

  @TestVisible
  private static Id testTemplateIdOverride;

  @TestVisible
  private static Boolean disableInTests = false;

  /**
   * @description Handles after-update Cases when status becomes Resolved.
   * @param newRecords Updated Case records from the trigger context.
   * @param oldRecordsById Prior field values keyed by Case Id.
   */
  public static void handleAfterUpdate(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (Test.isRunningTest() && disableInTests) {
      return;
    }
    processRecords(newRecords, oldRecordsById);
  }

  @TestVisible
  private static void processRecords(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (
      newRecords == null ||
      newRecords.isEmpty() ||
      oldRecordsById == null ||
      oldRecordsById.isEmpty()
    ) {
      return;
    }

    Id caseRecordTypeId = getRecordTypeId(CASE_RECORD_TYPE_DEV_NAME);
    Id internalTicketRecordTypeId = getRecordTypeId(INTERNAL_TICKET_RT_DEV_NAME);

    List<Case> caseRtResolved = new List<Case>();
    List<Case> internalTicketResolved = new List<Case>();

    for (Case caseRecord : newRecords) {
      Case oldCase = oldRecordsById.get(caseRecord.Id);
      if (oldCase == null || !isNewlyResolved(caseRecord, oldCase)) {
        continue;
      }

      if (
        caseRecordTypeId != null &&
        caseRecord.RecordTypeId == caseRecordTypeId
      ) {
        caseRtResolved.add(caseRecord);
      } else if (
        internalTicketRecordTypeId != null &&
        caseRecord.RecordTypeId == internalTicketRecordTypeId
      ) {
        internalTicketResolved.add(caseRecord);
      }
    }

    if (caseRtResolved.isEmpty() && internalTicketResolved.isEmpty()) {
      return;
    }

    EmailTemplate templateRecord = resolveTemplate(TEMPLATE_RESOLVED);
    if (templateRecord == null) {
      System.debug(
        LoggingLevel.ERROR,
        'CaseResolvedEmailHandler: template not found → ' + TEMPLATE_RESOLVED
      );
      return;
    }

    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    messages.addAll(buildCaseContactMessages(caseRtResolved, templateRecord));
    messages.addAll(
      buildCreatedByMessages(internalTicketResolved, templateRecord)
    );

    if (messages.isEmpty()) {
      return;
    }

    Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, false);
    for (Messaging.SendEmailResult result : results) {
      if (!result.isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'CaseResolvedEmailHandler: email failed → ' +
            result.getErrors()[0].getMessage()
        );
      }
    }
  }

  @TestVisible
  private static Boolean isNewlyResolved(Case caseRecord, Case oldCase) {
    if (caseRecord.IsClosed == true && oldCase.IsClosed != true) {
      return true;
    }
    return caseRecord.Status == 'Resolved' && oldCase.Status != 'Resolved';
  }

  private static List<Messaging.SingleEmailMessage> buildCaseContactMessages(
    List<Case> cases,
    EmailTemplate templateRecord
  ) {
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    if (cases == null || cases.isEmpty()) {
      return messages;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Case caseRecord : cases) {
      caseIds.add(caseRecord.Id);
    }

    Map<Id, List<String>> emailsByCaseId = new Map<Id, List<String>>();
    for (Case_Contacts__c caseContact : [
      SELECT Case__c, Email__c, Contact__r.Email
      FROM Case_Contacts__c
      WHERE Case__c IN :caseIds
    ]) {
      String emailAddress = firstNonBlank(
        caseContact.Email__c,
        caseContact.Contact__r == null ? null : caseContact.Contact__r.Email
      );
      if (String.isBlank(emailAddress)) {
        continue;
      }

      if (!emailsByCaseId.containsKey(caseContact.Case__c)) {
        emailsByCaseId.put(caseContact.Case__c, new List<String>());
      }
      List<String> emails = emailsByCaseId.get(caseContact.Case__c);
      String trimmed = emailAddress.trim();
      if (!emails.contains(trimmed)) {
        emails.add(trimmed);
      }
    }

    Map<Id, Case> casesWithCreator = queryCasesWithCreator(caseIds);
    for (Case caseRecord : cases) {
      List<String> toAddresses = emailsByCaseId.get(caseRecord.Id);
      if (toAddresses == null || toAddresses.isEmpty()) {
        System.debug(
          LoggingLevel.WARN,
          'CaseResolvedEmailHandler: skipping Case ' +
            caseRecord.Id +
            ' - no Case Contact emails'
        );
        continue;
      }

      Case detail = casesWithCreator.get(caseRecord.Id);
      Id whoId = detail == null ? UserInfo.getUserId() : detail.CreatedById;
      Messaging.SingleEmailMessage message = buildMessage(
        templateRecord,
        caseRecord.Id,
        whoId,
        toAddresses
      );
      if (message != null) {
        messages.add(message);
      }
    }

    return messages;
  }

  private static List<Messaging.SingleEmailMessage> buildCreatedByMessages(
    List<Case> cases,
    EmailTemplate templateRecord
  ) {
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    if (cases == null || cases.isEmpty()) {
      return messages;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Case caseRecord : cases) {
      caseIds.add(caseRecord.Id);
    }

    for (Case caseRecord : queryCasesWithCreator(caseIds).values()) {
      if (String.isBlank(caseRecord.CreatedBy.Email)) {
        System.debug(
          LoggingLevel.WARN,
          'CaseResolvedEmailHandler: skipping Case ' +
            caseRecord.Id +
            ' - CreatedBy has no email'
        );
        continue;
      }

      Messaging.SingleEmailMessage message = buildMessage(
        templateRecord,
        caseRecord.Id,
        caseRecord.CreatedById,
        new List<String>{ caseRecord.CreatedBy.Email.trim() }
      );
      if (message != null) {
        messages.add(message);
      }
    }

    return messages;
  }

  private static Map<Id, Case> queryCasesWithCreator(Set<Id> caseIds) {
    return new Map<Id, Case>(
      [
        SELECT Id, CreatedById, CreatedBy.Email
        FROM Case
        WHERE Id IN :caseIds
      ]
    );
  }

  private static Messaging.SingleEmailMessage buildMessage(
    EmailTemplate templateRecord,
    Id caseId,
    Id whoId,
    List<String> toAddresses
  ) {
    if (
      templateRecord == null ||
      caseId == null ||
      whoId == null ||
      toAddresses == null ||
      toAddresses.isEmpty()
    ) {
      return null;
    }

    RenderedCaseEmail rendered = renderTemplate(templateRecord, caseId, whoId);
    if (rendered == null) {
      return null;
    }

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(toAddresses);
    message.setSubject(rendered.subject);
    message.setSaveAsActivity(false);
    message.setTreatTargetObjectAsRecipient(false);

    if (String.isNotBlank(rendered.htmlBody)) {
      message.setHtmlBody(rendered.htmlBody);
    }
    if (String.isNotBlank(rendered.plainTextBody)) {
      message.setPlainTextBody(rendered.plainTextBody);
    }

    applyOrgWideSender(message);
    return message;
  }

  private static RenderedCaseEmail renderTemplate(
    EmailTemplate templateRecord,
    Id caseId,
    Id whoId
  ) {
    if (templateRecord == null || caseId == null || whoId == null) {
      return null;
    }

    if (isLightningTemplate(templateRecord)) {
      return renderLightningTemplate(templateRecord, caseId, whoId);
    }

    try {
      Messaging.SingleEmailMessage renderedMessage = Messaging.renderStoredEmailTemplate(
        templateRecord.Id,
        whoId,
        caseId
      );
      RenderedCaseEmail rendered = new RenderedCaseEmail();
      rendered.subject = renderedMessage.getSubject();
      rendered.plainTextBody = renderedMessage.getPlainTextBody();
      rendered.htmlBody = renderedMessage.getHtmlBody();
      return hasContent(rendered) ? rendered : null;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'CaseResolvedEmailHandler: classic render failed → ' + ex.getMessage()
      );
      return null;
    }
  }

  private static RenderedCaseEmail renderLightningTemplate(
    EmailTemplate templateRecord,
    Id caseId,
    Id whoId
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
      String.valueOf(whoId),
      String.valueOf(caseId),
      bodies
    );

    RenderedCaseEmail rendered = new RenderedCaseEmail();
    Integer resultIndex = 0;
    if (hasSubject) {
      if (results[resultIndex].getSuccess()) {
        rendered.subject = results[resultIndex].getMergedBody();
      } else {
        return null;
      }
      resultIndex++;
    }
    if (hasHtml && results.size() > resultIndex) {
      if (results[resultIndex].getSuccess()) {
        rendered.htmlBody = results[resultIndex].getMergedBody();
      } else {
        return null;
      }
    }

    return hasContent(rendered) ? rendered : null;
  }

  private static Boolean isLightningTemplate(EmailTemplate templateRecord) {
    return templateRecord.UiType == 'SFX' ||
      (String.isNotBlank(templateRecord.HtmlValue) &&
      templateRecord.HtmlValue.contains('{{{'));
  }

  private static String convertLightningMergeSyntax(String value) {
    if (String.isBlank(value)) {
      return value;
    }
    return value
      .replace(
        '{{{Case.CreatedBy.FirstName}}}',
        '{!Case.Case_Created_By_formula__c}'
      )
      .replaceAll('\\{\\{\\{', '{!')
      .replaceAll('\\}\\}\\}', '}')
      .replace(
        '{!Case.CreatedBy.FirstName}',
        '{!Case.Case_Created_By_formula__c}'
      );
  }

  private static Boolean hasContent(RenderedCaseEmail rendered) {
    return rendered != null &&
      (String.isNotBlank(rendered.subject) ||
      String.isNotBlank(rendered.htmlBody) ||
      String.isNotBlank(rendered.plainTextBody));
  }

  private static EmailTemplate resolveTemplate(String developerName) {
    if (Test.isRunningTest() && testTemplateIdOverride != null) {
      List<EmailTemplate> testTemplates = [
        SELECT Id, Subject, HtmlValue, Body, UiType
        FROM EmailTemplate
        WHERE Id = :testTemplateIdOverride
        LIMIT 1
      ];
      return testTemplates.isEmpty() ? null : testTemplates[0];
    }

    List<EmailTemplate> templates = [
      SELECT Id, DeveloperName, IsActive, Subject, HtmlValue, Body, UiType
      FROM EmailTemplate
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0];
  }

  private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
    List<OrgWideEmailAddress> orgWideAddresses = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = :ORG_WIDE_SENDER_EMAIL
      LIMIT 1
    ];
    if (!orgWideAddresses.isEmpty()) {
      message.setOrgWideEmailAddressId(orgWideAddresses[0].Id);
    }
  }

  private static Id getRecordTypeId(String developerName) {
    RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(developerName);
    return info == null ? null : info.getRecordTypeId();
  }

  private static String firstNonBlank(String firstValue, String secondValue) {
    if (String.isNotBlank(firstValue)) {
      return firstValue;
    }
    return secondValue;
  }

  private class RenderedCaseEmail {
    public String subject;
    public String plainTextBody;
    public String htmlBody;
  }
}