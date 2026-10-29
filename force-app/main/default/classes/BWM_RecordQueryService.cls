/**
 * @description   Queries Lead, Opportunity, and related records needed for messaging
 *                payload building.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_RecordQueryService {
  public static Lead queryLead(Id leadId) {
    return [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        Company,
        Company_Name__c,
        Email,
        Phone,
        LeadSource,
        Status,
        Department_Name__c,
        Product_Category__c,
        Lost_Reason__c,
        City,
        State,
        Owner.Name,
        Owner.FirstName,
        Owner.LastName,
        Owner.Email,
        Owner.Phone,
        CRM_User_Name_Formula__c,
        CRM_User_Contact_No_Formula__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadId
      LIMIT 1
    ];
  }

  public static Opportunity queryOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        StageName,
        LeadSource,
        Amount,
        CloseDate,
        IsClosed,
        LastModifiedDate,
        Department_Name__c,
        Product_Category__c,
        Lost_Reason__c,
        Sub_Stage__c,
        Customer_Journey__c,
        Quotation_Date__c,
        Contact_Person_Name__c,
        Quote_Number__c,
        SyncedQuoteId,
        SyncedQuote.QuoteNumber,
        SyncedQuote.CreatedDate,
        Final_Quote_Document_ID__c,
        City__c,
        State__c,
        Lead__c,
        Lead__r.Phone,
        Lead__r.FirstName,
        Lead__r.LastName,
        Phone__c,
        Email__c,
        ContactId,
        DealerAccount__c,
        DealerAccount__r.Phone,
        DealerAccount__r.Name,
        Owner.Name,
        Owner.FirstName,
        Owner.LastName,
        Owner.Email,
        Owner.Phone,
        Owner.MobilePhone,
        CRM_User_Name_Formula__c,
        CRM_User_Contact_No_Formula__c,
        CRM_User_Email_Formula__c,
        Account.Name,
        Account.Phone
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
  }
}