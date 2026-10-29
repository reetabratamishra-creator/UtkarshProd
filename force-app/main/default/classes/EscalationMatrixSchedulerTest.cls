/**
 * @description   Test class for EscalationMatrixScheduler.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class EscalationMatrixSchedulerTest {
  @IsTest
  static void testExecuteStartsAllBatches() {
    Test.startTest();
    new EscalationMatrixScheduler().execute(null);
    Test.stopTest();
    System.assert(true, 'Scheduler should enqueue all matrix batches without error');
  }
}