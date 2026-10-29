@IsTest
private class ExpenseNotificationHandlerTest {

    private static UserRole getOrCreateUserRole(String roleName) {
        List<UserRole> roles = [
            SELECT Id, Name
            FROM UserRole
            WHERE Name = :roleName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!roles.isEmpty()) {
            return roles[0];
        }
        UserRole newRole = new UserRole(Name = roleName);
        Database.insert(newRole, AccessLevel.SYSTEM_MODE);
        return newRole;
    }

    private static User createTestUser(String profileName, String department) {
        return createTestUser(profileName, department, null);
    }

    private static User createTestUser(String profileName, String department, Id userRoleId) {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = :profileName
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String alias = uniqueKey.length() > 8
            ? uniqueKey.substring(0, 8)
            : uniqueKey;

        User u = new User(
            FirstName = 'Expense',
            LastName = 'TestUser ' + uniqueKey,
            Alias = alias,
            Email = 'expense.testuser.' + uniqueKey + '@test.com',
            Username = 'expense.testuser.' + uniqueKey + '@test.com',
            ProfileId = p.Id,
            Department = department,
            UserRoleId = userRoleId,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        Database.insert(u, AccessLevel.SYSTEM_MODE);
        return u;
    }

    private static Expense__c insertExpenseAsUser(
        User runningUser,
        String status,
        String purpose
    ) {
        Expense__c expense = new Expense__c(
            Employee__c = runningUser.Id,
            Status__c = status,
            Purpose__c = purpose,
            User_Department__c = runningUser.Department
        );

        System.runAs(runningUser) {
            Database.insert(expense, AccessLevel.SYSTEM_MODE);
        }

        return [
            SELECT Id, Name, CreatedById, Employee__c, Status__c, Purpose__c, User_Department__c, Department__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];
    }

    @IsTest
    static void testHandleAfterInsert_PendingHodApproval_SendsNotification() {
        User salesUser = createTestUser('Utkarsh Sales', 'High Mast & Polygonal');
        createTestUser('Utkarsh HOD', 'High Mast & Polygonal');

        Test.startTest();
        Expense__c expense = insertExpenseAsUser(
            salesUser,
            ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL,
            'Test Pending HOD Expense'
        );
        ExpenseNotificationHandler.handleAfterInsert(new List<Expense__c>{ expense });
        Test.stopTest();

        System.assertNotEquals(null, expense.Id, 'Expense should have been inserted.');
        System.assertEquals(ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL, expense.Status__c);
    }

    @IsTest
    static void testHandleAfterUpdate_PendingHrApproval_SendsHRNotification() {
        createTestUser('Utkarsh HR', null);

        User salesUser = createTestUser('Utkarsh Sales', 'High Mast & Polygonal');
        Expense__c expense = insertExpenseAsUser(
            salesUser,
            ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL,
            'Test Pending HR Expense'
        );

        Expense__c oldExpense = expense.clone(true, false, false, false);
        oldExpense.Status__c = ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL;
        expense.Status__c = ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL;

        Map<Id, Expense__c> oldExpenses = new Map<Id, Expense__c>{ expense.Id => oldExpense };

        Test.startTest();
        ExpenseNotificationHandler.handleAfterUpdate(
            new List<Expense__c>{ expense },
            oldExpenses
        );
        Test.stopTest();

        System.assertEquals(ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL, expense.Status__c);
    }

    @IsTest
    static void testHandleAfterUpdate_PendingEdApproval_SendsEDNotification() {
        UserRole edRole = getOrCreateUserRole(ExpenseNotificationHandler.ROLE_ED);
        createTestUser('Standard User', null, edRole.Id);

        User salesUser = createTestUser('Utkarsh Sales', 'HDPE');
        Expense__c expense = insertExpenseAsUser(
            salesUser,
            ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL,
            'Test Pending ED Expense'
        );

        Expense__c oldExpense = expense.clone(true, false, false, false);
        oldExpense.Status__c = ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL;
        expense.Status__c = ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL;

        Map<Id, Expense__c> oldExpenses = new Map<Id, Expense__c>{ expense.Id => oldExpense };

        Test.startTest();
        ExpenseNotificationHandler.handleAfterUpdate(
            new List<Expense__c>{ expense },
            oldExpenses
        );
        Test.stopTest();

        System.assertEquals(ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL, expense.Status__c);
    }

    @IsTest
    static void testHandleAfterUpdate_ApprovedByEd_SendsSubmitterNotification() {
        User salesUser = createTestUser('Utkarsh Sales', 'HDPE');
        Expense__c expense = insertExpenseAsUser(
            salesUser,
            ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL,
            'Test Approved by ED Expense'
        );

        Expense__c oldExpense = expense.clone(true, false, false, false);
        oldExpense.Status__c = ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL;
        expense.Status__c = ExpenseNotificationHandler.STATUS_APPROVED_BY_ED;

        Map<Id, Expense__c> oldExpenses = new Map<Id, Expense__c>{ expense.Id => oldExpense };

        Test.startTest();
        ExpenseNotificationHandler.handleAfterUpdate(
            new List<Expense__c>{ expense },
            oldExpenses
        );
        Test.stopTest();

        System.assertEquals(ExpenseNotificationHandler.STATUS_APPROVED_BY_ED, expense.Status__c);
    }

    @IsTest
    static void testHandleAfterUpdate_Rejections_SendsSubmitterNotification() {
        User salesUser = createTestUser('Utkarsh Sales', 'HDPE');
        Expense__c expenseHod = insertExpenseAsUser(salesUser, ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL, 'Reject HOD');
        Expense__c expenseHr  = insertExpenseAsUser(salesUser, ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL,  'Reject HR');
        Expense__c expenseEd  = insertExpenseAsUser(salesUser, ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL,  'Reject ED');

        Expense__c oldHod = expenseHod.clone(true, false, false, false);
        oldHod.Status__c = ExpenseNotificationHandler.STATUS_PENDING_HOD_APPROVAL;
        expenseHod.Status__c = ExpenseNotificationHandler.STATUS_REJECTED_BY_HOD;

        Expense__c oldHr = expenseHr.clone(true, false, false, false);
        oldHr.Status__c = ExpenseNotificationHandler.STATUS_PENDING_HR_APPROVAL;
        expenseHr.Status__c = ExpenseNotificationHandler.STATUS_REJECTED_BY_HR;

        Expense__c oldEd = expenseEd.clone(true, false, false, false);
        oldEd.Status__c = ExpenseNotificationHandler.STATUS_PENDING_ED_APPROVAL;
        expenseEd.Status__c = ExpenseNotificationHandler.STATUS_REJECTED_BY_ED;

        Map<Id, Expense__c> oldExpenses = new Map<Id, Expense__c>{
            expenseHod.Id => oldHod,
            expenseHr.Id => oldHr,
            expenseEd.Id => oldEd
        };

        Test.startTest();
        ExpenseNotificationHandler.handleAfterUpdate(
            new List<Expense__c>{ expenseHod, expenseHr, expenseEd },
            oldExpenses
        );
        Test.stopTest();

        System.assertEquals(ExpenseNotificationHandler.STATUS_REJECTED_BY_HOD, expenseHod.Status__c);
        System.assertEquals(ExpenseNotificationHandler.STATUS_REJECTED_BY_HR, expenseHr.Status__c);
        System.assertEquals(ExpenseNotificationHandler.STATUS_REJECTED_BY_ED, expenseEd.Status__c);
    }

    @IsTest
    static void testHandleAfterInsert_NullOrEmptyList() {
        Test.startTest();
        ExpenseNotificationHandler.handleAfterInsert(null);
        ExpenseNotificationHandler.handleAfterInsert(new List<Expense__c>());
        ExpenseNotificationHandler.handleAfterUpdate(null, null);
        ExpenseNotificationHandler.handleAfterUpdate(new List<Expense__c>(), new Map<Id, Expense__c>());
        Test.stopTest();

        System.assert(true, 'Null and empty lists should be handled safely.');
    }

    @IsTest
    static void testFormatAmount() {
        System.assertEquals('0.00', ExpenseNotificationHandler.formatAmount(null));
        System.assertEquals('100.00', ExpenseNotificationHandler.formatAmount(100));
        System.assertEquals('1234.56', ExpenseNotificationHandler.formatAmount(1234.56));
        System.assertEquals('99.10', ExpenseNotificationHandler.formatAmount(99.1));
    }
}