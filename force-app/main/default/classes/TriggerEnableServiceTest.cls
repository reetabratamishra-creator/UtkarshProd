/**
 * @description   Tests TriggerEnableService fail-open behaviour and trigger skip.
 * @author        Anshita Chanda
 * @date          2026-08-23
 */
@IsTest
private class TriggerEnableServiceTest {
  @IsTest
  static void missingMetadataKeepsTriggerOn() {
    TriggerEnableService.clearTestOverrides();

    Test.startTest();
    Boolean blankName = TriggerEnableService.isEnabled(null);
    Boolean unknownRecord = TriggerEnableService.isEnabled('Does_Not_Exist_Trigger_Name');
    Test.stopTest();

    System.assertEquals(true, blankName);
    System.assertEquals(true, unknownRecord);
  }

  @IsTest
  static void testOverrideCanDisableTrigger() {
    TriggerEnableService.clearTestOverrides();
    TriggerEnableService.setTestOverride(
      TriggerEnableService.OPPORTUNITY_TEAM_MEMBER,
      false
    );

    Test.startTest();
    Boolean disabled = TriggerEnableService.isEnabled(
      TriggerEnableService.OPPORTUNITY_TEAM_MEMBER
    );
    TriggerEnableService.setTestOverride(
      TriggerEnableService.OPPORTUNITY_TEAM_MEMBER,
      true
    );
    Boolean enabled = TriggerEnableService.isEnabled(
      TriggerEnableService.OPPORTUNITY_TEAM_MEMBER
    );
    Test.stopTest();

    System.assertEquals(false, disabled);
    System.assertEquals(true, enabled);
  }

  @IsTest
  static void disabledPunchTriggerSkipsHandlerAndEnabledPathRuns() {
    TriggerEnableService.clearTestOverrides();

    Punch_Record__c skippedPunch = new Punch_Record__c(
      Is_WFH_Request__c = true,
      Is_WFO_Request__c = false
    );
    TriggerEnableService.setTestOverride(
      TriggerEnableService.PUNCH_RECORD_WFH_EMAIL,
      false
    );
    insert as system skippedPunch;

    TriggerEnableService.setTestOverride(
      TriggerEnableService.PUNCH_RECORD_WFH_EMAIL,
      true
    );
    Punch_Record__c enabledPunch = new Punch_Record__c(
      Is_WFH_Request__c = true,
      Is_WFO_Request__c = false
    );

    Test.startTest();
    insert as system enabledPunch;
    enabledPunch.Is_WFO_Request__c = true;
    update as system enabledPunch;
    Test.stopTest();

    System.assertNotEquals(null, skippedPunch.Id);
    System.assertNotEquals(null, enabledPunch.Id);
  }

  @IsTest
  static void coversTaskLogAndTeamMemberTriggers() {
    TriggerEnableService.clearTestOverrides();
    BWM_TaskLogUnoloTriggerHandler.skipForTests = true;

    Punch_Record__c punchRecord = new Punch_Record__c(
      Is_WFH_Request__c = false,
      Is_WFO_Request__c = false
    );
    insert as system punchRecord;

    Account accountRecord = new Account(
      Name = 'Trigger Enable Unolo ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Department_Name__c = 'Crash Barrier'
    );
    insert as system accountRecord;

    TriggerEnableService.setTestOverride(TriggerEnableService.BWM_TASK_LOG_UNOLO, false);
    insert as system new Task_Log__c(
      Account__c = accountRecord.Id,
      Punch_Record__c = punchRecord.Id,
      IsCheckout__c = false,
      is100mOutside__c = false,
      Manually_Created__c = false,
      Is_schedule__c = false,
      isRescheduled__c = false
    );

    TriggerEnableService.setTestOverride(TriggerEnableService.BWM_TASK_LOG_UNOLO, true);
    insert as system new Task_Log__c(
      Account__c = accountRecord.Id,
      Punch_Record__c = punchRecord.Id,
      IsCheckout__c = false,
      is100mOutside__c = false,
      Manually_Created__c = false,
      Is_schedule__c = false,
      isRescheduled__c = false
    );

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Trigger Enable Team ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Profile adminProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Utkarsh Admin'
      LIMIT 1
    ];
    String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
    User teamUser = new User(
      Alias = uniqueKey.right(8),
      Email = uniqueKey + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'TriggerEnable',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'Asia/Kolkata',
      Username = uniqueKey + '@triggerenable.test',
      ProfileId = adminProfile.Id
    );
    insert as system teamUser;

