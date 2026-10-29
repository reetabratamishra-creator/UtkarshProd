/**
 * @description   AuraEnabled API for Lead campaign search and
 *                Journey/WhatsApp/RCS/SMS/Email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class LeadManagementController {
    private static final String LEAD_MANAGEMENT_ORG_WIDE_EMAIL =
        'noreply@utkarshindialimited.in';

    /**
     * @description Returns active Lead Status picklist options for the Lead Management UI.
     * @return List of PicklistOption values for Lead.Status.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadStatusOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        for (
            Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
        ) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * @description Returns active Lead Lost Reason picklist options.
     * @return List of PicklistOption values for Lead.Lost_Reason__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadLostReasonOptions() {
        return getPicklistOptions(Lead.Lost_Reason__c);
    }

    /**
     * @description Returns active Lead Customer Category picklist options.
     * @return List of PicklistOption values for Lead.Customer_Category__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadCustomerCategoryOptions() {
        return getPicklistOptions(Lead.Customer_Category__c);
    }

    /**
     * @description Returns active Lead Country picklist options.
     * @return List of PicklistOption values for Lead.Country__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadCountryOptions() {
        return getPicklistOptions(Lead.Country__c);
    }

    /**
     * @description Returns active Lead State picklist options.
     * @return List of PicklistOption values for Lead.State__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadStateOptions() {
        return getPicklistOptions(Lead.State__c);
    }

    /**
     * @description Searches Leads by name, stage, department, campaign, lost reason, and created date range.
     * @param searchTerm Optional Lead Name LIKE filter.
     * @param stages Optional list of Lead Status values to include.
     * @param departmentFilter Optional Department_Name__c LIKE filter.
     * @param campaignFilter Optional Campaign_Name__c LIKE filter.
     * @param lostReasons Optional list of Lost_Reason__c values to include.
     * @param fromDate Optional CreatedDate lower bound (inclusive).
     * @param toDate Optional CreatedDate upper bound (inclusive through end of day).
     * @param customerCategories Optional list of Customer_Category__c values to include.
     * @param countryFilter Optional exact Country__c value filter.
     * @param states Optional list of State__c values to include.
     * @return Matching Lead records ordered by CreatedDate descending (max 5000).
     */
    @AuraEnabled
    public static List<Lead> searchLeads(
        String searchTerm,
        List<String> stages,
        String departmentFilter,
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
        String departmentPattern = String.isNotBlank(departmentFilter)
            ? '%' + departmentFilter.trim() + '%'
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
        if (departmentPattern != null) {
            soql += ' AND Department_Name__c LIKE :departmentPattern';
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

    /**
     * @description Returns Leads ordered by CreatedDate descending for the management grid.
     * @return List of Lead records, including Qualified status.
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeads() {
        return [
            SELECT Id, Name, Status, Email, Phone, Department_Name__c, Lost_Reason__c, Campaign_Name__c, CreatedDate
            FROM Lead
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description Sends Infobip campaign email to the selected Leads.
     * @param leadIds Lead Ids to send email to.
     * @param infobipTemplateId Infobip email template identifier.
     * @return SendCampaignEmailResult from BWM_CampaignEmailService.
     */
    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendLeadCampaignEmail(
        List<Id> leadIds,
        String infobipTemplateId
    ) {
        try {
            return BWM_CampaignEmailService.sendToLeads(leadIds, infobipTemplateId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendLeadCampaignEmailScheduled(
        List<Id> leadIds,
        String infobipTemplateId,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendLeadCampaignEmail(leadIds, infobipTemplateId);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads Bluewave/Infobip email template options for the Lead campaign UI.
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
     * @description Returns active campaign journey options for Lead sends.
     * @return List of JourneyOption values from BWM_JourneyDefinitionService.
     */
    @AuraEnabled
    public static List<BWM_JourneyDefinitionService.JourneyOption> getCampaignJourneys() {
        return BWM_JourneyDefinitionService.fetchActiveJourneys();
    }

    /**
     * @description Starts the selected campaign journey for the given Leads.
     * @param leadIds Lead Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendLeadJourney(
        List<Id> leadIds,
        String journeyName
    ) {
        return BWM_CampaignJourneyService.sendToLeads(leadIds, journeyName);
    }

    /**
     * @description Starts the selected campaign journey at the given UTC schedule time.
     * @param leadIds Lead Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @param scheduledDateTime UTC timestamp yyyy-MM-ddTHH:mm:ssZ written to scheduledatetime.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendLeadJourneyScheduled(
        List<Id> leadIds,
        String journeyName,
        String scheduledDateTime
    ) {
        return BWM_CampaignJourneyService.sendToLeads(
            leadIds,
            journeyName,
            scheduledDateTime
        );
    }

    /**
     * @description Loads active custom Lightning EmailTemplate options for Salesforce email sends.
     * @return List of EmailTemplateOption values ordered by folder and name.
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplateOption> getEmailTemplates() {
        List<EmailTemplateOption> options = new List<EmailTemplateOption>();
        for (EmailTemplate templateRecord : [
            SELECT Id, Name, FolderName
            FROM EmailTemplate
            WHERE IsActive = true
              AND TemplateType = 'custom'
              AND UiType = 'SFX'
            ORDER BY FolderName, Name
        ]) {
            options.add(
                new EmailTemplateOption(
                    templateRecord.Id,
                    templateRecord.Name,
                    templateRecord.FolderName
                )
            );
        }
        return options;
    }

    /**
     * @description Loads approved WhatsApp template options for Lead campaign sends.
     * @return List of WhatsAppTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementWhatsAppService.WhatsAppTemplateOption> getWhatsAppTemplates() {
        return LeadManagementWhatsAppService.fetchApprovedTemplates();
    }

    /**
     * @description Sends a WhatsApp template message to the selected Leads.
     * @param leadIds Lead Ids to message.
     * @param templateName Approved WhatsApp template name.
     * @return SendWhatsAppResult with send outcome details.
     */
    @AuraEnabled
    public static LeadManagementWhatsAppService.SendWhatsAppResult sendLeadWhatsApp(
        List<Id> leadIds,
        String templateName
    ) {
        return BWM_DirectWaCampaignSend.sendToLeads(leadIds, templateName);
    }

    /**
     * @description Loads approved RCS template options for Lead campaign sends.
     * @return List of RcsTemplateOption values.
     */
    @AuraEnabled
    public static List<LeadManagementRcsService.RcsTemplateOption> getRcsTemplates() {
        return LeadManagementRcsService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an RCS template message to the selected Leads.
     * @param leadIds Lead Ids to message.
     * @param templateName Approved RCS template name.
     * @return SendRcsResult with send outcome details.
     */
    @AuraEnabled
    public static LeadManagementRcsService.SendRcsResult sendLeadRcs(
        List<Id> leadIds,
        String templateName
    ) {
        return LeadManagementRcsService.sendToLeads(leadIds, templateName);
    }

    @AuraEnabled
    public static LeadManagementRcsService.SendRcsResult sendLeadRcsScheduled(
        List<Id> leadIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendLeadRcs(leadIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads approved SMS template options for Lead campaign sends.
     * @return List of SmsTemplateOption values.
     */
    @AuraEnabled
    public static List<BWM_SmsTemplateService.SmsTemplateOption> getSmsTemplates() {
        return BWM_SmsTemplateService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an SMS template message to the selected Leads.
     * @param leadIds Lead Ids to message.
     * @param templateName Approved SMS template name.
     * @return SendSmsResult with send outcome details.
     */
    @AuraEnabled
    public static LeadManagementSmsService.SendSmsResult sendLeadSms(
        List<Id> leadIds,
        String templateName
    ) {
        return LeadManagementSmsService.sendToLeads(leadIds, templateName);
    }

    @AuraEnabled
    public static LeadManagementSmsService.SendSmsResult sendLeadSmsScheduled(
        List<Id> leadIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendLeadSms(leadIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Renders and sends Salesforce email templates to Leads, applying org-wide from address and brochure attachments.
     * @param leadIds Lead Ids to email.
     * @param templateId Salesforce EmailTemplate Id to render and send.
     * @return SendEmailResult with sent/skipped counts and per-lead messages.
     */
    @AuraEnabled
    public static SendEmailResult sendLeadEmails(List<Id> leadIds, Id templateId) {
        SendEmailResult result = new SendEmailResult();

        if (leadIds == null || leadIds.isEmpty()) {
            throw new AuraHandledException('Select at least one lead.');
        }
        if (templateId == null) {
            throw new AuraHandledException('Select an email template.');
        }

        List<EmailTemplate> selectedTemplates = [
            SELECT Name
            FROM EmailTemplate
            WHERE Id = :templateId
            LIMIT 1
        ];
        String templateName = selectedTemplates.isEmpty() ? null : selectedTemplates[0].Name;

        List<Lead> leads = [
            SELECT Id, Name, Email, OwnerId, Department_Name__c, Product_Category__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<String> leadNames = new List<String>();

        for (Lead leadRecord : leads) {
            if (String.isBlank(leadRecord.Email)) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': No email address found on the lead.');
                continue;
            }

            LeadManagementEmailService.RenderedEmail renderedEmail =
                LeadManagementEmailService.renderTemplate(templateId, leadRecord);
            if (renderedEmail == null) {
                result.skippedCount++;
                result.messages.add(
                    leadRecord.Name + ': Could not render the selected email template.'
                );
                continue;
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setSaveAsActivity(true);
            message.setUseSignature(false);
            message.setToAddresses(new List<String>{ leadRecord.Email.trim() });
            message.setSubject(renderedEmail.subject);
            if (String.isNotBlank(renderedEmail.htmlBody)) {
                message.setHtmlBody(renderedEmail.htmlBody);
            }
            if (String.isNotBlank(renderedEmail.plainTextBody)) {
                message.setPlainTextBody(renderedEmail.plainTextBody);
            }

            List<Messaging.EmailFileAttachment> brochureAttachments =
                LeadManagementEmailService.buildBrochureAttachments(templateName, leadRecord);
            if (!brochureAttachments.isEmpty()) {
                message.setFileAttachments(brochureAttachments);
            }

            message.setTargetObjectId(leadRecord.Id);
            message.setTreatTargetObjectAsRecipient(false);

            applyOrgWideEmail(message);
            messages.add(message);
            leadNames.add(leadRecord.Name);
        }

        if (!messages.isEmpty()) {
            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(messages, false);
            for (Integer index = 0; index < sendResults.size(); index++) {
                if (sendResults[index].isSuccess()) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    String errorMessage = sendResults[index].getErrors().isEmpty()
                        ? 'Email send failed.'
                        : sendResults[index].getErrors()[0].getMessage();
                    result.messages.add(leadNames[index] + ': ' + errorMessage);
                }
            }
        }

        return result;
    }

    /**
     * @description Sets the Lead Management org-wide email address on the message when configured.
     * @param message SingleEmailMessage to apply the org-wide from address to.
     */
    private static void applyOrgWideEmail(Messaging.SingleEmailMessage message) {
        List<OrgWideEmailAddress> rows = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :LEAD_MANAGEMENT_ORG_WIDE_EMAIL
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            message.setOrgWideEmailAddressId(rows[0].Id);
        }
    }

    /**
     * @description Builds active picklist options from a field describe token.
     * @param fieldToken Schema field token whose picklist values are read.
     * @return List of PicklistOption label/value pairs for active entries.
     */
    private static List<PicklistOption> getPicklistOptions(Schema.SObjectField fieldToken) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    public class EmailTemplateOption {
        @AuraEnabled
        public Id value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String folderName;

        /**
         * @description Constructs an email template option for the Lead Management UI.
         * @param templateId EmailTemplate Id stored as value.
         * @param templateName Display name of the template.
         * @param folder Folder name of the template.
         */
        public EmailTemplateOption(Id templateId, String templateName, String folder) {
            value = templateId;
            label = templateName;
            folderName = folder;
        }
    }

    public class SendEmailResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        /**
         * @description Constructs a picklist option with label and API value.
         * @param optionLabel Display label for the option.
         * @param optionValue API value for the option.
         */
        public PicklistOption(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }
}