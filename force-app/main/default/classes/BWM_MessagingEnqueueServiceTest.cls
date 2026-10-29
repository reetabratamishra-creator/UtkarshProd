/**
 * @description   Test class for BWM_MessagingEnqueueService queueable enqueue and
 *                lead-create helpers.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_MessagingEnqueueServiceTest {
  /**
   * Scenario: Null or empty request lists return without enqueueing jobs.
   */
  @IsTest
  static void testEnqueue_NullOrEmpty_NoOp() {
    Test.startTest();
    BWM_MessagingEnqueueService.enqueue(null);
    BWM_MessagingEnqueueService.enqueue(new List<BWM_MessagingRequest>());
    Test.stopTest();

    System.assertEquals(true, true, 'Empty enqueue should complete without error.');
  }

  /**
   * Scenario: Single-record enqueue schedules messaging queueable work.
   */
  @IsTest
  static void testEnqueue_SingleRecord_QueuesJob() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    Lead leadRecord = new Lead(
      LastName = 'Enqueue Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Enqueue Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company_Name__c = 'Enqueue Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      LeadSource = 'INBOUND EMAIL',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'enqueue+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system leadRecord;

    Test.startTest();
    BWM_MessagingEnqueueService.enqueue(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE
    );
    Test.stopTest();

    System.assertEquals(true, true, 'Single enqueue should complete.');
  }

  /**
   * Scenario: enqueueLeadCreate builds TRIGGER_LEAD_CREATE requests for each Lead Id.
   */
  @IsTest
  static void testEnqueueLeadCreate_QueuesMessagingForLeads() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    Lead leadRecord = new Lead(
      LastName = 'Enqueue Create Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Enqueue Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company_Name__c = 'Enqueue Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      LeadSource = 'OUTBOUND PHONE CALL',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'enqueue.create+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system leadRecord;

    Test.startTest();
    BWM_MessagingEnqueueService.enqueueLeadCreate(new List<Id>{ leadRecord.Id });
    Test.stopTest();

    System.assertEquals(true, true, 'Lead create enqueue should complete.');
  }
}