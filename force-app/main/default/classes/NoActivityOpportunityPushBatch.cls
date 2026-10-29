/**
 * @description   Hourly batch for Active (72h) and Project/Tender (3 month) opportunity no-activity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class NoActivityOpportunityPushBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          StageName,
          CreatedDate,
          Budget_Confirmed__c,
          RecordType.DeveloperName,
          Active_No_Activity_Push_72_Sent__c,
          Project_Tender_No_Activity_Push_90d_Sent__c
        FROM Opportunity
        WHERE
          IsClosed = FALSE
          AND (
            (
              StageName = 'Nurture'
              AND RecordType.DeveloperName != 'Tender_Opportunity'
              AND Budget_Confirmed__c = FALSE
              AND Active_No_Activity_Push_72_Sent__c = FALSE
            )
            OR (
              RecordType.DeveloperName IN (
                'Project_Opportunity',
                'Tender_Opportunity'
              )
              AND Project_Tender_No_Activity_Push_90d_Sent__c = FALSE
            )
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    NoActivityPushNotificationService.processOpportunities(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}