trigger BWM_EmailLeadTrigger on Lead (after insert) {
  try {
    BWM_EmailLeadTriggerHandler.handleAfterInsert(Trigger.new);
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'BWM_EmailLeadTrigger failed: ' + ex.getMessage()
    );
  }
}