/**
 * @description Test class for Case 36-hour no-update push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseNoUpdate36hPushBatchTest {
  @IsTest
  static void testBatchProcessesNoUpdateCases() {
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'No Update Push Batch Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId()
    );
    insert caseRecord;
    caseRecord = [
      SELECT Id, CaseNumber, OwnerId, No_Update_36h_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    caseRecord.No_Update_36h_Push_Sent__c = false;

    Test.startTest();
    CasePushNotificationService.processNoUpdate36h(new List<Case>{ caseRecord });
    Database.executeBatch(new CaseNoUpdate36hPushBatch(), 50);
    System.schedule(
      'Case No Update Push Test',
      '0 0 */2 * * ?',
      new CaseNoUpdate36hPushBatch()
    );
    Test.stopTest();

    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
      !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }
}