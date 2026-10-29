/**
 * @description Direct WhatsApp send entry point for Send WhatsApp Campaign UIs.
 *              Uses channel WhatsApp + templatepayload (not Journey).
 */
public with sharing class BWM_WaCampSendA {
    private static final String TEMPLATES_PATH = '/api/v1/meta/templates';
    private static final Integer PAGE_SIZE = 100;

    @TestVisible
    private static Map<String, Map<String, Object>> templateMetaByName;

    @TestVisible
    private static final Map<String, String> META_TEMPLATE_ALIASES = new Map<String, String>{
        'u_prosp_not_resp' => 'prospect_not_responding_dept',
        'u_prospecting_not_resp' => 'prospecting_not_responding_dept',
        'u_prospect_de_not_rec' => 'prospect_details_not_received_dept',
        'u_prospecting_det_not_rec' => 'prospecting_details_not_received_dept',
        'u_prospect_enq_dept' => 'prospect_enq_dept',
        'u_prospect_enq_gen' => 'prospect_enq_gen',
        'u_dealer_enq_dept' => 'dealer_enq_dept',
        'u_dealer_enq_gen' => 'dealer_enq_gen'
    };

    public static LeadManagementWhatsAppService.SendWhatsAppResult sendToLeads(
        List<Id> leadIds,
        String templateName
    ) {
        LeadManagementWhatsAppService.SendWhatsAppResult result =
            new LeadManagementWhatsAppService.SendWhatsAppResult();

        if (leadIds == null || leadIds.isEmpty()) {
            throw new AuraHandledException('Select at least one lead.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select a WhatsApp template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        String normalizedTemplateName = templateName.trim();
        ensureTemplateCacheLoaded(settings);
        BWM_Template_Mapping__mdt mapping = findLeadMappingByTemplateName(normalizedTemplateName);
        String whatsAppTemplateName = resolveWhatsAppTemplateName(mapping, normalizedTemplateName);
        Map<String, Object> templateMeta = resolveTemplateMeta(normalizedTemplateName, whatsAppTemplateName);
        String successCodeForSend = String.isBlank(settings.WhatsApp_Success_Code__c)
            ? '202'
            : settings.WhatsApp_Success_Code__c;
        String triggerPoint = mapping != null && String.isNotBlank(mapping.Trigger_Point__c)
            ? mapping.Trigger_Point__c
            : BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN;
        String templateNameForLog = whatsAppTemplateName;

        List<Lead> leads = [
            SELECT
                Id,
                Name,
                FirstName,
                LastName,
                Phone,
                Email,
                Company,
                Company_Name__c,
                Department_Name__c,
                Product_Category__c,
                Status,
                OwnerId,
                Owner.Name,
                Owner.FirstName,
                Owner.LastName,
                Owner.Email,
                Owner.Phone,
                CRM_User_Name_Formula__c,
                CRM_User_Contact_No_Formula__c,
                CRM_User_Email_Formula__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Message_Log__c> logsToInsert = new List<Message_Log__c>();
        for (Lead leadRecord : leads) {
            sendDirectWhatsAppToRecord(
                settings,
                mapping,
                templateMeta,
                whatsAppTemplateName,
                templateNameForLog,
                triggerPoint,
                leadRecord,
                resolveLeadPhone(leadRecord, settings),
                leadRecord.Name,
                successCodeForSend,
                result,
                logsToInsert
            );
        }

        BWM_MessageLogService.insertLogs(logsToInsert);
        return result;
    }

    public static DealerOpportunityWhatsAppService.SendWhatsAppResult sendToOpportunities(
        List<Id> opportunityIds,
        String templateName
    ) {
        DealerOpportunityWhatsAppService.SendWhatsAppResult result =
            new DealerOpportunityWhatsAppService.SendWhatsAppResult();

        if (opportunityIds == null || opportunityIds.isEmpty()) {
            throw new AuraHandledException('Select at least one opportunity.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select a WhatsApp template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        String normalizedTemplateName = templateName.trim();
        ensureTemplateCacheLoaded(settings);
        BWM_Template_Mapping__mdt mapping = findOpportunityMappingByTemplateName(
            normalizedTemplateName
        );
        String whatsAppTemplateName = resolveWhatsAppTemplateName(mapping, normalizedTemplateName);
        Map<String, Object> templateMeta = resolveTemplateMeta(normalizedTemplateName, whatsAppTemplateName);
        String successCodeForSend = String.isBlank(settings.WhatsApp_Success_Code__c)
            ? '202'
            : settings.WhatsApp_Success_Code__c;
        String triggerPoint = mapping != null && String.isNotBlank(mapping.Trigger_Point__c)
            ? mapping.Trigger_Point__c
            : BWM_MessagingConstants.TRIGGER_OPPORTUNITY_CAMPAIGN;
        String templateNameForLog = whatsAppTemplateName;

        List<Opportunity> opportunities = [
            SELECT
                Id,
                Name,
                Phone__c,
                Email__c,
                Department_Name__c,
                Product_Category__c,
                ContactId,
                OwnerId,
                Owner.Name,
                Owner.FirstName,
                Owner.LastName,
                Owner.Email,
                Owner.Phone,
                Owner.MobilePhone,
                Account.Name,
                Account.Phone,
                Lead__c,
                Lead__r.Phone,
                DealerAccount__c,
                DealerAccount__r.Name,
                DealerAccount__r.Phone,
                CRM_User_Name_Formula__c,
                CRM_User_Contact_No_Formula__c,
                CRM_User_Email_Formula__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        List<Message_Log__c> logsToInsert = new List<Message_Log__c>();
        LeadManagementWhatsAppService.SendWhatsAppResult innerResult =
            new LeadManagementWhatsAppService.SendWhatsAppResult();
        for (Opportunity opportunityRecord : opportunities) {
            sendDirectWhatsAppToRecord(
                settings,
                mapping,
                templateMeta,
                whatsAppTemplateName,
                templateNameForLog,
                triggerPoint,
                opportunityRecord,
                resolveOpportunityPhone(opportunityRecord, settings),
                opportunityRecord.Name,
                successCodeForSend,
                innerResult,
                logsToInsert
            );
        }

        BWM_MessageLogService.insertLogs(logsToInsert);
        result.sentCount = innerResult.sentCount;
        result.skippedCount = innerResult.skippedCount;
        result.messages = innerResult.messages;
        return result;
    }

    public static LeadManagementWhatsAppService.SendWhatsAppResult sendToRecords(
        List<SObject> records,
        String templateName,
        String triggerPoint
    ) {
        LeadManagementWhatsAppService.SendWhatsAppResult result =
            new LeadManagementWhatsAppService.SendWhatsAppResult();

        if (records == null || records.isEmpty()) {
            throw new AuraHandledException('Select at least one record.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select a WhatsApp template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        String normalizedTemplateName = templateName.trim();
        ensureTemplateCacheLoaded(settings);
        BWM_Template_Mapping__mdt mapping = findLeadMappingByTemplateName(normalizedTemplateName);
        String whatsAppTemplateName = resolveWhatsAppTemplateName(mapping, normalizedTemplateName);
        Map<String, Object> templateMeta = resolveTemplateMeta(normalizedTemplateName, whatsAppTemplateName);
        String successCodeForSend = String.isBlank(settings.WhatsApp_Success_Code__c)
            ? '202'
            : settings.WhatsApp_Success_Code__c;
        String templateNameForLog = whatsAppTemplateName;
        List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

        for (SObject record : records) {
            sendDirectWhatsAppToRecord(
                settings,
                mapping,
                templateMeta,
                whatsAppTemplateName,
                templateNameForLog,
                triggerPoint,
                record,
                resolveGenericPhone(record, settings),
                String.valueOf(record.get('Name')),
                successCodeForSend,
                result,
                logsToInsert
            );
        }

        BWM_MessageLogService.insertLogs(logsToInsert);
        return result;
    }

    private static void sendDirectWhatsAppToRecord(
        BWM_Messaging_Settings__mdt settings,
        BWM_Template_Mapping__mdt mapping,
        Map<String, Object> templateMeta,
        String whatsAppTemplateName,
        String templateNameForLog,
        String triggerPoint,
        SObject record,
        String phoneNumber,
        String recordName,
        String successCodeForSend,
        LeadManagementWhatsAppService.SendWhatsAppResult result,
        List<Message_Log__c> logsToInsert
    ) {
        if (String.isBlank(phoneNumber)) {
            result.skippedCount++;
            result.messages.add(recordName + ': No valid mobile number on the record.');
            return;
        }

        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
            result.skippedCount++;
            result.messages.add(
                recordName + ': Callout limit reached. Send fewer records or try again.'
            );
            return;
        }

        String payload = BWM_WaCampPayloadA.buildPayload(
            settings,
            mapping,
            whatsAppTemplateName,
            templateMeta,
            record,
            phoneNumber
        );
        String requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);

        try {
            BWM_ApiResponse apiResponse = BWM_ApiResponse.parseWhatsAppDirect(
                BWM_MessagingCallout.send(payload),
                successCodeForSend
            );
            logsToInsert.add(
                BWM_MessageLogService.buildLogForRecord(
                    record,
                    triggerPoint,
                    BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                    templateNameForLog,
                    phoneNumber,
                    apiResponse.isSuccess
                        ? BWM_MessagingConstants.LOG_STATUS_SENT
                        : BWM_MessagingConstants.LOG_STATUS_FAILED,
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
                    recordName +
                        ': ' +
                        (String.isNotBlank(apiResponse.message)
                            ? apiResponse.message
                            : 'WhatsApp send failed.')
                );
            }
        } catch (Exception ex) {
            result.skippedCount++;
            result.messages.add(recordName + ': ' + ex.getMessage());
            logsToInsert.add(
                BWM_MessageLogService.buildLogForRecord(
                    record,
                    triggerPoint,
                    BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                    templateNameForLog,
                    phoneNumber,
                    BWM_MessagingConstants.LOG_STATUS_FAILED,
                    buildFailedApiResponse(ex),
                    requestCurl,
                    payload
                )
            );
        }
    }

    private static BWM_ApiResponse buildFailedApiResponse(Exception ex) {
        BWM_ApiResponse failedResponse = new BWM_ApiResponse();
        failedResponse.message = ex.getMessage();
        failedResponse.httpStatus = 0;
        return failedResponse;
    }

    private static String resolveLeadPhone(Lead leadRecord, BWM_Messaging_Settings__mdt settings) {
        String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
            leadRecord.Phone,
            settings.Default_Country_Code__c
        );
        if (
            String.isNotBlank(formattedPhone) &&
            formattedPhone.replaceAll('[^0-9]', '') ==
            settings.WhatsApp_From__c.replaceAll('[^0-9]', '')
        ) {
            return null;
        }
        return formattedPhone;
    }

    private static String resolveOpportunityPhone(
        Opportunity opportunityRecord,
        BWM_Messaging_Settings__mdt settings
    ) {
        String phone = opportunityRecord.Phone__c;
        if (String.isBlank(phone) && opportunityRecord.Lead__r != null) {
            phone = opportunityRecord.Lead__r.Phone;
        }
        return BWM_PhoneFormatter.formatForMessaging(
            phone,
            settings.Default_Country_Code__c
        );
    }

    private static String resolveGenericPhone(
        SObject record,
        BWM_Messaging_Settings__mdt settings
    ) {
        if (record instanceof Account) {
            return BWM_CampaignRecordSupport.resolveAccountPhone((Account) record, settings);
        }
        if (record instanceof Contact) {
            return BWM_CampaignRecordSupport.resolveContactPhone((Contact) record, settings);
        }
        if (record instanceof Offline_Campaign__c) {
            return BWM_CampaignRecordSupport.resolveOfflinePhone(
                (Offline_Campaign__c) record,
                settings
            );
        }
        return null;
    }

    private static BWM_Messaging_Settings__mdt getSettings() {
        BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('WhatsApp messaging is disabled or not configured.');
        }
        if (String.isBlank(settings.API_Bearer_Token__c)) {
            throw new AuraHandledException('WhatsApp API settings are not configured.');
        }
        return settings;
    }

    private static String resolveWhatsAppTemplateName(
        BWM_Template_Mapping__mdt mapping,
        String templateName
    ) {
        if (mapping != null && String.isNotBlank(mapping.WhatsApp_Template_Name__c)) {
            return mapping.WhatsApp_Template_Name__c;
        }
        return templateName;
    }

    private static BWM_Template_Mapping__mdt findLeadMappingByTemplateName(String templateName) {
        String normalizedTarget = templateName.trim().toLowerCase();
        BWM_Template_Mapping__mdt leadMatch;
        BWM_Template_Mapping__mdt fallbackMatch;

        for (BWM_Template_Mapping__mdt mapping : queryActiveMappings()) {
            if (!templateMappingMatches(mapping, normalizedTarget)) {
                continue;
            }
            if (mapping.Object_Type__c != BWM_MessagingConstants.OBJECT_TYPE_OPPORTUNITY) {
                if (isBetterMappingMatch(mapping, leadMatch)) {
                    leadMatch = mapping;
                }
            }
            if (isBetterMappingMatch(mapping, fallbackMatch)) {
                fallbackMatch = mapping;
            }
        }

        return leadMatch != null ? leadMatch : fallbackMatch;
    }

    private static BWM_Template_Mapping__mdt findOpportunityMappingByTemplateName(
        String templateName
    ) {
        String normalizedTarget = templateName.trim().toLowerCase();
        for (BWM_Template_Mapping__mdt mapping : queryActiveMappings()) {
            if (
                namesMatch(mapping.WhatsApp_Template_Name__c, normalizedTarget) ||
                namesMatch(mapping.Journey_Name__c, normalizedTarget)
            ) {
                return mapping;
            }
        }
        return null;
    }

    private static List<BWM_Template_Mapping__mdt> queryActiveMappings() {
        return [
            SELECT
                Trigger_Point__c,
                Object_Type__c,
                WhatsApp_Template_Name__c,
                Journey_Name__c,
                RCS_Template_Name__c,
                SMS_Template_Name__c,
                Include_Brochure_Header__c,
                Param1_Field__c,
                Param2_Field__c,
                Param3_Field__c,
                Param4_Field__c,
                Param5_Field__c,
                Param6_Field__c,
                Param7_Field__c,
                Param8_Field__c,
                RCS_SMS_Param_Limit__c,
                WhatsApp_Header_Format__c,
                WhatsApp_Header_Value_Field__c,
                Document_Header_URL__c,
                Brochure_Attachment_Mode__c,
                Priority__c
            FROM BWM_Template_Mapping__mdt
            WHERE Is_Active__c = TRUE
        ];
    }

    private static Boolean isBetterMappingMatch(
        BWM_Template_Mapping__mdt candidate,
        BWM_Template_Mapping__mdt incumbent
    ) {
        if (incumbent == null) {
            return true;
        }
        Boolean candidateHasJourney = String.isNotBlank(candidate.Journey_Name__c);
        Boolean incumbentHasJourney = String.isNotBlank(incumbent.Journey_Name__c);
        if (candidateHasJourney != incumbentHasJourney) {
            return candidateHasJourney;
        }
        Decimal candidatePriority = candidate.Priority__c == null ? 0 : candidate.Priority__c;
        Decimal incumbentPriority = incumbent.Priority__c == null ? 0 : incumbent.Priority__c;
        return candidatePriority > incumbentPriority;
    }

    private static Boolean templateMappingMatches(
        BWM_Template_Mapping__mdt mapping,
        String normalizedTarget
    ) {
        for (String lookupName : resolveTemplateLookupNames(normalizedTarget)) {
            if (
                namesMatch(mapping.WhatsApp_Template_Name__c, lookupName) ||
                namesMatch(mapping.Journey_Name__c, lookupName) ||
                namesMatch(mapping.SMS_Template_Name__c, lookupName) ||
                namesMatch(mapping.RCS_Template_Name__c, lookupName)
            ) {
                return true;
            }
        }
        return false;
    }

    private static List<String> resolveTemplateLookupNames(String normalizedTarget) {
        Set<String> lookupNames = new Set<String>{ normalizedTarget };
        if (META_TEMPLATE_ALIASES.containsKey(normalizedTarget)) {
            lookupNames.add(META_TEMPLATE_ALIASES.get(normalizedTarget));
        }
        for (String metaName : META_TEMPLATE_ALIASES.keySet()) {
            if (META_TEMPLATE_ALIASES.get(metaName) == normalizedTarget) {
                lookupNames.add(metaName);
            }
        }
        return new List<String>(lookupNames);
    }

    private static Boolean namesMatch(String candidate, String normalizedTarget) {
        if (String.isBlank(candidate)) {
            return false;
        }
        String normalizedCandidate = candidate.trim().toLowerCase();
        return normalizedCandidate == normalizedTarget ||
            ('u_' + normalizedCandidate) == normalizedTarget ||
            normalizedCandidate == ('u_' + normalizedTarget);
    }

    private static void ensureTemplateCacheLoaded(BWM_Messaging_Settings__mdt settings) {
        if (templateMetaByName != null && !templateMetaByName.isEmpty()) {
            return;
        }

        templateMetaByName = new Map<String, Map<String, Object>>();
        Integer page = 1;
        Integer totalPages = 1;
        while (page <= totalPages) {
            Map<String, Object> responseBody = fetchTemplatesPage(settings, page, PAGE_SIZE);
            if (responseBody == null) {
                break;
            }
            Object totalPagesValue = responseBody.get('total_pages');
            if (totalPagesValue != null) {
                totalPages = Integer.valueOf(String.valueOf(totalPagesValue));
            }
            List<Object> pageTemplates = (List<Object>) responseBody.get('templates');
            if (pageTemplates != null) {
                for (Object templateObject : pageTemplates) {
                    Map<String, Object> templateMap = (Map<String, Object>) templateObject;
                    String name = (String) templateMap.get('name');
                    if (String.isNotBlank(name)) {
                        templateMetaByName.put(name.trim().toLowerCase(), templateMap);
                    }
                }
            }
            page++;
        }
    }

    private static Map<String, Object> getTemplateMetaByName(String templateName) {
        if (String.isBlank(templateName) || templateMetaByName == null) {
            return null;
        }
        return templateMetaByName.get(templateName.trim().toLowerCase());
    }

    private static Map<String, Object> resolveTemplateMeta(
        String selectedTemplateName,
        String whatsAppTemplateName
    ) {
        Map<String, Object> templateMeta = getTemplateMetaByName(selectedTemplateName);
        if (templateMeta != null) {
            return templateMeta;
        }
        templateMeta = getTemplateMetaByName(whatsAppTemplateName);
        if (templateMeta != null) {
            return templateMeta;
        }
        for (String lookupName : resolveTemplateLookupNames(
            selectedTemplateName.trim().toLowerCase()
        )) {
            templateMeta = getTemplateMetaByName(lookupName);
            if (templateMeta != null) {
                return templateMeta;
            }
        }
        return null;
    }

    private static Map<String, Object> fetchTemplatesPage(
        BWM_Messaging_Settings__mdt settings,
        Integer page,
        Integer limitSize
    ) {
        String endpoint =
            BWM_MessagingConstants.NAMED_CREDENTIAL +
            TEMPLATES_PATH +
            '?page=' +
            page +
            '&limit=' +
            limitSize;

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader(
            String.isNotBlank(settings.API_Key_Header__c)
                ? settings.API_Key_Header__c
                : 'Authorization',
            'Bearer ' + settings.API_Bearer_Token__c
        );
        request.setTimeout(120000);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Failed to load WhatsApp templates: ' + response.getStatus()
            );
        }

        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    @TestVisible
    static void clearCache() {
        templateMetaByName = null;
    }
}