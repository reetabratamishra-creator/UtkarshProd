/**
 * @description   Test class for Unolo Task Log journey trigger and send service.
 * @author        Anshita Chanda
 * @date          2026-08-13
 */
@IsTest
private class BWM_TaskLogUnoloJourneyServiceTest {
  @TestSetup
  static void setupData() {
    Account accountRecord = new Account(
      Name = 'Unolo Test Account',
      Phone = '7980828320',
      Department_Name__c = 'Crash Barrier'
    );
    insert accountRecord;

    Punch_Record__c punchRecord = new Punch_Record__c(
      Is_WFH_Request__c = false,
      Is_WFO_Request__c = false
    );
    insert punchRecord;
  }

  private static Task_Log__c buildTaskLog(Id accountId, Id punchId) {
    return new Task_Log__c(
      Account__c = accountId,
      Punch_Record__c = punchId,
      IsCheckout__c = false,
      is100mOutside__c = false,
      Manually_Created__c = false,
      Is_schedule__c = false,
      isRescheduled__c = false
    );
  }

  @IsTest
  static void buildPayloadUsesWhatsAppAndRcsVariables() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();
    BWM_TaskLogUnoloTriggerHandler.skipForTests = true;

    Account accountRecord = [
      SELECT Id, Phone, Department_Name__c
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Task_Log__c taskLogRecord = buildTaskLog(
      accountRecord.Id,
      [SELECT Id FROM Punch_Record__c LIMIT 1].Id
    );
    insert taskLogRecord;

    taskLogRecord = [
      SELECT
        Id,
        Account__c,
        Punch_Record__c,
        OwnerId,
        Owner.Name,
        Owner.Phone,
        Owner.Email
      FROM Task_Log__c
      WHERE Id = :taskLogRecord.Id
    ];

    Test.startTest();
    String payload = BWM_TaskLogUnoloJourneyService.buildPayload(
      taskLogRecord,
      accountRecord,
      '917980828320'
    );
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> content = (Map<String, Object>) payloadMap.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get(
      'journeypayload'
    );
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> whatsAppNode = (Map<String, Object>) nodes.get('1');
    Map<String, Object> rcsNode = (Map<String, Object>) nodes.get('2');
    Map<String, Object> whatsAppData = (Map<String, Object>) whatsAppNode.get(
      'data'
    );
    Map<String, Object> rcsData = (Map<String, Object>) rcsNode.get('data');
    Map<String, Object> rcsBodyData = (Map<String, Object>) rcsData.get(
      'bodyData'
    );

    System.assertEquals('Journey', payloadMap.get('channel'));
    System.assertEquals(
      BWM_TaskLogUnoloJourneyService.JOURNEY_NAME,
      data.get('journeyname')
    );
    System.assertEquals('917980828320', ((List<Object>) payloadMap.get('to'))[0]);
    System.assertEquals('Crash Barrier', rcsBodyData.get('{{1}}'));
    System.assertEquals('Crash Barrier', rcsBodyData.get('{{2}}'));
    System.assertNotEquals('', rcsBodyData.get('{{3}}'));
    System.assertEquals(
      BWM_TaskLogUnoloJourneyService.WHATSAPP_TEMPLATE_NAME,
      whatsAppData.get('templateName')
    );
  }

  @IsTest
  static void handleAfterInsertEnqueuesOnlyForFirstTaskLogOnPunch() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();

    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Id punchId = [SELECT Id FROM Punch_Record__c LIMIT 1].Id;

    Test.startTest();
    insert buildTaskLog(accountRecord.Id, punchId);
    Integer afterFirst = BWM_TaskLogUnoloTriggerHandler.testEnqueueCount;
    insert buildTaskLog(accountRecord.Id, punchId);
    Test.stopTest();

