/**
 * @description Sends Case 1st-response SLA escalation emails to Owner, HOD, and CRM Head / ED Sir.
 * @author Anshita Chanda
 * @date 2026-08-16
 */
public without sharing class CaseSLAEscalationEmailService {
  public static final String ROLE_UTKARSH_ED = 'Utkarsh ED';
  public static final String ROLE_UTKARSH_CRM_HEAD = 'Utkarsh CRM Head';
  public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

  public enum EscalationTier {
    OWNER,
    HOD,
    SIR
  }

  @TestVisible
  private static Id testTemplateIdOverride;

  @TestVisible
  private static Set<String> testRecipientOverrides;

  @TestVisible
  private static Datetime testNowOverride;

  @TestVisible
  private static Datetime testAnchorOverride;

  private static Map<String, EmailTemplate> templateByDeveloperName = new Map<String, EmailTemplate>();
  private static Map<Id, String> ownerEmailById = new Map<Id, String>();
  private static Map<String, List<String>> roleEmailsByRoleName = new Map<String, List<String>>();
  private static Map<String, Id> hodUserIdByRoleName = new Map<String, Id>();
  private static Id cachedOrgWideEmailAddressId;
  private static Boolean orgWideEmailResolved = false;

  public static Boolean sendEscalationEmail(Case caseRecord, EscalationTier tier) {
    if (caseRecord == null || tier == null) {
      return false;
    }

    String templateDeveloperName = resolveTemplateDeveloperName(
      caseRecord.Priority,
      tier
    );
    if (String.isBlank(templateDeveloperName)) {
      return false;
    }

    EmailTemplate templateRecord = resolveTemplate(templateDeveloperName);
    if (templateRecord == null) {
      return false;
    }

    Id renderWhoId = resolveRenderWhoId(caseRecord, tier);
    if (renderWhoId == null) {
      return false;
    }

    RenderedCaseEmail rendered = renderTemplate(
      templateRecord,
      caseRecord.Id,
      renderWhoId
    );
    if (rendered == null) {
      return false;
    }

    Set<String> recipients = resolveRecipients(caseRecord, tier);
    if (recipients.isEmpty()) {
      return false;
    }

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(new List<String>(recipients));
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

    if (Test.isRunningTest()) {
      return true;
    }

    try {
      Messaging.SendEmailResult[] results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ message },
        false
      );
      return !results.isEmpty() && results[0].isSuccess();
    } catch (Exception ex) {
      // Org daily Single Email quota exhausted — skip without failing the batch chunk.
      if (isEmailLimitExceeded(ex)) {
        return false;
      }
      throw ex;
    }
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
  public static String resolveTemplateDeveloperName(
    String priority,
    EscalationTier tier
  ) {
    if (String.isBlank(priority) || tier == null) {
      return null;
    }

    Map<String, Map<EscalationTier, String>> templatesByPriority = new Map<String, Map<EscalationTier, String>>{
      'Critical' => new Map<EscalationTier, String>{
        EscalationTier.OWNER => 'Case_Critical_Response_24h_Owner',
        EscalationTier.HOD => 'Case_Critical_Response_48h_HOD',
        EscalationTier.SIR => 'Case_Critical_Response_72h_Sir'
      },
      'High' => new Map<EscalationTier, String>{
        EscalationTier.OWNER => 'Case_High_Response_24h_Owner',
        EscalationTier.HOD => 'Case_High_Response_48h_HOD',
        EscalationTier.SIR => 'Case_High_Response_72h_Sir'
      },
      'Medium' => new Map<EscalationTier, String>{
        EscalationTier.OWNER => 'Case_Medium_Response_48h_Owner',
        EscalationTier.HOD => 'Case_Medium_Response_72h_HOD',
        EscalationTier.SIR => 'Case_Medium_Response_144h_Sir'
      },
      'Low' => new Map<EscalationTier, String>{
        EscalationTier.OWNER => 'Case_Low_Response_72h_Owner',
        EscalationTier.HOD => 'Case_Low_Response_120h_HOD',
        EscalationTier.SIR => 'Case_Low_Response_144h_Sir'
      }
    };

    Map<EscalationTier, String> tierTemplates = templatesByPriority.get(priority);
    return tierTemplates == null ? null : tierTemplates.get(tier);
  }

  @TestVisible
  public static Boolean isTierDue(Case caseRecord, EscalationTier tier) {
    Datetime anchorDate = resolveAnchorDate(caseRecord);
    if (caseRecord == null || tier == null || anchorDate == null) {
      return false;
    }

    Datetime ownerDue = caseRecord.SLA_Due_Date_Time_RO__c;
    Datetime hodDue = caseRecord.Escalation_Date_1__c;
    Datetime sirDue = caseRecord.Escalation_Date_2__c;

    if (tier == EscalationTier.OWNER) {
      return ownerDue != null
        ? getNow() >= ownerDue
        : hoursSince(anchorDate) >= getOwnerThresholdHours(caseRecord.Priority);
    }
    if (tier == EscalationTier.HOD) {
      return hodDue != null
        ? getNow() >= hodDue
        : hoursSince(anchorDate) >= getHodThresholdHours(caseRecord.Priority);
    }
    return sirDue != null
      ? getNow() >= sirDue
      : hoursSince(anchorDate) >= getSirThresholdHours(caseRecord.Priority);
  }

  @TestVisible
  private static Datetime resolveAnchorDate(Case caseRecord) {
    if (Test.isRunningTest() && testAnchorOverride != null) {
      return testAnchorOverride;
    }
    return caseRecord == null ? null : caseRecord.CreatedDate;
  }

  @TestVisible
  private static Datetime getNow() {
    if (Test.isRunningTest() && testNowOverride != null) {
      return testNowOverride;
    }
    return System.now();
  }

  @TestVisible
  public static Integer getOwnerThresholdHours(String priority) {
    if (priority == 'Medium') {
      return 48;
    }
    if (priority == 'Low') {
      return 72;
    }
    return 24;
  }

  @TestVisible
  public static Integer getHodThresholdHours(String priority) {
    if (priority == 'Medium') {
      return 72;
    }
    if (priority == 'Low') {
      return 120;
    }
    return 48;
  }

  @TestVisible
  public static Integer getSirThresholdHours(String priority) {
    if (priority == 'Medium') {
      return 120;
    }
    if (priority == 'Low') {
      return 144;
    }
    return 72;
  }

  private static Long hoursSince(Datetime anchorDate) {
    return (getNow().getTime() - anchorDate.getTime()) / (1000 * 60 * 60);
  }

  private static Id resolveRenderWhoId(Case caseRecord, EscalationTier tier) {
    if (tier == EscalationTier.OWNER) {
      return caseRecord.OwnerId;
    }
    if (tier == EscalationTier.HOD) {
      Id hodUserId = resolveDepartmentHodUserId(caseRecord);
      return hodUserId != null ? hodUserId : caseRecord.OwnerId;
    }
    return caseRecord.OwnerId;
  }

  private static Set<String> resolveRecipients(Case caseRecord, EscalationTier tier) {
    if (
      Test.isRunningTest() &&
      testRecipientOverrides != null &&
      !testRecipientOverrides.isEmpty()
    ) {
      return new Set<String>(testRecipientOverrides);
    }

    Set<String> recipients = new Set<String>();

    if (tier == EscalationTier.OWNER) {
      addOwnerEmail(caseRecord.OwnerId, recipients);
      return recipients;
    }

    if (tier == EscalationTier.HOD) {
      addDepartmentHodEmails(caseRecord, recipients);
      return recipients;
    }

    addRoleEmails(ROLE_UTKARSH_CRM_HEAD, recipients);
    addRoleEmails(ROLE_UTKARSH_ED, recipients);
    return recipients;
  }

  private static void addOwnerEmail(Id ownerId, Set<String> recipients) {
    if (ownerId == null) {
      return;
    }

    if (!ownerEmailById.containsKey(ownerId)) {
      String ownerEmail = null;
      for (User ownerRecord : [
        SELECT Email
        FROM User
        WHERE Id = :ownerId AND Email != NULL
        LIMIT 1
      ]) {
        ownerEmail = ownerRecord.Email.trim().toLowerCase();
      }
      ownerEmailById.put(ownerId, ownerEmail);
    }

    if (String.isNotBlank(ownerEmailById.get(ownerId))) {
      recipients.add(ownerEmailById.get(ownerId));
    }
  }

  private static void addDepartmentHodEmails(Case caseRecord, Set<String> recipients) {
    if (String.isNotBlank(caseRecord.HOD_User_Email_Formula__c)) {
      recipients.add(caseRecord.HOD_User_Email_Formula__c.trim().toLowerCase());
    }

    String department = resolveDepartmentName(caseRecord);
    if (String.isNotBlank(department)) {
      addRoleEmails(department + ' HOD', recipients);
    }
  }

  private static Id resolveDepartmentHodUserId(Case caseRecord) {
    String department = resolveDepartmentName(caseRecord);
    if (String.isBlank(department)) {
      return null;
    }

    String roleName = department + ' HOD';
    if (!hodUserIdByRoleName.containsKey(roleName)) {
      List<User> hodUsers = [
        SELECT Id
        FROM User
        WHERE IsActive = TRUE AND UserRole.Name = :roleName
        LIMIT 1
      ];
      hodUserIdByRoleName.put(roleName, hodUsers.isEmpty() ? null : hodUsers[0].Id);
    }
    return hodUserIdByRoleName.get(roleName);
  }

  private static String resolveDepartmentName(Case caseRecord) {
    if (String.isNotBlank(caseRecord.Department_formula__c)) {
      return EscalationMatrixEmailService.getRoleDepartmentName(
        caseRecord.Department_formula__c
      );
    }
    if (String.isNotBlank(caseRecord.Department__c)) {
      return EscalationMatrixEmailService.getRoleDepartmentName(
        caseRecord.Department__c
      );
    }
    return null;
  }

  private static void addRoleEmails(String roleName, Set<String> recipients) {
    if (String.isBlank(roleName)) {
      return;
    }

    if (!roleEmailsByRoleName.containsKey(roleName)) {
      List<String> emails = new List<String>();
      for (User userRecord : [
        SELECT Email
        FROM User
        WHERE IsActive = TRUE AND UserRole.Name = :roleName AND Email != NULL
      ]) {
        emails.add(userRecord.Email.trim().toLowerCase());
      }
      roleEmailsByRoleName.put(roleName, emails);
    }

    recipients.addAll(roleEmailsByRoleName.get(roleName));
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
        'CaseSLAEscalationEmailService classic render failed: ' + ex.getMessage()
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
    return value.replaceAll('\\{\\{\\{', '{!').replaceAll('\\}\\}\\}', '}');
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

    if (templateByDeveloperName.containsKey(developerName)) {
      return templateByDeveloperName.get(developerName);
    }

    List<EmailTemplate> templates = [
      SELECT Id, DeveloperName, Subject, HtmlValue, Body, UiType
      FROM EmailTemplate
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    EmailTemplate templateRecord = templates.isEmpty() ? null : templates[0];
    templateByDeveloperName.put(developerName, templateRecord);
    return templateRecord;
  }

  private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
    if (!orgWideEmailResolved) {
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
    }

    if (cachedOrgWideEmailAddressId != null) {
      message.setOrgWideEmailAddressId(cachedOrgWideEmailAddressId);
    }
  }

  private class RenderedCaseEmail {
    public String subject;
    public String plainTextBody;
    public String htmlBody;
  }
}