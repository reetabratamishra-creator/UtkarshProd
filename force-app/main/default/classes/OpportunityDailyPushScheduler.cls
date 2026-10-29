/**
 * @description   Schedules daily Opportunity quotation, visit, and event push batches.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityDailyPushScheduler
  implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new OpportunityQuotationPendingPushBatch(), 50);
    Database.executeBatch(new OpportunityVisitTodayPushBatch(), 50);
    Database.executeBatch(new OpportunityEventTodayPushBatch(), 50);
  }
}