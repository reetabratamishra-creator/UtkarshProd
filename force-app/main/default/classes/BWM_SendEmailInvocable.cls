public without sharing class BWM_SendEmailInvocable {
  public class Request {
    @InvocableVariable(label='Record Id' description='Lead or Opportunity Id.')
    public Id recordId;

    @InvocableVariable(
      label='Trigger Point'
      description='BWM email trigger point constant.'
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
    label='Send Infobip Email'
    description='Queues Infobip email for a Lead or Opportunity trigger point.'
    category='BWM Email'
  )
  public static List<Response> sendEmail(List<Request> requests) {
    List<Response> responses = new List<Response>();
    List<BWM_EmailRequest> queueRequests = new List<BWM_EmailRequest>();

    for (Request requestItem : requests) {
      Response responseItem = new Response();

      if (requestItem.recordId == null || String.isBlank(requestItem.triggerPoint)) {
        responseItem.queued = false;
        responseItem.message = 'Record Id and trigger point are required.';
      } else {
        queueRequests.add(
          new BWM_EmailRequest(requestItem.recordId, requestItem.triggerPoint)
        );
        responseItem.queued = true;
        responseItem.message = 'Email queued.';
      }

      responses.add(responseItem);
    }

    if (!queueRequests.isEmpty()) {
      BWM_EmailEnqueueService.enqueue(queueRequests);
    }

    return responses;
  }
}