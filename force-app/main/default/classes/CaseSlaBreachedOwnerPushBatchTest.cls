/**
 * @description Test class for Case SLA breached owner push batch.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseSlaBreachedOwnerPushBatchTest {
  @IsTest
  static void testBatchProcessesSlaBreachedCases() {
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'SLA Batch Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Critical',
      OwnerId = UserInfo.getUserId(),
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Case')
        .getRecordTypeId()
    );
    insert as system caseRecord;

    caseRecord = [
      SELECT
        Id,
        CaseNumber,
        Priority,
        OwnerId,
        CreatedDate,
        First_Response__c,
        IsClosed,
        SLA_Breached_Push_Sent__c,
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
    Database.executeBatch(new CaseSlaBreachedOwnerPushBatch(), 1);
    System.schedule(
      'Case SLA Push Test',
      '0 0 * * * ?',
      new CaseSlaBreachedOwnerPushBatch()
    );
    Test.stopTest();

    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
      !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }
}