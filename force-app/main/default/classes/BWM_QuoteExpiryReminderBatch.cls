/**
 * @description   Batch and Schedulable that sends quote-expiry WhatsApp/journey
 *                reminders based on Quotation_Date.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_QuoteExpiryReminderBatch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    Date reminderDate = System.today().addDays(1);

    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Opportunity
        WHERE IsClosed = FALSE AND Quotation_Date__c = :reminderDate
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();

    for (Opportunity opportunityRecord : scope) {
      if (
        BWM_MessageLogService.hasRecentLog(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER,
          1
        )
      ) {
        continue;
      }

      requests.add(
        new BWM_MessagingRequest(
          opportunityRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER
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
      'BWM_QuoteExpiryReminderBatch finished. JobId=' +
        (context == null ? 'null' : String.valueOf(context.getJobId()))
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_QuoteExpiryReminderBatch(), 50);
  }
}