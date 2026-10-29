@IsTest
private class PolymerHDPESchedulerTest {
    
@IsTest
static void testSchedulerExecute() {

    Test.startTest();

    String cronExp = '0 0 17 * * ?';

    String jobId = System.schedule(
        'Polymer HDPE Daily Job Test',
        cronExp,
        new PolymerHDPEScheduler()
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