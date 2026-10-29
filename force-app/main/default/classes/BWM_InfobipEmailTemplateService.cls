/**
 * @description   Fetches Infobip/Bluewave email templates for campaign UI selection.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_InfobipEmailTemplateService {
  private static final String TEMPLATES_PATH = '/email/1/templates';
  private static final Integer PAGE_SIZE = 20;

  public class TemplateOption {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String createdAt;
    @AuraEnabled
    public String updatedAt;
    @AuraEnabled
    public String imagePreviewUrl;
  }

  public class SubjectOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
  }

  public class TemplateMetadata {
    public String subject;
    public String name;
    public String fromAddress;
    public String replyTo;

    public String resolveSubjectForLog() {
      return sanitizeSubjectForLog(subject);
    }
  }

  public static List<TemplateOption> fetchTemplates() {
    List<TemplateOption> allTemplates = new List<TemplateOption>();
    Integer pageNumber = 0;
    Integer totalPages = 1;

    while (pageNumber < totalPages) {
      HttpResponse response = sendGetRequest(pageNumber);
      if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        throw new BWM_EmailException(buildHttpErrorMessage(response));
      }

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
      List<Object> results = (List<Object>) payload.get('results');
      if (results != null) {
        for (Object row : results) {
          allTemplates.add(parseTemplateRow((Map<String, Object>) row));
        }
      }

      Map<String, Object> paging = (Map<String, Object>) payload.get('paging');
      if (paging != null && paging.containsKey('totalPages')) {
        totalPages = Integer.valueOf(String.valueOf(paging.get('totalPages')));
      } else {
        totalPages = pageNumber + 1;
      }
      pageNumber++;
    }

    allTemplates.sort(new TemplateOptionNameComparator());
    return allTemplates;
  }

  /**
   * @description Returns distinct Infobip template subjects for campaign email picklists.
   * @return Subject options sorted by label.
   */
  public static List<SubjectOption> fetchCampaignEmailSubjectOptions() {
    List<SubjectOption> options = new List<SubjectOption>();
    Map<String, SubjectOption> optionsByKey = new Map<String, SubjectOption>();

    for (TemplateOption template : fetchTemplates()) {
      if (template == null || String.isBlank(template.value)) {
        continue;
      }

      TemplateMetadata metadata = fetchTemplateMetadata(template.value);
      String subject = metadata == null ? null : metadata.resolveSubjectForLog();
      if (String.isBlank(subject)) {
        continue;
      }

      String normalizedSubject = subject.trim();
      String dedupeKey = normalizedSubject.toLowerCase();
      if (optionsByKey.containsKey(dedupeKey)) {
        continue;
      }

      SubjectOption option = new SubjectOption();
      option.label = normalizedSubject;
      option.value = normalizedSubject;
      optionsByKey.put(dedupeKey, option);
    }

    options.addAll(optionsByKey.values());
    options.sort(new SubjectOptionLabelComparator());
    return options;
  }

  /**
   * @description Resolves Infobip template ids that use the given email subject line.
   * @param subject Campaign email subject line.
   * @return Matching Infobip template ids.
   */
  public static Set<String> resolveTemplateIdsForSubject(String subject) {
    Set<String> templateIds = new Set<String>();
    if (String.isBlank(subject)) {
      return templateIds;
    }

    String normalizedSubject = subject.trim();
    for (TemplateOption template : fetchTemplates()) {
      if (template == null || String.isBlank(template.value)) {
        continue;
      }

      TemplateMetadata metadata = fetchTemplateMetadata(template.value);
      String templateSubject = metadata == null ? null : metadata.resolveSubjectForLog();
      if (normalizedSubject == templateSubject) {
        templateIds.add(template.value);
      }
    }

    return templateIds;
  }

  /**
   * @description Fetches the Infobip template subject for campaign email logging.
   * @param templateId Infobip email template identifier.
   * @return Template subject when available; otherwise null.
   */
  public static String fetchTemplateSubject(String templateId) {
    TemplateMetadata metadata = fetchTemplateMetadata(templateId);
    return metadata == null ? null : metadata.resolveSubjectForLog();
  }

  /**
   * @description Fetches Infobip template subject and name for campaign email logging.
   * @param templateId Infobip email template identifier.
   * @return Template metadata when available; otherwise null.
   */
  public static TemplateMetadata fetchTemplateMetadata(String templateId) {
    if (String.isBlank(templateId)) {
      return null;
    }

    TemplateMetadata metadata = parseTemplateMetadataFromDetail(templateId.trim());
    if (metadata != null && String.isNotBlank(metadata.subject)) {
      return metadata;
    }

    TemplateMetadata listMetadata = findTemplateMetadataInList(templateId.trim());
    if (listMetadata == null) {
      return metadata;
    }
    if (metadata == null) {
      return listMetadata;
    }
    if (String.isBlank(metadata.name)) {
      metadata.name = listMetadata.name;
    }
    if (String.isBlank(metadata.subject)) {
      metadata.subject = listMetadata.subject;
    }
    return metadata;
  }

  @TestVisible
  private static TemplateMetadata parseTemplateMetadataFromDetail(String templateId) {
    HttpResponse response = sendGetRequestForTemplate(templateId);
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      return null;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    TemplateMetadata metadata = new TemplateMetadata();
    metadata.subject = normalizeTemplateText((String) payload.get('subject'));
    metadata.name = normalizeTemplateText((String) payload.get('name'));
    metadata.fromAddress = trimAddress((String) payload.get('from'));
    metadata.replyTo = trimAddress((String) payload.get('replyTo'));
    return metadata;
  }

  @TestVisible
  private static TemplateMetadata findTemplateMetadataInList(String templateId) {
    Integer pageNumber = 0;
    Integer totalPages = 1;

    while (pageNumber < totalPages) {
      HttpResponse response = sendGetRequest(pageNumber);
      if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        return null;
      }

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
      List<Object> results = (List<Object>) payload.get('results');
      if (results != null) {
        for (Object row : results) {
          Map<String, Object> templateRow = (Map<String, Object>) row;
          Object idValue = templateRow.get('id');
          if (idValue != null && templateId == String.valueOf(idValue)) {
            TemplateMetadata metadata = new TemplateMetadata();
            metadata.name = normalizeTemplateText((String) templateRow.get('name'));
            return metadata;
          }
        }
      }

      Map<String, Object> paging = (Map<String, Object>) payload.get('paging');
      if (paging != null && paging.containsKey('totalPages')) {
        totalPages = Integer.valueOf(String.valueOf(paging.get('totalPages')));
      } else {
        totalPages = pageNumber + 1;
      }
      pageNumber++;
    }

    return null;
  }

  private static String normalizeTemplateText(String rawValue) {
    return sanitizeSubjectForLog(rawValue);
  }

  private static String trimAddress(String rawValue) {
    return String.isBlank(rawValue) ? null : rawValue.trim();
  }

  @TestVisible
  private static String sanitizeSubjectForLog(String rawValue) {
    if (String.isBlank(rawValue)) {
      return null;
    }

    String normalized = rawValue.trim();
    if (normalized.equalsIgnoreCase('no subject') ||
      normalized.equalsIgnoreCase('(no subject)')) {
      return null;
    }

    return normalized;
  }

  private static TemplateOption parseTemplateRow(Map<String, Object> templateRow) {
    TemplateOption option = new TemplateOption();
    Object idValue = templateRow.get('id');
    option.value = idValue == null ? null : String.valueOf(idValue);
    option.label = (String) templateRow.get('name');
    option.createdAt = (String) templateRow.get('createdAt');
    option.updatedAt = (String) templateRow.get('updatedAt');
    option.imagePreviewUrl = (String) templateRow.get('imagePreviewUrl');
    return option;
  }

  private static HttpResponse sendGetRequest(Integer pageNumber) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null) {
      throw new BWM_EmailException('BWM email settings are not configured.');
    }

    String path = TEMPLATES_PATH;
    if (pageNumber > 0) {
      path += '?page=' + pageNumber + '&size=' + PAGE_SIZE;
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint(BWM_EmailConstants.NAMED_CREDENTIAL + path);
    request.setMethod('GET');
    request.setHeader('Accept', 'application/json');

    String headerName = String.isBlank(settings.API_Key_Header__c)
      ? 'Authorization'
      : settings.API_Key_Header__c;
    if (String.isNotBlank(settings.API_App_Key__c)) {
      request.setHeader(headerName, 'App ' + settings.API_App_Key__c);
    }

    request.setTimeout(120000);
    return new Http().send(request);
  }

  private static HttpResponse sendGetRequestForTemplate(String templateId) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null) {
      throw new BWM_EmailException('BWM email settings are not configured.');
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint(
      BWM_EmailConstants.NAMED_CREDENTIAL + TEMPLATES_PATH + '/' + templateId
    );
    request.setMethod('GET');
    request.setHeader('Accept', 'application/json');

    String headerName = String.isBlank(settings.API_Key_Header__c)
      ? 'Authorization'
      : settings.API_Key_Header__c;
    if (String.isNotBlank(settings.API_App_Key__c)) {
      request.setHeader(headerName, 'App ' + settings.API_App_Key__c);
    }

    request.setTimeout(120000);
    return new Http().send(request);
  }

  private static String buildHttpErrorMessage(HttpResponse response) {
    Integer statusCode = response.getStatusCode();
    String body = response.getBody();

    if (statusCode == 401 || statusCode == 403) {
      return 'Bluewave email API authentication failed. Verify the API key in BWM Email Settings.';
    }
    if (statusCode == 500) {
      return 'Bluewave (Infobip) returned a server error while loading email templates. Please try again. If this continues, contact Bluewave support.';
    }

    if (String.isNotBlank(body)) {
      try {
        Map<String, Object> errorPayload = (Map<String, Object>) JSON.deserializeUntyped(
          body
        );
        Object description = errorPayload.get('description');
        if (description != null && String.isNotBlank(String.valueOf(description))) {
          return 'Failed to fetch Bluewave email templates: ' + String.valueOf(description);
        }
      } catch (Exception ex) {
        // Fall through to generic message.
      }
    }

    return 'Failed to fetch Bluewave email templates: HTTP ' + statusCode + '.';
  }

  private class TemplateOptionNameComparator implements Comparator<TemplateOption> {
    public Integer compare(TemplateOption first, TemplateOption second) {
      String firstName = first == null || first.label == null
        ? ''
        : first.label.toLowerCase();
      String secondName = second == null || second.label == null
        ? ''
        : second.label.toLowerCase();
      return firstName.compareTo(secondName);
    }
  }

  private class SubjectOptionLabelComparator implements Comparator<SubjectOption> {
    public Integer compare(SubjectOption first, SubjectOption second) {
      String firstLabel = first == null || first.label == null
        ? ''
        : first.label.toLowerCase();
      String secondLabel = second == null || second.label == null
        ? ''
        : second.label.toLowerCase();
      return firstLabel.compareTo(secondLabel);
    }
  }
}