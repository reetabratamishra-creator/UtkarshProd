public without sharing class BWM_SendMessageInvocable {
  public class Request {
    @InvocableVariable(label='Lead Id' description='Legacy input for Lead Create messaging.')
    public Id leadId;

    @InvocableVariable(
      label='Record Id'
      description='Lead or Opportunity Id to send messaging for.'
    )
    public Id recordId;

    @InvocableVariable(
      label='Trigger Point'
      description='BWM trigger point constant, e.g. Lead_Task_Callback_Prospect.'
    )
    public String triggerPoint;
  }

  public class Response {
    @InvocableVariable
    public Boolean queued;

    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Send Blue Waves Message'
    description='Queues WhatsApp with RCS fallback for a Lead or Opportunity trigger point.'
    category='Blue Waves Messaging'
  )
  public static List<Response> sendMessage(List<Request> requests) {
    List<Response> responses = new List<Response>();
    List<BWM_MessagingRequest> queueRequests = new List<BWM_MessagingRequest>();

    for (Request requestItem : requests) {
      Response responseItem = new Response();
      Id targetRecordId = requestItem.recordId != null
        ? requestItem.recordId
        : requestItem.leadId;
      String targetTriggerPoint = String.isNotBlank(requestItem.triggerPoint)
        ? requestItem.triggerPoint
        : BWM_MessagingConstants.TRIGGER_LEAD_CREATE;

      if (targetRecordId == null) {
        responseItem.queued = false;
        responseItem.message = 'Record Id is required.';
      } else {
        queueRequests.add(
          new BWM_MessagingRequest(targetRecordId, targetTriggerPoint)
        );
        responseItem.queued = true;
        responseItem.message = 'Messaging queued.';
      }

      responses.add(responseItem);
    }

    if (!queueRequests.isEmpty()) {
      BWM_MessagingEnqueueService.enqueue(queueRequests);
    }

    return responses;
  }
}