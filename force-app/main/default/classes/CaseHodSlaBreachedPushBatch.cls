/**
 * @description Batch that sends SLA-breached Case push notifications to Department HODs.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseHodSlaBreachedPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 1;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseHodSlaBreachedPushBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          CaseNumber,
          Priority,
          CreatedDate,
          First_Response__c,
          IsClosed,
          Department__c,
          Department_formula__c,
          HOD_User_Email_Formula__c,
          SLA_Breached_HOD_Push_Sent__c,
          SLA_Due_Date_Time_RO__c,
          Escalation_Date_1__c,
          Escalation_Date_2__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND First_Response__c = FALSE
          AND SLA_Breached_HOD_Push_Sent__c = FALSE
          AND Priority IN ('Critical', 'High', 'Medium', 'Low')
          AND (Department__c != NULL OR Department_formula__c != NULL)
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    CaseHodPushService.processSlaBreached(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}