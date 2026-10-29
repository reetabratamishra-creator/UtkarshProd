/**
 * @description   Trigger handler for Opportunity Team Member push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
public without sharing class OpportunityTeamMemberPushHandler {
  /**
   * @description Sends push notifications when Opportunity Team Members are inserted.
   */
  public static void handleAfterInsert(List<OpportunityTeamMember> newMembers) {
    OpportunityTeamMemberPushService.sendForNewTeamMembers(newMembers);
  }
}