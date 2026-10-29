/**
 * @description   Master schedulable that runs all Escalation Matrix batch jobs hourly.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class EscalationMatrixScheduler implements Schedulable {
  // Keep chunk size low so email/SOQL governors stay safe even if a record
  // sends multiple escalation tiers in one execute.
  private static final Integer BATCH_SIZE = 5;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new LeadProspectNotContacted48_96Batch(), BATCH_SIZE);
    //Database.executeBatch(new LeadProspectingNoActivityBatch(), BATCH_SIZE);
    Database.executeBatch(new OpportunityQuotationPendingMatrixBatch(), BATCH_SIZE);
    Database.executeBatch(new OpportunityNurtureActiveMatrixBatch(), BATCH_SIZE);
    Database.executeBatch(new OpportunityNurtureTenderMatrixBatch(), BATCH_SIZE);
    Database.executeBatch(new OpportunityNurtureBudgetaryMatrixBatch(), BATCH_SIZE);
    //Database.executeBatch(new OpportunityNegotiationActiveMatrixBatch(), BATCH_SIZE);
    //Database.executeBatch(new OpportunityNegotiationTenderMatrixBatch(), BATCH_SIZE);
    //Database.executeBatch(new OppNegoBudgetaryMatrixBatch(), BATCH_SIZE);
    //Database.executeBatch(new TaskOverdueEscalationMatrixBatch(), BATCH_SIZE);
  }
}