/**
 * @description   Trigger handler for Opportunity Closed Won custom push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class OpportunityWonPushNotificationHandler {
  /**
   * @description Sends push notifications when an Opportunity is marked Closed Won.
   */
  public static void handleAfterUpdate(
    List<Opportunity> newOpportunities,
    Map<Id, Opportunity> oldMap
  ) {
    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      newOpportunities,
      oldMap
    );
  }
}