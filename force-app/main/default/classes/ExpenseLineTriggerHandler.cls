/**
 * @description Trigger Handler for Expense_Line__c object.
 *              Enforces business rules on edit and deletion of Expense Line records:
 *              1. Prevents deletion of Expense_Line__c for all users.
 *              2. Prevents edits on Expense_Line__c for all users UNLESS:
 *                 a. The user has the 'Custom_Permission_for_Expense' permission set / custom permission.
 *                 b. The edit is performed via the newExpenseForm LWC context (reparenting Expense__c).
 * @author      Salesforce Developer
 * @date        2026
 */
public with sharing class ExpenseLineTriggerHandler {

    /**
     * @description Static flag set by NewExpenseFormController to allow reparenting
     *              of Expense_Line__c records during expense submission from LWC.
     */
    public static Boolean isLwcContext = false;

    // public static final String PERMISSION_NAME = 'Custom_Permission_for_Expense';
    public static final String DELETE_ERROR_MSG = 'Expense Line records cannot be deleted.';
    public static final String EDIT_RESTRICTED_MSG = 'Editing Expense Line records is not permitted.';

    public static final String HR_PROFILE_NAME = 'Utkarsh HR';
    public static final String HOD_PROFILE_NAME = 'Utkarsh HOD';
    public static final String CLIENT_ADMIN_ROLE = 'Utkarsh ED';

    public static final String STATUS_PENDING_HR = 'Pending HR Approval';
    public static final String STATUS_PENDING_HOD = 'Pending HOD Approval';
    public static final String STATUS_PENDING_ED = 'Pending ED Approval';

    public static final String HR_EDIT_RESTRICTED_MSG = 'Expense line details can only be edited by HR when the expense is in Pending HR Approval status.';
    public static final String HOD_EDIT_RESTRICTED_MSG = 'Expense line details can only be edited by HOD when the expense is in Pending HOD Approval status.';
    public static final String CLIENT_ADMIN_EDIT_RESTRICTED_MSG = 'Expense line details can only be edited when the expense is in Pending ED Approval status.';

    public static final Set<String> ALLOWED_EDIT_FIELDS = new Set<String>{
        'Approved_Amount__c',
        'Justification__c'
    };

    /*
    @TestVisible
    private static Boolean hasPermissionOverride = null;
    */

    @TestVisible
    private static String currentUserProfileNameOverride = null;

    @TestVisible
    private static String currentUserRoleNameOverride = null;

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
     * @description Checks if the running user is allowed to re-edit/re-submit a rejected expense via newExpenseForm LWC.
     *              - Normal user: 'Rejected by HOD', 'Rejected by HR', 'Rejected by ED'
     *              - Utkarsh HOD: 'Rejected by HR', 'Rejected by ED'
     *              - Utkarsh HR: 'Rejected by ED'
     *              - System Admin with role 'Utkarsh ED': 'Rejected by ED'
     *              - Standard System Admin / Utkarsh Admin: 'Rejected by HOD', 'Rejected by HR', 'Rejected by ED'
     * @param oldStatus The Status__c of the parent Expense__c record.
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
     * @description Checks if the current user has the HR profile.
     * @return Boolean True if HR, false otherwise.
     */
    public static Boolean isHrUser() {
        return getCurrentUserProfile().equalsIgnoreCase(HR_PROFILE_NAME);
    }

    /**
     * @description Handles before delete operations on Expense_Line__c.
     *              Prevents deletion of Expense_Line__c records unless initiated from newExpenseForm LWC.
     * @param oldLines List of Expense_Line__c records to be deleted (Trigger.old)
     */
    public static void beforeDelete(List<Expense_Line__c> oldLines) {
        if (!isLwcContext) {
            for (Expense_Line__c line : oldLines) {
                line.addError(DELETE_ERROR_MSG);
            }
        }
    }

    /**
     * @description Handles before update operations on Expense_Line__c.
     *              Restricts updates unless:
     *              1. Called from newExpenseForm LWC context (reparenting Expense__c or resubmitting rejected expenses).
     *              2. User is Utkarsh HR editing Approved_Amount__c/Justification__c when parent status is Pending HR Approval.
     *              3. User is Utkarsh HOD editing Approved_Amount__c/Justification__c when parent status is Pending HOD Approval.
     *              4. User is System Admin with role 'Utkarsh ED' editing Approved_Amount__c/Justification__c when parent status is Pending ED Approval.
     * @param newLines List of updated Expense_Line__c records (Trigger.new)
     * @param oldLinesMap Map of original Expense_Line__c records (Trigger.oldMap)
     */
    public static void beforeUpdate(List<Expense_Line__c> newLines, Map<Id, Expense_Line__c> oldLinesMap) {
        // Collect parent expense IDs for querying parent status
        Set<Id> parentExpenseIds = new Set<Id>();
        for (Expense_Line__c newLine : newLines) {
            if (newLine.Expense__c != null) {
                parentExpenseIds.add(newLine.Expense__c);
            }
        }

        Map<Id, Expense__c> parentExpenses = new Map<Id, Expense__c>();
        if (!parentExpenseIds.isEmpty()) {
            parentExpenses = new Map<Id, Expense__c>([
                SELECT Id, Status__c 
                FROM Expense__c 
                WHERE Id IN :parentExpenseIds
            ]);
        }

        String profileName = getCurrentUserProfile();
        String roleName = getCurrentUserRole();

        for (Expense_Line__c newLine : newLines) {
            Expense_Line__c oldLine = oldLinesMap.get(newLine.Id);
            Set<String> changedFields = getChangedUpdateableFields(newLine, oldLine);

            if (changedFields.isEmpty()) {
                // No updateable field changed
                continue;
            }

            Expense__c parentExp = (newLine.Expense__c != null) ? parentExpenses.get(newLine.Expense__c) : null;
            String parentStatus = (parentExp != null) ? parentExp.Status__c : null;

            // Case 1: Handled via newExpenseForm LWC context
            if (isLwcContext) {
                // If the parent expense is in an allowed rejected status, allow full line re-edit
                if (isAllowedToReEditRejectedExpense(parentStatus)) {
                    continue;
                }

                // If reparenting private vehicle lines / initializing approved amount from LWC
                Boolean onlyLwcAllowed = true;
                for (String fieldName : changedFields) {
                    if (!fieldName.equalsIgnoreCase('Expense__c') && !fieldName.equalsIgnoreCase('Approved_Amount__c')) {
                        onlyLwcAllowed = false;
                        break;
                    }
                }
                if (onlyLwcAllowed) {
                    continue;
                }
            }

            // Check if only allowed edit fields (Approved_Amount__c, Justification__c) were modified
            Boolean onlyAllowedFieldsChanged = true;
            for (String fieldName : changedFields) {
                Boolean isAllowed = false;
                for (String allowedField : ALLOWED_EDIT_FIELDS) {
                    if (allowedField.equalsIgnoreCase(fieldName)) {
                        isAllowed = true;
                        break;
                    }
                }
                if (!isAllowed) {
                    onlyAllowedFieldsChanged = false;
                    break;
                }
            }

            if (onlyAllowedFieldsChanged) {
                // Case 2: HR user editing Approved_Amount__c / Justification__c
                if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HR_PROFILE_NAME)) {
                    if (parentStatus == STATUS_PENDING_HR) {
                        continue;
                    } else {
                        newLine.addError(HR_EDIT_RESTRICTED_MSG);
                        continue;
                    }
                }

                // Case 3: HOD user editing Approved_Amount__c / Justification__c
                if (String.isNotBlank(profileName) && profileName.equalsIgnoreCase(HOD_PROFILE_NAME)) {
                    if (parentStatus == STATUS_PENDING_HOD) {
                        continue;
                    } else {
                        newLine.addError(HOD_EDIT_RESTRICTED_MSG);
                        continue;
                    }
                }

                // Case 4: System Admin with role 'Utkarsh ED' editing Approved_Amount__c / Justification__c
                if (String.isNotBlank(roleName) && roleName.equalsIgnoreCase(CLIENT_ADMIN_ROLE)) {
                    if (parentStatus == STATUS_PENDING_ED) {
                        continue;
                    } else {
                        newLine.addError(CLIENT_ADMIN_EDIT_RESTRICTED_MSG);
                        continue;
                    }
                }
            }

            // In all other cases, edits are not permitted
            newLine.addError(EDIT_RESTRICTED_MSG);
        }
    }

    /**
     * @description Returns the set of updateable field names that were modified.
     * @param newLine The updated record from Trigger.new
     * @param oldLine The original record from Trigger.old
     * @return Set<String> Set of changed field API names.
     */
    private static Set<String> getChangedUpdateableFields(Expense_Line__c newLine, Expense_Line__c oldLine) {
        Set<String> changedFields = new Set<String>();
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Expense_Line__c.fields.getMap();

        for (String fieldName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldsMap.get(fieldName).getDescribe();
            String actualFieldName = dfr.getName();

            // Skip Id, calculated (formulas, etc.), and non-updateable fields
            if (actualFieldName.equalsIgnoreCase('Id') ||
                dfr.isCalculated() ||
                !dfr.isUpdateable()) {
                continue;
            }

            if (newLine.get(actualFieldName) != oldLine.get(actualFieldName)) {
                changedFields.add(actualFieldName);
            }
        }
        return changedFields;
    }

    /*
    @description Checks if the running user has Custom Permission or Permission Set assigned.
    @return Boolean True if user has the permission, false otherwise.
    public static Boolean hasExpensePermission() {
        if (Test.isRunningTest() && hasPermissionOverride != null) {
            return hasPermissionOverride;
        }

        // Check Custom Permission
        if (FeatureManagement.checkPermission(PERMISSION_NAME)) {
            return true;
        }

        // Check Permission Set Assignment
        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND (PermissionSet.Name = :PERMISSION_NAME OR PermissionSet.Label = :PERMISSION_NAME)
            LIMIT 1
        ];

        return !assignments.isEmpty();
    }
    */
}