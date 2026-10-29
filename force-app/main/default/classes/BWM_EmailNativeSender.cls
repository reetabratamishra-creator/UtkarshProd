/**
 * @description   Sends email via Salesforce Messaging.SingleEmailMessage when Infobip
 *                is not used.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailNativeSender {
  public class SendOutcome {
    public Boolean success = false;
    public String message;
    public String auditPayload;
  }

  public static SendOutcome send(
    BWM_Email_Settings__mdt settings,
    BWM_EmailPayloadBuilder.BuiltEmail built,
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record,
    List<Messaging.EmailFileAttachment> attachments
  ) {
    SendOutcome outcome = new SendOutcome();
    if (built == null || !hasRecipientAddresses(built)) {
      outcome.message = 'Recipient email is required.';
      return outcome;
    }

    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setUseSignature(false);
    message.setToAddresses(resolveToAddresses(built));

  if (String.isNotBlank(built.subject)) {
      message.setSubject(built.subject);
    }
    if (String.isNotBlank(built.htmlBody)) {
      message.setHtmlBody(built.htmlBody);
    }
    if (String.isNotBlank(built.body)) {
      message.setPlainTextBody(built.body);
    }

    Id targetObjectId = BWM_EmailTemplateRenderer.resolveWhoId(record);
    Boolean hasFileAttachments = attachments != null && !attachments.isEmpty();

    // With PDF attachments, linking to Lead/Contact and save-as-activity can cause
    // Salesforce to deliver the brochure as an .html stub instead of a real PDF.
    message.setSaveAsActivity(!hasFileAttachments);

    if (targetObjectId != null && !hasFileAttachments) {
      message.setTargetObjectId(targetObjectId);
      message.setTreatTargetObjectAsRecipient(false);
    }

    Id whatId = BWM_EmailTemplateRenderer.resolveWhatId(record);
    if (whatId != null && !hasFileAttachments) {
      message.setWhatId(whatId);
    }

    applySender(settings, mapping, record, message);

    if (hasFileAttachments) {
      message.setFileAttachments(attachments);
    }

    outcome.auditPayload = buildAuditPayload(built, attachments);

    try {
      Messaging.SendEmailResult[] results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ message }
      );
      if (!results.isEmpty() && results[0].isSuccess()) {
        outcome.success = true;
        outcome.message = 'Sent via Salesforce Email.';
        return outcome;
      }

      if (!results.isEmpty() && !results[0].getErrors().isEmpty()) {
        outcome.message = results[0].getErrors()[0].getMessage();
      } else {
        outcome.message = 'Salesforce email send failed.';
      }
    } catch (Exception ex) {
      outcome.message = ex.getMessage();
    }

    return outcome;
  }

  private static void applySender(
    BWM_Email_Settings__mdt settings,
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record,
    Messaging.SingleEmailMessage message
  ) {
    String centralSenderEmail = settings == null
      ? null
      : settings.Central_Sender_Email__c;
    Id orgWideEmailId = resolveOrgWideEmailAddressId(centralSenderEmail);
    if (orgWideEmailId != null) {
      message.setOrgWideEmailAddressId(orgWideEmailId);
    }

    if (
      mapping != null &&
      mapping.Sender_Type__c == BWM_EmailConstants.SENDER_OWNER
    ) {
      String ownerEmail = BWM_FieldValueResolver.resolveRecord(
        record,
        'Owner.Email'
      );
      if (String.isNotBlank(ownerEmail)) {
        message.setReplyTo(ownerEmail.trim());
        return;
      }
    }

    if (String.isNotBlank(centralSenderEmail)) {
      message.setReplyTo(centralSenderEmail.trim());
    }
  }

  private static Map<String, Id> orgWideEmailIdByAddress = new Map<String, Id>();

  private static Id resolveOrgWideEmailAddressId(String emailAddress) {
    if (String.isBlank(emailAddress)) {
      return null;
    }

    String key = emailAddress.trim().toLowerCase();
    if (orgWideEmailIdByAddress.containsKey(key)) {
      return orgWideEmailIdByAddress.get(key);
    }

    List<OrgWideEmailAddress> rows = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = :emailAddress.trim()
      LIMIT 1
    ];
    Id orgWideId = rows.isEmpty() ? null : rows[0].Id;
    orgWideEmailIdByAddress.put(key, orgWideId);
    return orgWideId;
  }

  private static String buildAuditPayload(
    BWM_EmailPayloadBuilder.BuiltEmail built,
    List<Messaging.EmailFileAttachment> attachments
  ) {
    List<String> attachmentNames = new List<String>();
    if (attachments != null) {
      for (Messaging.EmailFileAttachment attachment : attachments) {
        attachmentNames.add(attachment.getFileName());
      }
    }

    return JSON.serialize(
      new Map<String, Object>{
        'channel' => 'SalesforceEmail',
        'to' => resolveToAddresses(built),
        'subject' => built.subject,
        'templateId' => built.templateIdUsed,
        'attachments' => attachmentNames
      }
    );
  }

  private static Boolean hasRecipientAddresses(
    BWM_EmailPayloadBuilder.BuiltEmail built
  ) {
    return !resolveToAddresses(built).isEmpty();
  }

  private static List<String> resolveToAddresses(
    BWM_EmailPayloadBuilder.BuiltEmail built
  ) {
    if (built.recipientEmails != null && !built.recipientEmails.isEmpty()) {
      return new List<String>(built.recipientEmails);
    }
    if (String.isNotBlank(built.recipientEmail)) {
      return new List<String>{ built.recipientEmail.trim() };
    }
    return new List<String>();
  }
}