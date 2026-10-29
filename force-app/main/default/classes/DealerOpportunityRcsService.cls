public without sharing class DealerOpportunityRcsService {
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

    public static SendRcsResult sendToOpportunities(
        List<Id> opportunityIds,
        String templateName
    ) {
        SendRcsResult result = new SendRcsResult();

        if (opportunityIds == null || opportunityIds.isEmpty()) {
            throw new AuraHandledException('Select at least one opportunity.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select an RCS template.');
        }

        BWM_Messaging_Settings__mdt settings = getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('RCS messaging is disabled or not configured.');
        }

        String normalizedTemplateName = templateName.trim();
        Map<Id, List<OpportunityContactRole>> contactRolesByOpportunityId =
            queryContactRolesByOpportunityId(opportunityIds);

        List<Opportunity> opportunities = [
            SELECT
                Id,
                Name,
                Department_Name__c,
                Product_Category__c,
                ContactId,
                OwnerId,
                Owner.Name,
                Owner.FirstName,
                Owner.LastName,
                Owner.Phone,
                Owner.MobilePhone,
                Owner.Email,
                Account.Name,
                Account.Phone
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        String successCode = String.isBlank(settings.RCS_Success_Code__c)
            ? (String.isBlank(settings.Journey_Success_Code__c)
                  ? '200'
                  : settings.Journey_Success_Code__c)
            : settings.RCS_Success_Code__c;

        for (Opportunity opportunityRecord : opportunities) {
            List<String> recipientPhones = collectContactRolePhones(
                contactRolesByOpportunityId.get(opportunityRecord.Id),
                settings
            );
            if (recipientPhones.isEmpty()) {
                result.skippedCount++;
                result.messages.add(
                    opportunityRecord.Name +
                        ': No valid phone number for RCS. WhatsApp may still be sent.'
                );
                continue;
            }

            for (String phoneNumber : recipientPhones) {
                String payload = BWM_RcsDirectPayloadBuilder.buildPayload(
                    settings,
                    normalizedTemplateName,
                    opportunityRecord,
                    phoneNumber
                );

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
                            opportunityRecord.Name +
                                ': ' +
                                (String.isNotBlank(apiResponse.message)
                                    ? apiResponse.message
                                    : 'RCS send failed.')
                        );
                    }
                } catch (Exception ex) {
                    result.skippedCount++;
                    result.messages.add(opportunityRecord.Name + ': ' + ex.getMessage());
                }
            }
        }

        return result;
    }

    private static Map<Id, List<OpportunityContactRole>> queryContactRolesByOpportunityId(
        List<Id> opportunityIds
    ) {
        Map<Id, List<OpportunityContactRole>> contactRolesByOpportunityId =
            new Map<Id, List<OpportunityContactRole>>();

        for (OpportunityContactRole contactRole : [
            SELECT
                OpportunityId,
                ContactId,
                IsPrimary,
                Contact.Phone,
                Contact.MobilePhone
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

    private static List<String> collectContactRolePhones(
        List<OpportunityContactRole> contactRoles,
        BWM_Messaging_Settings__mdt settings
    ) {
        List<String> recipientPhones = new List<String>();
        Set<String> uniquePhones = new Set<String>();

        if (contactRoles == null) {
            return recipientPhones;
        }

        for (OpportunityContactRole contactRole : contactRoles) {
            String rawPhone = resolveContactRolePhone(contactRole);
            if (String.isBlank(rawPhone)) {
                continue;
            }

            String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
                rawPhone,
                settings.Default_Country_Code__c
            );
            if (String.isBlank(formattedPhone)) {
                continue;
            }

            if (isSamePhoneNumber(formattedPhone, settings.RCS_From__c) ||
                isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c) ||
                isSamePhoneNumber(formattedPhone, '9830637280')) {
                continue;
            }

            String normalizedPhone = formattedPhone.replaceAll('[^0-9]', '');
            if (!uniquePhones.contains(normalizedPhone)) {
                uniquePhones.add(normalizedPhone);
                recipientPhones.add(formattedPhone);
            }
        }

        return recipientPhones;
    }

    private static String resolveContactRolePhone(OpportunityContactRole contactRole) {
        if (contactRole == null || contactRole.Contact == null) {
            return null;
        }

        if (String.isNotBlank(contactRole.Contact.MobilePhone)) {
            return contactRole.Contact.MobilePhone;
        }
        return contactRole.Contact.Phone;
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
            throw new AuraHandledException('RCS API settings are not configured.');
        }
        return settings;
    }

    private class TemplateNameComparator implements System.Comparator<RcsTemplateOption> {
        public Integer compare(RcsTemplateOption first, RcsTemplateOption second) {
            String firstName = first == null || first.label == null ? '' : first.label;
            String secondName = second == null || second.label == null ? '' : second.label;
            return firstName.toLowerCase().compareTo(secondName.toLowerCase());
        }
    }
}