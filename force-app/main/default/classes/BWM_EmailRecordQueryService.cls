public without sharing class BWM_EmailRecordQueryService {
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
        Owner.Phone,
        Owner.Email,
        CRM_User_Name_Formula__c
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
        Phone__c,
        Email__c,
        ContactId,
        OwnerId,
        DealerAccount__c,
        DealerAccount__r.Name,
        DealerAccount__r.Phone,
        DealerAccount__r.Email__c,
        Owner.Name,
        Owner.Email,
        CRM_User_Name_Formula__c,
        Account.Name,
        Account.Phone
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
  }

  public static Account queryAccount(Id accountId) {
    return [
      SELECT
        Id,
        Name,
        Email__c,
        Phone,
        Owner.Name,
        Owner.Email
      FROM Account
      WHERE Id = :accountId
      LIMIT 1
    ];
  }
}