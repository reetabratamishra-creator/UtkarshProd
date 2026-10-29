global class OpportunityNurtureScheduler
implements Schedulable {

    global void execute(
        SchedulableContext sc
    ){

        Database.executeBatch(
            new OpportunityNurtureBatch(),
            200
        );
    }
}