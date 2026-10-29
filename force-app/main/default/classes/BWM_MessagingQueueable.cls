/**
 * @description   Queueable job that processes messaging requests with HTTP callouts for
 *                WhatsApp/RCS/SMS journey sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_MessagingQueueable implements Queueable, Database.AllowsCallouts {
  private final List<BWM_MessagingRequest> requests;

  public BWM_MessagingQueueable(List<BWM_MessagingRequest> requests) {
    this.requests = requests == null
      ? new List<BWM_MessagingRequest>()
      : new List<BWM_MessagingRequest>(requests);
  }

  public void execute(QueueableContext context) {
    processRequests(requests);
  }

  public static void processRequests(List<BWM_MessagingRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

    for (BWM_MessagingRequest requestItem : requests) {
      if (requestItem == null || requestItem.recordId == null) {
        continue;
      }

      try {
        BWM_MessagingService.SendResult sendResult;
        if (
          requestItem.triggerPoint == BWM_MessagingConstants.TRIGGER_LEAD_CREATE
        ) {
          sendResult = BWM_MessagingService.sendForLeadCreate(
            requestItem.recordId
          );
        } else {
          sendResult = BWM_MessagingService.send(
            requestItem.recordId,
            requestItem.triggerPoint,
            requestItem.stageAtAction
          );
        }
        logsToInsert.addAll(sendResult.logs);
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'BWM messaging failed for ' +
            requestItem.recordId +
            ' / ' +
            requestItem.triggerPoint +
            ': ' +
            ex.getMessage()
        );
        logsToInsert.add(buildFailedExceptionLog(requestItem, ex));
      }
    }

    BWM_MessageLogService.insertLogs(logsToInsert);
  }

  /**
   * @description Builds a Failed Message_Log__c so Apex exceptions are visible in
   *              the UI instead of only debug logs.
   */
  @TestVisible
  private static Message_Log__c buildFailedExceptionLog(
    BWM_MessagingRequest requestItem,
    Exception ex
  ) {
    Message_Log__c failedLog = new Message_Log__c();
    failedLog.Related_Record_Id__c = String.valueOf(requestItem.recordId);
    failedLog.Trigger_Point__c = requestItem.triggerPoint;
    failedLog.Channel__c = BWM_MessagingConstants.LOG_CHANNEL_JOURNEY;
    failedLog.Template_Name__c = 'Apex exception';
    failedLog.Status__c = BWM_MessagingConstants.LOG_STATUS_FAILED;
    failedLog.Response_Message__c = formatExceptionMessage(ex);

    Schema.SObjectType recordType = requestItem.recordId.getSObjectType();
    if (recordType == Lead.SObjectType) {
      failedLog.Lead__c = requestItem.recordId;
    } else if (recordType == Opportunity.SObjectType) {
      failedLog.Opportunity__c = requestItem.recordId;
    }

    return failedLog;
  }

  private static String formatExceptionMessage(Exception ex) {
    if (ex == null) {
      return 'Apex exception with no message.';
    }

    String message =
      'Apex exception: ' +
      ex.getTypeName() +
      ': ' +
      ex.getMessage();
    String stackTrace = ex.getStackTraceString();
    if (String.isNotBlank(stackTrace)) {
      message += '\n' + stackTrace;
    }
    if (message.length() > 32000) {
      return message.substring(0, 32000);
    }
    return message;
  }
}