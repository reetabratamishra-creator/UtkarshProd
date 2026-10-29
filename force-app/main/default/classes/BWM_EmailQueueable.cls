public without sharing class BWM_EmailQueueable implements Queueable, Database.AllowsCallouts {
  private final List<BWM_EmailRequest> requests;

  public BWM_EmailQueueable(List<BWM_EmailRequest> requests) {
    this.requests = requests == null
      ? new List<BWM_EmailRequest>()
      : new List<BWM_EmailRequest>(requests);
  }

  public void execute(QueueableContext context) {
    List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

    for (BWM_EmailRequest requestItem : requests) {
      if (requestItem == null || requestItem.recordId == null) {
        continue;
      }

      try {
        BWM_EmailService.SendResult sendResult;
        if (
          requestItem.triggerPoint == BWM_EmailConstants.TRIGGER_LEAD_CREATE
        ) {
          sendResult = BWM_EmailService.sendForLeadCreate(requestItem.recordId);
        } else {
          sendResult = BWM_EmailService.send(
            requestItem.recordId,
            requestItem.triggerPoint,
            requestItem.stageAtAction
          );
        }
        if (sendResult != null && sendResult.logs != null) {
          logsToInsert.addAll(sendResult.logs);
        }
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'BWM_EmailQueueable failed for ' +
            requestItem.recordId +
            ' / ' +
            requestItem.triggerPoint +
            ': ' +
            ex.getMessage()
        );
        Email_Log__c failLog = new Email_Log__c();
        failLog.Related_Record_Id__c = String.valueOf(requestItem.recordId);
        failLog.Trigger_Point__c = requestItem.triggerPoint;
        failLog.Status__c = BWM_EmailConstants.LOG_STATUS_FAILED;
        failLog.Response_Message__c = ex.getMessage();
        if (requestItem.recordId.getSObjectType() == Lead.SObjectType) {
          failLog.Lead__c = requestItem.recordId;
        } else if (
          requestItem.recordId.getSObjectType() == Opportunity.SObjectType
        ) {
          failLog.Opportunity__c = requestItem.recordId;
        }
        logsToInsert.add(failLog);
      }
    }

    BWM_EmailLogService.insertLogs(logsToInsert);
  }
}