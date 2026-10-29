/**
 * @description Batch that sends Case 1st-response SLA escalation emails by priority tier.
 * @author Anshita Chanda
 * @date 2026-08-16
 */
public without sharing class CaseSLAEscalationBatch
  implements Database.Batchable<SObject>, Schedulable {
  private static final Integer BATCH_SIZE = 1;

  public void execute(SchedulableContext context) {
    Database.executeBatch(new CaseSLAEscalationBatch(), BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          CaseNumber,
          Priority,
          OwnerId,
          Owner.Email,
          Department__c,
          Department_formula__c,
          CreatedDate,
          First_Response__c,
          IsClosed,
          HOD_User_Email_Formula__c,
          Response_Esc_Owner_Sent__c,
          Response_Esc_HOD_Sent__c,
          Response_Esc_Sir_Sent__c,
          SLA_Due_Date_Time_RO__c,
          Escalation_Date_1__c,
          Escalation_Date_2__c
        FROM Case
        WHERE
          IsClosed = FALSE
          AND RecordType.DeveloperName = 'Case'
          AND First_Response__c = FALSE
          AND Priority IN ('Critical', 'High', 'Medium', 'Low')
          AND (
            Response_Esc_Owner_Sent__c = FALSE
            OR Response_Esc_HOD_Sent__c = FALSE
            OR Response_Esc_Sir_Sent__c = FALSE
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Case> scope) {
    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      Case updateRecord = processCase(caseRecord);
      if (updateRecord != null) {
        casesToUpdate.add(updateRecord);
      }
    }

    if (!casesToUpdate.isEmpty()) {
      // Partial update: one Case with invalid ContactId must not fail the chunk.
      Database.update(casesToUpdate, false);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  @TestVisible
  private static Case processCase(Case caseRecord) {
    if (caseRecord == null || caseRecord.First_Response__c == true) {
      return null;
    }

    Case updateRecord = new Case(Id = caseRecord.Id);
    Boolean changed = false;

    if (
      caseRecord.Response_Esc_Owner_Sent__c != true &&
      CaseSLAEscalationEmailService.isTierDue(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.OWNER
      ) &&
      CaseSLAEscalationEmailService.sendEscalationEmail(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.OWNER
      )
    ) {
      updateRecord.Response_Esc_Owner_Sent__c = true;
      changed = true;
    }

    if (
      caseRecord.Response_Esc_HOD_Sent__c != true &&
      CaseSLAEscalationEmailService.isTierDue(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.HOD
      ) &&
      CaseSLAEscalationEmailService.sendEscalationEmail(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.HOD
      )
    ) {
      updateRecord.Response_Esc_HOD_Sent__c = true;
      changed = true;
    }

    if (
      caseRecord.Response_Esc_Sir_Sent__c != true &&
      CaseSLAEscalationEmailService.isTierDue(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.SIR
      ) &&
      CaseSLAEscalationEmailService.sendEscalationEmail(
        caseRecord,
        CaseSLAEscalationEmailService.EscalationTier.SIR
      )
    ) {
      updateRecord.Response_Esc_Sir_Sent__c = true;
      changed = true;
    }

    return changed ? updateRecord : null;
  }
}