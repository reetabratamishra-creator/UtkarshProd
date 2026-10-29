global class LeadProspectingEscalationScheduler
implements Schedulable {

    global void execute(
        SchedulableContext sc
    ) {

        Database.executeBatch(
            new LeadProspectingEscalationBatch(),
            100
        );
    }
}