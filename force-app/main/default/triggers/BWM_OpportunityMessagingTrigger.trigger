trigger BWM_OpportunityMessagingTrigger on Opportunity (after insert, after update) {
  try {
    if (Trigger.isAfter && Trigger.isInsert) {
      BWM_OpportunityMessagingTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
      BWM_OpportunityMessagingTriggerHandler.handleAfterUpdate(
        Trigger.new,
        Trigger.oldMap
      );
    }
  } catch (Exception ex) {
    System.debug(
      'BWM_OpportunityMessagingTrigger failed: ' + ex.getMessage()
    );
  }
}