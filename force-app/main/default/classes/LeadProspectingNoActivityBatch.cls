/**
 * @description   Prospecting-stage 24h, 48h, 96h and 168h no-activity escalation emails.
 * @author        Anshita Chanda
 * @date          2026-08-10
 *
 * CHANGE LOG
 * - Added Database.Stateful so leads can be collected across all execute() chunks.
 * - 24h / 48h / 96h emails are now CONSOLIDATED (one email per recipient group,
 *   listing all matching leads).
 * - finish() no longer sends emails itself (that hit "Too many SOQL queries: 201").
 *   It hands the groups to LeadProspectingConsolidatedEmailBatch, which sends a few
 *   emails per transaction.
 * - 168h escalation removed (commented out, not deleted).
 */
// CHANGE: added "Database.Stateful"
public without sharing class LeadProspectingNoActivityBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String TEMPLATE_24H = 'Lead No Activity 24h Owner';
  private static final String TEMPLATE_48H = 'Lead No Activity 48h HOD';
  private static final String TEMPLATE_96H = 'Lead No Activity 96h Sir';
  //private static final String TEMPLATE_168H = 'Lead No Activity 168h Sir';

  @TestVisible
  private static Map<Id, Datetime> testLastProspectingActivityOverrides;

  // ---------------------------------------------------------------------------
  // NEW: state kept across execute() chunks (this is why Database.Stateful is needed).
  // Key   = recipient group key (sorted recipient emails joined by ';').
  //         24h -> effectively "one key per Lead Owner"
  //         48h -> effectively "one key per Department HOD / CRM Head group"
  //         96h -> one key (ED)
  // Value = all leads that must be listed in that one consolidated email.
  // ---------------------------------------------------------------------------
  private Map<String, List<Lead>> leadsByGroup24H = new Map<String, List<Lead>>();
  private Map<String, List<Lead>> leadsByGroup48H = new Map<String, List<Lead>>();
  private Map<String, List<Lead>> leadsByGroup96H = new Map<String, List<Lead>>();

  // NEW: hours-since-activity per lead, shown inside the consolidated email table.
  private Map<Id, Long> hoursByLeadId = new Map<Id, Long>();

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff24 = System.now().addHours(-24);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Owner.Email,
          Owner.Name, // NEW: shown in the consolidated email table
          Status,
          Department_Name__c,
          Department_NameFormula__c,
          Last_Prospecting_Activity__c,
          Prospecting_Escalation_24_Sent__c,
          Prospecting_Escalation_48_Sent__c,
          Prospecting_Escalation_72_Sent__c,
          //Prospecting_Escalation_168_Sent__c, // REMOVED: 168h escalation no longer used
          CRM_User_Email_Formula__c
        FROM Lead
        WHERE
          Status = 'Prospecting'
          AND IsConverted = FALSE
          AND Last_Prospecting_Activity__c != NULL
          AND Last_Prospecting_Activity__c <= :cutoff24
          AND (
            Prospecting_Escalation_24_Sent__c = FALSE
            OR Prospecting_Escalation_48_Sent__c = FALSE
            OR Prospecting_Escalation_72_Sent__c = FALSE
            //OR Prospecting_Escalation_168_Sent__c = FALSE // REMOVED: 168h escalation
          )
      ]
    );
  }

  /**
   * CHANGE: execute() no longer sends anything. It only decides which tier(s)
   * each lead qualifies for and groups the lead by recipient group.
   */
  public void execute(Database.BatchableContext context, List<Lead> scope) {
    for (Lead leadRecord : scope) {
      Datetime activityAnchor = resolveProspectingActivityAnchor(leadRecord);
      Long hoursSinceActivity = EscalationMatrixEmailService.hoursSince(activityAnchor);
      hoursByLeadId.put(leadRecord.Id, hoursSinceActivity);

      // 24h -> Owner (grouped per owner)
      if (
        !leadRecord.Prospecting_Escalation_24_Sent__c &&
        hoursSinceActivity >= 24
      ) {
        addLeadToGroup(
          leadsByGroup24H,
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.OWNER
        );
      }

      // 48h -> HOD + CRM Head (grouped per recipient group / department)
      if (
        !leadRecord.Prospecting_Escalation_48_Sent__c &&
        hoursSinceActivity >= 48
      ) {
        addLeadToGroup(
          leadsByGroup48H,
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        );
      }

      // 96h -> ED (single group). Existing behaviour kept: uses the _72_ checkbox.
      if (
        !leadRecord.Prospecting_Escalation_72_Sent__c &&
        hoursSinceActivity >= 96
      ) {
        addLeadToGroup(
          leadsByGroup96H,
          leadRecord,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }
    }
  }

  /**
   * NEW finish(): sends nothing itself. It converts the collected groups into
   * work items and hands them to LeadProspectingConsolidatedEmailBatch, which
   * processes a few emails per transaction (fresh governor limits per chunk).
   */
  public void finish(Database.BatchableContext context) {
    List<LeadProspectingConsolidatedEmailBatch.WorkItem> workItems = new List<LeadProspectingConsolidatedEmailBatch.WorkItem>();

    addWorkItems(
      workItems,
      leadsByGroup24H,
      TEMPLATE_24H,
      EscalationMatrixEmailService.RecipientGroup.OWNER,
      24
    );
    addWorkItems(
      workItems,
      leadsByGroup48H,
      TEMPLATE_48H,
      EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD,
      48
    );
    addWorkItems(
      workItems,
      leadsByGroup96H,
      TEMPLATE_96H,
      EscalationMatrixEmailService.RecipientGroup.ED_SIR,
      96
    );

    if (workItems.isEmpty()) {
      return;
    }

    if (Test.isRunningTest()) {
      // A test cannot chain a second executeBatch from finish(), so run inline.
      LeadProspectingConsolidatedEmailBatch.processItems(workItems, hoursByLeadId);
    } else {
      // 10 emails per chunk. Lower this number if you ever hit limits again.
      Database.executeBatch(
        new LeadProspectingConsolidatedEmailBatch(workItems, hoursByLeadId),
        10
      );
    }
  }

  // ===========================================================================
  // NEW HELPERS
  // ===========================================================================

  /**
   * Resolves recipients with the EXISTING recipient logic and groups the lead by
   * the resulting recipient list. Leads with identical recipients land in the same
   * bucket => one email per Owner / per HOD+CRM group / one for ED.
   */
  private static void addLeadToGroup(
    Map<String, List<Lead>> target,
    Lead leadRecord,
    EscalationMatrixEmailService.RecipientGroup recipientType
  ) {
    Set<String> recipients = EscalationMatrixEmailService.resolveLeadRecipients(
      leadRecord,
      recipientType
    );
    // No recipient => nothing to send; lead stays unflagged and is retried next run.
    if (recipients == null || recipients.isEmpty()) {
      return;
    }

    List<String> sortedRecipients = new List<String>(recipients);
    sortedRecipients.sort();
    String groupKey = String.join(sortedRecipients, ';');

    if (!target.containsKey(groupKey)) {
      target.put(groupKey, new List<Lead>());
    }
    target.get(groupKey).add(leadRecord);
  }

  /**
   * One work item per group (= one consolidated email).
   */
  private static void addWorkItems(
    List<LeadProspectingConsolidatedEmailBatch.WorkItem> target,
    Map<String, List<Lead>> groupedLeads,
    String templateName,
    EscalationMatrixEmailService.RecipientGroup recipientType,
    Integer tierHours
  ) {
    for (String groupKey : groupedLeads.keySet()) {
      LeadProspectingConsolidatedEmailBatch.WorkItem item = new LeadProspectingConsolidatedEmailBatch.WorkItem();
      item.groupKey = groupKey;
      item.templateName = templateName;
      item.recipientType = recipientType;
      item.tierHours = tierHours;
      item.leads = groupedLeads.get(groupKey);
      target.add(item);
    }
  }

  /**
   * PREVIOUS finish() (kept, NOT CALLED any more): sent every email in ONE transaction,
   * which failed with "Too many SOQL queries: 201" when there were many groups.
   * Replaced by LeadProspectingConsolidatedEmailBatch.
   */
    
    @TestVisible
  @SuppressWarnings('PMD.UnusedPrivateMethod')
  private void legacyFinishSingleTransaction() {
    // 1) Queue one email per group, per tier.
    queueConsolidatedEmails(
      leadsByGroup24H,
      TEMPLATE_24H,
      EscalationMatrixEmailService.RecipientGroup.OWNER
    );
    queueConsolidatedEmails(
      leadsByGroup48H,
      TEMPLATE_48H,
      EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
    );
    queueConsolidatedEmails(
      leadsByGroup96H,
      TEMPLATE_96H,
      EscalationMatrixEmailService.RecipientGroup.ED_SIR
    );

    // 2) Send everything that was queued.
    EscalationMatrixEmailService.flushQueuedEmails();

    // 3) Mark checkboxes only for groups whose email succeeded.
    Map<Id, Lead> updatesByLeadId = new Map<Id, Lead>();
    markSentFlags(leadsByGroup24H, TEMPLATE_24H, 24, updatesByLeadId);
    markSentFlags(leadsByGroup48H, TEMPLATE_48H, 48, updatesByLeadId);
    markSentFlags(leadsByGroup96H, TEMPLATE_96H, 96, updatesByLeadId);

    if (!updatesByLeadId.isEmpty()) {
      Database.update(updatesByLeadId.values(), false);
    }
  }

  // Used only by legacyFinishSingleTransaction().
  private void queueConsolidatedEmails(
    Map<String, List<Lead>> groupedLeads,
    String templateName,
    EscalationMatrixEmailService.RecipientGroup recipientType
  ) {
    for (String groupKey : groupedLeads.keySet()) {
      try {
        EscalationMatrixEmailService.sendConsolidatedLeadEmail(
          groupedLeads.get(groupKey),
          templateName,
          recipientType,
          groupKey,
          hoursByLeadId
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Consolidated lead email failed for group ' + groupKey + ': ' + ex.getMessage()
        );
      }
    }
  }

  // Used only by legacyFinishSingleTransaction().
  private void markSentFlags(
    Map<String, List<Lead>> groupedLeads,
    String templateName,
    Integer tierHours,
    Map<Id, Lead> updatesByLeadId
  ) {
    for (String groupKey : groupedLeads.keySet()) {
      if (
        !EscalationMatrixEmailService.wasConsolidatedSendSuccessful(
          groupKey,
          templateName
        )
      ) {
        continue;
      }

      for (Lead leadRecord : groupedLeads.get(groupKey)) {
        Lead updateRecord = updatesByLeadId.containsKey(leadRecord.Id)
          ? updatesByLeadId.get(leadRecord.Id)
          : new Lead(Id = leadRecord.Id);

        if (tierHours == 24) {
          updateRecord.Prospecting_Escalation_24_Sent__c = true;
        } else if (tierHours == 48) {
          updateRecord.Prospecting_Escalation_48_Sent__c = true;
        } else if (tierHours == 96) {
          updateRecord.Prospecting_Escalation_72_Sent__c = true;
        }
        updatesByLeadId.put(leadRecord.Id, updateRecord);
      }
    }
  }

  // ===========================================================================
  // ORIGINAL LOGIC (kept as-is, NOT CALLED any more).
  // Previously this was the body of execute(): one email per lead.
  // The 168h blocks stay commented out as in your original code.
  // ===========================================================================
   
  @TestVisible
  @SuppressWarnings('PMD.UnusedPrivateMethod')
  private void legacyExecutePerLead(List<Lead> scope) {
    for (Lead leadRecord : scope) {
      Datetime activityAnchor = resolveProspectingActivityAnchor(leadRecord);
      Long hoursSinceActivity = EscalationMatrixEmailService.hoursSince(activityAnchor);

      if (
        !leadRecord.Prospecting_Escalation_24_Sent__c &&
        hoursSinceActivity >= 24
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_24H,
          EscalationMatrixEmailService.RecipientGroup.OWNER
        );
      }

      if (
        !leadRecord.Prospecting_Escalation_48_Sent__c &&
        hoursSinceActivity >= 48
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_48H,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        );
      }

      if (
        !leadRecord.Prospecting_Escalation_72_Sent__c &&
        hoursSinceActivity >= 96
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_96H,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }

     /* if (
        !leadRecord.Prospecting_Escalation_168_Sent__c &&
        hoursSinceActivity >= 168
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_168H,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }*/
    }

    EscalationMatrixEmailService.flushQueuedEmails();

    List<Lead> leadsToUpdate = new List<Lead>();
    for (Lead leadRecord : scope) {
      Datetime activityAnchor = resolveProspectingActivityAnchor(leadRecord);
      Long hoursSinceActivity = EscalationMatrixEmailService.hoursSince(activityAnchor);

      Lead updateRecord = new Lead(Id = leadRecord.Id);
      Boolean changed = false;

      if (
        !leadRecord.Prospecting_Escalation_24_Sent__c &&
        hoursSinceActivity >= 24 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_24H)
      ) {
        updateRecord.Prospecting_Escalation_24_Sent__c = true;
        changed = true;
      }

      if (
        !leadRecord.Prospecting_Escalation_48_Sent__c &&
        hoursSinceActivity >= 48 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_48H)
      ) {
        updateRecord.Prospecting_Escalation_48_Sent__c = true;
        changed = true;
      }

      if (
        !leadRecord.Prospecting_Escalation_72_Sent__c &&
        hoursSinceActivity >= 96 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_96H)
      ) {
        updateRecord.Prospecting_Escalation_72_Sent__c = true;
        changed = true;
      }

     /* if (
        !leadRecord.Prospecting_Escalation_168_Sent__c &&
        hoursSinceActivity >= 168 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_168H)
      ) {
        updateRecord.Prospecting_Escalation_168_Sent__c = true;
        changed = true;
      }*/

      if (changed) {
        leadsToUpdate.add(updateRecord);
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      Database.update(leadsToUpdate, false);
    }
  }

  private static Datetime resolveProspectingActivityAnchor(Lead leadRecord) {
    if (
      Test.isRunningTest() &&
      testLastProspectingActivityOverrides != null &&
      testLastProspectingActivityOverrides.containsKey(leadRecord.Id)
    ) {
      return testLastProspectingActivityOverrides.get(leadRecord.Id);
    }

    return leadRecord.Last_Prospecting_Activity__c;
  }

  @TestVisible
  static void setTestLastProspectingActivity(Id leadId, Datetime activityDate) {
    if (testLastProspectingActivityOverrides == null) {
      testLastProspectingActivityOverrides = new Map<Id, Datetime>();
    }
    testLastProspectingActivityOverrides.put(leadId, activityDate);
  }

  @TestVisible
  static void clearTestLastProspectingActivityOverrides() {
    testLastProspectingActivityOverrides = null;
  }
}