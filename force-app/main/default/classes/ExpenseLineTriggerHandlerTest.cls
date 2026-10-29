/**
 * @description Unit tests for ExpenseLineTrigger and ExpenseLineTriggerHandler.
 * @author      Salesforce Developer
 * @date        2026
 */
@IsTest
private class ExpenseLineTriggerHandlerTest {

    @TestSetup
    static void setupData() {
        Expense__c exp1 = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'New',
            Purpose__c = 'Initial Expense'
        );
        Expense__c exp2 = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HOD Approval',
            Purpose__c = 'Target Expense'
        );
        insert new List<Expense__c>{ exp1, exp2 };

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = exp1.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;
    }

    @IsTest
    static void testDeleteBlocked() {
        Expense_Line__c line = [SELECT Id FROM Expense_Line__c LIMIT 1];

        Test.startTest();
        try {
            delete line;
            System.assert(false, 'Exception should have been thrown preventing deletion');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.DELETE_ERROR_MSG),
                'Expected delete error message but received: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testEditOtherFieldsBlockedWithoutPermission() {
        Expense_Line__c line = [SELECT Id, Amount__c FROM Expense_Line__c LIMIT 1];
        // ExpenseLineTriggerHandler.hasPermissionOverride = false;
        ExpenseLineTriggerHandler.isLwcContext = false;

        line.Amount__c = 999;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Exception should have been thrown preventing edit without permission');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG),
                'Expected restricted edit error message but received: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testReparentExpenseAllowedFromLwcContext() {
        Expense__c exp2 = [SELECT Id FROM Expense__c WHERE Purpose__c = 'Target Expense' LIMIT 1];
        Expense_Line__c line = [SELECT Id, Expense__c FROM Expense_Line__c LIMIT 1];
        // ExpenseLineTriggerHandler.hasPermissionOverride = false;

        line.Expense__c = exp2.Id;

        Test.startTest();
        try {
            ExpenseLineTriggerHandler.isLwcContext = true;
            update line;
        } finally {
            ExpenseLineTriggerHandler.isLwcContext = false;
        }
        Test.stopTest();

        Expense_Line__c updatedLine = [SELECT Id, Expense__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(exp2.Id, updatedLine.Expense__c, 'Expense line parent should be updated from LWC context');
    }

    @IsTest
    static void testReparentExpenseBlockedWhenNotInLwcContext() {
        Expense__c exp2 = [SELECT Id FROM Expense__c WHERE Purpose__c = 'Target Expense' LIMIT 1];
        Expense_Line__c line = [SELECT Id, Expense__c FROM Expense_Line__c LIMIT 1];
        // ExpenseLineTriggerHandler.hasPermissionOverride = false;
        ExpenseLineTriggerHandler.isLwcContext = false;

        line.Expense__c = exp2.Id;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Exception should have been thrown for reparenting outside LWC context without permission');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG),
                'Expected restricted error message but received: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testReparentExpenseBlockedWhenMultipleFieldsChangedEvenInLwcContext() {
        Expense__c exp2 = [SELECT Id FROM Expense__c WHERE Purpose__c = 'Target Expense' LIMIT 1];
        Expense_Line__c line = [SELECT Id, Expense__c, Amount__c FROM Expense_Line__c LIMIT 1];
        // ExpenseLineTriggerHandler.hasPermissionOverride = false;

        line.Expense__c = exp2.Id;
        line.Amount__c = 2000;

        Test.startTest();
        try {
            ExpenseLineTriggerHandler.isLwcContext = true;
            update line;
            System.assert(false, 'Exception should have been thrown when editing fields alongside Expense__c without permission');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG),
                'Expected restricted edit error message but received: ' + e.getMessage()
            );
        } finally {
            ExpenseLineTriggerHandler.isLwcContext = false;
        }
        Test.stopTest();
    }

    /*
    @IsTest
    static void testEditAllowedWithPermissionOverride() {
        Expense_Line__c line = [SELECT Id, Amount__c, Description__c FROM Expense_Line__c LIMIT 1];
        ExpenseLineTriggerHandler.hasPermissionOverride = true;
        ExpenseLineTriggerHandler.isLwcContext = false;

        line.Amount__c = 3000;
        line.Description__c = 'Updated with privileged permission';

        Test.startTest();
        update line;
        Test.stopTest();

        Expense_Line__c updatedLine = [SELECT Id, Amount__c, Description__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(3000, updatedLine.Amount__c, 'Amount should be updated successfully');
        System.assertEquals('Updated with privileged permission', updatedLine.Description__c, 'Description should be updated successfully');
    }
    */

    @IsTest
    static void testTriggerBypassViaTriggerEnableService() {
        TriggerEnableService.setTestOverride(TriggerEnableService.EXPENSE_LINE_TRIGGER, false);
        Expense_Line__c line = [SELECT Id FROM Expense_Line__c LIMIT 1];

        Test.startTest();
        delete line;
        Test.stopTest();

        List<Expense_Line__c> remainingLines = [SELECT Id FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(0, remainingLines.size(), 'Line should be deleted when trigger is disabled');
    }

    /*
    @IsTest
    static void testHasExpensePermissionMethod() {
        ExpenseLineTriggerHandler.hasPermissionOverride = null;
        Test.startTest();
        Boolean hasPerm = ExpenseLineTriggerHandler.hasExpensePermission();
        Test.stopTest();
        System.assertNotEquals(null, hasPerm, 'Permission check should return a boolean value');
    }
    */

    @IsTest
    static void testHrEditAllowedWhenPendingHrApproval() {
        Expense__c hrExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HR Approval',
            Purpose__c = 'HR Approval Test Expense'
        );
        insert hrExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hrExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HR';

        line.Approved_Amount__c = 650;
        line.Justification__c = 'Adjusted by HR during audit';

        Test.startTest();
        try {
            update line;
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();

        Expense_Line__c updatedLine = [SELECT Id, Approved_Amount__c, Justification__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(650, updatedLine.Approved_Amount__c);
        System.assertEquals('Adjusted by HR during audit', updatedLine.Justification__c);
    }

    @IsTest
    static void testHrEditBlockedWhenNotPendingHrApproval() {
        Expense__c hodExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HOD Approval',
            Purpose__c = 'HOD Stage Expense'
        );
        insert hodExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hodExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HR';

        line.Approved_Amount__c = 750;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Expected DmlException when HR attempts edit on non-Pending HR Approval expense');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.HR_EDIT_RESTRICTED_MSG),
                'Expected HR restricted edit error message but received: ' + e.getMessage()
            );
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testHrEditOtherFieldsBlockedEvenWhenPendingHrApproval() {
        Expense__c hrExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HR Approval',
            Purpose__c = 'HR Disallowed Edit Expense'
        );
        insert hrExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hrExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HR';

        line.City_Tier__c = 'Tier 2';

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Expected DmlException when HR attempts to edit fields other than Approved_Amount/Justification');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG),
                'Expected edit restricted error message but received: ' + e.getMessage()
            );
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testHodEditAllowedWhenPendingHodApproval() {
        Expense__c hodExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HOD Approval',
            Purpose__c = 'HOD Approval Test Expense'
        );
        insert hodExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hodExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HOD';

        line.Approved_Amount__c = 450;
        line.Justification__c = 'Approved lower by HOD';

        Test.startTest();
        try {
            update line;
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();

        Expense_Line__c updatedLine = [SELECT Id, Approved_Amount__c, Justification__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(450, updatedLine.Approved_Amount__c);
        System.assertEquals('Approved lower by HOD', updatedLine.Justification__c);
    }

    @IsTest
    static void testHodEditBlockedWhenNotPendingHodApproval() {
        Expense__c hrExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HR Approval',
            Purpose__c = 'HR Stage Expense'
        );
        insert hrExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hrExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HOD';

        line.Approved_Amount__c = 450;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Expected DmlException when HOD attempts edit on non-Pending HOD Approval expense');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.HOD_EDIT_RESTRICTED_MSG),
                'Expected HOD restricted edit error message but received: ' + e.getMessage()
            );
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testUtkarshEdRoleEditAllowedWhenPendingEdApproval() {
        Expense__c edExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending ED Approval',
            Purpose__c = 'ED Approval Test Expense'
        );
        insert edExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = edExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserRoleNameOverride = 'Utkarsh ED';

        line.Approved_Amount__c = 400;
        line.Justification__c = 'Adjusted by ED';

        Test.startTest();
        try {
            update line;
        } finally {
            ExpenseLineTriggerHandler.currentUserRoleNameOverride = null;
        }
        Test.stopTest();

        Expense_Line__c updatedLine = [SELECT Id, Approved_Amount__c, Justification__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(400, updatedLine.Approved_Amount__c);
        System.assertEquals('Adjusted by ED', updatedLine.Justification__c);
    }

    @IsTest
    static void testUtkarshEdRoleEditBlockedWhenNotPendingEdApproval() {
        Expense__c hodExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Pending HOD Approval',
            Purpose__c = 'HOD Stage Expense'
        );
        insert hodExpense;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = hodExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserRoleNameOverride = 'Utkarsh ED';

        line.Approved_Amount__c = 400;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Expected DmlException when user with Utkarsh ED role attempts edit on non-Pending ED Approval expense');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(ExpenseLineTriggerHandler.CLIENT_ADMIN_EDIT_RESTRICTED_MSG),
                'Expected ED restricted edit error message but received: ' + e.getMessage()
            );
        } finally {
            ExpenseLineTriggerHandler.currentUserRoleNameOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testReEditLineForRejectedExpenseInLwcContext_NormalUser() {
        Expense__c rejectedExp = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Rejected by HOD',
            Purpose__c = 'Rejected Expense'
        );
        insert rejectedExp;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = rejectedExp.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Standard User';
        ExpenseLineTriggerHandler.isLwcContext = true;

        line.Amount__c = 700;
        line.Approved_Amount__c = 700;
        line.City_Tier__c = 'Tier 2';

        Test.startTest();
        try {
            update line;
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
            ExpenseLineTriggerHandler.isLwcContext = false;
        }
        Test.stopTest();

        Expense_Line__c updated = [SELECT Amount__c, Approved_Amount__c, City_Tier__c FROM Expense_Line__c WHERE Id = :line.Id];
        System.assertEquals(700, updated.Amount__c);
        System.assertEquals(700, updated.Approved_Amount__c);
        System.assertEquals('Tier 2', updated.City_Tier__c);
    }

    @IsTest
    static void testReEditLineForRejectedExpenseOutsideLwcBlocked_NormalUser() {
        Expense__c rejectedExp = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Rejected by HOD',
            Purpose__c = 'Rejected Expense'
        );
        insert rejectedExp;

        Expense_Line__c line = new Expense_Line__c(
            Expense__c = rejectedExp.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Approved_Amount__c = 500,
            Date__c = Date.today()
        );
        insert line;

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Standard User';
        ExpenseLineTriggerHandler.isLwcContext = false;

        line.Amount__c = 700;

        Test.startTest();
        try {
            update line;
            System.assert(false, 'Expected DmlException when updating line outside LWC context even if rejected');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG));
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
        }
        Test.stopTest();
    }

    @IsTest
    static void testReEditLineForHodAndHrRejectedScenarios() {
        Expense__c expRejectedByHR = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Rejected by HR',
            Purpose__c = 'Rejected by HR'
        );
        Expense__c expRejectedByHOD = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'Rejected by HOD',
            Purpose__c = 'Rejected by HOD'
        );
        insert new List<Expense__c>{ expRejectedByHR, expRejectedByHOD };

        Expense_Line__c line1 = new Expense_Line__c(
            Expense__c = expRejectedByHR.Id,
            Expense_Type__c = 'Fooding',
            Amount__c = 500,
            Date__c = Date.today()
        );
        Expense_Line__c line2 = new Expense_Line__c(
            Expense__c = expRejectedByHOD.Id,
            Expense_Type__c = 'Fooding',
            Amount__c = 500,
            Date__c = Date.today()
        );
        insert new List<Expense_Line__c>{ line1, line2 };

        ExpenseLineTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HOD';
        ExpenseLineTriggerHandler.isLwcContext = true;

        Test.startTest();
        try {
            // HOD can re-edit line when parent is Rejected by HR
            line1.Amount__c = 600;
            update line1;

            // HOD cannot re-edit line when parent is Rejected by HOD
            line2.Amount__c = 600;
            try {
                update line2;
                System.assert(false, 'Expected DmlException when HOD re-edits line for Rejected by HOD expense');
            } catch (DmlException e) {
                System.assert(e.getMessage().contains(ExpenseLineTriggerHandler.EDIT_RESTRICTED_MSG));
            }
        } finally {
            ExpenseLineTriggerHandler.currentUserProfileNameOverride = null;
            ExpenseLineTriggerHandler.isLwcContext = false;
        }
        Test.stopTest();
    }
}