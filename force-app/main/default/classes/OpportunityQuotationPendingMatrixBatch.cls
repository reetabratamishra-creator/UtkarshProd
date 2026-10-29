/**
 * @description   Nurture-stage quotation pending escalation emails at 48h, 60h, and 72h.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class OpportunityQuotationPendingMatrixBatch implements Database.Batchable<SObject> {
  private static final String TEMPLATE_48H = 'Pending Quotation 48h Owner';
  private static final String TEMPLATE_60H = 'Quotation Pending 60h HOD';
  private static final String TEMPLATE_72H = 'Quotation Pending 72h Sir';

  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff48 = System.now().addHours(-48);

    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Name,
          OwnerId,
          Owner.Email,
          StageName,
          CreatedDate,
          Nurture_Stage_Entry_Date__c,
          Department_Name__c,
          Department_NameFormula__c,
          CRM_User_Email_Formula__c,
          Nurture_Escalation_48_Sent__c,
          Nurture_Escalation_60_Sent__c,
          Nurture_Escalation_72_Sent__c
        FROM Opportunity
        WHERE
          StageName = 'Nurture'
          AND IsClosed = FALSE
          AND (
            Nurture_Escalation_48_Sent__c = FALSE
            OR Nurture_Escalation_60_Sent__c = FALSE
            OR Nurture_Escalation_72_Sent__c = FALSE
          )
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<Opportunity> scope) {
    Set<Id> opportunityIds = new Map<Id, Opportunity>(scope).keySet();
    Set<Id> opportunitiesWithQuotes = new Set<Id>();

    for (Quote quoteRecord : [
      SELECT OpportunityId
      FROM Quote
      WHERE OpportunityId IN :opportunityIds
    ]) {
      opportunitiesWithQuotes.add(quoteRecord.OpportunityId);
    }

    for (Opportunity opportunityRecord : scope) {
      if (opportunitiesWithQuotes.contains(opportunityRecord.Id)) {
        continue;
      }

      Datetime anchorDate = opportunityRecord.Nurture_Stage_Entry_Date__c != null
        ? opportunityRecord.Nurture_Stage_Entry_Date__c
        : opportunityRecord.CreatedDate;
      Long hoursDiff = EscalationMatrixEmailService.hoursSince(anchorDate);

      if (hoursDiff < 48) {
        continue;
      }

      if (
        !opportunityRecord.Nurture_Escalation_48_Sent__c &&
        hoursDiff >= 48
      ) {
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_48H,
          EscalationMatrixEmailService.RecipientGroup.OWNER_AND_CRM
        );
      }

      if (
        !opportunityRecord.Nurture_Escalation_60_Sent__c &&
        hoursDiff >= 60
      ) {
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_60H,
          EscalationMatrixEmailService.RecipientGroup.HOD_AND_CRM_HEAD
        );
      }

      if (
        !opportunityRecord.Nurture_Escalation_72_Sent__c &&
        hoursDiff >= 72
      ) {
        EscalationMatrixEmailService.sendOpportunityEmail(
          opportunityRecord,
          TEMPLATE_72H,
          EscalationMatrixEmailService.RecipientGroup.ED_SIR
        );
      }
    }

    EscalationMatrixEmailService.flushQueuedEmails();

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (Opportunity opportunityRecord : scope) {
      if (opportunitiesWithQuotes.contains(opportunityRecord.Id)) {
        continue;
      }

      Datetime anchorDate = opportunityRecord.Nurture_Stage_Entry_Date__c != null
        ? opportunityRecord.Nurture_Stage_Entry_Date__c
        : opportunityRecord.CreatedDate;
      Long hoursDiff = EscalationMatrixEmailService.hoursSince(anchorDate);

      if (hoursDiff < 48) {
        continue;
      }

      Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
      Boolean changed = false;

      if (
        !opportunityRecord.Nurture_Escalation_48_Sent__c &&
        hoursDiff >= 48 &&
        EscalationMatrixEmailService.wasSendSuccessful(opportunityRecord.Id, TEMPLATE_48H)
      ) {
        updateRecord.Nurture_Escalation_48_Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.Nurture_Escalation_60_Sent__c &&
        hoursDiff >= 60 &&
        EscalationMatrixEmailService.wasSendSuccessful(opportunityRecord.Id, TEMPLATE_60H)
      ) {
        updateRecord.Nurture_Escalation_60_Sent__c = true;
        changed = true;
      }

      if (
        !opportunityRecord.Nurture_Escalation_72_Sent__c &&
        hoursDiff >= 72 &&
        EscalationMatrixEmailService.wasSendSuccessful(opportunityRecord.Id, TEMPLATE_72H)
      ) {
        updateRecord.Nurture_Escalation_72_Sent__c = true;
        changed = true;
      }

      if (changed) {
        opportunitiesToUpdate.add(updateRecord);
      }
    }

    EscalationMatrixEmailService.updateOpportunitiesAllowPartial(opportunitiesToUpdate);
  }

  public void finish(Database.BatchableContext context) {
  }
}