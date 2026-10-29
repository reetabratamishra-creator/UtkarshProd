public without sharing class BWM_MessageLogService {
  public static Message_Log__c buildLog(
    Lead leadRecord,
    String triggerPoint,
    String channel,
    String templateName,
    String phoneNumber,
    String status,
    BWM_ApiResponse apiResponse
  ) {
    return buildLogForRecord(
      leadRecord,
      triggerPoint,
      channel,
      templateName,
      phoneNumber,
      status,
      apiResponse,
      null
    );
  }

  public static Message_Log__c buildLogForRecord(
    SObject record,
    String triggerPoint,
    String channel,
    String templateName,
    String phoneNumber,
    String status,
    BWM_ApiResponse apiResponse
  ) {
    return buildLogForRecord(
      record,
      triggerPoint,
      channel,
      templateName,
      phoneNumber,
      status,
      apiResponse,
      null
    );
  }

  public static Message_Log__c buildLogForRecord(
    SObject record,
    String triggerPoint,
    String channel,
    String templateName,
    String phoneNumber,
    String status,
    BWM_ApiResponse apiResponse,
    String requestCurl
  ) {
    return buildLogForRecord(
      record,
      triggerPoint,
      channel,
      templateName,
      phoneNumber,
      status,
      apiResponse,
      requestCurl,
      null
    );
  }

  public static Message_Log__c buildLogForRecord(
    SObject record,
    String triggerPoint,
    String channel,
    String templateName,
    String phoneNumber,
    String status,
    BWM_ApiResponse apiResponse,
    String requestCurl,
    String requestPayload
  ) {
    Message_Log__c logRecord = new Message_Log__c();
    logRecord.Related_Record_Id__c = record.Id;
    logRecord.Trigger_Point__c = triggerPoint;
    logRecord.Channel__c = channel;
    logRecord.Template_Name__c = templateName;
    logRecord.Phone_Number__c = phoneNumber;
    logRecord.Status__c = status;
    logRecord.Request_Curl__c = requestCurl;
    logRecord.Request_Payload__c = requestPayload;

    if (record instanceof Lead) {
      logRecord.Lead__c = record.Id;
    } else if (record instanceof Opportunity) {
      logRecord.Opportunity__c = record.Id;
    }

    if (apiResponse != null) {
      applyApiResponse(logRecord, apiResponse);
    }

    return logRecord;
  }

  private static void applyApiResponse(
    Message_Log__c logRecord,
    BWM_ApiResponse apiResponse
  ) {
    logRecord.Response_Code__c = apiResponse.code;
    logRecord.Response_Message__c = apiResponse.message;
    logRecord.Response_Payload__c = apiResponse.rawBody;
    logRecord.Response_Http_Status__c = apiResponse.httpStatus == null
      ? null
      : String.valueOf(apiResponse.httpStatus);
  }

  public static void insertLogs(List<Message_Log__c> logs) {
    if (!logs.isEmpty()) {
      insert logs;
    }
  }

  public static Boolean hasRecentLog(
    Id opportunityId,
    String triggerPoint,
    Integer withinDays
  ) {
    if (opportunityId == null || String.isBlank(triggerPoint)) {
      return false;
    }

    DateTime cutoff = System.now().addDays(-withinDays);
    Integer existingCount = [
      SELECT COUNT()
      FROM Message_Log__c
      WHERE
        Opportunity__c = :opportunityId
        AND Trigger_Point__c = :triggerPoint
        AND Status__c = :BWM_MessagingConstants.LOG_STATUS_SENT
        AND CreatedDate >= :cutoff
    ];

    return existingCount > 0;
  }
}