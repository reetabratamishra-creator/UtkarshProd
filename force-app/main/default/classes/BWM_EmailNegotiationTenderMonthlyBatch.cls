/**
 * @description   Batch and Schedulable for monthly negotiation/tender email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailNegotiationTenderMonthlyBatch implements Database.Batchable<SObject>, Schedulable {
  private static final Integer DEDUP_DAYS = 28;

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Opportunity
        WHERE
          IsClosed = FALSE
          AND StageName = :BWM_EmailConstants.STAGE_NEGOTIATION
          AND Sub_Stage__c = :BWM_EmailConstants.SUB_STAGE_TENDER
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Opportunity opportunityRecord : scope) {
      if (
        BWM_EmailLogService.hasRecentSentLog(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE,
          DEDUP_DAYS
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_EmailRequest(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE
        )
      );
    }

    if (!requests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(requests);
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug(
      LoggingLevel.INFO,
      'BWM_EmailNegotiationTenderMonthlyBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailNegotiationTenderMonthlyBatch(), 50);
  }
}