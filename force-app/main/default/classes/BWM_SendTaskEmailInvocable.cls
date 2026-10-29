public without sharing class BWM_SendTaskEmailInvocable {
  public class Request {
    @InvocableVariable(label='Record Id' required=true)
    public Id recordId;

    @InvocableVariable(
      label='Task Action'
      description='Callback or Lost'
      required=true
    )
    public String taskAction;

    @InvocableVariable(
      label='Stage At Action'
      description='Prospect or Prospecting'
    )
    public String stageAtAction;

    @InvocableVariable(label='Lost Reason')
    public String lostReason;
  }

  public class Response {
    @InvocableVariable
    public Boolean queued;

    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Send Infobip Task Email'
    description='Routes Lead Task Callback/Lost flows to the correct Infobip email trigger point.'
    category='BWM Email'
  )
  public static List<Response> sendTaskEmail(List<Request> requests) {
    List<Response> responses = new List<Response>();
    List<BWM_EmailRequest> queueRequests = new List<BWM_EmailRequest>();

    for (Request requestItem : requests) {
      Response responseItem = new Response();
      String triggerPoint = resolveTriggerPoint(requestItem);

      if (String.isBlank(triggerPoint)) {
        responseItem.queued = false;
        responseItem.message = 'No email trigger matched this task action.';
      } else {
        queueRequests.add(
          new BWM_EmailRequest(
            requestItem.recordId,
            triggerPoint,
            requestItem.stageAtAction
          )
        );
        responseItem.queued = true;
        responseItem.message = triggerPoint;
      }
      responses.add(responseItem);
    }

    if (!queueRequests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(queueRequests);
    }

    return responses;
  }

  private static String resolveTriggerPoint(Request requestItem) {
    if (requestItem == null || requestItem.recordId == null) {
      return null;
    }

    String objectName = requestItem.recordId.getSObjectType().getDescribe().getName();
    String action = requestItem.taskAction == null
      ? ''
      : requestItem.taskAction.trim().toLowerCase();
    String stage = requestItem.stageAtAction == null
      ? ''
      : requestItem.stageAtAction.trim();

    if (objectName == BWM_EmailConstants.OBJECT_OPPORTUNITY) {
      if (action == 'callback') {
        return resolveOpportunityCallbackTrigger(stage, requestItem.recordId);
      }
      return null;
    }

    if (objectName != BWM_EmailConstants.OBJECT_LEAD) {
      return null;
    }

    if (action == 'callback') {
      return resolveCallbackTrigger(
        normalizeStageAtAction(stage, requestItem.recordId)
      );
    }
    if (action == 'lost') {
      return resolveLostTrigger(
        resolveLeadStageForLost(requestItem),
        requestItem.lostReason
      );
    }
    return null;
  }

  private static String resolveCallbackTrigger(String stage) {
    if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
      return BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT;
    }
    if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
      return BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING;
    }
    return null;
  }

  private static String resolveOpportunityCallbackTrigger(String stage, Id recordId) {
    String resolvedStage = resolveOpportunityStage(stage, recordId);
    if (resolvedStage == BWM_EmailConstants.STAGE_NEGOTIATION) {
      return BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NEGOTIATION;
    }
    if (resolvedStage == BWM_EmailConstants.STAGE_NURTURE) {
      return BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NURTURE;
    }
    return null;
  }

  private static String resolveOpportunityStage(String stage, Id recordId) {
    if (String.isNotBlank(stage)) {
      return stage.trim();
    }

    if (recordId == null) {
      return stage;
    }

    List<Opportunity> opportunities = [
      SELECT StageName
      FROM Opportunity
      WHERE Id = :recordId
      LIMIT 1
    ];
    return opportunities.isEmpty() ? stage : opportunities[0].StageName;
  }

  private static String resolveLostTrigger(String stage, String lostReason) {
    if (String.isBlank(stage) || String.isBlank(lostReason)) {
      return null;
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_NOT_RESPONDING)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING;
      }
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_DETAILS_NOT_RECEIVED)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT;
      }
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING;
      }
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_OPERATIONAL)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_OPERATIONAL_PROSPECT;
      }
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_OPERATIONAL_PROSPECTING;
      }
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_PURCHASED_OTHER_BRAND)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_PURCHASED_PROSPECT;
      }
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_PURCHASED_PROSPECTING;
      }
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_FUTURE_PROSPECT)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECT;
      }
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECTING;
      }
    }

    if (isInGroup(lostReason, BWM_EmailConstants.LOST_GROUP_PRICE_OR_EXISTING)) {
      if (stage == BWM_EmailConstants.STAGE_PROSPECT) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_PRICE_PROSPECT;
      }
      if (stage == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_PRICE_PROSPECTING;
      }
    }

    return null;
  }

  private static Boolean isInGroup(String lostReason, String groupName) {
    Set<String> allowed = BWM_EmailConstants.LOST_REASONS_BY_GROUP.get(groupName);
    return allowed != null && allowed.contains(lostReason);
  }

  private static String resolveLeadStageForLost(Request requestItem) {
    String flowStage = requestItem.stageAtAction == null
      ? ''
      : requestItem.stageAtAction.trim();
    String normalizedFlowStage = normalizeStageAtAction(
      flowStage,
      requestItem.recordId
    );

    if (requestItem.recordId != null) {
      List<Lead> leads = [
        SELECT Status
        FROM Lead
        WHERE Id = :requestItem.recordId
        LIMIT 1
      ];
      if (!leads.isEmpty()) {
        String liveStatus = leads[0].Status;
        if (
          liveStatus == BWM_EmailConstants.STAGE_PROSPECT ||
          liveStatus == BWM_EmailConstants.STAGE_PROSPECTING
        ) {
          return liveStatus;
        }
      }
    }

    if (
      normalizedFlowStage == BWM_EmailConstants.STAGE_PROSPECT ||
      normalizedFlowStage == BWM_EmailConstants.STAGE_PROSPECTING
    ) {
      return normalizedFlowStage;
    }

    return normalizedFlowStage;
  }

  private static String normalizeStageAtAction(String stage, Id recordId) {
    if (String.isBlank(stage)) {
      return stage;
    }

    String normalizedStage = stage.trim();
    if (
      normalizedStage == BWM_EmailConstants.STAGE_PROSPECT ||
      normalizedStage == BWM_EmailConstants.STAGE_PROSPECTING
    ) {
      return normalizedStage;
    }

    if (normalizedStage == 'Qualified') {
      return BWM_EmailConstants.STAGE_PROSPECTING;
    }

    if (normalizedStage == 'Lost' && recordId != null) {
      List<Lead> leads = [
        SELECT Status
        FROM Lead
        WHERE Id = :recordId
        LIMIT 1
      ];
      if (!leads.isEmpty() && leads[0].Status == BWM_EmailConstants.STAGE_PROSPECTING) {
        return BWM_EmailConstants.STAGE_PROSPECTING;
      }
    }

    return normalizedStage;
  }
}