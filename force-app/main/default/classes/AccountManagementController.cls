/**
 * @description   AuraEnabled API for Account campaign search and
 *                Journey/WhatsApp/RCS/SMS/Email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class AccountManagementController {
    /**
     * @description Returns active Account Country picklist options.
     * @return List of PicklistOption values for Account.Country__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountCountryOptions() {
        return getPicklistOptions(Account.Country__c);
    }

    /**
     * @description Returns active Account State picklist options.
     * @return List of PicklistOption values for Account.State__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAccountStateOptions() {
        return getPicklistOptions(Account.State__c);
    }

    /**
     * @description Searches Accounts by optional name, phone, email, and department filters.
     * @param searchTerm Optional Account Name LIKE filter.
     * @param phoneFilter Optional Phone LIKE filter.
     * @param emailFilter Optional Email__c LIKE filter.
     * @param departmentFilter Optional Department_Name__c LIKE filter.
     * @param countryFilter Optional exact Country__c value filter.
     * @param states Optional list of State__c values to include.
     * @return Matching Account records ordered by CreatedDate descending (max 5000).
     */
    @AuraEnabled
    public static List<Account> searchAccounts(
        String searchTerm,
        String phoneFilter,
        String emailFilter,
        String departmentFilter,
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
        String departmentPattern = String.isNotBlank(departmentFilter)
            ? '%' + departmentFilter.trim() + '%'
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
        if (departmentPattern != null) {
            soql += ' AND Department_Name__c LIKE :departmentPattern';
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

    /**
     * @description Sends Infobip campaign email to the selected Accounts.
     * @param accountIds Account Ids to send email to.
     * @param infobipTemplateId Infobip email template identifier.
     * @return SendCampaignEmailResult from BWM_CampaignEmailService.
     */
    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendAccountCampaignEmail(
        List<Id> accountIds,
        String infobipTemplateId
    ) {
        try {
            return BWM_CampaignEmailService.sendToAccounts(accountIds, infobipTemplateId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendAccountCampaignEmailScheduled(
        List<Id> accountIds,
        String infobipTemplateId,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendAccountCampaignEmail(accountIds, infobipTemplateId);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads Bluewave/Infobip email template options for the Account campaign UI.
     * @return List of TemplateOption values from BWM_InfobipEmailTemplateService.
     */
    @AuraEnabled
    public static List<BWM_InfobipEmailTemplateService.TemplateOption> getBluewaveEmailTemplates() {
        try {
            return BWM_InfobipEmailTemplateService.fetchTemplates();
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Returns active campaign journey options for Account sends.
     * @return List of JourneyOption values from BWM_JourneyDefinitionService.
     */
    @AuraEnabled
    public static List<BWM_JourneyDefinitionService.JourneyOption> getCampaignJourneys() {
        return BWM_JourneyDefinitionService.fetchActiveJourneys();
    }

    /**
     * @description Starts the selected campaign journey for the given Accounts.
     * @param accountIds Account Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendAccountJourney(
        List<Id> accountIds,
        String journeyName
    ) {
        return BWM_CampaignJourneyService.sendToAccounts(accountIds, journeyName);
    }

    /**
     * @description Starts the selected campaign journey at the given UTC schedule time.
     * @param accountIds Account Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @param scheduledDateTime UTC timestamp yyyy-MM-ddTHH:mm:ssZ written to scheduledatetime.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendAccountJourneyScheduled(
        List<Id> accountIds,
        String journeyName,
        String scheduledDateTime
    ) {
        return BWM_CampaignJourneyService.sendToAccounts(
            accountIds,
            journeyName,
            scheduledDateTime
        );
    }

    /**
     * @description Loads approved WhatsApp template options for Account campaign sends.
     * @return List of WhatsAppTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementWhatsAppService.WhatsAppTemplateOption> getWhatsAppTemplates() {
        return LeadManagementWhatsAppService.fetchApprovedTemplates();
    }

    /**
     * @description Sends a WhatsApp template message to the selected Accounts.
     * @param accountIds Account Ids to message.
     * @param templateName Approved WhatsApp template name.
     * @return SendWhatsAppResult with send outcome details.
     */
    @AuraEnabled
    public static LeadManagementWhatsAppService.SendWhatsAppResult sendAccountWhatsApp(
        List<Id> accountIds,
        String templateName
    ) {
        return AccountManagementWhatsAppService.sendToAccounts(accountIds, templateName);
    }

    /**
     * @description Loads approved RCS template options for Account campaign sends.
     * @return List of RcsTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementRcsService.RcsTemplateOption> getRcsTemplates() {
        return LeadManagementRcsService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an RCS template message to the selected Accounts.
     * @param accountIds Account Ids to message.
     * @param templateName Approved RCS template name.
     * @return SendRcsResult with send outcome details.
     */
    @AuraEnabled
    public static AccountManagementRcsService.SendRcsResult sendAccountRcs(
        List<Id> accountIds,
        String templateName
    ) {
        return AccountManagementRcsService.sendToAccounts(accountIds, templateName);
    }

    @AuraEnabled
    public static AccountManagementRcsService.SendRcsResult sendAccountRcsScheduled(
        List<Id> accountIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendAccountRcs(accountIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads approved SMS template options for Account campaign sends.
     * @return List of SmsTemplateOption values.
     */
    @AuraEnabled
    public static List<BWM_SmsTemplateService.SmsTemplateOption> getSmsTemplates() {
        return BWM_SmsTemplateService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an SMS template message to the selected Accounts.
     * @param accountIds Account Ids to message.
     * @param templateName Approved SMS template name.
     * @return SendSmsResult with send outcome details.
     */
    @AuraEnabled
    public static AccountManagementSmsService.SendSmsResult sendAccountSms(
        List<Id> accountIds,
        String templateName
    ) {
        return AccountManagementSmsService.sendToAccounts(accountIds, templateName);
    }

    @AuraEnabled
    public static AccountManagementSmsService.SendSmsResult sendAccountSmsScheduled(
        List<Id> accountIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendAccountSms(accountIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
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