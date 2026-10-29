/**
 * @description   Schedules the daily Lead task overdue push notification batch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class TaskOverduePushNotificationScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new TaskOverduePushNotificationBatch(), 200);
  }
}