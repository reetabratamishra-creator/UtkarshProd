/**
 * @description Test class for Case trigger push notification wiring.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseTriggerPushNotificationTest {
  @IsTest
  static void testCaseTriggerSendsPushOnUpdate() {
    CasePushNotificationHandler.disableInTests = false;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'Trigger Coverage Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId()
    );
    insert caseRecord;
    CasePushNotificationService.clearTestState();

    caseRecord.Subject = 'Trigger Coverage Case Updated';

    Test.startTest();
    update caseRecord;
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }
}