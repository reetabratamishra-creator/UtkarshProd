public without sharing class BWM_EmailBrochureAttachmentService {
  private static Map<String, BWM_Email_Department_Brochure__mdt> brochureByDepartment;

  public class AttachmentInfo {
    public String staticResourceName;
    public String fileName;
    public String contentFileTitle;
    public String publicDownloadUrl;
  }

  public static List<Messaging.EmailFileAttachment> buildAttachments(
    BWM_Email_Settings__mdt settings,
    BWM_Email_Template_Mapping__mdt mapping,
    SObject record
  ) {
    List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
    if (mapping == null || record == null) {
      return attachments;
    }

    String mode = mapping.Brochure_Attachment_Mode__c;
    if (String.isBlank(mode) || mode == BWM_EmailConstants.BROCHURE_ATTACH_NONE) {
      return attachments;
    }

    if (mode == BWM_EmailConstants.BROCHURE_ATTACH_CORPORATE) {
      Messaging.EmailFileAttachment corporateAttachment = buildCorporateAttachment(
        settings
      );
      if (corporateAttachment != null) {
        attachments.add(corporateAttachment);
      }
      return attachments;
    }

    if (mode == BWM_EmailConstants.BROCHURE_ATTACH_DEPARTMENT) {
      AttachmentInfo departmentInfo = resolveDepartmentAttachment(record);
      if (departmentInfo == null) {
        return attachments;
      }
      Messaging.EmailFileAttachment departmentAttachment = buildDepartmentAttachment(
        departmentInfo
      );
      if (departmentAttachment != null) {
        attachments.add(departmentAttachment);
      }
      return attachments;
    }

    if (mode == BWM_EmailConstants.BROCHURE_ATTACH_DEALER_MONTHLY) {
      if (record instanceof Account) {
        Messaging.EmailFileAttachment monthlyPdf =
          BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(
            record.Id
          );
        if (monthlyPdf != null) {
          attachments.add(monthlyPdf);
        }
      }
    }

    return attachments;
  }

  public static AttachmentInfo resolveDepartmentAttachment(SObject record) {
    String departmentName = resolveDepartmentName(record);
    if (String.isBlank(departmentName)) {
      return null;
    }

    loadBrochures();
    BWM_Email_Department_Brochure__mdt row = brochureByDepartment.get(departmentName);
    if (row == null) {
      return null;
    }

    AttachmentInfo info = new AttachmentInfo();
    info.staticResourceName = row.Static_Resource_Name__c;
    info.contentFileTitle = row.Content_File_Title__c;
    info.publicDownloadUrl = row.Public_Download_Url__c;
    info.fileName = String.isBlank(row.File_Name__c)
      ? row.Static_Resource_Name__c + '.pdf'
      : row.File_Name__c;
    return info;
  }

  @TestVisible
  static void setBrochureMapForTest(
    Map<String, BWM_Email_Department_Brochure__mdt> values
  ) {
    brochureByDepartment = values == null
      ? new Map<String, BWM_Email_Department_Brochure__mdt>()
      : values;
  }

  public static String resolveDepartmentName(SObject record) {
    if (record instanceof Lead) {
      return ((Lead) record).Department_Name__c;
    }
    if (record instanceof Opportunity) {
      return ((Opportunity) record).Department_Name__c;
    }
    return null;
  }

  private static Messaging.EmailFileAttachment buildCorporateAttachment(
    BWM_Email_Settings__mdt settings
  ) {
    String fileTitle = resolveCorporateFileTitle(settings);
    String publicUrl = resolveCorporatePublicUrl(settings);
    Messaging.EmailFileAttachment fileAttachment = resolveEmailAttachment(
      fileTitle,
      'Corporate_Brochure.pdf',
      resolveCorporateResourceName(settings),
      'Corporate_Brochure.pdf',
      publicUrl
    );
    return fileAttachment;
  }

  private static Messaging.EmailFileAttachment buildDepartmentAttachment(
    AttachmentInfo departmentInfo
  ) {
    if (departmentInfo == null) {
      return null;
    }

    return resolveEmailAttachment(
      departmentInfo.contentFileTitle,
      departmentInfo.fileName,
      departmentInfo.staticResourceName,
      departmentInfo.fileName,
      departmentInfo.publicDownloadUrl
    );
  }

  private static Messaging.EmailFileAttachment resolveEmailAttachment(
    String contentFileTitle,
    String attachmentFileName,
    String staticResourceName,
    String staticResourceFileName,
    String publicDownloadUrl
  ) {
    // Prefer uploaded Salesforce Files (org Files library) first.
    if (String.isNotBlank(contentFileTitle)) {
      Messaging.EmailFileAttachment attachment = BWM_BrochureFileService.buildEmailAttachment(
        contentFileTitle,
        attachmentFileName
      );
      if (attachment != null) {
        return attachment;
      }
    }

    if (String.isNotBlank(publicDownloadUrl)) {
      Messaging.EmailFileAttachment publicAttachment = BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
        publicDownloadUrl,
        attachmentFileName
      );
      if (publicAttachment != null) {
        return publicAttachment;
      }
    }

    return buildFromStaticResource(staticResourceName, staticResourceFileName);
  }

  private static String resolveCorporateFileTitle(
    BWM_Email_Settings__mdt settings
  ) {
    if (
      settings != null &&
      String.isNotBlank(settings.Corporate_Brochure_File_Title__c)
    ) {
      return settings.Corporate_Brochure_File_Title__c.trim();
    }
    return BWM_BrochureFileService.DEFAULT_CORPORATE_FILE_TITLE;
  }

  private static String resolveCorporateResourceName(
    BWM_Email_Settings__mdt settings
  ) {
    if (
      settings != null &&
      String.isNotBlank(settings.Corporate_Brochure_Static_Resource__c)
    ) {
      return settings.Corporate_Brochure_Static_Resource__c.trim();
    }
    return BWM_EmailConstants.DEFAULT_CORPORATE_BROCHURE_RESOURCE;
  }

  private static String resolveCorporatePublicUrl(
    BWM_Email_Settings__mdt settings
  ) {
    if (
      settings != null &&
      String.isNotBlank(settings.Corporate_Brochure_Public_Url__c)
    ) {
      return settings.Corporate_Brochure_Public_Url__c.trim();
    }
    return null;
  }

  private static Messaging.EmailFileAttachment buildFromStaticResource(
    String resourceName,
    String defaultFileName
  ) {
    if (String.isBlank(resourceName)) {
      return null;
    }

    List<StaticResource> resources = [
      SELECT Name, Body, ContentType
      FROM StaticResource
      WHERE Name = :resourceName
      LIMIT 1
    ];
    if (resources.isEmpty()) {
      return null;
    }

    StaticResource resource = resources[0];
    if (
      resource.Body != null &&
      resource.Body.size() > BWM_BrochureFileService.INLINE_ATTACHMENT_MAX_BYTES
    ) {
      return null;
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    String fileName = String.isBlank(defaultFileName)
      ? resource.Name + '.pdf'
      : defaultFileName;
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName += '.pdf';
    }
    attachment.setFileName(fileName);
    attachment.setBody(resource.Body);
    attachment.setContentType('application/pdf');
    attachment.setInline(false);
    return attachment;
  }

  private static void loadBrochures() {
    if (brochureByDepartment != null) {
      return;
    }

    brochureByDepartment = new Map<String, BWM_Email_Department_Brochure__mdt>();
    for (BWM_Email_Department_Brochure__mdt row : [
      SELECT
        Department_Name__c,
        Static_Resource_Name__c,
        File_Name__c,
        Content_File_Title__c,
        Public_Download_Url__c
      FROM BWM_Email_Department_Brochure__mdt
    ]) {
      brochureByDepartment.put(row.Department_Name__c, row);
    }
  }

  @TestVisible
  static void clearCache() {
    brochureByDepartment = null;
    BWM_BrochureFileService.clearCache();
  }
}