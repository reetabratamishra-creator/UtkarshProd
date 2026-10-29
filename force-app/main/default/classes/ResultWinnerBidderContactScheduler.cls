/*
================================================================================
CLASS: ResultWinnerBidderContactScheduler
--------------------------------------------------------------------------------
Entry point for Stage 3 (Result pipeline). Fires once daily at 5:00 PM,
enqueues ResultWinnerBidderContactBatch.
================================================================================
*/
public class ResultWinnerBidderContactScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        System.debug('[ResultWinnerBidderContactScheduler] Firing Result pipeline at: ' + DateTime.now());
        Database.executeBatch(new ResultWinnerBidderContactBatch(), 1);
    }
}
/*
================================================================================
ONE-TIME SETUP INSTRUCTIONS (run in Execute Anonymous, ONCE):
================================================================================

// 11:00 AM run - Result / Winner Bidder Contact data
System.schedule(
    'Tender247 Integration - Fetch Result & Winner Contact - 11AM Run',
    '0 0 11 * * ?',
    new ResultWinnerBidderContactScheduler()
);

//To verify:
SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime
FROM CronTrigger
WHERE CronJobDetail.Name = 'Tender247 Integration - Fetch Result & Winner Contact - 11AM Run'

//To run manually right now (for testing):
Database.executeBatch(new ResultWinnerBidderContactBatch(), 1);
================================================================================
*/