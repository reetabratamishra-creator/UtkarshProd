/**
 * @description   Resolves brochure / WhatsApp document URLs used in messaging
 *                templates.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_BrochureService {
  public static final String DEFAULT_FILE_NAME = 'Testing File';

  private static Map<String, BWM_Department_Brochure__mdt> brochureByDepartment;
  private static Map<String, String> publicDownloadUrlByFileName;

  public class BrochureInfo {
    public String documentId;
    public String brochureUrl;
    public String fileName;
    public String contentFileTitle;
    public String staticResourceName;
    public String staticResourceUrl;
    public String publicDownloadUrl;
  }

  public static BrochureInfo getBrochureForDepartment(String departmentName) {
    if (String.isBlank(departmentName)) {
      return null;
    }

    loadBrochures();
    BWM_Department_Brochure__mdt row = brochureByDepartment.get(departmentName);
    if (row == null) {
      return null;
    }

    BrochureInfo info = new BrochureInfo();
    info.documentId = row.WhatsApp_Document_Id__c;
    info.brochureUrl = row.Brochure_URL__c;
    info.staticResourceName = row.Static_Resource_Name__c;
    info.contentFileTitle = row.Content_File_Title__c;
    info.fileName = String.isBlank(row.Brochure_File_Name__c)
      ? DEFAULT_FILE_NAME
      : row.Brochure_File_Name__c;
    info.staticResourceUrl = buildStaticResourceUrl(info.staticResourceName);
    info.publicDownloadUrl = resolveDepartmentPublicUrl(info);
    return info;
  }

  public static String resolveCorporateWhatsAppUrl(
    BWM_Messaging_Settings__mdt settings
  ) {
    String fileTitle = resolveCorporateFileTitle(settings);
    if (String.isNotBlank(fileTitle)) {
      String fileUrl = BWM_BrochureFileService.getPublicDownloadUrl(fileTitle);
      if (isValidWhatsAppDocumentUrl(fileUrl) && !isSandboxOrInaccessibleUrl(fileUrl)) {
        return fileUrl.trim();
      }
    }

    if (
      settings != null &&
      isValidPortalBrochureUrl(settings.Default_Brochure_Portal_URL__c)
    ) {
      return settings.Default_Brochure_Portal_URL__c.trim();
    }

    return BWM_MessagingConstants.DEFAULT_PORTAL_BROCHURE_URL;
  }

  /**
   * @description Resolves the PDF URL for WhatsApp DOCUMENT headers using brochure mode
   *              (Department / Corporate). Falls back to corporate portal URL when the
   *              department URL is blank or sandbox-only (not reachable by WhatsApp).
   * @param settings Messaging settings (corporate defaults).
   * @param record Lead/Opportunity/Account/Contact/Offline record (for department).
   * @param brochureMode Brochure_Attachment_Mode__c value (Corporate, Department, or blank).
   * @return WhatsApp-reachable document URL.
   */
  public static String resolveBrochureUrlForSend(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    String brochureMode
  ) {
    String mode = String.isBlank(brochureMode)
      ? BWM_MessagingConstants.BROCHURE_ATTACH_CORPORATE
      : brochureMode.trim();

    if (mode == BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT) {
      String departmentName = BWM_FieldValueResolver.resolveDepartmentName(record);
      BrochureInfo brochure = getBrochureForDepartment(departmentName);
      String departmentUrl = resolveWhatsAppDocumentUrl(
        brochure,
        settings == null ? null : settings.Default_Brochure_Portal_URL__c
      );
      if (
        String.isNotBlank(departmentUrl) &&
        !isSandboxOrInaccessibleUrl(departmentUrl) &&
        !isCorporateBrochureUrl(departmentUrl)
      ) {
        return departmentUrl.trim();
      }
      // Sandbox Content File links are not WhatsApp-reachable — use the department
      // portal PDF before falling back to corporate.
      if (
        brochure != null &&
        isValidPortalBrochureUrl(brochure.brochureUrl) &&
        !isCorporateBrochureUrl(brochure.brochureUrl)
      ) {
        return brochure.brochureUrl.trim();
      }
      return resolveCorporateWhatsAppUrl(settings);
    }

    return resolveCorporateWhatsAppUrl(settings);
  }

  /**
   * @description True when URL is blank or hosted on Salesforce sandbox file CDN
   *              (WhatsApp cannot download those links).
   * @param url Candidate document URL.
   * @return True when URL should not be used for WhatsApp document headers.
   */
  public static Boolean isSandboxOrInaccessibleUrl(String url) {
    if (String.isBlank(url)) {
      return true;
    }
    String normalized = url.trim().toLowerCase();
    return normalized.contains('.sandbox.') ||
      normalized.contains('sandbox.file.force.com');
  }

  /**
   * Department WhatsApp document URL resolution:
   * 1) Uploaded Salesforce File (Content_File_Title__c)
   * 2) Non-corporate Bluewave portal URL
   * 3) Legacy ContentDistribution by brochure file name
   * 4) Corporate / default portal brochure
   */
  public static String resolveWhatsAppDocumentUrl(
    BrochureInfo brochure,
    String defaultPortalUrl
  ) {
    if (brochure != null && String.isNotBlank(brochure.publicDownloadUrl)) {
      return brochure.publicDownloadUrl.trim();
    }

    if (
      brochure != null &&
      isValidPortalBrochureUrl(brochure.brochureUrl) &&
      !isCorporateBrochureUrl(brochure.brochureUrl)
    ) {
      return brochure.brochureUrl.trim();
    }

    if (isValidPortalBrochureUrl(defaultPortalUrl)) {
      return defaultPortalUrl.trim();
    }

    return BWM_MessagingConstants.DEFAULT_PORTAL_BROCHURE_URL;
  }

  public static String buildStaticResourceUrl(String resourceName) {
    if (String.isBlank(resourceName)) {
      return null;
    }

    return URL.getOrgDomainUrl().toExternalForm() +
      '/resource/' +
      String.valueOf(Datetime.now().getTime()) +
      '/' +
      resourceName;
  }

  public static Boolean isCorporateBrochureUrl(String url) {
    if (String.isBlank(url)) {
      return false;
    }
    return url.trim().toLowerCase().contains('corporate_brochure');
  }

  public static Boolean isValidPortalBrochureUrl(String url) {
    if (String.isBlank(url)) {
      return false;
    }
    String normalized = url.trim().toLowerCase();
    return normalized.contains(BWM_MessagingConstants.BROCHURE_PORTAL_HOST) &&
      normalized.endsWith('.pdf');
  }

  public static Boolean isValidWhatsAppDocumentUrl(String url) {
    if (String.isBlank(url)) {
      return false;
    }
    if (isValidPortalBrochureUrl(url)) {
      return true;
    }
    String normalized = url.trim().toLowerCase();
    return normalized.contains('file.force.com') &&
      normalized.contains('/sfc/dist/version/download/');
  }

  private static String resolveDepartmentPublicUrl(BrochureInfo info) {
    if (info == null) {
      return null;
    }

    if (String.isNotBlank(info.contentFileTitle)) {
      String fileUrl = BWM_BrochureFileService.getPublicDownloadUrl(
        info.contentFileTitle
      );
      if (isValidWhatsAppDocumentUrl(fileUrl)) {
        return fileUrl;
      }
    }

    return getLegacyPublicDownloadUrl(info.fileName);
  }

  private static String getLegacyPublicDownloadUrl(String fileName) {
    if (String.isBlank(fileName)) {
      return null;
    }
    loadPublicDownloadUrls();
    return publicDownloadUrlByFileName.get(fileName);
  }

  private static String resolveCorporateFileTitle(
    BWM_Messaging_Settings__mdt settings
  ) {
    if (
      settings != null &&
      String.isNotBlank(settings.Corporate_Brochure_File_Title__c)
    ) {
      return settings.Corporate_Brochure_File_Title__c.trim();
    }
    return BWM_BrochureFileService.DEFAULT_CORPORATE_FILE_TITLE;
  }

  private static void loadPublicDownloadUrls() {
    if (publicDownloadUrlByFileName != null) {
      return;
    }

    publicDownloadUrlByFileName = new Map<String, String>();
    for (ContentDistribution dist : [
      SELECT Name, ContentDownloadUrl
      FROM ContentDistribution
      ORDER BY CreatedDate DESC
    ]) {
      if (
        String.isBlank(dist.Name) ||
        String.isBlank(dist.ContentDownloadUrl) ||
        publicDownloadUrlByFileName.containsKey(dist.Name)
      ) {
        continue;
      }
      publicDownloadUrlByFileName.put(dist.Name, dist.ContentDownloadUrl);
    }
  }

  private static void loadBrochures() {
    if (brochureByDepartment != null) {
      return;
    }

    brochureByDepartment = new Map<String, BWM_Department_Brochure__mdt>();
    for (BWM_Department_Brochure__mdt row : [
      SELECT
        Department_Name__c,
        WhatsApp_Document_Id__c,
        Brochure_URL__c,
        Brochure_File_Name__c,
        Content_File_Title__c,
        Static_Resource_Name__c
      FROM BWM_Department_Brochure__mdt
    ]) {
      brochureByDepartment.put(row.Department_Name__c, row);
    }
  }

  @TestVisible
  static void setBrochureMapForTest(
    Map<String, BWM_Department_Brochure__mdt> values
  ) {
    brochureByDepartment = values == null
      ? new Map<String, BWM_Department_Brochure__mdt>()
      : values;
  }

  @TestVisible
  static void setPublicDownloadUrlMapForTest(Map<String, String> values) {
    publicDownloadUrlByFileName = values == null
      ? new Map<String, String>()
      : values;
  }

  @TestVisible
  static void clearCache() {
    brochureByDepartment = null;
    publicDownloadUrlByFileName = null;
    BWM_BrochureFileService.clearCache();
  }
}