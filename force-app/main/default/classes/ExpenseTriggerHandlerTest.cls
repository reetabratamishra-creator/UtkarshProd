/**
 * @description Test class for ExpenseTriggerHandler.
 * Invokes handler methods directly so org validation/flows cannot
 * hide trigger field updates during DML.
 */
@IsTest
private class ExpenseTriggerHandlerTest {
  private static Expense__c insertDraftExpense() {
    Expense__c expense = new Expense__c();
    insert as system expense;
    return expense;
  }

  @IsTest
  static void testBeforeInsertDefaults() {
    Expense__c expense = new Expense__c();
    ExpenseTriggerHandler.beforeInsert(new List<Expense__c>{ expense });

    System.assertEquals('New', expense.Status__c);
    System.assertEquals(UserInfo.getUserId(), expense.Employee__c);
  }

  /* @IsTest
  static void testAfterUpdateCollectsSubmittedExpenses() {
    Expense__c inserted = insertDraftExpense();
    Expense__c oldExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Draft',
      Employee__c = UserInfo.getUserId()
    );
    Expense__c newExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Submitted',
      Employee__c = UserInfo.getUserId()
    );

    Test.startTest();
    ExpenseTriggerHandler.beforeUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );
    ExpenseTriggerHandler.afterUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );
    Test.stopTest();

    System.assertEquals('Submitted', newExpense.Status__c);
    System.assertEquals(Date.today(), newExpense.Submitted_Date__c);
  } */

  /* @IsTest
  static void testBeforeUpdateApprovedPath() {
    Expense__c inserted = insertDraftExpense();
    Expense__c oldExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Submitted',
      Employee__c = UserInfo.getUserId()
    );
    Expense__c newExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Approved',
      Employee__c = UserInfo.getUserId()
    );

    Test.startTest();
    ExpenseTriggerHandler.beforeUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );
    ExpenseTriggerHandler.afterUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );
    Test.stopTest();

    System.assertEquals('Approved', newExpense.Status__c);
    System.assertEquals(Date.today(), newExpense.Approval_Date__c);
    System.assertEquals(UserInfo.getUserId(), newExpense.Approver__c);
  } */

  /* @IsTest
  static void testBeforeDeleteBlocksNonDraft() {
    Expense__c inserted = insertDraftExpense();
    Expense__c submitted = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Submitted',
      Employee__c = UserInfo.getUserId()
    );

    Test.startTest();
    ExpenseTriggerHandler.beforeDelete(new List<Expense__c>{ submitted });
    Test.stopTest();

    System.assertEquals(true, submitted.hasErrors());
  } */

  @IsTest
  static void testBeforeInsertKeepsProvidedValues() {
    Expense__c expense = new Expense__c(
      Status__c = 'Pending HOD Approval',
      Employee__c = UserInfo.getUserId()
    );
    ExpenseTriggerHandler.beforeInsert(new List<Expense__c>{ expense });
    System.assertEquals('Pending HOD Approval', expense.Status__c);
    System.assertEquals(UserInfo.getUserId(), expense.Employee__c);
  }

  /*@IsTest
  static void testBeforeUpdateBlocksApprovedModification() {
    Expense__c inserted = insertDraftExpense();
    Expense__c oldExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Approved'
    );
    Expense__c newExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Draft'
    );

    ExpenseTriggerHandler.beforeUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );

    System.assertEquals(true, newExpense.hasErrors());
  }*/

  /*@IsTest
  static void testBeforeUpdateAllowsReimbursedFromApproved() {
    Expense__c inserted = insertDraftExpense();
    Expense__c oldExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Approved'
    );
    Expense__c newExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Reimbursed'
    );

    ExpenseTriggerHandler.beforeUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );

    System.assertEquals(false, newExpense.hasErrors());
  }*/

