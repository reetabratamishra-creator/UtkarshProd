/**
 * @description   AuraEnabled API for Opportunity (dealer) campaign search and
 *                multi-channel sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class DealerOpportunityManagementController {
    private static final String DEALER_OPPORTUNITY_ORG_WIDE_EMAIL =
        'noreply@utkarshindialimited.in';

    /**
     * @description Returns active Opportunity StageName picklist options for the dealer Opportunity UI.
     * @return List of PicklistOption values for Opportunity.StageName.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityStageOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        for (
            Schema.PicklistEntry entry : Opportunity.StageName.getDescribe()
                .getPicklistValues()
        ) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * @description Returns active Opportunity Lost Reason picklist options.
     * @return List of PicklistOption values for Opportunity.Lost_Reason__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityLostReasonOptions() {
        return getPicklistOptions(Opportunity.Lost_Reason__c);
    }

    /**
     * @description Returns active Opportunity Customer Category picklist options.
     * @return List of PicklistOption values for Opportunity.Customer_Category__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityCustomerCategoryOptions() {
        return getPicklistOptions(Opportunity.Customer_Category__c);
    }

    /**
     * @description Returns active Opportunity Country picklist options.
     * @return List of PicklistOption values for Opportunity.Country__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityCountryOptions() {
        return getPicklistOptions(Opportunity.Country__c);
    }

    /**
     * @description Returns active Opportunity State picklist options.
     * @return List of PicklistOption values for Opportunity.State__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityStateOptions() {
        return getPicklistOptions(Opportunity.State__c);
    }

    /**
     * @description Searches Opportunities by name, dealer account, stage, department, lost reason, and created date range.
     * @param searchTerm Optional Opportunity Name LIKE filter.
     * @param dealerAccountFilter Optional DealerAccount__r.Name LIKE filter.
     * @param stages Optional list of StageName values to include.
     * @param departmentFilter Optional Department_Name__c LIKE filter.
     * @param lostReasons Optional list of Lost_Reason__c values to include.
     * @param fromDate Optional CreatedDate lower bound (inclusive).
     * @param toDate Optional CreatedDate upper bound (inclusive through end of day).
     * @param customerCategories Optional list of Customer_Category__c values to include.
     * @param countryFilter Optional exact Country__c value filter.
     * @param states Optional list of State__c values to include.
     * @return OpportunityListItem rows including primary contact details (max 5000).
     */
    @AuraEnabled
    public static List<OpportunityListItem> searchDealerOpportunities(
        String searchTerm,
        String dealerAccountFilter,
        List<String> stages,
        String departmentFilter,
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
        String departmentPattern = String.isNotBlank(departmentFilter)
            ? '%' + departmentFilter.trim() + '%'
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
        if (departmentPattern != null) {
            soql += ' AND Department_Name__c LIKE :departmentPattern';
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
        List<Opportunity> opportunities = Database.query(soql);
        return buildOpportunityListItems(opportunities);
    }

    /**
     * @description Returns Opportunities ordered by CreatedDate descending for the dealer management grid.
     * @return OpportunityListItem rows including primary contact details.
     */
    @AuraEnabled(cacheable=true)
    public static List<OpportunityListItem> getDealerOpportunities() {
        List<Opportunity> opportunities = [
            SELECT
                Id,
                Name,
                StageName,
                Amount,
                CloseDate,
                CreatedDate,
                Department_Name__c,
                Lost_Reason__c,
                DealerAccount__r.Name
            FROM Opportunity
            ORDER BY CreatedDate DESC
        ];

        return buildOpportunityListItems(opportunities);
    }

    /**
     * @description Maps Opportunity records to UI list items and hydrates primary contact fields.
     * @param opportunities Opportunity records to transform.
     * @return List of OpportunityListItem DTOs for the LWC.
     */
    private static List<OpportunityListItem> buildOpportunityListItems(
        List<Opportunity> opportunities
    ) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opportunityRecord : opportunities) {
            opportunityIds.add(opportunityRecord.Id);
        }

        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            queryPrimaryContactsByOpportunityId(opportunityIds);

        List<OpportunityListItem> rows = new List<OpportunityListItem>();
        for (Opportunity opportunityRecord : opportunities) {
            OpportunityListItem row = new OpportunityListItem();
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

    /**
     * @description Queries primary OpportunityContactRole rows keyed by Opportunity Id.
     * @param opportunityIds Opportunity Ids to load primary contacts for.
     * @return Map of Opportunity Id to primary OpportunityContactRole.
     */
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

    /**
     * @description Sends Infobip campaign email to the selected Opportunities.
     * @param opportunityIds Opportunity Ids to send email to.
     * @param infobipTemplateId Infobip email template identifier.
     * @return SendCampaignEmailResult from BWM_CampaignEmailService.
     */
    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendOpportunityCampaignEmail(
        List<Id> opportunityIds,
        String infobipTemplateId
    ) {
        try {
            return BWM_CampaignEmailService.sendToOpportunities(
                opportunityIds,
                infobipTemplateId
            );
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static BWM_CampaignEmailService.SendCampaignEmailResult sendOpportunityCampaignEmailScheduled(
        List<Id> opportunityIds,
        String infobipTemplateId,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendOpportunityCampaignEmail(opportunityIds, infobipTemplateId);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads Bluewave/Infobip email template options for the Opportunity campaign UI.
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
     * @description Returns active campaign journey options for Opportunity sends.
     * @return List of JourneyOption values from BWM_JourneyDefinitionService.
     */
    @AuraEnabled
    public static List<BWM_JourneyDefinitionService.JourneyOption> getCampaignJourneys() {
        return BWM_JourneyDefinitionService.fetchActiveJourneys();
    }

    /**
     * @description Starts the selected campaign journey for the given Opportunities.
     * @param opportunityIds Opportunity Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendOpportunityJourney(
        List<Id> opportunityIds,
        String journeyName
    ) {
        return BWM_CampaignJourneyService.sendToOpportunities(
            opportunityIds,
            journeyName
        );
    }

    /**
     * @description Starts the selected campaign journey at the given UTC schedule time.
     * @param opportunityIds Opportunity Ids to enroll in the journey.
     * @param journeyName Name of the journey definition to send.
     * @param scheduledDateTime UTC timestamp yyyy-MM-ddTHH:mm:ssZ written to scheduledatetime.
     * @return SendJourneyResult from BWM_CampaignJourneyService.
     */
    @AuraEnabled
    public static BWM_JourneyDefinitionService.SendJourneyResult sendOpportunityJourneyScheduled(
        List<Id> opportunityIds,
        String journeyName,
        String scheduledDateTime
    ) {
        return BWM_CampaignJourneyService.sendToOpportunities(
            opportunityIds,
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
     * @description Loads approved WhatsApp template options for Opportunity campaign sends.
     * @return List of WhatsAppTemplateOption values.
     */
    @AuraEnabled
    public static List<DealerOpportunityWhatsAppService.WhatsAppTemplateOption> getWhatsAppTemplates() {
        return DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    }

    /**
     * @description Sends a WhatsApp template message to the selected Opportunities.
     * @param opportunityIds Opportunity Ids to message.
     * @param templateName Approved WhatsApp template name.
     * @return SendWhatsAppResult with send outcome details.
     */
    @AuraEnabled
    public static DealerOpportunityWhatsAppService.SendWhatsAppResult sendOpportunityWhatsApp(
        List<Id> opportunityIds,
        String templateName
    ) {
        return BWM_DirectWaCampaignSend.sendToOpportunities(
            opportunityIds,
            templateName
        );
    }

    /**
     * @description Loads approved RCS template options for Opportunity campaign sends.
     * @return List of RcsTemplateOption values.
     */
    @AuraEnabled
    public static List<DealerOpportunityRcsService.RcsTemplateOption> getRcsTemplates() {
        return DealerOpportunityRcsService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an RCS template message to the selected Opportunities.
     * @param opportunityIds Opportunity Ids to message.
     * @param templateName Approved RCS template name.
     * @return SendRcsResult with send outcome details.
     */
    @AuraEnabled
    public static DealerOpportunityRcsService.SendRcsResult sendOpportunityRcs(
        List<Id> opportunityIds,
        String templateName
    ) {
        return DealerOpportunityRcsService.sendToOpportunities(
            opportunityIds,
            templateName
        );
    }

    @AuraEnabled
    public static DealerOpportunityRcsService.SendRcsResult sendOpportunityRcsScheduled(
        List<Id> opportunityIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendOpportunityRcs(opportunityIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Loads approved SMS template options for Opportunity campaign sends.
     * @return List of SmsTemplateOption values.
     */
    @AuraEnabled
    public static List<BWM_SmsTemplateService.SmsTemplateOption> getSmsTemplates() {
        return BWM_SmsTemplateService.fetchApprovedTemplates();
    }

    /**
     * @description Sends an SMS template message to the selected Opportunities.
     * @param opportunityIds Opportunity Ids to message.
     * @param templateName Approved SMS template name.
     * @return SendSmsResult with send outcome details.
     */
    @AuraEnabled
    public static DealerOpportunitySmsService.SendSmsResult sendOpportunitySms(
        List<Id> opportunityIds,
        String templateName
    ) {
        return DealerOpportunitySmsService.sendToOpportunities(
            opportunityIds,
            templateName
        );
    }

    @AuraEnabled
    public static DealerOpportunitySmsService.SendSmsResult sendOpportunitySmsScheduled(
        List<Id> opportunityIds,
        String templateName,
        String scheduledDateTime
    ) {
        BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
        try {
            return sendOpportunitySms(opportunityIds, templateName);
        } finally {
            BWM_CampaignScheduleContext.clear();
        }
    }

    /**
     * @description Renders and sends Salesforce email templates to Opportunity contact-role recipients with brochure attachments.
     * @param opportunityIds Opportunity Ids to email.
     * @param templateId Salesforce EmailTemplate Id to render and send.
     * @return SendEmailResult with sent/skipped counts and per-opportunity messages.
     */
    @AuraEnabled
    public static SendEmailResult sendOpportunityEmails(
        List<Id> opportunityIds,
        Id templateId
    ) {
        SendEmailResult result = new SendEmailResult();

        if (opportunityIds == null || opportunityIds.isEmpty()) {
            throw new AuraHandledException('Select at least one opportunity.');
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

        List<Opportunity> opportunities = [
            SELECT Id, Name, Email__c, ContactId, OwnerId, Department_Name__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        Map<Id, List<OpportunityContactRole>> contactRolesByOpportunityId =
            queryContactRolesByOpportunityId(opportunityIds);

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<String> opportunityNames = new List<String>();

        for (Opportunity opportunityRecord : opportunities) {
            List<OpportunityContactRole> contactRoles =
                contactRolesByOpportunityId.get(opportunityRecord.Id);
            List<String> recipientEmails = collectContactRoleEmails(contactRoles);
            if (recipientEmails.isEmpty()) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name +
                        ': No email address found on related contact roles.'
                );
                continue;
            }

            Id contactIdForTemplate = resolveContactIdForTemplate(
                contactRoles,
                opportunityRecord
            );

            DealerOpportunityEmailService.RenderedEmail renderedEmail =
                DealerOpportunityEmailService.renderTemplate(
                    templateId,
                    opportunityRecord,
                    contactIdForTemplate
                );
            if (renderedEmail == null) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name + ': Could not render the selected email template.'
                );
                continue;
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setSaveAsActivity(true);
            message.setUseSignature(false);
            message.setToAddresses(recipientEmails);
            message.setSubject(renderedEmail.subject);
            if (String.isNotBlank(renderedEmail.htmlBody)) {
                message.setHtmlBody(renderedEmail.htmlBody);
            }
            if (String.isNotBlank(renderedEmail.plainTextBody)) {
                message.setPlainTextBody(renderedEmail.plainTextBody);
            }

            List<Messaging.EmailFileAttachment> brochureAttachments =
                DealerOpportunityEmailService.buildBrochureAttachments(
                    templateName,
                    opportunityRecord
                );
            if (!brochureAttachments.isEmpty()) {
                message.setFileAttachments(brochureAttachments);
            }

            Id whoId = contactIdForTemplate != null
                ? contactIdForTemplate
                : BWM_EmailTemplateRenderer.resolveWhoId(opportunityRecord);
            if (whoId != null) {
                message.setTargetObjectId(whoId);
                message.setTreatTargetObjectAsRecipient(false);
            }

            Id whatId = BWM_EmailTemplateRenderer.resolveWhatId(opportunityRecord);
            if (whatId != null) {
                message.setWhatId(whatId);
            }

            applyDealerOrgWideEmail(message);
            messages.add(message);
            opportunityNames.add(opportunityRecord.Name);
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
                    result.messages.add(opportunityNames[index] + ': ' + errorMessage);
                }
            }
        }

        return result;
    }

    /**
     * @description Queries OpportunityContactRole rows keyed by Opportunity Id, primary first.
     * @param opportunityIds Opportunity Ids to load contact roles for.
     * @return Map of Opportunity Id to ordered contact role lists.
     */
    private static Map<Id, List<OpportunityContactRole>> queryContactRolesByOpportunityId(
        List<Id> opportunityIds
    ) {
        Map<Id, List<OpportunityContactRole>> contactRolesByOpportunityId =
            new Map<Id, List<OpportunityContactRole>>();

        for (OpportunityContactRole contactRole : [
            SELECT OpportunityId, ContactId, IsPrimary, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds
            ORDER BY IsPrimary DESC, CreatedDate ASC
        ]) {
            if (!contactRolesByOpportunityId.containsKey(contactRole.OpportunityId)) {
                contactRolesByOpportunityId.put(
                    contactRole.OpportunityId,
                    new List<OpportunityContactRole>()
                );
            }
            contactRolesByOpportunityId.get(contactRole.OpportunityId).add(contactRole);
        }

        return contactRolesByOpportunityId;
    }

    /**
     * @description Collects unique non-blank email addresses from Opportunity contact roles.
     * @param contactRoles Contact roles for a single Opportunity; may be null.
     * @return Deduplicated list of recipient email addresses.
     */
    private static List<String> collectContactRoleEmails(
        List<OpportunityContactRole> contactRoles
    ) {
        List<String> recipientEmails = new List<String>();
        Set<String> uniqueEmails = new Set<String>();

        if (contactRoles == null) {
            return recipientEmails;
        }

        for (OpportunityContactRole contactRole : contactRoles) {
            String emailAddress = contactRole.Contact == null
                ? null
                : contactRole.Contact.Email;
            if (String.isBlank(emailAddress)) {
                continue;
            }

            String normalizedEmail = emailAddress.trim().toLowerCase();
            if (!uniqueEmails.contains(normalizedEmail)) {
                uniqueEmails.add(normalizedEmail);
                recipientEmails.add(emailAddress.trim());
            }
        }

        return recipientEmails;
    }

    /**
     * @description Resolves the Contact Id used for template merge (primary, then first emailed role, else Opportunity.ContactId).
     * @param contactRoles Contact roles for the Opportunity; may be null.
     * @param opportunityRecord Opportunity providing fallback ContactId.
     * @return Contact Id for template rendering, or null if none available.
     */
    private static Id resolveContactIdForTemplate(
        List<OpportunityContactRole> contactRoles,
        Opportunity opportunityRecord
    ) {
        if (contactRoles != null) {
            for (OpportunityContactRole contactRole : contactRoles) {
                if (contactRole.IsPrimary == true && contactRole.ContactId != null) {
                    return contactRole.ContactId;
                }
            }
            for (OpportunityContactRole contactRole : contactRoles) {
                if (
                    contactRole.ContactId != null &&
                    contactRole.Contact != null &&
                    String.isNotBlank(contactRole.Contact.Email)
                ) {
                    return contactRole.ContactId;
                }
            }
        }

        return opportunityRecord.ContactId;
    }

    /**
     * @description Sets the dealer Opportunity org-wide email address on the message when configured.
     * @param message SingleEmailMessage to apply the org-wide from address to.
     */
    private static void applyDealerOrgWideEmail(Messaging.SingleEmailMessage message) {
        List<OrgWideEmailAddress> rows = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :DEALER_OPPORTUNITY_ORG_WIDE_EMAIL
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
         * @description Constructs an email template option for the Opportunity Management UI.
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

    public class OpportunityListItem {
        @AuraEnabled
        public Id Id;
        @AuraEnabled
        public String Name;
        @AuraEnabled
        public String StageName;
        @AuraEnabled
        public Decimal Amount;
        @AuraEnabled
        public Date CloseDate;
        @AuraEnabled
        public Datetime CreatedDate;
        @AuraEnabled
        public String DepartmentName;
        @AuraEnabled
        public String LostReason;
        @AuraEnabled
        public String DealerAccountName;
        @AuraEnabled
        public String PrimaryContactName;
        @AuraEnabled
        public String PrimaryContactEmail;
        @AuraEnabled
        public String PrimaryContactPhone;
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