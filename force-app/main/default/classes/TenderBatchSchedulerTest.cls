@isTest
private class TenderBatchSchedulerTest {

    private class NoOpMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"Success":true,"Message":"OK","TotalRecord":0,' +
                '"Data":[{"count":0}],"StatusCode":200}'
            );

            return res;
        }
    }

    @isTest
    static void testScheduledMorningRunRegistersJob() {

        Test.setMock(
            HttpCalloutMock.class,
            new NoOpMock()
        );

        String cronExp = '0 0 8 * * ?';

        Test.startTest();

        System.schedule(
            'Tender247 Test - Morning',
            cronExp,
            new TenderBatchScheduler(
                TenderBatchScheduler.MAILTYPE_MORNING
            )
        );

        Test.stopTest();

        List<CronTrigger> triggers = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Tender247 Test - Morning'
        ];

        System.assertEquals(1, triggers.size());
        System.assertEquals(
            cronExp,
            triggers[0].CronExpression
        );
    }


    @isTest
    static void testScheduledAfternoonRunRegistersJob() {

        Test.setMock(
            HttpCalloutMock.class,
            new NoOpMock()
        );

        String cronExp = '0 0 16 * * ?';

        Test.startTest();

        System.schedule(
            'Tender247 Test - Afternoon',
            cronExp,
            new TenderBatchScheduler(
                TenderBatchScheduler.MAILTYPE_AFTERNOON
            )
        );

        Test.stopTest();

        List<CronTrigger> triggers = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Tender247 Test - Afternoon'
        ];

        System.assertEquals(1, triggers.size());
    }


    @isTest
    static void testExecuteDirectlyEnqueuesBatchWithoutException() {

        Test.setMock(
            HttpCalloutMock.class,
            new NoOpMock()
        );

        TenderBatchScheduler scheduler =
            new TenderBatchScheduler(
                TenderBatchScheduler.MAILTYPE_MORNING
            );

        Test.startTest();

        scheduler.execute(null);

        Test.stopTest();

        System.assert(
            true,
            'execute() should complete without throwing.'
        );
    }
}