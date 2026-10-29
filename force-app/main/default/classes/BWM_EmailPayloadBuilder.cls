/**
 * @description   Builds Infobip/native email payloads from email template mappings and
 *                record data.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailPayloadBuilder {
  public class BuiltEmail {
    public String senderEmail;
    public String recipientEmail;
    public List<String> recipientEmails;
    public String subject;
    public String body;
    public String htmlBody;
    public String payloadJson;
    public Id templateIdUsed;
    public Boolean usedSalesforceTemplate = false;
  }

  public static BuiltEmail build(
    BWM_Email_Settings__mdt settings,
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    BuiltEmail built = new BuiltEmail();
    built.senderEmail = resolveSenderEmail(settings, mapping, record);
    built.recipientEmails = resolveRecipientEmails(mapping, record);
    built.recipientEmail = built.recipientEmails.isEmpty()
      ? null
      : built.recipientEmails[0];

    BWM_EmailTemplateRenderer.RenderedEmail rendered = BWM_EmailTemplateRenderer.render(
      mapping,
      record
    );
    if (rendered != null && rendered.fromSalesforceTemplate) {
      built.subject = rendered.subject;
      built.htmlBody = rendered.htmlBody;
      built.body = String.isNotBlank(rendered.plainTextBody)
        ? rendered.plainTextBody
        : stripHtml(rendered.htmlBody);
      if (record instanceof Lead) {
        built.htmlBody = BWM_ProspectLostFutureGenBrochureUtil.applyRenderedHtmlFix(
          built.htmlBody,
          (Lead) record,
          mapping.Template_Name__c
        );
        if (String.isBlank(rendered.plainTextBody) && String.isNotBlank(built.htmlBody)) {
          built.body = stripHtml(built.htmlBody);
        }
      }
      built.templateIdUsed = rendered.templateId;
      built.usedSalesforceTemplate = true;
    } else {
      List<String> params = resolveParams(record, mapping);
      built.subject = mergeTemplate(mapping.Subject_Template__c, params);
      built.body = mergeTemplate(mapping.Body_Template__c, params);
      built.templateIdUsed = BWM_EmailTemplateRenderer.resolveTemplateId(mapping);
    }

    injectProductBrief(built, record, mapping);

    Map<String, Object> content = new Map<String, Object>{
      'subject' => built.subject
    };
    if (String.isNotBlank(built.htmlBody)) {
      content.put('html', built.htmlBody);
    }
    if (String.isNotBlank(built.body)) {
      content.put('text', built.body);
    }

    Map<String, Object> payload = new Map<String, Object>{
      'messages' => new List<Object>{
        new Map<String, Object>{
          'sender' => built.senderEmail,
          'destinations' => new List<Object>{
            new Map<String, Object>{
              'to' => new List<Object>{
                new Map<String, Object>{
                  'destination' => built.recipientEmail
                }
              }
            }
          },
          'content' => content
        }
      }
    };
    built.payloadJson = JSON.serialize(payload);
    return built;
  }

  private static void injectProductBrief(
    BuiltEmail built,
    SObject record,
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    if (shouldSkipProductBriefBodyInjection(mapping)) {
      return;
    }

    String plainBrief = BWM_EmailProductBriefService.resolvePlainText(record);
    if (String.isBlank(plainBrief)) {
      return;
    }

    String htmlBrief = BWM_EmailProductBriefService.resolveHtml(record);
    if (String.isNotBlank(built.htmlBody)) {
      built.htmlBody = BWM_EmailProductBriefService.injectIntoContent(
        built.htmlBody,
        plainBrief,
        htmlBrief,
        record
      );
    }
    if (String.isNotBlank(built.body)) {
      built.body = BWM_EmailProductBriefService.injectIntoContent(
        built.body,
        plainBrief,
        htmlBrief,
        record
      );
    }
  }

  private static Boolean shouldSkipProductBriefBodyInjection(
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    return isTemplateMapping(
      mapping,
      BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN
    ) ||
      isTemplateMapping(
        mapping,
        BWM_EmailConstants.TEMPLATE_NEGOTIATION_LOST_FUTURE_TENDER_DEPT
      ) ||
      isTemplateMapping(
        mapping,
        BWM_EmailConstants.TEMPLATE_NEGOTIATION_LOST_FUTURE_TENDER_GEN
      );
  }

  private static Boolean isTemplateMapping(
    BWM_Email_Template_Mapping__mdt mapping,
    String templateName
  ) {
    if (mapping == null || String.isBlank(mapping.Template_Name__c)) {
      return false;
    }
    return normalizeTemplateName(mapping.Template_Name__c) ==
      normalizeTemplateName(templateName);
  }

  private static String normalizeTemplateName(String templateName) {
    return templateName == null
      ? ''
      : templateName.trim().toLowerCase().replace(' ', '_');
  }

  @TestVisible
  private static Boolean isDealerSalesAssignMapping(
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    return isTemplateMapping(mapping, BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN);
  }

  public static String mergeTemplate(String template, List<String> params) {
    if (String.isBlank(template)) {
      return '';
    }
    String merged = template;
    for (Integer index = 0; index < params.size(); index++) {
      String placeholder = '{#var' + String.valueOf(index + 1) + '#}';
      String value = String.isBlank(params[index]) ? 'NA' : params[index];
      merged = merged.replace(placeholder, value);
    }
    return merged;
  }

  private static String stripHtml(String htmlValue) {
    if (String.isBlank(htmlValue)) {
      return '';
    }
    return htmlValue.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
  }

  private static List<String> resolveParams(
    SObject record,
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    List<String> params = new List<String>{
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param1_Field__c),
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param2_Field__c),
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param3_Field__c),
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param4_Field__c),
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param5_Field__c),
      BWM_FieldValueResolver.resolveRecord(record, mapping.Param6_Field__c)
    };

    if (String.isBlank(params[0])) {
      params[0] = 'Customer';
    }
    if (String.isBlank(params[5])) {
      params[5] = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Email');
    }
    return params;
  }

  private static String resolveSenderEmail(
    BWM_Email_Settings__mdt settings,
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (mapping.Sender_Type__c == BWM_EmailConstants.SENDER_OWNER) {
      String ownerEmail = BWM_FieldValueResolver.resolveRecord(
        record,
        'Owner.Email'
      );
      if (String.isNotBlank(ownerEmail)) {
        return ownerEmail.trim();
      }
    }
    return settings.Central_Sender_Email__c;
  }

  private static List<String> resolveRecipientEmails(
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (mapping.Recipient_Type__c == BWM_EmailConstants.RECIPIENT_DEALER) {
      String dealerEmail = resolveDealerEmail(record);
      return String.isBlank(dealerEmail)
        ? new List<String>()
        : new List<String>{ dealerEmail.trim() };
    }

    if (mapping.Recipient_Type__c == BWM_EmailConstants.RECIPIENT_OWNER) {
      String ownerEmail = BWM_FieldValueResolver.resolveRecord(
        record,
        'Owner.Email'
      );
      return String.isBlank(ownerEmail)
        ? new List<String>()
        : new List<String>{ ownerEmail.trim() };
    }

    if (record instanceof Lead) {
      String leadEmail = ((Lead) record).Email;
      return String.isBlank(leadEmail)
        ? new List<String>()
        : new List<String>{ leadEmail.trim() };
    }

    if (record instanceof Account) {
      Account accountRecord = (Account) record;
      if (String.isNotBlank(accountRecord.Email__c)) {
        return new List<String>{ accountRecord.Email__c.trim() };
      }
      return new List<String>();
    }

    if (record instanceof Opportunity) {
      return resolveOpportunityContactRoleEmails(record.Id);
    }

    return new List<String>();
  }

  @TestVisible
  private static List<String> resolveOpportunityContactRoleEmails(Id opportunityId) {
    List<String> recipientEmails = new List<String>();
    Set<String> uniqueEmails = new Set<String>();

    for (OpportunityContactRole contactRole : [
      SELECT Contact.Email
      FROM OpportunityContactRole
      WHERE OpportunityId = :opportunityId
      ORDER BY IsPrimary DESC, CreatedDate ASC
    ]) {
      String emailAddress = contactRole.Contact == null
        ? null
        : contactRole.Contact.Email;
      if (String.isBlank(emailAddress)) {
        continue;
      }

      String trimmedEmail = emailAddress.trim();
      String normalizedEmail = trimmedEmail.toLowerCase();
      if (!uniqueEmails.contains(normalizedEmail)) {
        uniqueEmails.add(normalizedEmail);
        recipientEmails.add(trimmedEmail);
      }
    }

    return recipientEmails;
  }

  private static String resolveRecipientEmail(
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    List<String> recipientEmails = resolveRecipientEmails(mapping, record);
    return recipientEmails.isEmpty() ? null : recipientEmails[0];
  }

  private static String resolveDealerEmail(SObject record) {
    if (!(record instanceof Opportunity)) {
      return null;
    }
    SObject dealer = record.getSObject('DealerAccount__r');
    if (dealer == null) {
      return null;
    }
    Object emailValue = dealer.get('Email__c');
    if (emailValue == null) {
      emailValue = dealer.get('PersonEmail');
    }
    if (emailValue == null) {
      emailValue = dealer.get('Email');
    }
    return emailValue == null ? null : String.valueOf(emailValue);
  }
}