/**
 * @description   Invocable Apex for Flow to queue Task Callback/Lost messaging
 *                journeys.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_SendTaskMessageInvocable {
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
    label='Send Blue Waves Task Message'
    description='Routes Lead Task Callback/Lost flows to the correct WhatsApp journey trigger point.'
    category='Blue Waves Messaging'
  )
  public static List<Response> sendTaskMessage(List<Request> requests) {
    List<Response> responses = new List<Response>();
    List<BWM_MessagingRequest> queueRequests = new List<BWM_MessagingRequest>();

    for (Request requestItem : requests) {
      Response responseItem = new Response();
      String triggerPoint = resolveTriggerPoint(requestItem);

      if (String.isBlank(triggerPoint)) {
        responseItem.queued = false;
        responseItem.message = 'No messaging trigger matched this task action.';
      } else {
        queueRequests.add(
          new BWM_MessagingRequest(
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
      BWM_MessagingEnqueueService.enqueue(queueRequests);
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

    if (objectName == BWM_MessagingConstants.OBJECT_TYPE_OPPORTUNITY) {
      if (action == 'callback') {
        return resolveOpportunityCallbackTrigger(stage, requestItem.recordId);
      }
      return null;
    }

    if (objectName != BWM_MessagingConstants.OBJECT_TYPE_LEAD) {
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

  private static String resolveOpportunityCallbackTrigger(String stage, Id recordId) {
    String resolvedStage = resolveOpportunityStage(stage, recordId);
    if (
      resolvedStage == BWM_MessagingConstants.STAGE_NURTURE ||
      resolvedStage == BWM_MessagingConstants.STAGE_NEGOTIATION
    ) {
      return BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE;
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

  private static String resolveCallbackTrigger(String stage) {
    if (stage == BWM_MessagingConstants.STAGE_PROSPECT) {
      return BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT;
    }
    if (stage == BWM_MessagingConstants.STAGE_PROSPECTING) {
      return BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING;
    }
    return null;
  }

  private static String resolveLostTrigger(String stage, String lostReason) {
    if (String.isBlank(stage) || String.isBlank(lostReason)) {
      return null;
    }

    if (
      BWM_MessagingConstants.OPP_LOST_DETAILS_NOT_RECEIVED.contains(lostReason)
    ) {
      if (stage == BWM_MessagingConstants.STAGE_PROSPECT) {
        return BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT;
      }
      if (stage == BWM_MessagingConstants.STAGE_PROSPECTING) {
        return BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING;
      }
    }

    if (BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(lostReason)) {
      if (stage == BWM_MessagingConstants.STAGE_PROSPECTING) {
        return BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING;
      }
    }

    return null;
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
          liveStatus == BWM_MessagingConstants.STAGE_PROSPECT ||
          liveStatus == BWM_MessagingConstants.STAGE_PROSPECTING
        ) {
          return liveStatus;
        }
      }
    }

    if (
      normalizedFlowStage == BWM_MessagingConstants.STAGE_PROSPECT ||
      normalizedFlowStage == BWM_MessagingConstants.STAGE_PROSPECTING
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
      normalizedStage == BWM_MessagingConstants.STAGE_PROSPECT ||
      normalizedStage == BWM_MessagingConstants.STAGE_PROSPECTING
    ) {
      return normalizedStage;
    }

    if (normalizedStage == 'Qualified') {
      return BWM_MessagingConstants.STAGE_PROSPECTING;
    }

    if (normalizedStage == BWM_MessagingConstants.STAGE_LOST && recordId != null) {
      List<Lead> leads = [
        SELECT Status
        FROM Lead
        WHERE Id = :recordId
        LIMIT 1
      ];
      if (
        !leads.isEmpty() &&
        leads[0].Status == BWM_MessagingConstants.STAGE_PROSPECTING
      ) {
        return BWM_MessagingConstants.STAGE_PROSPECTING;
      }
    }

    return normalizedStage;
  }
}