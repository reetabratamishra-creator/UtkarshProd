trigger BWM_LeadMessagingTrigger on Lead (after insert) {
  try {
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(Trigger.new);
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'BWM_LeadMessagingTrigger suppressed: ' + ex.getMessage()
    );
  }
}