/**
 * @description   AuraEnabled API for Contact campaign search and
 *                Journey/WhatsApp/RCS/SMS/Email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class ContactManagementController {
    /**
     * @description Returns active Contact Country picklist options.
     * @return List of PicklistOption values for Contact.Country__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getContactCountryOptions() {
        return getPicklistOptions(Contact.Country__c);
    }

    /**
     * @description Returns active Contact State picklist options.
     * @return List of PicklistOption values for Contact.State__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getContactStateOptions() {
        return getPicklistOptions(Contact.State__c);
    }

    /**
     * @description Searches Contacts by optional name, phone/mobile, and email filters.
     * @param searchTerm Optional Contact Name LIKE filter.
     * @param phoneFilter Optional Phone or MobilePhone LIKE filter.
     * @param emailFilter Optional Email LIKE filter.
     * @param countryFilter Optional exact Country__c value filter.
     * @param states Optional list of State__c values to include.
     * @return Matching Contact records ordered by CreatedDate descending (max 5000).
     */
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

    /**
     * @description Sends Infobip campaign email to the selected Contacts.
     * @param contactIds Contact Ids to send email to.
     * @param infobipTemplateId Infobip email template identifier.
     * @return SendCampaignEmailResult from BWM_CampaignEmailService.
     */
    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendContactCampaignEmail(
        List<Id> contactIds,
        String infobipTemplateId
    ) {
        try {
            return BWM_CampaignEmailService.sendToContacts(contactIds, infobipTemplateId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendContactCampaignEmailScheduled(
        List<Id> contactIds,
        String infobipTemplateId,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendContactCampaignEmail(contactIds, infobipTemplateId);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads Bluewave/Infobip email template options for the Contact campaign UI.
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
     * @description Returns active campaign journey options for Contact sends.
     * @return List of JourneyOption values from BWM_JourneyDefinitionService.
     */
    @AuraEnabled
    public static List<BWM_JourneyDefinitionService.JourneyOption> getCampaignJourneys() {
        return BWM_JourneyDefinitionService.fetchActiveJourneys();
    }

    /**
     * @description Starts the selected campaign journey for the given Contacts.
     * @param contactIds Contact Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendContactJourney(
        List<Id> contactIds,
        String journeyName
    ) {
        return BWM_CampaignJourneyService.sendToContacts(contactIds, journeyName);
    }

    /**
     * @description Starts the selected campaign journey at the given UTC schedule time.
     * @param contactIds Contact Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @param scheduledDateTime UTC timestamp yyyy-MM-ddTHH:mm:ssZ written to scheduledatetime.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendContactJourneyScheduled(
        List<Id> contactIds,
        String journeyName,
        String scheduledDateTime
    ) {
        return BWM_CampaignJourneyService.sendToContacts(
            contactIds,
            journeyName,
            scheduledDateTime
        );
    }

    /**
     * @description Loads approved WhatsApp template options for Contact campaign sends.
     * @return List of WhatsAppTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementWhatsAppService.WhatsAppTemplateOption> getWhatsAppTemplates() {
        return LeadManagementWhatsAppService.fetchApprovedTemplates();
    }

    /**
     * @description Sends a WhatsApp template message to the selected Contacts.
     * @param contactIds Contact Ids to message.
     * @param templateName Approved WhatsApp template name.
     * @return SendWhatsAppResult with send outcome details.
     */
    @AuraEnabled
    public static LeadManagementWhatsAppService.SendWhatsAppResult sendContactWhatsApp(
        List<Id> contactIds,
        String templateName
    ) {
        return ContactManagementWhatsAppService.sendToContacts(contactIds, templateName);
    }

    /**
     * @description Loads approved RCS template options for Contact campaign sends.
     * @return List of RcsTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementRcsService.RcsTemplateOption> getRcsTemplates() {
        return LeadManagementRcsService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an RCS template message to the selected Contacts.
     * @param contactIds Contact Ids to message.
     * @param templateName Approved RCS template name.
     * @return SendRcsResult with send outcome details.
     */
    @AuraEnabled
    public static ContactManagementRcsService.SendRcsResult sendContactRcs(
        List<Id> contactIds,
        String templateName
    ) {
        return ContactManagementRcsService.sendToContacts(contactIds, templateName);
    }

    @AuraEnabled
    public static ContactManagementRcsService.SendRcsResult sendContactRcsScheduled(
        List<Id> contactIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendContactRcs(contactIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads approved SMS template options for Contact campaign sends.
     * @return List of SmsTemplateOption values.
     */
    @AuraEnabled
    public static List<BWM_SmsTemplateService.SmsTemplateOption> getSmsTemplates() {
        return BWM_SmsTemplateService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an SMS template message to the selected Contacts.
     * @param contactIds Contact Ids to message.
     * @param templateName Approved SMS template name.
     * @return SendSmsResult with send outcome details.
     */
    @AuraEnabled
    public static ContactManagementSmsService.SendSmsResult sendContactSms(
        List<Id> contactIds,
        String templateName
    ) {
        return ContactManagementSmsService.sendToContacts(contactIds, templateName);
    }

    @AuraEnabled
    public static ContactManagementSmsService.SendSmsResult sendContactSmsScheduled(
        List<Id> contactIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendContactSms(contactIds, templateName);
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