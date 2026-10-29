/**
 * @description   Sends Case assignment and reassignment emails to the Case Owner
 *                (and CC Case Creator on reassignment).
 * @author        Rani Mate
 * @date          2026-08-14
 */
public without sharing class CaseNewAssignedOwnerHandler {
  public static final String TEMPLATE_NEW_ASSIGNED = 'Case_New_Assigned_Owner';
  public static final String TEMPLATE_REASSIGNED = 'Case_Reassigned_New_Owner';
  public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';
  private static final String CASE_RECORD_TYPE_DEV_NAME = 'Case';

  @TestVisible
  private static Id testTemplateIdOverride;

  /**
   * @description Handles after-insert Cases (new assignment).
   * @param newRecords Inserted Case records from the trigger context.
   */
  public static void handleAfterInsert(List<Case> newRecords) {
    processRecords(filterCaseRecordType(newRecords), null);
  }

  /**
   * @description Handles after-update Cases (reassignment).
   * @param newRecords Updated Case records from the trigger context.
   * @param oldRecordsById Prior field values keyed by Case Id.
   */
  public static void handleAfterUpdate(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    processRecords(filterCaseRecordType(newRecords), oldRecordsById);
  }

  private static List<Case> filterCaseRecordType(List<Case> cases) {
    if (cases == null || cases.isEmpty()) {
      return cases;
    }

    Id caseRecordTypeId = getCaseRecordTypeId();
    if (caseRecordTypeId == null) {
      return new List<Case>();
    }

    List<Case> filtered = new List<Case>();
    for (Case caseRecord : cases) {
      if (caseRecord.RecordTypeId == caseRecordTypeId) {
        filtered.add(caseRecord);
      }
    }
    return filtered;
  }

  private static Id getCaseRecordTypeId() {
    RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(CASE_RECORD_TYPE_DEV_NAME);
    return info == null ? null : info.getRecordTypeId();
  }

  @TestVisible
  private static void processRecords(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    List<Case> newAssignmentCases = new List<Case>();
    List<Case> reassignmentCases = new List<Case>();

    for (Case caseRecord : newRecords) {
      Case oldCase = oldRecordsById == null
        ? null
        : oldRecordsById.get(caseRecord.Id);

      if (qualifiesAsNewAssignment(caseRecord, oldCase)) {
        newAssignmentCases.add(caseRecord);
      } else if (qualifiesAsReassignment(caseRecord, oldCase)) {
        reassignmentCases.add(caseRecord);
      }
    }

    if (!newAssignmentCases.isEmpty()) {
      sendEmails(newAssignmentCases, TEMPLATE_NEW_ASSIGNED, false);
    }

    if (!reassignmentCases.isEmpty()) {
      sendEmails(reassignmentCases, TEMPLATE_REASSIGNED, true);
    }
  }

  @TestVisible
  private static Boolean qualifiesAsNewAssignment(Case caseRecord, Case oldCase) {
    if (oldCase != null) {
      return false;
    }
    return caseRecord.OwnerId != null;
  }

  @TestVisible
  private static Boolean qualifiesAsReassignment(
    Case caseRecord,
    Case oldCase
  ) {
    if (oldCase == null) {
      return false;
    }
    return caseRecord.OwnerId != null && caseRecord.OwnerId != oldCase.OwnerId;
  }

  private static void sendEmails(
    List<Case> cases,
    String templateDeveloperName,
    Boolean ccCreator
  ) {
    EmailTemplate templateRecord = resolveTemplate(templateDeveloperName);
    if (templateRecord == null) {
      System.debug(
        LoggingLevel.ERROR,
        'CaseNewAssignedOwnerHandler: template not found → ' + templateDeveloperName
      );
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Case caseRecord : cases) {
      caseIds.add(caseRecord.Id);
    }

    List<Case> casesWithDetails = [
      SELECT Id, OwnerId, Owner.Email, CreatedById, CreatedBy.Email
      FROM Case
      WHERE Id IN :caseIds
    ];

    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

    for (Case caseRecord : casesWithDetails) {
      if (String.isBlank(caseRecord.Owner.Email)) {
        System.debug(
          LoggingLevel.WARN,
          'CaseNewAssignedOwnerHandler: skipping Case ' +
            caseRecord.Id +
            ' - Owner has no email'
        );
        continue;
      }

      Messaging.SingleEmailMessage message = buildMessage(
        templateRecord,
        caseRecord,
        ccCreator
      );

      if (message != null) {
        messages.add(message);
      }
    }

    if (messages.isEmpty()) {
      return;
    }

    Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
    for (Messaging.SendEmailResult result : results) {
      if (!result.isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'CaseNewAssignedOwnerHandler: email failed → ' +
            result.getErrors()[0].getMessage()
        );
      }
    }
  }

  private static Messaging.SingleEmailMessage buildMessage(
    EmailTemplate templateRecord,
    Case caseRecord,
    Boolean ccCreator
  ) {
    if (
      templateRecord == null ||
      caseRecord == null ||
      caseRecord.OwnerId == null ||
      String.isBlank(caseRecord.Owner.Email)
    ) {
      return null;
    }

    RenderedCaseEmail rendered = renderTemplate(
      templateRecord,
      caseRecord.Id,
      caseRecord.OwnerId
    );
    if (rendered == null) {
      return null;
    }

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(new List<String>{ caseRecord.Owner.Email.trim() });
    message.setSubject(rendered.subject);
    message.setSaveAsActivity(false);
    message.setTreatTargetObjectAsRecipient(false);

    if (String.isNotBlank(rendered.htmlBody)) {
      message.setHtmlBody(rendered.htmlBody);
    }
    if (String.isNotBlank(rendered.plainTextBody)) {
      message.setPlainTextBody(rendered.plainTextBody);
    }

    if (
      ccCreator == true &&
      String.isNotBlank(caseRecord.CreatedBy.Email) &&
      caseRecord.CreatedById != caseRecord.OwnerId
    ) {
      message.setCcAddresses(
        new List<String>{ caseRecord.CreatedBy.Email.trim() }
      );
    }

    applyOrgWideSender(message);
    return message;
  }

  private static RenderedCaseEmail renderTemplate(
    EmailTemplate templateRecord,
    Id caseId,
    Id ownerId
  ) {
    if (templateRecord == null || caseId == null || ownerId == null) {
      return null;
    }

    if (isLightningTemplate(templateRecord)) {
      return renderLightningTemplate(templateRecord, caseId, ownerId);
    }

    try {
      Messaging.SingleEmailMessage renderedMessage = Messaging.renderStoredEmailTemplate(
        templateRecord.Id,
        ownerId,
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
        'CaseNewAssignedOwnerHandler: classic render failed → ' + ex.getMessage()
      );
      return null;
    }
  }

  private static RenderedCaseEmail renderLightningTemplate(
    EmailTemplate templateRecord,
    Id caseId,
    Id ownerId
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
      String.valueOf(ownerId),
      String.valueOf(caseId),
      bodies
    );

    RenderedCaseEmail rendered = new RenderedCaseEmail();
    Integer resultIndex = 0;
    if (hasSubject) {
      if (results[resultIndex].getSuccess()) {
        rendered.subject = results[resultIndex].getMergedBody();
      } else {
        logRenderErrors(results[resultIndex]);
        return null;
      }
      resultIndex++;
    }
    if (hasHtml && results.size() > resultIndex) {
      if (results[resultIndex].getSuccess()) {
        rendered.htmlBody = results[resultIndex].getMergedBody();
      } else {
        logRenderErrors(results[resultIndex]);
        return null;
      }
    }

    return hasContent(rendered) ? rendered : null;
  }

  private static void logRenderErrors(
    Messaging.RenderEmailTemplateBodyResult result
  ) {
    if (result == null || result.getErrors() == null) {
      return;
    }
    for (Messaging.RenderEmailTemplateError error : result.getErrors()) {
      System.debug(
        LoggingLevel.ERROR,
        'CaseNewAssignedOwnerHandler: template merge failed → ' +
          error.getMessage()
      );
    }
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
      .replace('{{{Case.Owner.FirstName}}}', '{!Case.Case_Owner_Formula__c}')
      .replace('{{{Case.Owner.Name}}}', '{!Case.Case_Owner_Formula__c}')
      .replace('{{{Case.CreatedBy.FirstName}}}', '{!Case.Case_Created_By_formula__c}')
      .replaceAll('\\{\\{\\{', '{!')
      .replaceAll('\\}\\}\\}', '}')
      .replace('{!Case.Owner.FirstName}', '{!Case.Case_Owner_Formula__c}')
      .replace('{!Case.Owner.Name}', '{!Case.Case_Owner_Formula__c}')
      .replace('{!Case.CreatedBy.FirstName}', '{!Case.Case_Created_By_formula__c}');
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

  private class RenderedCaseEmail {
    public String subject;
    public String plainTextBody;
    public String htmlBody;
  }
}