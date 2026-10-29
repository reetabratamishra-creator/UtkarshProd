/**
 * @description Trigger handler for Expense__c object
 * Handles trigger logic following the trigger handler pattern
 * @author Salesforce
 * @date 2026
 */
public with sharing class ExpenseTriggerHandler {
    
    /**
     * @description Static flag indicating if execution is within the newExpenseForm LWC context.
     *              Delegates to ExpenseLineTriggerHandler.isLwcContext so state is always synchronized.
     */
    public static Boolean isLwcContext {
        get {
            return ExpenseLineTriggerHandler.isLwcContext;
        }
        set {
            ExpenseLineTriggerHandler.isLwcContext = value;
        }
    }

    public static final String DELETE_ERROR_MSG = 'Expense records cannot be deleted.';
    
    /**
     * @description Before Insert trigger logic
     * @param newExpenses List of new expense records
     */
    public static void beforeInsert(List<Expense__c> newExpenses) {
        // Set default values
        for (Expense__c expense : newExpenses) {
            if (String.isBlank(expense.Status__c)) {
                expense.Status__c = 'New';
            }
            
            if (expense.Employee__c == null) {
                expense.Employee__c = UserInfo.getUserId();
            }
        }
    }
    
    public static final String EDIT_RESTRICTED_MSG = 'Editing expense details after creation is not permitted.';
    public static final String APPROVAL_RESTRICTED_MSG = 'Only Utkarsh HOD, Utkarsh HR, or System Administrator can approve or reject expenses.';
    
    public static final Set<String> ALLOWED_APPROVAL_FIELDS = new Set<String>{
        'Status__c',
        'Remark__c',
        'Approver__c',
        'Approval_Date__c'
    };

    public static final Set<String> ALLOWED_APPROVAL_PROFILES = new Set<String>{
        'Utkarsh HOD',
        'Utkarsh HR',
        'System Administrator',
        'Utkarsh Admin'
    };

    public static final String HOD_PROFILE_NAME = 'Utkarsh HOD';
    public static final String HR_PROFILE_NAME = 'Utkarsh HR';
    public static final String STATUS_PENDING_HOD = 'Pending HOD Approval';
    public static final String STATUS_PENDING_HR = 'Pending HR Approval';
    public static final String STATUS_PENDING_ED = 'Pending ED Approval';

    public static final String HOD_RESTRICTED_MSG = 'You are only permitted to approve or reject expenses when the status is Pending HOD Approval.';
    public static final String HR_RESTRICTED_MSG = 'You are only permitted to approve or reject expenses when the status is Pending HR Approval.';

    public static final String CLIENT_ADMIN_ROLE = 'Utkarsh ED';
    public static final String CLIENT_ADMIN_RESTRICTED_MSG = 'You are only permitted to approve or reject expenses when the status is Pending ED Approval.';

    @TestVisible
    private static Boolean isAuthorizedApproverOverride = null;

    @TestVisible
    private static String currentUserRoleNameOverride = null;

    @TestVisible
    private static String currentUserProfileNameOverride = null;

    /*
    @TestVisible
    private static Boolean hasPermissionOverride = null;
    */

    private static String currentUserProfileName;
    private static String currentUserRoleName;

    /**
     * @description Loads current user's profile and role information.
     */
    private static void loadCurrentUserInfo() {
        if (currentUserProfileName == null) {
            User u = [
                SELECT Profile.Name, UserRole.Name 
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                LIMIT 1
            ];
            currentUserProfileName = (u.Profile != null) ? u.Profile.Name : '';
            currentUserRoleName = (u.UserRole != null) ? u.UserRole.Name : '';
        }
    }

    /*
    @description Checks if the user has custom permission Custom_Permission_for_Expense.
    @return Boolean True if custom permission is assigned.
    public static Boolean hasCustomPermission() {
        if (Test.isRunningTest() && hasPermissionOverride != null) {
            return hasPermissionOverride;
        }
        return FeatureManagement.checkPermission('Custom_Permission_for_Expense');
    }
    */

    /**
     * @description Retrieves the current user's profile name.
     * @return String Profile name.
     */
    public static String getCurrentUserProfile() {
        if (Test.isRunningTest() && currentUserProfileNameOverride != null) {
            return currentUserProfileNameOverride;
        }
        loadCurrentUserInfo();
        return currentUserProfileName;
    }

    /**
     * @description Retrieves the current user's role name.
     * @return String UserRole name.
     */
    public static String getCurrentUserRole() {
        if (Test.isRunningTest() && currentUserRoleNameOverride != null) {
            return currentUserRoleNameOverride;
        }
        loadCurrentUserInfo();
        return currentUserRoleName;
    }

    /**
     * @description Checks if the running user has an authorized profile to approve/reject expenses.
     * @return Boolean True if authorized, false otherwise.
     */
    public static Boolean isAuthorizedApprover() {
        if (Test.isRunningTest() && isAuthorizedApproverOverride != null) {
            return isAuthorizedApproverOverride;
        }

        String profileName = getCurrentUserProfile();

        if (ALLOWED_APPROVAL_PROFILES.contains(profileName)) {
            return true;
        }

        /*
        if (hasCustomPermission()) {
            return true;
        }
        */

        return false;
    }

    /**
     * @description Checks if the running user is allowed to re-edit/re-submit a rejected expense via newExpenseForm LWC.
     *              - Normal user: 'Rejected by HOD', 'Rejected by HR', 'Rejected by ED'
     *              - Utkarsh HOD: 'Rejected by HR', 'Rejected by ED'
     *              - Utkarsh HR: 'Rejected by ED'
     *              - System Admin with role 'Utkarsh ED': 'Rejected by ED'
     *              - Standard System Admin / Utkarsh Admin: 'Rejected by HOD', 'Rejected by HR', 'Rejected by ED'
     * @param oldStatus The current (old) Status__c of the Expense__c record.
     * @return Boolean True if eligible for re-edit, false otherwise.
     */
    public static Boolean isAllowedToReEditRejectedExpense(String oldStatus) {
        if (String.isBlank(oldStatus)) {
            return false;
        }
        String profileName = getCurrentUserProfile();
        String roleName = getCurrentUserRole();

        // 1. System Admin with role 'Utkarsh ED'
        if (String.isNotBlank(roleName) && roleName.equalsIgnoreCase(CLIENT_ADMIN_ROLE)) {
            return oldStatus == 'Rejected by ED';
        }

        // 2. HR User
        if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HR_PROFILE_NAME)) {
            return oldStatus == 'Rejected by ED';
        }

        // 3. HOD User
        if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HOD_PROFILE_NAME)) {
            return oldStatus == 'Rejected by HR' || oldStatus == 'Rejected by ED';
        }

        // 4. Standard System Admin / Utkarsh Admin (without Utkarsh ED role)
        if (String.isNotBlank(profileName) && (profileName.equalsIgnoreCase('System Administrator') || profileName.equalsIgnoreCase('Utkarsh Admin'))) {
            return oldStatus == 'Rejected by HOD' || oldStatus == 'Rejected by HR' || oldStatus == 'Rejected by ED';
        }

        // 5. Normal User (All other users/profiles)
        return oldStatus == 'Rejected by HOD' || oldStatus == 'Rejected by HR' || oldStatus == 'Rejected by ED';
    }

    /**
     * @description Before Update trigger logic.
     *              Restricts updates on Expense__c records after creation:
     *              1. Roll-up summary changes (Total_Amount__c) are allowed in all cases.
     *              2. Updates to Status__c, Remark__c, Approver__c, and Approval_Date__c are only allowed
     *                 for authorized approvers:
     *                 - Utkarsh HOD: only when status is 'Pending HOD Approval'
     *                 - Utkarsh HR: only when status is 'Pending HR Approval'
     *                 - System Admin with role 'Utkarsh ED': only when status is 'Pending ED Approval'
     *              3. Editing general fields is allowed for rejected expenses when submitted via newExpenseForm LWC.
     *              4. Editing any other fields is strictly prohibited for all users.
     * @param newExpenses List of updated Expense__c records (Trigger.new)
     * @param oldExpensesMap Map of original Expense__c records (Trigger.oldMap)
     */
    public static void beforeUpdate(List<Expense__c> newExpenses, Map<Id, Expense__c> oldExpensesMap) {
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Expense__c.fields.getMap();
        Boolean isApprover = isAuthorizedApprover();

        for (Expense__c newExpense : newExpenses) {
            Expense__c oldExpense = oldExpensesMap.get(newExpense.Id);
            if (oldExpense == null) {
                continue;
            }

            // Case: Resubmission of a rejected expense through newExpenseForm LWC
            if (isLwcContext && isAllowedToReEditRejectedExpense(oldExpense.Status__c)) {
                continue;
            }

            Boolean hasDisallowedChanges = false;
            Boolean hasApprovalFieldChanges = false;

            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldsMap.get(fieldName).getDescribe();
                String actualFieldName = dfr.getName();

                // Skip non-updateable, calculated (including roll-up summary Total_Amount__c and formula fields), and Id/system fields
                if (actualFieldName.equalsIgnoreCase('Id') ||
                    dfr.isCalculated() ||
                    !dfr.isUpdateable()) {
                    continue;
                }

                if (newExpense.get(actualFieldName) != oldExpense.get(actualFieldName)) {
                    // Check if this field is one of the allowed approval fields (case-insensitive check)
                    Boolean isApprovalField = false;
                    for (String allowedField : ALLOWED_APPROVAL_FIELDS) {
                        if (allowedField.equalsIgnoreCase(actualFieldName)) {
                            isApprovalField = true;
                            break;
                        }
                    }

                    if (isApprovalField) {
                        hasApprovalFieldChanges = true;
                    } else {
                        hasDisallowedChanges = true;
                    }
                }
            }

            if (hasDisallowedChanges) {
                // If any general field (e.g. Subject__c, Travel_Start_Date__c, etc.) was edited, block it
                newExpense.addError(EDIT_RESTRICTED_MSG);
            } else if (hasApprovalFieldChanges) {
                if (!isApprover) {
                    // If only approval fields were changed, but user is not an authorized approver, block it
                    newExpense.addError(APPROVAL_RESTRICTED_MSG);
                } else {
                    String profileName = getCurrentUserProfile();
                    // If user is Utkarsh HOD, only allow changes when Status__c is 'Pending HOD Approval'
                    if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HOD_PROFILE_NAME) && oldExpense.Status__c != STATUS_PENDING_HOD) {
                        newExpense.addError(HOD_RESTRICTED_MSG);
                    }
                    // If user is Utkarsh HR, only allow changes when Status__c is 'Pending HR Approval'
                    else if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HR_PROFILE_NAME) && oldExpense.Status__c != STATUS_PENDING_HR) {
                        newExpense.addError(HR_RESTRICTED_MSG);
                    }
                    else {
                        // If user has the role 'Utkarsh ED', only allow changes when Status__c is 'Pending ED Approval'
                        String roleName = getCurrentUserRole();
                        if (String.isNotBlank(roleName) && roleName.equalsIgnoreCase(CLIENT_ADMIN_ROLE) && oldExpense.Status__c != STATUS_PENDING_ED) {
                            newExpense.addError(CLIENT_ADMIN_RESTRICTED_MSG);
                        }
                    }
                }
            }
        }
    }
    
    /**
     * @description Before Delete trigger logic
     *              Prevents deletion of Expense__c records unless initiated from newExpenseForm LWC.
     * @param oldExpenses List of expense records to be deleted (Trigger.old)
     */
    public static void beforeDelete(List<Expense__c> oldExpenses) {
        if (!isLwcContext) {
            for (Expense__c expense : oldExpenses) {
                expense.addError(DELETE_ERROR_MSG);
            }
        }
    }
}