  /* @IsTest
  static void testAfterInsertAndRejectedAfterUpdate() {
    Expense__c inserted = insertDraftExpense();
    ExpenseTriggerHandler.afterInsert(new List<Expense__c>{ inserted });

    Expense__c oldExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Submitted'
    );
    Expense__c newExpense = new Expense__c(
      Id = inserted.Id,
      Status__c = 'Rejected'
    );

    ExpenseTriggerHandler.afterUpdate(
      new List<Expense__c>{ newExpense },
      new Map<Id, Expense__c>{ inserted.Id => oldExpense }
    );

    System.assertEquals('Rejected', newExpense.Status__c);
  } */

  @IsTest
  static void testDeleteBlockedWhenNotInLwcContext() {
    Expense__c expense = insertDraftExpense();
    ExpenseTriggerHandler.isLwcContext = false;

    Test.startTest();
    try {
      delete expense;
      System.assert(false, 'Exception should have been thrown preventing deletion outside LWC context');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains(ExpenseTriggerHandler.DELETE_ERROR_MSG),
        'Expected delete error message but received: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testDeleteAllowedWhenInLwcContext() {
    Expense__c expense = insertDraftExpense();

    Test.startTest();
    try {
      ExpenseTriggerHandler.isLwcContext = true;
      delete expense;
    } finally {
      ExpenseTriggerHandler.isLwcContext = false;
    }
    Test.stopTest();

    List<Expense__c> remaining = [SELECT Id FROM Expense__c WHERE Id = :expense.Id];
    System.assertEquals(0, remaining.size(), 'Expense should be successfully deleted in LWC context');
  }

  @IsTest
  static void testBeforeDeleteHandlerDirectInvocation() {
    Expense__c expenseBlocked = insertDraftExpense();
    ExpenseTriggerHandler.isLwcContext = false;
    ExpenseTriggerHandler.beforeDelete(new List<Expense__c>{ expenseBlocked });
    System.assertEquals(true, expenseBlocked.hasErrors(), 'Should add error when not in LWC context');

    Expense__c expenseAllowed = insertDraftExpense();
    ExpenseTriggerHandler.isLwcContext = true;
    ExpenseTriggerHandler.beforeDelete(new List<Expense__c>{ expenseAllowed });
    System.assertEquals(false, expenseAllowed.hasErrors(), 'Should not add error when in LWC context');
    ExpenseTriggerHandler.isLwcContext = false;
  }

  @IsTest
  static void testTriggerBypassViaTriggerEnableService() {
    TriggerEnableService.setTestOverride(TriggerEnableService.EXPENSE_TRIGGER, false);
    Expense__c expense = insertDraftExpense();
    ExpenseTriggerHandler.isLwcContext = false;

    Test.startTest();
    delete expense;
    Test.stopTest();

    List<Expense__c> remaining = [SELECT Id FROM Expense__c WHERE Id = :expense.Id];
    System.assertEquals(0, remaining.size(), 'Expense should be deleted when trigger is bypassed');
  }

  @IsTest
  static void testBeforeUpdate_BlockedForGeneralFieldEdit() {
    Expense__c expense = insertDraftExpense();
    expense.Subject__c = 'Modified Subject';

    Test.startTest();
    try {
      update expense;
      System.assert(false, 'Should throw DmlException when modifying general fields after creation');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains(ExpenseTriggerHandler.EDIT_RESTRICTED_MSG),
        'Expected edit restricted error message but received: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testBeforeUpdate_AllowedForAuthorizedApprover() {
    Expense__c expense = insertDraftExpense();
    ExpenseTriggerHandler.isAuthorizedApproverOverride = true;

    expense.Status__c = 'Pending HR Approval';
    expense.Remark__c = 'Approved by HOD';
    expense.Approver__c = UserInfo.getUserId();
    expense.Approval_Date__c = Date.today();

    Test.startTest();
    try {
      update expense;
    } finally {
      ExpenseTriggerHandler.isAuthorizedApproverOverride = null;
    }
    Test.stopTest();

    Expense__c updatedExp = [SELECT Status__c, Remark__c, Approver__c, Approval_Date__c FROM Expense__c WHERE Id = :expense.Id];
    System.assertEquals('Pending HR Approval', updatedExp.Status__c);
    System.assertEquals('Approved by HOD', updatedExp.Remark__c);
    System.assertEquals(UserInfo.getUserId(), updatedExp.Approver__c);
    System.assertEquals(Date.today(), updatedExp.Approval_Date__c);
  }

  @IsTest
  static void testBeforeUpdate_BlockedForUnauthorizedApprover() {
    Expense__c expense = insertDraftExpense();
    ExpenseTriggerHandler.isAuthorizedApproverOverride = false;

    expense.Status__c = 'Pending HR Approval';

    Test.startTest();
    try {
      update expense;
      System.assert(false, 'Should throw DmlException when unauthorized user attempts status change');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains(ExpenseTriggerHandler.APPROVAL_RESTRICTED_MSG),
        'Expected approval restricted error message but received: ' + e.getMessage()
      );
    } finally {
      ExpenseTriggerHandler.isAuthorizedApproverOverride = null;
    }
    Test.stopTest();
  }

  @IsTest
  static void testBeforeUpdate_DirectInvocationNoChangesAllowed() {
    Expense__c insertedExp = insertDraftExpense();
    Expense__c oldExp = new Expense__c(Id = insertedExp.Id, Status__c = 'New');
    Expense__c newExp = new Expense__c(Id = insertedExp.Id, Status__c = 'New');

    Test.startTest();
    ExpenseTriggerHandler.beforeUpdate(new List<Expense__c>{ newExp }, new Map<Id, Expense__c>{ insertedExp.Id => oldExp });
    Test.stopTest();

    System.assertEquals(false, newExp.hasErrors(), 'Untouched record should not have errors');
  }

  @IsTest
  static void testIsAuthorizedApproverDefault() {
    ExpenseTriggerHandler.isAuthorizedApproverOverride = null;
    Test.startTest();
    Boolean isAuthorized = ExpenseTriggerHandler.isAuthorizedApprover();
    Test.stopTest();
    // System Administrator running the test is in ALLOWED_APPROVAL_PROFILES
    System.assertEquals(true, isAuthorized);
  }

  @IsTest
  static void testBeforeUpdate_UtkarshBansalRoleAllowedWhenPendingED() {
    Expense__c expense = new Expense__c(
      Status__c = 'Pending ED Approval',
      Employee__c = UserInfo.getUserId()
    );
    insert as system expense;

    ExpenseTriggerHandler.isAuthorizedApproverOverride = true;
    ExpenseTriggerHandler.currentUserRoleNameOverride = 'Utkarsh ED';

    expense.Status__c = 'Approved by ED';
    expense.Approval_Date__c = Date.today();
    expense.Approver__c = UserInfo.getUserId();

    Test.startTest();
    try {
      update expense;
    } finally {
      ExpenseTriggerHandler.isAuthorizedApproverOverride = null;
      ExpenseTriggerHandler.currentUserRoleNameOverride = null;
    }
    Test.stopTest();

    Expense__c updatedExp = [SELECT Status__c FROM Expense__c WHERE Id = :expense.Id];
    System.assertEquals('Approved by ED', updatedExp.Status__c);
  }

  @IsTest
  static void testBeforeUpdate_UtkarshBansalRoleBlockedWhenNotPendingED() {
    Expense__c expense = new Expense__c(
      Status__c = 'Pending HOD Approval',
      Employee__c = UserInfo.getUserId()
    );
    insert as system expense;

    ExpenseTriggerHandler.isAuthorizedApproverOverride = true;
    ExpenseTriggerHandler.currentUserRoleNameOverride = 'Utkarsh ED';

    expense.Status__c = 'Pending HR Approval';

    Test.startTest();
    try {
      update expense;
      System.assert(false, 'Expected DmlException when user with role Utkarsh ED tries to edit non-Pending ED Approval expense');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains(ExpenseTriggerHandler.CLIENT_ADMIN_RESTRICTED_MSG),
        'Expected client admin restricted error message but received: ' + e.getMessage()
      );
    } finally {
      ExpenseTriggerHandler.isAuthorizedApproverOverride = null;
      ExpenseTriggerHandler.currentUserRoleNameOverride = null;
    }
    Test.stopTest();
  }

