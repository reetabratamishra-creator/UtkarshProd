public without sharing class BWM_LeadMessagingTriggerHandler {
  @TestVisible
  private static Boolean skipEnqueueForTests = false;

  private static Set<Id> processedLeadIds = new Set<Id>();

  public static void handleAfterInsert(List<Lead> newLeads) {
    if (Test.isRunningTest() && skipEnqueueForTests) {
      return;
    }
    if (newLeads == null || newLeads.isEmpty()) {
      return;
    }

    // prospect_enq_dept / prospect_enq_gen fire from Lead: New Lead Flow only.
  }

  public static void enqueueMessaging(List<Id> leadIds) {
    if (leadIds.isEmpty()) {
      return;
    }

    BWM_MessagingEnqueueService.enqueueLeadCreate(leadIds);
  }
}