/**
 * @description   Resolves product brief text for email template merge fields.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailProductBriefService {
  private static Map<String, BWM_Email_Department_Brochure__mdt> briefByDepartment;

  public static String resolvePlainText(SObject record) {
    BWM_Email_Department_Brochure__mdt row = resolveRow(record);
    return row == null ? '' : nullToEmpty(row.Product_Brief__c).trim();
  }

  public static String resolveHtml(SObject record) {
    return formatAsHtml(resolvePlainText(record));
  }

  public static Boolean containsProductBriefToken(String content) {
    if (String.isBlank(content)) {
      return false;
    }
    String lower = content.toLowerCase();
    return lower.contains('product_brief') ||
      content.contains(BWM_EmailConstants.PRODUCT_BRIEF_PLACEHOLDER);
  }

  public static String replaceProductBriefMergeTokens(
    String content,
    String plainBrief,
    String htmlBrief
  ) {
    if (String.isBlank(content) || String.isBlank(plainBrief)) {
      return content;
    }

    Boolean isHtml = looksLikeHtml(content);
    String replacement = isHtml ? htmlBrief : plainBrief;
    String result = content;

    result = result.replaceAll(
      '(?is)<p\\b[^>]*>(?:(?!</p>).)*?(?:\\{\\{\\{Product_Brief\\}\\}\\}|\\{\\{Product_Brief\\}\\}|\\{!Product_Brief\\}|\\{#product_brief#\\})(?:(?!</p>).)*?</p>',
      replacement
    );

    for (String token : productBriefMergeTokens()) {
      result = result.replace(token, replacement);
    }

    return result;
  }

  private static List<String> productBriefMergeTokens() {
    return new List<String>{
      '{{{Product_Brief}}}',
      '{{Product_Brief}}',
      '{!Product_Brief}',
      BWM_EmailConstants.PRODUCT_BRIEF_PLACEHOLDER,
      '{{product_brief}}',
      '{{PRODUCT_BRIEF}}',
      '{!product_brief}'
    };
  }

  @TestVisible
  static String formatAsHtml(String plainBrief) {
    if (String.isBlank(plainBrief)) {
      return '';
    }

    List<String> htmlParts = new List<String>();
    for (String line : plainBrief.split('\n')) {
      String trimmed = line == null ? '' : line.trim();
      if (String.isBlank(trimmed)) {
        continue;
      }
      htmlParts.add('<p>' + escapeHtml(trimmed) + '</p>');
    }
    return String.join(htmlParts, '\n\n');
  }

  public static String injectIntoContent(
    String content,
    String plainBrief,
    String htmlBrief,
    SObject record
  ) {
    if (String.isBlank(content) || String.isBlank(plainBrief)) {
      return content;
    }

    content = replaceProductBriefMergeTokens(content, plainBrief, htmlBrief);
    content = replaceRenderedProductCategory(content, record, plainBrief, htmlBrief);

    if (!containsBriefContent(content, plainBrief)) {
      if (looksLikeHtml(content)) {
        content = injectIntoHtml(content, htmlBrief);
      } else {
        content = injectIntoPlainText(content, plainBrief);
      }
    }

    return content;
  }

  private static Boolean containsBriefContent(String content, String plainBrief) {
    if (String.isBlank(content) || String.isBlank(plainBrief)) {
      return false;
    }

    Integer newlineIndex = plainBrief.indexOf('\n');
    String excerpt = newlineIndex > 0
      ? plainBrief.substring(0, newlineIndex).trim()
      : plainBrief.trim();
    return String.isNotBlank(excerpt) && content.contains(excerpt);
  }

  @TestVisible
  static String replaceRenderedProductCategory(
    String content,
    SObject record,
    String plainBrief,
    String htmlBrief
  ) {
    if (String.isBlank(content) || String.isBlank(plainBrief) || record == null) {
      return content;
    }
    if (containsBriefContent(content, plainBrief)) {
      return content;
    }

    String productCategory = BWM_FieldValueResolver.resolveRecord(
      record,
      'Product_Category__c'
    );
    if (String.isBlank(productCategory)) {
      return content;
    }

    if (looksLikeHtml(content)) {
      String categoryPattern = '(?is)<p>\\s*' +
        escapeRegex(productCategory) +
        '\\s*</p>';
      String replaced = content.replaceAll(categoryPattern, htmlBrief);
      if (replaced != content) {
        return replaced;
      }
    }

    if (content.contains(productCategory)) {
      return content.replace(productCategory, plainBrief);
    }

    return content;
  }

  @TestVisible
  static String injectIntoHtml(String htmlContent, String htmlBrief) {
    if (String.isBlank(htmlContent) || String.isBlank(htmlBrief)) {
      return htmlContent;
    }

    String replaced = htmlContent.replaceAll(
      '(?is)<p>\\s*(?:&nbsp;|\\u00a0|\\s)*</p>\\s*<p>\\s*(?:&nbsp;|\\u00a0|\\s)*</p>',
      htmlBrief
    );
    if (replaced != htmlContent) {
      return replaced;
    }

    Integer markerIndex = htmlContent.toLowerCase().indexOf('for more details, please find attached');
    if (markerIndex < 0) {
      return htmlContent;
    }

    return htmlContent.substring(0, markerIndex) +
      htmlBrief +
      '\n\n' +
      htmlContent.substring(markerIndex);
  }

  @TestVisible
  static String injectIntoPlainText(String plainContent, String plainBrief) {
    if (String.isBlank(plainContent) || String.isBlank(plainBrief)) {
      return plainContent;
    }

    String marker = 'For more details, please find attached';
    Integer markerIndex = plainContent.indexOf(marker);
    if (markerIndex < 0) {
      return plainContent + '\n\n' + plainBrief;
    }

    return plainContent.substring(0, markerIndex).trim() +
      '\n\n' +
      plainBrief +
      '\n\n' +
      plainContent.substring(markerIndex);
  }

  @TestVisible
  static void setBriefMapForTest(
    Map<String, BWM_Email_Department_Brochure__mdt> values
  ) {
    briefByDepartment = values == null
      ? new Map<String, BWM_Email_Department_Brochure__mdt>()
      : values;
  }

  @TestVisible
  static void clearCache() {
    briefByDepartment = null;
  }

  private static BWM_Email_Department_Brochure__mdt resolveRow(SObject record) {
    String departmentName = BWM_EmailBrochureAttachmentService.resolveDepartmentName(
      record
    );
    if (String.isBlank(departmentName)) {
      return null;
    }

    loadBriefs();
    return briefByDepartment.get(departmentName);
  }

  private static void loadBriefs() {
    if (briefByDepartment != null) {
      return;
    }

    briefByDepartment = new Map<String, BWM_Email_Department_Brochure__mdt>();
    for (BWM_Email_Department_Brochure__mdt row : [
      SELECT Department_Name__c, Product_Brief__c
      FROM BWM_Email_Department_Brochure__mdt
    ]) {
      if (String.isNotBlank(row.Product_Brief__c)) {
        briefByDepartment.put(row.Department_Name__c, row);
      }
    }
  }

  private static Boolean looksLikeHtml(String content) {
    return content != null && content.contains('<');
  }

  private static String escapeHtml(String value) {
    if (String.isBlank(value)) {
      return '';
    }
    return value
      .replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;');
  }

  private static String escapeRegex(String value) {
    if (String.isBlank(value)) {
      return '';
    }
    return value.replaceAll('([\\\\.*+?^${}()|\\[\\]])', '\\\\$1');
  }

  private static String nullToEmpty(String value) {
    return value == null ? '' : value;
  }
}