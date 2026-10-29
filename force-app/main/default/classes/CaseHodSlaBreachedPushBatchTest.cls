/**
 * @description Test class for Case HOD SLA breached push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseHodSlaBreachedPushBatchTest {
  @IsTest
  static void testBatchProcessesSlaBreachedCasesForHod() {
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'HOD SLA Batch Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'High',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert caseRecord;

    caseRecord = [
      SELECT
        Id,
        CaseNumber,
        Priority,
        CreatedDate,
        First_Response__c,
        IsClosed,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c,
        SLA_Breached_HOD_Push_Sent__c,
        SLA_Due_Date_Time_RO__c,
        Escalation_Date_1__c,
        Escalation_Date_2__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Datetime ownerDue = caseRecord.SLA_Due_Date_Time_RO__c != null
      ? caseRecord.SLA_Due_Date_Time_RO__c
      : caseRecord.CreatedDate.addHours(24);
    CaseSLAEscalationEmailService.testNowOverride = ownerDue.addHours(1);

    Test.startTest();
    CaseHodPushService.processSlaBreached(new List<Case>{ caseRecord });
    Database.executeBatch(new CaseHodSlaBreachedPushBatch(), 1);
    System.schedule(
      'Case HOD SLA Push Test',
      '0 0 * * * ?',
      new CaseHodSlaBreachedPushBatch()
    );
    Test.stopTest();

    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
      !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }
}