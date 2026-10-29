/**
 * @description   Sends push notifications when users are added to Opportunity Teams.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityTeamMemberPushService {
  public static final String NOTIF_TYPE = 'Opportunity_Team_Member_Push_Notification';
  public static final String NOTIFICATION_TITLE = 'Opportunity Team Member';

  /**
   * @description Sends push notifications to the Opportunity Owner when team members are added.
   */
  public static void sendForNewTeamMembers(List<OpportunityTeamMember> newMembers) {
    if (newMembers == null || newMembers.isEmpty()) {
      return;
    }

    Set<Id> opportunityIds = new Set<Id>();
    for (OpportunityTeamMember memberRecord : newMembers) {
      if (memberRecord.OpportunityId != null) {
        opportunityIds.add(memberRecord.OpportunityId);
      }
    }

    if (opportunityIds.isEmpty()) {
      return;
    }

    Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>(
      [
        SELECT Id, Name, OwnerId
        FROM Opportunity
        WHERE Id IN :opportunityIds
      ]
    );

    for (OpportunityTeamMember memberRecord : newMembers) {
      Opportunity opportunityRecord = opportunitiesById.get(memberRecord.OpportunityId);
      if (opportunityRecord == null || opportunityRecord.OwnerId == null) {
        continue;
      }

      String body =
        'You have been added to the below opportunity. Click below ' +
        opportunityRecord.Name;

      CrmPushNotificationService.send(
        opportunityRecord.OwnerId,
        opportunityRecord.Id,
        NOTIFICATION_TITLE,
        body,
        NOTIF_TYPE
      );
    }
  }

  @TestVisible
  static void clearTestState() {
    CrmPushNotificationService.clearTestState();
  }
}