  @IsTest
  static void testBeforeUpdate_NormalUserReEditRejectedInLwcContext() {
    Expense__c expHOD = new Expense__c(Status__c = 'Rejected by HOD', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    insert as system expHOD;

    ExpenseTriggerHandler.isLwcContext = true;
    expHOD.Subject__c = 'Updated by Normal User';
    expHOD.Status__c = 'Pending HOD Approval';

    Test.startTest();
    try {
      update expHOD;
    } finally {
      ExpenseTriggerHandler.isLwcContext = false;
    }
    Test.stopTest();

    Expense__c res = [SELECT Subject__c, Status__c FROM Expense__c WHERE Id = :expHOD.Id];
    System.assertEquals('Updated by Normal User', res.Subject__c);
    System.assertEquals('Pending HOD Approval', res.Status__c);
  }

  @IsTest
  static void testBeforeUpdate_NormalUserReEditRejectedOutsideLwcBlocked() {
    Expense__c expHOD = new Expense__c(Status__c = 'Rejected by HOD', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    insert as system expHOD;

    ExpenseTriggerHandler.isLwcContext = false;
    expHOD.Subject__c = 'Updated Outside LWC';

    Test.startTest();
    try {
      update expHOD;
      System.assert(false, 'Expected DmlException when normal user edits rejected expense outside LWC context');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains(ExpenseTriggerHandler.EDIT_RESTRICTED_MSG),
        'Expected edit restricted message but received: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testBeforeUpdate_HodUserReEditRejectedScenarios() {
    Expense__c expHR = new Expense__c(Status__c = 'Rejected by HR', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    Expense__c expHOD = new Expense__c(Status__c = 'Rejected by HOD', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    insert as system new List<Expense__c>{ expHR, expHOD };

    ExpenseTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HOD';
    ExpenseTriggerHandler.isLwcContext = true;

    Test.startTest();
    try {
      // Allowed: HOD can re-edit when Rejected by HR
      expHR.Subject__c = 'HOD Resubmitted';
      expHR.Status__c = 'Pending HR Approval';
      update expHR;

      // Blocked: HOD cannot re-edit when Rejected by HOD
      expHOD.Subject__c = 'HOD Attempted';
      try {
        update expHOD;
        System.assert(false, 'Expected DmlException when HOD tries to re-edit Rejected by HOD expense');
      } catch (DmlException e) {
        System.assert(e.getMessage().contains(ExpenseTriggerHandler.EDIT_RESTRICTED_MSG));
      }
    } finally {
      ExpenseTriggerHandler.currentUserProfileNameOverride = null;
      ExpenseTriggerHandler.isLwcContext = false;
    }
    Test.stopTest();
  }

  @IsTest
  static void testBeforeUpdate_HrAndEdUserReEditRejectedScenarios() {
    Expense__c expED = new Expense__c(Status__c = 'Rejected by ED', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    Expense__c expHR = new Expense__c(Status__c = 'Rejected by HR', Employee__c = UserInfo.getUserId(), Subject__c = 'Original');
    insert as system new List<Expense__c>{ expED, expHR };

    ExpenseTriggerHandler.currentUserProfileNameOverride = 'Utkarsh HR';
    ExpenseTriggerHandler.isLwcContext = true;

    Test.startTest();
    try {
      // Allowed: HR can re-edit when Rejected by ED
      expED.Subject__c = 'HR Resubmitted';
      expED.Status__c = 'Pending ED Approval';
      update expED;

      // Blocked: HR cannot re-edit when Rejected by HR
      expHR.Subject__c = 'HR Attempted';
      try {
        update expHR;
        System.assert(false, 'Expected DmlException when HR tries to re-edit Rejected by HR expense');
      } catch (DmlException e) {
        System.assert(e.getMessage().contains(ExpenseTriggerHandler.EDIT_RESTRICTED_MSG));
      }
    } finally {
      ExpenseTriggerHandler.currentUserProfileNameOverride = null;
      ExpenseTriggerHandler.isLwcContext = false;
    }
    Test.stopTest();
  }
}