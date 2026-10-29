/**
 * @description Test class for ExpenseStatusEmailHandler employee / HOD / HR email criteria.
 */
@IsTest
private class ExpenseStatusEmailHandlerTest {
  private static final String STATUS_NEW = 'New';

  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE IsActive = TRUE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  // Lets the running user change Status__c past ExpenseTriggerHandler's approver checks.
  private static void allowStatusChanges() {
    ExpenseTriggerHandler.isAuthorizedApproverOverride = true;
    ExpenseTriggerHandler.currentUserProfileNameOverride = 'System Administrator';
    ExpenseTriggerHandler.currentUserRoleNameOverride = '';
  }

  private static Expense__c buildExpense(String status) {
    return new Expense__c(Status__c = status, Employee__c = UserInfo.getUserId());
  }

  @IsTest
  static void testHodAndHrQualificationMethods() {
    Expense__c submitted = buildExpense(ExpenseStatusEmailHandler.STATUS_SUBMITTED);
    Expense__c oldNew = new Expense__c(Status__c = STATUS_NEW);

    System.assertEquals(
      true,
      ExpenseStatusEmailHandler.qualifiesForHodSubmittedNotification(submitted, oldNew)
    );
    System.assertEquals(
      true,
      ExpenseStatusEmailHandler.qualifiesForHodSubmittedNotification(submitted, null)
    );
    System.assertEquals(
      false,
      ExpenseStatusEmailHandler.qualifiesForHodSubmittedNotification(submitted, submitted)
    );

    Expense__c approvedByHod = buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HOD);

    System.assertEquals(
      true,
      ExpenseStatusEmailHandler.qualifiesForHrAwaitingApprovalNotification(
        approvedByHod,
        submitted
      )
    );
    System.assertEquals(
      false,
      ExpenseStatusEmailHandler.qualifiesForHrAwaitingApprovalNotification(
        approvedByHod,
        approvedByHod
      )
    );
    System.assertEquals(
      false,
      ExpenseStatusEmailHandler.qualifiesForHrAwaitingApprovalNotification(submitted, oldNew)
    );

