/**
 * @description   Trigger handler for Lead and Opportunity task overdue custom notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class TaskOverduePushNotificationHandler {
  /**
   * @description Sends a custom notification when a Lead or Opportunity task becomes overdue.
   */
  public static void handleOverdueTasks(
    List<Task> newTasks,
    Map<Id, Task> oldMap
  ) {
    TaskOverduePushNotificationService.sendForNewlyOverdueTasks(newTasks, oldMap);
  }
}