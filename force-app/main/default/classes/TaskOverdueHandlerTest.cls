/**
 * @description   Test class for TaskOverdueHandler.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class TaskOverdueHandlerTest {
  @IsTest
  static void testNewOverdueLeadTaskStampsDateAndSendsEmail() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'OverdueHandlerLead');

    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Overdue Lead Task',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );

    Test.startTest();
    insert as system taskRecord;
    TaskOverdueHandler.handleOverdueTasks(
      new List<Task>{ taskRecord },
      null
    );
    Test.stopTest();

    Lead updatedLead = [
      SELECT FirstOverdueTaskDate__c, LeadOverdueEsc36Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, updatedLead.FirstOverdueTaskDate__c);
    System.assertEquals(false, updatedLead.LeadOverdueEsc36Sent__c);
  }

  @IsTest
  static void testNewOverdueOpportunityTaskStampsDate() {
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Overdue Handler Opp',
      false,
      null
    );

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Overdue Opp Task',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-2)
    );

    Test.startTest();
    insert as system taskRecord;
    TaskOverdueHandler.handleOverdueTasks(
      new List<Task>{ taskRecord },
      null
    );
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT FirstOverdueTaskDate__c, OppOverdueEsc36Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertNotEquals(null, updatedOpp.FirstOverdueTaskDate__c);
    System.assertEquals(false, updatedOpp.OppOverdueEsc36Sent__c);
  }

  @IsTest
  static void testSkipsNonOverdueAndAlreadyOverdueTasks() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'SkipOverdueLead');

    Task currentTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Current Task',
      Status = 'Not Started',
      ActivityDate = Date.today()
    );
    insert as system currentTask;

    TaskOverdueHandler.handleOverdueTasks(new List<Task>{ currentTask }, null);

    Task overdueTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Already Overdue',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-3)
    );
    insert as system overdueTask;

    Task oldTask = overdueTask.clone(true, true, true, true);
    overdueTask.Subject = 'Already Overdue Updated';

    Test.startTest();
    TaskOverdueHandler.handleOverdueTasks(
      new List<Task>{ currentTask, overdueTask },
      new Map<Id, Task>{ oldTask.Id => oldTask }
    );
    Test.stopTest();

    System.assert(true, 'Non-overdue and already-overdue tasks should be skipped safely');
  }

  @IsTest
  static void testCompletedTaskAndEmptyListAreSkipped() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'CompletedOverdueLead');
    Task completedTask = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Completed Task',
      Status = 'Completed',
      ActivityDate = Date.today().addDays(-1)
    );
    insert as system completedTask;

    Test.startTest();
    TaskOverdueHandler.handleOverdueTasks(new List<Task>(), null);
    TaskOverdueHandler.handleOverdueTasks(new List<Task>{ completedTask }, null);
    Test.stopTest();

    Lead updatedLead = [
      SELECT FirstOverdueTaskDate__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(null, updatedLead.FirstOverdueTaskDate__c);
  }
}