/**
 * @description   Test class for EscalationMatrixDailyScheduler.
 * 
 */
@IsTest
private class EscalationMatrixDailySchedulerTest {
  @IsTest
  static void testSchedulerIsScheduled() {
    EscalationMatrixTestUtil.prepareTestContext();

    String cronExp = '0 0 9 * * ?'; // daily at 9 AM

    Test.startTest();
    String jobId = System.schedule(
      'EscalationMatrixDailyScheduler Test',
      cronExp,
      new EscalationMatrixDailyScheduler()
    );
    Test.stopTest();

    CronTrigger ct = [
      SELECT CronExpression, TimesTriggered, NextFireTime
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cronExp, ct.CronExpression);
    System.assertEquals(0, ct.TimesTriggered); // fires on schedule, not inside the test
    System.assertNotEquals(null, ct.NextFireTime);
  }

  @IsTest
  static void testSchedulerExecuteRunsAllBatches() {
    EscalationMatrixTestUtil.prepareTestContext();

    // Seed one record per batch so each batch has something to process
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'DailySchedLead');
    Opportunity activeOpp = EscalationMatrixTestUtil.createOpportunity(
      'Negotiation',
      'Daily Sched Active Opp',
      false,
      null
    );
    Task overdueTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Daily Sched Overdue',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert overdueTask;

    Test.startTest();
    new EscalationMatrixDailyScheduler().execute(null); // calls executeBatch for all 5 batches
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Id = :leadRecord.Id]);
    System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Id = :activeOpp.Id]);
  }
}