public with sharing class CampaignStatsService {
  public static final String CAMPAIGN_STATS_PATH = '/api/v1/journey/campaign-stats';
  public static final String INTEGRATION_NAME_CAMPAIGN_STATS = 'Campaign Stats';

  public class CampaignOption {
    @AuraEnabled public Id id;
    @AuraEnabled public String name;
  }

  public class StatsRow {
    @AuraEnabled public Integer indexNo;
    @AuraEnabled public Integer delivered;
    @AuraEnabled public Integer failed;
    @AuraEnabled public Integer nonRcsNo;
    @AuraEnabled public Integer readCount;
  }

  public class FetchResult {
    @AuraEnabled public String journeyName;
    @AuraEnabled public String journeyCampaignName;
    @AuraEnabled public String productName;
    @AuraEnabled public String rawResponse;
    @AuraEnabled public List<StatsRow> components;
    @AuraEnabled public List<Id> reportIds;
    @AuraEnabled public Id integrationLogId;
  }

  public static List<CampaignOption> getCampaignOptions(List<Id> campaignIds) {
    List<CampaignOption> options = new List<CampaignOption>();
    if (campaignIds == null || campaignIds.isEmpty()) {
      return options;
    }

    for (Campaign campaignRecord : [
      SELECT Id, Name
      FROM Campaign
      WHERE Id IN :campaignIds
      ORDER BY Name
    ]) {
      CampaignOption option = new CampaignOption();
      option.id = campaignRecord.Id;
      option.name = campaignRecord.Name;
      options.add(option);
    }
    return options;
  }

  public static FetchResult fetchAndSave(
    Id campaignId,
    String campaignName,
    String productName
  ) {
    if (campaignId == null) {
      throw new AuraHandledException('Campaign is required.');
    }
    if (String.isBlank(campaignName)) {
      throw new AuraHandledException('Campaign name is required.');
    }
    if (String.isBlank(productName)) {
      throw new AuraHandledException('Product name is required.');
    }

    String normalizedProduct = normalizeProductName(productName);
    String requestBody = JSON.serialize(
      new Map<String, Object>{
        'productName' => normalizedProduct,
        'campaignName' => campaignName.trim()
      }
    );

    Integer statusCode;
    String responseBody;
    try {
      HttpResponse response = sendCampaignStatsRequest(requestBody);
      statusCode = response.getStatusCode();
      responseBody = response.getBody();
    } catch (Exception calloutEx) {
      insertIntegrationLog(
        campaignId,
        campaignName.trim(),
        normalizedProduct,
        requestBody,
        null,
        null,
        'Failed',
        calloutEx.getMessage()
      );
      throw new AuraHandledException(
        'Campaign stats callout failed: ' + calloutEx.getMessage()
      );
    }

    Boolean isSuccess = statusCode >= 200 && statusCode < 300;
    Id logId = insertIntegrationLog(
      campaignId,
      campaignName.trim(),
      normalizedProduct,
      requestBody,
      responseBody,
      statusCode,
      isSuccess ? 'Success' : 'Failed',
      isSuccess ? null : extractErrorMessage(responseBody)
    );

    if (!isSuccess) {
      throw new AuraHandledException(
        'Campaign stats API failed (' +
          String.valueOf(statusCode) +
          '): ' +
          extractErrorMessage(responseBody)
      );
    }

    FetchResult result = persistResponse(campaignId, responseBody);
    result.integrationLogId = logId;
    return result;
  }

  @TestVisible
  static Id insertIntegrationLog(
    Id campaignId,
    String campaignName,
    String productName,
    String requestBody,
    String responseBody,
    Integer statusCode,
    String status,
    String errorMessage
  ) {
    Integration_Log__c logRecord = new Integration_Log__c();
    logRecord.Campaign__c = campaignId;
    logRecord.Campaign_Name__c = campaignName;
    logRecord.Product_Name__c = productName;
    logRecord.Integration_Name__c = INTEGRATION_NAME_CAMPAIGN_STATS;
    logRecord.Endpoint__c = CAMPAIGN_STATS_PATH;
    logRecord.Http_Method__c = 'POST';
    logRecord.Request_Payload__c = requestBody;
    logRecord.Response_Payload__c = responseBody;
    logRecord.Response_Http_Status__c = statusCode;
    logRecord.Status__c = status;
    logRecord.Error_Message__c = errorMessage;
    logRecord.Called_At__c = System.now();
    insert logRecord;
    return logRecord.Id;
  }

  @TestVisible
  static String normalizeProductName(String productName) {
    String value = productName == null ? '' : productName.trim();
    if (value.equalsIgnoreCase('WhatsApp') || value.equalsIgnoreCase('WA')) {
      return 'WhatsApp';
    }
    if (
      value.equalsIgnoreCase('RCS') ||
      value.equalsIgnoreCase('RCSMessage') ||
      value.equalsIgnoreCase('RCSMESSAGE')
    ) {
      return 'RCS';
    }
    throw new AuraHandledException(
      'Invalid product name. Allowed: RCS, WhatsApp.'
    );
  }

  @TestVisible
  static HttpResponse sendCampaignStatsRequest(String requestBody) {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null) {
      throw new AuraHandledException('BWM messaging settings are not configured.');
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint(
      BWM_MessagingConstants.NAMED_CREDENTIAL + CAMPAIGN_STATS_PATH
    );
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('accept', 'application/json');

    if (String.isNotBlank(settings.API_Bearer_Token__c)) {
      request.setHeader(
        String.isNotBlank(settings.API_Key_Header__c)
          ? settings.API_Key_Header__c
          : 'Authorization',
        'Bearer ' + settings.API_Bearer_Token__c
      );
    }

    request.setTimeout(120000);
    request.setBody(requestBody);
    return new Http().send(request);
  }

  @TestVisible
  static FetchResult persistResponse(Id campaignId, String responseBody) {
    Map<String, Object> payload = parseObjectMap(responseBody);
    if (payload == null) {
      throw new AuraHandledException('Campaign stats API returned invalid JSON.');
    }

    if (payload.containsKey('code') && payload.containsKey('message')) {
      throw new AuraHandledException(
        String.valueOf(payload.get('message'))
      );
    }

    FetchResult result = new FetchResult();
    result.journeyName = asString(payload.get('journeyName'));
    result.journeyCampaignName = asString(payload.get('journeyCampaignName'));
    result.productName = asString(payload.get('productName'));
    result.rawResponse = responseBody;
    result.components = new List<StatsRow>();
    result.reportIds = new List<Id>();

    List<Object> components = payload.get('components') instanceof List<Object>
      ? (List<Object>) payload.get('components')
      : new List<Object>();

    Datetime fetchedAt = System.now();
    List<Campaign_Report__c> reports = new List<Campaign_Report__c>();

    if (components.isEmpty()) {
      Campaign_Report__c report = buildReport(
        campaignId,
        result,
        null,
        null,
        fetchedAt,
        responseBody
      );
      reports.add(report);
    } else {
      for (Object componentObj : components) {
        if (!(componentObj instanceof Map<String, Object>)) {
          continue;
        }
        Map<String, Object> component = (Map<String, Object>) componentObj;
        Map<String, Object> statistics = component.get('statistics') instanceof Map<String, Object>
          ? (Map<String, Object>) component.get('statistics')
          : new Map<String, Object>();

        StatsRow row = new StatsRow();
        row.indexNo = asInteger(component.get('indexNo'));
        row.delivered = getStatisticValue(
          statistics,
          new List<String>{ 'DELIVERED', 'deliveredCount', 'delivered' }
        );
        row.failed = getStatisticValue(
          statistics,
          new List<String>{ 'FAILED', 'failedCount', 'failed' }
        );
        row.nonRcsNo = getStatisticValue(
          statistics,
          new List<String>{ 'NON_RCS_NO', 'nonRcsNo', 'non_rcs_no' }
        );
        row.readCount = getStatisticValue(
          statistics,
          new List<String>{ 'READ', 'readCount', 'read' }
        );
        result.components.add(row);

        reports.add(
          buildReport(campaignId, result, row, row.indexNo, fetchedAt, responseBody)
        );
      }
    }

    if (!reports.isEmpty()) {
      insert reports;
      for (Campaign_Report__c report : reports) {
        result.reportIds.add(report.Id);
      }
    }

    return result;
  }

  private static Campaign_Report__c buildReport(
    Id campaignId,
    FetchResult result,
    StatsRow row,
    Integer indexNo,
    Datetime fetchedAt,
    String responseBody
  ) {
    Campaign_Report__c report = new Campaign_Report__c();
    report.Campaign__c = campaignId;
    report.Journey_Name__c = result.journeyName;
    report.Journey_Campaign_Name__c = result.journeyCampaignName;
    report.Product_Name__c = result.productName;
    report.Index_No__c = indexNo;
    report.Fetched_At__c = fetchedAt;
    report.Raw_Response__c = responseBody;
    if (row != null) {
      report.Delivered__c = row.delivered;
      report.Failed__c = row.failed;
      report.Non_RCS_No__c = row.nonRcsNo;
      report.Read__c = row.readCount;
    }
    return report;
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
    if (payload != null && payload.containsKey('message')) {
      return String.valueOf(payload.get('message'));
    }
    return String.isBlank(responseBody) ? 'Unknown error' : responseBody;
  }

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
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

  @TestVisible
  private static Integer getStatisticValue(
    Map<String, Object> statistics,
    List<String> keys
  ) {
    if (statistics == null || statistics.isEmpty() || keys == null || keys.isEmpty()) {
      return null;
    }

    for (String key : keys) {
      if (statistics.containsKey(key)) {
        return asInteger(statistics.get(key));
      }
    }

    Map<String, Object> lowerCaseStatistics = new Map<String, Object>();
    for (String statKey : statistics.keySet()) {
      lowerCaseStatistics.put(statKey.toLowerCase(), statistics.get(statKey));
    }

    for (String key : keys) {
      Object value = lowerCaseStatistics.get(key.toLowerCase());
      if (value != null) {
        return asInteger(value);
      }
    }

    return null;
  }
}