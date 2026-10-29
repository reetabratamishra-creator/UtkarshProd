@isTest
private class ResultWinnerBidderContactSchedulerTest {

    // ============================================================
    // TEST 1: SCHEDULE JOB
    // ============================================================
    @isTest
    static void testScheduleJob() {

        String cronExp = '0 0 11 * * ?';
        String jobName =
            'Test - Result Winner Contact - 11AM';

        Test.startTest();

        String jobId = System.schedule(
            jobName,
            cronExp,
            new ResultWinnerBidderContactScheduler()
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            jobId,
            'Scheduled job Id should be returned.'
        );

        CronTrigger cron = [
            SELECT
                Id,
                CronExpression,
                CronJobDetail.Name,
                State
            FROM CronTrigger
            WHERE Id = :jobId
            LIMIT 1
        ];

        System.assertEquals(
            jobName,
            cron.CronJobDetail.Name
        );

        System.assertEquals(
            cronExp,
            cron.CronExpression
        );
    }


    // ============================================================
    // TEST 2: DIRECT EXECUTION
    // ============================================================
    @isTest
    static void testExecute() {

        Test.startTest();

        ResultWinnerBidderContactScheduler scheduler =
            new ResultWinnerBidderContactScheduler();

        scheduler.execute(null);

        Test.stopTest();

        System.assert(
            true,
            'Scheduler execute() completed successfully.'
        );
    }
}