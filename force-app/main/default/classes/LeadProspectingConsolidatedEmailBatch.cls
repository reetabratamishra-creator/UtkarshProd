/**
 * @description   Sends the consolidated Prospecting no-activity emails (24h / 48h / 96h)
 *                in small chunks so each chunk gets its own governor limits.
 *                Started from LeadProspectingNoActivityBatch.finish().
 *                One WorkItem = ONE consolidated email (one recipient group, one tier).
 * @author        Rani Mate
 * @date          2026-10-13
 */
public without sharing class LeadProspectingConsolidatedEmailBatch implements Database.Batchable<LeadProspectingConsolidatedEmailBatch.WorkItem> {
  /**
   * One consolidated email to send.
   */
  public class WorkItem {
    public String groupKey; // recipient group key (also used to track send success)
    public String templateName; // existing Lightning template name
    public EscalationMatrixEmailService.RecipientGroup recipientType; // existing recipient group
    public Integer tierHours; // 24, 48 or 96 (decides which checkbox to set)
    public List<Lead> leads; // all leads to list in this email
  }

  private List<WorkItem> items;
  private Map<Id, Long> hoursByLeadId;

  public LeadProspectingConsolidatedEmailBatch(
    List<WorkItem> items,
    Map<Id, Long> hoursByLeadId
  ) {
    this.items = items;
    this.hoursByLeadId = hoursByLeadId;
  }

  public Iterable<WorkItem> start(Database.BatchableContext context) {
    return items;
  }

  public void execute(Database.BatchableContext context, List<WorkItem> scope) {
    processItems(scope, hoursByLeadId);
  }

  public void finish(Database.BatchableContext context) {
  }

  /**
   * Queues + sends the emails of this chunk, then sets the "sent" checkbox only on
   * leads whose consolidated email succeeded.
   * Public/static so LeadProspectingNoActivityBatch.finish() can call it directly in
   * tests (a test cannot chain a second executeBatch from finish()).
   */
  public static void processItems(List<WorkItem> scope, Map<Id, Long> hoursByLeadId) {
    // 1) Queue one email per work item.
    for (WorkItem item : scope) {
      try {
        EscalationMatrixEmailService.sendConsolidatedLeadEmail(
          item.leads,
          item.templateName,
          item.recipientType,
          item.groupKey,
          hoursByLeadId
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Consolidated lead email failed for group ' + item.groupKey + ': ' + ex.getMessage()
        );
      }
    }

    // 2) Send the queued emails.
    EscalationMatrixEmailService.flushQueuedEmails();

    // 3) Set checkboxes only for successful emails. A lead can be in several items
    //    (24h + 48h ...), so merge flags into one record per Lead (no duplicate Ids).
    Map<Id, Lead> updatesByLeadId = new Map<Id, Lead>();
    for (WorkItem item : scope) {
      if (
        !EscalationMatrixEmailService.wasConsolidatedSendSuccessful(
          item.groupKey,
          item.templateName
        )
      ) {
        continue;
      }

      for (Lead leadRecord : item.leads) {
        Lead updateRecord = updatesByLeadId.containsKey(leadRecord.Id)
          ? updatesByLeadId.get(leadRecord.Id)
          : new Lead(Id = leadRecord.Id);

        if (item.tierHours == 24) {
          updateRecord.Prospecting_Escalation_24_Sent__c = true;
        } else if (item.tierHours == 48) {
          updateRecord.Prospecting_Escalation_48_Sent__c = true;
        } else if (item.tierHours == 96) {
          updateRecord.Prospecting_Escalation_72_Sent__c = true; // existing field reuse
        }
        updatesByLeadId.put(leadRecord.Id, updateRecord);
      }
    }

    if (!updatesByLeadId.isEmpty()) {
      Database.update(updatesByLeadId.values(), false);
    }
  }
}