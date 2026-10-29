/**
 * @description   Shared test data factory and mock setup for Escalation Matrix Apex tests.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
public class EscalationMatrixTestUtil {
  public static void prepareTestContext() {
    EscalationMatrixEmailService.clearTestState();
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();
    LeadProspectingNoActivityBatch.clearTestLastProspectingActivityOverrides();

    LeadManagementEmailService.RenderedEmail leadRendered = new LeadManagementEmailService.RenderedEmail();
    leadRendered.subject = 'Escalation Test Subject';
    leadRendered.plainTextBody = 'Escalation test body';
    EscalationMatrixEmailService.testLeadRenderedOverride = leadRendered;

    DealerOpportunityEmailService.RenderedEmail oppRendered = new DealerOpportunityEmailService.RenderedEmail();
    oppRendered.subject = 'Escalation Test Subject';
    oppRendered.plainTextBody = 'Escalation test body';
    EscalationMatrixEmailService.testOppRenderedOverride = oppRendered;

    EscalationMatrixEmailService.testRecipientOverrides = new Set<String>{
      UserInfo.getUserEmail().trim().toLowerCase()
    };
    EscalationMatrixEmailService.testSimulateSuccessfulSend = true;

    List<EmailTemplate> templates = [
      SELECT Id, Name
      FROM EmailTemplate
      LIMIT 1
    ];
    if (!templates.isEmpty()) {
      EscalationMatrixEmailService.setTestTemplateId(
        'Lead Not Contacted 48h HOD',
        templates[0].Id
      );
      EscalationMatrixEmailService.setTestTemplateId(
        'Pending Quotation 48h Owner',
        templates[0].Id
      );
      EscalationMatrixEmailService.setTestTemplateId('Task Overdue Owner', templates[0].Id);
    }
  }

  public static Lead createLead(String statusValue, String lastName) {
    Lead leadRecord = new Lead(
      LastName = lastName,
      Company = 'Escalation Matrix Co',
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = statusValue,
      Department_Name__c = 'Enquiry',
      Email = lastName.toLowerCase().replace(' ', '') + '@example.com',
      Phone = '9876543210'
    );
    insert leadRecord;
    return leadRecord;
  }

  public static Opportunity createOpportunity(
    String stageName,
    String opportunityName,
    Boolean budgetConfirmed,
    Id recordTypeId
  ) {
    Account accountRecord = new Account(Name = opportunityName + ' Account');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = opportunityName,
      AccountId = accountRecord.Id,
      StageName = stageName,
      CloseDate = Date.today().addDays(30),
      Budget_Confirmed__c = budgetConfirmed
    );
    if (recordTypeId != null) {
      opportunityRecord.RecordTypeId = recordTypeId;
    }
    insert opportunityRecord;
    return opportunityRecord;
  }

  public static void setOldOpportunityActivity(Id opportunityId, Integer daysAgo) {
    Test.setCreatedDate(opportunityId, System.now().addDays(-daysAgo));
    EscalationMatrixOpportunityHelper.setTestLastActivityDate(
      opportunityId,
      Date.today().addDays(-daysAgo)
    );
  }

  public static Id getTenderRecordTypeId() {
    Schema.RecordTypeInfo recordTypeInfo = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
      .get('Tender_Opportunity');
    return recordTypeInfo == null ? null : recordTypeInfo.getRecordTypeId();
  }

  public static Lead queryLead(Id leadId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Email,
        Status,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  public static Lead queryProspectLead(Id leadId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Status,
        Department_NameFormula__c,
        Prospect_Stage_Entry_Date__c,
        Escalation_48_Sent__c,
        Escalation_72_Sent__c,
        LastActivityDate,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  public static Lead queryProspectingLead(Id leadId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Status,
        Department_NameFormula__c,
        Last_Prospecting_Activity__c,
        Prospecting_Escalation_24_Sent__c,
        Prospecting_Escalation_48_Sent__c,
        Prospecting_Escalation_72_Sent__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
    ];
  }

  public static Opportunity queryOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
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
      WHERE Id = :opportunityId
    ];
  }

  public static Opportunity queryActiveNurtureOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        Active_Task_Escalation_72_Sent__c,
        Active_Task_Escalation_96_Sent__c,
        Active_Task_Escalation_120_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }

  public static Opportunity queryTenderOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        LastModifiedDate,
        RecordType.DeveloperName,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        TenderEsc15Sent__c,
        TenderEsc21Sent__c,
        TenderEsc30Sent__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }

  public static Opportunity queryBudgetaryOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        LastModifiedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        NurtureEscalation48Sent__c,
        NurtureEscalation60Sent__c,
        NurtureEscalation72Sent__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }

  public static Opportunity queryNegotiationActiveOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c,
        EscalationNeg7Sent__c,
        EscalationNeg14Sent__c,
        EscalationNeg21Sent__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }
}