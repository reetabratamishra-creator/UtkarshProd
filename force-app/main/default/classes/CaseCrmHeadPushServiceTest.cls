/**
 * @description Test class for Case CRM Head push notifications.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CaseCrmHeadPushServiceTest {
  @IsTest
  static void testInsertWithDepartmentSendsPushToCrmHead() {
    CaseCrmHeadPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(
      Subject = 'CRM Head Department Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Medium',
      OwnerId = UserInfo.getUserId(),
      Department__c = 'HDPE'
    );
    insert as system caseRecord;
    caseRecord = [
      SELECT Id, Department__c, Department_formula__c, CRM_User_Email_Formula__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Test.startTest();
    CaseCrmHeadPushService.sendForNewDepartmentAssignments(
      new List<Case>{ caseRecord },
      null
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      CaseCrmHeadPushService.BODY_DEPT_ASSIGNMENT,
      CrmPushNotificationService.testSentRequests[0].body
    );
  }

  @IsTest
  static void testResolvedAndReopenedSendToCrmHead() {
    CaseCrmHeadPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case resolvedCase = createCase('Resolved CRM Head Case', 'HDPE');
    Case resolvedOld = resolvedCase.clone(true, true, true, true);
    resolvedCase.Status = 'Resolved';

    Case reopenedCase = createCase('Reopened CRM Head Case', 'HDPE');
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
    CaseCrmHeadPushService.sendForUpdatedCases(
      new List<Case>{ resolvedCase },
      new Map<Id, Case>{ resolvedCase.Id => resolvedOld }
    );
    CaseCrmHeadPushService.sendForUpdatedCases(
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
    CaseCrmHeadPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = createCase('Critical SLA CRM Head Case', 'HDPE');
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
        CRM_User_Email_Formula__c,
        SLA_Breached_CRM_Head_Push_Sent__c,
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
    CaseCrmHeadPushService.processSlaBreached(new List<Case>{ caseRecord });
    Test.stopTest();

    caseRecord = [
      SELECT SLA_Breached_CRM_Head_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(true, caseRecord.SLA_Breached_CRM_Head_Push_Sent__c);
    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains('Critical Case:')
    );
  }

  @IsTest
  static void testProcessNoUpdate36hForCrmHead() {
    CaseCrmHeadPushService.clearTestState();
    CasePushNotificationHandler.disableCrmHeadInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableInTests = true;
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = createCase('No Update CRM Head Case', 'HDPE');
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
    Test.stopTest();

    caseRecord = [
      SELECT No_Update_36h_CRM_Head_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    System.assertEquals(true, caseRecord.No_Update_36h_CRM_Head_Push_Sent__c);
    System.assertEquals(
      CaseCrmHeadPushService.BODY_NO_UPDATE,
      CrmPushNotificationService.testSentRequests[0].body
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
        CRM_User_Email_Formula__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
  }
}