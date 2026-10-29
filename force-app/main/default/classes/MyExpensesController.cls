/**
 * @description Controller for the myExpenses LWC.
 *              Lists the running user's own Expense__c records and flags the rejected ones
 *              that can be edited and resubmitted through newExpenseForm.
 */
public with sharing class MyExpensesController {

    @AuraEnabled(cacheable=true)
    public static List<ExpenseRow> getMyExpenses() {
        try {
            List<ExpenseRow> rows = new List<ExpenseRow>();
            for (Expense__c exp : [
                SELECT Id, Name, Status__c, Total_Amount__c, Remark__c
                FROM Expense__c
                WHERE Employee__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 1000
            ]) {
                ExpenseRow row = new ExpenseRow();
                row.Id = exp.Id;
                row.Name = exp.Name;
                row.Status = exp.Status__c;
                row.TotalAmount = exp.Total_Amount__c;
                row.Remark = exp.Remark__c;
                // Same rule the triggers enforce for edits made through newExpenseForm
                row.canEdit = ExpenseTriggerHandler.isAllowedToReEditRejectedExpense(exp.Status__c);
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException('Error fetching expenses: ' + e.getMessage());
            ex.setMessage('Error fetching expenses: ' + e.getMessage());
            throw ex;
        }
    }

    public class ExpenseRow {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Status;
        @AuraEnabled public Decimal TotalAmount;
        @AuraEnabled public String Remark;
        @AuraEnabled public Boolean canEdit;
    }
}