/**
 * @description   Schedulable that runs monthly dealer and negotiation email batches on
 *                the 1st.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailMonthlyScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    List<Database.Batchable<SObject>> batches = new List<Database.Batchable<SObject>>{
      new BWM_EmailDealerMonthlyBatch(),
      new BWM_EmailNegotiationTenderMonthlyBatch(),
      new BWM_EmailNegotiationStageUpdateBatch()
    };
    if (!Test.isRunningTest() && System.today().day() != 1) {
      return;
    }

    Integer batchCount = Test.isRunningTest() ? 1 : batches.size();
    for (Integer index = 0; index < batchCount; index++) {
      Database.executeBatch(batches[index], 50);
    }
  }
}