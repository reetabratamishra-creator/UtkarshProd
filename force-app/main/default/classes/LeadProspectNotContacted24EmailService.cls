/**
 * @description   Renders and sends Prospect-stage 24-hour not-contacted escalation emails
 *                to the Lead Owner and Department CRM Head using the Lightning template.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class LeadProspectNotContacted24EmailService {
  public static final String TEMPLATE_NAME = 'Lead Not Contacted 24h Owner';

  @TestVisible
  private static Id testTemplateIdOverride;

  /**
   * @description Sends the escalation email to the Lead Owner and CRM Head when recipients exist.
   * @param leadRecord Lead record with owner and department fields populated.
   * @return True when at least one email was sent successfully.
   */
  public static Boolean sendEscalationEmail(Lead leadRecord) {
    if (leadRecord == null) {
      return false;
    }

    Id templateId = resolveTemplateId();
    if (templateId == null) {
      return false;
    }

    LeadManagementEmailService.RenderedEmail rendered = LeadManagementEmailService.renderTemplate(
      templateId,
      leadRecord
    );
    if (rendered == null) {
      return false;
    }

    Set<String> recipients = resolveRecipients(leadRecord);
    if (recipients.isEmpty()) {
      return false;
    }

    Messaging.SingleEmailMessage message = buildMessage(
      leadRecord,
      rendered,
      new List<String>(recipients)
    );

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

  /**
   * @description Returns true when the lead has had no activity since entering Prospect stage.
   * @param leadRecord Lead to evaluate.
   * @return True when no qualifying activity exists.
   */
  public static Boolean hasNoActivitySinceProspectEntry(Lead leadRecord) {
    if (leadRecord == null || leadRecord.Prospect_Stage_Entry_Date__c == null) {
      return false;
    }

    if (leadRecord.LastActivityDate == null) {
      return true;
    }

    Date entryDate = leadRecord.Prospect_Stage_Entry_Date__c.date();
    return leadRecord.LastActivityDate <= entryDate;
  }

  /**
   * @description Returns true when at least 24 hours have elapsed since Prospect stage entry.
   * @param leadRecord Lead to evaluate.
   * @return True when the 24-hour threshold is met.
   */
  public static Boolean isPast24Hours(Lead leadRecord) {
    if (leadRecord == null || leadRecord.Prospect_Stage_Entry_Date__c == null) {
      return false;
    }

    Long hoursDiff =
      (System.now().getTime() - leadRecord.Prospect_Stage_Entry_Date__c.getTime()) /
      (1000 * 60 * 60);
    return hoursDiff >= 24;
  }

  /**
   * @description Maps Lead department values to UserRole name prefixes used in the org.
   * @param department Lead department value.
   * @return Role department prefix.
   */
  public static String getRoleDepartmentName(String department) {
    Map<String, String> departmentMap = new Map<String, String>{
      'Transmission & Telecom Tower' => 'Transmission Tower'
    };

    return departmentMap.containsKey(department) ? departmentMap.get(department) : department;
  }

  private static Id cachedTemplateId;
  private static Id cachedOrgWideEmailAddressId;
  private static Boolean orgWideEmailResolved = false;

  private static Id resolveTemplateId() {
    if (Test.isRunningTest() && testTemplateIdOverride != null) {
      return testTemplateIdOverride;
    }

    if (cachedTemplateId != null) {
      return cachedTemplateId;
    }

    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE Name = :TEMPLATE_NAME
      LIMIT 1
    ];
    cachedTemplateId = templates.isEmpty() ? null : templates[0].Id;
    return cachedTemplateId;
  }

  private static Set<String> resolveRecipients(Lead leadRecord) {
    Set<String> recipients = new Set<String>();

    if (leadRecord.Owner != null && String.isNotBlank(leadRecord.Owner.Email)) {
      recipients.add(leadRecord.Owner.Email.trim().toLowerCase());
    }

    String crmHeadEmail = leadRecord.CRM_User_Email_Formula__c;
    if (String.isBlank(crmHeadEmail)) {
      crmHeadEmail = resolveCrmHeadEmailFromRole(leadRecord);
    }

    if (String.isNotBlank(crmHeadEmail)) {
      recipients.add(crmHeadEmail.trim().toLowerCase());
    }

    return recipients;
  }

  private static String resolveCrmHeadEmailFromRole(Lead leadRecord) {
    String department = getRoleDepartmentName(leadRecord.Department_NameFormula__c);
    if (String.isBlank(department)) {
      return null;
    }

    String roleName = department + ' CRM User';
    List<User> users = [
      SELECT Email
      FROM User
      WHERE IsActive = TRUE AND UserRole.Name = :roleName
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0].Email;
  }

  private static Messaging.SingleEmailMessage buildMessage(
    Lead leadRecord,
    LeadManagementEmailService.RenderedEmail rendered,
    List<String> toAddresses
  ) {
    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(toAddresses);
    message.setSubject(rendered.subject);
    message.setSaveAsActivity(false);
    message.setTargetObjectId(leadRecord.Id);
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

  private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null || String.isBlank(settings.Central_Sender_Email__c)) {
      return;
    }

    if (!orgWideEmailResolved) {
      List<OrgWideEmailAddress> orgWideAddresses = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE Address = :settings.Central_Sender_Email__c.trim()
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
}