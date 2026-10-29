/**
 * @description   Sends WFH employee approval-pending email on Punch Record create/update.
 * @author        Anshita Chanda
 * @date          2026-08-14
 */
trigger PunchRecordWfhEmployeeEmailTrigger on Punch_Record__c (
  after insert,
  after update
) {
  if (!TriggerEnableService.isEnabled(TriggerEnableService.PUNCH_RECORD_WFH_EMAIL)) {
    return;
  }

  try {
    if (Trigger.isAfter && Trigger.isInsert) {
      PunchRecordWfhEmployeeEmailHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
      PunchRecordWfhEmployeeEmailHandler.handleAfterUpdate(
        Trigger.new,
        Trigger.oldMap
      );
    }
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'PunchRecordWfhEmployeeEmailTrigger failed: ' +
        ex.getMessage() +
        '\nStack Trace: ' +
        ex.getStackTraceString()
    );
  }
}