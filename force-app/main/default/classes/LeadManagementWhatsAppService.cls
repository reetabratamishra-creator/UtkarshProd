/**
 * @description   Lead campaign WhatsApp template fetch and direct send logic.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class LeadManagementWhatsAppService {
    private static final String TEMPLATES_PATH = '/api/v1/meta/templates';
    private static final Integer PAGE_SIZE = 100;

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

    @TestVisible
    private static Map<String, Map<String, Object>> templateMetaByName;

    public class WhatsAppTemplateOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String categoryName;
        @AuraEnabled
        public String state;
        @AuraEnabled
        public String language;
        @AuraEnabled
        public String templateId;
    }

    public class SendWhatsAppResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    /**
     * @description Loads approved WhatsApp templates for Lead campaign sends.
     * @return List of WhatsAppTemplateOption values.
     */
    public static List<WhatsAppTemplateOption> fetchApprovedTemplates() {
        BWM_Messaging_Settings__mdt settings = getSettings();
        List<WhatsAppTemplateOption> templates = new List<WhatsAppTemplateOption>();
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
                    if (templateMap.get('state') != 'APPROVED') {
                        continue;
                    }

                    WhatsAppTemplateOption option = new WhatsAppTemplateOption();
                    option.value = (String) templateMap.get('name');
                    option.label = (String) templateMap.get('name');
                    option.categoryName = (String) templateMap.get('category_name');
                    option.state = (String) templateMap.get('state');
                    option.language = (String) templateMap.get('language');
                    option.templateId = (String) templateMap.get('template_id');
                    templates.add(option);
                    cacheTemplateMeta(option.label, templateMap);
                }
            }

            page++;
        }

        templates.sort(new TemplateNameComparator());
        return templates;
    }

    /**
     * @description Sends a WhatsApp template/journey message to the selected Leads and aggregates results.
     * @param leadIds Lead Ids to message.
     * @param templateName Approved WhatsApp template name.
     * @return SendWhatsAppResult with sent/skipped counts and messages.
     */
    public static SendWhatsAppResult sendToLeads(List<Id> leadIds, String templateName) {
        SendWhatsAppResult result = new SendWhatsAppResult();

        if (leadIds == null || leadIds.isEmpty()) {
            throw new AuraHandledException('Select at least one lead.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select a WhatsApp template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('WhatsApp messaging is disabled or not configured.');
        }

        String normalizedTemplateName = templateName.trim();
        ensureTemplateCacheLoaded();
        BWM_Template_Mapping__mdt mapping = findMappingByTemplateName(normalizedTemplateName);
        Map<String, Object> templateMeta = getTemplateMetaByName(normalizedTemplateName);
        String journeyName = resolveJourneyName(mapping, normalizedTemplateName);
        String whatsAppTemplateName = resolveWhatsAppTemplateName(
            mapping,
            normalizedTemplateName
        );

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
                Owner.Phone
            FROM Lead
            WHERE Id IN :leadIds
        ];

        String successCode = String.isBlank(settings.Journey_Success_Code__c)
            ? '200'
            : settings.Journey_Success_Code__c;

        List<Message_Log__c> logsToInsert = new List<Message_Log__c>();
        String triggerPoint = mapping != null && String.isNotBlank(mapping.Trigger_Point__c)
            ? mapping.Trigger_Point__c
            : BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN;
        String templateNameForLog = mapping != null &&
            String.isNotBlank(mapping.WhatsApp_Template_Name__c)
            ? mapping.WhatsApp_Template_Name__c
            : normalizedTemplateName;

        for (Lead leadRecord : leads) {
            String phoneNumber = resolveLeadPhone(leadRecord, settings);
            if (String.isBlank(phoneNumber)) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': No valid mobile number on the lead.');
                continue;
            }

            String payload;
            String requestCurl;
            if (mapping != null) {
                payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
                    settings,
                    mapping,
                    leadRecord,
                    phoneNumber,
                    true,
                    true
                );
                payload = BWM_MessagePayloadBuilder.finalizeCampaignPayload(
                    settings,
                    leadRecord,
                    payload,
                    mapping
                );
            } else {
                payload = buildGenericJourneyPayload(
                    settings,
                    journeyName,
                    whatsAppTemplateName,
                    templateMeta,
                    leadRecord,
                    phoneNumber
                );
            }
            requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                result.skippedCount++;
                result.messages.add(
                    leadRecord.Name + ': Callout limit reached. Send fewer records or try again.'
                );
                continue;
            }
            try {
                BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(
                    BWM_MessagingCallout.send(payload),
                    successCode
                );
                logsToInsert.add(
                    BWM_MessageLogService.buildLogForRecord(
                        leadRecord,
                        triggerPoint,
                        BWM_MessagingConstants.LOG_CHANNEL_JOURNEY,
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
                        leadRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'WhatsApp send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': ' + ex.getMessage());
                logsToInsert.add(
                    BWM_MessageLogService.buildLogForRecord(
                        leadRecord,
                        triggerPoint,
                        BWM_MessagingConstants.LOG_CHANNEL_JOURNEY,
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

        BWM_MessageLogService.insertLogs(logsToInsert);

        return result;
    }

    /**
     * @description Builds a failed BWM_ApiResponse wrapper from an exception for Message_Log__c.
     * @param ex Exception thrown during the callout.
     * @return ApiResponse with message set and httpStatus 0.
     */
    private static BWM_ApiResponse buildFailedApiResponse(Exception ex) {
        BWM_ApiResponse failedResponse = new BWM_ApiResponse();
        failedResponse.message = ex.getMessage();
        failedResponse.httpStatus = 0;
        return failedResponse;
    }

    /**
     * @description Formats Lead.Phone for WhatsApp and suppresses numbers matching WhatsApp_From__c.
     * @param leadRecord Lead whose phone is resolved.
     * @param settings Messaging settings for formatting.
     * @return Formatted phone, or null when blank/matching from number.
     */
    private static String resolveLeadPhone(
        Lead leadRecord,
        BWM_Messaging_Settings__mdt settings
    ) {
        String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
            leadRecord.Phone,
            settings.Default_Country_Code__c
        );

        if (
            String.isNotBlank(formattedPhone) &&
            isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c)
        ) {
            return null;
        }

        return formattedPhone;
    }

    /**
     * @description Compares two phone values by digits only to detect identical numbers.
     * @param phoneA First phone string.
     * @param phoneB Second phone string.
     * @return True when both are non-blank and digit-normalized values match.
     */
    private static Boolean isSamePhoneNumber(String phoneA, String phoneB) {
        if (String.isBlank(phoneA) || String.isBlank(phoneB)) {
            return false;
        }
        return phoneA.replaceAll('[^0-9]', '') == phoneB.replaceAll('[^0-9]', '');
    }

    /**
     * @description Builds a generic WhatsApp/journey JSON payload for the record and template.
     * @param settings Active messaging settings metadata.
     * @param journeyName Journey definition name used in the payload.
     * @param whatsAppTemplateName WhatsApp template name used for the send.
     * @param templateMeta Cached Bluewave template metadata map.
     * @param leadRecord Lead record being messaged.
     * @param phoneNumber Formatted recipient phone number.
     * @return Serialized payload JSON string.
     */
    private static String buildGenericJourneyPayload(
        BWM_Messaging_Settings__mdt settings,
        String journeyName,
        String whatsAppTemplateName,
        Map<String, Object> templateMeta,
        Lead leadRecord,
        String phoneNumber
    ) {
        Integer variableCount = countBodyVariables(templateMeta);
        List<String> params = buildDefaultParams(leadRecord, variableCount);

        Map<String, Object> whatsAppData = new Map<String, Object>{
            'templateName' => whatsAppTemplateName,
            'bodyVariables' => buildIndexedVariables(params),
            'buttonVariables' => new List<Object>(),
            'carouselCards' => new List<Object>(),
            'limitedTimeOffer' => null
        };

        applyHeaderFromTemplateMeta(settings, leadRecord, templateMeta, whatsAppData);

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => BWM_MessagingConstants.CHANNEL_JOURNEY,
            'to' => new List<String>{ phoneNumber },
            'content' => new Map<String, Object>{
                'data' => new Map<String, Object>{
                    'journeyname' => journeyName,
                    'journeypayload' => new Map<String, Object>{
                        'nodes' => new Map<String, Object>{
                            '1' => new Map<String, Object>{
                                'templateType' => 'WHATSAPP',
                                'data' => whatsAppData
                            }
                        }
                    }
                }
            }
        };

        return JSON.serialize(payload);
    }

    /**
     * @description Applies document/header components from template metadata onto the payload.
     * @param settings Active messaging settings metadata.
     * @param leadRecord Lead record being messaged.
     * @param templateMeta Cached Bluewave template metadata map.
     * @param whatsAppData Mutable WhatsApp data map receiving header components.
     */
    private static void applyHeaderFromTemplateMeta(
        BWM_Messaging_Settings__mdt settings,
        Lead leadRecord,
        Map<String, Object> templateMeta,
        Map<String, Object> whatsAppData
    ) {
        Map<String, Object> content = getTemplateContent(templateMeta);
        Map<String, Object> header = content == null
            ? null
            : (Map<String, Object>) content.get('header');

        if (header == null) {
            // No header: omit keys — empty headerFormat breaks Blue Waves delivery.
            return;
        }

        String headerType = String.valueOf(header.get('type'));
        if (headerType == 'DOCUMENT') {
            String brochureUrl = resolveBrochureUrl(settings, leadRecord);
            Map<String, Object> headerVariable = new Map<String, Object>{
                'index' => 1,
                'type' => 'static',
                'value' => brochureUrl,
                'format' => 'document'
            };
            String cleanFileName = sanitizeBrochureFileName(brochureUrl);
            if (String.isNotBlank(cleanFileName)) {
                headerVariable.put('fileName', cleanFileName);
            }
            whatsAppData.put('headerFormat', BWM_MessagingConstants.WHATSAPP_HEADER_DOCUMENT);
            whatsAppData.put(
                'headerVariables',
                new List<Object>{ headerVariable }
            );
            return;
        }

        if (headerType == 'TEXT') {
            String headerText = header.containsKey('text')
                ? String.valueOf(header.get('text'))
                : BWM_FieldValueResolver.resolveDepartmentName(leadRecord);
            whatsAppData.put('headerFormat', BWM_MessagingConstants.WHATSAPP_HEADER_TEXT);
            whatsAppData.put(
                'headerVariables',
                new List<Object>{
                    new Map<String, Object>{
                        'index' => 1,
                        'type' => 'static',
                        'value' => String.isNotBlank(headerText) ? headerText.trim() : 'NA',
                        'format' => 'text'
                    }
                }
            );
            return;
        }

        // Unknown header type: omit header keys.
    }

    /**
     * @description Resolves a brochure/document URL for WhatsApp header attachment.
     * @param settings Active messaging settings metadata.
     * @param leadRecord Lead record being messaged.
     * @return Document URL string, or null/blank when unavailable.
     */
    private static String resolveBrochureUrl(
        BWM_Messaging_Settings__mdt settings,
        Lead leadRecord
    ) {
        return BWM_BrochureService.resolveBrochureUrlForSend(
            settings,
            leadRecord,
            BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT
        );
    }

    /**
     * @description Builds a clean WhatsApp document fileName from the brochure URL
     *              (e.g. crash_barrier(2).pdf → crash_barrier.pdf).
     * @param brochureUrl Full document URL.
     * @return Sanitized .pdf file name, or null when URL has no usable name.
     */
    private static String sanitizeBrochureFileName(String brochureUrl) {
        if (String.isBlank(brochureUrl)) {
            return null;
        }
        String trimmed = brochureUrl.trim();
        Integer queryIndex = trimmed.indexOf('?');
        if (queryIndex >= 0) {
            trimmed = trimmed.substring(0, queryIndex);
        }
        Integer slashIndex = trimmed.lastIndexOf('/');
        String fileName = slashIndex >= 0 && slashIndex < trimmed.length() - 1
            ? trimmed.substring(slashIndex + 1)
            : trimmed;
        if (String.isBlank(fileName)) {
            return null;
        }

        String extension = '.pdf';
        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            extension = fileName.substring(dotIndex).toLowerCase();
            fileName = fileName.substring(0, dotIndex);
        }
        fileName = fileName.replaceAll('(?i)\\(\\d+\\)', '');
        fileName = fileName.replaceAll('[_-]\\d+$', '');
        fileName = fileName.replaceAll('[0-9]', '');
        fileName = fileName.replaceAll('[()]', '');
        fileName = fileName.replaceAll('[^a-zA-Z_\\-]+', '_');
        fileName = fileName.replaceAll('_+', '_');
        fileName = fileName.replaceAll('^_+|_+$', '');
        fileName = fileName.toLowerCase();
        if (String.isBlank(fileName)) {
            return 'brochure.pdf';
        }
        if (extension != '.pdf') {
            extension = '.pdf';
        }
        return fileName + extension;
    }

    /**
     * @description Returns true when the document URL points to inaccessible Salesforce sandbox/file hosts.
     * @param url Candidate document URL.
     * @return True when the URL cannot be used for WhatsApp delivery.
     */
    private static Boolean isSandboxOrInaccessibleDocumentUrl(String url) {
        if (String.isBlank(url)) {
            return true;
        }

        String normalized = url.trim().toLowerCase();
        return normalized.contains('.sandbox.') ||
            normalized.contains('sandbox.file.force.com');
    }

    /**
     * @description Builds default template parameter values for the record.
     * @param leadRecord Lead record being messaged.
     * @param variableCount Number of body variables expected by the template.
     * @return List of default parameter strings.
     */
    private static List<String> buildDefaultParams(Lead leadRecord, Integer variableCount) {
        String companyName = BWM_FieldValueResolver.resolveRecord(leadRecord, 'Company');
        if (String.isBlank(companyName)) {
            companyName = BWM_FieldValueResolver.resolveRecord(leadRecord, 'Company_Name__c');
        }

        List<String> defaults = new List<String>{
            String.isNotBlank(leadRecord.Name) ? leadRecord.Name : 'Customer',
            companyName,
            BWM_FieldValueResolver.resolveRecord(leadRecord, 'Product_Category__c'),
            BWM_FieldValueResolver.resolveDepartmentName(leadRecord),
            BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Name'),
            BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Phone'),
            BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Email'),
            companyName
        };

        List<String> params = new List<String>();
        for (Integer index = 0; index < variableCount; index++) {
            String value = index < defaults.size() ? defaults[index] : '';
            params.add(String.isNotBlank(value) ? value.trim() : 'NA');
        }
        return params;
    }

    /**
     * @description Builds indexed template variable map from default params.
     * @param params Resolved template parameter values.
     * @return Map of indexed variable values.
     */
    private static List<Object> buildIndexedVariables(List<String> params) {
        List<Object> variables = new List<Object>();
        for (Integer index = 0; index < params.size(); index++) {
            String value = String.isBlank(params[index]) ? ' ' : params[index].trim();
            variables.add(
                new Map<String, Object>{
                    'index' => index + 1,
                    'type' => 'static',
                    'value' => value,
                    'format' => '{{' + String.valueOf(index + 1) + '}}'
                }
            );
        }
        return variables;
    }

    /**
     * @description Counts body variable placeholders in template content.
     * @param templateContent Template content JSON/text.
     * @return Number of body variables detected.
     */
    private static Integer countBodyVariables(Map<String, Object> templateMeta) {
        Map<String, Object> content = getTemplateContent(templateMeta);
        if (content == null || !content.containsKey('body')) {
            return 0;
        }

        String body = String.valueOf(content.get('body'));
        Integer maxIndex = 0;
        Matcher matcher = Pattern.compile('\\{\\{(\\d+)\\}\\}').matcher(body);
        while (matcher.find()) {
            Integer currentIndex = Integer.valueOf(matcher.group(1));
            if (currentIndex > maxIndex) {
                maxIndex = currentIndex;
            }
        }
        return maxIndex;
    }

    /**
     * @description Returns template content used to inspect body variables and headers.
     * @param templateMeta Cached Bluewave template metadata map.
     * @return Template content string or structure.
     */
    private static Map<String, Object> getTemplateContent(Map<String, Object> templateMeta) {
        if (templateMeta == null || !templateMeta.containsKey('content')) {
            return null;
        }
        return (Map<String, Object>) templateMeta.get('content');
    }

    /**
     * @description Finds the best BWM_Template_Mapping__mdt match for a template name.
     * @param templateName WhatsApp template name to match.
     * @return Matching template mapping, or null.
     */
    private static BWM_Template_Mapping__mdt findMappingByTemplateName(String templateName) {
        String normalizedTarget = templateName.trim().toLowerCase();
        BWM_Template_Mapping__mdt leadMatch;
        BWM_Template_Mapping__mdt fallbackMatch;

        for (BWM_Template_Mapping__mdt mapping : [
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
        ]) {
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

    /**
     * @description Ranks whether a candidate mapping is a better match than the current best.
     * @param candidate Candidate mapping or template name being evaluated.
     * @param incumbent Current best mapping match being compared.
     * @return True when candidate should replace current.
     */
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

    /**
     * @description Returns true when a template mapping matches the requested template name.
     * @param mapping Template mapping metadata row.
     * @param normalizedTarget Normalized target template name for matching.
     * @return True when mapping is a match.
     */
    private static Boolean templateMappingMatches(
        BWM_Template_Mapping__mdt mapping,
        String normalizedTarget
    ) {
        List<String> lookupNames = resolveTemplateLookupNames(normalizedTarget);
        for (String lookupName : lookupNames) {
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

    /**
     * @description Builds candidate template lookup names for mapping resolution.
     * @param normalizedTarget Normalized target template name for matching.
     * @return List of candidate names.
     */
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

    /**
     * @description Returns true when two template/journey names match after normalization.
     * @param candidate Candidate mapping or template name being evaluated.
     * @param normalizedTarget Normalized target template name for matching.
     * @return True when names are considered the same.
     */
    private static Boolean namesMatch(String candidate, String normalizedTarget) {
        if (String.isBlank(candidate)) {
            return false;
        }

        String normalizedCandidate = candidate.trim().toLowerCase();
        return normalizedCandidate == normalizedTarget ||
            ('u_' + normalizedCandidate) == normalizedTarget ||
            normalizedCandidate == ('u_' + normalizedTarget);
    }

    /**
     * @description Resolves the journey name used for the WhatsApp send payload.
     * @param mapping Template mapping metadata row.
     * @param templateName WhatsApp template name.
     * @return Journey name string.
     */
    private static String resolveJourneyName(
        BWM_Template_Mapping__mdt mapping,
        String templateName
    ) {
        if (mapping != null && String.isNotBlank(mapping.Journey_Name__c)) {
            return mapping.Journey_Name__c;
        }
        return templateName;
    }

    /**
     * @description Resolves the WhatsApp template name used for logging and payload.
     * @param mapping Template mapping metadata row.
     * @param templateName WhatsApp template name.
     * @return WhatsApp template name string.
     */
    private static String resolveWhatsAppTemplateName(
        BWM_Template_Mapping__mdt mapping,
        String templateName
    ) {
        if (mapping != null && String.isNotBlank(mapping.WhatsApp_Template_Name__c)) {
            return mapping.WhatsApp_Template_Name__c;
        }
        return templateName;
    }

    /**
     * @description Caches WhatsApp template metadata for subsequent payload builds.
     * @param templateName WhatsApp template name.
     * @param templateMap Raw template metadata map from the API.
     */
    private static void cacheTemplateMeta(String templateName, Map<String, Object> templateMap) {
        if (String.isBlank(templateName)) {
            return;
        }
        if (templateMetaByName == null) {
            templateMetaByName = new Map<String, Map<String, Object>>();
        }
        templateMetaByName.put(templateName.trim().toLowerCase(), templateMap);
    }

    /**
     * @description Returns cached template metadata for the given template name.
     * @param templateName Template name to look up.
     * @return Template metadata map, or null when missing.
     */
    private static Map<String, Object> getTemplateMetaByName(String templateName) {
        if (String.isBlank(templateName)) {
            return null;
        }
        ensureTemplateCacheLoaded();
        return templateMetaByName == null
            ? null
            : templateMetaByName.get(templateName.trim().toLowerCase());
    }

    /**
     * @description Loads and caches WhatsApp template metadata pages when the cache is empty.
     */
    private static void ensureTemplateCacheLoaded() {
        if (templateMetaByName != null && !templateMetaByName.isEmpty()) {
            return;
        }
        fetchApprovedTemplates();
    }

    /**
     * @description Loads messaging settings required for campaign sends.
     * @return Active BWM_Messaging_Settings__mdt row.
     */
    private static BWM_Messaging_Settings__mdt getSettings() {
        BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
        if (settings == null || String.isBlank(settings.API_Bearer_Token__c)) {
            throw new AuraHandledException('WhatsApp API settings are not configured.');
        }
        return settings;
    }

    /**
     * @description Fetches one page of WhatsApp templates from the Bluewave API.
     * @param settings Active messaging settings metadata.
     * @param page 1-based page number to fetch.
     * @param limitSize Page size for the templates API request.
     * @return Parsed template page payload.
     */
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

    private class TemplateNameComparator implements System.Comparator<WhatsAppTemplateOption> {
        /**
         * @description Compares WhatsApp template options by label for ascending sort order.
         * @param first Left WhatsAppTemplateOption.
         * @param second Right WhatsAppTemplateOption.
         * @return Negative, zero, or positive comparison result.
         */
        public Integer compare(WhatsAppTemplateOption first, WhatsAppTemplateOption second) {
            String firstName = first == null || first.label == null ? '' : first.label;
            String secondName = second == null || second.label == null ? '' : second.label;
            return firstName.toLowerCase().compareTo(secondName.toLowerCase());
        }
    }
}