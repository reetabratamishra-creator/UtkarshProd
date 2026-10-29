/**
 * @description   Prospect-stage 48h and 96h not-contacted escalation emails.
 *                The 24h automation remains in LeadProspectNotContacted24Batch because
 *                it uses a different sent flag, template, and recipient set.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class LeadProspectNotContacted48_96Batch implements Database.Batchable<SObject> {
  private static final String TEMPLATE_48H = 'Lead Not Contacted 48h HOD';
  private static final String TEMPLATE_96H = 'Lead Not Contacted 96h Sir';

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff48 = System.now().addHours(-48);

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
          Escalation_48_Sent__c,
          Escalation_72_Sent__c,
          LastActivityDate,
          CRM_User_Email_Formula__c
        FROM Lead
        WHERE
          Status = 'Prospect'
          AND IsConverted = FALSE
          AND Prospect_Stage_Entry_Date__c != NULL
          AND Prospect_Stage_Entry_Date__c <= :cutoff48
          AND (
            Escalation_48_Sent__c = FALSE
            OR Escalation_72_Sent__c = FALSE
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Lead> scope) {
    for (Lead leadRecord : scope) {
      if (
        !EscalationMatrixEmailService.hasNoActivitySince(
          leadRecord.Prospect_Stage_Entry_Date__c,
          leadRecord.LastActivityDate
        )
      ) {
        continue;
      }

      if (
        !leadRecord.Escalation_48_Sent__c &&
        EscalationMatrixEmailService.hoursSince(
          leadRecord.Prospect_Stage_Entry_Date__c
        ) >= 48
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_48H,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        );
      }

      if (
        !leadRecord.Escalation_72_Sent__c &&
        EscalationMatrixEmailService.hoursSince(
          leadRecord.Prospect_Stage_Entry_Date__c
        ) >= 96
      ) {
        EscalationMatrixEmailService.sendLeadEmail(
          leadRecord,
          TEMPLATE_96H,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }
    }

    EscalationMatrixEmailService.flushQueuedEmails();

    List<Lead> leadsToUpdate = new List<Lead>();
    for (Lead leadRecord : scope) {
      if (
        !EscalationMatrixEmailService.hasNoActivitySince(
          leadRecord.Prospect_Stage_Entry_Date__c,
          leadRecord.LastActivityDate
        )
      ) {
        continue;
      }

      Lead updateRecord = new Lead(Id = leadRecord.Id);
      Boolean changed = false;

      if (
        !leadRecord.Escalation_48_Sent__c &&
        EscalationMatrixEmailService.hoursSince(
          leadRecord.Prospect_Stage_Entry_Date__c
        ) >= 48 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_48H)
      ) {
        updateRecord.Escalation_48_Sent__c = true;
        changed = true;
      }

      if (
        !leadRecord.Escalation_72_Sent__c &&
        EscalationMatrixEmailService.hoursSince(
          leadRecord.Prospect_Stage_Entry_Date__c
        ) >= 96 &&
        EscalationMatrixEmailService.wasSendSuccessful(leadRecord.Id, TEMPLATE_96H)
      ) {
        updateRecord.Escalation_72_Sent__c = true;
        changed = true;
      }

      if (changed) {
        leadsToUpdate.add(updateRecord);
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      Database.update(leadsToUpdate, false);
    }
  }

  public void finish(Database.BatchableContext context) {
  }
}