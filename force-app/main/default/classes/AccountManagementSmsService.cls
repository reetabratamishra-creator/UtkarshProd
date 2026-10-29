public with sharing class AccountManagementSmsService {
    public class SendSmsResult {
        @AuraEnabled public Integer sentCount = 0;
        @AuraEnabled public Integer skippedCount = 0;
        @AuraEnabled public List<String> messages = new List<String>();
    }

    public static SendSmsResult sendToAccounts(List<Id> accountIds, String templateName) {
        SendSmsResult result = new SendSmsResult();
        if (accountIds == null || accountIds.isEmpty()) {
            throw new AuraHandledException('Select at least one account.');
        }
        if (String.isBlank(templateName)) {
            throw new AuraHandledException('Select an SMS template.');
        }
        BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
        String normalizedTemplateName = templateName.trim();
        List<Account> accounts = BWM_CampaignRecordSupport.queryAccountsByIds(accountIds);
        String successCode = String.isBlank(settings.Journey_Success_Code__c) ? '200' : settings.Journey_Success_Code__c;
        for (Account accountRecord : accounts) {
            String phoneNumber = BWM_CampaignRecordSupport.resolveAccountPhone(accountRecord, settings);
            if (String.isBlank(phoneNumber)) {
                result.skippedCount++;
                result.messages.add(accountRecord.Name + ': No valid phone number on the account.');
                continue;
            }
            try {
                String payload = BWM_SmsDirectPayloadBuilder.buildPayload(settings, normalizedTemplateName, accountRecord, phoneNumber);
                BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(BWM_MessagingCallout.send(payload), successCode);
                if (apiResponse.isSuccess) result.sentCount++;
                else {
                    result.skippedCount++;
                    result.messages.add(accountRecord.Name + ': ' + (String.isNotBlank(apiResponse.message) ? apiResponse.message : 'SMS send failed.'));
                }
            } catch (Exception ex) {
                result.skippedCount++;
                result.messages.add(accountRecord.Name + ': ' + ex.getMessage());
            }
        }
        return result;
    }
}