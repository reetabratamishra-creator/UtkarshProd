/**
 * @description   Renders Salesforce email template subject and body for a given record.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailTemplateRenderer {
  public class RenderedEmail {
    public String subject;
    public String plainTextBody;
    public String htmlBody;
    public Id templateId;
    public Boolean fromSalesforceTemplate = false;
  }

  @TestVisible
  private static Map<String, Id> templateIdByName;

  @TestVisible
  private static RenderedEmail testOverride;

  public static RenderedEmail render(
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (Test.isRunningTest() && testOverride != null) {
      return testOverride;
    }

    if (mapping == null || record == null || String.isBlank(mapping.Template_Name__c)) {
      return null;
    }

    Id templateId = resolveTemplateId(mapping);
    if (templateId == null) {
      return null;
    }

    Id whoId = resolveWhoId(record);
    if (whoId == null) {
      return null;
    }

    EmailTemplate templateRecord = loadTemplateById(templateId);
    if (templateRecord == null) {
      return null;
    }

    if (isLightningTemplate(templateRecord)) {
      return renderLightningTemplate(
        templateRecord,
        record,
        templateId,
        whoId,
        mapping.Template_Name__c
      );
    }

    try {
      Messaging.SingleEmailMessage renderedMessage = Messaging.renderStoredEmailTemplate(
        templateId,
        whoId,
        resolveWhatId(record)
      );

      RenderedEmail rendered = new RenderedEmail();
      rendered.templateId = templateId;
      rendered.subject = renderedMessage.getSubject();
      rendered.plainTextBody = renderedMessage.getPlainTextBody();
      rendered.htmlBody = renderedMessage.getHtmlBody();
      rendered.fromSalesforceTemplate = String.isNotBlank(rendered.subject) ||
        String.isNotBlank(rendered.htmlBody) ||
        String.isNotBlank(rendered.plainTextBody);
      return rendered.fromSalesforceTemplate ? rendered : null;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        'BWM email template render failed for ' +
          mapping.Template_Name__c +
          ': ' +
          ex.getMessage()
      );
      return null;
    }
  }

  public static Id resolveTemplateId(BWM_Email_Template_Mapping__mdt mapping) {
    if (mapping == null) {
      return null;
    }

    if (isUsableTemplateId(mapping.Template_Id__c)) {
      return (Id) mapping.Template_Id__c;
    }

    if (String.isBlank(mapping.Template_Name__c)) {
      return null;
    }

    loadTemplateIdsByName();
    return templateIdByName.get(normalizeTemplateName(mapping.Template_Name__c));
  }

  public static Id resolveWhoId(SObject record) {
    if (record == null) {
      return null;
    }

    if (record instanceof Lead) {
      return record.Id;
    }

    if (record instanceof Opportunity) {
      Opportunity opportunityRecord = (Opportunity) record;
      if (opportunityRecord.ContactId != null) {
        return opportunityRecord.ContactId;
      }
      return opportunityRecord.OwnerId;
    }

    if (record instanceof Account) {
      return ((Account) record).OwnerId;
    }

    return null;
  }

  public static Id resolveWhatId(SObject record) {
    if (record == null) {
      return null;
    }

    if (record instanceof Lead) {
      return null;
    }

    return record.Id;
  }

  private static EmailTemplate loadTemplateById(Id templateId) {
    List<EmailTemplate> templates = [
      SELECT Id, Subject, HtmlValue, Body, UiType
      FROM EmailTemplate
      WHERE Id = :templateId
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0];
  }

  private static Boolean isLightningTemplate(EmailTemplate templateRecord) {
    return templateRecord.UiType == 'SFX' ||
      (String.isNotBlank(templateRecord.HtmlValue) &&
      templateRecord.HtmlValue.contains('{{{'));
  }

  private static RenderedEmail renderLightningTemplate(
    EmailTemplate templateRecord,
    SObject record,
    Id templateId,
    Id whoId,
    String templateName
  ) {
    Id whatId = resolveLightningWhatId(record);
    if (whatId == null) {
      return null;
    }

    String subject = convertLightningMergeSyntax(
      templateRecord.Subject,
      record,
      templateName
    );
    String html = convertLightningMergeSyntax(
      templateRecord.HtmlValue,
      record,
      templateName
    );
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
      String.valueOf(whatId),
      bodies
    );

    RenderedEmail rendered = new RenderedEmail();
    rendered.templateId = templateId;

    Integer resultIndex = 0;
    if (hasSubject) {
      if (results[resultIndex].getSuccess()) {
        rendered.subject = results[resultIndex].getMergedBody();
      }
      resultIndex++;
    }
    if (hasHtml && results.size() > resultIndex && results[resultIndex].getSuccess()) {
      rendered.htmlBody = results[resultIndex].getMergedBody();
    }

    rendered.fromSalesforceTemplate = String.isNotBlank(rendered.subject) ||
      String.isNotBlank(rendered.htmlBody);
    return rendered.fromSalesforceTemplate ? rendered : null;
  }

  private static Id resolveLightningWhatId(SObject record) {
    if (record instanceof Lead) {
      return record.Id;
    }

    Id whatId = resolveWhatId(record);
    return whatId != null ? whatId : record.Id;
  }

  private static String convertLightningMergeSyntax(
    String value,
    SObject record,
    String templateName
  ) {
    if (String.isBlank(value)) {
      return value;
    }

    String converted = applySenderFieldSubstitutions(value, record);
    converted = applyProductBriefSubstitutions(converted, record);
    converted = applyDealerSalesAssignTemplateSubstitutions(
      converted,
      record,
      templateName
    );
    converted = applyProspectLostFutureGenBrochureSubstitutions(
      converted,
      record,
      templateName
    );
    return converted.replaceAll('\\{\\{\\{', '{!').replaceAll('\\}\\}\\}', '}');
  }

  @TestVisible
  static String applyProspectLostFutureGenBrochureSubstitutionsForTest(
    String templateBody,
    SObject record,
    String templateName
  ) {
    return applyProspectLostFutureGenBrochureSubstitutions(
      templateBody,
      record,
      templateName
    );
  }

  private static String applyProspectLostFutureGenBrochureSubstitutions(
    String templateBody,
    SObject record,
    String templateName
  ) {
    if (!(record instanceof Lead)) {
      return templateBody;
    }
    return BWM_ProspectLostFutureGenBrochureUtil.applyTemplateSubstitutions(
      templateBody,
      (Lead) record,
      templateName
    );
  }

  @TestVisible
  static String applyDealerSalesAssignTemplateSubstitutionsForTest(
    String templateBody,
    SObject record,
    String templateName
  ) {
    return applyDealerSalesAssignTemplateSubstitutions(
      templateBody,
      record,
      templateName
    );
  }

  @TestVisible
  static String applySenderFieldSubstitutionsForTest(
    String templateBody,
    SObject record
  ) {
    return applySenderFieldSubstitutions(templateBody, record);
  }

  private static String applyDealerSalesAssignTemplateSubstitutions(
    String templateBody,
    SObject record,
    String templateName
  ) {
    if (
      String.isBlank(templateBody) ||
      !(record instanceof Opportunity) ||
      !isDealerSalesAssignTemplate(templateName)
    ) {
      return templateBody;
    }

    String productInterest = BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      (Opportunity) record,
      ' | '
    );
    String companyName = BWM_FieldValueResolver.resolveRecord(record, 'Account.Name');
    String converted = templateBody;
    converted = replaceMergeToken(
      converted,
      'Opportunity.Product_Category__c',
      productInterest
    );
    converted = replaceMergeToken(
      converted,
      'Opportunity.Account.Name',
      companyName
    );
    return converted;
  }

  private static Boolean isDealerSalesAssignTemplate(String templateName) {
    if (String.isBlank(templateName)) {
      return false;
    }
    return normalizeTemplateName(templateName) ==
      normalizeTemplateName(BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN);
  }

  private static String applyProductBriefSubstitutions(
    String templateBody,
    SObject record
  ) {
    if (String.isBlank(templateBody) || record == null) {
      return templateBody;
    }
    if (!BWM_EmailProductBriefService.containsProductBriefToken(templateBody)) {
      return templateBody;
    }

    return BWM_EmailProductBriefService.replaceProductBriefMergeTokens(
      templateBody,
      BWM_EmailProductBriefService.resolvePlainText(record),
      BWM_EmailProductBriefService.resolveHtml(record)
    );
  }

  private static String applySenderFieldSubstitutions(
    String templateBody,
    SObject record
  ) {
    if (String.isBlank(templateBody) || !(record instanceof Lead)) {
      return templateBody;
    }

    Lead leadRecord = (Lead) record;
    User ownerUser = queryOwnerUser(leadRecord);
    String ownerFirstName = ownerUser == null
      ? ''
      : nullToEmpty(ownerUser.FirstName);
    String ownerLastName = ownerUser == null
      ? ''
      : nullToEmpty(ownerUser.LastName);
    String ownerName = ownerUser == null ? '' : nullToEmpty(ownerUser.Name);

    if (String.isBlank(ownerFirstName) && String.isNotBlank(ownerName)) {
      List<String> nameParts = ownerName.trim().split('\\s+');
      ownerFirstName = nameParts[0];
      if (nameParts.size() > 1) {
        ownerLastName = ownerName.substring(ownerFirstName.length()).trim();
      }
    }

    String contactPhone = resolveOwnerContactPhone(ownerUser);

    String contactEmail = normalizeContactEmail(
      ownerUser == null ? '' : nullToEmpty(ownerUser.Email)
    );
    if (String.isBlank(contactEmail)) {
      contactEmail = normalizeContactEmail(leadRecord.Email);
    }
    if (String.isBlank(contactEmail)) {
      contactEmail = BWM_EmailConstants.FALLBACK_CONTACT_EMAIL;
    }

    String converted = templateBody;
    converted = applyOwnerContactTokens(
      converted,
      'Sender',
      ownerFirstName,
      ownerLastName,
      contactPhone,
      contactEmail
    );
    converted = applyOwnerContactTokens(
      converted,
      'Recipient',
      ownerFirstName,
      ownerLastName,
      contactPhone,
      contactEmail
    );
    converted = applyOwnerContactTokens(
      converted,
      'Lead.Owner',
      ownerFirstName,
      ownerLastName,
      contactPhone,
      contactEmail
    );
    converted = replaceMergeToken(converted, 'Lead.Owner.Name', ownerName);
    converted = replaceMergeToken(
      converted,
      'Lead.Owner_First_name__c',
      ownerFirstName
    );
    converted = replaceMergeToken(
      converted,
      'Lead.Owner_LastName__c',
      ownerLastName
    );
    converted = replaceMergeToken(
      converted,
      'Lead.Owner_User_Phone__c',
      contactPhone
    );
    converted = replaceMergeToken(
      converted,
      'Lead.Owner_User_Email__c',
      contactEmail
    );
    return converted;
  }

  private static String applyOwnerContactTokens(
    String templateBody,
    String objectPrefix,
    String firstName,
    String lastName,
    String phone,
    String email
  ) {
    String converted = templateBody;
    converted = replaceMergeToken(
      converted,
      objectPrefix + '.FirstName',
      firstName
    );
    converted = replaceMergeToken(
      converted,
      objectPrefix + '.LastName',
      lastName
    );
    converted = replaceMergeToken(converted, objectPrefix + '.Phone', phone);
    converted = replaceMergeToken(
      converted,
      objectPrefix + '.MobilePhone',
      phone
    );
    converted = replaceMergeToken(converted, objectPrefix + '.Email', email);
    return converted;
  }

  private static String replaceMergeToken(
    String templateBody,
    String tokenName,
    String value
  ) {
    String safeValue = String.isBlank(value) ? '' : value;
    return templateBody
      .replace('{{{' + tokenName + '}}}', safeValue)
      .replace('{{' + tokenName + '}}', safeValue)
      .replace('{!' + tokenName + '}', safeValue);
  }

  private static User queryOwnerUser(Lead leadRecord) {
    Id ownerId = leadRecord.OwnerId;
    if (ownerId == null || ownerId.getSobjectType() != User.SObjectType) {
      return null;
    }

    List<User> owners = [
      SELECT FirstName, LastName, Name, Email, Phone, MobilePhone
      FROM User
      WHERE Id = :ownerId
      LIMIT 1
    ];
    return owners.isEmpty() ? null : owners[0];
  }

  private static String resolveOwnerContactPhone(User ownerUser) {
    // Owner contact only — never Lead phone. Blank if owner has no phone.
    if (ownerUser == null) {
      return '';
    }
    String mobile = nullToEmpty(ownerUser.MobilePhone);
    if (String.isNotBlank(mobile)) {
      return mobile.trim();
    }
    String phone = nullToEmpty(ownerUser.Phone);
    if (String.isNotBlank(phone)) {
      return phone.trim();
    }
    return '';
  }

  private static String normalizeContactEmail(String email) {
    if (String.isBlank(email)) {
      return '';
    }

    String normalized = email.trim().toLowerCase();
    if (normalized.contains('example.com') || !normalized.contains('@')) {
      return '';
    }
    if (normalized.endsWith('.invalid')) {
      return email.trim().replaceAll('(?i)\\.invalid$', '');
    }

    return email.trim();
  }

  private static String sanitizeContactEmail(String email) {
    return normalizeContactEmail(email);
  }

  private static String nullToEmpty(String value) {
    return value == null ? '' : value;
  }

  private static Boolean isUsableTemplateId(String templateIdValue) {
    if (String.isBlank(templateIdValue) || templateIdValue == 'TBD') {
      return false;
    }

    try {
      Id templateId = (Id) templateIdValue;
      return String.valueOf(templateId).startsWith('00X');
    } catch (Exception ex) {
      return false;
    }
  }

  private static void loadTemplateIdsByName() {
    if (templateIdByName != null) {
      return;
    }

    templateIdByName = new Map<String, Id>();
    for (EmailTemplate templateRecord : [
      SELECT Id, Name
      FROM EmailTemplate
      WHERE IsActive = TRUE
      ORDER BY CreatedDate DESC
    ]) {
      String normalizedName = normalizeTemplateName(templateRecord.Name);
      if (!templateIdByName.containsKey(normalizedName)) {
        templateIdByName.put(normalizedName, templateRecord.Id);
      }
    }
  }

  private static String normalizeTemplateName(String templateName) {
    if (templateName == null) {
      return '';
    }
    // Org templates mix spaces and underscores (e.g. "not serviceable" vs "not_serviceable").
    return templateName.trim().toLowerCase().replace(' ', '_');
  }

  @TestVisible
  static void clearCache() {
    templateIdByName = null;
    testOverride = null;
  }
}