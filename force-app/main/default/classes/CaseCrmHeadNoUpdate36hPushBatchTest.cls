/**
 * @description Test class for Case CRM Head 36-hour no-update push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseCrmHeadNoUpdate36hPushBatchTest {
  @IsTest
  static void testBatchProcessesNoUpdateCasesForCrmHead() {
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CaseCrmHeadPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'CRM Head No Update Batch Case',
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
        CRM_User_Email_Formula__c,
        No_Update_36h_CRM_Head_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    caseRecord.No_Update_36h_CRM_Head_Push_Sent__c = false;

    Test.startTest();
    CaseCrmHeadPushService.processNoUpdate36h(new List<Case>{ caseRecord });
    Database.executeBatch(new CaseCrmHeadNoUpdate36hPushBatch(), 50);
    System.schedule(
      'Case CRM Head No Update Push Test',
      '0 0 */2 * * ?',
      new CaseCrmHeadNoUpdate36hPushBatch()
    );
    Test.stopTest();

    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
      !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }
}