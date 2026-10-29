/**
 * @description   Daily batch for quotation-pending Opportunity push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityQuotationPendingPushBatch
  implements Database.Batchable<SObject>, Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new OpportunityQuotationPendingPushBatch(), 50);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id, Name, OwnerId, Quotation_Pending_Push_Sent__c
        FROM Opportunity
        WHERE IsClosed = FALSE AND Quotation_Pending_Push_Sent__c = FALSE
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    OpportunityQuotationPendingPushService.processOpportunities(scope);
  }

  public void finish(Database.BatchableContext context) {
  }
}