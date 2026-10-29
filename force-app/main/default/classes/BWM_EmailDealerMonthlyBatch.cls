/**
 * @description   Batch and Schedulable for monthly dealer email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailDealerMonthlyBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Account
        WHERE
          Id IN (
            SELECT DealerAccount__c
            FROM Opportunity
            WHERE IsClosed = FALSE AND DealerAccount__c != NULL
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Account> scope) {
    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Account accountRecord : scope) {
      if (
        BWM_EmailLogService.hasRecentSentLog(
          accountRecord.Id,
          BWM_EmailConstants.TRIGGER_DEALER_MONTHLY_UPDATE,
          28
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_EmailRequest(
          accountRecord.Id,
          BWM_EmailConstants.TRIGGER_DEALER_MONTHLY_UPDATE
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
      'BWM_EmailDealerMonthlyBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailDealerMonthlyBatch(), 50);
  }
}