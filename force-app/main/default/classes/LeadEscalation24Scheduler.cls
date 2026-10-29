global class LeadEscalation24Scheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        Database.executeBatch(
            new LeadEscalation24Batch(),
            200
        );
    }
}