/**
 * @description Runs ProjectOpportunityCreatedDigestBatch once a day.
 *
 * Schedule it once from Execute Anonymous (example: every day at 9:00 AM, org time zone):
 *   System.schedule(
 *     'Project Opportunity Created Digest',
 *     '0 0 9 * * ?',
 *     new ProjectOpportunityCreatedDigestScheduler()
 *   );
 */
public without sharing class ProjectOpportunityCreatedDigestScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new ProjectOpportunityCreatedDigestBatch(), 5);
  }
}