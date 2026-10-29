/**
 * @description Batch that sends 36-hour no-update Case push notifications to owners.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseNoUpdate36hPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 50;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseNoUpdate36hPushBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff = System.now().addHours(-36);

    return Database.getQueryLocator(
      [
        SELECT Id, CaseNumber, OwnerId, No_Update_36h_Push_Sent__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND LastModifiedDate <= :cutoff
          AND No_Update_36h_Push_Sent__c = FALSE
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    CasePushNotificationService.processNoUpdate36h(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}