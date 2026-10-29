/**
 * @description   Batch and Schedulable that sends messaging for Opportunities stuck in
 *                Negotiation stage.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_NegotiationStageUpdateBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    DateTime cutoffDate = System.now().addDays(-30);

    return Database.getQueryLocator(
      [
        SELECT Id, Sub_Stage__c
        FROM Opportunity
        WHERE
          IsClosed = FALSE
          AND StageName = :BWM_MessagingConstants.STAGE_NEGOTIATION
          AND LastModifiedDate <= :cutoffDate
      ]
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Opportunity> scope
  ) {
    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();

    for (Opportunity opportunityRecord : scope) {
      if (
        opportunityRecord.Sub_Stage__c != BWM_MessagingConstants.SUB_STAGE_ACTIVE &&
        opportunityRecord.Sub_Stage__c != BWM_MessagingConstants.SUB_STAGE_BUDGETARY
      ) {
        continue;
      }

      if (
        BWM_MessageLogService.hasRecentLog(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
          30
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_MessagingRequest(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS
        )
      );
    }

    if (!requests.isEmpty()) {
      BWM_MessagingEnqueueService.enqueue(requests);
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug(
      LoggingLevel.INFO,
      'BWM_NegotiationStageUpdateBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_NegotiationStageUpdateBatch(), 50);
  }
}