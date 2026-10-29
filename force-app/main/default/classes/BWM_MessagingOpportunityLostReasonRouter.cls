/**
 * @description   Maps Opportunity lost reason / stage changes to messaging trigger
 *                points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_MessagingOpportunityLostReasonRouter {
  public static String resolveTriggerPoint(String stageName, String lostReason) {
    return resolveTriggerPoint(stageName, null, lostReason);
  }

  public static String resolveTriggerPoint(
    String stageName,
    String priorStageName,
    String lostReason
  ) {
    if (String.isBlank(lostReason)) {
      return null;
    }

    String routingStage = resolveRoutingStage(stageName, priorStageName);
    if (routingStage == BWM_MessagingConstants.STAGE_NURTURE) {
      return resolveNurtureTrigger(lostReason);
    }
    if (routingStage == BWM_MessagingConstants.STAGE_NEGOTIATION) {
      return resolveNegotiationTrigger(lostReason);
    }

    return null;
  }

  private static String resolveNurtureTrigger(String lostReason) {
    if (BWM_MessagingConstants.OPP_LOST_DETAILS_NOT_RECEIVED.contains(lostReason)) {
      return BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE;
    }

    if (
      BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(lostReason)
    ) {
      return BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE;
    }

    return null;
  }

  private static String resolveNegotiationTrigger(String lostReason) {
    if (
      BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(lostReason)
    ) {
      return BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION;
    }

    return null;
  }

  private static String resolveRoutingStage(
    String stageName,
    String priorStageName
  ) {
    if (String.isBlank(stageName)) {
      return null;
    }

    if (
      stageName == BWM_MessagingConstants.STAGE_NURTURE ||
      stageName == BWM_MessagingConstants.STAGE_NEGOTIATION
    ) {
      return stageName;
    }

    if (
      stageName == BWM_MessagingConstants.STAGE_CLOSED_LOST &&
      String.isNotBlank(priorStageName)
    ) {
      if (
        priorStageName == BWM_MessagingConstants.STAGE_NURTURE ||
        priorStageName == BWM_MessagingConstants.STAGE_NEGOTIATION
      ) {
        return priorStageName;
      }
    }

    return null;
  }
}