/**
 * @description   Test class for Opportunity Team Member push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
@IsTest
private class OpportunityTeamMemberPushServiceTest {
  @IsTest
  static void testSendForNewTeamMembersNotifiesOwner() {
    OpportunityTeamMemberPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Team Member Opp');
    OpportunityTeamMember memberRecord = new OpportunityTeamMember(
      OpportunityId = opportunityRecord.Id,
      UserId = UserInfo.getUserId(),
      TeamMemberRole = resolveTeamMemberRole()
    );

    Test.startTest();
    OpportunityTeamMemberPushService.sendForNewTeamMembers(
      new List<OpportunityTeamMember>{ memberRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      opportunityRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assertEquals(
      opportunityRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(opportunityRecord.Name)
    );
  }

  @IsTest
  static void testHandlerAfterInsertNotifiesOwner() {
    OpportunityTeamMemberPushService.clearTestState();

    Opportunity opportunityRecord = createOpportunity('Handler Team Opp');
    OpportunityTeamMember memberRecord = new OpportunityTeamMember(
      OpportunityId = opportunityRecord.Id,
      UserId = UserInfo.getUserId(),
      TeamMemberRole = resolveTeamMemberRole()
    );

    Test.startTest();
    OpportunityTeamMemberPushHandler.handleAfterInsert(
      new List<OpportunityTeamMember>{ memberRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      OpportunityTeamMemberPushService.NOTIF_TYPE,
      CrmPushNotificationService.testSentRequests[0].notificationTypeDevName
    );
  }

  @IsTest
  static void testSendForNewTeamMembersIgnoresBlankList() {
    OpportunityTeamMemberPushService.clearTestState();

    Test.startTest();
    OpportunityTeamMemberPushService.sendForNewTeamMembers(null);
    OpportunityTeamMemberPushService.sendForNewTeamMembers(
      new List<OpportunityTeamMember>()
    );
    Test.stopTest();

    System.assertEquals(
      true,
      CrmPushNotificationService.testSentRequests == null ||
        CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }

  private static Opportunity createOpportunity(String name) {
    Account accountRecord = new Account(Name = name + ' Account');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30)
    );
    insert opportunityRecord;

    return [
      SELECT Id, Name, OwnerId
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
  }

  private static String resolveTeamMemberRole() {
    List<Schema.PicklistEntry> entries = OpportunityTeamMember.TeamMemberRole.getDescribe()
      .getPicklistValues();
    return entries.isEmpty() ? 'Sales Rep' : entries[0].getValue();
  }
}