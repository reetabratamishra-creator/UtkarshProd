global class NegoEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(
            new NegoActiveEscalationBatch(),
            200
        );

        // Database.executeBatch(
        //     new NegoTenderEscalationBatch(),
        //     200
        // );
    }
}