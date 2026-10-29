/**
 * @description Test class for ExpenseValidationHelper
 * @author Salesforce
 * @date 2026
 */
@IsTest
private class ExpenseValidationHelperTest {

    @TestSetup
    static void setupTestData() {
        // Create an active eligibility record for Level L6
        Employee_Eligibility__c eligibilityL6 = new Employee_Eligibility__c(
            Name = 'Test Eligibility L6',
            Level__c = 'L6',
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
        insert eligibilityL6;

        // Create a valid expense
        Expense__c validExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Employee_Level__c = 'L6',
            Purpose__c = 'Client Visit',
            Status__c = 'New',
            Travel_Start_Date__c = Date.today().addDays(-5),
            Travel_End_Date__c = Date.today().addDays(-2),
            Submitted_Date__c = Date.today()
        );
        insert validExpense;

        // Add valid expense lines to validExpense
        List<Expense_Line__c> validLines = new List<Expense_Line__c>{
            new Expense_Line__c(
                Expense__c = validExpense.Id,
                Expense_Type__c = 'Lodging',
                City_Tier__c = 'Tier 1',
                Amount__c = 4000,
                Bill_Attached__c = true,
                Date__c = Date.today().addDays(-3)
            ),
            new Expense_Line__c(
                Expense__c = validExpense.Id,
                Expense_Type__c = 'Fooding',
                City_Tier__c = 'Tier 2',
                Amount__c = 600,
                Bill_Attached__c = true,
                Date__c = Date.today().addDays(-3)
            )
        };
        insert validLines;
    }

    @IsTest
    static void testValidateExpenseSuccess() {
        Expense__c exp = [SELECT Id FROM Expense__c WHERE Purpose__c = 'Client Visit' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = ExpenseValidationHelper.validateExpense(exp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.get('isValid'), 'Expense should be valid');
        List<String> errors = (List<String>) result.get('errors');
        System.assertEquals(0, errors.size(), 'Errors list should be empty');
    }

    @IsTest
    static void testValidateExpenseNoEligibility() {
        // Create expense for level with no eligibility record
        Expense__c noEligExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Employee_Level__c = 'L9',
            Purpose__c = 'No Eligibility Test',
            Status__c = 'New'
        );
        insert noEligExpense;

        Test.startTest();
        Map<String, Object> result = ExpenseValidationHelper.validateExpense(noEligExpense.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('isValid'), 'Expense should be invalid without eligibility');
        List<String> errors = (List<String>) result.get('errors');
        System.assert(errors.size() > 0, 'There should be an error for missing eligibility');
        System.assert(errors[0].contains('No active eligibility found'), 'Error should mention missing eligibility');
    }

    @IsTest
    static void testValidateExpenseSubmissionTimelineExceeded() {
        // Expense with travel end date older than 10 days before submission date
        Expense__c lateExpense = new Expense__c(
            Employee__c = UserInfo.getUserId(),
            Employee_Level__c = 'L6',
            Purpose__c = 'Late Submission Test',
            Status__c = 'New',
            Travel_End_Date__c = Date.today().addDays(-15),
            Submitted_Date__c = Date.today()
        );
        insert lateExpense;

        Test.startTest();
        Map<String, Object> result = ExpenseValidationHelper.validateExpense(lateExpense.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('isValid'), 'Late submission should be invalid');
        List<String> errors = (List<String>) result.get('errors');
        Boolean hasTimelineError = false;
        for (String err : errors) {
            if (err.contains('beyond 10 days')) {
                hasTimelineError = true;
            }
        }
        System.assert(hasTimelineError, 'Result should contain submission timeline error');
    }

    @IsTest
    static void testValidateExpenseLineLodging() {
        Employee_Eligibility__c elig = [SELECT Id, Lodging_Tier1__c, Lodging_Tier2__c FROM Employee_Eligibility__c WHERE Level__c = 'L6' LIMIT 1];

        // Lodging Tier 1 within limit
        Expense_Line__c lineValidTier1 = new Expense_Line__c(
            Expense_Type__c = 'Lodging',
            City_Tier__c = 'Tier 1',
            Amount__c = 4500
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineValidTier1, elig), 'Lodging Tier 1 within limit should be valid');

