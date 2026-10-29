/**
 * @description   Task overdue escalation emails for owner, 36h HOD, and 96h CRM HOD.
 * @author        Anshita Chanda
 * @date          2026-08-10
 *
 * CHANGE LOG
 * - Added Database.Stateful so rows can be collected across all execute() chunks.
 * - Owner / 36h / 96h emails are now CONSOLIDATED (one email per recipient group, listing
 *   all matching overdue tasks).
 * - execute() groups the rows and stamps FirstOverdueTaskDate__c (as before).
 *   finish() hands the groups to TaskOverdueConsolidatedEmailBatch, which sends a few
 *   emails per transaction and then sets the 36h / 96h checkboxes for successful emails.
 * - Original per-record logic is preserved in legacyExecutePerRecord() and the original
 *   helper methods (no longer called).
 */
// CHANGE: added "Database.Stateful"
public without sharing class TaskOverdueEscalationMatrixBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String TEMPLATE_OWNER = 'Task Overdue Owner';
  private static final String TEMPLATE_36H = 'Task Overdue 36h HOD';
  private static final String TEMPLATE_96H = 'Task Overdue 96h CRM HOD';

  // ---------------------------------------------------------------------------
  // NEW: state kept across execute() chunks.
  // Key   = recipient group key (sorted recipient emails joined by ';').
  // Value = all rows (Lead/Opportunity + its overdue Task) listed in that one email.
  // ---------------------------------------------------------------------------
  private Map<String, List<EscalationMatrixEmailService.TaskDigestRow>> rowsByGroupOwner = new Map<String, List<EscalationMatrixEmailService.TaskDigestRow>>();
  private Map<String, List<EscalationMatrixEmailService.TaskDigestRow>> rowsByGroup36H = new Map<String, List<EscalationMatrixEmailService.TaskDigestRow>>();
  private Map<String, List<EscalationMatrixEmailService.TaskDigestRow>> rowsByGroup96H = new Map<String, List<EscalationMatrixEmailService.TaskDigestRow>>();

  // NEW: records already handled in this job, so one record never appears twice
  // (the same Lead/Opportunity can own several overdue tasks in different chunks).
  private Set<Id> processedOpportunityIdsAll = new Set<Id>();
  private Set<Id> processedLeadIdsAll = new Set<Id>();

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id, Subject, Status, ActivityDate, WhatId, WhoId, OwnerId
        FROM Task
        WHERE
          Status != 'Completed'
          AND ActivityDate != NULL
          AND ActivityDate < TODAY
          AND (WhatId != NULL OR WhoId != NULL)
      ]
    );
  }

  /**
   * CHANGE: execute() no longer sends anything. It groups each Lead/Opportunity by the
   * recipients of every tier it qualifies for, and stamps FirstOverdueTaskDate__c.
   */
  public void execute(Database.BatchableContext context, List<Task> scope) {
    Set<Id> opportunityIds = new Set<Id>();
    Set<Id> leadIds = new Set<Id>();

    for (Task taskRecord : scope) {
      if (taskRecord.WhatId != null && taskRecord.WhatId.getSobjectType() == Opportunity.SObjectType) {
        opportunityIds.add(taskRecord.WhatId);
      }
      if (taskRecord.WhoId != null && taskRecord.WhoId.getSobjectType() == Lead.SObjectType) {
        leadIds.add(taskRecord.WhoId);
      }
    }

    Map<Id, Opportunity> opportunityById = queryOpportunities(opportunityIds);
    Map<Id, Lead> leadById = queryLeads(leadIds);
    Set<Id> processedOpportunityIds = new Set<Id>(); // this chunk only (for the stamp update)
    Set<Id> processedLeadIds = new Set<Id>(); // this chunk only (for the stamp update)

    for (Task taskRecord : scope) {
      if (
        taskRecord.WhatId != null &&
        opportunityById.containsKey(taskRecord.WhatId) &&
        !processedOpportunityIdsAll.contains(taskRecord.WhatId)
      ) {
        processedOpportunityIdsAll.add(taskRecord.WhatId);
        processedOpportunityIds.add(taskRecord.WhatId);
        groupOpportunityTask(opportunityById.get(taskRecord.WhatId), taskRecord);
      } else if (
        taskRecord.WhoId != null &&
        leadById.containsKey(taskRecord.WhoId) &&
        !processedLeadIdsAll.contains(taskRecord.WhoId)
      ) {
        processedLeadIdsAll.add(taskRecord.WhoId);
        processedLeadIds.add(taskRecord.WhoId);
        groupLeadTask(leadById.get(taskRecord.WhoId), taskRecord);
      }
    }

    // Stamp the first-overdue anchor now (same behaviour as before: it is stamped even
    // if the owner email later fails, so the 36h/96h ladder can progress).
    List<Opportunity> opportunitiesToStamp = new List<Opportunity>();
    for (Id opportunityId : processedOpportunityIds) {
      Opportunity stamp = buildOpportunityStamp(opportunityById.get(opportunityId));
      if (stamp != null) {
        opportunitiesToStamp.add(stamp);
      }
    }

    List<Lead> leadsToStamp = new List<Lead>();
    for (Id leadId : processedLeadIds) {
      Lead stamp = buildLeadStamp(leadById.get(leadId));
      if (stamp != null) {
        leadsToStamp.add(stamp);
      }
    }

    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(opportunitiesToStamp);
    if (!leadsToStamp.isEmpty()) {
      Database.update(leadsToStamp, false);
    }
  }

  /**
   * NEW finish(): sends nothing itself. Converts the collected groups into work items
   * and hands them to TaskOverdueConsolidatedEmailBatch (fresh limits per chunk).
   */
  public void finish(Database.BatchableContext context) {
    List<TaskOverdueConsolidatedEmailBatch.WorkItem> workItems = new List<TaskOverdueConsolidatedEmailBatch.WorkItem>();

    addWorkItems(
      workItems,
      rowsByGroupOwner,
      TEMPLATE_OWNER,
      TaskOverdueConsolidatedEmailBatch.TIER_OWNER
    );
    addWorkItems(
      workItems,
      rowsByGroup36H,
      TEMPLATE_36H,
      TaskOverdueConsolidatedEmailBatch.TIER_36H
    );
    addWorkItems(
      workItems,
      rowsByGroup96H,
      TEMPLATE_96H,
      TaskOverdueConsolidatedEmailBatch.TIER_96H
    );
      
       System.debug('***line 146' + workItems);

    if (workItems.isEmpty()) {
      return;
    }

    if (Test.isRunningTest()) {
      // A test cannot chain a second executeBatch from finish(), so run inline.
      TaskOverdueConsolidatedEmailBatch.processItems(workItems);
    } else {
      // 10 emails per chunk. Lower this number if you ever hit limits again.
      Database.executeBatch(new TaskOverdueConsolidatedEmailBatch(workItems), 10);
    }
  }

  // ===========================================================================
  // NEW HELPERS
  // ===========================================================================

  /**
   * Decides which tiers an Opportunity qualifies for (same conditions as the original
   * queueOpportunityEmails) and adds a row to the matching recipient group.
   */
  private void groupOpportunityTask(Opportunity opportunityRecord, Task taskRecord) {
    Datetime firstOverdueDate = opportunityRecord.FirstOverdueTaskDate__c != null
      ? opportunityRecord.FirstOverdueTaskDate__c
      : System.now();
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    EscalationMatrixEmailService.TaskDigestRow row = new EscalationMatrixEmailService.TaskDigestRow();
    row.taskRecord = taskRecord;
    row.opportunityRecord = opportunityRecord;
    row.hoursSinceFirstOverdue = hoursSinceFirstOverdue;

    if (opportunityRecord.FirstOverdueTaskDate__c == null) {
      addRowToGroup(
        rowsByGroupOwner,
        row,
        EscalationMatrixEmailService.resolveOpportunityRecipients(
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.OWNER
        )
      );
    }

    if (
      opportunityRecord.OppOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36
    ) {
      addRowToGroup(
        rowsByGroup36H,
        row,
        EscalationMatrixEmailService.resolveOpportunityRecipients(
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.HOD_ONLY
        )
      );
    }

    if (
      opportunityRecord.OppOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96
    ) {
      addRowToGroup(
        rowsByGroup96H,
        row,
        EscalationMatrixEmailService.resolveOpportunityRecipients(
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.CRM_HEAD_ONLY
        )
      );
    }
  }

  /**
   * Same as above for a Lead (mirrors the original queueLeadEmails conditions).
   */
  private void groupLeadTask(Lead leadRecord, Task taskRecord) {
    Datetime firstOverdueDate = leadRecord.FirstOverdueTaskDate__c != null
      ? leadRecord.FirstOverdueTaskDate__c
      : System.now();
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    EscalationMatrixEmailService.TaskDigestRow row = new EscalationMatrixEmailService.TaskDigestRow();
    row.taskRecord = taskRecord;
    row.leadRecord = leadRecord;
    row.hoursSinceFirstOverdue = hoursSinceFirstOverdue;

    if (leadRecord.FirstOverdueTaskDate__c == null) {
      addRowToGroup(
        rowsByGroupOwner,
        row,
        EscalationMatrixEmailService.resolveLeadRecipients(
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.OWNER
        )
      );
    }

    if (
      leadRecord.LeadOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36
    ) {
      addRowToGroup(
        rowsByGroup36H,
        row,
        EscalationMatrixEmailService.resolveLeadRecipients(
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.HOD_ONLY
        )
      );
    }

    if (
      leadRecord.LeadOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96
    ) {
      addRowToGroup(
        rowsByGroup96H,
        row,
        EscalationMatrixEmailService.resolveLeadRecipients(
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.CRM_HEAD_ONLY
        )
      );
    }
  }

  /**
   * Groups a row by its recipients (sorted + joined) => one email per recipient group.
   * No recipients => nothing to send; the record is retried on the next run.
   */
  private static void addRowToGroup(
    Map<String, List<EscalationMatrixEmailService.TaskDigestRow>> target,
    EscalationMatrixEmailService.TaskDigestRow row,
    Set<String> recipients
  ) {
    if (recipients == null || recipients.isEmpty()) {
      return;
    }

    List<String> sortedRecipients = new List<String>(recipients);
    sortedRecipients.sort();
    String groupKey = String.join(sortedRecipients, ';');

    if (!target.containsKey(groupKey)) {
      target.put(groupKey, new List<EscalationMatrixEmailService.TaskDigestRow>());
    }
    target.get(groupKey).add(row);
  }

  /**
   * One work item per group (= one consolidated email).
   */
  private static void addWorkItems(
    List<TaskOverdueConsolidatedEmailBatch.WorkItem> target,
    Map<String, List<EscalationMatrixEmailService.TaskDigestRow>> groupedRows,
    String templateName,
    String tier
  ) {
    for (String groupKey : groupedRows.keySet()) {
      TaskOverdueConsolidatedEmailBatch.WorkItem item = new TaskOverdueConsolidatedEmailBatch.WorkItem();
      item.groupKey = groupKey;
      item.templateName = templateName;
      item.tier = tier;
      item.rows = groupedRows.get(groupKey);
      target.add(item);
    }
  }

  /**
   * Stamps the first-overdue anchor on an Opportunity seen for the first time.
   * (The 36h/96h checkboxes are now set later, after the consolidated email succeeds.)
   */
  private static Opportunity buildOpportunityStamp(Opportunity opportunityRecord) {
    if (opportunityRecord == null || opportunityRecord.FirstOverdueTaskDate__c != null) {
      return null;
    }
    Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
    updateRecord.FirstOverdueTaskDate__c = System.now();
    updateRecord.OppOverdueEsc36Sent__c = false;
    updateRecord.OppOverdueEsc96Sent__c = false;
    return updateRecord;
  }

  private static Lead buildLeadStamp(Lead leadRecord) {
    if (leadRecord == null || leadRecord.FirstOverdueTaskDate__c != null) {
      return null;
    }
    Lead updateRecord = new Lead(Id = leadRecord.Id);
    updateRecord.FirstOverdueTaskDate__c = System.now();
    updateRecord.LeadOverdueEsc36Sent__c = false;
    updateRecord.LeadOverdueEsc96Sent__c = false;
    return updateRecord;
  }

  // ===========================================================================
  // ORIGINAL LOGIC (kept as-is, NOT CALLED any more).
  // Previously this was the body of execute(): one email per Lead/Opportunity.
  // ===========================================================================
  @SuppressWarnings('PMD.UnusedPrivateMethod')
    @TestVisible
  private void legacyExecutePerRecord(List<Task> scope) {
    Set<Id> opportunityIds = new Set<Id>();
    Set<Id> leadIds = new Set<Id>();

    for (Task taskRecord : scope) {
      if (taskRecord.WhatId != null && taskRecord.WhatId.getSobjectType() == Opportunity.SObjectType) {
        opportunityIds.add(taskRecord.WhatId);
      }
      if (taskRecord.WhoId != null && taskRecord.WhoId.getSobjectType() == Lead.SObjectType) {
        leadIds.add(taskRecord.WhoId);
      }
    }

    Map<Id, Opportunity> opportunityById = queryOpportunities(opportunityIds);
    Map<Id, Lead> leadById = queryLeads(leadIds);
    Set<Id> processedOpportunityIds = new Set<Id>();
    Set<Id> processedLeadIds = new Set<Id>();

    for (Task taskRecord : scope) {
      if (
        taskRecord.WhatId != null &&
        opportunityById.containsKey(taskRecord.WhatId) &&
        !processedOpportunityIds.contains(taskRecord.WhatId)
      ) {
        processedOpportunityIds.add(taskRecord.WhatId);
        queueOpportunityEmails(opportunityById.get(taskRecord.WhatId), taskRecord);
      } else if (
        taskRecord.WhoId != null &&
        leadById.containsKey(taskRecord.WhoId) &&
        !processedLeadIds.contains(taskRecord.WhoId)
      ) {
        processedLeadIds.add(taskRecord.WhoId);
        queueLeadEmails(leadById.get(taskRecord.WhoId), taskRecord);
      }
    }

    EscalationMatrixEmailService.flushQueuedEmails();

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (Id opportunityId : processedOpportunityIds) {
      Opportunity opportunityRecord = opportunityById.get(opportunityId);
      Opportunity updateRecord = buildOpportunityUpdate(opportunityRecord);
      if (updateRecord != null) {
        opportunitiesToUpdate.add(updateRecord);
      }
    }

    List<Lead> leadsToUpdate = new List<Lead>();
    for (Id leadId : processedLeadIds) {
      Lead leadRecord = leadById.get(leadId);
      Lead updateRecord = buildLeadUpdate(leadRecord);
      if (updateRecord != null) {
        leadsToUpdate.add(updateRecord);
      }
    }

    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(opportunitiesToUpdate);
    if (!leadsToUpdate.isEmpty()) {
      Database.update(leadsToUpdate, false);
    }
  }

  private static void queueOpportunityEmails(
    Opportunity opportunityRecord,
    Task taskRecord
  ) {
    if (opportunityRecord.FirstOverdueTaskDate__c == null) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_OWNER,
        EscalationMatrixEmailService.RecipientGroup.OWNER,
        null,
        opportunityRecord
      );
    }

    Datetime firstOverdueDate = opportunityRecord.FirstOverdueTaskDate__c != null
      ? opportunityRecord.FirstOverdueTaskDate__c
      : System.now();
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    if (
      opportunityRecord.OppOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36
    ) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_36H,
        EscalationMatrixEmailService.RecipientGroup.HOD_ONLY,
        null,
        opportunityRecord
      );
    }

    if (
      opportunityRecord.OppOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96
    ) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_96H,
        EscalationMatrixEmailService.RecipientGroup.CRM_HEAD_ONLY,
        null,
        opportunityRecord
      );
    }
  }

  private static void queueLeadEmails(Lead leadRecord, Task taskRecord) {
    if (leadRecord.FirstOverdueTaskDate__c == null) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_OWNER,
        EscalationMatrixEmailService.RecipientGroup.OWNER,
        leadRecord,
        null
      );
    }

    Datetime firstOverdueDate = leadRecord.FirstOverdueTaskDate__c != null
      ? leadRecord.FirstOverdueTaskDate__c
      : System.now();
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    if (
      leadRecord.LeadOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36
    ) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_36H,
        EscalationMatrixEmailService.RecipientGroup.HOD_ONLY,
        leadRecord,
        null
      );
    }

    if (
      leadRecord.LeadOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96
    ) {
      EscalationMatrixEmailService.sendTaskRelatedEmail(
        taskRecord,
        TEMPLATE_96H,
        EscalationMatrixEmailService.RecipientGroup.CRM_HEAD_ONLY,
        leadRecord,
        null
      );
    }
  }

  private static Opportunity buildOpportunityUpdate(Opportunity opportunityRecord) {
    Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
    Boolean changed = false;

    // Stamp overdue anchor so 36h/96h ladder can progress even if owner email hit a limit.
    if (opportunityRecord.FirstOverdueTaskDate__c == null) {
      updateRecord.FirstOverdueTaskDate__c = System.now();
      updateRecord.OppOverdueEsc36Sent__c = false;
      updateRecord.OppOverdueEsc96Sent__c = false;
      changed = true;
    }

    Datetime firstOverdueDate = updateRecord.FirstOverdueTaskDate__c != null
      ? updateRecord.FirstOverdueTaskDate__c
      : opportunityRecord.FirstOverdueTaskDate__c;
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    if (
      opportunityRecord.OppOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36 &&
      EscalationMatrixEmailService.wasSendSuccessful(opportunityRecord.Id, TEMPLATE_36H)
    ) {
      updateRecord.OppOverdueEsc36Sent__c = true;
      changed = true;
    }

    if (
      opportunityRecord.OppOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96 &&
      EscalationMatrixEmailService.wasSendSuccessful(opportunityRecord.Id, TEMPLATE_96H)
    ) {
      updateRecord.OppOverdueEsc96Sent__c = true;
      changed = true;
    }

    return changed ? updateRecord : null;
  }

  private static Lead buildLeadUpdate(Lead leadRecord) {
    Lead updateRecord = new Lead(Id = leadRecord.Id);
    Boolean changed = false;

    if (leadRecord.FirstOverdueTaskDate__c == null) {
      updateRecord.FirstOverdueTaskDate__c = System.now();
      updateRecord.LeadOverdueEsc36Sent__c = false;
      updateRecord.LeadOverdueEsc96Sent__c = false;
      changed = true;
    }

    Datetime firstOverdueDate = updateRecord.FirstOverdueTaskDate__c != null
      ? updateRecord.FirstOverdueTaskDate__c
      : leadRecord.FirstOverdueTaskDate__c;
    Long hoursSinceFirstOverdue = EscalationMatrixEmailService.hoursSince(firstOverdueDate);

    if (
      leadRecord.LeadOverdueEsc36Sent__c != true &&
      hoursSinceFirstOverdue >= 36 &&
      EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_36H)
    ) {
      updateRecord.LeadOverdueEsc36Sent__c = true;
      changed = true;
    }

    if (
      leadRecord.LeadOverdueEsc96Sent__c != true &&
      hoursSinceFirstOverdue >= 96 &&
      EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_96H)
    ) {
      updateRecord.LeadOverdueEsc96Sent__c = true;
      changed = true;
    }

    return changed ? updateRecord : null;
  }

  private static Map<Id, Opportunity> queryOpportunities(Set<Id> opportunityIds) {
    Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>();
    if (opportunityIds.isEmpty()) {
      return opportunityById;
    }

    for (Opportunity opportunityRecord : [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Name,
        Owner.Email,
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        FirstOverdueTaskDate__c,
        OppOverdueEsc36Sent__c,
        OppOverdueEsc96Sent__c
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ]) {
      opportunityById.put(opportunityRecord.Id, opportunityRecord);
    }
    return opportunityById;
  }

  private static Map<Id, Lead> queryLeads(Set<Id> leadIds) {
    Map<Id, Lead> leadById = new Map<Id, Lead>();
    if (leadIds.isEmpty()) {
      return leadById;
    }

    for (Lead leadRecord : [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Name,
        Owner.Email,
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        FirstOverdueTaskDate__c,
        LeadOverdueEsc36Sent__c,
        LeadOverdueEsc96Sent__c
      FROM Lead
      WHERE Id IN :leadIds
    ]) {
      leadById.put(leadRecord.Id, leadRecord);
    }
    return leadById;
  }
}