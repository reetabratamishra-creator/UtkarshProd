/**
 * @description   Lead campaign RCS template fetch and direct send logic.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class LeadManagementRcsService {
    private static final String TEMPLATES_PATH = '/api/v1/rcs/getTemplate';

    public class RcsTemplateOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String status;
    }

    public class SendRcsResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    /**
     * @description Loads approved RCS templates for Lead campaign sends.
     * @return List of RcsTemplateOption values.
     */
    public static List<RcsTemplateOption> fetchApprovedTemplates() {
        BWM_Messaging_Settings__mdt settings = getSettings();
        if (String.isBlank(settings.RCS_From__c)) {
            throw new AuraHandledException('RCS bot ID is not configured.');
        }

        String endpoint =
            BWM_MessagingConstants.NAMED_CREDENTIAL +
            TEMPLATES_PATH +
            '?botid=' +
            EncodingUtil.urlEncode(settings.RCS_From__c, 'UTF-8');

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
                'Failed to load RCS templates: ' + response.getStatus()
            );
        }

        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );
        List<Object> templateRows = (List<Object>) responseBody.get('data');
        BWM_RcsDirectPayloadBuilder.cacheTemplates(templateRows);
        List<RcsTemplateOption> templates = new List<RcsTemplateOption>();

        if (templateRows != null) {
            for (Object templateObject : templateRows) {
                Map<String, Object> templateMap = (Map<String, Object>) templateObject;
                String status = (String) templateMap.get('TemplateStatus');
                if (status != null && status.toLowerCase() != 'approve') {
                    continue;
                }

                String templateName = (String) templateMap.get('TemplateName');
                if (String.isBlank(templateName)) {
                    continue;
                }

                RcsTemplateOption option = new RcsTemplateOption();
                option.value = templateName;
                option.label = templateName;
                option.status = status;
                templates.add(option);
            }
        }

        templates.sort(new TemplateNameComparator());
        return templates;
    }

    /**
     * @description Sends an RCS template message to the selected Leads and aggregates results.
     * @param leadIds Lead Ids to message.
     * @param templateName Approved RCS template name.
     * @return SendRcsResult with sent/skipped counts and messages.
     */
    public static SendRcsResult sendToLeads(List<Id> leadIds, String templateName) {
        SendRcsResult result = new SendRcsResult();

        if (leadIds == null || leadIds.isEmpty()) {
            throw new AuraHandledException('Select at least one lead.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select an RCS template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('RCS messaging is disabled or not configured.');
        }

        String normalizedTemplateName = templateName.trim();

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

        String successCode = String.isBlank(settings.RCS_Success_Code__c)
            ? (String.isBlank(settings.Journey_Success_Code__c)
                  ? '200'
                  : settings.Journey_Success_Code__c)
            : settings.RCS_Success_Code__c;

        for (Lead leadRecord : leads) {
            String phoneNumber = resolveLeadPhone(leadRecord, settings);
            if (String.isBlank(phoneNumber)) {
                result.skippedCount++;
                result.messages.add(
                    leadRecord.Name +
                        ': No valid phone number for RCS. WhatsApp may still be sent.'
                );
                continue;
            }

            String payload = BWM_RcsDirectPayloadBuilder.buildPayload(
                settings,
                normalizedTemplateName,
                leadRecord,
                phoneNumber
            );

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
                if (apiResponse.isSuccess) {
                    result.sentCount++;
                } else {
                    result.skippedCount++;
                    result.messages.add(
                        leadRecord.Name +
                            ': ' +
                            (String.isNotBlank(apiResponse.message)
                                ? apiResponse.message
                                : 'RCS send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(leadRecord.Name + ': ' + ex.getMessage());
            }
        }

        return result;
    }

    /**
     * @description Formats Lead.Phone for RCS and suppresses numbers matching the WhatsApp/from number.
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

        if (String.isBlank(formattedPhone)) {
            return null;
        }

        if (
            isSamePhoneNumber(formattedPhone, settings.RCS_From__c) ||
            isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c) ||
            isSamePhoneNumber(formattedPhone, '9830637280')
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
     * @description Loads messaging settings required for campaign sends.
     * @return Active BWM_Messaging_Settings__mdt row.
     */
    private static BWM_Messaging_Settings__mdt getSettings() {
        BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
        if (settings == null || String.isBlank(settings.API_Bearer_Token__c)) {
            throw new AuraHandledException('RCS API settings are not configured.');
        }
        return settings;
    }

    private class TemplateNameComparator implements System.Comparator<RcsTemplateOption> {
        /**
         * @description Compares RCS template options by label for ascending sort order.
         * @param first Left RcsTemplateOption.
         * @param second Right RcsTemplateOption.
         * @return Negative, zero, or positive comparison result.
         */
        public Integer compare(RcsTemplateOption first, RcsTemplateOption second) {
            String firstName = first == null || first.label == null ? '' : first.label;
            String secondName = second == null || second.label == null ? '' : second.label;
            return firstName.toLowerCase().compareTo(secondName.toLowerCase());
        }
    }
}