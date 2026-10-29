public with sharing class BWM_EmailRequest {
  public Id recordId;
  public String triggerPoint;
  public String stageAtAction;

  public BWM_EmailRequest() {
  }

  public BWM_EmailRequest(Id recordId, String triggerPoint) {
    this.recordId = recordId;
    this.triggerPoint = triggerPoint;
  }

  public BWM_EmailRequest(
    Id recordId,
    String triggerPoint,
    String stageAtAction
  ) {
    this.recordId = recordId;
    this.triggerPoint = triggerPoint;
    this.stageAtAction = stageAtAction;
  }
}