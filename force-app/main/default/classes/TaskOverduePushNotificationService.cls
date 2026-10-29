/**
 * @description   Sends custom notifications when Lead- or Opportunity-related Tasks become overdue.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class TaskOverduePushNotificationService {
  private static final String LEAD_NOTIF_TYPE = 'Lead_Owner_Notification';
  private static final String OPP_NOTIF_TYPE = 'Task_Assignment';
  private static final String NOTIFICATION_TITLE = 'Task is now overdue';

  /**
   * @description Sends overdue push notifications for newly overdue Lead or Opportunity tasks.
   */
  public static void sendForNewlyOverdueTasks(
    List<Task> newTasks,
    Map<Id, Task> oldMap
  ) {
    if (newTasks == null || newTasks.isEmpty()) {
      return;
    }

    Set<Id> leadIds = new Set<Id>();
    Set<Id> opportunityIds = new Set<Id>();

    for (Task taskRecord : newTasks) {
      if (isNewlyOverdueLeadTask(taskRecord, oldMap) && taskRecord.WhoId != null) {
        leadIds.add(taskRecord.WhoId);
      }
      if (
        isNewlyOverdueOpportunityTask(taskRecord, oldMap) &&
        taskRecord.WhatId != null
      ) {
        opportunityIds.add(taskRecord.WhatId);
      }
    }

    Map<Id, Lead> leadById = leadIds.isEmpty()
      ? new Map<Id, Lead>()
      : new Map<Id, Lead>(
          [
            SELECT Id, Name, OwnerId
            FROM Lead
            WHERE Id IN :leadIds
          ]
        );

    Map<Id, Opportunity> opportunityById = opportunityIds.isEmpty()
      ? new Map<Id, Opportunity>()
      : new Map<Id, Opportunity>(
          [
            SELECT Id, Name, OwnerId
            FROM Opportunity
            WHERE Id IN :opportunityIds
          ]
        );

    for (Task taskRecord : newTasks) {
      if (isNewlyOverdueLeadTask(taskRecord, oldMap) && taskRecord.WhoId != null) {
        Lead leadRecord = leadById.get(taskRecord.WhoId);
        if (leadRecord != null && leadRecord.OwnerId != null) {
          sendToLeadOwner(leadRecord);
        }
      }

      if (
        isNewlyOverdueOpportunityTask(taskRecord, oldMap) &&
        taskRecord.WhatId != null
      ) {
        Opportunity opportunityRecord = opportunityById.get(taskRecord.WhatId);
        if (opportunityRecord != null && opportunityRecord.OwnerId != null) {
          sendToOpportunityOwner(opportunityRecord);
        }
      }
    }
  }

  /**
   * @description Sends overdue push notifications for Lead and Opportunity tasks that became
   *              overdue on the previous calendar day and remain open.
   */
  public static void sendForYesterdayOverdueTasks(List<Task> taskRecords) {
    if (taskRecords == null || taskRecords.isEmpty()) {
      return;
    }

    Set<Id> leadIds = new Set<Id>();
    Set<Id> opportunityIds = new Set<Id>();

    for (Task taskRecord : taskRecords) {
      Id whoId = getPopulatedId(taskRecord, 'WhoId');
      Id whatId = getPopulatedId(taskRecord, 'WhatId');

      if (whoId != null) {
        leadIds.add(whoId);
      }
      if (whatId != null) {
        opportunityIds.add(whatId);
      }
    }

    Map<Id, Lead> leadById = leadIds.isEmpty()
      ? new Map<Id, Lead>()
      : new Map<Id, Lead>(
          [
            SELECT Id, Name, OwnerId
            FROM Lead
            WHERE Id IN :leadIds
          ]
        );

    Map<Id, Opportunity> opportunityById = opportunityIds.isEmpty()
      ? new Map<Id, Opportunity>()
      : new Map<Id, Opportunity>(
          [
            SELECT Id, Name, OwnerId
            FROM Opportunity
            WHERE Id IN :opportunityIds
          ]
        );

    Set<Id> notifiedLeadIds = new Set<Id>();
    Set<Id> notifiedOpportunityIds = new Set<Id>();

    for (Task taskRecord : taskRecords) {
      Id whoId = getPopulatedId(taskRecord, 'WhoId');
      Id whatId = getPopulatedId(taskRecord, 'WhatId');

      if (whoId != null && !notifiedLeadIds.contains(whoId)) {
        Lead leadRecord = leadById.get(whoId);
        if (leadRecord != null && leadRecord.OwnerId != null) {
          sendToLeadOwner(leadRecord);
          notifiedLeadIds.add(whoId);
        }
      }

      if (whatId != null && !notifiedOpportunityIds.contains(whatId)) {
        Opportunity opportunityRecord = opportunityById.get(whatId);
        if (opportunityRecord != null && opportunityRecord.OwnerId != null) {
          sendToOpportunityOwner(opportunityRecord);
          notifiedOpportunityIds.add(whatId);
        }
      }
    }
  }

  @TestVisible
  private static Id getPopulatedId(Task taskRecord, String fieldName) {
    if (
      taskRecord == null ||
      !taskRecord.getPopulatedFieldsAsMap().containsKey(fieldName)
    ) {
      return null;
    }

    return (Id) taskRecord.get(fieldName);
  }

  @TestVisible
  static Boolean isNewlyOverdueLeadTask(Task taskRecord, Map<Id, Task> oldMap) {
    if (taskRecord == null || taskRecord.WhoId == null) {
      return false;
    }

    if (String.valueOf(taskRecord.WhoId).substring(0, 3) != '00Q') {
      return false;
    }

    return isNewlyOverdueTask(taskRecord, oldMap);
  }

  @TestVisible
  static Boolean isNewlyOverdueOpportunityTask(
    Task taskRecord,
    Map<Id, Task> oldMap
  ) {
    if (taskRecord == null || taskRecord.WhatId == null) {
      return false;
    }

    if (String.valueOf(taskRecord.WhatId).substring(0, 3) != '006') {
      return false;
    }

    return isNewlyOverdueTask(taskRecord, oldMap);
  }

  @TestVisible
  static Boolean isNewlyOverdueTask(Task taskRecord, Map<Id, Task> oldMap) {
    if (!isOverdueOpenTask(taskRecord)) {
      return false;
    }

    if (oldMap == null) {
      return true;
    }

    Task oldTask = oldMap.get(taskRecord.Id);
    if (oldTask == null) {
      return true;
    }

    return !isOverdueOpenTask(oldTask);
  }

  @TestVisible
  static Boolean isOverdueOpenTask(Task taskRecord) {
    return taskRecord != null &&
      taskRecord.Status != 'Completed' &&
      taskRecord.ActivityDate != null &&
      taskRecord.ActivityDate < Date.today();
  }

  private static void sendToLeadOwner(Lead leadRecord) {
    String body =
      'Task is now overdue - Please take action. Click below ' +
      leadRecord.Name +
      '.';

    CrmPushNotificationService.send(
      leadRecord.OwnerId,
      leadRecord.Id,
      NOTIFICATION_TITLE,
      body,
      LEAD_NOTIF_TYPE
    );
  }

  private static void sendToOpportunityOwner(Opportunity opportunityRecord) {
    String body =
      'Task is now overdue - Please take action. Click below ' +
      opportunityRecord.Name +
      '.';

    CrmPushNotificationService.send(
      opportunityRecord.OwnerId,
      opportunityRecord.Id,
      NOTIFICATION_TITLE,
      body,
      OPP_NOTIF_TYPE
    );
  }

  @TestVisible
  static void clearTestState() {
    CrmPushNotificationService.clearTestState();
  }
}