/**
 * @description   After-insert Task Log handler that enqueues the Unolo client visit
 *                journey when the related Punch record has no prior Task Log.
 * @author        Anshita Chanda
 * @date          2026-08-13
 */
public without sharing class BWM_TaskLogUnoloTriggerHandler {
  @TestVisible
  private static Boolean skipForTests = false;

  @TestVisible
  private static Boolean forceExceptionForTests = false;

  @TestVisible
  private static Integer testEnqueueCount = 0;

  @TestVisible
  static void resetTestState() {
    skipForTests = false;
    forceExceptionForTests = false;
    testEnqueueCount = 0;
  }

  /**
   * @description Evaluates newly inserted Task Logs and enqueues Unolo journey sends
   *              for the first Task Log on each Punch record.
   * @param newRecords Task Log records inserted in the trigger context.
   */
  public static void handleAfterInsert(List<Task_Log__c> newRecords) {
    if (Test.isRunningTest() && forceExceptionForTests) {
      throw new AuraHandledException('Forced test exception');
    }
    if (Test.isRunningTest() && skipForTests) {
      return;
    }
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      return;
    }

    Set<Id> newTaskLogIds = new Map<Id, Task_Log__c>(newRecords).keySet();
    Set<Id> punchIds = new Set<Id>();
    for (Task_Log__c taskLogRecord : newRecords) {
      if (taskLogRecord.Punch_Record__c != null) {
        punchIds.add(taskLogRecord.Punch_Record__c);
      }
    }
    if (punchIds.isEmpty()) {
      return;
    }

    Map<Id, Integer> priorTaskLogCountByPunch = queryPriorTaskLogCountByPunch(
      punchIds,
      newTaskLogIds
    );
    List<Id> taskLogIdsToSend = selectFirstTaskLogIdsForPunch(
      newRecords,
      priorTaskLogCountByPunch
    );
    if (taskLogIdsToSend.isEmpty()) {
      return;
    }

    enqueueSend(taskLogIdsToSend);
  }

  @TestVisible
  private static Map<Id, Integer> queryPriorTaskLogCountByPunch(
    Set<Id> punchIds,
    Set<Id> excludeTaskLogIds
  ) {
    Map<Id, Integer> priorTaskLogCountByPunch = new Map<Id, Integer>();
    for (AggregateResult aggregateRow : [
      SELECT Punch_Record__c punchId, COUNT(Id) taskLogCount
      FROM Task_Log__c
      WHERE Punch_Record__c IN :punchIds AND Id NOT IN :excludeTaskLogIds
      GROUP BY Punch_Record__c
    ]) {
      priorTaskLogCountByPunch.put(
        (Id) aggregateRow.get('punchId'),
        (Integer) aggregateRow.get('taskLogCount')
      );
    }
    return priorTaskLogCountByPunch;
  }

  @TestVisible
  private static List<Id> selectFirstTaskLogIdsForPunch(
    List<Task_Log__c> newRecords,
    Map<Id, Integer> priorTaskLogCountByPunch
  ) {
    List<Id> taskLogIdsToSend = new List<Id>();
    Set<Id> punchesQueued = new Set<Id>();

    for (Task_Log__c taskLogRecord : newRecords) {
      if (
        taskLogRecord == null ||
        taskLogRecord.Id == null ||
        taskLogRecord.Punch_Record__c == null ||
        taskLogRecord.Account__c == null
      ) {
        continue;
      }

      Id punchId = taskLogRecord.Punch_Record__c;
      Integer priorCount = priorTaskLogCountByPunch.containsKey(punchId)
        ? priorTaskLogCountByPunch.get(punchId)
        : 0;
      if (priorCount > 0 || punchesQueued.contains(punchId)) {
        continue;
      }

      punchesQueued.add(punchId);
      taskLogIdsToSend.add(taskLogRecord.Id);
    }

    return taskLogIdsToSend;
  }

  private static void enqueueSend(List<Id> taskLogIdsToSend) {
    if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
      if (Test.isRunningTest()) {
        testEnqueueCount++;
      }
      System.enqueueJob(new BWM_TaskLogUnoloJourneyQueueable(taskLogIdsToSend));
      return;
    }
    BWM_TaskLogUnoloJourneyService.sendForTaskLogIds(taskLogIdsToSend);
  }
}