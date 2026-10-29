/**
 * @description   Nurture-stage budgetary opportunity no-activity escalation emails.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class OpportunityNurtureBudgetaryMatrixBatch implements Database.Batchable<SObject> {
  private static final String TEMPLATE_15D = 'Budgetary Opp No Update 15d Owner';
  private static final String TEMPLATE_21D = 'Budgetary Opp No Update 21d HOD';
  private static final String TEMPLATE_30D = 'Budgetary Opp No Update 30d HOD';

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
          LastModifiedDate,
          LastActivityDate,
          Budget_Confirmed__c,
          RecordType.DeveloperName,
          Department_Name__c,
          Department_NameFormula__c,
          CRM_User_Email_Formula__c,
          NurtureEscalation48Sent__c,
          NurtureEscalation60Sent__c,
          NurtureEscalation72Sent__c
        FROM Opportunity
        WHERE
          StageName = 'Nurture'
          AND IsClosed = FALSE
          AND Budget_Confirmed__c = TRUE
          AND RecordType.DeveloperName != 'Tender_Opportunity'
          AND (
            NurtureEscalation48Sent__c = FALSE
            OR NurtureEscalation60Sent__c = FALSE
            OR NurtureEscalation72Sent__c = FALSE
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
        : opportunityRecord.LastModifiedDate.date();
      Long daysSinceActivity = EscalationMatrixEmailService.daysSince(lastActivityDate);

      Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
      Boolean changed = false;

      if (
        !opportunityRecord.NurtureEscalation48Sent__c &&
        daysSinceActivity >= 15 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_15D,
          EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM
        )
      ) {
        updateRecord.NurtureEscalation48Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.NurtureEscalation60Sent__c &&
        daysSinceActivity >= 21 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_21D,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        )
      ) {
        updateRecord.NurtureEscalation60Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.NurtureEscalation72Sent__c &&
        daysSinceActivity >= 30 &&
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_30D,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        )
      ) {
        updateRecord.NurtureEscalation72Sent__c = true;
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
      if (candidate.NurtureEscalation48Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_15D)) {
        filtered.NurtureEscalation48Sent__c = true;
        changed = true;
      }
      if (candidate.NurtureEscalation60Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_21D)) {
        filtered.NurtureEscalation60Sent__c = true;
        changed = true;
      }
      if (candidate.NurtureEscalation72Sent__c == true &&
        EscalationMatrixEmailService.wasSendSuccessful(candidate.Id, TEMPLATE_30D)) {
        filtered.NurtureEscalation72Sent__c = true;
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