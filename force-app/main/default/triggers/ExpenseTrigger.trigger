/**
 * @description Trigger for Expense__c object
 * Delegates logic to ExpenseTriggerHandler
 * @author Salesforce
 * @date 2026
 */
trigger ExpenseTrigger on Expense__c (before insert, before update, before delete, 
                                      after insert, after update, after delete, after undelete) {
    if (!TriggerEnableService.isEnabled(TriggerEnableService.EXPENSE_TRIGGER)) {
        return;
    }

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ExpenseTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            ExpenseTriggerHandler.beforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            // ExpenseTriggerHandler.afterInsert(Trigger.new);
            ExpenseNotificationHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            // ExpenseTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
            
            ExpenseNotificationHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    try {
        if (Trigger.isAfter && Trigger.isInsert) {
            ExpenseStatusEmailHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            ExpenseStatusEmailHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'ExpenseStatusEmailTrigger failed: ' +
            ex.getMessage() +
            '\nStack Trace: ' +
            ex.getStackTraceString()
        );
    }
}