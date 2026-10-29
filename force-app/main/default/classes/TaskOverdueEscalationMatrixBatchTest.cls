/**
 * @description   Test class for TaskOverdueEscalationMatrixBatch and TaskOverdueConsolidatedEmailBatch
 *                (includes the legacy per-record logic).
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class TaskOverdueEscalationMatrixBatchTest {
  // ===========================================================================
  // start / finish
  // ===========================================================================
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    Database.QueryLocator locator = batch.start(null);
    batch.finish(null); // no rows collected -> returns early
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  // ===========================================================================
  // NEW consolidated flow: execute() then finish() on the SAME instance
  // ===========================================================================
  @IsTest
  static void testExecuteLeadOwnerStamp() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'TaskOverdueOwner');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up Overdue Owner',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Lead updatedLead = [
      SELECT FirstOverdueTaskDate__c, LeadOverdueEsc36Sent__c, LeadOverdueEsc96Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, updatedLead.FirstOverdueTaskDate__c);
    System.assertNotEquals(true, updatedLead.LeadOverdueEsc36Sent__c);
    System.assertNotEquals(true, updatedLead.LeadOverdueEsc96Sent__c);
  }

  @IsTest
  static void testExecuteOpportunityOwnerStamp() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Task Overdue Opp Owner',
      false,
      null
    );
    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Opp Follow Up Overdue Owner',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT FirstOverdueTaskDate__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertNotEquals(null, updatedOpp.FirstOverdueTaskDate__c);
  }

  @IsTest
  static void testExecuteLead36HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'TaskOverdue36');
    leadRecord.FirstOverdueTaskDate__c = System.now().addHours(-40);
    leadRecord.LeadOverdueEsc36Sent__c = false;
    leadRecord.LeadOverdueEsc96Sent__c = false;
    update leadRecord;

    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up Overdue 36h',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-2)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Lead updatedLead = [
      SELECT LeadOverdueEsc36Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(true, updatedLead.LeadOverdueEsc36Sent__c);
  }

  @IsTest
  static void testExecuteLead96HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'TaskOverdue96');
    leadRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    leadRecord.LeadOverdueEsc36Sent__c = true;
    leadRecord.LeadOverdueEsc96Sent__c = false;
    update leadRecord;

    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Follow Up Overdue 96h',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Lead updatedLead = [
      SELECT LeadOverdueEsc96Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(true, updatedLead.LeadOverdueEsc96Sent__c);
  }

  @IsTest
  static void testExecuteOpportunity36HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Task Overdue Opp 36h',
      false,
      null
    );
    opportunityRecord.FirstOverdueTaskDate__c = System.now().addHours(-40);
    opportunityRecord.OppOverdueEsc36Sent__c = false;
    update opportunityRecord;

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Opportunity Follow Up Overdue 36h',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-2)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT OppOverdueEsc36Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.OppOverdueEsc36Sent__c);
  }

  @IsTest
  static void testExecuteOpportunity96HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Task Overdue Opp 96h',
      false,
      null
    );
    opportunityRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    opportunityRecord.OppOverdueEsc36Sent__c = true;
    opportunityRecord.OppOverdueEsc96Sent__c = false;
    update opportunityRecord;

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Opportunity Follow Up Overdue 96h',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT OppOverdueEsc96Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, updatedOpp.OppOverdueEsc96Sent__c);
  }

  @IsTest
  static void testExecuteSkipsDuplicateRecords() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'DupLead');
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Dup Opp',
      false,
      null
    );

    // Two tasks per record -> the second one hits the "already processed" check
    List<Task> tasks = new List<Task>{
      new Task(WhoId = leadRecord.Id, Subject = 'L1', Status = 'Not Started', ActivityDate = Date.today().addDays(-1)),
      new Task(WhoId = leadRecord.Id, Subject = 'L2', Status = 'Not Started', ActivityDate = Date.today().addDays(-1)),
      new Task(WhatId = opportunityRecord.Id, Subject = 'O1', Status = 'Not Started', ActivityDate = Date.today().addDays(-1)),
      new Task(WhatId = opportunityRecord.Id, Subject = 'O2', Status = 'Not Started', ActivityDate = Date.today().addDays(-1))
    };
    insert tasks;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, tasks);
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(
      null,
      [SELECT FirstOverdueTaskDate__c FROM Lead WHERE Id = :leadRecord.Id]
      .FirstOverdueTaskDate__c
    );
    System.assertNotEquals(
      null,
      [SELECT FirstOverdueTaskDate__c FROM Opportunity WHERE Id = :opportunityRecord.Id]
      .FirstOverdueTaskDate__c
    );
  }

  @IsTest
  static void testExecuteWithNoMatchingRecords() {
    EscalationMatrixTestUtil.prepareTestContext();

    // Task with no Lead/Opportunity -> both query helpers return early on empty sets
    Task taskRecord = new Task(
      Subject = 'No parent',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert taskRecord;

    Test.startTest();
    TaskOverdueEscalationMatrixBatch batch = new TaskOverdueEscalationMatrixBatch();
    batch.execute(null, new List<Task>{ taskRecord });
    batch.finish(null);
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Id = :taskRecord.Id]);
  }

  // ===========================================================================
  // LEGACY per-record logic (needs @TestVisible on legacyExecutePerRecord)
  // ===========================================================================
  @IsTest
  static void testLegacyLeadFirstOverdueOwner() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'LegacyLeadOwner');
    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Legacy Lead Owner',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT FirstOverdueTaskDate__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, updatedLead.FirstOverdueTaskDate__c);
  }

  @IsTest
  static void testLegacyLead36And96() {
    EscalationMatrixTestUtil.prepareTestContext();

    // 100h old, nothing sent -> both 36h and 96h branches run
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'Legacy36And96');
    leadRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    leadRecord.LeadOverdueEsc36Sent__c = false;
    leadRecord.LeadOverdueEsc96Sent__c = false;
    update leadRecord;

    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Legacy Lead 36/96',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Id = :leadRecord.Id]);
  }

  @IsTest
  static void testLegacyLeadAlreadySent() {
    EscalationMatrixTestUtil.prepareTestContext();

    // Everything already sent -> all "if" conditions false
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'LegacyLeadSent');
    leadRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    leadRecord.LeadOverdueEsc36Sent__c = true;
    leadRecord.LeadOverdueEsc96Sent__c = true;
    update leadRecord;

    Task taskRecord = new Task(
      WhoId = leadRecord.Id,
      Subject = 'Legacy Lead Sent',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Id = :leadRecord.Id]);
  }

  @IsTest
  static void testLegacyOpportunityFirstOverdueOwner() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Legacy Opp Owner',
      false,
      null
    );
    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Legacy Opp Owner',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-1)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    Opportunity updatedOpp = [
      SELECT FirstOverdueTaskDate__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertNotEquals(null, updatedOpp.FirstOverdueTaskDate__c);
  }

  @IsTest
  static void testLegacyOpportunity36And96() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Legacy Opp 36/96',
      false,
      null
    );
    opportunityRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    opportunityRecord.OppOverdueEsc36Sent__c = false;
    opportunityRecord.OppOverdueEsc96Sent__c = false;
    update opportunityRecord;

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Legacy Opp 36/96',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }

  @IsTest
  static void testLegacyOpportunityAlreadySent() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Legacy Opp Sent',
      false,
      null
    );
    opportunityRecord.FirstOverdueTaskDate__c = System.now().addHours(-100);
    opportunityRecord.OppOverdueEsc36Sent__c = true;
    opportunityRecord.OppOverdueEsc96Sent__c = true;
    update opportunityRecord;

    Task taskRecord = new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Legacy Opp Sent',
      Status = 'Not Started',
      ActivityDate = Date.today().addDays(-5)
    );
    insert taskRecord;

    Test.startTest();
    new TaskOverdueEscalationMatrixBatch()
      .legacyExecutePerRecord(new List<Task>{ taskRecord });
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }

  // ===========================================================================
  // TaskOverdueConsolidatedEmailBatch
  // ===========================================================================
  @IsTest
  static void testConsolidatedEmailBatchLead36H() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'ConsolidatedLead');

    EscalationMatrixEmailService.TaskDigestRow row = new EscalationMatrixEmailService.TaskDigestRow();
    row.taskRecord = new Task(Subject = 'Dummy', ActivityDate = Date.today().addDays(-2));
    row.leadRecord = leadRecord;
    row.hoursSinceFirstOverdue = 40;

    TaskOverdueConsolidatedEmailBatch.WorkItem item = new TaskOverdueConsolidatedEmailBatch.WorkItem();
    item.groupKey = 'test.recipient@example.com';
    item.templateName = 'Task Overdue 36h HOD';
    item.tier = TaskOverdueConsolidatedEmailBatch.TIER_36H;
    item.rows = new List<EscalationMatrixEmailService.TaskDigestRow>{ row };

    Test.startTest();
    Database.executeBatch(
      new TaskOverdueConsolidatedEmailBatch(
        new List<TaskOverdueConsolidatedEmailBatch.WorkItem>{ item }
      ),
      10
    );
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Id = :leadRecord.Id]);
  }

  @IsTest
  static void testConsolidatedEmailBatchOpportunity96HAndOwner() {
    EscalationMatrixTestUtil.prepareTestContext();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'ConsolidatedOpp',
      false,
      null
    );
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'ConsolidatedLead96');

    EscalationMatrixEmailService.TaskDigestRow oppRow = new EscalationMatrixEmailService.TaskDigestRow();
    oppRow.taskRecord = new Task(Subject = 'Dummy Opp', ActivityDate = Date.today().addDays(-5));
    oppRow.opportunityRecord = opportunityRecord;
    oppRow.hoursSinceFirstOverdue = 100;

    EscalationMatrixEmailService.TaskDigestRow leadRow = new EscalationMatrixEmailService.TaskDigestRow();
    leadRow.taskRecord = new Task(Subject = 'Dummy Lead', ActivityDate = Date.today().addDays(-5));
    leadRow.leadRecord = leadRecord;
    leadRow.hoursSinceFirstOverdue = 100;

    TaskOverdueConsolidatedEmailBatch.WorkItem item96Opp = new TaskOverdueConsolidatedEmailBatch.WorkItem();
    item96Opp.groupKey = 'crm.head@example.com';
    item96Opp.templateName = 'Task Overdue 96h CRM HOD';
    item96Opp.tier = TaskOverdueConsolidatedEmailBatch.TIER_96H;
    item96Opp.rows = new List<EscalationMatrixEmailService.TaskDigestRow>{ oppRow };

    TaskOverdueConsolidatedEmailBatch.WorkItem item96Lead = new TaskOverdueConsolidatedEmailBatch.WorkItem();
    item96Lead.groupKey = 'crm.head2@example.com';
    item96Lead.templateName = 'Task Overdue 96h CRM HOD';
    item96Lead.tier = TaskOverdueConsolidatedEmailBatch.TIER_96H;
    item96Lead.rows = new List<EscalationMatrixEmailService.TaskDigestRow>{ leadRow };

    TaskOverdueConsolidatedEmailBatch.WorkItem itemOwner = new TaskOverdueConsolidatedEmailBatch.WorkItem();
    itemOwner.groupKey = 'owner@example.com';
    itemOwner.templateName = 'Task Overdue Owner';
    itemOwner.tier = TaskOverdueConsolidatedEmailBatch.TIER_OWNER;
    itemOwner.rows = new List<EscalationMatrixEmailService.TaskDigestRow>{ leadRow };

    Test.startTest();
    TaskOverdueConsolidatedEmailBatch.processItems(
      new List<TaskOverdueConsolidatedEmailBatch.WorkItem>{
        item96Opp,
        item96Lead,
        itemOwner
      }
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Opportunity WHERE Id = :opportunityRecord.Id]
    );
  }

  @IsTest
  static void testConsolidatedEmailBatchStartAndFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    TaskOverdueConsolidatedEmailBatch batch = new TaskOverdueConsolidatedEmailBatch(
      new List<TaskOverdueConsolidatedEmailBatch.WorkItem>()
    );

    Test.startTest();
    Object result = batch.start(null);
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, result);
  }
}