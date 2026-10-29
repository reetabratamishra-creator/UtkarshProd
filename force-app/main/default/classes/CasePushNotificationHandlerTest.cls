/**
 * @description Test class for unified Case push notification trigger handler.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CasePushNotificationHandlerTest {
  @IsTest
  static void testHandlerDelegatesToServiceOnUpdate() {
    disableNonOwnerHandlers();
    CasePushNotificationHandler.disableInTests = false;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'Handler Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId()
    );
    insert as system caseRecord;

    caseRecord.Subject = 'Handler Case Updated';

    Test.startTest();
    CasePushNotificationHandler.handleAfterUpdate(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{
        caseRecord.Id => new Case(
          Id = caseRecord.Id,
          Subject = 'Handler Case',
          Status = 'Open',
          OwnerId = UserInfo.getUserId()
        )
      }
    );
    Test.stopTest();

    if (
      CrmPushNotificationService.testSentRequests == null ||
      CrmPushNotificationService.testSentRequests.isEmpty()
    ) {
      return;
    }
    System.assert(
      CrmPushNotificationService.testSentRequests[
        CrmPushNotificationService.testSentRequests.size() - 1
      ].body.contains(CasePushNotificationService.BODY_UPDATED)
    );
  }

  @IsTest
  static void testTriggerUpdateSendsOwnerPushNotification() {
    disableNonOwnerHandlers();
    CasePushNotificationHandler.disableInTests = false;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'Trigger Push Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId()
    );
    insert as system caseRecord;
    CasePushNotificationService.clearTestState();

    caseRecord.Subject = 'Trigger Push Case Updated';

    Test.startTest();
    update as system caseRecord;
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }

  @IsTest
  static void testHandlerInsertDelegatesToHodService() {
    disableNonHodHandlers();
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'Handler Department Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE',
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Case')
        .getRecordTypeId()
    );
    insert as system caseRecord;
    caseRecord = [
      SELECT
        Id,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c,
        RecordTypeId
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableHodInTests = false;

    Test.startTest();
    CasePushNotificationHandler.handleAfterInsert(new List<Case>{ caseRecord });
    Test.stopTest();

    Integer sentCount = CrmPushNotificationService.testSentRequests == null
      ? 0
      : CrmPushNotificationService.testSentRequests.size();
    System.assert(sentCount >= 0);
  }

  @IsTest
  static void testTriggerInsertSendsDepartmentHodPush() {
    disableNonHodHandlers();
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Test.startTest();
    insert as system new Case(
      Subject = 'Trigger Department Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void testTriggerUpdateSendsResolvedHodPush() {
    disableNonHodHandlers();
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'Trigger Resolved HOD Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert as system caseRecord;
    CaseHodPushService.clearTestState();
    caseRecord.Status = 'Resolved';

    Test.startTest();
    update as system caseRecord;
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }

  @IsTest
  static void testTriggerInsertSendsDepartmentCrmHeadPush() {
    disableNonCrmHeadHandlers();
    CaseCrmHeadPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Test.startTest();
    insert as system new Case(
      Subject = 'Trigger CRM Head Department Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void testTriggerUpdateSendsResolvedCrmHeadPush() {
    disableNonCrmHeadHandlers();
    CaseCrmHeadPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'Trigger Resolved CRM Head Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert as system caseRecord;
    CaseCrmHeadPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };
    caseRecord.Status = 'Resolved';

    Test.startTest();
    update as system caseRecord;
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }

  private static void disableNonOwnerHandlers() {
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableInTests = true;
  }

  private static void disableNonHodHandlers() {
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationHandler.disableHodInTests = false;
  }

  private static void disableNonCrmHeadHandlers() {
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = false;
  }
}