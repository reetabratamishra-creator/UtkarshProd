@IsTest
private class ExpenseControllerTest {

    private static User createTestUser(String profileName, String department) {
        List<Profile> profs = [
            SELECT Id
            FROM Profile
            WHERE Name = :profileName
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Id profileId = !profs.isEmpty()
            ? profs[0].Id
            : [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1].Id;

        String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String alias = uniqueKey.length() > 8 ? uniqueKey.substring(0, 8) : uniqueKey;

        User u = new User(
            FirstName = 'Expense',
            LastName = 'TestUser ' + uniqueKey,
            Alias = alias,
            Email = 'expense.testuser.' + uniqueKey + '@test.com',
            Username = 'expense.testuser.' + uniqueKey + '@test.com',
            ProfileId = profileId,
            Department = department,
            Employee_Level__c = 'L6',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        Database.insert(u, AccessLevel.SYSTEM_MODE);
        return u;
    }

    @TestSetup
    static void setupData() {
        User currentUser = [
            SELECT Id, Employee_Level__c, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String userLevel = String.isBlank(currentUser.Employee_Level__c) ? 'L6' : currentUser.Employee_Level__c;
        String userDept = String.isBlank(currentUser.Department) ? 'Sales' : currentUser.Department;

        // Create eligibility record for user's level
        Employee_Eligibility__c eligibility = new Employee_Eligibility__c(
            Name = 'Test Eligibility ' + userLevel,
            Level__c = userLevel,
            Grade__c = 'A',
            Designation__c = 'Manager',
            Lodging_Tier1__c = 5000,
            Lodging_Tier2__c = 3000,
            Fooding_Tier1__c = 1000,
            Fooding_Tier2__c = 800,
            Air_Business__c = false,
            Air_Economy__c = true,
            Train_1AC__c = false,
            Train_2AC__c = true,
            Train_3AC__c = true,
            Train_Sleeper__c = true,
            Own_Vehicle_Rate__c = 10,
            Active__c = true
        );
        Database.insert(eligibility, AccessLevel.SYSTEM_MODE);

        // New expense with line item
        Expense__c newExpense = new Expense__c(
            Employee__c = currentUser.Id,
            Status__c = 'New',
            Purpose__c = 'Test Initial Expense',
            User_Department__c = userDept,
            Travel_Start_Date__c = Date.today().addDays(-2),
            Travel_End_Date__c = Date.today().addDays(-1)
        );
        Database.insert(newExpense, AccessLevel.SYSTEM_MODE);

        Expense_Line__c lineItem = new Expense_Line__c(
            Expense__c = newExpense.Id,
            Expense_Type__c = 'Lodging',
            City__c = 'Kolkata',
            City_Tier__c = 'Tier 1',
            Amount__c = 2500,
            Bill_Attached__c = true,
            Date__c = Date.today().addDays(-1),
            Description__c = 'Hotel Stay'
        );
        Database.insert(lineItem, AccessLevel.SYSTEM_MODE);

        // Pending HOD Approval expense
        Expense__c pendingHodExpense = new Expense__c(
            Employee__c = currentUser.Id,
            Status__c = 'Pending HOD Approval',
            Purpose__c = 'Test Pending HOD Expense',
            User_Department__c = userDept,
            Travel_Start_Date__c = Date.today().addDays(-3),
            Travel_End_Date__c = Date.today().addDays(-2),
            Submitted_Date__c = Date.today().addDays(-1)
        );
        Database.insert(pendingHodExpense, AccessLevel.SYSTEM_MODE);

        // Pending HR Approval expense
        Expense__c pendingHrExpense = new Expense__c(
            Employee__c = currentUser.Id,
            Status__c = 'Pending HR Approval',
            Purpose__c = 'Test Pending HR Expense',
            User_Department__c = userDept,
            Travel_Start_Date__c = Date.today().addDays(-4),
            Travel_End_Date__c = Date.today().addDays(-3),
            Submitted_Date__c = Date.today().addDays(-2)
        );
        Database.insert(pendingHrExpense, AccessLevel.SYSTEM_MODE);

        // Pending ED Approval expense
        Expense__c pendingEdExpense = new Expense__c(
            Employee__c = currentUser.Id,
            Status__c = 'Pending ED Approval',
            Purpose__c = 'Test Pending ED Expense',
            User_Department__c = userDept,
            Travel_Start_Date__c = Date.today().addDays(-5),
            Travel_End_Date__c = Date.today().addDays(-4),
            Submitted_Date__c = Date.today().addDays(-3)
        );
        Database.insert(pendingEdExpense, AccessLevel.SYSTEM_MODE);
    }

    @IsTest
    static void testGetMyExpenses() {
        Test.startTest();
        List<Expense__c> expenses = ExpenseController.getMyExpenses();
        Test.stopTest();

        System.assertNotEquals(null, expenses);
        System.assert(expenses.size() > 0, 'Current user should have expenses.');
    }

    @IsTest
    static void testGetExpenseWithLines() {
        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'New'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Test.startTest();
        Expense__c result = ExpenseController.getExpenseWithLines(expense.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(expense.Id, result.Id, 'Returned expense should match the requested expense.');
        System.assertNotEquals(null, result.Expense_Lines__r, 'Related expense lines should be returned.');
        System.assertEquals(1, result.Expense_Lines__r.size(), 'Should return 1 related expense line.');
    }

    @IsTest
    static void testGetMyEligibility() {
        Test.startTest();
        Employee_Eligibility__c result = ExpenseController.getMyEligibility();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.Active__c);
    }

    @IsTest
    static void testSaveExpense_InsertDefault() {
        User currentUser = [
            SELECT Id, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Expense__c expense = new Expense__c(
            Purpose__c = 'Created From Test',
            User_Department__c = currentUser.Department
        );

        Test.startTest();
        Expense__c result = ExpenseController.saveExpense(expense);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.Id);
        System.assertEquals(
            currentUser.Id,
            result.Employee__c,
            'Employee should default to the current user.'
        );
        System.assertEquals(
            'New',
            result.Status__c,
            'New expenses without status should default to New.'
        );
    }

    @IsTest
    static void testSaveExpense_UpdateExisting() {
        Expense__c expense = [
            SELECT Id, Purpose__c, Status__c
            FROM Expense__c
            WHERE Status__c = 'New'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        expense.Purpose__c = 'Updated Test Purpose';

        /*Test.startTest();
        Expense__c result = ExpenseController.saveExpense(expense);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Updated Test Purpose', result.Purpose__c);*/
    }

    @IsTest
    static void testGetPendingApprovals_Admin() {
        Test.startTest();
        List<Expense__c> expenses = ExpenseController.getPendingApprovals();
        Test.stopTest();

        System.assertNotEquals(null, expenses);
        System.assert(expenses.size() >= 3, 'Admin should retrieve pending HOD, HR, and ED approval expenses.');
    }

    @IsTest
    static void testGetPendingApprovals_HR() {
        User hrUser = createTestUser('Utkarsh HR', 'HR');

        System.runAs(hrUser) {
            Test.startTest();
            List<Expense__c> expenses = ExpenseController.getPendingApprovals();
            Test.stopTest();

            System.assertNotEquals(null, expenses);
            for (Expense__c exp : expenses) {
                System.assertEquals('Pending HR Approval', exp.Status__c, 'HR should only see Pending HR Approval expenses.');
            }
        }
    }

    @IsTest
    static void testGetPendingApprovals_HOD() {
        User currentUser = [
            SELECT Id, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String userDept = String.isBlank(currentUser.Department) ? 'Sales' : currentUser.Department;
        User hodUser = createTestUser('Utkarsh HOD', userDept);

        System.runAs(hodUser) {
            Test.startTest();
            List<Expense__c> expenses = ExpenseController.getPendingApprovals();
            Test.stopTest();

            System.assertNotEquals(null, expenses);
            for (Expense__c exp : expenses) {
                System.assertEquals('Pending HOD Approval', exp.Status__c, 'HOD should only see Pending HOD Approval expenses.');
            }
        }
    }

    @IsTest
    static void testApproveExpense_Admin() {
        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending ED Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Test.startTest();
        ExpenseController.approveExpense(expense.Id, 'Approved by Admin');
        Test.stopTest();

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Approved by ED', result.Status__c, 'Admin approval sets status to Approved by ED.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(UserInfo.getUserId(), result.Approver__c);
    }

    @IsTest
    static void testApproveExpense_HR() {
        User hrUser = createTestUser('Utkarsh HR', 'HR');
        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending HR Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.runAs(hrUser) {
            Test.startTest();
            ExpenseController.approveExpense(expense.Id, 'Approved by HR');
            Test.stopTest();
        }

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Pending ED Approval', result.Status__c, 'HR approval sets status to Pending ED Approval.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(hrUser.Id, result.Approver__c);
    }

    @IsTest
    static void testApproveExpense_HOD() {
        User currentUser = [
            SELECT Id, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String userDept = String.isBlank(currentUser.Department) ? 'Sales' : currentUser.Department;
        User hodUser = createTestUser('Utkarsh HOD', userDept);

        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending HOD Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.runAs(hodUser) {
            Test.startTest();
            ExpenseController.approveExpense(expense.Id, 'Approved by HOD');
            Test.stopTest();
        }

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Pending HR Approval', result.Status__c, 'HOD approval sets status to Pending HR Approval.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(hodUser.Id, result.Approver__c);
    }

    @IsTest
    static void testRejectExpense_Admin() {
        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending ED Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Test.startTest();
        ExpenseController.rejectExpense(expense.Id, 'Rejected by Admin');
        Test.stopTest();

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c, Remark__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Rejected by ED', result.Status__c, 'Admin rejection sets status to Rejected by ED.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(UserInfo.getUserId(), result.Approver__c);
        System.assertEquals('Rejected by Admin', result.Remark__c);
    }

    @IsTest
    static void testRejectExpense_HR() {
        User hrUser = createTestUser('Utkarsh HR', 'HR');
        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending HR Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.runAs(hrUser) {
            Test.startTest();
            ExpenseController.rejectExpense(expense.Id, 'Rejected by HR');
            Test.stopTest();
        }

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c, Remark__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Rejected by HR', result.Status__c, 'HR rejection sets status to Rejected by HR.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(hrUser.Id, result.Approver__c);
        System.assertEquals('Rejected by HR', result.Remark__c);
    }

    @IsTest
    static void testRejectExpense_HOD() {
        User currentUser = [
            SELECT Id, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String userDept = String.isBlank(currentUser.Department) ? 'Sales' : currentUser.Department;
        User hodUser = createTestUser('Utkarsh HOD', userDept);

        Expense__c expense = [
            SELECT Id
            FROM Expense__c
            WHERE Status__c = 'Pending HOD Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.runAs(hodUser) {
            Test.startTest();
            ExpenseController.rejectExpense(expense.Id, 'Rejected by HOD');
            Test.stopTest();
        }

        Expense__c result = [
            SELECT Id, Status__c, Approval_Date__c, Approver__c, Remark__c
            FROM Expense__c
            WHERE Id = :expense.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals('Rejected by HOD', result.Status__c, 'HOD rejection sets status to Rejected by HOD.');
        System.assertEquals(Date.today(), result.Approval_Date__c);
        System.assertEquals(hodUser.Id, result.Approver__c);
        System.assertEquals('Rejected by HOD', result.Remark__c);
    }

    @IsTest
    static void testSubmitExpense_Success() {
        User currentUser = [
            SELECT Id, Employee_Level__c, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String userDept = String.isBlank(currentUser.Department) ? 'Sales' : currentUser.Department;

        Expense__c validExpense = new Expense__c(
            Employee__c = currentUser.Id,
            Status__c = 'New',
            Purpose__c = 'Valid Expense Submission',
            User_Department__c = userDept,
            Travel_Start_Date__c = Date.today().addDays(-2),
            Travel_End_Date__c = Date.today().addDays(-1)
        );
        Database.insert(validExpense, AccessLevel.SYSTEM_MODE);

        Expense_Line__c validLine = new Expense_Line__c(
            Expense__c = validExpense.Id,
            Expense_Type__c = 'Lodging',
            City__c = 'Kolkata',
            City_Tier__c = 'Tier 1',
            Amount__c = 2000,
            Bill_Attached__c = true,
            Date__c = Date.today().addDays(-1)
        );
        Database.insert(validLine, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        Map<String, Object> result = ExpenseController.submitExpense(validExpense.Id);
        Test.stopTest();

        /*System.assertEquals(true, (Boolean) result.get('isValid'));
        System.assertEquals('Expense submitted successfully', (String) result.get('message'));*/
    }

    @IsTest
    static void testSubmitExpense_Invalid() {
        Expense__c invalidExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Status__c = 'New',
            Purpose__c = 'Invalid Expense Without Lines'
        );
        Database.insert(invalidExpense, AccessLevel.SYSTEM_MODE);

        // Add an invalid line (Fooding without bill attached)
        Expense_Line__c invalidLine = new Expense_Line__c(
            Expense__c = invalidExpense.Id,
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Bill_Attached__c = false,
            Date__c = Date.today()
        );
        Database.insert(invalidLine, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        Map<String, Object> result = ExpenseController.submitExpense(invalidExpense.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('isValid'));
        System.assertEquals('Expense validation failed. Please review errors.', (String) result.get('message'));
    }
}