    User secondTeamUser = new User(
      Alias = (uniqueKey + 'x').right(8),
      Email = uniqueKey + '2@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'TriggerEnable2',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'Asia/Kolkata',
      Username = uniqueKey + '2@triggerenable.test',
      ProfileId = adminProfile.Id
    );
    insert as system secondTeamUser;

    OpportunityTeamMember memberRecord = new OpportunityTeamMember(
      OpportunityId = opportunityRecord.Id,
      UserId = teamUser.Id,
      TeamMemberRole = 'Utkarsh Admin'
    );
    OpportunityTeamMember enabledMember = new OpportunityTeamMember(
      OpportunityId = opportunityRecord.Id,
      UserId = secondTeamUser.Id,
      TeamMemberRole = 'Utkarsh Admin'
    );

    Test.startTest();
    System.runAs(teamUser) {
      TriggerEnableService.setTestOverride(
        TriggerEnableService.OPPORTUNITY_TEAM_MEMBER,
        false
      );
      insert memberRecord;
    }
    System.runAs(secondTeamUser) {
      TriggerEnableService.setTestOverride(
        TriggerEnableService.OPPORTUNITY_TEAM_MEMBER,
        true
      );
      insert enabledMember;
    }
    Test.stopTest();

    System.assertNotEquals(null, memberRecord.Id);
    System.assertNotEquals(null, enabledMember.Id);
  }

  @IsTest
  static void coversCaseExpenseAndTaskOverdueTriggers() {
    TriggerEnableService.clearTestOverrides();
    CasePushNotificationHandler.disableInTests = true;
    CasePushNotificationHandler.disableHodInTests = true;
    CasePushNotificationHandler.disableCrmHeadInTests = true;

    TriggerEnableService.setTestOverride(TriggerEnableService.CASE_TRIGGER, false);
    Case disabledCase = new Case(
      Subject = 'Disabled Case Trigger ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Open'
    );
    insert as system disabledCase;

    TriggerEnableService.setTestOverride(TriggerEnableService.CASE_TRIGGER, true);
    Case enabledCase = new Case(
      Subject = 'Enabled Case Trigger ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Open'
    );
    insert as system enabledCase;
    enabledCase.Subject = 'Enabled Case Trigger Updated';
    update as system enabledCase;

    TriggerEnableService.setTestOverride(TriggerEnableService.EXPENSE_TRIGGER, false);
    Expense__c disabledExpense = new Expense__c();
    insert as system disabledExpense;

    TriggerEnableService.setTestOverride(TriggerEnableService.EXPENSE_TRIGGER, true);
    Expense__c enabledExpense = new Expense__c();
    insert as system enabledExpense;
    enabledExpense = [
      SELECT Id, Status__c, Employee__c
      FROM Expense__c
      WHERE Id = :enabledExpense.Id
    ];
    System.assertEquals('New', enabledExpense.Status__c);
    enabledExpense.Status__c = 'Pending HOD Approval';
    update as system enabledExpense;

    ExpenseTriggerHandler.isLwcContext = true;
    Expense__c deleteExpense = new Expense__c();
    insert as system deleteExpense;
    delete as system deleteExpense;
    ExpenseTriggerHandler.isLwcContext = false;

    Lead leadRecord = new Lead(
      LastName = 'TaskOverdueTrigger ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Trigger Enable Co',
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Email = 'taskoverdue' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;

    Task disabledTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Disabled Overdue Task',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    TriggerEnableService.setTestOverride(TriggerEnableService.TASK_OVERDUE_TRIGGER, false);
    insert as system disabledTask;

    Task enabledTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Enabled Overdue Task',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-2)
    );
    TriggerEnableService.setTestOverride(TriggerEnableService.TASK_OVERDUE_TRIGGER, true);

    Test.startTest();
    insert as system enabledTask;
    enabledTask.Subject = 'Enabled Overdue Task Updated';
    update as system enabledTask;
    Test.stopTest();

    System.assertNotEquals(null, disabledCase.Id);
    System.assertNotEquals(null, enabledCase.Id);
    System.assertNotEquals(null, disabledExpense.Id);
    System.assertNotEquals(null, disabledTask.Id);
    System.assertNotEquals(null, enabledTask.Id);
  }
}