/**
 * @description Batch that sends 36-hour no-update Case push notifications to CRM Head.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseCrmHeadNoUpdate36hPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 50;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseCrmHeadNoUpdate36hPushBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff = System.now().addHours(-36);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          CaseNumber,
          Department__c,
          Department_formula__c,
          CRM_User_Email_Formula__c,
          No_Update_36h_CRM_Head_Push_Sent__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND LastModifiedDate <= :cutoff
          AND No_Update_36h_CRM_Head_Push_Sent__c = FALSE
          AND (Department__c != NULL OR Department_formula__c != NULL)
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    CaseCrmHeadPushService.processNoUpdate36h(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}