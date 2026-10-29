/**
 * @description   Fetches and parses Infobip email campaign log/report data.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class CampaignEmailReportService {
  public static final String EMAIL_REPORTS_PATH = '/email/4/reports';
  public static final String EMAIL_LOGS_PATH = '/email/4/logs';
  public static final String EMAIL_REPORTS_MERGED_PATH = '/email/4/reports+/email/4/logs';
  public static final String INTEGRATION_NAME_EMAIL_REPORT = 'Email Campaign Report';
  public static final String REPORT_TYPE_EMAIL = 'Email';
  public static final String PRODUCT_NAME_EMAIL = 'Email';
  private static final Integer DEFAULT_LIMIT = 1000;
  private static final Integer LOOKBACK_HOURS = 48;
  private static final String CAMPAIGN_EMAIL_TRIGGER_SUFFIX = 'Campaign_Manual';

  public class SubjectOption {
    @AuraEnabled public String label;
    @AuraEnabled public String value;
  }

  private class CampaignSendMatchIndex {
    public Set<String> messageIds = new Set<String>();
    public Set<String> bulkIds = new Set<String>();

    public Boolean isEmpty() {
      return messageIds.isEmpty() && bulkIds.isEmpty();
    }
  }

  private class CalloutResult {
    public String endpointPath;
    public HttpResponse response;

    public CalloutResult(String endpointPath, HttpResponse response) {
      this.endpointPath = endpointPath;
      this.response = response;
    }
  }

  public class EmailReportRow {
    @AuraEnabled public String bulkId;
    @AuraEnabled public String messageId;
    @AuraEnabled public String recipient;
    @AuraEnabled public String sender;
    @AuraEnabled public Datetime sentAt;
    @AuraEnabled public Datetime doneAt;
    @AuraEnabled public Integer messageCount;
    @AuraEnabled public String status;
    @AuraEnabled public String statusDescription;
    @AuraEnabled public String campaignReferenceId;
    @AuraEnabled public Integer attemptCount;
    @AuraEnabled public Decimal pricePerMessage;
    @AuraEnabled public String priceCurrency;
    @AuraEnabled public String errorName;
    @AuraEnabled public String errorDescription;
    @AuraEnabled public Integer timeToFirstAttempt;
  }

  public class EmailSummaryRow {
    @AuraEnabled public Integer indexNo;
    @AuraEnabled public String recipient;
    @AuraEnabled public Integer delivered;
    @AuraEnabled public Integer failed;
    @AuraEnabled public Integer pending;
    @AuraEnabled public Integer opened;
    @AuraEnabled public Integer total;
  }

  public class FetchResult {
    @AuraEnabled public String rawResponse;
    @AuraEnabled public List<EmailReportRow> rows;
    @AuraEnabled public List<EmailSummaryRow> summaryRows;
    @AuraEnabled public List<Id> reportIds;
    @AuraEnabled public Id integrationLogId;
  }

  public static FetchResult fetchAndSave() {
    return fetchAndSave(null);
  }

  public static FetchResult fetchAndSave(String campaignEmailSubject) {
    Integer statusCode;
    String responseBody;
    String endpointPath = EMAIL_REPORTS_MERGED_PATH;
    try {
      CalloutResult calloutResult = fetchEmailDeliveryData();
      endpointPath = calloutResult.endpointPath;
      statusCode = calloutResult.response.getStatusCode();
      responseBody = calloutResult.response.getBody();
    } catch (Exception calloutEx) {
      insertIntegrationLog(
        null,
        null,
        EMAIL_REPORTS_PATH,
        null,
        null,
        'Failed',
        calloutEx.getMessage()
      );
      throw new AuraHandledException(
        'Email campaign report callout failed: ' + calloutEx.getMessage()
      );
    }

    Boolean isSuccess = statusCode >= 200 && statusCode < 300;
    Id logId = insertIntegrationLog(
      null,
      null,
      endpointPath,
      responseBody,
      statusCode,
      isSuccess ? 'Success' : 'Failed',
      isSuccess ? null : extractErrorMessage(responseBody)
    );

    if (!isSuccess) {
      throw new AuraHandledException(
        'Email campaign report API failed (' +
          String.valueOf(statusCode) +
          '): ' +
          extractErrorMessage(responseBody)
      );
    }

    FetchResult result = persistResponse(responseBody, campaignEmailSubject);
    result.integrationLogId = logId;
    return result;
  }

  /**
   * @description Returns campaign email subject options for the report filter dropdown.
   * @return Distinct subject options from Infobip templates and sent Email Logs.
   */
  public static List<SubjectOption> getCampaignEmailSubjectOptions() {
    Map<String, SubjectOption> optionsByKey = new Map<String, SubjectOption>();

    try {
      for (BWM_InfobipEmailTemplateService.SubjectOption templateOption :
        BWM_InfobipEmailTemplateService.fetchCampaignEmailSubjectOptions()) {
        addSubjectOption(optionsByKey, templateOption == null ? null : templateOption.value);
      }
    } catch (Exception ex) {
      // Fall back to Email Log subjects when Infobip is unavailable.
    }

    addSubjectOptionsFromEmailLogs(optionsByKey);
    List<SubjectOption> options = new List<SubjectOption>(optionsByKey.values());
    options.sort(new SubjectOptionLabelComparator());
    return options;
  }

  /**
   * @description Returns campaign email subject options from Email Log records only.
   * @return Distinct subject options without external callouts.
   */
  public static List<SubjectOption> getCampaignEmailSubjectOptionsFromLogs() {
    Map<String, SubjectOption> optionsByKey = new Map<String, SubjectOption>();
    addSubjectOptionsFromEmailLogs(optionsByKey);
    List<SubjectOption> options = new List<SubjectOption>(optionsByKey.values());
    options.sort(new SubjectOptionLabelComparator());
    return options;
  }

  @TestVisible
  static CalloutResult fetchEmailDeliveryData() {
    HttpResponse reportsResponse = sendGetRequest(EMAIL_REPORTS_PATH);
    HttpResponse logsResponse = sendGetRequest(
      EMAIL_LOGS_PATH,
      buildSentSinceParam(LOOKBACK_HOURS)
    );

    Integer reportsStatus = reportsResponse.getStatusCode();
    Integer logsStatus = logsResponse.getStatusCode();
    if (
      (reportsStatus < 200 || reportsStatus >= 300) &&
      (logsStatus < 200 || logsStatus >= 300)
    ) {
      return new CalloutResult(EMAIL_REPORTS_PATH, reportsResponse);
    }

    String mergedBody = mergeResponseBodies(
      reportsStatus >= 200 && reportsStatus < 300 ? reportsResponse.getBody() : null,
      logsStatus >= 200 && logsStatus < 300 ? logsResponse.getBody() : null
    );

    HttpResponse mergedResponse = new HttpResponse();
    mergedResponse.setStatusCode(200);
    mergedResponse.setHeader('Content-Type', 'application/json');
    mergedResponse.setBody(mergedBody);
    return new CalloutResult(EMAIL_REPORTS_MERGED_PATH, mergedResponse);
  }

  @TestVisible
  static HttpResponse sendEmailReportsRequest() {
    return fetchEmailDeliveryData().response;
  }

  @TestVisible
  static HttpResponse sendGetRequest(String path) {
    return sendGetRequest(path, null);
  }

  @TestVisible
  static HttpResponse sendGetRequest(String path, String sentSince) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null) {
      throw new AuraHandledException('BWM email settings are not configured.');
    }

    String queryString = 'limit=' + String.valueOf(DEFAULT_LIMIT);
    if (String.isNotBlank(sentSince)) {
      queryString += '&sentSince=' + EncodingUtil.urlEncode(sentSince, 'UTF-8');
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint(
      BWM_EmailConstants.NAMED_CREDENTIAL + path + '?' + queryString
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

  @TestVisible
  static Boolean hasResultRows(String responseBody) {
    Map<String, Object> payload = parseObjectMap(responseBody);
    if (payload == null) {
      return false;
    }
    List<Object> results = payload.get('results') instanceof List<Object>
      ? (List<Object>) payload.get('results')
      : new List<Object>();
    return !results.isEmpty();
  }

  @TestVisible
  static String buildSentSinceParam(Integer lookbackHours) {
    Datetime sentSince = System.now().addHours(-1 * lookbackHours);
    return sentSince.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
  }

  @TestVisible
  static String mergeResponseBodies(String reportsBody, String logsBody) {
    Map<String, Map<String, Object>> mergedRows = new Map<String, Map<String, Object>>();

    addRowsToMergeMap(mergedRows, extractResultMaps(logsBody), true);
    addRowsToMergeMap(mergedRows, extractResultMaps(reportsBody), false);

    List<Map<String, Object>> sortedRows = new List<Map<String, Object>>(mergedRows.values());
    sortedRows.sort(new EmailReportRowMapComparator());

    Map<String, Object> payload = new Map<String, Object>{ 'results' => sortedRows };
    return JSON.serialize(payload);
  }

  @TestVisible
  static List<Map<String, Object>> extractResultMaps(String responseBody) {
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    Map<String, Object> payload = parseObjectMap(responseBody);
    if (payload == null) {
      return rows;
    }

    List<Object> results = payload.get('results') instanceof List<Object>
      ? (List<Object>) payload.get('results')
      : new List<Object>();
    for (Object rowObj : results) {
      if (rowObj instanceof Map<String, Object>) {
        rows.add((Map<String, Object>) rowObj);
      }
    }
    return rows;
  }

  private static void addRowsToMergeMap(
    Map<String, Map<String, Object>> mergedRows,
    List<Map<String, Object>> rows,
    Boolean preferExisting
  ) {
    for (Map<String, Object> rowMap : rows) {
      String mergeKey = buildMergeKey(rowMap);
      if (String.isBlank(mergeKey)) {
        mergeKey = 'row-' + String.valueOf(mergedRows.size());
      }
      if (!mergedRows.containsKey(mergeKey) || !preferExisting) {
        mergedRows.put(mergeKey, rowMap);
      }
    }
  }

  private static String buildMergeKey(Map<String, Object> rowMap) {
    String messageId = asString(rowMap.get('messageId'));
    if (String.isNotBlank(messageId)) {
      return messageId;
    }
    String bulkId = asString(rowMap.get('bulkId'));
    String recipient = asString(rowMap.get('to'));
    if (String.isBlank(recipient)) {
      recipient = asString(rowMap.get('destination'));
    }
    return String.join(
      new List<String>{ bulkId, recipient, asString(rowMap.get('sentAt')) },
      '|'
    );
  }

  private class EmailReportRowMapComparator implements Comparator<Map<String, Object>> {
    public Integer compare(Map<String, Object> left, Map<String, Object> right) {
      Datetime leftSentAt = parseDateTime(asString(left.get('sentAt')));
      Datetime rightSentAt = parseDateTime(asString(right.get('sentAt')));
      if (leftSentAt == null && rightSentAt == null) {
        return 0;
      }
      if (leftSentAt == null) {
        return 1;
      }
      if (rightSentAt == null) {
        return -1;
      }
      if (leftSentAt == rightSentAt) {
        return 0;
      }
      return leftSentAt > rightSentAt ? -1 : 1;
    }
  }

  @TestVisible
  static FetchResult persistResponse(String responseBody) {
    return persistResponse(responseBody, null);
  }

  @TestVisible
  static FetchResult persistResponse(String responseBody, String campaignEmailSubject) {
    Map<String, Object> payload = parseObjectMap(responseBody);
    if (payload == null) {
      throw new AuraHandledException('Email report API returned invalid JSON.');
    }

    FetchResult result = new FetchResult();
    result.rawResponse = responseBody;
    result.rows = new List<EmailReportRow>();
    result.summaryRows = new List<EmailSummaryRow>();
    result.reportIds = new List<Id>();

    List<Object> results = payload.get('results') instanceof List<Object>
      ? (List<Object>) payload.get('results')
      : new List<Object>();

    Datetime fetchedAt = System.now();
    List<Campaign_Report__c> reports = new List<Campaign_Report__c>();
    List<EmailReportRow> parsedRows = new List<EmailReportRow>();

    if (results.isEmpty()) {
      reports.add(buildEmailReport(null, fetchedAt, responseBody));
    } else {
      for (Object rowObj : results) {
        if (!(rowObj instanceof Map<String, Object>)) {
          continue;
        }
        parsedRows.add(parseEmailReportRow((Map<String, Object>) rowObj));
      }
    }

    result.rows = filterRowsByCampaignSubject(parsedRows, campaignEmailSubject);

    if (result.rows.isEmpty() && parsedRows.isEmpty()) {
      // Keep existing empty-response behavior.
    } else {
      for (EmailReportRow row : result.rows) {
        reports.add(buildEmailReport(row, fetchedAt, responseBody));
      }
    }

    List<EmailSummaryRow> summaryRows = buildSummaryRows(result.rows);
    result.summaryRows.addAll(summaryRows);
    for (EmailSummaryRow summary : summaryRows) {
      reports.add(buildEmailSummaryReport(summary, fetchedAt, responseBody));
    }

    if (!reports.isEmpty()) {
      insert reports;
      for (Campaign_Report__c report : reports) {
        result.reportIds.add(report.Id);
      }
    }

    return result;
  }

  @TestVisible
  static List<EmailSummaryRow> buildSummaryRows(List<EmailReportRow> rows) {
    List<EmailSummaryRow> summaryRows = new List<EmailSummaryRow>();
    if (rows == null || rows.isEmpty()) {
      return summaryRows;
    }

    Map<String, EmailSummaryRow> byRecipient = new Map<String, EmailSummaryRow>();
    List<String> recipientOrder = new List<String>();

    for (EmailReportRow row : rows) {
      String recipient = row == null || String.isBlank(row.recipient)
        ? '(unknown)'
        : row.recipient.trim();
      EmailSummaryRow summary = byRecipient.get(recipient);
      if (summary == null) {
        summary = new EmailSummaryRow();
        summary.recipient = recipient;
        summary.delivered = 0;
        summary.failed = 0;
        summary.pending = 0;
        summary.opened = 0;
        summary.total = 0;
        byRecipient.put(recipient, summary);
        recipientOrder.add(recipient);
      }

      summary.total++;
      String status = row == null || String.isBlank(row.status)
        ? ''
        : row.status.trim().toUpperCase();
      String errorName = row == null || String.isBlank(row.errorName)
        ? ''
        : row.errorName.trim().toUpperCase();

      if (isOpenedStatus(status)) {
        summary.opened++;
        summary.delivered++;
      } else if (isDeliveredStatus(status)) {
        summary.delivered++;
      } else if (isFailedStatus(status, errorName)) {
        summary.failed++;
      } else {
        summary.pending++;
      }
    }

    Integer indexNo = 1;
    for (String recipient : recipientOrder) {
      EmailSummaryRow summary = byRecipient.get(recipient);
      summary.indexNo = indexNo;
      summaryRows.add(summary);
      indexNo++;
    }

    return summaryRows;
  }

  @TestVisible
  static List<EmailReportRow> filterRowsByCampaignSubject(
    List<EmailReportRow> rows,
    String campaignEmailSubject
  ) {
    if (rows == null) {
      return new List<EmailReportRow>();
    }
    if (String.isBlank(campaignEmailSubject)) {
      return rows;
    }

    CampaignSendMatchIndex matchIndex = buildCampaignSendMatchIndex(
      campaignEmailSubject.trim()
    );
    if (matchIndex.isEmpty()) {
      return new List<EmailReportRow>();
    }

    List<EmailReportRow> filteredRows = new List<EmailReportRow>();
    for (EmailReportRow row : rows) {
      if (matchesCampaignSend(row, matchIndex)) {
        filteredRows.add(row);
      }
    }
    return filteredRows;
  }

  @TestVisible
  static CampaignSendMatchIndex buildCampaignSendMatchIndex(String campaignEmailSubject) {
    CampaignSendMatchIndex matchIndex = new CampaignSendMatchIndex();
    if (String.isBlank(campaignEmailSubject)) {
      return matchIndex;
    }

    String subject = campaignEmailSubject.trim();
    Datetime sentSince = System.now().addHours(-1 * LOOKBACK_HOURS);
    Set<String> templateIds = resolveTemplateIdsForSubject(subject);
    Set<String> safeTemplateIds = filterSafeTemplateIds(subject, templateIds, sentSince);
    Set<String> templateNames = resolveTemplateNamesForIds(safeTemplateIds);

    List<Email_Log__c> campaignLogs;
    if (safeTemplateIds.isEmpty()) {
      campaignLogs = [
        SELECT Response_Payload__c
        FROM Email_Log__c
        WHERE Trigger_Point__c LIKE :('%' + CAMPAIGN_EMAIL_TRIGGER_SUFFIX)
          AND Status__c = 'Sent'
          AND CreatedDate >= :sentSince
          AND (
            Campaign_Email_Subject__c = :subject
            OR Template_Name__c = :subject
          )
      ];
    } else {
      campaignLogs = [
        SELECT Response_Payload__c
        FROM Email_Log__c
        WHERE Trigger_Point__c LIKE :('%' + CAMPAIGN_EMAIL_TRIGGER_SUFFIX)
          AND Status__c = 'Sent'
          AND CreatedDate >= :sentSince
          AND (
            Campaign_Email_Subject__c = :subject
            OR Template_Name__c = :subject
            OR (
              Template_Id__c IN :safeTemplateIds
              AND (
                Campaign_Email_Subject__c = null
                OR Campaign_Email_Subject__c = :subject
              )
              AND (
                Template_Name__c = null
                OR Template_Name__c = :subject
                OR Template_Name__c IN :templateNames
              )
            )
          )
      ];
    }

    for (Email_Log__c logRecord : campaignLogs) {
      addPayloadIds(logRecord.Response_Payload__c, matchIndex);
    }

    return matchIndex;
  }

  @TestVisible
  static Set<String> resolveTemplateIdsForSubject(String campaignEmailSubject) {
    Set<String> templateIds = new Set<String>();
    if (String.isBlank(campaignEmailSubject)) {
      return templateIds;
    }

    String subject = campaignEmailSubject.trim();
    for (Email_Log__c logRecord : [
      SELECT Template_Id__c
      FROM Email_Log__c
      WHERE Trigger_Point__c LIKE :('%' + CAMPAIGN_EMAIL_TRIGGER_SUFFIX)
        AND Template_Id__c != null
        AND (
          Campaign_Email_Subject__c = :subject
          OR Template_Name__c = :subject
        )
    ]) {
      templateIds.add(logRecord.Template_Id__c);
    }

    try {
      templateIds.addAll(
        BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(subject)
      );
    } catch (Exception ex) {
      // Continue with Email Log template ids only.
    }

    return templateIds;
  }

  @TestVisible
  static Set<String> filterSafeTemplateIds(
    String campaignEmailSubject,
    Set<String> templateIds,
    Datetime sentSince
  ) {
    Set<String> safeTemplateIds = new Set<String>(templateIds);
    if (safeTemplateIds.isEmpty() || String.isBlank(campaignEmailSubject)) {
      return safeTemplateIds;
    }

    String subject = campaignEmailSubject.trim();
    for (AggregateResult aggregateResult : [
      SELECT Template_Id__c templateId
      FROM Email_Log__c
      WHERE Trigger_Point__c LIKE :('%' + CAMPAIGN_EMAIL_TRIGGER_SUFFIX)
        AND Status__c = 'Sent'
        AND CreatedDate >= :sentSince
        AND Template_Id__c IN :safeTemplateIds
        AND Campaign_Email_Subject__c != null
        AND Campaign_Email_Subject__c != :subject
      GROUP BY Template_Id__c
    ]) {
      safeTemplateIds.remove((String) aggregateResult.get('templateId'));
    }

    return safeTemplateIds;
  }

  private static Set<String> resolveTemplateNamesForIds(Set<String> templateIds) {
    Set<String> templateNames = new Set<String>();
    if (templateIds == null || templateIds.isEmpty()) {
      return templateNames;
    }

    try {
      for (BWM_InfobipEmailTemplateService.TemplateOption templateOption :
        BWM_InfobipEmailTemplateService.fetchTemplates()) {
        if (
          templateOption != null &&
          String.isNotBlank(templateOption.value) &&
          templateIds.contains(templateOption.value) &&
          String.isNotBlank(templateOption.label)
        ) {
          templateNames.add(templateOption.label.trim());
        }
      }
    } catch (Exception ex) {
      for (Email_Log__c logRecord : [
        SELECT Template_Name__c
        FROM Email_Log__c
        WHERE Template_Id__c IN :templateIds AND Template_Name__c != null
        LIMIT 200
      ]) {
        templateNames.add(logRecord.Template_Name__c.trim());
      }
    }

    return templateNames;
  }

  @TestVisible
  static void addPayloadIds(String responsePayload, CampaignSendMatchIndex matchIndex) {
    if (matchIndex == null || String.isBlank(responsePayload)) {
      return;
    }

    Map<String, Object> payload = parseObjectMap(responsePayload);
    if (payload == null) {
      return;
    }

    String bulkId = asString(payload.get('bulkId'));
    if (String.isNotBlank(bulkId)) {
      matchIndex.bulkIds.add(bulkId);
    }

    List<Object> messages = payload.get('messages') instanceof List<Object>
      ? (List<Object>) payload.get('messages')
      : new List<Object>();
    for (Object messageObj : messages) {
      if (!(messageObj instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> messageMap = (Map<String, Object>) messageObj;
      String messageId = asString(messageMap.get('messageId'));
      if (String.isNotBlank(messageId)) {
        matchIndex.messageIds.add(messageId);
      }
    }
  }

  private static Boolean matchesCampaignSend(
    EmailReportRow row,
    CampaignSendMatchIndex matchIndex
  ) {
    if (row == null || matchIndex == null) {
      return false;
    }
    if (
      String.isNotBlank(row.messageId) &&
      matchIndex.messageIds.contains(row.messageId)
    ) {
      return true;
    }
    return String.isNotBlank(row.bulkId) &&
      matchIndex.bulkIds.contains(row.bulkId);
  }

  private static void addSubjectOptionsFromEmailLogs(
    Map<String, SubjectOption> optionsByKey
  ) {
    for (Email_Log__c logRecord : [
      SELECT Campaign_Email_Subject__c, Template_Name__c
      FROM Email_Log__c
      WHERE Trigger_Point__c LIKE :('%' + CAMPAIGN_EMAIL_TRIGGER_SUFFIX)
        AND (Campaign_Email_Subject__c != null OR Template_Name__c != null)
      ORDER BY CreatedDate DESC
      LIMIT 1000
    ]) {
      addSubjectOption(optionsByKey, logRecord.Campaign_Email_Subject__c);
      if (String.isBlank(logRecord.Campaign_Email_Subject__c)) {
        addSubjectOption(optionsByKey, logRecord.Template_Name__c);
      }
    }
  }

  private static void addSubjectOption(
    Map<String, SubjectOption> optionsByKey,
    String subject
  ) {
    if (optionsByKey == null || String.isBlank(subject)) {
      return;
    }

    String normalizedSubject = subject.trim();
    String dedupeKey = normalizedSubject.toLowerCase();
    if (optionsByKey.containsKey(dedupeKey)) {
      return;
    }

    SubjectOption option = new SubjectOption();
    option.label = normalizedSubject;
    option.value = normalizedSubject;
    optionsByKey.put(dedupeKey, option);
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

  @TestVisible
  static EmailSummaryRow buildSummary(List<EmailReportRow> rows) {
    EmailSummaryRow summary = new EmailSummaryRow();
    summary.indexNo = 1;
    summary.recipient = null;
    summary.delivered = 0;
    summary.failed = 0;
    summary.pending = 0;
    summary.opened = 0;
    summary.total = 0;

    for (EmailSummaryRow rowSummary : buildSummaryRows(rows)) {
      summary.delivered += rowSummary.delivered;
      summary.failed += rowSummary.failed;
      summary.pending += rowSummary.pending;
      summary.opened += rowSummary.opened;
      summary.total += rowSummary.total;
    }

    return summary;
  }

  private static Boolean isOpenedStatus(String status) {
    return status.contains('OPEN') ||
      status.contains('SEEN') ||
      status.contains('CLICK') ||
      status == 'READ';
  }

  private static Boolean isDeliveredStatus(String status) {
    return status.contains('DELIVERED');
  }

  private static Boolean isFailedStatus(String status, String errorName) {
    if (
      String.isNotBlank(errorName) &&
      errorName != 'NO_ERROR' &&
      errorName != 'OK'
    ) {
      return true;
    }
    return status.contains('FAILED') ||
      status.contains('REJECT') ||
      status.contains('UNDELIVER') ||
      status.contains('BOUNCE') ||
      status.contains('EXPIRED');
  }

  private static Campaign_Report__c buildEmailSummaryReport(
    EmailSummaryRow summary,
    Datetime fetchedAt,
    String responseBody
  ) {
    Campaign_Report__c report = new Campaign_Report__c();
    report.Report_Type__c = REPORT_TYPE_EMAIL;
    report.Product_Name__c = PRODUCT_NAME_EMAIL;
    report.Fetched_At__c = fetchedAt;
    report.Raw_Response__c = responseBody;
    report.Index_No__c = summary.indexNo;
    report.Delivered__c = summary.delivered;
    report.Failed__c = summary.failed;
    report.Read__c = summary.opened;
    report.Email_Recipient__c = summary.recipient;
    report.Email_Status__c = 'CONSOLIDATED';
    report.Email_Status_Description__c =
      'Pending=' +
      String.valueOf(summary.pending) +
      '; Total=' +
      String.valueOf(summary.total);
    return report;
  }

  @TestVisible
  static EmailReportRow parseEmailReportRow(Map<String, Object> rowMap) {
    EmailReportRow row = new EmailReportRow();
    row.bulkId = asString(rowMap.get('bulkId'));
    row.messageId = asString(rowMap.get('messageId'));
    row.recipient = asString(rowMap.get('to'));
    if (String.isBlank(row.recipient)) {
      row.recipient = asString(rowMap.get('destination'));
    }
    row.sender = asString(rowMap.get('sender'));
    row.sentAt = parseDateTime(asString(rowMap.get('sentAt')));
    row.doneAt = parseDateTime(asString(rowMap.get('doneAt')));
    row.messageCount = asInteger(rowMap.get('messageCount'));
    row.campaignReferenceId = asString(rowMap.get('campaignReferenceId'));
    row.attemptCount = asInteger(rowMap.get('attemptCount'));
    row.timeToFirstAttempt = asInteger(rowMap.get('timeToFirstAttempt'));

    if (rowMap.get('status') instanceof Map<String, Object>) {
      Map<String, Object> statusMap = (Map<String, Object>) rowMap.get('status');
      row.status = asString(statusMap.get('name'));
      row.statusDescription = asString(statusMap.get('description'));
    }

    if (rowMap.get('price') instanceof Map<String, Object>) {
      Map<String, Object> priceMap = (Map<String, Object>) rowMap.get('price');
      row.pricePerMessage = asDecimal(priceMap.get('pricePerMessage'));
      row.priceCurrency = asString(priceMap.get('currency'));
    }

    if (rowMap.get('error') instanceof Map<String, Object>) {
      Map<String, Object> errorMap = (Map<String, Object>) rowMap.get('error');
      row.errorName = asString(errorMap.get('name'));
      row.errorDescription = asString(errorMap.get('description'));
    }

    return row;
  }

  private static Campaign_Report__c buildEmailReport(
    EmailReportRow row,
    Datetime fetchedAt,
    String responseBody
  ) {
    Campaign_Report__c report = new Campaign_Report__c();
    report.Report_Type__c = REPORT_TYPE_EMAIL;
    report.Product_Name__c = PRODUCT_NAME_EMAIL;
    report.Fetched_At__c = fetchedAt;
    report.Raw_Response__c = responseBody;

    if (row != null) {
      report.Email_Bulk_Id__c = row.bulkId;
      report.Email_Message_Id__c = row.messageId;
      report.Email_Recipient__c = row.recipient;
      report.Email_Sender__c = row.sender;
      report.Email_Sent_At__c = row.sentAt;
      report.Email_Done_At__c = row.doneAt;
      report.Email_Message_Count__c = row.messageCount;
      report.Email_Status__c = row.status;
      report.Email_Status_Description__c = row.statusDescription;
      report.Email_Campaign_Reference_Id__c = row.campaignReferenceId;
      report.Email_Attempt_Count__c = row.attemptCount;
      report.Email_Price_Per_Message__c = row.pricePerMessage;
      report.Email_Price_Currency__c = row.priceCurrency;
      report.Email_Error_Name__c = row.errorName;
      report.Email_Error_Description__c = row.errorDescription;
      report.Email_Time_To_First_Attempt__c = row.timeToFirstAttempt;
    }

    return report;
  }

  @TestVisible
  static Id insertIntegrationLog(
    Id campaignId,
    String campaignName,
    String endpointPath,
    String responseBody,
    Integer statusCode,
    String status,
    String errorMessage
  ) {
    Integration_Log__c logRecord = new Integration_Log__c();
    logRecord.Campaign__c = campaignId;
    logRecord.Campaign_Name__c = campaignName;
    logRecord.Product_Name__c = PRODUCT_NAME_EMAIL;
    logRecord.Integration_Name__c = INTEGRATION_NAME_EMAIL_REPORT;
    logRecord.Endpoint__c = String.isBlank(endpointPath)
      ? EMAIL_REPORTS_PATH
      : endpointPath;
    logRecord.Http_Method__c = 'GET';
    logRecord.Response_Payload__c = responseBody;
    logRecord.Response_Http_Status__c = statusCode;
    logRecord.Status__c = status;
    logRecord.Error_Message__c = errorMessage;
    logRecord.Called_At__c = System.now();
    insert logRecord;
    return logRecord.Id;
  }

  private static Map<String, Object> parseObjectMap(String jsonBody) {
    if (String.isBlank(jsonBody)) {
      return null;
    }
    try {
      Object parsed = JSON.deserializeUntyped(jsonBody);
      return parsed instanceof Map<String, Object>
        ? (Map<String, Object>) parsed
        : null;
    } catch (Exception ex) {
      return null;
    }
  }

  private static String extractErrorMessage(String responseBody) {
    Map<String, Object> payload = parseObjectMap(responseBody);
    if (payload != null && payload.containsKey('description')) {
      return String.valueOf(payload.get('description'));
    }
    if (payload != null && payload.containsKey('message')) {
      return String.valueOf(payload.get('message'));
    }
    return String.isBlank(responseBody) ? 'Unknown error' : responseBody;
  }

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Decimal asDecimal(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Decimal) {
      return (Decimal) value;
    }
    if (value instanceof Integer) {
      return Decimal.valueOf((Integer) value);
    }
    if (value instanceof Long) {
      return Decimal.valueOf((Long) value);
    }
    if (value instanceof Double) {
      return Decimal.valueOf((Double) value);
    }
    try {
      return Decimal.valueOf(String.valueOf(value));
    } catch (Exception ex) {
      return null;
    }
  }

  private static Integer asInteger(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Integer) {
      return (Integer) value;
    }
    if (value instanceof Long) {
      return Integer.valueOf(String.valueOf(value));
    }
    if (value instanceof Decimal) {
      return ((Decimal) value).intValue();
    }
    try {
      return Integer.valueOf(String.valueOf(value));
    } catch (Exception ex) {
      return null;
    }
  }

  private static Datetime parseDateTime(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
    } catch (Exception ex) {
      return null;
    }
  }
}