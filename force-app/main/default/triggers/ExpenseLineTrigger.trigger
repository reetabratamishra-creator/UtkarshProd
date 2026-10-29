/**
 * @description Trigger for Expense_Line__c object
 * Delegates logic to ExpenseLineTriggerHandler
 * @author Salesforce Developer
 * @date 2026
 */
trigger ExpenseLineTrigger on Expense_Line__c (before insert, before update, before delete,
                                              after insert, after update, after delete, after undelete) {
    if (!TriggerEnableService.isEnabled(TriggerEnableService.EXPENSE_LINE_TRIGGER)) {
        return;
    }

    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            ExpenseLineTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            ExpenseLineTriggerHandler.beforeDelete(Trigger.old);
        }
    }
}