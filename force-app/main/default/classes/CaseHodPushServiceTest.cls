/**
 * @description Test class for Case HOD push notifications.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseHodPushServiceTest {
  @IsTest
  static void testInsertWithDepartmentSendsPushToHod() {
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'Department Assignment Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Medium',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert as system caseRecord;
    caseRecord = [
      SELECT Id, Department__c, Department_formula__c, HOD_User_Email_Formula__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Test.startTest();
    CaseHodPushService.sendForNewDepartmentAssignments(
      new List<Case>{ caseRecord },
      null
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      CaseHodPushService.BODY_DEPT_ASSIGNMENT,
      CrmPushNotificationService.testSentRequests[0].body
    );
    System.assertEquals(
      CaseHodPushService.NOTIF_TYPE_DEPT_ASSIGNMENT,
      CrmPushNotificationService.testSentRequests[0].notificationTypeDevName
    );
  }

  @IsTest
  static void testDepartmentChangeSendsPushToHod() {
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'Department Change Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert as system caseRecord;

    Case oldCase = caseRecord.clone(true, true, true, true);
    caseRecord.Department__c = 'Steel Pipes';

    Test.startTest();
    CaseHodPushService.sendForNewDepartmentAssignments(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => oldCase }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
  }

  @IsTest
  static void testNoDepartmentDoesNotSendPush() {
    CaseHodPushService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'No Department Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId()
    );

    CaseHodPushService.sendForNewDepartmentAssignments(
      new List<Case>{ caseRecord },
      null
    );

    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testResolvedAndReopenedSendToHod() {
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case resolvedCase = createCase('Resolved HOD Case', 'HDPE');
    Case resolvedOld = resolvedCase.clone(true, true, true, true);
    resolvedCase.Status = 'Resolved';

    Case reopenedCase = createCase('Reopened HOD Case', 'HDPE');
    reopenedCase.Status = 'Resolved';
    update as system reopenedCase;
    Case reopenedOld = [
      SELECT Id, Status, IsClosed
      FROM Case
      WHERE Id = :reopenedCase.Id
    ];
    reopenedCase.Status = 'Open';
    update as system reopenedCase;
    reopenedCase = [
      SELECT Id, Status, IsClosed
      FROM Case
      WHERE Id = :reopenedCase.Id
    ];

    Test.startTest();
    CaseHodPushService.sendForUpdatedCases(
      new List<Case>{ resolvedCase },
      new Map<Id, Case>{ resolvedCase.Id => resolvedOld }
    );
    CaseHodPushService.sendForUpdatedCases(
      new List<Case>{ reopenedCase },
      new Map<Id, Case>{ reopenedCase.Id => reopenedOld }
    );
    Test.stopTest();

    System.assertEquals(2, CrmPushNotificationService.testSentRequests.size());
    System.assert(containsBody('has been resolved successfully'));
    System.assert(containsBody('has been reopened by the customer'));
  }

  @IsTest
  static void testProcessSlaBreachedByPriority() {
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = createCase('Critical SLA HOD Case', 'HDPE');
    caseRecord.Priority = 'Critical';
    update as system caseRecord;

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
    Test.stopTest();

    caseRecord = [
      SELECT SLA_Breached_HOD_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(true, caseRecord.SLA_Breached_HOD_Push_Sent__c);
    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains('Critical Case:')
    );
  }

  @IsTest
  static void testProcessNoUpdate36hForHod() {
    CaseHodPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = createCase('No Update HOD Case', 'HDPE');
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
    Test.stopTest();

    caseRecord = [
      SELECT No_Update_36h_HOD_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(true, caseRecord.No_Update_36h_HOD_Push_Sent__c);
    System.assertEquals(
      CaseHodPushService.BODY_NO_UPDATE,
      CrmPushNotificationService.testSentRequests[0].body
    );
  }

  @IsTest
  static void testHelperMethods() {
    System.assertEquals(
      'Critical Priority Case: SLA Breached',
      CaseHodPushService.resolveSlaBreachedTitle('Critical')
    );

    Case caseRecord = createCase('Helper SLA Body Case', 'HDPE');
    caseRecord.Priority = 'High';
    update as system caseRecord;
    caseRecord = [SELECT CaseNumber, Priority FROM Case WHERE Id = :caseRecord.Id];
    System.assertEquals(
      true,
      CaseHodPushService.resolveSlaBreachedBody(caseRecord).contains('High Priority: #' + caseRecord.CaseNumber)
    );

    System.assertEquals(
      true,
      CaseHodPushService.hasDepartment(new Case(Department__c = 'HDPE'))
    );
    System.assertEquals(
      false,
      CaseHodPushService.hasDepartment(new Case())
    );

    Case newCase = new Case(Department__c = 'HDPE');
    System.assertEquals(
      true,
      CaseHodPushService.isNewDepartmentAssignment(newCase, null)
    );
    System.assertEquals(
      false,
      CaseHodPushService.isNewDepartmentAssignment(
        new Case(Department__c = 'HDPE'),
        new Case(Department__c = 'HDPE')
      )
    );
    System.assertEquals(
      'HDPE',
      CaseHodPushService.resolveDepartmentKey(new Case(Department__c = 'HDPE'))
    );
  }

  private static Boolean containsBody(String fragment) {
    for (CrmPushNotificationService.NotificationSendRequest request : CrmPushNotificationService.testSentRequests) {
      if (request.body.contains(fragment)) {
        return true;
      }
    }
    return false;
  }

  private static Case createCase(String subject, String department) {
    Case caseRecord = new Case(
      Subject = subject,
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Medium',
      OwnerId = UserInfo.getUserId(),
      Department__c = department
    );
    insert as system caseRecord;
    return [
      SELECT
        Id,
        CaseNumber,
        Status,
        IsClosed,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
  }
}