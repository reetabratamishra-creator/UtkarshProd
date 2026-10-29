/**
 * @description Test class for Case follow-up-due-today push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseFollowUpDueTodayPushBatchTest {
  @IsTest
  static void testBatchProcessesFollowUpDueToday() {
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'Follow Up Batch Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Due_Date_Time__c = System.now()
    );
    insert caseRecord;
    caseRecord.Due_Date_Time__c = System.now();
    update caseRecord;

    caseRecord = [
      SELECT
        Id,
        CaseNumber,
        OwnerId,
        Status,
        IsClosed,
        Due_Date_Time__c,
        Follow_Up_Due_Push_Sent_On__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Test.startTest();
    CasePushNotificationService.processFollowUpDueToday(
      new List<Case>{ caseRecord }
    );
    Database.executeBatch(new CaseFollowUpDueTodayPushBatch(), 50);
    System.schedule(
      'Case Follow Up Push Test',
      '0 0 8 * * ?',
      new CaseFollowUpDueTodayPushBatch()
    );
    Test.stopTest();

    caseRecord = [
      SELECT Follow_Up_Due_Push_Sent_On__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(Date.today(), caseRecord.Follow_Up_Due_Push_Sent_On__c);
  }
}