public with sharing class BWM_SmsTemplateService {
    private static final String TEMPLATES_PATH = '/api/v1/sms/getTemplate';

    public class SmsTemplateOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String status;
    }

    public static List<SmsTemplateOption> fetchApprovedTemplates() {
        BWM_Messaging_Settings__mdt settings = getSettings();
        HttpResponse response = fetchTemplatesResponse(settings);
        if (response == null) {
            throw new AuraHandledException(
                'Failed to load SMS templates. Verify SMS sender ID and Blue Waves API access.'
            );
        }
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Failed to load SMS templates: ' +
                    response.getStatus() +
                    (String.isNotBlank(response.getBody())
                        ? ' - ' + response.getBody()
                        : '')
            );
        }

        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );
        List<Object> templateRows = (List<Object>) responseBody.get('data');
        BWM_SmsDirectPayloadBuilder.cacheTemplates(templateRows);
        List<SmsTemplateOption> templates = new List<SmsTemplateOption>();

        if (templateRows != null) {
            for (Object templateObject : templateRows) {
                Map<String, Object> templateMap = (Map<String, Object>) templateObject;
                String status = (String) templateMap.get('TemplateStatus');
                if (status != null && status.toLowerCase() != 'approve') {
                    continue;
                }

                String templateName = (String) templateMap.get('TemplateName');
                if (String.isBlank(templateName)) {
                    templateName = (String) templateMap.get('templateName');
                }
                if (String.isBlank(templateName)) {
                    continue;
                }

                SmsTemplateOption option = new SmsTemplateOption();
                option.value = templateName;
                option.label = templateName;
                option.status = status;
                templates.add(option);
            }
        }

        templates.sort(new TemplateNameComparator());
        return templates;
    }

    public static HttpResponse fetchTemplatesResponse(BWM_Messaging_Settings__mdt settings) {
        HttpResponse lastResponse;

        for (String senderId : buildSenderIdCandidates(settings)) {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(
                BWM_MessagingConstants.NAMED_CREDENTIAL +
                    TEMPLATES_PATH +
                    '?senderId=' +
                    EncodingUtil.urlEncode(senderId, 'UTF-8')
            );
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader(
                String.isNotBlank(settings.API_Key_Header__c)
                    ? settings.API_Key_Header__c
                    : 'Authorization',
                'Bearer ' + settings.API_Bearer_Token__c
            );
            request.setTimeout(120000);

            lastResponse = new Http().send(request);
            if (
                lastResponse.getStatusCode() >= 200 &&
                lastResponse.getStatusCode() < 300
            ) {
                return lastResponse;
            }
        }

        return lastResponse;
    }

    private static List<String> buildSenderIdCandidates(
        BWM_Messaging_Settings__mdt settings
    ) {
        List<String> senderIds = new List<String>();
        Set<String> seen = new Set<String>();

        if (settings != null && String.isNotBlank(settings.SMS_From__c)) {
            addSenderId(senderIds, seen, settings.SMS_From__c);
        }

        addSenderId(senderIds, seen, 'UTKRSI');
        addSenderId(senderIds, seen, 'UTKRSH');

        return senderIds;
    }

    private static void addSenderId(
        List<String> senderIds,
        Set<String> seen,
        String senderId
    ) {
        if (String.isBlank(senderId)) {
            return;
        }

        String normalized = senderId.trim();
        if (!seen.contains(normalized.toUpperCase())) {
            seen.add(normalized.toUpperCase());
            senderIds.add(normalized);
        }
    }

    private static BWM_Messaging_Settings__mdt getSettings() {
        BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
        if (settings == null || String.isBlank(settings.API_Bearer_Token__c)) {
            throw new AuraHandledException('SMS API settings are not configured.');
        }
        return settings;
    }

    private class TemplateNameComparator implements System.Comparator<SmsTemplateOption> {
        public Integer compare(SmsTemplateOption first, SmsTemplateOption second) {
            String firstName = first == null || first.label == null ? '' : first.label;
            String secondName = second == null || second.label == null ? '' : second.label;
            return firstName.toLowerCase().compareTo(secondName.toLowerCase());
        }
    }
}