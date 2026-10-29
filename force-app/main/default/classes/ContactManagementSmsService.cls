public with sharing class ContactManagementSmsService {
    public class SendSmsResult {
        @AuraEnabled public Integer sentCount = 0;
        @AuraEnabled public Integer skippedCount = 0;
        @AuraEnabled public List<String> messages = new List<String>();
    }

    public static SendSmsResult sendToContacts(List<Id> contactIds, String templateName) {
        SendSmsResult result = new SendSmsResult();
        if (contactIds == null || contactIds.isEmpty()) {
            throw new AuraHandledException('Select at least one contact.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select an SMS template.');
        }
        BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
        String normalizedTemplateName = templateName.trim();
        List<Contact> contacts = BWM_CampaignRecordSupport.queryContactsByIds(contactIds);
        String successCode = String.isBlank(settings.Journey_Success_Code__c) ? '200' : settings.Journey_Success_Code__c;
        for (Contact contactRecord : contacts) {
            String phoneNumber = BWM_CampaignRecordSupport.resolveContactPhone(contactRecord, settings);
            if (String.isBlank(phoneNumber)) {
                result.skippedCount++;
                result.messages.add(contactRecord.Name + ': No valid phone number on the contact.');
                continue;
            }
            try {
                String payload = BWM_SmsDirectPayloadBuilder.buildPayload(settings, normalizedTemplateName, contactRecord, phoneNumber);
                BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(BWM_MessagingCallout.send(payload), successCode);
                if (apiResponse.isSuccess) result.sentCount++;
                else {
                    result.skippedCount++;
                    result.messages.add(contactRecord.Name + ': ' + (String.isNotBlank(apiResponse.message) ? apiResponse.message : 'SMS send failed.'));
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(contactRecord.Name + ': ' + ex.getMessage());
            }
        }
        return result;
    }
}