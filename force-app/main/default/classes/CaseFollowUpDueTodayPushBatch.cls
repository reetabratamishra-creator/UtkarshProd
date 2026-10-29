/**
 * @description Batch that sends follow-up-due-today Case push notifications to owners.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseFollowUpDueTodayPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 50;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseFollowUpDueTodayPushBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime startOfDay = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
    Datetime endOfDay = startOfDay.addDays(1);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          CaseNumber,
          OwnerId,
          Status,
          IsClosed,
          Due_Date_Time__c,
          Follow_Up_Due_Push_Sent_On__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND Due_Date_Time__c >= :startOfDay
          AND Due_Date_Time__c < :endOfDay
          AND (
            Follow_Up_Due_Push_Sent_On__c = NULL
            OR Follow_Up_Due_Push_Sent_On__c != TODAY
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    CasePushNotificationService.processFollowUpDueToday(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}