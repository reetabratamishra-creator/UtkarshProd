public without sharing class BWM_EmailLogService {
  public static Email_Log__c buildLog(
    SObject record,
    String triggerPoint,
    BWM_Email_Template_Mapping__mdt mapping,
    String fromEmail,
    String toEmail,
    String status,
    BWM_EmailApiResponse apiResponse,
    String requestCurl,
    String requestPayload
  ) {
    Email_Log__c logRecord = new Email_Log__c();
    logRecord.Related_Record_Id__c = record.Id;
    logRecord.Trigger_Point__c = triggerPoint;
    logRecord.From_Email__c = fromEmail;
    logRecord.To_Email__c = toEmail;
    logRecord.Status__c = status;

    if (mapping != null) {
      logRecord.Template_Name__c = mapping.Template_Name__c;
      logRecord.Template_Id__c = mapping.Template_Id__c;
    }

    if (record instanceof Lead) {
      logRecord.Lead__c = record.Id;
    } else if (record instanceof Opportunity) {
      logRecord.Opportunity__c = record.Id;
    }

    logRecord.Request_Curl__c = requestCurl;
    logRecord.Request_Payload__c = requestPayload;

    if (apiResponse != null) {
      logRecord.Response_Payload__c = apiResponse.rawBody;
      logRecord.Response_Message__c = apiResponse.message;
      logRecord.Response_Http_Status__c = apiResponse.httpStatus == null
        ? null
        : String.valueOf(apiResponse.httpStatus);
    }

    return logRecord;
  }

  public static void applyResolvedTemplateId(
    Email_Log__c logRecord,
    Id templateId
  ) {
    if (logRecord != null && templateId != null) {
      logRecord.Template_Id__c = String.valueOf(templateId);
    }
  }

  public static void insertLogs(List<Email_Log__c> logs) {
    if (!logs.isEmpty()) {
      insert logs;
    }
  }

  public static Boolean hasRecentSentLog(
    Id recordId,
    String triggerPoint,
    Integer withinDays
  ) {
    if (recordId == null || String.isBlank(triggerPoint)) {
      return false;
    }
    DateTime cutoff = System.now().addDays(-withinDays);
    Integer existingCount = [
      SELECT COUNT()
      FROM Email_Log__c
      WHERE
        Related_Record_Id__c = :String.valueOf(recordId)
        AND Trigger_Point__c = :triggerPoint
        AND Status__c = :BWM_EmailConstants.LOG_STATUS_SENT
        AND CreatedDate >= :cutoff
    ];
    return existingCount > 0;
  }
}