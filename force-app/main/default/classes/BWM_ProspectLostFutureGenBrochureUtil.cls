/**
 * @description Resolves brochure label text for Prospect_lost_future_tender_gen emails.
 */
public without sharing class BWM_ProspectLostFutureGenBrochureUtil {
  public static String resolveBrochureLabel(Lead leadRecord) {
    if (leadRecord == null) {
      return '';
    }
    if (leadRecord.Department_Name__c == BWM_EmailConstants.DEPT_ENQUIRY) {
      return 'Corporate';
    }
    return String.isBlank(leadRecord.Department_Name__c)
      ? ''
      : leadRecord.Department_Name__c;
  }

  public static String applyRenderedHtmlFix(
    String htmlBody,
    Lead leadRecord,
    String templateName
  ) {
    if (
      String.isBlank(htmlBody) ||
      leadRecord == null ||
      !isProspectLostFutureGenTemplate(templateName) ||
      leadRecord.Department_Name__c != BWM_EmailConstants.DEPT_ENQUIRY
    ) {
      return htmlBody;
    }

    return htmlBody
      .replace('>Enquiry</strong> brochure', '>Corporate</strong> brochure')
      .replace('>Enquiry</strong>&nbsp;brochure', '>Corporate</strong>&nbsp;brochure');
  }

  public static String applyTemplateSubstitutions(
    String templateBody,
    Lead leadRecord,
    String templateName
  ) {
    if (
      String.isBlank(templateBody) ||
      leadRecord == null ||
      !isProspectLostFutureGenTemplate(templateName)
    ) {
      return templateBody;
    }

    String brochureLabel = resolveBrochureLabel(leadRecord);
    String converted = templateBody;
    converted = replaceMergeToken(
      converted,
      'Lead.Department_NameFormula__c',
      brochureLabel
    );
    converted = replaceMergeToken(
      converted,
      'Lead.Email_Brochure_Label__c',
      brochureLabel
    );
    return converted;
  }

  private static Boolean isProspectLostFutureGenTemplate(String templateName) {
    if (String.isBlank(templateName)) {
      return false;
    }
    return normalizeTemplateName(templateName) ==
      normalizeTemplateName('Prospect_lost_future_tender_gen');
  }

  private static String replaceMergeToken(
    String templateBody,
    String tokenName,
    String value
  ) {
    String safeValue = String.isBlank(value) ? '' : value;
    return templateBody
      .replace('{{{' + tokenName + '}}}', safeValue)
      .replace('{!' + tokenName + '}', safeValue);
  }

  private static String normalizeTemplateName(String templateName) {
    return templateName == null
      ? ''
      : templateName.trim().toLowerCase().replace(' ', '_');
  }
}