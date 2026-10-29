trigger BWM_EmailOpportunityTrigger on Opportunity (after insert, after update) {
  try {
    if (Trigger.isAfter && Trigger.isInsert) {
      BWM_EmailOpportunityTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
      BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
        Trigger.new,
        Trigger.oldMap
      );
    }
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'BWM_EmailOpportunityTrigger failed: ' + ex.getMessage()
    );
  }
}