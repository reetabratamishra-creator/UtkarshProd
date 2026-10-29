/**
 * @description Runs selected Escalation Matrix batches daily at 9 AM.
 */
public without sharing class EscalationMatrixDailyScheduler
    implements Schedulable {

    private static final Integer BATCH_SIZE = 5;

    public void execute(SchedulableContext context) {
        Database.executeBatch(
            new LeadProspectingNoActivityBatch(), BATCH_SIZE
        );

        Database.executeBatch(
            new OpportunityNegotiationActiveMatrixBatch(), BATCH_SIZE
        );

        Database.executeBatch(
            new OpportunityNegotiationTenderMatrixBatch(), BATCH_SIZE
        );

        Database.executeBatch(
            new OppNegoBudgetaryMatrixBatch(), BATCH_SIZE
        );

        Database.executeBatch(
            new TaskOverdueEscalationMatrixBatch(), BATCH_SIZE
        );
    }
}