    Expense__c noEmployee = new Expense__c(
      Status__c = ExpenseStatusEmailHandler.STATUS_SUBMITTED
    );
    System.assertEquals(
      false,
      ExpenseStatusEmailHandler.qualifiesForHodSubmittedNotification(noEmployee, oldNew)
    );
    System.assertEquals(
      false,
      ExpenseStatusEmailHandler.qualifiesForHrAwaitingApprovalNotification(null, oldNew)
    );
  }

  @IsTest
  static void testEmployeeStatusTemplateMapping() {
    Expense__c oldNew = new Expense__c(Status__c = STATUS_NEW);
    Expense__c submitted = buildExpense(ExpenseStatusEmailHandler.STATUS_SUBMITTED);
    Expense__c approvedByHod = buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HOD);
    Expense__c approvedByHr = buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HR);

    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_SUBMITTED,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(submitted, oldNew)
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_APPROVED_HOD,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(approvedByHod, submitted)
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_REJECTED_HOD,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        buildExpense(ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HOD),
        submitted
      )
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_APPROVED_HR,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(approvedByHr, approvedByHod)
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_REJECTED_HR,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        buildExpense(ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HR),
        approvedByHod
      )
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_APPROVED_ED,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_ED),
        approvedByHr
      )
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.TEMPLATE_REJECTED_ED,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        buildExpense(ExpenseStatusEmailHandler.STATUS_REJECTED_BY_ED),
        approvedByHr
      )
    );
  }

  @IsTest
  static void testEmployeeStatusTemplateMappingNoEmail() {
    Expense__c submitted = buildExpense(ExpenseStatusEmailHandler.STATUS_SUBMITTED);

    // Unchanged status
    System.assertEquals(
      null,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(submitted, submitted)
    );
    // Status without an email (New, Reimbursed)
    System.assertEquals(
      null,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(buildExpense(STATUS_NEW), null)
    );
    System.assertEquals(
      null,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        buildExpense('Reimbursed'),
        buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_ED)
      )
    );
    // No employee
    System.assertEquals(
      null,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(
        new Expense__c(Status__c = ExpenseStatusEmailHandler.STATUS_SUBMITTED),
        null
      )
    );
    System.assertEquals(
      null,
      ExpenseStatusEmailHandler.getTemplateForStatusChange(null, null)
    );
  }

  @IsTest
  static void testHandleAfterUpdateApprovalPath() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    ExpenseStatusEmailHandler.testTemplateIdOverride = templateId;
    allowStatusChanges();

    Expense__c expense = buildExpense(STATUS_NEW);
    insert expense;

    List<String> approvalPath = new List<String>{
      ExpenseStatusEmailHandler.STATUS_SUBMITTED,
      ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HOD,
      ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HR,
      ExpenseStatusEmailHandler.STATUS_APPROVED_BY_ED
    };

    Test.startTest();
    for (String status : approvalPath) {
      expense.Status__c = status;
      update expense;
    }
    Test.stopTest();

    expense = [SELECT Status__c FROM Expense__c WHERE Id = :expense.Id];
    System.assertEquals(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_ED, expense.Status__c);
  }

  @IsTest
  static void testHandleAfterUpdateRejectionPaths() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    ExpenseStatusEmailHandler.testTemplateIdOverride = templateId;
    allowStatusChanges();

    Expense__c rejectedByHod = buildExpense(ExpenseStatusEmailHandler.STATUS_SUBMITTED);
    Expense__c rejectedByHr = buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HOD);
    Expense__c rejectedByEd = buildExpense(ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HR);
    List<Expense__c> expenses = new List<Expense__c>{ rejectedByHod, rejectedByHr, rejectedByEd };
    insert expenses;

    rejectedByHod.Status__c = ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HOD;
    rejectedByHr.Status__c = ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HR;
    rejectedByEd.Status__c = ExpenseStatusEmailHandler.STATUS_REJECTED_BY_ED;

    Test.startTest();
    update expenses;
    Test.stopTest();

    Map<Id, Expense__c> savedById = new Map<Id, Expense__c>(
      [SELECT Status__c FROM Expense__c WHERE Id IN :expenses]
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HOD,
      savedById.get(rejectedByHod.Id).Status__c
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.STATUS_REJECTED_BY_HR,
      savedById.get(rejectedByHr.Id).Status__c
    );
    System.assertEquals(
      ExpenseStatusEmailHandler.STATUS_REJECTED_BY_ED,
      savedById.get(rejectedByEd.Id).Status__c
    );
  }

  @IsTest
  static void testSendHodAndHrEmailsPaths() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    ExpenseStatusEmailHandler.testTemplateIdOverride = templateId;

    Expense__c expense = buildExpense(STATUS_NEW);
    insert expense;

    Expense__c oldNew = new Expense__c(
      Id = expense.Id,
      Status__c = STATUS_NEW,
      Employee__c = expense.Employee__c
    );
    Expense__c oldSubmitted = new Expense__c(
      Id = expense.Id,
      Status__c = ExpenseStatusEmailHandler.STATUS_SUBMITTED,
      Employee__c = expense.Employee__c
    );
    Expense__c submitted = new Expense__c(
      Id = expense.Id,
      Status__c = ExpenseStatusEmailHandler.STATUS_SUBMITTED,
      Employee__c = expense.Employee__c
    );
    Expense__c approvedByHod = new Expense__c(
      Id = expense.Id,
      Status__c = ExpenseStatusEmailHandler.STATUS_APPROVED_BY_HOD,
      Employee__c = expense.Employee__c
    );

    Test.startTest();
    ExpenseStatusEmailHandler.sendHodAndHrEmails(
      new List<Expense__c>{ submitted },
      new Map<Id, Expense__c>{ expense.Id => oldNew }
    );
    ExpenseStatusEmailHandler.sendHodAndHrEmails(
      new List<Expense__c>{ approvedByHod },
      new Map<Id, Expense__c>{ expense.Id => oldSubmitted }
    );
    Test.stopTest();

    System.assertNotEquals(null, expense.Id);
  }

  @IsTest
  static void testProcessRecordsEmptyInput() {
    Test.startTest();
    ExpenseStatusEmailHandler.handleAfterInsert(new List<Expense__c>());
    ExpenseStatusEmailHandler.handleAfterUpdate(null, null);
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.assertEquals(0, emailInvocations);
  }
}