/**
 * @description   Maps Opportunity lost reason to email trigger points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_EmailOpportunityLostReasonRouter {
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
    if (String.isBlank(routingStage)) {
      return null;
    }

    if (routingStage == BWM_EmailConstants.STAGE_NURTURE) {
      return resolveNurtureTrigger(lostReason, stageName, priorStageName);
    }
    if (routingStage == BWM_EmailConstants.STAGE_NEGOTIATION) {
      return resolveNegotiationTrigger(lostReason, stageName, priorStageName);
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
      stageName == BWM_EmailConstants.STAGE_NURTURE ||
      stageName == BWM_EmailConstants.STAGE_NEGOTIATION
    ) {
      return stageName;
    }

    if (
      stageName == BWM_EmailConstants.STAGE_CLOSED_LOST &&
      String.isNotBlank(priorStageName)
    ) {
      if (
        priorStageName == BWM_EmailConstants.STAGE_NURTURE ||
        priorStageName == BWM_EmailConstants.STAGE_NEGOTIATION
      ) {
        return priorStageName;
      }
    }

    return null;
  }

  private static String resolveNurtureTrigger(
    String lostReason,
    String stageName,
    String priorStageName
  ) {
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_NOT_RESPONDING)
    ) {
      if (
        stageName == BWM_EmailConstants.STAGE_CLOSED_LOST &&
        priorStageName == BWM_EmailConstants.STAGE_NURTURE
      ) {
        return BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST;
      }
      return null;
    }
    if (isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_OPERATIONAL)) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_OPERATIONAL_NURTURE;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_DETAILS_NOT_RECEIVED)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_RATE_OR_PURCHASED)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_RATE_OTHER_NURTURE;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_FUTURE_OR_TENDER)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_FUTURE_TENDER_NURTURE;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_PRICE_OR_EXISTING)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_PRICE_NURTURE;
    }
    return null;
  }

  private static String resolveNegotiationTrigger(
    String lostReason,
    String stageName,
    String priorStageName
  ) {
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_NOT_RESPONDING)
    ) {
      if (
        stageName == BWM_EmailConstants.STAGE_CLOSED_LOST &&
        priorStageName == BWM_EmailConstants.STAGE_NEGOTIATION
      ) {
        return BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION_LOST;
      }
      return null;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_RATE_OR_PURCHASED)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_RATE_OTHER_NEGOTIATION;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_FUTURE_OR_TENDER)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_FUTURE_TENDER_NEGOTIATION;
    }
    if (
      isInGroup(lostReason, BWM_EmailConstants.OPP_LOST_GROUP_PRICE_OR_EXISTING)
    ) {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_PRICE_NEGOTIATION;
    }
    if (lostReason == 'Internal Problem' || lostReason == 'Internal problem') {
      return BWM_EmailConstants.TRIGGER_OPP_LOST_OPERATIONAL_NEGOTIATION;
    }
    return null;
  }

  private static Boolean isInGroup(String lostReason, String groupName) {
    Set<String> allowed = BWM_EmailConstants.OPP_LOST_REASONS_BY_GROUP.get(
      groupName
    );
    return allowed != null && allowed.contains(lostReason);
  }
}