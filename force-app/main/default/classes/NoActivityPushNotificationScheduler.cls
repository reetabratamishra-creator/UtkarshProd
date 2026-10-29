/**
 * @description   Schedules hourly no-activity push notification batches for Leads and Opportunities.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class NoActivityPushNotificationScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new NoActivityLeadPushBatch(), 50);
    Database.executeBatch(new NoActivityOpportunityPushBatch(), 50);
  }
}