/**
 * @description Helper class for expense validation logic based on UIL Eligibility Matrix
 * and Standing Instructions for travel expense policies
 * @author Salesforce
 * @date 2026
 */
public with sharing class ExpenseValidationHelper {
    
    /**
     * @description Validates expense against employee eligibility and policy rules
     * @param expenseId The ID of the expense to validate
     * @return Map<String, Object> containing validation results and error messages
     */
    public static Map<String, Object> validateExpense(Id expenseId) {
        Map<String, Object> validationResult = new Map<String, Object>();
        List<String> errors = new List<String>();
        Boolean isValid = true;
        
        // Query expense with related lines
        Expense__c expense = [
            SELECT Id, Employee_Level__c, Travel_End_Date__c, Submitted_Date__c, Status__c,
                   (SELECT Id, Expense_Type__c, City_Tier__c, Travel_Class__c, 
                    Amount__c, Bill_Attached__c, Distance_KM__c, Vehicle_Type__c
                    FROM Expense_Lines__r)
            FROM Expense__c 
            WHERE Id = :expenseId
            LIMIT 1
        ];
        
        // Get employee eligibility
        List<Employee_Eligibility__c> eligibilities = [
            SELECT Id, Level__c, Lodging_Tier1__c, Lodging_Tier2__c, 
                   Fooding_Tier1__c, Fooding_Tier2__c, Air_Business__c, Air_Economy__c,
                   Train_1AC__c, Train_2AC__c, Train_3AC__c, Train_Sleeper__c,
                   Own_Vehicle_Rate__c
            FROM Employee_Eligibility__c
            WHERE Level__c = :expense.Employee_Level__c AND Active__c = true
            LIMIT 1
        ];
        
        if (eligibilities.isEmpty()) {
            errors.add('No active eligibility found for employee level: ' + expense.Employee_Level__c);
            isValid = false;
        } else {
            Employee_Eligibility__c eligibility = eligibilities[0];
            
            // Validate each expense line
            for (Expense_Line__c line : expense.Expense_Lines__r) {
                String lineError = validateExpenseLine(line, eligibility);
                if (String.isNotBlank(lineError)) {
                    errors.add(lineError);
                    isValid = false;
                }
            }
        }
        
        // Validate submission timeline (10 days per Standing Instructions)
        if (expense.Travel_End_Date__c != null && expense.Submitted_Date__c != null) {
            Integer daysDiff = expense.Travel_End_Date__c.daysBetween(expense.Submitted_Date__c);
            if (daysDiff > 10) {
                errors.add('Expense submitted beyond 10 days. Submission not allowed per policy.');
                isValid = false;
            }
        }
        
        validationResult.put('isValid', isValid);
        validationResult.put('errors', errors);
        return validationResult;
    }
    
    /**
     * @description Validates individual expense line against eligibility
     * @param line The expense line to validate
     * @param eligibility The employee eligibility record
     * @return String error message if validation fails, null otherwise
     */
    public static String validateExpenseLine(Expense_Line__c line, Employee_Eligibility__c eligibility) {
        String error = null;
        
        switch on line.Expense_Type__c {
            when 'Lodging' {
                Decimal allowedLimit = (line.City_Tier__c == 'Tier 1') ? 
                    eligibility.Lodging_Tier1__c : eligibility.Lodging_Tier2__c;
                if (line.Amount__c > allowedLimit) {
                    error = 'Lodging amount ' + line.Amount__c + ' exceeds limit ' + allowedLimit + 
                           ' for ' + line.City_Tier__c;
                }
            }
            when 'Fooding' {
                // Validate bill attachment per Standing Instructions
                if (!line.Bill_Attached__c) {
                    error = 'All food expenses must be supported by bills';
                }
                Decimal allowedLimit = (line.City_Tier__c == 'Tier 1') ? 
                    eligibility.Fooding_Tier1__c : eligibility.Fooding_Tier2__c;
                if (line.Amount__c > allowedLimit) {
                    error = 'Fooding amount ' + line.Amount__c + ' exceeds limit ' + allowedLimit + 
                           ' for ' + line.City_Tier__c;
                }
            }
            when 'Air' {
                Boolean allowed = (line.Travel_Class__c == 'Business') ? 
                    eligibility.Air_Business__c : eligibility.Air_Economy__c;
                if (!allowed) {
                    error = line.Travel_Class__c + ' class air travel not allowed for this level';
                }
            }
            when 'Train' {
                Boolean allowed = false;
                switch on line.Travel_Class__c {
                    when '1AC' { allowed = eligibility.Train_1AC__c; }
                    when '2AC' { allowed = eligibility.Train_2AC__c; }
                    when '3AC' { allowed = eligibility.Train_3AC__c; }
                    when 'Sleeper' { allowed = eligibility.Train_Sleeper__c; }
                }
                if (!allowed) {
                    error = line.Travel_Class__c + ' train class not allowed for this level';
                }
            }
            when 'Own Vehicle' {
                if (line.Distance_KM__c != null && eligibility.Own_Vehicle_Rate__c != null) {
                    Decimal calculatedAmount = line.Distance_KM__c * eligibility.Own_Vehicle_Rate__c;
                    if (line.Amount__c > calculatedAmount) {
                        error = 'Own vehicle amount ' + line.Amount__c + 
                               ' exceeds calculated amount ' + calculatedAmount + 
                               ' (Distance: ' + line.Distance_KM__c + ' KM × Rate: ' + 
                               eligibility.Own_Vehicle_Rate__c + ')';
                    }
                }
            }
        }
        
        return error;
    }
    
    /**
     * @description Updates expense status to Submitted and sets submission date
     * @param expenseId The ID of the expense to submit
     */
    public static void submitExpense(Id expenseId) {
        Expense__c expense = new Expense__c(
            Id = expenseId,
            Status__c = 'Pending HOD Approval',
            Submitted_Date__c = Date.today()
        );
        update expense;
    }
}