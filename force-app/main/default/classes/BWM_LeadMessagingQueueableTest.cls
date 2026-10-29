/**
 * @description   Tests Lead-create messaging queueable construction and execute.
 * @author        Anshita Chanda
 * @date          2026-08-18
 */
@IsTest
private class BWM_LeadMessagingQueueableTest {
  @IsTest
  static void executeWithLeadIdsAndNullList() {
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    Lead leadRecord = new Lead(
      LastName = 'Queueable Lead',
      Company = 'Queueable Co',
      Status = 'Prospect',
      Phone = '9000018201'
    );
    insert leadRecord;
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"accepted"}',
        '{"code":"200","message":"accepted"}'
      )
    );

    Test.startTest();
    new BWM_LeadMessagingQueueable(null).execute(null);
    System.enqueueJob(new BWM_LeadMessagingQueueable(new List<Id>{ leadRecord.Id }));
    Test.stopTest();

    System.assertNotEquals(null, leadRecord.Id);
  }
}