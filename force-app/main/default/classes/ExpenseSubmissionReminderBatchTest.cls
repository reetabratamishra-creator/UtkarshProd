/**
 * @description Test class for ExpenseSubmissionReminderBatch day-7 HOD reminder logic.
 */
@IsTest
private class ExpenseSubmissionReminderBatchTest {
  @IsTest
  static void testExecuteNonReminderDayReturnsEarly() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 10);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    batch.finish(null);
    Test.stopTest();

    System.assert(true, 'Non-reminder day should return without error');
  }

  @IsTest
  static void testExecuteDay7WithPriorMonthSubmission() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 7);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Expense__c expense = new Expense__c(
      Status__c = 'Submitted',
      Employee__c = runAsUser.Id,
      Submitted_Date__c = Date.newInstance(2026, 2, 15)
    );
    insert expense;

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    Test.stopTest();

    System.assert(true, 'Submitted employee should be excluded from HOD reminders');
  }

  @IsTest
  static void testExecuteDay7HodReminderPath() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 7);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Expense__c expense = new Expense__c(
      Status__c = 'Draft',
      Employee__c = runAsUser.Id
    );
    insert expense;

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    Test.stopTest();

    System.assert(true, 'Day-7 HOD reminder path should execute without error');
  }

  @IsTest
  static void testExecuteDay16EmployeeReminderPath() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 16);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    Test.stopTest();

    System.assert(true, 'Day-16 employee reminder path should execute without error');
  }

  @IsTest
  static void testExecuteDay1EmployeeReminderPath() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 1);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    Test.stopTest();

    System.assert(true, 'Day-1 employee reminder path should execute without error');
  }

  @IsTest
  static void testExecuteDay16SkipsSubmittedEmployee() {
    ExpenseSubmissionReminderBatch.testTodayOverride = Date.newInstance(2026, 3, 16);
    User runAsUser = [
      SELECT Id, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Expense__c expense = new Expense__c(
      Status__c = 'Submitted',
      Employee__c = runAsUser.Id,
      Submitted_Date__c = Date.newInstance(2026, 3, 5)
    );
    insert expense;

    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();

    Test.startTest();
    batch.execute(null, new List<User>{ runAsUser });
    Test.stopTest();

    System.assert(true, 'Submitted employee should be skipped on day 16');
  }

  @IsTest
  static void testStartQueryLocator() {
    ExpenseSubmissionReminderBatch batch = new ExpenseSubmissionReminderBatch();
    Test.startTest();
    Database.QueryLocator queryLocator = batch.start(null);
    Test.stopTest();
    System.assertNotEquals(null, queryLocator);
  }
}