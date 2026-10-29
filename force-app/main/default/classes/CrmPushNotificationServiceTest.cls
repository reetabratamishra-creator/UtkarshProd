/**
 * @description   Test class for shared custom push notification helper.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class CrmPushNotificationServiceTest {
  @IsTest
  static void testSendRecordsRequestInTestContext() {
    CrmPushNotificationService.clearTestState();

    Id recipientId = UserInfo.getUserId();
    Id targetId = UserInfo.getUserId();

    Test.startTest();
    Boolean sent = CrmPushNotificationService.send(
      recipientId,
      targetId,
      'Test Title',
      'Test Body',
      'Lead_Owner_Notification'
    );
    Test.stopTest();

    System.assertEquals(true, sent);
    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      'Lead_Owner_Notification',
      CrmPushNotificationService.testSentRequests[0].notificationTypeDevName
    );
  }

  @IsTest
  static void testSendSkipsInvalidInputs() {
    CrmPushNotificationService.clearTestState();

    System.assertEquals(
      false,
      CrmPushNotificationService.send(null, UserInfo.getUserId(), 'Title', 'Body', 'Lead_Owner_Notification')
    );
    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testSimulatedProductionSendUsesNotificationTypeLookup() {
    CrmPushNotificationService.clearTestState();
    CrmPushNotificationService.simulateProductionSend = true;

    Test.startTest();
    Boolean sent = CrmPushNotificationService.send(
      UserInfo.getUserId(),
      UserInfo.getUserId(),
      'Production Path Title',
      'Production Path Body',
      'Non_Existent_Notification_Type_XYZ'
    );
    Test.stopTest();

    System.assertEquals(false, sent);
  }

  @IsTest
  static void testSendToUsersRecordsEachRecipient() {
    CrmPushNotificationService.clearTestState();

    Test.startTest();
    Integer sentCount = CrmPushNotificationService.sendToUsers(
      new Set<Id>{ UserInfo.getUserId(), UserInfo.getUserId() },
      UserInfo.getUserId(),
      'Multi Title',
      'Multi Body',
      'Lead_Owner_Notification'
    );
    Test.stopTest();

    System.assertEquals(1, sentCount);
    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
  }

  @IsTest
  static void testSimulatedProductionSendExecutesNotificationSendPath() {
    CrmPushNotificationService.clearTestState();
    CrmPushNotificationService.simulateProductionSend = true;
    CrmPushNotificationService.testNotificationTypeIds = new Map<String, Id>{
      'Lead_Owner_Notification' => UserInfo.getUserId()
    };

    Test.startTest();
    CrmPushNotificationService.send(
      UserInfo.getUserId(),
      UserInfo.getUserId(),
      'Send Path Title',
      'Send Path Body',
      'Lead_Owner_Notification'
    );
    Test.stopTest();
  }
}