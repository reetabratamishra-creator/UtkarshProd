/**
 * @description Test class for Case custom push notifications.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
@IsTest
private class CasePushNotificationServiceTest {
  @IsTest
  static void testUpdatedCaseSendsPushToOwner() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case caseRecord = createCase('Updated Case', UserInfo.getUserId());
    Case oldCase = caseRecord.clone(true, true, true, true);
    caseRecord.Subject = 'Updated Subject';

    Test.startTest();
    CasePushNotificationService.sendForUpdatedCases(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => oldCase }
    );
    Test.stopTest();

    assertSingleRequest(
      CasePushNotificationService.BODY_UPDATED,
      CasePushNotificationService.NOTIF_TYPE_EMPLOYEE
    );
  }

  @IsTest
  static void testReassignedCaseUsesOwnerChangeNotificationType() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    User newOwner = createUser('push01');
    Case caseRecord = createCase('Reassigned Case', UserInfo.getUserId());
    Case oldCase = caseRecord.clone(true, true, true, true);
    caseRecord.OwnerId = newOwner.Id;

    Test.startTest();
    CasePushNotificationService.sendForUpdatedCases(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => oldCase }
    );
    Test.stopTest();

    assertSingleRequest(
      CasePushNotificationService.BODY_REASSIGNED,
      CasePushNotificationService.NOTIF_TYPE_OWNER_CHANGE
    );
  }

  @IsTest
  static void testResolvedAndReopenedNotifications() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case resolvedCase = createCase('Resolved Case', UserInfo.getUserId());
    Case resolvedOld = resolvedCase.clone(true, true, true, true);
    resolvedCase.Status = 'Resolved';

    Case reopenedCase = createCase('Reopened Case', UserInfo.getUserId());
    reopenedCase.Status = 'Resolved';
    update as system reopenedCase;
    Case reopenedOld = [
      SELECT Id, CaseNumber, Status, IsClosed, OwnerId
      FROM Case
      WHERE Id = :reopenedCase.Id
    ];
    reopenedCase.Status = 'Open';
    update as system reopenedCase;
    reopenedCase = [
      SELECT Id, CaseNumber, Status, IsClosed, OwnerId
      FROM Case
      WHERE Id = :reopenedCase.Id
    ];

    Test.startTest();
    CasePushNotificationService.sendForUpdatedCases(
      new List<Case>{ resolvedCase },
      new Map<Id, Case>{ resolvedCase.Id => resolvedOld }
    );
    CasePushNotificationService.sendForUpdatedCases(
      new List<Case>{ reopenedCase },
      new Map<Id, Case>{ reopenedCase.Id => reopenedOld }
    );
    Test.stopTest();

    System.assertEquals(2, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      containsBody('has been resolved successfully')
    );
    System.assert(
      containsBody('has been reopened')
    );
  }

  @IsTest
  static void testIgnoredFieldUpdateDoesNotSendPush() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case caseRecord = createCase('Ignored Field Case', UserInfo.getUserId());
    Case oldCase = caseRecord.clone(true, true, true, true);
    caseRecord.Response_Esc_Owner_Sent__c = true;

    CasePushNotificationService.sendForUpdatedCases(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => oldCase }
    );

    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testProcessFollowUpDueToday() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'Follow Up Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Low',
      OwnerId = UserInfo.getUserId(),
      Due_Date_Time__c = System.now()
    );
    insert as system caseRecord;
    caseRecord.Due_Date_Time__c = System.now();
    update as system caseRecord;

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
    String caseNumber = caseRecord.CaseNumber;

    Test.startTest();
    CasePushNotificationService.processFollowUpDueToday(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    caseRecord = [
      SELECT Follow_Up_Due_Push_Sent_On__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    System.assertEquals(Date.today(), caseRecord.Follow_Up_Due_Push_Sent_On__c);
    assertSingleRequest(
      'Reminder: Follow-up is due today for Case #' + caseNumber,
      CasePushNotificationService.NOTIF_TYPE_EMPLOYEE
    );
  }

  @IsTest
  static void testProcessSlaBreached() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case caseRecord = new Case(
      Subject = 'SLA Case',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Critical',
      OwnerId = UserInfo.getUserId()
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
    CasePushNotificationService.processSlaBreached(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    caseRecord = [
      SELECT SLA_Breached_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    System.assertEquals(true, caseRecord.SLA_Breached_Push_Sent__c);
    assertSingleRequest(
      'has exceeded the SLA',
      CasePushNotificationService.NOTIF_TYPE_EMPLOYEE
    );
  }

  @IsTest
  static void testProcessNoUpdate36h() {
    disableTriggerHandler();
    CasePushNotificationService.clearTestState();

    Case caseRecord = createCase('No Update Case', UserInfo.getUserId());
    caseRecord = [
      SELECT Id, CaseNumber, OwnerId, No_Update_36h_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
    caseRecord.No_Update_36h_Push_Sent__c = false;

    Test.startTest();
    CasePushNotificationService.processNoUpdate36h(
      new List<Case>{ caseRecord }
    );
    Test.stopTest();

    caseRecord = [
      SELECT No_Update_36h_Push_Sent__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    System.assertEquals(true, caseRecord.No_Update_36h_Push_Sent__c);
    assertSingleRequest(
      CasePushNotificationService.BODY_NO_UPDATE,
      CasePushNotificationService.NOTIF_TYPE_EMPLOYEE
    );
  }

  @IsTest
  static void testHelperMethods() {
    Case caseRecord = new Case(
      Status = 'Resolved',
      OwnerId = UserInfo.getUserId()
    );
    Case oldCase = new Case(Status = 'Open');

    System.assertEquals(true, CasePushNotificationService.isNewlyResolved(caseRecord, oldCase));
    System.assertEquals(
      true,
      CasePushNotificationService.isNewlyReopened(
        new Case(Status = 'Open'),
        new Case(Status = 'Resolved')
      )
    );
    System.assertEquals(
      true,
      CasePushNotificationService.hasMeaningfulUpdate(
        new Case(Subject = 'Changed'),
        new Case(Subject = 'Original')
      )
    );
    System.assertEquals(
      'Case 00001001 has been resolved successfully.',
      CasePushNotificationService.formatBody(
        'Case #Case Number has been resolved successfully.',
        '00001001'
      )
    );
    System.assertEquals(true, CasePushNotificationService.isUserOwner(UserInfo.getUserId()));
    System.assertEquals(
      false,
      CasePushNotificationService.isFollowUpDueToday(
        new Case(Due_Date_Time__c = null),
        Date.today()
      )
    );
  }

  private static void disableTriggerHandler() {
    CasePushNotificationHandler.disableInTests = true;
  }

  private static void assertSingleRequest(String bodyFragment, String notificationType) {
    System.assertNotEquals(null, CrmPushNotificationService.testSentRequests);
    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(bodyFragment)
    );
    System.assertEquals(
      notificationType,
      CrmPushNotificationService.testSentRequests[0].notificationTypeDevName
    );
  }

  private static Boolean containsBody(String bodyFragment) {
    for (CrmPushNotificationService.NotificationSendRequest request : CrmPushNotificationService.testSentRequests) {
      if (request.body.contains(bodyFragment)) {
        return true;
      }
    }
    return false;
  }

  private static Case createCase(String subject, Id ownerId) {
    Case caseRecord = new Case(
      Subject = subject,
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Medium',
      OwnerId = ownerId
    );
    insert as system caseRecord;
    return [
      SELECT Id, CaseNumber, Subject, Status, IsClosed, OwnerId
      FROM Case
      WHERE Id = :caseRecord.Id
    ];
  }

  private static User createUser(String aliasSuffix) {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name LIKE 'Standard User%'
      LIMIT 1
    ];
    User userRecord = new User(
      Alias = ('p' + aliasSuffix).left(8),
      Email = 'casepush' +
        String.valueOf(Math.abs(Crypto.getRandomInteger())) +
        aliasSuffix +
        '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'CasePush' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + aliasSuffix,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileRecord.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'casepush' + aliasSuffix + '@example.com.utkarshuat'
    );
    insert as system userRecord;
    return userRecord;
  }
}