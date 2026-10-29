public without sharing class BWM_MessagingService {
  public class SendResult {
    public Boolean sent = false;
    public String channelUsed;
    public String skipReason;
    public List<Message_Log__c> logs = new List<Message_Log__c>();
  }

  public static SendResult sendForLeadCreate(Id leadId) {
    SendResult result = new SendResult();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    if (settings == null || settings.Is_Enabled__c != true) {
      result.skipReason = 'Messaging is disabled or settings are missing.';
      return result;
    }

    Lead leadRecord = BWM_RecordQueryService.queryLead(leadId);
    BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );

    if (!resolveResult.shouldSend) {
      result.skipReason = resolveResult.skipReason;
      return result;
    }

    return sendMessage(
      settings,
      leadRecord,
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE,
      resolveResult.mapping,
      resolvePhoneForRecord(leadRecord, resolveResult.mapping)
    );
  }

  public static SendResult send(Id recordId, String triggerPoint) {
    return send(recordId, triggerPoint, null);
  }

  public static SendResult send(
    Id recordId,
    String triggerPoint,
    String stageAtAction
  ) {
    SendResult result = new SendResult();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    if (settings == null || settings.Is_Enabled__c != true) {
      result.skipReason = 'Messaging is disabled or settings are missing.';
      return result;
    }

    if (recordId == null || String.isBlank(triggerPoint)) {
      result.skipReason = 'Record Id and trigger point are required.';
      return result;
    }

    SObject record = queryRecord(recordId);
    BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolve(
      triggerPoint,
      record,
      stageAtAction
    );

    if (!resolveResult.shouldSend) {
      result.skipReason = resolveResult.skipReason;
      return result;
    }

    return sendMessage(
      settings,
      record,
      triggerPoint,
      resolveResult.mapping,
      resolvePhoneForRecord(record, resolveResult.mapping)
    );
  }

  private static SObject queryRecord(Id recordId) {
    String objectName = recordId.getSObjectType().getDescribe().getName();

    if (objectName == BWM_MessagingConstants.OBJECT_TYPE_LEAD) {
      return BWM_RecordQueryService.queryLead(recordId);
    }

    if (objectName == BWM_MessagingConstants.OBJECT_TYPE_OPPORTUNITY) {
      return BWM_RecordQueryService.queryOpportunity(recordId);
    }

    throw new BWM_MessagingException(
      'Unsupported object type for messaging: ' + objectName
    );
  }

  private static String resolvePhoneForRecord(
    SObject record,
    BWM_Template_Mapping__mdt mapping
  ) {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    String rawPhone;

    if (
      mapping != null &&
      mapping.Recipient_Type__c == BWM_MessagingConstants.RECIPIENT_DEALER &&
      record instanceof Opportunity
    ) {
      Opportunity opportunityRecord = (Opportunity) record;
      rawPhone = opportunityRecord.DealerAccount__r != null
        ? opportunityRecord.DealerAccount__r.Phone
        : null;
      if (String.isBlank(rawPhone)) {
        rawPhone = opportunityRecord.Account != null
          ? opportunityRecord.Account.Phone
          : null;
      }
    } else if (
      mapping != null &&
      mapping.Recipient_Type__c == BWM_MessagingConstants.RECIPIENT_OWNER &&
      record instanceof Opportunity
    ) {
      rawPhone = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Phone');
    } else if (record instanceof Lead) {
      rawPhone = ((Lead) record).Phone;
    } else if (record instanceof Opportunity) {
      Opportunity opportunityRecord = (Opportunity) record;
      rawPhone = resolveCustomerPhoneForOpportunity(opportunityRecord);
    }

    String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
      rawPhone,
      settings.Default_Country_Code__c
    );

    if (isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c)) {
      return null;
    }

    return formattedPhone;
  }

  private static String resolveCustomerPhoneForOpportunity(
    Opportunity opportunityRecord
  ) {
    String leadPhone = opportunityRecord.Lead__r != null
      ? opportunityRecord.Lead__r.Phone
      : null;
    if (String.isNotBlank(leadPhone)) {
      return leadPhone;
    }

    if (opportunityRecord.Lead__c == null) {
      leadPhone = queryConvertedLeadPhone(opportunityRecord.Id);
      if (String.isNotBlank(leadPhone)) {
        return leadPhone;
      }
    }

    if (String.isNotBlank(opportunityRecord.Phone__c)) {
      return opportunityRecord.Phone__c;
    }

    return opportunityRecord.Account != null
      ? opportunityRecord.Account.Phone
      : null;
  }

  private static String queryConvertedLeadPhone(Id opportunityId) {
    List<Lead> convertedLeads = [
      SELECT Phone
      FROM Lead
      WHERE ConvertedOpportunityId = :opportunityId AND IsConverted = TRUE
      ORDER BY ConvertedDate DESC
      LIMIT 1
    ];
    return convertedLeads.isEmpty() ? null : convertedLeads[0].Phone;
  }

  private static Boolean isSamePhoneNumber(String phoneA, String phoneB) {
    if (String.isBlank(phoneA) || String.isBlank(phoneB)) {
      return false;
    }

    return phoneA.replaceAll('[^0-9]', '') == phoneB.replaceAll('[^0-9]', '');
  }

  private static SendResult sendMessage(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    String triggerPoint,
    BWM_Template_Mapping__mdt mapping,
    String phoneNumber
  ) {
    SendResult result = new SendResult();
    String templateNameForLog = resolveTemplateNameForLog(mapping);

    if (String.isBlank(phoneNumber)) {
      result.skipReason = 'Record does not have a valid phone number.';
      Message_Log__c skippedLog = BWM_MessageLogService.buildLogForRecord(
        record,
        triggerPoint,
        null,
        templateNameForLog,
        null,
        BWM_MessagingConstants.LOG_STATUS_SKIPPED,
        null
      );
      skippedLog.Response_Message__c = result.skipReason;
      result.logs.add(skippedLog);
      return result;
    }

    if (String.isBlank(mapping.Journey_Name__c)) {
      result.skipReason = 'Journey name is not configured for this template mapping.';
      return result;
    }

    String journeyPayload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      record,
      phoneNumber,
      shouldIncludeDocumentFileName(triggerPoint)
    );
    String journeyCurl = BWM_MessagingCallout.buildRequestCurl(journeyPayload);
    String successCode = String.isBlank(settings.Journey_Success_Code__c)
      ? settings.WhatsApp_Success_Code__c
      : settings.Journey_Success_Code__c;

    BWM_ApiResponse journeyResponse;
    try {
      journeyResponse = BWM_ApiResponse.parse(
        BWM_MessagingCallout.send(journeyPayload),
        successCode
      );
    } catch (Exception ex) {
      journeyResponse = new BWM_ApiResponse();
      journeyResponse.message = ex.getMessage();
      journeyResponse.httpStatus = 0;
    }

    result.logs.add(
      BWM_MessageLogService.buildLogForRecord(
        record,
        triggerPoint,
        BWM_MessagingConstants.LOG_CHANNEL_JOURNEY,
        templateNameForLog,
        phoneNumber,
        journeyResponse.isSuccess
          ? BWM_MessagingConstants.LOG_STATUS_SENT
          : BWM_MessagingConstants.LOG_STATUS_FAILED,
        journeyResponse,
        journeyCurl,
        journeyPayload
      )
    );

    result.sent = journeyResponse.isSuccess;
    result.channelUsed = journeyResponse.isSuccess
      ? BWM_MessagingConstants.LOG_CHANNEL_JOURNEY
      : null;
    if (!result.sent) {
      result.skipReason = 'Journey message failed.';
    }
    return result;
  }

  private static Boolean shouldIncludeDocumentFileName(String triggerPoint) {
    return triggerPoint !=
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER &&
      triggerPoint !=
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS;
  }

  private static String resolveTemplateNameForLog(BWM_Template_Mapping__mdt mapping) {
    if (mapping == null) {
      return null;
    }
    return String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : mapping.Journey_Name__c;
  }
}