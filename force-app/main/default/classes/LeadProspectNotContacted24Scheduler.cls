/**
 * @description   Unused entry point. The 24-hour Prospect criteria runs from
 *                LeadProspectNotContacted24Batch, which is schedulable itself.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class LeadProspectNotContacted24Scheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    // Database.executeBatch(new LeadProspectNotContacted24Batch(), 10);
  }
}