public without sharing class BWM_LeadMessagingQueueable implements Queueable, Database.AllowsCallouts {
  private final List<Id> leadIds;

  public BWM_LeadMessagingQueueable(List<Id> leadIds) {
    this.leadIds = leadIds == null ? new List<Id>() : new List<Id>(leadIds);
  }

  public void execute(QueueableContext context) {
    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();
    for (Id leadId : leadIds) {
      requests.add(
        new BWM_MessagingRequest(leadId, BWM_MessagingConstants.TRIGGER_LEAD_CREATE)
      );
    }

    new BWM_MessagingQueueable(requests).execute(context);
  }
}