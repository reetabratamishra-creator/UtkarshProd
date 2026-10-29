/**
 * @description Test class for Case HOD 36-hour no-update push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseHodNoUpdate36hPushBatchTest {
  @IsTest
  static void testBatchProcessesNoUpdateCasesForHod() {
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'HOD No Update Batch Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert caseRecord;
    caseRecord = [
      SELECT
        Id,
        CaseNumber,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c,
        No_Update_36h_HOD_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    caseRecord.No_Update_36h_HOD_Push_Sent__c = false;

    Test.startTest();
    CaseHodPushService.processNoUpdate36h(new List<Case>{ caseRecord });
    Database.executeBatch(new CaseHodNoUpdate36hPushBatch(), 50);
    System.schedule(
      'Case HOD No Update Push Test',
      '0 0 */2 * * ?',
      new CaseHodNoUpdate36hPushBatch()
    );
    Test.stopTest();

    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
      !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }
}