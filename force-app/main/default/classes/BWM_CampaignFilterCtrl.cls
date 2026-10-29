/**
 * @description Campaign Management filter/search API (Lead, Opportunity, Account, Contact).
 */
public with sharing class BWM_CampaignFilterCtrl {
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadCustomerCategoryOptions() {
        return getPicklistOptions(Lead.Customer_Category__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadCountryOptions() {
        return getPicklistOptions(Lead.Country__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadStateOptions() {
        return getPicklistOptions(Lead.State__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityCustomerCategoryOptions() {
        return getPicklistOptions(Opportunity.Customer_Category__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityCountryOptions() {
        return getPicklistOptions(Opportunity.Country__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityStateOptions() {
        return getPicklistOptions(Opportunity.State__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountCountryOptions() {
        return getPicklistOptions(Account.Country__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountStateOptions() {
        return getPicklistOptions(Account.State__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getContactCountryOptions() {
        return getPicklistOptions(Contact.Country__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getContactStateOptions() {
        return getPicklistOptions(Contact.State__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadDepartmentOptions() {
        return getPicklistOptions(Lead.Department_Name__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityDepartmentOptions() {
        return getPicklistOptions(Opportunity.Department_Name__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountDepartmentOptions() {
        return getPicklistOptions(Account.Department_Name__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOfflineCampaignDepartmentOptions() {
        return getPicklistOptions(Offline_Campaign__c.Department__c);
    }

    @AuraEnabled
    public static List<Lead> searchLeads(
        String searchTerm,
        List<String> stages,
        List<String> departments,
        String campaignFilter,
        List<String> lostReasons,
        Date fromDate,
        Date toDate,
        List<String> customerCategories,
        String countryFilter,
        List<String> states
    ) {
        String namePattern = String.isNotBlank(searchTerm)
            ? '%' + searchTerm.trim() + '%'
            : null;
        String campaignPattern = String.isNotBlank(campaignFilter)
            ? '%' + campaignFilter.trim() + '%'
            : null;
        Datetime toDateTime = toDate == null
            ? null
            : Datetime.newInstance(
                  toDate.year(),
                  toDate.month(),
                  toDate.day(),
                  23,
                  59,
                  59
              );

        String soql =
            'SELECT Id, Name, Status, Email, Phone, Department_Name__c, Lost_Reason__c, Campaign_Name__c, CreatedDate' +
            ' FROM Lead WHERE Id != null';

        if (namePattern != null) {
            soql += ' AND Name LIKE :namePattern';
        }
        if (stages != null && !stages.isEmpty()) {
            soql += ' AND Status IN :stages';
        }
        if (departments != null && !departments.isEmpty()) {
            soql += ' AND Department_Name__c IN :departments';
        }
        if (campaignPattern != null) {
            soql += ' AND Campaign_Name__c LIKE :campaignPattern';
        }
        if (lostReasons != null && !lostReasons.isEmpty()) {
            soql += ' AND Lost_Reason__c IN :lostReasons';
        }
        if (fromDate != null) {
            soql += ' AND CreatedDate >= :fromDate';
        }
        if (toDateTime != null) {
            soql += ' AND CreatedDate <= :toDateTime';
        }
        if (customerCategories != null && !customerCategories.isEmpty()) {
            soql += ' AND Customer_Category__c IN :customerCategories';
        }
        if (String.isNotBlank(countryFilter)) {
            soql += ' AND Country__c = :countryFilter';
        }
        if (states != null && !states.isEmpty()) {
            soql += ' AND State__c IN :states';
        }

        soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
        return Database.query(soql);
    }

    @AuraEnabled
    public static List<DealerOpportunityManagementController.OpportunityListItem> searchDealerOpportunities(
        String searchTerm,
        String dealerAccountFilter,
        List<String> stages,
        List<String> departments,
        List<String> lostReasons,
        Date fromDate,
        Date toDate,
        List<String> customerCategories,
        String countryFilter,
        List<String> states
    ) {
        String namePattern = String.isNotBlank(searchTerm)
            ? '%' + searchTerm.trim() + '%'
            : null;
        String dealerPattern = String.isNotBlank(dealerAccountFilter)
            ? '%' + dealerAccountFilter.trim() + '%'
            : null;
        Datetime toDateTime = toDate == null
            ? null
            : Datetime.newInstance(
                  toDate.year(),
                  toDate.month(),
                  toDate.day(),
                  23,
                  59,
                  59
              );

        String soql =
            'SELECT Id, Name, StageName, Amount, CloseDate, CreatedDate,' +
            ' Department_Name__c, Lost_Reason__c, DealerAccount__r.Name' +
            ' FROM Opportunity WHERE Id != null';

        if (namePattern != null) {
            soql += ' AND Name LIKE :namePattern';
        }
        if (dealerPattern != null) {
            soql += ' AND DealerAccount__r.Name LIKE :dealerPattern';
        }
        if (stages != null && !stages.isEmpty()) {
            soql += ' AND StageName IN :stages';
        }
        if (departments != null && !departments.isEmpty()) {
            soql += ' AND Department_Name__c IN :departments';
        }
        if (lostReasons != null && !lostReasons.isEmpty()) {
            soql += ' AND Lost_Reason__c IN :lostReasons';
        }
        if (fromDate != null) {
            soql += ' AND CreatedDate >= :fromDate';
        }
        if (toDateTime != null) {
            soql += ' AND CreatedDate <= :toDateTime';
        }
        if (customerCategories != null && !customerCategories.isEmpty()) {
            soql += ' AND Customer_Category__c IN :customerCategories';
        }
        if (String.isNotBlank(countryFilter)) {
            soql += ' AND Country__c = :countryFilter';
        }
        if (states != null && !states.isEmpty()) {
            soql += ' AND State__c IN :states';
        }

        soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
        return buildOpportunityListItems(Database.query(soql));
    }

    @AuraEnabled
    public static List<Account> searchAccounts(
        String searchTerm,
        String phoneFilter,
        String emailFilter,
        List<String> departments,
        String countryFilter,
        List<String> states
    ) {
        String namePattern = String.isNotBlank(searchTerm)
            ? '%' + searchTerm.trim() + '%'
            : null;
        String phonePattern = String.isNotBlank(phoneFilter)
            ? '%' + phoneFilter.trim() + '%'
            : null;
        String emailPattern = String.isNotBlank(emailFilter)
            ? '%' + emailFilter.trim() + '%'
            : null;

        String soql =
            'SELECT Id, Name, Phone, Email__c, Department_Name__c, CreatedDate FROM Account WHERE Id != null';
        if (namePattern != null) {
            soql += ' AND Name LIKE :namePattern';
        }
        if (phonePattern != null) {
            soql += ' AND Phone LIKE :phonePattern';
        }
        if (emailPattern != null) {
            soql += ' AND Email__c LIKE :emailPattern';
        }
        if (departments != null && !departments.isEmpty()) {
            soql += ' AND Department_Name__c IN :departments';
        }
        if (String.isNotBlank(countryFilter)) {
            soql += ' AND Country__c = :countryFilter';
        }
        if (states != null && !states.isEmpty()) {
            soql += ' AND State__c IN :states';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
        return Database.query(soql);
    }

    @AuraEnabled
    public static List<Contact> searchContacts(
        String searchTerm,
        String phoneFilter,
        String emailFilter,
        String countryFilter,
        List<String> states
    ) {
        String namePattern = String.isNotBlank(searchTerm)
            ? '%' + searchTerm.trim() + '%'
            : null;
        String phonePattern = String.isNotBlank(phoneFilter)
            ? '%' + phoneFilter.trim() + '%'
            : null;
        String emailPattern = String.isNotBlank(emailFilter)
            ? '%' + emailFilter.trim() + '%'
            : null;

        String soql =
            'SELECT Id, Name, Email, Phone, MobilePhone, Account.Name, CreatedDate FROM Contact WHERE Id != null';
        if (namePattern != null) {
            soql += ' AND Name LIKE :namePattern';
        }
        if (phonePattern != null) {
            soql += ' AND (Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)';
        }
        if (emailPattern != null) {
            soql += ' AND Email LIKE :emailPattern';
        }
        if (String.isNotBlank(countryFilter)) {
            soql += ' AND Country__c = :countryFilter';
        }
        if (states != null && !states.isEmpty()) {
            soql += ' AND State__c IN :states';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
        return Database.query(soql);
    }

    @AuraEnabled
    public static List<Offline_Campaign__c> searchOfflineCampaigns(
        String searchTerm,
        String phoneFilter,
        String emailFilter,
        List<String> departments,
        String groupListFilter
    ) {
        String namePattern = String.isNotBlank(searchTerm)
            ? '%' + searchTerm.trim() + '%'
            : null;
        String phonePattern = String.isNotBlank(phoneFilter)
            ? '%' + phoneFilter.trim() + '%'
            : null;
        String emailPattern = String.isNotBlank(emailFilter)
            ? '%' + emailFilter.trim() + '%'
            : null;
        String groupListValue = String.isNotBlank(groupListFilter)
            ? groupListFilter.trim()
            : null;

        String soql =
            'SELECT Id, Name, Phone__c, Email__c, Department__c, Group_List__c, Active__c, CreatedDate' +
            ' FROM Offline_Campaign__c WHERE Active__c = true';
        if (namePattern != null) {
            soql += ' AND Name LIKE :namePattern';
        }
        if (phonePattern != null) {
            soql += ' AND Phone__c LIKE :phonePattern';
        }
        if (emailPattern != null) {
            soql += ' AND Email__c LIKE :emailPattern';
        }
        if (departments != null && !departments.isEmpty()) {
            soql += ' AND Department__c IN :departments';
        }
        if (groupListValue != null) {
            soql += ' AND Group_List__c = :groupListValue';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
        return Database.query(soql);
    }

    private static List<DealerOpportunityManagementController.OpportunityListItem> buildOpportunityListItems(
        List<Opportunity> opportunities
    ) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opportunityRecord : opportunities) {
            opportunityIds.add(opportunityRecord.Id);
        }

        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            queryPrimaryContactsByOpportunityId(opportunityIds);

        List<DealerOpportunityManagementController.OpportunityListItem> rows =
            new List<DealerOpportunityManagementController.OpportunityListItem>();
        for (Opportunity opportunityRecord : opportunities) {
            DealerOpportunityManagementController.OpportunityListItem row =
                new DealerOpportunityManagementController.OpportunityListItem();
            row.Id = opportunityRecord.Id;
            row.Name = opportunityRecord.Name;
            row.StageName = opportunityRecord.StageName;
            row.Amount = opportunityRecord.Amount;
            row.CloseDate = opportunityRecord.CloseDate;
            row.CreatedDate = opportunityRecord.CreatedDate;
            row.DepartmentName = opportunityRecord.Department_Name__c;
            row.LostReason = opportunityRecord.Lost_Reason__c;
            row.DealerAccountName = opportunityRecord.DealerAccount__r == null
                ? null
                : opportunityRecord.DealerAccount__r.Name;

            OpportunityContactRole primaryContactRole =
                primaryContactByOpportunityId.get(opportunityRecord.Id);
            if (primaryContactRole != null && primaryContactRole.Contact != null) {
                row.PrimaryContactName = primaryContactRole.Contact.Name;
                row.PrimaryContactEmail = primaryContactRole.Contact.Email;
                row.PrimaryContactPhone = String.isNotBlank(
                        primaryContactRole.Contact.Phone
                    )
                    ? primaryContactRole.Contact.Phone
                    : primaryContactRole.Contact.MobilePhone;
            }

            rows.add(row);
        }

        return rows;
    }

    private static Map<Id, OpportunityContactRole> queryPrimaryContactsByOpportunityId(
        Set<Id> opportunityIds
    ) {
        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            new Map<Id, OpportunityContactRole>();

        if (opportunityIds.isEmpty()) {
            return primaryContactByOpportunityId;
        }

        for (OpportunityContactRole contactRole : [
            SELECT
                OpportunityId,
                Contact.Name,
                Contact.Email,
                Contact.Phone,
                Contact.MobilePhone
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds AND IsPrimary = TRUE
        ]) {
            primaryContactByOpportunityId.put(contactRole.OpportunityId, contactRole);
        }

        return primaryContactByOpportunityId;
    }

    private static List<PicklistOption> getPicklistOptions(Schema.SObjectField fieldToken) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public PicklistOption(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }
}