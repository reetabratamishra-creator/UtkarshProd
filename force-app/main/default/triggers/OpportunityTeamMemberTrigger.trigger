/**
 * @description   Sends push notifications when Opportunity Team Members are added.
 * @author        Anshita Chanda
 * @date          2026-08-20
 */
trigger OpportunityTeamMemberTrigger on OpportunityTeamMember (after insert) {
  if (!TriggerEnableService.isEnabled(TriggerEnableService.OPPORTUNITY_TEAM_MEMBER)) {
    return;
  }

  try {
    if (Trigger.isAfter && Trigger.isInsert) {
      OpportunityTeamMemberPushHandler.handleAfterInsert(Trigger.new);
    }
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'OpportunityTeamMemberTrigger failed: ' + ex.getMessage() +
      '\nStack Trace: ' + ex.getStackTraceString()
    );
  }
}