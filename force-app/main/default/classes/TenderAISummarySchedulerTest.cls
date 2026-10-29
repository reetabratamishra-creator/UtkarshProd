@IsTest
private class TenderAISummarySchedulerTest {


@IsTest
static void testTenderAISummaryScheduler() {

    Test.startTest();

    String cronExp = '0 30 8 * * ?';

    String jobId = System.schedule(
        'Tender AI Summary Fetch Test',
        cronExp,
        new TenderAISummaryScheduler()
    );

    Test.stopTest();

    System.assertNotEquals(
        null,
        jobId,
        'Scheduled job should be created successfully.'
    );

    CronTrigger ct = [
        SELECT Id, CronExpression, TimesTriggered, State
        FROM CronTrigger
        WHERE Id = :jobId
        LIMIT 1
    ];

    System.assertEquals(
        cronExp,
        ct.CronExpression,
        'Cron expression should match the expected schedule.'
    );
}

}