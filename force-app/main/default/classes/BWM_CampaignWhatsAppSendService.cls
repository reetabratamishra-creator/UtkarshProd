public without sharing class BWM_CampaignWhatsAppSendService {
  public static LeadManagementWhatsAppService.SendWhatsAppResult sendToRecords(
    List<SObject> records,
    String templateName,
    String triggerPoint,
    String objectType
  ) {
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      new LeadManagementWhatsAppService.SendWhatsAppResult();

    if (records == null || records.isEmpty()) {
      throw new AuraHandledException('Select at least one record.');
    }
    if (String.isBlank(templateName)) {
      throw new AuraHandledException('Select a WhatsApp template.');
    }

    BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
    if (settings.Is_Enabled__c != true) {
      throw new AuraHandledException('WhatsApp messaging is disabled or not configured.');
    }

    String normalizedTemplateName = templateName.trim();
    String successCode = String.isBlank(settings.Journey_Success_Code__c)
      ? '200'
      : settings.Journey_Success_Code__c;
    List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

    for (SObject record : records) {
      String recordName = String.valueOf(record.get('Name'));
      String phoneNumber = resolvePhone(record, settings);
      if (String.isBlank(phoneNumber)) {
        result.skippedCount++;
        result.messages.add(recordName + ': No valid mobile number on the record.');
        continue;
      }

      String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
        settings,
        record,
        normalizedTemplateName,
        phoneNumber,
        true
      );
      String requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);

      try {
        BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(
          BWM_MessagingCallout.send(payload),
          successCode
        );
        logsToInsert.add(
          BWM_MessageLogService.buildLogForRecord(
            record,
            triggerPoint,
            BWM_MessagingConstants.LOG_CHANNEL_JOURNEY,
            normalizedTemplateName,
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
      }
    }

    if (!logsToInsert.isEmpty()) {
      BWM_MessageLogService.insertLogs(logsToInsert);
    }

    return result;
  }

  private static String resolvePhone(
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
}