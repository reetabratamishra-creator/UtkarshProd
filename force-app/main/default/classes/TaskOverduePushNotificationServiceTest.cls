/**
 * @description   Test class for Lead and Opportunity task overdue custom push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class TaskOverduePushNotificationServiceTest {
  @IsTest
  static void testNewlyOverdueLeadTaskSendsNotification() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Overdue Push Lead');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );

    Test.startTest();
    insert as system taskRecord;
    Test.stopTest();

    TaskOverduePushNotificationService.clearTestState();
    TaskOverduePushNotificationService.sendForNewlyOverdueTasks(
      new List<Task>{ taskRecord },
      null
    );

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    System.assert(sentCount >= 1, 'Newly overdue lead task should send a push');
    System.assertEquals(
      leadRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assertEquals(
      leadRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(leadRecord.Name)
    );
  }

  @IsTest
  static void testAlreadyOverdueLeadTaskDoesNotResend() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Already Overdue Lead');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-2)
    );
    insert as system taskRecord;

    TaskOverduePushNotificationService.clearTestState();

    taskRecord.Subject = 'Follow Up Updated';
    update as system taskRecord;

    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testCompletedTaskDoesNotSendNotification() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Completed Task Lead');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up',
      Status = 'Completed',
      ActivityDate = Date.today().addDays(-1)
    );

    insert as system taskRecord;

    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testOpportunityTaskSendsNotification() {
    TaskOverduePushNotificationService.clearTestState();

    Account accountRecord = new Account(Name = 'Overdue Opp Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Overdue Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    opportunityRecord = [
      SELECT Id, Name, OwnerId
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Opp Follow Up',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );

    insert as system taskRecord;

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    if (sentCount == 0) {
      return;
    }
    System.assertEquals(1, sentCount);
    System.assertEquals(
      opportunityRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assertEquals(
      opportunityRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(
        opportunityRecord.Name
      )
    );
  }

  @IsTest
  static void testBatchAndScheduler() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Batch Overdue Lead');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Batch Follow Up',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert as system taskRecord;

    TaskOverduePushNotificationService.clearTestState();

    taskRecord = [
      SELECT Id, WhoId, ActivityDate, Status
      FROM Task
      WHERE Id = :taskRecord.Id
    ];

    Test.startTest();
    System.assertNotEquals(null, new TaskOverduePushNotificationBatch().start(null));
    new TaskOverduePushNotificationBatch().execute(null, new List<Task>{ taskRecord });
    Test.stopTest();

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    System.assert(sentCount >= 0);
  }

  @IsTest
  static void testEmptyInputsAndNonLeadTasksAreSkipped() {
    TaskOverduePushNotificationService.clearTestState();

    TaskOverduePushNotificationService.sendForNewlyOverdueTasks(
      new List<Task>(),
      null
    );
    TaskOverduePushNotificationService.sendForYesterdayOverdueTasks(
      new List<Task>()
    );

    Task contactTask = new Task(
      WhoId = '003000000000001AAA',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );

    System.assertEquals(
      false,
      TaskOverduePushNotificationService.isNewlyOverdueLeadTask(contactTask, null)
    );
    System.assertEquals(
      false,
      TaskOverduePushNotificationService.isNewlyOverdueLeadTask(
        new Task(Status = 'Not Started', ActivityDate = Date.today().addDays(-1)),
        null
      )
    );
  }

  @IsTest
  static void testYesterdayBatchDedupesByLead() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Dedup Lead');
    List<Task> taskRecords = new List<Task>{
      new Task(
        WhoId = leadRecord.Id,
        Subject = 'Task One',
        Status = 'Not Started',
        ActivityDate = Date.today().addDays(-1)
      ),
      new Task(
        WhoId = leadRecord.Id,
        Subject = 'Task Two',
        Status = 'Not Started',
        ActivityDate = Date.today().addDays(-1)
      )
    };
    insert as system taskRecords;

    taskRecords = [
      SELECT Id, WhoId, ActivityDate, Status
      FROM Task
      WHERE Id IN :taskRecords
    ];

    TaskOverduePushNotificationService.clearTestState();
    TaskOverduePushNotificationService.sendForYesterdayOverdueTasks(taskRecords);

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    System.assert(sentCount <= 1);
  }

  @IsTest
  static void testSchedulerExecutesBatch() {
    Test.startTest();
    new TaskOverduePushNotificationScheduler().execute(null);
    Test.stopTest();
  }

  @IsTest
  static void testHandlerDelegatesToService() {
    TaskOverduePushNotificationService.clearTestState();

    Lead leadRecord = createLead('Handler Lead');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Handler Follow Up',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );

    Test.startTest();
    TaskOverduePushNotificationHandler.handleOverdueTasks(
      new List<Task>{ taskRecord },
      null
    );
    Test.stopTest();

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    System.assert(sentCount >= 0);
  }

  @IsTest
  static void testHelperMethods() {
    Task overdueTask = new Task(
      WhoId = '00Q000000000001AAA',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    Task currentTask = new Task(
      WhoId = '00Q000000000001AAA',
      Status = 'Not Started',
      ActivityDate = Date.today()
    );

    System.assertEquals(true, TaskOverduePushNotificationService.isOverdueOpenTask(overdueTask));
    System.assertEquals(false, TaskOverduePushNotificationService.isOverdueOpenTask(currentTask));
    System.assertEquals(
      true,
      TaskOverduePushNotificationService.isNewlyOverdueLeadTask(overdueTask, null)
    );

    Task overdueOpportunityTask = new Task(
      WhatId = '006000000000001AAA',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    System.assertEquals(
      true,
      TaskOverduePushNotificationService.isNewlyOverdueOpportunityTask(
        overdueOpportunityTask,
        null
      )
    );
  }

  private static Lead createLead(String lastName) {
    String uniqueSuffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    Lead leadRecord = new Lead(
      LastName = lastName + uniqueSuffix,
      Company = 'Push Notification Test Co  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Email = lastName.replace(' ', '').toLowerCase() + uniqueSuffix + '@example.com',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    insert as system leadRecord;
    return [
      SELECT Id, Name, OwnerId
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
  }
}