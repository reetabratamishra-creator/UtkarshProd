public class BWM_MessagingRequest {
  public Id recordId;
  public String triggerPoint;
  public String stageAtAction;

  public BWM_MessagingRequest() {
  }

  public BWM_MessagingRequest(Id recordId, String triggerPoint) {
    this.recordId = recordId;
    this.triggerPoint = triggerPoint;
  }

  public BWM_MessagingRequest(
    Id recordId,
    String triggerPoint,
    String stageAtAction
  ) {
    this.recordId = recordId;
    this.triggerPoint = triggerPoint;
    this.stageAtAction = stageAtAction;
  }
}