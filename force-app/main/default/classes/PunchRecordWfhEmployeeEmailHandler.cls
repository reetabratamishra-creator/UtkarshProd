/**
 * @description Sends WFH & WFO related emails:
 *              1. Employee - Approval Pending
 *              2. HOD - Submission
 *              3. Employee - Approved
 * @author Rani Mate
 * @date 2026-08-14
 */
public without sharing class PunchRecordWfhEmployeeEmailHandler {
  public static final String PUNCH_TYPE_WFH = 'WFH';
  public static final String PUNCH_TYPE_WFO = 'WFO';

  public static final String APPROVAL_STATUS_PENDING = 'Pending';
  public static final String APPROVAL_STATUS_APPROVED = 'Approved';

  public static final String TEMPLATE_WFH_EMPLOYEE_PENDING =
    'Employee_Approval_pending_1786604926046';
  public static final String TEMPLATE_WFH_HOD_SUBMISSION =
    'HOD_WFH_Submission_email_1786608000419';
  public static final String TEMPLATE_WFH_EMPLOYEE_APPROVED =
    'Employee_Approved_1786609772323';

  public static final String TEMPLATE_WFO_EMPLOYEE_PENDING =
    'WFO_Employee_Approval_pending_1786610200787';
  public static final String TEMPLATE_WFO_HOD_SUBMISSION =
    'HOD_WFO_Submission_email_1786610422083';
  public static final String TEMPLATE_WFO_EMPLOYEE_APPROVED =
    'WFO_Employee_Approved_1786611659696';

  public static final String ORG_WIDE_SENDER_EMAIL =
    'noreply@utkarshindialimited.in';

  @TestVisible
  private static Id testTemplateIdOverride;

  public static void handleAfterInsert(List<Punch_Record__c> newRecords) {
    processRecords(newRecords, null);
  }

  public static void handleAfterUpdate(
    List<Punch_Record__c> newRecords,
    Map<Id, Punch_Record__c> oldRecordsById
  ) {
    processRecords(newRecords, oldRecordsById);
  }

  @TestVisible
  private static void processRecords(
    List<Punch_Record__c> newRecords,
    Map<Id, Punch_Record__c> oldRecordsById
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    List<Punch_Record__c> pendingRecords = new List<Punch_Record__c>();
    List<Punch_Record__c> approvedRecords = new List<Punch_Record__c>();

    for (Punch_Record__c punchRecord : newRecords) {
      Punch_Record__c oldRecord = oldRecordsById == null
        ? null
        : oldRecordsById.get(punchRecord.Id);

      if (qualifiesAsPending(punchRecord, oldRecord)) {
        pendingRecords.add(punchRecord);
      }

      if (qualifiesAsApproved(punchRecord, oldRecord)) {
        approvedRecords.add(punchRecord);
      }
    }

    if (!pendingRecords.isEmpty()) {
      sendPendingEmails(pendingRecords);
    }

    if (!approvedRecords.isEmpty()) {
      sendApprovedEmails(approvedRecords);
    }
  }

  @TestVisible
  private static Boolean qualifiesAsPending(
    Punch_Record__c punchRecord,
    Punch_Record__c oldRecord
  ) {
    if (punchRecord == null) {
      return false;
    }
    if (punchRecord.User__c == null) {
      return false;
    }
    if (punchRecord.WFH_Approval_Status__c != APPROVAL_STATUS_PENDING) {
      return false;
    }
    if (
      punchRecord.Punch_Type__c != PUNCH_TYPE_WFH &&
      punchRecord.Punch_Type__c != PUNCH_TYPE_WFO
    ) {
      return false;
    }
    if (oldRecord == null) {
      return true;
    }

    return punchRecord.Punch_Type__c != oldRecord.Punch_Type__c ||
      punchRecord.WFH_Approval_Status__c != oldRecord.WFH_Approval_Status__c;
  }

  @TestVisible
  private static Boolean qualifiesAsApproved(
    Punch_Record__c punchRecord,
    Punch_Record__c oldRecord
  ) {
    if (punchRecord == null || oldRecord == null) {
      return false;
    }
    if (punchRecord.User__c == null) {
      return false;
    }
    if (
      punchRecord.Punch_Type__c != PUNCH_TYPE_WFH &&
      punchRecord.Punch_Type__c != PUNCH_TYPE_WFO
    ) {
      return false;
    }

    return punchRecord.WFH_Approval_Status__c == APPROVAL_STATUS_APPROVED &&
      oldRecord.WFH_Approval_Status__c != APPROVAL_STATUS_APPROVED;
  }

  private static void sendPendingEmails(List<Punch_Record__c> punchRecords) {
    for (Punch_Record__c punchRecord : punchRecords) {
      String employeeTemplate;
      String hodTemplate;

      if (punchRecord.Punch_Type__c == PUNCH_TYPE_WFH) {
        employeeTemplate = TEMPLATE_WFH_EMPLOYEE_PENDING;
        hodTemplate = TEMPLATE_WFH_HOD_SUBMISSION;
      } else if (punchRecord.Punch_Type__c == PUNCH_TYPE_WFO) {
        employeeTemplate = TEMPLATE_WFO_EMPLOYEE_PENDING;
        hodTemplate = TEMPLATE_WFO_HOD_SUBMISSION;
      } else {
        continue;
      }

      sendEmailToUser(punchRecord, employeeTemplate, punchRecord.User__c);

      if (punchRecord.HOD__c != null) {
        sendEmailToUser(punchRecord, hodTemplate, punchRecord.HOD__c);
      }
    }
  }

  private static void sendApprovedEmails(List<Punch_Record__c> punchRecords) {
    for (Punch_Record__c punchRecord : punchRecords) {
      String templateName;
      if (punchRecord.Punch_Type__c == PUNCH_TYPE_WFH) {
        templateName = TEMPLATE_WFH_EMPLOYEE_APPROVED;
      } else if (punchRecord.Punch_Type__c == PUNCH_TYPE_WFO) {
        templateName = TEMPLATE_WFO_EMPLOYEE_APPROVED;
      } else {
        continue;
      }
      sendEmailToUser(punchRecord, templateName, punchRecord.User__c);
    }
  }

  private static void sendEmailToUser(
    Punch_Record__c punchRecord,
    String templateDeveloperName,
    Id userId
  ) {
    if (userId == null) {
      return;
    }

    Id templateId = resolveTemplateId(templateDeveloperName);
    if (templateId == null) {
      return;
    }

    List<User> recipients = [
      SELECT Id, Email
      FROM User
      WHERE Id = :userId AND Email != NULL
      LIMIT 1
    ];
    if (recipients.isEmpty() || String.isBlank(recipients[0].Email)) {
      return;
    }

    Messaging.SingleEmailMessage message = buildMessage(
      templateId,
      punchRecord.Id,
      recipients[0].Email.trim()
    );
    if (message != null) {
      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
    }
  }

  private static Messaging.SingleEmailMessage buildMessage(
    Id templateId,
    Id punchRecordId,
    String recipientEmail
  ) {
    if (templateId == null || punchRecordId == null || String.isBlank(recipientEmail)) {
      return null;
    }

    Messaging.SingleEmailMessage message = Messaging.renderStoredEmailTemplate(
      templateId,
      null,
      punchRecordId
    );
    message.setToAddresses(new List<String>{ recipientEmail });
    message.setSaveAsActivity(false);
    message.setTreatTargetObjectAsRecipient(false);
    applyOrgWideSender(message);
    return message;
  }

  private static Id resolveTemplateId(String templateDeveloperName) {
    if (Test.isRunningTest() && testTemplateIdOverride != null) {
      return testTemplateIdOverride;
    }

    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :templateDeveloperName
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
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
}