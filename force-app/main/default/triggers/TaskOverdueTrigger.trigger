/**
 * @description   Task after insert/update trigger for overdue email and push notifications.
 *                Email and push handlers are isolated in try/catch so one failure
 *                never blocks the other or rolls back Task saves.
 */
trigger TaskOverdueTrigger on Task (after insert, after update) {
    if (!TriggerEnableService.isEnabled(TriggerEnableService.TASK_OVERDUE_TRIGGER)) {
        return;
    }

    try {
        TaskOverdueHandler.handleOverdueTasks(Trigger.new, Trigger.oldMap);
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'TaskOverdueHandler failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }

    try {
        TaskOverduePushNotificationHandler.handleOverdueTasks(
            Trigger.new,
            Trigger.oldMap
        );
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'TaskOverduePushNotificationTrigger failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }
}