        // Lodging Tier 1 exceeding limit
        Expense_Line__c lineExceedTier1 = new Expense_Line__c(
            Expense_Type__c = 'Lodging',
            City_Tier__c = 'Tier 1',
            Amount__c = 5500
        );
        String errTier1 = ExpenseValidationHelper.validateExpenseLine(lineExceedTier1, elig);
        System.assertNotEquals(null, errTier1, 'Lodging Tier 1 exceeding limit should return error');
        System.assert(errTier1.contains('exceeds limit'), 'Error should mention exceeds limit');

        // Lodging Tier 2 within limit
        Expense_Line__c lineValidTier2 = new Expense_Line__c(
            Expense_Type__c = 'Lodging',
            City_Tier__c = 'Tier 2',
            Amount__c = 2500
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineValidTier2, elig), 'Lodging Tier 2 within limit should be valid');

        // Lodging Tier 2 exceeding limit
        Expense_Line__c lineExceedTier2 = new Expense_Line__c(
            Expense_Type__c = 'Lodging',
            City_Tier__c = 'Tier 2',
            Amount__c = 3500
        );
        String errTier2 = ExpenseValidationHelper.validateExpenseLine(lineExceedTier2, elig);
        System.assertNotEquals(null, errTier2, 'Lodging Tier 2 exceeding limit should return error');
    }

    @IsTest
    static void testValidateExpenseLineFooding() {
        Employee_Eligibility__c elig = [SELECT Id, Fooding_Tier1__c, Fooding_Tier2__c FROM Employee_Eligibility__c WHERE Level__c = 'L6' LIMIT 1];

        // Fooding without bill attached
        Expense_Line__c lineNoBill = new Expense_Line__c(
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 500,
            Bill_Attached__c = false
        );
        String errNoBill = ExpenseValidationHelper.validateExpenseLine(lineNoBill, elig);
        System.assertNotEquals(null, errNoBill, 'Fooding without bill should return error');
        System.assert(errNoBill.contains('supported by bills'), 'Error should mention bills');

        // Fooding Tier 1 within limit with bill
        Expense_Line__c lineValid = new Expense_Line__c(
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 800,
            Bill_Attached__c = true
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineValid, elig), 'Fooding Tier 1 within limit should be valid');

        // Fooding Tier 1 exceeding limit
        Expense_Line__c lineExceedTier1 = new Expense_Line__c(
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 1',
            Amount__c = 1200,
            Bill_Attached__c = true
        );
        String errExceed = ExpenseValidationHelper.validateExpenseLine(lineExceedTier1, elig);
        System.assertNotEquals(null, errExceed, 'Fooding Tier 1 exceeding limit should return error');

        // Fooding Tier 2 exceeding limit
        Expense_Line__c lineExceedTier2 = new Expense_Line__c(
            Expense_Type__c = 'Fooding',
            City_Tier__c = 'Tier 2',
            Amount__c = 900,
            Bill_Attached__c = true
        );
        String errExceedTier2 = ExpenseValidationHelper.validateExpenseLine(lineExceedTier2, elig);
        System.assertNotEquals(null, errExceedTier2, 'Fooding Tier 2 exceeding limit should return error');
    }

    @IsTest
    static void testValidateExpenseLineAir() {
        Employee_Eligibility__c elig = [SELECT Id, Air_Business__c, Air_Economy__c FROM Employee_Eligibility__c WHERE Level__c = 'L6' LIMIT 1];

        // Economy air travel (allowed)
        Expense_Line__c lineEconomy = new Expense_Line__c(
            Expense_Type__c = 'Air',
            Travel_Class__c = 'Economy',
            Amount__c = 5000
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineEconomy, elig), 'Economy air should be allowed');

        // Business air travel (not allowed for L6)
        Expense_Line__c lineBusiness = new Expense_Line__c(
            Expense_Type__c = 'Air',
            Travel_Class__c = 'Business',
            Amount__c = 15000
        );
        String errAir = ExpenseValidationHelper.validateExpenseLine(lineBusiness, elig);
        System.assertNotEquals(null, errAir, 'Business air should not be allowed');
        System.assert(errAir.contains('not allowed'), 'Error should mention not allowed');
    }

    @IsTest
    static void testValidateExpenseLineTrain() {
        Employee_Eligibility__c elig = [SELECT Id, Train_1AC__c, Train_2AC__c, Train_3AC__c, Train_Sleeper__c FROM Employee_Eligibility__c WHERE Level__c = 'L6' LIMIT 1];

        // Train 2AC (allowed)
        Expense_Line__c line2AC = new Expense_Line__c(
            Expense_Type__c = 'Train',
            Travel_Class__c = '2AC',
            Amount__c = 1500
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(line2AC, elig), 'Train 2AC should be allowed');

        // Train 3AC (allowed)
        Expense_Line__c line3AC = new Expense_Line__c(
            Expense_Type__c = 'Train',
            Travel_Class__c = '3AC',
            Amount__c = 1000
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(line3AC, elig), 'Train 3AC should be allowed');

        // Train Sleeper (allowed)
        Expense_Line__c lineSleeper = new Expense_Line__c(
            Expense_Type__c = 'Train',
            Travel_Class__c = 'Sleeper',
            Amount__c = 500
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineSleeper, elig), 'Train Sleeper should be allowed');

        // Train 1AC (not allowed for L6)
        Expense_Line__c line1AC = new Expense_Line__c(
            Expense_Type__c = 'Train',
            Travel_Class__c = '1AC',
            Amount__c = 2500
        );
        String errTrain = ExpenseValidationHelper.validateExpenseLine(line1AC, elig);
        System.assertNotEquals(null, errTrain, 'Train 1AC should not be allowed');
        System.assert(errTrain.contains('not allowed'), 'Error should mention not allowed');
    }

    @IsTest
    static void testValidateExpenseLineOwnVehicle() {
        Employee_Eligibility__c elig = [SELECT Id, Own_Vehicle_Rate__c FROM Employee_Eligibility__c WHERE Level__c = 'L6' LIMIT 1];

        // Own vehicle within calculated amount (50 KM * 10 Rate = 500 max, Amount = 400)
        Expense_Line__c lineValidVehicle = new Expense_Line__c(
            Expense_Type__c = 'Own Vehicle',
            Distance_KM__c = 50,
            Amount__c = 400
        );
        System.assertEquals(null, ExpenseValidationHelper.validateExpenseLine(lineValidVehicle, elig), 'Own vehicle within limit should be valid');

        // Own vehicle exceeding calculated amount (50 KM * 10 Rate = 500 max, Amount = 600)
        Expense_Line__c lineExceedVehicle = new Expense_Line__c(
            Expense_Type__c = 'Own Vehicle',
            Distance_KM__c = 50,
            Amount__c = 600
        );
        String errVehicle = ExpenseValidationHelper.validateExpenseLine(lineExceedVehicle, elig);
        System.assertNotEquals(null, errVehicle, 'Own vehicle exceeding calculated amount should return error');
        System.assert(errVehicle.contains('exceeds calculated amount'), 'Error should mention calculated amount');
    }

    @IsTest
    static void testSubmitExpense() {
        Expense__c exp = [SELECT Id, Status__c, Submitted_Date__c FROM Expense__c WHERE Purpose__c = 'Client Visit' LIMIT 1];

        Test.startTest();
        ExpenseValidationHelper.submitExpense(exp.Id);
        Test.stopTest();

        Expense__c updatedExp = [SELECT Id, Status__c, Submitted_Date__c FROM Expense__c WHERE Id = :exp.Id];
        System.assertEquals('Pending HOD Approval', updatedExp.Status__c, 'Status should be Pending HOD Approval');
        System.assertEquals(Date.today(), updatedExp.Submitted_Date__c, 'Submitted date should be today');
    }
}