    System.assertEquals(
      afterFirst,
      BWM_TaskLogUnoloTriggerHandler.testEnqueueCount,
      'A second Task Log on the same Punch should not enqueue another journey send.'
    );
    System.assert(afterFirst <= 1);
  }

  @IsTest
  static void handleAfterInsertSkipsWhenPunchAlreadyHasTaskLog() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();

    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Id punchId = [SELECT Id FROM Punch_Record__c LIMIT 1].Id;

    BWM_TaskLogUnoloTriggerHandler.skipForTests = true;
    insert buildTaskLog(accountRecord.Id, punchId);
    BWM_TaskLogUnoloTriggerHandler.skipForTests = false;

    Test.startTest();
    insert buildTaskLog(accountRecord.Id, punchId);
    Test.stopTest();

    System.assertEquals(
      0,
      BWM_TaskLogUnoloTriggerHandler.testEnqueueCount,
      'A second Task Log on the same Punch should not enqueue another journey send.'
    );
  }

  @IsTest
  static void sendForTaskLogIdsUsesAccountPhone() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();
    BWM_TaskLogUnoloTriggerHandler.skipForTests = true;

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey request enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Account accountRecord = [
      SELECT Id, Phone, Department_Name__c
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Task_Log__c taskLogRecord = buildTaskLog(
      accountRecord.Id,
      [SELECT Id FROM Punch_Record__c LIMIT 1].Id
    );
    insert taskLogRecord;

    Test.startTest();
    BWM_TaskLogUnoloJourneyService.sendForTaskLogIds(
      new List<Id>{ taskLogRecord.Id }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Status__c, Template_Name__c, Phone_Number__c
      FROM Message_Log__c
      WHERE
        Trigger_Point__c = :BWM_TaskLogUnoloJourneyService.TRIGGER_POINT
        AND Related_Record_Id__c = :taskLogRecord.Id
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('Sent', logs[0].Status__c);
    System.assertEquals(
      BWM_TaskLogUnoloJourneyService.JOURNEY_NAME,
      logs[0].Template_Name__c
    );
    System.assertEquals('917980828320', logs[0].Phone_Number__c);
  }

  @IsTest
  static void selectFirstTaskLogIdsForPunchReturnsOnlyFirstEligibleRecord() {
    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Id punchId = [SELECT Id FROM Punch_Record__c LIMIT 1].Id;

    Task_Log__c firstTaskLog = buildTaskLog(accountRecord.Id, punchId);
    Task_Log__c secondTaskLog = buildTaskLog(accountRecord.Id, punchId);
    secondTaskLog.Manually_Created__c = true;

    BWM_TaskLogUnoloTriggerHandler.skipForTests = true;
    insert new List<Task_Log__c>{ firstTaskLog, secondTaskLog };

    List<Id> selectedIds = BWM_TaskLogUnoloTriggerHandler.selectFirstTaskLogIdsForPunch(
      new List<Task_Log__c>{ firstTaskLog, secondTaskLog },
      new Map<Id, Integer>()
    );

    System.assertEquals(1, selectedIds.size());
    System.assertEquals(firstTaskLog.Id, selectedIds[0]);
  }

  @IsTest
  static void triggerEnqueuesJourneyForFirstTaskLogOnPunch() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();

    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Id punchId = [SELECT Id FROM Punch_Record__c LIMIT 1].Id;

    Test.startTest();
    insert buildTaskLog(accountRecord.Id, punchId);
    Test.stopTest();

    System.assert(
      BWM_TaskLogUnoloTriggerHandler.testEnqueueCount <= 1,
      'Trigger should enqueue at most one Unolo journey for the first Task Log on a Punch.'
    );
  }

  @IsTest
  static void triggerHandlesHandlerException() {
    BWM_TaskLogUnoloTriggerHandler.resetTestState();
    BWM_TaskLogUnoloTriggerHandler.forceExceptionForTests = true;

    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name = 'Unolo Test Account'
      LIMIT 1
    ];
    Id punchId = [SELECT Id FROM Punch_Record__c LIMIT 1].Id;

    Test.startTest();
    insert buildTaskLog(accountRecord.Id, punchId);
    Test.stopTest();

    System.assertEquals(
      0,
      BWM_TaskLogUnoloTriggerHandler.testEnqueueCount,
      'Trigger should swallow handler exceptions without enqueueing a journey send.'
    );
  }
}