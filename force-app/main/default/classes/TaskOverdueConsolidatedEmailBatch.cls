/**
 * @description   Sends the consolidated Task-overdue emails (Owner / 36h HOD / 96h CRM Head)
 *                in small chunks so each chunk gets its own governor limits.
 *                Started from TaskOverdueEscalationMatrixBatch.finish().
 *                One WorkItem = ONE consolidated email (one recipient group, one tier).
 * @author        Anshita Chanda
 * @date          2026-10-14
 */
public without sharing class TaskOverdueConsolidatedEmailBatch implements Database.Batchable<TaskOverdueConsolidatedEmailBatch.WorkItem> {
  public static final String TIER_OWNER = 'OWNER';
  public static final String TIER_36H = '36H';
  public static final String TIER_96H = '96H';

  public class WorkItem {
    public String groupKey; // recipient group key (sorted emails joined by ';')
    public String templateName; // existing Lightning template name
    public String tier; // TIER_OWNER, TIER_36H or TIER_96H
    public List<EscalationMatrixEmailService.TaskDigestRow> rows; // rows listed in this email
  }

  private List<WorkItem> items;

  public TaskOverdueConsolidatedEmailBatch(List<WorkItem> items) {
    this.items = items;
  }

  public Iterable<WorkItem> start(Database.BatchableContext context) {
    return items;
  }

  public void execute(Database.BatchableContext context, List<WorkItem> scope) {
    processItems(scope);
  }

  public void finish(Database.BatchableContext context) {
  }

  /**
   * Queues + sends the emails of this chunk, then sets the 36h / 96h "sent" checkbox only
   * on records whose consolidated email succeeded.
   * The Owner tier has no checkbox: the first-overdue stamp (set by the main batch) is its marker.
   * Public/static so the main batch's finish() can run it inline in tests.
   */
  public static void processItems(List<WorkItem> scope) {
    // 1) Queue one email per work item.
    for (WorkItem item : scope) {
      try {
        EscalationMatrixEmailService.sendConsolidatedTaskEmail(
          item.rows,
          item.templateName,
          item.groupKey
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Consolidated task email failed for group ' + item.groupKey + ': ' + ex.getMessage()
        );
      }
    }

    // 2) Send the queued emails.
    EscalationMatrixEmailService.flushQueuedEmails();

    // 3) Set checkboxes only for successful emails. A record can be in the 36h and 96h
    //    items in the same chunk, so merge flags into one record per Id.
    Map<Id, Opportunity> opportunityUpdates = new Map<Id, Opportunity>();
    Map<Id, Lead> leadUpdates = new Map<Id, Lead>();

    for (WorkItem item : scope) {
      if (item.tier == TIER_OWNER) {
        continue; // no checkbox for the owner email
      }
      if (
        !EscalationMatrixEmailService.wasConsolidatedSendSuccessful(
          item.groupKey,
          item.templateName
        )
      ) {
        continue;
      }

      for (EscalationMatrixEmailService.TaskDigestRow row : item.rows) {
        if (row.opportunityRecord != null) {
          Opportunity updateRecord = opportunityUpdates.containsKey(row.opportunityRecord.Id)
            ? opportunityUpdates.get(row.opportunityRecord.Id)
            : new Opportunity(Id = row.opportunityRecord.Id);
          if (item.tier == TIER_36H) {
            updateRecord.OppOverdueEsc36Sent__c = true;
          } else if (item.tier == TIER_96H) {
            updateRecord.OppOverdueEsc96Sent__c = true;
          }
          opportunityUpdates.put(row.opportunityRecord.Id, updateRecord);
        } else if (row.leadRecord != null) {
          Lead updateRecord = leadUpdates.containsKey(row.leadRecord.Id)
            ? leadUpdates.get(row.leadRecord.Id)
            : new Lead(Id = row.leadRecord.Id);
          if (item.tier == TIER_36H) {
            updateRecord.LeadOverdueEsc36Sent__c = true;
          } else if (item.tier == TIER_96H) {
            updateRecord.LeadOverdueEsc96Sent__c = true;
          }
          leadUpdates.put(row.leadRecord.Id, updateRecord);
        }
      }
    }

    // Existing helper: partial update, skips approval-locked opportunities.
    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(opportunityUpdates.values());
    if (!leadUpdates.isEmpty()) {
      Database.update(leadUpdates.values(), false);
    }
  }
}