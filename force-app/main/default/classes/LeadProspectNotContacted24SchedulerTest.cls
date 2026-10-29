/**
 * @description   Test class for LeadProspectNotContacted24Scheduler. The scheduler
 *                body is commented out, so execute must not start any batch.
 * @author        Anshita Chanda
 * @date          2026-10-23
 */
@IsTest
private class LeadProspectNotContacted24SchedulerTest {
  @IsTest
  static void executeDoesNotStartBatch() {
    Test.startTest();
    new LeadProspectNotContacted24Scheduler().execute(null);
    Integer batchJobs = Limits.getQueueableJobs();
    Test.stopTest();

    System.assertEquals(0, batchJobs, 'Scheduler is disabled and must not queue work.');
  }
}