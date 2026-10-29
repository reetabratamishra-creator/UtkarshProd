/**
 * @description Batch that sends SLA-breached Case push notifications to owners.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseSlaBreachedOwnerPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 1;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseSlaBreachedOwnerPushBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          CaseNumber,
          Priority,
          OwnerId,
          CreatedDate,
          First_Response__c,
          IsClosed,
          SLA_Breached_Push_Sent__c,
          SLA_Due_Date_Time_RO__c,
          Escalation_Date_1__c,
          Escalation_Date_2__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND First_Response__c = FALSE
          AND SLA_Breached_Push_Sent__c = FALSE
          AND Priority IN ('Critical', 'High', 'Medium', 'Low')
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    CasePushNotificationService.processSlaBreached(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}