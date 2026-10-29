/**
 * @description   Test class for the BWM_Bypass_Auto_Messaging custom permission on
 *                BWM_EmailEnqueueService and BWM_MessagingEnqueueService.
 * @author        Anshita Chanda
 * @date          2026-10-19
 */
@IsTest
private class BWM_AutoMessagingBypassTest {
  // Blank record Ids are skipped by both queueables, so queued jobs do no work.
  private static List<BWM_EmailRequest> emailRequests() {
    return new List<BWM_EmailRequest>{
      new BWM_EmailRequest(null, BWM_EmailConstants.TRIGGER_LEAD_CREATE)
    };
  }

  private static List<BWM_MessagingRequest> messagingRequests() {
    return new List<BWM_MessagingRequest>{
      new BWM_MessagingRequest(null, BWM_MessagingConstants.TRIGGER_LEAD_CREATE)
    };
  }

  @IsTest
  static void enqueuesWithoutBypassPermission() {
    Test.startTest();
    BWM_EmailEnqueueService.enqueue(emailRequests());
    BWM_MessagingEnqueueService.enqueue(messagingRequests());
    Integer queuedJobs = Limits.getQueueableJobs();
    Test.stopTest();

    System.assertEquals(2, queuedJobs, 'Email and messaging jobs should be queued.');
  }

  @IsTest
  static void enqueuesLeadCreateAndSingleRequests() {
    List<Id> blankLeadIds = new List<Id>{ null };

    Test.startTest();
    BWM_EmailEnqueueService.enqueueLeadCreate(blankLeadIds);
    BWM_EmailEnqueueService.enqueue(null, BWM_EmailConstants.TRIGGER_LEAD_CREATE);
    BWM_MessagingEnqueueService.enqueueLeadCreate(blankLeadIds);
    BWM_MessagingEnqueueService.enqueue(
      null,
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE
    );
    BWM_EmailEnqueueService.enqueue(new List<BWM_EmailRequest>());
    BWM_MessagingEnqueueService.enqueue(new List<BWM_MessagingRequest>());
    Integer queuedJobs = Limits.getQueueableJobs();
    Test.stopTest();

    System.assertEquals(4, queuedJobs, 'Each non-empty call should queue one job.');
  }

  @IsTest
  static void skipsEnqueueWithBypassPermission() {
    PermissionSet bypassSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'BWM_Bypass_Auto_Messaging'
      LIMIT 1
    ];
    insert as system new PermissionSetAssignment(
      AssigneeId = UserInfo.getUserId(),
      PermissionSetId = bypassSet.Id
    );

    Integer queuedJobs;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      BWM_EmailEnqueueService.enqueue(emailRequests());
      BWM_MessagingEnqueueService.enqueue(messagingRequests());
      queuedJobs = Limits.getQueueableJobs();
      Test.stopTest();
    }

    System.assertEquals(0, queuedJobs, 'No jobs should be queued for a bypass user.');
  }
}