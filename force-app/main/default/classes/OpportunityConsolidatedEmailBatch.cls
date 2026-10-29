/**
 * @description   Sends consolidated Opportunity escalation emails in small chunks so each
 *                chunk gets its own governor limits. Reusable by ALL Opportunity escalation
 *                batches: each WorkItem says which checkbox (flagField) to set on success.
 *                One WorkItem = ONE consolidated email (one recipient group, one tier).
 * @author        Anshita Chanda
 * @date          2026-10-13
 */
public without sharing class OpportunityConsolidatedEmailBatch implements Database.Batchable<OpportunityConsolidatedEmailBatch.WorkItem> {
  public class WorkItem {
    public String groupKey; // recipient group key (also used to track send success)
    public String templateName; // existing Lightning template name
    public EscalationMatrixEmailService.RecipientGroup recipientType; // existing recipient group
    public String flagField; // API name of the "sent" checkbox, e.g. EscalationNeg7Sent__c
    public List<Opportunity> opportunities; // all opportunities listed in this email
  }

  private List<WorkItem> items;
  private Map<Id, Long> daysByOpportunityId;

  public OpportunityConsolidatedEmailBatch(
    List<WorkItem> items,
    Map<Id, Long> daysByOpportunityId
  ) {
    this.items = items;
    this.daysByOpportunityId = daysByOpportunityId;
  }

  public Iterable<WorkItem> start(Database.BatchableContext context) {
    return items;
  }

  public void execute(Database.BatchableContext context, List<WorkItem> scope) {
    processItems(scope, daysByOpportunityId);
  }

  public void finish(Database.BatchableContext context) {
  }

  /**
   * Queues + sends the emails of this chunk, then sets the "sent" checkbox only on
   * opportunities whose consolidated email succeeded.
   * Public/static so the calling batch's finish() can run it inline in tests
   * (a test cannot chain a second executeBatch from finish()).
   */
  public static void processItems(List<WorkItem> scope, Map<Id, Long> daysByOpportunityId) {
    // 1) Queue one email per work item.
    for (WorkItem item : scope) {
      try {
        EscalationMatrixEmailService.sendConsolidatedOpportunityEmail(
          item.opportunities,
          item.templateName,
          item.recipientType,
          item.groupKey,
          daysByOpportunityId
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Consolidated opportunity email failed for group ' + item.groupKey + ': ' + ex.getMessage()
        );
      }
    }

    // 2) Send the queued emails.
    EscalationMatrixEmailService.flushQueuedEmails();

    // 3) Set checkboxes only for successful emails. An opportunity can be in several items
    //    (7d + 14d ...), so merge flags into one record per Opportunity (no duplicate Ids).
    Map<Id, Opportunity> updatesById = new Map<Id, Opportunity>();
    for (WorkItem item : scope) {
      if (
        !EscalationMatrixEmailService.wasConsolidatedSendSuccessful(
          item.groupKey,
          item.templateName
        )
      ) {
        continue;
      }

      for (Opportunity opportunityRecord : item.opportunities) {
        Opportunity updateRecord = updatesById.containsKey(opportunityRecord.Id)
          ? updatesById.get(opportunityRecord.Id)
          : new Opportunity(Id = opportunityRecord.Id);
        updateRecord.put(item.flagField, true);
        updatesById.put(opportunityRecord.Id, updateRecord);
      }
    }

    // Existing helper: partial update, skips approval-locked opportunities.
    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(updatesById.values());
  }
}