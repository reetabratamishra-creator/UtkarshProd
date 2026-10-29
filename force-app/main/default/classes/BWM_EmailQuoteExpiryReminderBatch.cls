/**
 * @description   Batch and Schedulable that sends email quote-expiry reminders.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailQuoteExpiryReminderBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    Date reminderDate = System.today().addDays(1);

    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Opportunity
        WHERE
          IsClosed = FALSE
          AND Quotation_Date__c = :reminderDate
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();

    for (Opportunity opportunityRecord : scope) {
      if (
        BWM_EmailLogService.hasRecentSentLog(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_QUOTE_EXPIRY_REMINDER,
          1
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_EmailRequest(
          opportunityRecord.Id,
          BWM_EmailConstants.TRIGGER_OPP_QUOTE_EXPIRY_REMINDER
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
      'BWM_EmailQuoteExpiryReminderBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailQuoteExpiryReminderBatch(), 50);
  }
}