public without sharing class BWM_EmailNegotiationStaleBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    DateTime cutoffDate = System.now().addDays(-30);

    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Opportunity
        WHERE
          IsClosed = FALSE
          AND StageName = :BWM_EmailConstants.STAGE_NEGOTIATION
          AND LastModifiedDate <= :cutoffDate
      ]
    );
  }

  public void execute(
    Database.BatchableContext context,
    List<Opportunity> scope
  ) {
    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Opportunity opportunityRecord : scope) {
      if (
        BWM_EmailLogService.hasRecentSentLog(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
          30
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_EmailRequest(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS
        )
      );
    }

    if (!requests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(requests);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailNegotiationStaleBatch(), 50);
  }
}