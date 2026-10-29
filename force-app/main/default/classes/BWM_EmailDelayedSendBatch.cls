/**
 * @description   Batch and Schedulable that processes pending
 *                BWM_Email_Scheduled_Send__c delayed emails.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailDelayedSendBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Related_Record_Id__c,
          Trigger_Point__c,
          Lead__c,
          Opportunity__c,
          Process_After__c,
          Status__c
        FROM BWM_Email_Scheduled_Send__c
        WHERE
          Status__c = :BWM_EmailConstants.SCHEDULE_STATUS_PENDING
          AND Process_After__c <= :System.now()
      ]
    );
  }

  /**
   * @description Processes a batch of pending scheduled email rows; collects logs and updates for bulk DML outside the loop.
   * @param context Batchable context from the platform.
   * @param scope Pending BWM_Email_Scheduled_Send__c records due for send.
   */
  public void execute(
    Database.BatchableContext context,
    List<BWM_Email_Scheduled_Send__c> scope
  ) {
    List<BWM_Email_Scheduled_Send__c> updates = new List<BWM_Email_Scheduled_Send__c>();
    List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

    for (BWM_Email_Scheduled_Send__c scheduled : scope) {
      try {
        Id recordId = resolveRecordId(scheduled);
        if (recordId == null) {
          markCancelled(scheduled, 'Related record Id is missing.');
          updates.add(scheduled);
          continue;
        }

        if (!isStillEligible(recordId, scheduled.Trigger_Point__c)) {
          markCancelled(scheduled, 'Record no longer matches delayed send criteria.');
          updates.add(scheduled);
          continue;
        }

        BWM_EmailService.SendResult sendResult = BWM_EmailService.sendScheduled(
          recordId,
          scheduled.Trigger_Point__c
        );

        if (sendResult.sent) {
          scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_SENT;
          scheduled.Error_Message__c = null;
        } else {
          scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_FAILED;
          scheduled.Error_Message__c = sendResult.skipReason;
        }
        updates.add(scheduled);
        if (sendResult.logs != null && !sendResult.logs.isEmpty()) {
          logsToInsert.addAll(sendResult.logs);
        }
      } catch (Exception ex) {
        scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_FAILED;
        scheduled.Error_Message__c = ex.getMessage();
        updates.add(scheduled);
      }
    }

    if (!logsToInsert.isEmpty()) {
      BWM_EmailLogService.insertLogs(logsToInsert);
    }
    if (!updates.isEmpty()) {
      update updates;
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug(
      LoggingLevel.INFO,
      'BWM_EmailDelayedSendBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailDelayedSendBatch(), 50);
  }

  private static Id resolveRecordId(BWM_Email_Scheduled_Send__c scheduled) {
    if (scheduled.Lead__c != null) {
      return scheduled.Lead__c;
    }
    if (scheduled.Opportunity__c != null) {
      return scheduled.Opportunity__c;
    }
    if (String.isNotBlank(scheduled.Related_Record_Id__c)) {
      return (Id) scheduled.Related_Record_Id__c;
    }
    return null;
  }

  private static Boolean isStillEligible(Id recordId, String triggerPoint) {
    if (
      triggerPoint ==
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED
    ) {
      Lead leadRecord = BWM_EmailRecordQueryService.queryLead(recordId);
      return isProspectingLostDetailsLead(leadRecord);
    }

    if (
      triggerPoint ==
      BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE_DELAYED
    ) {
      Opportunity opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
        recordId
      );
      Set<String> allowed = BWM_EmailConstants.OPP_LOST_REASONS_BY_GROUP.get(
        BWM_EmailConstants.OPP_LOST_GROUP_DETAILS_NOT_RECEIVED
      );
      Boolean stageMatches =
        opportunityRecord.StageName == BWM_EmailConstants.STAGE_NURTURE ||
        opportunityRecord.StageName == BWM_EmailConstants.STAGE_CLOSED_LOST;
      return stageMatches &&
        allowed != null &&
        allowed.contains(opportunityRecord.Lost_Reason__c);
    }

    return true;
  }

  private static Boolean isProspectingLostDetailsLead(Lead leadRecord) {
    if (leadRecord == null) {
      return false;
    }

    Boolean stageMatches =
      leadRecord.Status == BWM_EmailConstants.STAGE_PROSPECTING ||
      leadRecord.Status == 'Lost';

    Set<String> allowed = BWM_EmailConstants.LOST_REASONS_BY_GROUP.get(
      BWM_EmailConstants.LOST_GROUP_DETAILS_NOT_RECEIVED
    );

    return stageMatches &&
      allowed != null &&
      allowed.contains(leadRecord.Lost_Reason__c);
  }

  private static void markCancelled(
    BWM_Email_Scheduled_Send__c scheduled,
    String reason
  ) {
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_CANCELLED;
    scheduled.Error_Message__c = reason;
  }
}