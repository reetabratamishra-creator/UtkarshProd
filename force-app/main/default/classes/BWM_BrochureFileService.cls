public without sharing class BWM_BrochureFileService {
  public static final String DEFAULT_CORPORATE_FILE_TITLE = 'Corporate Brochure';

  // Kept for reference: Salesforce may rewrite attachments over this size as HTML stubs.
  public static final Integer INLINE_ATTACHMENT_MAX_BYTES = 3 * 1024 * 1024;

  private static Map<String, ContentVersion> versionByTitle;
  private static Map<String, String> publicUrlByTitle;

  public class FileBrochure {
    public String fileTitle;
    public String attachmentFileName;
    public Blob body;
    public Integer contentSize;
    public String publicDownloadUrl;
  }

  public static FileBrochure resolveFileBrochure(
    String contentFileTitle,
    String attachmentFileName
  ) {
    return resolveFileBrochure(contentFileTitle, attachmentFileName, true);
  }

  public static FileBrochure resolveFileBrochure(
    String contentFileTitle,
    String attachmentFileName,
    Boolean includeBody
  ) {
    if (String.isBlank(contentFileTitle)) {
      return null;
    }

    String normalizedTitle = contentFileTitle.trim();
    ContentVersion version = getLatestPdfVersion(normalizedTitle);
    if (version == null) {
      return null;
    }

    FileBrochure brochure = new FileBrochure();
    brochure.fileTitle = normalizedTitle;
    brochure.contentSize = version.ContentSize;
    brochure.attachmentFileName = resolveAttachmentFileName(
      attachmentFileName,
      normalizedTitle,
      version.Title
    );
    // Read-only here. Callers that need a link must use ensurePublicDownloadUrl
    // (email path only — never before HTTP callouts).
    brochure.publicDownloadUrl = resolvePublicDownloadUrl(
      normalizedTitle,
      version.Id
    );
    if (includeBody == true) {
      brochure.body = loadVersionData(version.Id);
    }
    return brochure;
  }

  /**
   * Read-only lookup. Never inserts ContentDistribution — safe before callouts
   * (WhatsApp / HTTP). Use ensurePublicDownloadUrl from email-only paths.
   */
  public static String getPublicDownloadUrl(String contentFileTitle) {
    if (String.isBlank(contentFileTitle)) {
      return null;
    }
    ContentVersion version = getLatestPdfVersion(contentFileTitle.trim());
    if (version == null) {
      return null;
    }
    return resolvePublicDownloadUrl(contentFileTitle.trim(), version.Id);
  }

  public static Messaging.EmailFileAttachment buildEmailAttachmentFromPublicUrl(
    String downloadUrl,
    String attachmentFileName
  ) {
    if (String.isBlank(downloadUrl)) {
      return null;
    }

    Blob body = fetchPdfBlobFromPublicUrl(downloadUrl.trim());
    if (body == null || body.size() == 0) {
      return null;
    }

    if (body.size() > INLINE_ATTACHMENT_MAX_BYTES) {
      return null;
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    attachment.setFileName(resolveAttachmentFileName(attachmentFileName, null, null));
    attachment.setBody(body);
    attachment.setContentType('application/pdf');
    attachment.setInline(false);
    return attachment;
  }

  public static Messaging.EmailFileAttachment buildEmailAttachment(
    String contentFileTitle,
    String attachmentFileName
  ) {
    ContentVersion version = getEmailPdfVersion(contentFileTitle);
    if (version == null) {
      return null;
    }

    Blob body = loadVersionDataForEmail(contentFileTitle, version);
    if (body == null || body.size() == 0) {
      return null;
    }

    if (body.size() > INLINE_ATTACHMENT_MAX_BYTES) {
      return null;
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    attachment.setFileName(
      resolveAttachmentFileName(
        attachmentFileName,
        contentFileTitle.trim(),
        version.Title
      )
    );
    attachment.setBody(body);
    attachment.setContentType('application/pdf');
    attachment.setInline(false);
    return attachment;
  }

  public static Boolean hasPdfContentVersion(String contentFileTitle) {
    return getEmailPdfVersion(contentFileTitle) != null;
  }

  /**
   * Email-only: pick a PDF version that fits Salesforce inline attachment limits.
   * Prefers the newest file at or under the limit; otherwise the smallest file.
   * WhatsApp/RCS should keep using getLatestPdfVersion() for full-quality files.
   */
  public static ContentVersion getEmailPdfVersion(String contentFileTitle) {
    if (String.isBlank(contentFileTitle)) {
      return null;
    }

    String normalized = contentFileTitle.trim();
    if (Test.isRunningTest()) {
      loadVersions();
      if (versionByTitle.containsKey(normalized)) {
        return versionByTitle.get(normalized);
      }
    }

    List<ContentVersion> versions = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId, CreatedDate
      FROM ContentVersion
      WHERE
        Title = :normalized
        AND (
          FileExtension = NULL
          OR FileExtension = 'pdf'
          OR FileExtension = 'PDF'
        )
      WITH SYSTEM_MODE
      ORDER BY CreatedDate DESC
    ];
    if (versions.isEmpty()) {
      return null;
    }

    ContentVersion smallest = null;
    for (ContentVersion version : versions) {
      Integer size = version.ContentSize == null ? 0 : version.ContentSize;
      if (size <= INLINE_ATTACHMENT_MAX_BYTES) {
        return version;
      }
      if (
        smallest == null ||
        size <
        (smallest.ContentSize == null
          ? 2147483647
          : smallest.ContentSize)
      ) {
        smallest = version;
      }
    }
    return smallest;
  }


  public static String ensurePublicDownloadUrl(
    String contentFileTitle,
    Id contentVersionId
  ) {
    String existing = resolvePublicDownloadUrl(contentFileTitle, contentVersionId);
    if (String.isNotBlank(existing)) {
      return existing;
    }
    if (contentVersionId == null) {
      return null;
    }

    String distributionName = String.isNotBlank(contentFileTitle)
      ? contentFileTitle.trim()
      : String.valueOf(contentVersionId);

    ContentDistribution distribution = new ContentDistribution();
    distribution.Name = distributionName.left(255);
    distribution.ContentVersionId = contentVersionId;
    distribution.PreferencesAllowViewInBrowser = true;
    distribution.PreferencesAllowOriginalDownload = true;
    distribution.PreferencesLinkLatestVersion = true;
    distribution.PreferencesPasswordRequired = false;
    distribution.PreferencesNotifyOnVisit = false;
    insert distribution;

    List<ContentDistribution> created = [
      SELECT ContentDownloadUrl
      FROM ContentDistribution
      WHERE Id = :distribution.Id
      LIMIT 1
    ];
    if (created.isEmpty() || String.isBlank(created[0].ContentDownloadUrl)) {
      return null;
    }

    publicUrlByTitle = null;
    loadPublicUrls();
    return created[0].ContentDownloadUrl;
  }

  public static ContentVersion getLatestPdfVersion(String contentFileTitle) {
    if (String.isBlank(contentFileTitle)) {
      return null;
    }

    loadVersions();
    if (versionByTitle.containsKey(contentFileTitle)) {
      return versionByTitle.get(contentFileTitle);
    }

    String normalized = contentFileTitle.trim();
    if (versionByTitle.containsKey(normalized)) {
      return versionByTitle.get(normalized);
    }

    return null;
  }

  public static String resolvePublicDownloadUrl(
    String contentFileTitle,
    Id contentVersionId
  ) {
    if (String.isBlank(contentFileTitle) && contentVersionId == null) {
      return null;
    }

    loadPublicUrls();

    if (String.isNotBlank(contentFileTitle)) {
      String normalized = contentFileTitle.trim();
      if (publicUrlByTitle.containsKey(normalized)) {
        return publicUrlByTitle.get(normalized);
      }
    }

    if (contentVersionId != null) {
      String versionKey = String.valueOf(contentVersionId);
      if (publicUrlByTitle.containsKey(versionKey)) {
        return publicUrlByTitle.get(versionKey);
      }
    }

    return null;
  }

  private static Blob loadVersionData(Id contentVersionId) {
    if (contentVersionId == null) {
      return null;
    }
    List<ContentVersion> rows = [
      SELECT VersionData
      FROM ContentVersion
      WHERE Id = :contentVersionId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0].VersionData;
  }

  /**
   * Email-only: direct VersionData when permitted; otherwise public file URL
   * (queueable callout). Avoids oversized static-resource fallback for users
   * without Files library access.
   */
  private static Blob loadVersionDataForEmail(
    String contentFileTitle,
    ContentVersion version
  ) {
    if (version == null) {
      return null;
    }

    Blob body = loadVersionDataFromTestMap(version);
    if (body != null && body.size() > 0) {
      return body;
    }

    // Queueable email runs as the submitting user, who often cannot read VersionData.
    // Prefer the pre-created public distribution URL (read-only lookup, no DML) first.
    if (canPerformEmailFileCallout()) {
      body = fetchVersionDataViaPublicUrl(contentFileTitle, version.Id);
      if (body != null && body.size() > 0) {
        return body;
      }
    }

    body = loadVersionDataSystem(version.Id);
    if (body != null && body.size() > 0) {
      return body;
    }

    if (canPerformEmailFileCallout()) {
      return fetchVersionDataViaPublicUrl(contentFileTitle, version.Id);
    }

    return null;
  }

  private static Blob loadVersionDataSystem(Id contentVersionId) {
    if (contentVersionId == null) {
      return null;
    }
    List<ContentVersion> rows = [
      SELECT VersionData
      FROM ContentVersion
      WHERE Id = :contentVersionId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0].VersionData;
  }

  private static Blob loadVersionDataFromTestMap(ContentVersion version) {
    if (!Test.isRunningTest() || version == null) {
      return null;
    }

    loadVersions();
    if (String.isNotBlank(version.Title) && versionByTitle.containsKey(version.Title)) {
      ContentVersion mapped = versionByTitle.get(version.Title);
      if (mapped != null && mapped.VersionData != null && mapped.VersionData.size() > 0) {
        return mapped.VersionData;
      }
    }
    if (version.VersionData != null && version.VersionData.size() > 0) {
      return version.VersionData;
    }
    return null;
  }

  private static Boolean canPerformEmailFileCallout() {
    if (Test.isRunningTest()) {
      return Limits.getLimitCallouts() > 0;
    }
    return System.isQueueable() || System.isBatch() || System.isFuture();
  }

  private static Blob fetchVersionDataViaPublicUrl(
    String contentFileTitle,
    Id contentVersionId
  ) {
    String downloadUrl = resolvePublicDownloadUrlForEmail(
      contentFileTitle,
      contentVersionId
    );
    return fetchPdfBlobFromPublicUrl(downloadUrl);
  }

  private static Blob fetchPdfBlobFromPublicUrl(String downloadUrl) {
    if (String.isBlank(downloadUrl)) {
      return null;
    }

    if (!canPerformEmailFileCallout()) {
      return null;
    }

    downloadUrl = preferPdfDownloadUrl(downloadUrl);

    try {
      HttpRequest request = new HttpRequest();
      request.setEndpoint(downloadUrl);
      request.setMethod('GET');
      request.setTimeout(120000);

      HttpResponse response = new Http().send(request);
      if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        return null;
      }

      Blob body = response.getBodyAsBlob();
      return body == null || body.size() == 0 ? null : body;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        'BWM_BrochureFileService brochure callout failed: ' + ex.getMessage()
      );
      return null;
    }
  }

  private static String resolvePublicDownloadUrlForEmail(
    String contentFileTitle,
    Id contentVersionId
  ) {
    if (String.isBlank(contentFileTitle) && contentVersionId == null) {
      return null;
    }

    loadPublicUrlsForEmail();

    if (String.isNotBlank(contentFileTitle)) {
      String normalized = contentFileTitle.trim();
      if (publicUrlByTitleEmail.containsKey(normalized)) {
        return publicUrlByTitleEmail.get(normalized);
      }
    }

    if (contentVersionId != null) {
      String versionKey = String.valueOf(contentVersionId);
      if (publicUrlByTitleEmail.containsKey(versionKey)) {
        return publicUrlByTitleEmail.get(versionKey);
      }
    }

    return null;
  }

  private static Map<String, String> publicUrlByTitleEmail;

  private static void loadPublicUrlsForEmail() {
    if (publicUrlByTitleEmail != null) {
      return;
    }

    publicUrlByTitleEmail = new Map<String, String>();
    for (ContentDistribution dist : [
      SELECT Name, ContentDownloadUrl, ContentVersionId
      FROM ContentDistribution
      WITH SYSTEM_MODE
      ORDER BY CreatedDate DESC
    ]) {
      if (String.isBlank(dist.ContentDownloadUrl)) {
        continue;
      }
      if (
        String.isNotBlank(dist.Name) &&
        !publicUrlByTitleEmail.containsKey(dist.Name.trim())
      ) {
        publicUrlByTitleEmail.put(dist.Name.trim(), dist.ContentDownloadUrl);
      }
      if (dist.ContentVersionId != null) {
        String versionKey = String.valueOf(dist.ContentVersionId);
        if (!publicUrlByTitleEmail.containsKey(versionKey)) {
          publicUrlByTitleEmail.put(versionKey, dist.ContentDownloadUrl);
        }
      }
    }
  }

  private static String preferPdfDownloadUrl(String downloadUrl) {
    if (String.isBlank(downloadUrl)) {
      return downloadUrl;
    }
    if (downloadUrl.contains('asPdf=false')) {
      return downloadUrl.replace('asPdf=false', 'asPdf=true');
    }
    if (!downloadUrl.contains('asPdf=')) {
      String joiner = downloadUrl.contains('?') ? '&' : '?';
      return downloadUrl + joiner + 'asPdf=true';
    }
    return downloadUrl;
  }

  private static String resolveAttachmentFileName(
    String preferredName,
    String contentFileTitle,
    String versionTitle
  ) {
    String baseName = String.isNotBlank(preferredName)
      ? preferredName.trim()
      : String.isNotBlank(versionTitle)
        ? versionTitle.trim()
        : contentFileTitle.trim();

    if (!baseName.toLowerCase().endsWith('.pdf')) {
      baseName += '.pdf';
    }
    return baseName;
  }

  private static void loadVersions() {
    if (versionByTitle != null) {
      return;
    }

    versionByTitle = new Map<String, ContentVersion>();
    for (ContentVersion version : [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId
      FROM ContentVersion
      WHERE IsLatest = TRUE AND FileExtension = 'pdf'
      ORDER BY CreatedDate DESC
    ]) {
      if (String.isBlank(version.Title) || versionByTitle.containsKey(version.Title)) {
        continue;
      }
      versionByTitle.put(version.Title.trim(), version);
    }
  }

  private static void loadPublicUrls() {
    if (publicUrlByTitle != null) {
      return;
    }

    publicUrlByTitle = new Map<String, String>();
    for (ContentDistribution dist : [
      SELECT Name, ContentDownloadUrl, ContentVersionId
      FROM ContentDistribution
      ORDER BY CreatedDate DESC
    ]) {
      if (String.isBlank(dist.ContentDownloadUrl)) {
        continue;
      }
      if (
        String.isNotBlank(dist.Name) &&
        !publicUrlByTitle.containsKey(dist.Name.trim())
      ) {
        publicUrlByTitle.put(dist.Name.trim(), dist.ContentDownloadUrl);
      }
      if (dist.ContentVersionId != null) {
        String versionKey = String.valueOf(dist.ContentVersionId);
        if (!publicUrlByTitle.containsKey(versionKey)) {
          publicUrlByTitle.put(versionKey, dist.ContentDownloadUrl);
        }
      }
    }
  }

  @TestVisible
  static void setVersionMapForTest(Map<String, ContentVersion> values) {
    versionByTitle = values == null ? new Map<String, ContentVersion>() : values;
  }

  @TestVisible
  static void setPublicUrlMapForTest(Map<String, String> values) {
    publicUrlByTitle = values == null ? new Map<String, String>() : values;
  }

  @TestVisible
  public static void clearCache() {
    versionByTitle = null;
    publicUrlByTitle = null;
    publicUrlByTitleEmail = null;
  }
}