/**
 * @description   Scheduled batch that sends Prospect-stage 24-hour not-contacted escalation
 *                emails to the Lead Owner and Department CRM Head.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class LeadProspectNotContacted24Batch implements Database.Batchable<SObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff = System.now().addHours(-24);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Owner.Email,
          Status,
          Department_Name__c,
          Department_NameFormula__c,
          Prospect_Stage_Entry_Date__c,
          Escalation_24_Sent__c,
          LastActivityDate,
          CRM_User_Email_Formula__c
        FROM Lead
        WHERE
          Status = 'Prospect'
          AND IsConverted = FALSE
          AND Escalation_24_Sent__c = FALSE
          AND Prospect_Stage_Entry_Date__c != NULL
          AND Prospect_Stage_Entry_Date__c <= :cutoff
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Lead> scope) {
    List<Lead> leadsToUpdate = new List<Lead>();

    for (Lead leadRecord : scope) {
      if (
        !LeadProspectNotContacted24EmailService.isPast24Hours(leadRecord) ||
        !LeadProspectNotContacted24EmailService.hasNoActivitySinceProspectEntry(
          leadRecord
        )
      ) {
        continue;
      }

      if (LeadProspectNotContacted24EmailService.sendEscalationEmail(leadRecord)) {
        leadsToUpdate.add(
          new Lead(Id = leadRecord.Id, Escalation_24_Sent__c = true)
        );
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      Database.update(leadsToUpdate, false);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new LeadProspectNotContacted24Batch(), 10);
  }
}