public with sharing class OfflineCampaignManagementRcsService {
  public class SendRcsResult {
    @AuraEnabled
    public Integer sentCount = 0;
    @AuraEnabled
    public Integer skippedCount = 0;
    @AuraEnabled
    public List<String> messages = new List<String>();
  }

  public static SendRcsResult sendToOfflineCampaigns(
    List<Id> offlineCampaignIds,
    String templateName
  ) {
    SendRcsResult result = new SendRcsResult();
    if (offlineCampaignIds == null || offlineCampaignIds.isEmpty()) {
      throw new AuraHandledException('Select at least one offline campaign record.');
    }
    if (String.isBlank(templateName)) {
      throw new AuraHandledException('Select an RCS template.');
    }

    BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
    String normalizedTemplateName = templateName.trim();
    List<Offline_Campaign__c> offlineCampaigns = BWM_CampaignRecordSupport.queryOfflineCampaignsByIds(
      offlineCampaignIds
    );
    String successCode = String.isBlank(settings.RCS_Success_Code__c)
      ? (String.isBlank(settings.Journey_Success_Code__c)
          ? '200'
          : settings.Journey_Success_Code__c)
      : settings.RCS_Success_Code__c;

    for (Offline_Campaign__c offlineCampaignRecord : offlineCampaigns) {
      String phoneNumber = BWM_CampaignRecordSupport.resolveOfflinePhone(
        offlineCampaignRecord,
        settings
      );
      if (String.isBlank(phoneNumber)) {
        result.skippedCount++;
        result.messages.add(
          offlineCampaignRecord.Name + ': No valid phone number for RCS.'
        );
        continue;
      }

      try {
        String payload = BWM_RcsDirectPayloadBuilder.buildPayload(
          settings,
          normalizedTemplateName,
          offlineCampaignRecord,
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
            offlineCampaignRecord.Name +
              ': ' +
              (String.isNotBlank(apiResponse.message)
                ? apiResponse.message
                : 'RCS send failed.')
          );
        }
      } catch (Exception ex) {
        result.skippedCount++;
        result.messages.add(offlineCampaignRecord.Name + ': ' + ex.getMessage());
      }
    }

    return result;
  }
}