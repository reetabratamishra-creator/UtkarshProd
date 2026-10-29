/**
 * @description   Manual campaign email send service for Lead, Opportunity, Account,
 *                Contact, and Offline Campaign.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_CampaignEmailService {
    private static final String TRIGGER_LEAD_CAMPAIGN = 'Email_Lead_Campaign_Manual';
    private static final String TRIGGER_OPP_CAMPAIGN = 'Email_Opp_Campaign_Manual';
    private static final String TRIGGER_ACCOUNT_CAMPAIGN = 'Email_Account_Campaign_Manual';
    private static final String TRIGGER_CONTACT_CAMPAIGN = 'Email_Contact_Campaign_Manual';
    private static final String TRIGGER_OFFLINE_CAMPAIGN = 'Email_Offline_Campaign_Manual';

    @TestVisible
    private static Map<String, String> templateSubjectCache;

    @TestVisible
    private static Map<String, String> templateNameCache;

    @TestVisible
    private static Map<String, String> templateSenderCache;

    @TestVisible
    private static Map<String, String> templateReplyToCache;

    public class CampaignTemplateMetadata {
        public String subjectForLog;
        public String templateName;
        public String senderEmail;
        public String replyToEmail;
    }

    public class SendCampaignEmailResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    /**
     * @description Sends Infobip campaign email to Leads and writes Email_Log__c rows.
     * @param leadIds Lead Ids to email.
     * @param infobipTemplateId Infobip template identifier.
     * @return SendCampaignEmailResult with sent/skipped counts and messages.
     */
    public static SendCampaignEmailResult sendToLeads(
        List<Id> leadIds,
        String infobipTemplateId
    ) {
        SendCampaignEmailResult result = new SendCampaignEmailResult();
        validateRequest(leadIds, infobipTemplateId);

        BWM_Email_Settings__mdt settings = getSettings();
        CampaignTemplateMetadata templateMetadata = resolveCampaignTemplateMetadata(
            infobipTemplateId
        );
        String senderEmail = resolveCampaignSender(settings, templateMetadata);
        String replyToEmail = templateMetadata.replyToEmail;
        List<Lead> leads = [
            SELECT Id, Name, Email
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

        for (Lead leadRecord : leads) {
            if (String.isBlank(leadRecord.Email)) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': No email address found on the lead.');
                continue;
            }

            String recipientEmail = leadRecord.Email.trim();
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    leadRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            String payload = buildPayload(
                senderEmail,
                recipientEmail,
                infobipTemplateId,
                replyToEmail
            );
            String requestCurl = BWM_EmailCallout.buildRequestCurl(payload);
            try {
                BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(
                    BWM_EmailCallout.send(payload)
                );
                logsToInsert.add(
                    buildCampaignLog(
                        leadRecord,
                        TRIGGER_LEAD_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        apiResponse.isSuccess
                            ? BWM_EmailConstants.LOG_STATUS_SENT
                            : BWM_EmailConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                );

                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        leadRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'Campaign email send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': ' + ex.getMessage());
                logsToInsert.add(
                    buildCampaignLog(
                        leadRecord,
                        TRIGGER_LEAD_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        BWM_EmailConstants.LOG_STATUS_FAILED,
                        null,
                        requestCurl,
                        payload
                    )
                );
            }
        }

        BWM_EmailLogService.insertLogs(logsToInsert);
        return result;
    }

    /**
     * @description Sends Infobip campaign email to Opportunities via primary contact emails and writes Email_Log__c rows.
     * @param opportunityIds Opportunity Ids to email.
     * @param infobipTemplateId Infobip template identifier.
     * @return SendCampaignEmailResult with sent/skipped counts and messages.
     */
    public static SendCampaignEmailResult sendToOpportunities(
        List<Id> opportunityIds,
        String infobipTemplateId
    ) {
        SendCampaignEmailResult result = new SendCampaignEmailResult();
        validateRequest(opportunityIds, infobipTemplateId);

        BWM_Email_Settings__mdt settings = getSettings();
        CampaignTemplateMetadata templateMetadata = resolveCampaignTemplateMetadata(
            infobipTemplateId
        );
        String senderEmail = resolveCampaignSender(settings, templateMetadata);
        String replyToEmail = templateMetadata.replyToEmail;

        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            queryPrimaryContactsByOpportunityId(new Set<Id>(opportunityIds));

        List<Opportunity> opportunities = [
            SELECT Id, Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

        for (Opportunity opportunityRecord : opportunities) {
            OpportunityContactRole primaryRole = primaryContactByOpportunityId.get(
                opportunityRecord.Id
            );
            String recipientEmail = primaryRole == null ||
                primaryRole.Contact == null
                ? null
                : primaryRole.Contact.Email;

            if (String.isBlank(recipientEmail)) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name +
                        ': No email address found on the primary contact.'
                );
                continue;
            }

            recipientEmail = recipientEmail.trim();
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            String payload = buildPayload(
                senderEmail,
                recipientEmail,
                infobipTemplateId,
                replyToEmail
            );
            String requestCurl = BWM_EmailCallout.buildRequestCurl(payload);
            try {
                BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(
                    BWM_EmailCallout.send(payload)
                );
                logsToInsert.add(
                    buildCampaignLog(
                        opportunityRecord,
                        TRIGGER_OPP_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        apiResponse.isSuccess
                            ? BWM_EmailConstants.LOG_STATUS_SENT
                            : BWM_EmailConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                );

                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        opportunityRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'Campaign email send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(opportunityRecord.Name + ': ' + ex.getMessage());
                logsToInsert.add(
                    buildCampaignLog(
                        opportunityRecord,
                        TRIGGER_OPP_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        BWM_EmailConstants.LOG_STATUS_FAILED,
                        null,
                        requestCurl,
                        payload
                    )
                );
            }
        }

        BWM_EmailLogService.insertLogs(logsToInsert);
        return result;
    }

    /**
     * @description Sends Infobip campaign email to Accounts and writes Email_Log__c rows.
     * @param accountIds Account Ids to email.
     * @param infobipTemplateId Infobip template identifier.
     * @return SendCampaignEmailResult with sent/skipped counts and messages.
     */
    public static SendCampaignEmailResult sendToAccounts(
        List<Id> accountIds,
        String infobipTemplateId
    ) {
        SendCampaignEmailResult result = new SendCampaignEmailResult();
        validateRequest(accountIds, infobipTemplateId);

        BWM_Email_Settings__mdt settings = getSettings();
        CampaignTemplateMetadata templateMetadata = resolveCampaignTemplateMetadata(
            infobipTemplateId
        );
        String senderEmail = resolveCampaignSender(settings, templateMetadata);
        String replyToEmail = templateMetadata.replyToEmail;
        List<Account> accounts = [
            SELECT Id, Name, Email__c
            FROM Account
            WHERE Id IN :accountIds
        ];
        List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

        for (Account accountRecord : accounts) {
            String recipientEmail = BWM_CampaignRecordSupport.resolveAccountEmail(accountRecord);
            if (String.isBlank(recipientEmail)) {
                result.skippedCount++;
                result.messages.add(accountRecord.Name + ': No email address found on the account.');
                continue;
            }

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    accountRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            String payload = buildPayload(
                senderEmail,
                recipientEmail,
                infobipTemplateId,
                replyToEmail
            );
            String requestCurl = BWM_EmailCallout.buildRequestCurl(payload);
            try {
                BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(
                    BWM_EmailCallout.send(payload)
                );
                logsToInsert.add(
                    buildCampaignLog(
                        accountRecord,
                        TRIGGER_ACCOUNT_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        apiResponse.isSuccess
                            ? BWM_EmailConstants.LOG_STATUS_SENT
                            : BWM_EmailConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                );
                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        accountRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'Campaign email send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(accountRecord.Name + ': ' + ex.getMessage());
            }
        }

        BWM_EmailLogService.insertLogs(logsToInsert);
        return result;
    }

    /**
     * @description Sends Infobip campaign email to Contacts and writes Email_Log__c rows.
     * @param contactIds Contact Ids to email.
     * @param infobipTemplateId Infobip template identifier.
     * @return SendCampaignEmailResult with sent/skipped counts and messages.
     */
    public static SendCampaignEmailResult sendToContacts(
        List<Id> contactIds,
        String infobipTemplateId
    ) {
        SendCampaignEmailResult result = new SendCampaignEmailResult();
        validateRequest(contactIds, infobipTemplateId);

        BWM_Email_Settings__mdt settings = getSettings();
        CampaignTemplateMetadata templateMetadata = resolveCampaignTemplateMetadata(
            infobipTemplateId
        );
        String senderEmail = resolveCampaignSender(settings, templateMetadata);
        String replyToEmail = templateMetadata.replyToEmail;
        List<Contact> contacts = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id IN :contactIds
        ];
        List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

        for (Contact contactRecord : contacts) {
            String recipientEmail = BWM_CampaignRecordSupport.resolveContactEmail(contactRecord);
            if (String.isBlank(recipientEmail)) {
                result.skippedCount++;
                result.messages.add(contactRecord.Name + ': No email address found on the contact.');
                continue;
            }

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    contactRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            String payload = buildPayload(
                senderEmail,
                recipientEmail,
                infobipTemplateId,
                replyToEmail
            );
            String requestCurl = BWM_EmailCallout.buildRequestCurl(payload);
            try {
                BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(
                    BWM_EmailCallout.send(payload)
                );
                logsToInsert.add(
                    buildCampaignLog(
                        contactRecord,
                        TRIGGER_CONTACT_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        apiResponse.isSuccess
                            ? BWM_EmailConstants.LOG_STATUS_SENT
                            : BWM_EmailConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                );
                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        contactRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'Campaign email send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(contactRecord.Name + ': ' + ex.getMessage());
            }
        }

        BWM_EmailLogService.insertLogs(logsToInsert);
        return result;
    }

    /**
     * @description Sends Infobip campaign email to Offline_Campaign__c records and writes Email_Log__c rows.
     * @param offlineCampaignIds Offline_Campaign__c Ids to email.
     * @param infobipTemplateId Infobip template identifier.
     * @return SendCampaignEmailResult with sent/skipped counts and messages.
     */
    public static SendCampaignEmailResult sendToOfflineCampaigns(
        List<Id> offlineCampaignIds,
        String infobipTemplateId
    ) {
        SendCampaignEmailResult result = new SendCampaignEmailResult();
        validateRequest(offlineCampaignIds, infobipTemplateId);

        BWM_Email_Settings__mdt settings = getSettings();
        CampaignTemplateMetadata templateMetadata = resolveCampaignTemplateMetadata(
            infobipTemplateId
        );
        String senderEmail = resolveCampaignSender(settings, templateMetadata);
        String replyToEmail = templateMetadata.replyToEmail;
        List<Offline_Campaign__c> offlineCampaigns = [
            SELECT Id, Name, Email__c
            FROM Offline_Campaign__c
            WHERE Id IN :offlineCampaignIds
        ];
        List<Email_Log__c> logsToInsert = new List<Email_Log__c>();

        for (Offline_Campaign__c offlineCampaignRecord : offlineCampaigns) {
            String recipientEmail = BWM_CampaignRecordSupport.resolveOfflineEmail(
                offlineCampaignRecord
            );
            if (String.isBlank(recipientEmail)) {
                result.skippedCount++;
                result.messages.add(
                    offlineCampaignRecord.Name + ': No email address found on the record.'
                );
                continue;
            }

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    offlineCampaignRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            String payload = buildPayload(
                senderEmail,
                recipientEmail,
                infobipTemplateId,
                replyToEmail
            );
            String requestCurl = BWM_EmailCallout.buildRequestCurl(payload);
            try {
                BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(
                    BWM_EmailCallout.send(payload)
                );
                logsToInsert.add(
                    buildCampaignLog(
                        offlineCampaignRecord,
                        TRIGGER_OFFLINE_CAMPAIGN,
                        senderEmail,
                        recipientEmail,
                        infobipTemplateId,
                        templateMetadata,
                        apiResponse.isSuccess
                            ? BWM_EmailConstants.LOG_STATUS_SENT
                            : BWM_EmailConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                );
                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        offlineCampaignRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'Campaign email send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(offlineCampaignRecord.Name + ': ' + ex.getMessage());
            }
        }

        BWM_EmailLogService.insertLogs(logsToInsert);
        return result;
    }

    /**
     * @description Validates that at least one record Id and an Infobip template Id were provided.
     * @param recordIds Target record Ids for the campaign email send.
     * @param infobipTemplateId Infobip template identifier selected in the UI.
     */
    private static void validateRequest(List<Id> recordIds, String infobipTemplateId) {
        if (recordIds == null || recordIds.isEmpty()) {
            throw new AuraHandledException('Select at least one record.');
        }
        if (String.isBlank(infobipTemplateId)) {
            throw new AuraHandledException('Select an email template.');
        }
    }

    /**
     * @description Loads enabled email settings and requires a configured central sender email.
     * @return Active BWM_Email_Settings__mdt row.
     */
    private static BWM_Email_Settings__mdt getSettings() {
        BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('Email settings are not configured or disabled.');
        }
        if (String.isBlank(settings.Central_Sender_Email__c)) {
            throw new AuraHandledException('Central sender email is not configured.');
        }
        return settings;
    }

    /**
     * @description Uses the template from address when the template API returned one.
     * @param settings Active email settings, used when the template has no from address.
     * @param templateMetadata Template metadata loaded from Infobip.
     * @return Sender value for the campaign email payload.
     */
    private static String resolveCampaignSender(
        BWM_Email_Settings__mdt settings,
        CampaignTemplateMetadata templateMetadata
    ) {
        if (templateMetadata != null && String.isNotBlank(templateMetadata.senderEmail)) {
            return templateMetadata.senderEmail;
        }
        return settings.Central_Sender_Email__c;
    }

    /**
     * @description Builds the Infobip campaign email JSON payload for a single recipient.
     * @param senderEmail Sender taken from the template from address when present.
     * @param recipientEmail Destination email address.
     * @param infobipTemplateId Infobip template identifier.
     * @param replyToEmail Reply-to address from the template when present.
     * @return Serialized Infobip messages payload JSON.
     */
    private static String buildPayload(
        String senderEmail,
        String recipientEmail,
        String infobipTemplateId,
        String replyToEmail
    ) {
        Map<String, Object> message = new Map<String, Object>{
            'sender' => senderEmail,
            'destinations' => new List<Object>{
                new Map<String, Object>{
                    'to' => new List<Object>{
                        new Map<String, Object>{
                            'destination' => recipientEmail
                        }
                    }
                }
            },
            'content' => new Map<String, Object>{
                'templateId' => infobipTemplateId.trim()
            }
        };
        if (String.isNotBlank(replyToEmail)) {
            message.put('replyTo', replyToEmail.trim());
        }
        Map<String, Object> payload = new Map<String, Object>{
            'messages' => new List<Object>{ message }
        };
        String sendAt = toInfobipSendAt(BWM_CampaignScheduleContext.scheduledDateTime);
        if (String.isNotBlank(sendAt)) {
            payload.put(
                'options',
                new Map<String, Object>{
                    'schedule' => new Map<String, Object>{ 'sendAt' => sendAt }
                }
            );
        }
        return JSON.serialize(payload);
    }

    /**
     * @description Converts the campaign schedule (UTC, yyyy-MM-ddTHH:mm:ssZ) to the
     *              Infobip sendAt format yyyy-MM-ddTHH:mm:ss.000Z.
     * @param scheduledDateTime UTC timestamp from the campaign schedule screen.
     * @return Infobip sendAt value, or null when no schedule was chosen.
     */
    @TestVisible
    private static String toInfobipSendAt(String scheduledDateTime) {
        if (String.isBlank(scheduledDateTime)) {
            return null;
        }
        String value = scheduledDateTime.trim();
        if (Pattern.matches('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', value)) {
            return value.removeEnd('Z') + '.000Z';
        }
        return value;
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
            SELECT OpportunityId, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds AND IsPrimary = TRUE
        ]) {
            primaryContactByOpportunityId.put(contactRole.OpportunityId, contactRole);
        }

        return primaryContactByOpportunityId;
    }

    @TestVisible
    static void resetTemplateSubjectCacheForTests() {
        templateSubjectCache = null;
        templateNameCache = null;
        templateSenderCache = null;
        templateReplyToCache = null;
    }

    private static CampaignTemplateMetadata resolveCampaignTemplateMetadata(
        String infobipTemplateId
    ) {
        CampaignTemplateMetadata metadata = new CampaignTemplateMetadata();
        if (String.isBlank(infobipTemplateId)) {
            return metadata;
        }

        if (templateSubjectCache == null) {
            templateSubjectCache = new Map<String, String>();
        }
        if (templateNameCache == null) {
            templateNameCache = new Map<String, String>();
        }
        if (templateSenderCache == null) {
            templateSenderCache = new Map<String, String>();
        }
        if (templateReplyToCache == null) {
            templateReplyToCache = new Map<String, String>();
        }
        if (
            templateSubjectCache.containsKey(infobipTemplateId) &&
            templateNameCache.containsKey(infobipTemplateId) &&
            templateSenderCache.containsKey(infobipTemplateId) &&
            templateReplyToCache.containsKey(infobipTemplateId)
        ) {
            metadata.subjectForLog = templateSubjectCache.get(infobipTemplateId);
            metadata.templateName = templateNameCache.get(infobipTemplateId);
            metadata.senderEmail = templateSenderCache.get(infobipTemplateId);
            metadata.replyToEmail = templateReplyToCache.get(infobipTemplateId);
            return metadata;
        }

        BWM_InfobipEmailTemplateService.TemplateMetadata templateMetadata;
        try {
            templateMetadata = BWM_InfobipEmailTemplateService.fetchTemplateMetadata(
                infobipTemplateId
            );
        } catch (Exception ex) {
            templateMetadata = null;
        }

        metadata.subjectForLog = templateMetadata == null
            ? null
            : templateMetadata.resolveSubjectForLog();
        metadata.templateName = templateMetadata == null ? null : templateMetadata.name;
        metadata.senderEmail = templateMetadata == null ? null : templateMetadata.fromAddress;
        metadata.replyToEmail = templateMetadata == null ? null : templateMetadata.replyTo;
        templateSubjectCache.put(infobipTemplateId, metadata.subjectForLog);
        templateNameCache.put(infobipTemplateId, metadata.templateName);
        templateSenderCache.put(infobipTemplateId, metadata.senderEmail);
        templateReplyToCache.put(infobipTemplateId, metadata.replyToEmail);
        return metadata;
    }

    private static void applyCampaignTemplateMetadata(
        Email_Log__c logRecord,
        CampaignTemplateMetadata templateMetadata
    ) {
        if (logRecord == null || templateMetadata == null) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = Email_Log__c.SObjectType.getDescribe()
            .fields.getMap();
        if (fieldMap.containsKey('Campaign_Email_Subject__c')) {
            if (String.isNotBlank(templateMetadata.subjectForLog)) {
                logRecord.put('Campaign_Email_Subject__c', templateMetadata.subjectForLog);
            }
            logRecord.Template_Name__c = templateMetadata.templateName;
            return;
        }

        if (String.isNotBlank(templateMetadata.subjectForLog)) {
            logRecord.Template_Name__c = templateMetadata.subjectForLog;
            return;
        }

        logRecord.Template_Name__c = templateMetadata.templateName;
    }

    /**
     * @description Builds an Email_Log__c row for a manual campaign email send attempt.
     * @param record Related Lead or Opportunity (or other) record.
     * @param triggerPoint Campaign email trigger key.
     * @param fromEmail Sender email address.
     * @param toEmail Recipient email address.
     * @param infobipTemplateId Infobip template identifier used.
     * @param templateMetadata Resolved Infobip template subject and name.
     * @param status Log status (Sent/Failed/Skipped).
     * @param apiResponse Parsed Infobip response; may be null on exceptions.
     * @param requestCurl Request curl/audit string.
     * @param requestPayload Request payload JSON.
     * @return Populated Email_Log__c ready for insert.
     */
    private static Email_Log__c buildCampaignLog(
        SObject record,
        String triggerPoint,
        String fromEmail,
        String toEmail,
        String infobipTemplateId,
        CampaignTemplateMetadata templateMetadata,
        String status,
        BWM_EmailApiResponse apiResponse,
        String requestCurl,
        String requestPayload
    ) {
        Email_Log__c logRecord = new Email_Log__c();
        logRecord.Related_Record_Id__c = record.Id;
        logRecord.Trigger_Point__c = triggerPoint;
        logRecord.From_Email__c = fromEmail;
        logRecord.To_Email__c = toEmail;
        logRecord.Status__c = status;
        logRecord.Template_Id__c = infobipTemplateId;
        applyCampaignTemplateMetadata(logRecord, templateMetadata);

        if (record instanceof Lead) {
            logRecord.Lead__c = record.Id;
        } else if (record instanceof Opportunity) {
            logRecord.Opportunity__c = record.Id;
        }

        logRecord.Request_Curl__c = requestCurl;
        logRecord.Request_Payload__c = requestPayload;

        if (apiResponse != null) {
            logRecord.Response_Payload__c = apiResponse.rawBody;
            logRecord.Response_Message__c = apiResponse.message;
            logRecord.Response_Http_Status__c = apiResponse.httpStatus == null
                ? null
                : String.valueOf(apiResponse.httpStatus);
        }

        return logRecord;
    }
}