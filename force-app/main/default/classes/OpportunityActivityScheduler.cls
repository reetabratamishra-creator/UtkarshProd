global with sharing class OpportunityActivityScheduler
implements Schedulable{

    global void execute(
        SchedulableContext sc
    ){

        System.debug(
            LoggingLevel.INFO,
            '========== Opportunity Activity Scheduler Started =========='
        );

        Database.executeBatch(

            new OpportunityActivityBatch(),

            OpportunityActivityConstants.DEFAULT_BATCH_SIZE

        );

        System.debug(
            LoggingLevel.INFO,
            '========== Opportunity Activity Scheduler Finished =========='
        );

    }

}