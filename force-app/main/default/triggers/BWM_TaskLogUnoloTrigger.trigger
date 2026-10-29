trigger BWM_TaskLogUnoloTrigger on Task_Log__c (after insert) {
  if (!TriggerEnableService.isEnabled(TriggerEnableService.BWM_TASK_LOG_UNOLO)) {
    return;
  }

  try {
    BWM_TaskLogUnoloTriggerHandler.handleAfterInsert(Trigger.new);
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'BWM_TaskLogUnoloTrigger failed: ' + ex.getMessage()
    );
  }
}