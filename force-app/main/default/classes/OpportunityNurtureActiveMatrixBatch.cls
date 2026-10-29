/**
 * @description   Nurture-stage active opportunity no-activity escalation emails.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class OpportunityNurtureActiveMatrixBatch implements Database.Batchable<SObject> {
  private static final String TEMPLATE_72H = 'Active Opp No Update 72h Owner';
  private static final String TEMPLATE_96H = 'Active Opp No Update 96h HOD';
  private static final String TEMPLATE_120H = 'Active Opp No Update 120h HOD';

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Owner.Email,
          StageName,
          CreatedDate,
          LastActivityDate,
          Budget_Confirmed__c,
          RecordType.DeveloperName,
          Department_Name__c,
          Department_NameFormula__c,
          CRM_User_Email_Formula__c,
          Active_Task_Escalation_72_Sent__c,
          Active_Task_Escalation_96_Sent__c,
          Active_Task_Escalation_120_Sent__c
        FROM Opportunity
        WHERE
          StageName = 'Nurture'
          AND IsClosed = FALSE
          AND RecordType.DeveloperName != 'Tender_Opportunity'
          AND Budget_Confirmed__c = FALSE
          AND (
            Active_Task_Escalation_72_Sent__c = FALSE
            OR Active_Task_Escalation_96_Sent__c = FALSE
            OR Active_Task_Escalation_120_Sent__c = FALSE
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    Map<Id, Date> lastActivityByOpportunityId = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Map<Id, Opportunity>(scope).keySet()
    );
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    for (Opportunity opportunityRecord : scope) {
      Date lastActivityDate = lastActivityByOpportunityId.containsKey(opportunityRecord.Id)
        ? lastActivityByOpportunityId.get(opportunityRecord.Id)
        : opportunityRecord.CreatedDate.date();
      Long hoursSinceActivity = EscalationMatrixOpportunityHelper.hoursSinceDate(
        lastActivityDate
      );

      Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
      Boolean changed = false;

      if (
        !opportunityRecord.Active_Task_Escalation_72_Sent__c &&
        hoursSinceActivity >= 72 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_72H,
          EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM
        )
      ) {
        updateRecord.Active_Task_Escalation_72_Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.Active_Task_Escalation_96_Sent__c &&
        hoursSinceActivity >= 96 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_96H,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        )
      ) {
        updateRecord.Active_Task_Escalation_96_Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.Active_Task_Escalation_120_Sent__c &&
        hoursSinceActivity >= 120 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_120H,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        )
      ) {
        updateRecord.Active_Task_Escalation_120_Sent__c = true;
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
      if (candidate.Active_Task_Escalation_72_Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_72H)) {
        filtered.Active_Task_Escalation_72_Sent__c = true;
        changed = true;
      }
      if (candidate.Active_Task_Escalation_96_Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_96H)) {
        filtered.Active_Task_Escalation_96_Sent__c = true;
        changed = true;
      }
      if (candidate.Active_Task_Escalation_120_Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_120H)) {
        filtered.Active_Task_Escalation_120_Sent__c = true;
        changed = true;
      }
      if (changed) {
        confirmed.add(filtered);
      }
    }
    return confirmed;
  }


  public void finish(Database.BatchableContext context) {
  }
}