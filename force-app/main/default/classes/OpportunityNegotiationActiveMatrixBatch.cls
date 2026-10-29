/**
 * @description   Negotiation-stage active opportunity no-activity escalation emails.
 * @author        Anshita Chanda
 * @date          2026-08-10
 *
 * CHANGE LOG
 * - Added Database.Stateful so opportunities can be collected across all execute() chunks.
 * - 7d / 14d / 21d emails are now CONSOLIDATED (one email per recipient group, listing
 *   all matching opportunities).
 * - execute() only groups. finish() hands the groups to OpportunityConsolidatedEmailBatch,
 *   which sends a few emails per transaction (avoids "Too many SOQL queries: 201").
 * - Original per-opportunity logic is preserved in legacyExecutePerOpportunity()
 *   (no longer called).
 */
// CHANGE: added "Database.Stateful"
public without sharing class OpportunityNegotiationActiveMatrixBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String TEMPLATE_7D = 'Negotiation Active 7d Owner';
  private static final String TEMPLATE_14D = 'Negotiation Active 14d HOD';
  private static final String TEMPLATE_21D = 'Negotiation Active 21d Sir';

  // ---------------------------------------------------------------------------
  // NEW: state kept across execute() chunks.
  // Key   = recipient group key (sorted recipient emails joined by ';').
  // Value = all opportunities listed in that one consolidated email.
  // ---------------------------------------------------------------------------
  private Map<String, List<Opportunity>> oppsByGroup7D = new Map<String, List<Opportunity>>();
  private Map<String, List<Opportunity>> oppsByGroup14D = new Map<String, List<Opportunity>>();
  private Map<String, List<Opportunity>> oppsByGroup21D = new Map<String, List<Opportunity>>();

  // NEW: days-since-activity per opportunity, shown in the consolidated email table.
  private Map<Id, Long> daysByOpportunityId = new Map<Id, Long>();

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Owner.Email,
          Owner.Name, // NEW: shown in the consolidated email table
          StageName,
          CreatedDate,
          Budget_Confirmed__c,
          RecordType.DeveloperName,
          Department_Name__c,
          Department_NameFormula__c,
          CRM_User_Email_Formula__c,
          EscalationNeg7Sent__c,
          EscalationNeg14Sent__c,
          EscalationNeg21Sent__c
        FROM Opportunity
        WHERE
          StageName = 'Negotiation'
          AND IsClosed = FALSE
          AND RecordType.DeveloperName != 'Tender_Opportunity'
          AND Budget_Confirmed__c = FALSE
          AND (
            EscalationNeg7Sent__c = FALSE
            OR EscalationNeg14Sent__c = FALSE
            OR EscalationNeg21Sent__c = FALSE
          )
      ]
    );
  }

  /**
   * CHANGE: execute() no longer sends anything. It only decides which tier(s) each
   * opportunity qualifies for and groups it by recipient group.
   */
  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    Map<Id, Date> lastActivityByOpportunityId = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Map<Id, Opportunity>(scope).keySet()
    );

    for (Opportunity opportunityRecord : scope) {
      Date lastActivityDate = lastActivityByOpportunityId.get(opportunityRecord.Id);
      Long daysSinceActivity = EscalationMatrixEmailService.daysSince(lastActivityDate);
      daysByOpportunityId.put(opportunityRecord.Id, daysSinceActivity);

      // 7d -> Owner + CRM
      if (!opportunityRecord.EscalationNeg7Sent__c && daysSinceActivity >= 7) {
        addOpportunityToGroup(
          oppsByGroup7D,
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM
        );
      }

      // 14d -> HOD + CRM Head
      if (!opportunityRecord.EscalationNeg14Sent__c && daysSinceActivity >= 14) {
        addOpportunityToGroup(
          oppsByGroup14D,
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        );
      }

      // 21d -> ED
      if (!opportunityRecord.EscalationNeg21Sent__c && daysSinceActivity >= 21) {
        addOpportunityToGroup(
          oppsByGroup21D,
          opportunityRecord,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }
    }
  }

  /**
   * NEW finish(): sends nothing itself. Converts the collected groups into work items
   * and hands them to OpportunityConsolidatedEmailBatch (fresh limits per chunk).
   */
  public void finish(Database.BatchableContext context) {
    List<OpportunityConsolidatedEmailBatch.WorkItem> workItems = new List<OpportunityConsolidatedEmailBatch.WorkItem>();

    addWorkItems(
      workItems,
      oppsByGroup7D,
      TEMPLATE_7D,
      EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM,
      'EscalationNeg7Sent__c'
    );
    addWorkItems(
      workItems,
      oppsByGroup14D,
      TEMPLATE_14D,
      EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD,
      'EscalationNeg14Sent__c'
    );
    addWorkItems(
      workItems,
      oppsByGroup21D,
      TEMPLATE_21D,
      EscalationMatrixEmailService.RecipientGroup.ED_SIR,
      'EscalationNeg21Sent__c'
    );

    if (workItems.isEmpty()) {
      return;
    }

    if (Test.isRunningTest()) {
      // A test cannot chain a second executeBatch from finish(), so run inline.
      OpportunityConsolidatedEmailBatch.processItems(workItems, daysByOpportunityId);
    } else {
      // 10 emails per chunk. Lower this number if you ever hit limits again.
      Database.executeBatch(
        new OpportunityConsolidatedEmailBatch(workItems, daysByOpportunityId),
        10
      );
    }
  }

  // ===========================================================================
  // NEW HELPERS
  // ===========================================================================

  /**
   * Resolves recipients with the EXISTING recipient logic and groups the opportunity by
   * the resulting recipient list => one email per recipient group.
   */
  private static void addOpportunityToGroup(
    Map<String, List<Opportunity>> target,
    Opportunity opportunityRecord,
    EscalationMatrixEmailService.RecipientGroup recipientType
  ) {
    Set<String> recipients = EscalationMatrixEmailService.resolveOpportunityRecipients(
      opportunityRecord,
      recipientType
    );
    // No recipient => nothing to send; stays unflagged and is retried next run.
    if (recipients == null || recipients.isEmpty()) {
      return;
    }

    List<String> sortedRecipients = new List<String>(recipients);
    sortedRecipients.sort();
    String groupKey = String.join(sortedRecipients, ';');

    if (!target.containsKey(groupKey)) {
      target.put(groupKey, new List<Opportunity>());
    }
    target.get(groupKey).add(opportunityRecord);
  }

  /**
   * One work item per group (= one consolidated email).
   */
  private static void addWorkItems(
    List<OpportunityConsolidatedEmailBatch.WorkItem> target,
    Map<String, List<Opportunity>> groupedOpportunities,
    String templateName,
    EscalationMatrixEmailService.RecipientGroup recipientType,
    String flagField
  ) {
    for (String groupKey : groupedOpportunities.keySet()) {
      OpportunityConsolidatedEmailBatch.WorkItem item = new OpportunityConsolidatedEmailBatch.WorkItem();
      item.groupKey = groupKey;
      item.templateName = templateName;
      item.recipientType = recipientType;
      item.flagField = flagField;
      item.opportunities = groupedOpportunities.get(groupKey);
      target.add(item);
    }
  }

  // ===========================================================================
  // ORIGINAL LOGIC (kept as-is, NOT CALLED any more).
  // Previously this was the body of execute(): one email per opportunity.
  // ===========================================================================
  @SuppressWarnings('PMD.UnusedPrivateMethod')
    @TestVisible
  private void legacyExecutePerOpportunity(List<Opportunity> scope) {
    Map<Id, Date> lastActivityByOpportunityId = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Map<Id, Opportunity>(scope).keySet()
    );
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    for (Opportunity opportunityRecord : scope) {
      Date lastActivityDate = lastActivityByOpportunityId.get(opportunityRecord.Id);
      Long daysSinceActivity = EscalationMatrixEmailService.daysSince(lastActivityDate);

      Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
      Boolean changed = false;

      if (
        !opportunityRecord.EscalationNeg7Sent__c &&
        daysSinceActivity >= 7 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_7D,
          EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM
        )
      ) {
        updateRecord.EscalationNeg7Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.EscalationNeg14Sent__c &&
        daysSinceActivity >= 14 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_14D,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        )
      ) {
        updateRecord.EscalationNeg14Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.EscalationNeg21Sent__c &&
        daysSinceActivity >= 21 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_21D,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        )
      ) {
        updateRecord.EscalationNeg21Sent__c = true;
        changed = true;
      }

      if (changed) {
        opportunitiesToUpdate.add(updateRecord);
      }
    }

    EscalationMatrixEmailService.flushQueuedEmails();
    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(
      confirmOpportunityUpdates(opportunitiesToUpdate)
    );
  }

  private static List<Opportunity> confirmOpportunityUpdates(
    List<Opportunity> candidates
  ) {
    List<Opportunity> confirmed = new List<Opportunity>();
    if (candidates == null || candidates.isEmpty()) {
      return confirmed;
    }
    for (Opportunity candidate : candidates) {
      if (candidate == null || candidate.Id == null) {
        continue;
      }
      Opportunity filtered = new Opportunity(Id = candidate.Id);
      Boolean changed = false;
      if (candidate.EscalationNeg7Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_7D)) {
        filtered.EscalationNeg7Sent__c = true;
        changed = true;
      }
      if (candidate.EscalationNeg14Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_14D)) {
        filtered.EscalationNeg14Sent__c = true;
        changed = true;
      }
      if (candidate.EscalationNeg21Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_21D)) {
        filtered.EscalationNeg21Sent__c = true;
        changed = true;
      }
      if (changed) {
        confirmed.add(filtered);
      }
    }
    return confirmed;
  }
}