/**
 * @description Controller class for Expense Line LWC components
 * Handles CRUD operations for Expense_Line__c records
 * @author Salesforce
 * @date 2026
 */
public with sharing class ExpenseLineController {
    
    /**
     * @description Retrieves expense lines for a given expense
     * @param expenseId The ID of the parent expense
     * @return List<Expense_Line__c> List of expense lines
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense_Line__c> getExpenseLines(Id expenseId) {
        try {
            return [
                SELECT Id, Name, Expense__c, Expense_Type__c, City__c, City_Tier__c,
                       Travel_Class__c, Vehicle_Type__c, Amount__c,
                       Bill_Attached__c, Date__c, Distance_KM__c, Description__c,
                       CreatedDate, LastModifiedDate
                FROM Expense_Line__c
                WHERE Expense__c = :expenseId
                ORDER BY Date__c, CreatedDate
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching expense lines: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates or updates an expense line
     * @param expenseLine The expense line to save
     * @return Expense_Line__c The saved expense line
     */
    @AuraEnabled
    public static Expense_Line__c saveExpenseLine(Expense_Line__c expenseLine) {
        try {
            // Validate required fields
            if (expenseLine.Expense__c == null) {
                throw new AuraHandledException('Parent Expense is required');
            }
            
            if (expenseLine.Expense_Type__c == null) {
                throw new AuraHandledException('Expense Type is required');
            }
            
            // Auto-calculate own vehicle expense if applicable
            if (expenseLine.Expense_Type__c == 'Own Vehicle' && 
                expenseLine.Distance_KM__c != null) {
                expenseLine.Amount__c = calculateOwnVehicleAmount(
                    expenseLine.Expense__c, 
                    expenseLine.Distance_KM__c
                );
            }
            
            upsert expenseLine;
            return expenseLine;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving expense line: ' + e.getMessage());
        }
    }
    
    /**
     * @description Saves multiple expense lines in bulk
     * @param expenseLines List of expense lines to save
     * @return List<Expense_Line__c> List of saved expense lines
     */
    @AuraEnabled
    public static List<Expense_Line__c> saveExpenseLines(List<Expense_Line__c> expenseLines) {
        try {
            if (expenseLines == null || expenseLines.isEmpty()) {
                throw new AuraHandledException('No expense lines provided');
            }
            
            // Process own vehicle calculations
            for (Expense_Line__c line : expenseLines) {
                if (line.Expense_Type__c == 'Own Vehicle' && 
                    line.Distance_KM__c != null && 
                    line.Expense__c != null) {
                    line.Amount__c = calculateOwnVehicleAmount(
                        line.Expense__c, 
                        line.Distance_KM__c
                    );
                }
            }
            
            upsert expenseLines;
            return expenseLines;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving expense lines: ' + e.getMessage());
        }
    }
    
    /**
     * @description Deletes an expense line
     * @param expenseLineId The ID of the expense line to delete
     */
    @AuraEnabled
    public static void deleteExpenseLine(Id expenseLineId) {
        try {
            // Check if parent expense is in draft status
            Expense_Line__c line = [
                SELECT Id, Expense__c, Expense__r.Status__c
                FROM Expense_Line__c
                WHERE Id = :expenseLineId
                LIMIT 1
            ];
            
            if (line.Expense__r.Status__c != 'Draft') {
                throw new AuraHandledException('Cannot delete expense line. Parent expense is not in Draft status.');
            }
            
            delete line;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting expense line: ' + e.getMessage());
        }
    }
    
    /**
     * @description Validates an expense line against eligibility rules
     * @param expenseLine The expense line to validate
     * @return Map<String, Object> Validation result with isValid and errors
     */
    @AuraEnabled
    public static Map<String, Object> validateExpenseLine(Expense_Line__c expenseLine) {
        Map<String, Object> result = new Map<String, Object>();
        List<String> errors = new List<String>();
        Boolean isValid = true;
        
        try {
            // Get employee eligibility
            Expense__c expense = [
                SELECT Employee_Level__c
                FROM Expense__c
                WHERE Id = :expenseLine.Expense__c
                LIMIT 1
            ];
            
            List<Employee_Eligibility__c> eligibilities = [
                SELECT Lodging_Tier1__c, Lodging_Tier2__c,
                       Fooding_Tier1__c, Fooding_Tier2__c,
                       Air_Business__c, Air_Economy__c,
                       Train_1AC__c, Train_2AC__c, Train_3AC__c, Train_Sleeper__c,
                       Own_Vehicle_Rate__c
                FROM Employee_Eligibility__c
                WHERE Level__c = :expense.Employee_Level__c AND Active__c = true
                LIMIT 1
            ];
            
            if (!eligibilities.isEmpty()) {
                Employee_Eligibility__c eligibility = eligibilities[0];
                
                // Validate based on expense type
                switch on expenseLine.Expense_Type__c {
                    when 'Lodging' {
                        Decimal allowedLimit = (expenseLine.City_Tier__c == 'Tier 1') ? 
                            eligibility.Lodging_Tier1__c : eligibility.Lodging_Tier2__c;
                        if (expenseLine.Amount__c > allowedLimit) {
                            errors.add('Amount exceeds allowed limit of ₹' + allowedLimit + ' for ' + expenseLine.City_Tier__c);
                            isValid = false;
                        }
                    }
                    when 'Fooding' {
                        Decimal allowedLimit = (expenseLine.City_Tier__c == 'Tier 1') ? 
                            eligibility.Fooding_Tier1__c : eligibility.Fooding_Tier2__c;
                        if (expenseLine.Amount__c > allowedLimit) {
                            errors.add('Amount exceeds allowed limit of ₹' + allowedLimit + ' for ' + expenseLine.City_Tier__c);
                            isValid = false;
                        }
                        if (!expenseLine.Bill_Attached__c) {
                            errors.add('Bill is required for food expenses');
                            isValid = false;
                        }
                    }
                    when 'Air' {
                        Boolean allowed = (expenseLine.Travel_Class__c == 'Business') ? 
                            eligibility.Air_Business__c : eligibility.Air_Economy__c;
                        if (!allowed) {
                            errors.add(expenseLine.Travel_Class__c + ' class not allowed for your level');
                            isValid = false;
                        }
                    }
                    when 'Train' {
                        Boolean allowed = false;
                        switch on expenseLine.Travel_Class__c {
                            when '1AC' { allowed = eligibility.Train_1AC__c; }
                            when '2AC' { allowed = eligibility.Train_2AC__c; }
                            when '3AC' { allowed = eligibility.Train_3AC__c; }
                            when 'Sleeper' { allowed = eligibility.Train_Sleeper__c; }
                        }
                        if (!allowed) {
                            errors.add(expenseLine.Travel_Class__c + ' class not allowed for your level');
                            isValid = false;
                        }
                    }
                    when 'Own Vehicle' {
                        if (expenseLine.Distance_KM__c != null && eligibility.Own_Vehicle_Rate__c != null) {
                            Decimal maxAmount = expenseLine.Distance_KM__c * eligibility.Own_Vehicle_Rate__c;
                            if (expenseLine.Amount__c > maxAmount) {
                                errors.add('Amount exceeds calculated rate: ₹' + maxAmount + 
                                         ' (' + expenseLine.Distance_KM__c + ' KM × ₹' + eligibility.Own_Vehicle_Rate__c + '/KM)');
                                isValid = false;
                            }
                        }
                    }
                }
            }
            
            result.put('isValid', isValid);
            result.put('errors', errors);
            result.put('warnings', new List<String>());
            
        } catch (Exception e) {
            result.put('isValid', false);
            result.put('errors', new List<String>{ e.getMessage() });
        }
        
        return result;
    }
    
    /**
     * @description Calculates own vehicle expense amount
     * @param expenseId The parent expense ID
     * @param distanceKM The distance in kilometers
     * @return Decimal The calculated amount
     */
    private static Decimal calculateOwnVehicleAmount(Id expenseId, Decimal distanceKM) {
        Expense__c expense = [
            SELECT Employee_Level__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];
        
        List<Employee_Eligibility__c> eligibilities = [
            SELECT Own_Vehicle_Rate__c
            FROM Employee_Eligibility__c
            WHERE Level__c = :expense.Employee_Level__c AND Active__c = true
            LIMIT 1
        ];
        
        if (!eligibilities.isEmpty() && eligibilities[0].Own_Vehicle_Rate__c != null) {
            return distanceKM * eligibilities[0].Own_Vehicle_Rate__c;
        }
        
        return 0;
    }
    
    /**
     * @description Gets the total amount for all expense lines of an expense
     * @param expenseId The parent expense ID
     * @return Decimal The total amount
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getTotalAmount(Id expenseId) {
        try {
            AggregateResult[] results = [
                SELECT SUM(Amount__c) total
                FROM Expense_Line__c
                WHERE Expense__c = :expenseId
            ];
            
            return results[0].get('total') != null ? (Decimal)results[0].get('total') : 0;
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating total: ' + e.getMessage());
        }
    }
}