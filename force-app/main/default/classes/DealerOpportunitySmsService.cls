public with sharing class DealerOpportunitySmsService {
    private static final String TEMPLATES_PATH = '/api/v1/sms/getTemplate';

    public class SmsTemplateOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String status;
    }

    public class SendSmsResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    public static List<SmsTemplateOption> fetchApprovedTemplates() {
        BWM_Messaging_Settings__mdt settings = getSettings();
        if (String.isBlank(settings.SMS_From__c)) {
            throw new AuraHandledException('SMS sender ID is not configured.');
        }

        String endpoint =
            BWM_MessagingConstants.NAMED_CREDENTIAL +
            TEMPLATES_PATH +
            '?senderId=' +
            EncodingUtil.urlEncode(settings.SMS_From__c, 'UTF-8');

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
                'Failed to load SMS templates: ' + response.getStatus()
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

    public static SendSmsResult sendToOpportunities(
        List<Id> opportunityIds,
        String templateName
    ) {
        SendSmsResult result = new SendSmsResult();

        if (opportunityIds == null || opportunityIds.isEmpty()) {
            throw new AuraHandledException('Select at least one opportunity.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select an SMS template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('SMS messaging is disabled or not configured.');
        }

        String normalizedTemplateName = templateName.trim();
        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            queryPrimaryContactsByOpportunityId(opportunityIds);

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
                DealerAccount__r.Phone
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        String successCode = String.isBlank(settings.Journey_Success_Code__c)
            ? '200'
            : settings.Journey_Success_Code__c;

        for (Opportunity opportunityRecord : opportunities) {
            String phoneNumber = resolvePrimaryContactPhone(
                primaryContactByOpportunityId.get(opportunityRecord.Id),
                settings
            );
            if (String.isBlank(phoneNumber)) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name +
                        ': No valid primary contact phone number.'
                );
                continue;
            }

            try {
                String payload = BWM_SmsDirectPayloadBuilder.buildPayload(
                    settings,
                    normalizedTemplateName,
                    opportunityRecord,
                    phoneNumber
                );

                BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(
                    BWM_MessagingCallout.send(payload),
                    successCode
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
                                : 'SMS send failed.')
                    );
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(opportunityRecord.Name + ': ' + ex.getMessage());
            }
        }

        return result;
    }

    private static Map<Id, OpportunityContactRole> queryPrimaryContactsByOpportunityId(
        List<Id> opportunityIds
    ) {
        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            new Map<Id, OpportunityContactRole>();

        for (OpportunityContactRole contactRole : [
            SELECT
                OpportunityId,
                ContactId,
                IsPrimary,
                Contact.Phone,
                Contact.MobilePhone
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds AND IsPrimary = TRUE
        ]) {
            primaryContactByOpportunityId.put(contactRole.OpportunityId, contactRole);
        }

        return primaryContactByOpportunityId;
    }

    private static String resolvePrimaryContactPhone(
        OpportunityContactRole contactRole,
        BWM_Messaging_Settings__mdt settings
    ) {
        if (contactRole == null || contactRole.Contact == null) {
            return null;
        }

        String rawPhone = String.isNotBlank(contactRole.Contact.MobilePhone)
            ? contactRole.Contact.MobilePhone
            : contactRole.Contact.Phone;
        if (String.isBlank(rawPhone)) {
            return null;
        }

        String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
            rawPhone,
            settings.Default_Country_Code__c
        );
        if (String.isBlank(formattedPhone)) {
            return null;
        }

        if (
            isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c) ||
            isSamePhoneNumber(formattedPhone, '9830637280')
        ) {
            return null;
        }

        return formattedPhone;
    }

    private static Boolean isSamePhoneNumber(String phoneA, String phoneB) {
        if (String.isBlank(phoneA) || String.isBlank(phoneB)) {
            return false;
        }
        return phoneA.replaceAll('[^0-9]', '') == phoneB.replaceAll('[^0-9]', '');
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