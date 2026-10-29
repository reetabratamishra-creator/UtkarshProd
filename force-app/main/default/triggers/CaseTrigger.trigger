trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    if (!TriggerEnableService.isEnabled(TriggerEnableService.CASE_TRIGGER)) {
        return;
    }

    try {
        if (Trigger.isBefore && Trigger.isUpdate) {
            CaseCreatorShareHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
        if (Trigger.isAfter && Trigger.isInsert) {
            CaseCreatorShareHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            CaseCreatorShareHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'CaseCreatorShareHandler failed: ' +
                ex.getMessage() +
                '\nStack Trace: ' +
                ex.getStackTraceString()
        );
    }

    try {
        if (Trigger.isAfter && Trigger.isInsert) {
            CaseNewAssignedOwnerHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            CaseNewAssignedOwnerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'CaseNewAssignedOwnerHandler failed: ' +
                ex.getMessage() +
                '\nStack Trace: ' +
                ex.getStackTraceString()
        );
    }

    try {
        if (Trigger.isAfter && Trigger.isInsert) {
            CasePushNotificationHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            CasePushNotificationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'CasePushNotificationHandler failed: ' +
                ex.getMessage() +
                '\nStack Trace: ' +
                ex.getStackTraceString()
        );
    }

    try {
        if (Trigger.isAfter && Trigger.isUpdate) {
            CaseResolvedEmailHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'CaseResolvedEmailHandler failed: ' +
                ex.getMessage() +
                '\nStack Trace: ' +
                ex.getStackTraceString()
        );
    }
    
    try {
        if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
            CaseSLADueDateHandler.setDueDate(
                Trigger.new,
                Trigger.isUpdate ? Trigger.oldMap : null
            );
        }
    } catch (Exception ex) {
        System.debug(LoggingLevel.ERROR, 'CaseSLADueDateHandler failed: ' + ex.getMessage());
    }
}