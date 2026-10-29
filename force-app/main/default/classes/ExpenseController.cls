/**
 * @description Controller class for Expense LWC components
 * Handles CRUD operations and business logic for Expense records
 */
public with sharing class ExpenseController {

    /**
     * @description Retrieves expenses for the current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getMyExpenses() {
        try {
            return [
                SELECT Id, Name, Employee__c, Employee_Level__c, Employee_Grade__c,
                       Status__c, Total_Amount__c, Purpose__c,
                       Travel_Start_Date__c, Travel_End_Date__c,
                       Submitted_Date__c, Approval_Date__c,
                       Approver__c, Approver__r.Name,
                       CreatedDate, LastModifiedDate
                FROM Expense__c
                WHERE Employee__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching expenses: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves a single expense with all related expense lines
     * NOTE: Not cacheable so post-save data is always fresh
     */
    @AuraEnabled
    public static Expense__c getExpenseWithLines(Id expenseId) {
        try {
            return [
                SELECT Id, Name, Employee__c, Employee_Level__c, Employee_Grade__c,
                       Status__c, Total_Amount__c, Purpose__c,
                       Travel_Start_Date__c, Travel_End_Date__c,
                       Submitted_Date__c, Approval_Date__c,
                       Approver__c, Approver__r.Name,
                       (
                           SELECT Id, Name, Expense_Type__c, City__c, City_Tier__c,
                                  Travel_Class__c, Vehicle_Type__c, Amount__c,
                                  Bill_Attached__c, Date__c, Distance_KM__c, Description__c
                           FROM Expense_Lines__r
                           ORDER BY Date__c ASC, CreatedDate ASC
                       )
                FROM Expense__c
                WHERE Id = :expenseId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching expense: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves employee eligibility for the current user.
     *              Derives employee level from the User record's Employee_Level__c field.
     *              Falls back to 'L6' if not configured.
     */
    @AuraEnabled(cacheable=true)
    public static Employee_Eligibility__c getMyEligibility() {
        try {
            // Get level directly from the User record — not from past expenses
            List<User> users = [
                SELECT Employee_Level__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            String userLevel = 'L6'; // safe default
            if (!users.isEmpty() && String.isNotBlank(users[0].Employee_Level__c)) {
                userLevel = users[0].Employee_Level__c;
            }

            List<Employee_Eligibility__c> eligibilities = [
                SELECT Id, Name, Level__c, Grade__c, Designation__c,
                       Lodging_Tier1__c, Lodging_Tier2__c,
                       Fooding_Tier1__c, Fooding_Tier2__c,
                       Air_Business__c, Air_Economy__c,
                       Train_1AC__c, Train_2AC__c, Train_3AC__c, Train_Sleeper__c,
                       Own_Vehicle_Rate__c, Active__c
                FROM Employee_Eligibility__c
                WHERE Level__c = :userLevel
                  AND Active__c = true
                LIMIT 1
            ];

            return eligibilities.isEmpty() ? null : eligibilities[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching eligibility: ' + e.getMessage());
        }
    }

    /**
     * @description Creates or updates an expense record.
     *              Always returns fresh data by querying directly (not via cacheable method).
     */
    @AuraEnabled
    public static Expense__c saveExpense(Expense__c expense) {
        try {
            if (expense.Employee__c == null) {
                expense.Employee__c = UserInfo.getUserId();
            }
            if (expense.Id == null && String.isBlank(expense.Status__c)) {
                expense.Status__c = 'New';
            }

            upsert expense;

            // Query fresh — do NOT call cacheable getExpenseWithLines here
            return [
                SELECT Id, Name, Employee__c, Employee_Level__c, Employee_Grade__c,
                       Status__c, Total_Amount__c, Purpose__c,
                       Travel_Start_Date__c, Travel_End_Date__c,
                       Submitted_Date__c, Approval_Date__c,
                       Approver__c, Approver__r.Name,
                       (
                           SELECT Id, Name, Expense_Type__c, City__c, City_Tier__c,
                                  Travel_Class__c, Vehicle_Type__c, Amount__c,
                                  Bill_Attached__c, Date__c, Distance_KM__c, Description__c
                           FROM Expense_Lines__r
                           ORDER BY Date__c ASC, CreatedDate ASC
                       )
                FROM Expense__c
                WHERE Id = :expense.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error saving expense: ' + e.getMessage());
        }
    }

    /**
     * @description Validates and submits an expense for approval
     */
    @AuraEnabled
    public static Map<String, Object> submitExpense(Id expenseId) {
        try {
            Map<String, Object> validationResult = ExpenseValidationHelper.validateExpense(expenseId);

            if ((Boolean) validationResult.get('isValid')) {
                ExpenseValidationHelper.submitExpense(expenseId);
                validationResult.put('message', 'Expense submitted successfully');
            } else {
                validationResult.put('message', 'Expense validation failed. Please review errors.');
            }

            return validationResult;
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting expense: ' + e.getMessage());
        }
    }

    /**
     * @description Returns all expenses pending approval (for managers/admins)
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense__c> getPendingApprovals() {
        try {
            User currentUser = [
                SELECT Profile.Name, Department, UserRole.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (currentUser.Profile.Name == 'System Administrator' && currentUser.UserRole.Name == 'Utkarsh ED') {
                // admins can see all expenses apart from rejected states
                return [
                    SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Level__c,
                        Status__c, Total_Amount__c, Purpose__c,
                        Travel_Start_Date__c, Travel_End_Date__c,
                        Submitted_Date__c
                    FROM Expense__c
                    WHERE Status__c IN ('Pending ED Approval')
                    ORDER BY Submitted_Date__c ASC
                    LIMIT 100
                ];
            } else if (currentUser.Profile.Name == 'System Administrator' || currentUser.Profile.Name == 'Utkarsh Admin') {
                // admins can see all expenses apart from rejected states
                return [
                    SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Level__c,
                        Status__c, Total_Amount__c, Purpose__c,
                        Travel_Start_Date__c, Travel_End_Date__c,
                        Submitted_Date__c
                    FROM Expense__c
                    WHERE Status__c IN ('Pending HOD Approval', 'Pending HR Approval', 'Pending ED Approval')
                    ORDER BY Submitted_Date__c ASC
                    LIMIT 100
                ];
            } else if (currentUser.Profile.Name == 'Utkarsh HR') {
                // HR Users will see expenses in Pending HR Approval expenses
                return [
                    SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Level__c,
                        Status__c, Total_Amount__c, Purpose__c,
                        Travel_Start_Date__c, Travel_End_Date__c,
                        Submitted_Date__c
                    FROM Expense__c
                    WHERE Status__c IN ('Pending HR Approval')
                    ORDER BY Submitted_Date__c ASC
                    LIMIT 100
                ];
            }
            else {
                // HOD Users will only see expenses in Pending HOD Approval state
                return [
                    SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Level__c,
                        Status__c, Total_Amount__c, Purpose__c,
                        Travel_Start_Date__c, Travel_End_Date__c,
                        Submitted_Date__c
                    FROM Expense__c
                    WHERE Status__c = 'Pending HOD Approval'
                    AND User_Department__c = :currentUser.Department
                    ORDER BY Submitted_Date__c ASC
                    LIMIT 100
                ];
            }

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error fetching pending approvals: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Approves an expense
     */
    @AuraEnabled
    public static void approveExpense(Id expenseId, String comments) {
        try {
            User currentUser = [
                SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];

            // String approvalStatus = currentUser.Profile.Name == 'Utkarsh HOD' ? 'HOD Approved' : 'ED Approved';
            String approvalStatus;
            if (currentUser.Profile.Name == 'System Administrator' || currentUser.Profile.Name == 'Utkarsh Admin') {
                approvalStatus = 'Approved by ED';
            } else if (currentUser.Profile.Name == 'Utkarsh HR') {
                approvalStatus = 'Pending ED Approval';
            } else if (currentUser.Profile.Name == 'Utkarsh HOD') {
                approvalStatus = 'Pending HR Approval';
            }

            update new Expense__c(
                Id = expenseId,
                Status__c = approvalStatus,
                Approval_Date__c = Date.today(),
                Approver__c = UserInfo.getUserId()
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error approving expense: ' + e.getMessage());
        }
    }

    /**
     * @description Rejects an expense
     */
    @AuraEnabled
    public static void rejectExpense(Id expenseId, String comments) {
        try {
             User currentUser = [
                SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];

            String rejectionStatus;
            if (currentUser.Profile.Name == 'System Administrator' || currentUser.Profile.Name == 'Utkarsh Admin') {
                rejectionStatus = 'Rejected by ED';
            } else if (currentUser.Profile.Name == 'Utkarsh HR') {
                rejectionStatus = 'Rejected by HR';
            } else if (currentUser.Profile.Name == 'Utkarsh HOD') {
                rejectionStatus = 'Rejected by HOD';
            }

            update new Expense__c(
                Id = expenseId,
                Status__c = rejectionStatus,
                Approval_Date__c = Date.today(),
                Approver__c = UserInfo.getUserId(),
                Remark__c = comments
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting expense: ' + e.getMessage());
        }
    }
}