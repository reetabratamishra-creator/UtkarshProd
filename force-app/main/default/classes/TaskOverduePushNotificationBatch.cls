/**
 * @description   Daily catch-up batch for Lead and Opportunity tasks that became overdue overnight.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class TaskOverduePushNotificationBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext context) {
    Date yesterday = Date.today().addDays(-1);

    return Database.getQueryLocator(
      [
        SELECT Id, WhoId, WhatId, ActivityDate, Status
        FROM Task
        WHERE
          Status != 'Completed'
          AND ActivityDate = :yesterday
          AND (WhoId != NULL OR WhatId != NULL)
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Task> scope) {
    List<Task> relevantTasks = new List<Task>();

    for (Task taskRecord : scope) {
      if (
        (taskRecord.WhoId != null &&
        String.valueOf(taskRecord.WhoId).substring(0, 3) == '00Q') ||
        (taskRecord.WhatId != null &&
        String.valueOf(taskRecord.WhatId).substring(0, 3) == '006')
      ) {
        relevantTasks.add(taskRecord);
      }
    }

    TaskOverduePushNotificationService.sendForYesterdayOverdueTasks(relevantTasks);
  }

  public void finish(Database.BatchableContext context) {
  }
}