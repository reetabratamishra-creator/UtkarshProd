/**
 * @description   Sends Bluewave Journey (WhatsApp+RCS+SMS) campaigns to Lead,
 *                Opportunity, Account, Contact, and Offline Campaign records.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_CampaignJourneyService {
  /**
   * @description Sends a Bluewave journey campaign to the selected Leads and aggregates send results.
   * @param leadIds Lead Ids to message.
   * @param journeyName Journey definition name to send.
   * @return SendJourneyResult with sent/skipped counts and messages.
   */
  public static BWM_JourneyDefinitionService.SendJourneyResult sendToLeads(
    List<Id> leadIds,
    String journeyName
  ) {
    return sendToLeads(leadIds, journeyName, null);
  }

  public static BWM_JourneyDefinitionService.SendJourneyResult sendToLeads(
    List<Id> leadIds,
    String journeyName,
    String scheduledDateTime
  ) {
    BWM_JourneyDefinitionService.SendJourneyResult result =
      new BWM_JourneyDefinitionService.SendJourneyResult();

    if (leadIds == null || leadIds.isEmpty()) {
      throw new AuraHandledException('Select at least one lead.');
    }
    if (String.isBlank(journeyName)) {
      throw new AuraHandledException('Select a journey.');
    }

    BWM_Messaging_Settings__mdt settings = getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      throw new AuraHandledException('Messaging is disabled or not configured.');
    }

    BWM_Journey_Definition__mdt definition =
      BWM_JourneyDefinitionService.getDefinitionByJourneyName(journeyName);
    if (definition == null) {
      throw new AuraHandledException('Journey not found: ' + journeyName);
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    String templateNameForLog = mapping != null &&
      String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : journeyName;

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
        Owner.Phone,
        CRM_User_Name_Formula__c,
        CRM_User_Contact_No_Formula__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id IN :leadIds
    ];

    sendToRecords(
      leads,
      journeyName,
      settings,
      templateNameForLog,
      BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN,
      result,
      scheduledDateTime
    );
    return result;
  }

  /**
   * @description Sends a Bluewave journey campaign to the selected Accounts and aggregates send results.
   * @param accountIds Account Ids to message.
   * @param journeyName Journey definition name to send.
   * @return SendJourneyResult with sent/skipped counts and messages.
   */
  public static BWM_JourneyDefinitionService.SendJourneyResult sendToAccounts(
    List<Id> accountIds,
    String journeyName
  ) {
    return sendToAccounts(accountIds, journeyName, null);
  }

  public static BWM_JourneyDefinitionService.SendJourneyResult sendToAccounts(
    List<Id> accountIds,
    String journeyName,
    String scheduledDateTime
  ) {
    BWM_JourneyDefinitionService.SendJourneyResult result =
      new BWM_JourneyDefinitionService.SendJourneyResult();
    validateJourneyRequest(accountIds, journeyName);

    BWM_Messaging_Settings__mdt settings = getSettings();
    BWM_Journey_Definition__mdt definition =
      BWM_JourneyDefinitionService.getDefinitionByJourneyName(journeyName);
    if (definition == null) {
      throw new AuraHandledException('Journey not found: ' + journeyName);
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    String templateNameForLog = mapping != null &&
      String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : journeyName;

    sendToRecords(
      BWM_CampaignRecordSupport.queryAccountsByIds(accountIds),
      journeyName,
      settings,
      templateNameForLog,
      BWM_MessagingConstants.TRIGGER_ACCOUNT_CAMPAIGN,
      result,
      scheduledDateTime
    );
    return result;
  }

  /**
   * @description Sends a Bluewave journey campaign to the selected Contacts and aggregates send results.
   * @param contactIds Contact Ids to message.
   * @param journeyName Journey definition name to send.
   * @return SendJourneyResult with sent/skipped counts and messages.
   */
  public static BWM_JourneyDefinitionService.SendJourneyResult sendToContacts(
    List<Id> contactIds,
    String journeyName
  ) {
    return sendToContacts(contactIds, journeyName, null);
  }

  public static BWM_JourneyDefinitionService.SendJourneyResult sendToContacts(
    List<Id> contactIds,
    String journeyName,
    String scheduledDateTime
  ) {
    BWM_JourneyDefinitionService.SendJourneyResult result =
      new BWM_JourneyDefinitionService.SendJourneyResult();
    validateJourneyRequest(contactIds, journeyName);

    BWM_Messaging_Settings__mdt settings = getSettings();
    BWM_Journey_Definition__mdt definition =
      BWM_JourneyDefinitionService.getDefinitionByJourneyName(journeyName);
    if (definition == null) {
      throw new AuraHandledException('Journey not found: ' + journeyName);
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    String templateNameForLog = mapping != null &&
      String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : journeyName;

    sendToRecords(
      BWM_CampaignRecordSupport.queryContactsByIds(contactIds),
      journeyName,
      settings,
      templateNameForLog,
      BWM_MessagingConstants.TRIGGER_CONTACT_CAMPAIGN,
      result,
      scheduledDateTime
    );
    return result;
  }

  /**
   * @description Sends a Bluewave journey campaign to Offline_Campaign__c records and aggregates send results.
   * @param offlineCampaignIds Offline_Campaign__c Ids to message.
   * @param journeyName Journey definition name to send.
   * @return SendJourneyResult with sent/skipped counts and messages.
   */
  public static BWM_JourneyDefinitionService.SendJourneyResult sendToOfflineCampaigns(
    List<Id> offlineCampaignIds,
    String journeyName
  ) {
    return sendToOfflineCampaigns(offlineCampaignIds, journeyName, null);
  }

  public static BWM_JourneyDefinitionService.SendJourneyResult sendToOfflineCampaigns(
    List<Id> offlineCampaignIds,
    String journeyName,
    String scheduledDateTime
  ) {
    BWM_JourneyDefinitionService.SendJourneyResult result =
      new BWM_JourneyDefinitionService.SendJourneyResult();
    validateJourneyRequest(offlineCampaignIds, journeyName);

    BWM_Messaging_Settings__mdt settings = getSettings();
    BWM_Journey_Definition__mdt definition =
      BWM_JourneyDefinitionService.getDefinitionByJourneyName(journeyName);
    if (definition == null) {
      throw new AuraHandledException('Journey not found: ' + journeyName);
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    String templateNameForLog = mapping != null &&
      String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : journeyName;

    sendToRecords(
      BWM_CampaignRecordSupport.queryOfflineCampaignsByIds(offlineCampaignIds),
      journeyName,
      settings,
      templateNameForLog,
      BWM_MessagingConstants.TRIGGER_OFFLINE_CAMPAIGN,
      result,
      scheduledDateTime
    );
    return result;
  }

  /**
   * @description Validates that at least one record Id and a journey name were provided.
   * @param recordIds Target record Ids for the campaign send.
   * @param journeyName Journey definition name selected in the UI.
   */
  private static void validateJourneyRequest(List<Id> recordIds, String journeyName) {
    if (recordIds == null || recordIds.isEmpty()) {
      throw new AuraHandledException('Select at least one record.');
    }
    if (String.isBlank(journeyName)) {
      throw new AuraHandledException('Select a journey.');
    }
  }

  /**
   * @description Sends a Bluewave journey campaign to Opportunities using primary-contact phones when available.
   * @param opportunityIds Opportunity Ids to message.
   * @param journeyName Journey definition name to send.
   * @return SendJourneyResult with sent/skipped counts and messages.
   */
  public static BWM_JourneyDefinitionService.SendJourneyResult sendToOpportunities(
    List<Id> opportunityIds,
    String journeyName
  ) {
    return sendToOpportunities(opportunityIds, journeyName, null);
  }

  public static BWM_JourneyDefinitionService.SendJourneyResult sendToOpportunities(
    List<Id> opportunityIds,
    String journeyName,
    String scheduledDateTime
  ) {
    BWM_JourneyDefinitionService.SendJourneyResult result =
      new BWM_JourneyDefinitionService.SendJourneyResult();

    if (opportunityIds == null || opportunityIds.isEmpty()) {
      throw new AuraHandledException('Select at least one opportunity.');
    }
    if (String.isBlank(journeyName)) {
      throw new AuraHandledException('Select a journey.');
    }

    BWM_Messaging_Settings__mdt settings = getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      throw new AuraHandledException('Messaging is disabled or not configured.');
    }

    BWM_Journey_Definition__mdt definition =
      BWM_JourneyDefinitionService.getDefinitionByJourneyName(journeyName);
    if (definition == null) {
      throw new AuraHandledException('Journey not found: ' + journeyName);
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    String templateNameForLog = mapping != null &&
      String.isNotBlank(mapping.WhatsApp_Template_Name__c)
      ? mapping.WhatsApp_Template_Name__c
      : journeyName;

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
        CRM_User_Name_Formula__c,
        CRM_User_Contact_No_Formula__c,
        CRM_User_Email_Formula__c,
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

    Map<Id, String> primaryContactPhoneByOpportunityId =
      queryPrimaryContactPhonesByOpportunityId(opportunityIds);

    sendToOpportunityRecords(
      opportunities,
      primaryContactPhoneByOpportunityId,
      journeyName,
      settings,
      templateNameForLog,
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_CAMPAIGN,
      result,
      scheduledDateTime
    );
    return result;
  }

  /**
   * @description Sends journey payloads for generic campaign records, updates the result, and inserts Message_Log__c rows.
   * @param records Lead/Account/Contact/Offline_Campaign__c records to message.
   * @param journeyName Journey definition name used in the payload.
   * @param settings Active messaging settings metadata.
   * @param templateNameForLog Template/journey name written to Message_Log__c.
   * @param triggerPoint Campaign trigger key for logging.
   * @param result Mutable SendJourneyResult accumulating counts and messages.
   */
  private static void sendToRecords(
    List<SObject> records,
    String journeyName,
    BWM_Messaging_Settings__mdt settings,
    String templateNameForLog,
    String triggerPoint,
    BWM_JourneyDefinitionService.SendJourneyResult result,
    String scheduledDateTime
  ) {
    String successCode = String.isBlank(settings.Journey_Success_Code__c)
      ? '200'
      : settings.Journey_Success_Code__c;
    List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

    for (SObject record : records) {
      String recordName = String.valueOf(record.get('Name'));
      String phoneNumber = resolveRecordPhone(record, settings);
      if (String.isBlank(phoneNumber)) {
        result.skippedCount++;
        result.messages.add(recordName + ': No valid mobile number on the record.');
        continue;
      }

      if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
        result.skippedCount++;
        result.messages.add(
          recordName + ': Callout limit reached. Send fewer records or try again.'
        );
        continue;
      }

      try {
        String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
          settings,
          record,
          journeyName,
          phoneNumber,
          true,
          scheduledDateTime
        );
        String requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);
        BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(
          BWM_MessagingCallout.send(payload),
          successCode
        );
        logsToInsert.add(
          BWM_MessageLogService.buildLogForRecord(
            record,
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
          result.messages.add(recordName + ': ' + String.valueOf(apiResponse.message));
        }
      } catch (Exception ex) {
        result.skippedCount++;
        result.messages.add(recordName + ': ' + ex.getMessage());
      }
    }

    if (!logsToInsert.isEmpty()) {
      BWM_MessageLogService.insertLogs(logsToInsert);
    }
  }

  /**
   * @description Resolves a formatted phone for Lead, Account, Contact, or Offline_Campaign__c campaign sends.
   * @param record SObject being messaged.
   * @param settings Messaging settings used for formatting.
   * @return Formatted phone number, or null when unsupported/blank.
   */
  private static String resolveRecordPhone(
    SObject record,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (record instanceof Lead) {
      return resolveLeadPhone((Lead) record, settings);
    }
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

  /**
   * @description Sends journey payloads for Opportunities, updates the result, and inserts Message_Log__c rows.
   * @param opportunities Opportunity records to message.
   * @param primaryContactPhoneByOpportunityId Map of Opportunity Id to primary contact phone.
   * @param journeyName Journey definition name used in the payload.
   * @param settings Active messaging settings metadata.
   * @param templateNameForLog Template/journey name written to Message_Log__c.
   * @param triggerPoint Campaign trigger key for logging.
   * @param result Mutable SendJourneyResult accumulating counts and messages.
   */
  private static void sendToOpportunityRecords(
    List<Opportunity> opportunities,
    Map<Id, String> primaryContactPhoneByOpportunityId,
    String journeyName,
    BWM_Messaging_Settings__mdt settings,
    String templateNameForLog,
    String triggerPoint,
    BWM_JourneyDefinitionService.SendJourneyResult result,
    String scheduledDateTime
  ) {
    String successCode = String.isBlank(settings.Journey_Success_Code__c)
      ? '200'
      : settings.Journey_Success_Code__c;
    List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

    for (Opportunity opportunityRecord : opportunities) {
      String phoneNumber = resolveOpportunityPhone(
        opportunityRecord,
        primaryContactPhoneByOpportunityId,
        settings
      );
      if (String.isBlank(phoneNumber)) {
        result.skippedCount++;
        result.messages.add(
          opportunityRecord.Name +
            ': No valid mobile number on the primary contact role.'
        );
        continue;
      }

      if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
        result.skippedCount++;
        result.messages.add(
          opportunityRecord.Name +
            ': Callout limit reached. Send fewer records or try again.'
        );
        continue;
      }

      try {
        String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
          settings,
          opportunityRecord,
          journeyName,
          phoneNumber,
          true,
          scheduledDateTime
        );
        String requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);
        BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(
          BWM_MessagingCallout.send(payload),
          successCode
        );
        logsToInsert.add(
          BWM_MessageLogService.buildLogForRecord(
            opportunityRecord,
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
            opportunityRecord.Name + ': ' + String.valueOf(apiResponse.message)
          );
        }
      } catch (Exception ex) {
        result.skippedCount++;
        result.messages.add(opportunityRecord.Name + ': ' + ex.getMessage());
      }
    }

    if (!logsToInsert.isEmpty()) {
      BWM_MessageLogService.insertLogs(logsToInsert);
    }
  }

  /**
   * @description Queries primary OpportunityContactRole phones keyed by Opportunity Id.
   * @param opportunityIds Opportunity Ids to load primary contact phones for.
   * @return Map of Opportunity Id to raw phone string.
   */
  private static Map<Id, String> queryPrimaryContactPhonesByOpportunityId(
    List<Id> opportunityIds
  ) {
    Map<Id, String> phoneByOpportunityId = new Map<Id, String>();
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return phoneByOpportunityId;
    }

    for (OpportunityContactRole contactRole : [
      SELECT OpportunityId, Contact.Phone, Contact.MobilePhone
      FROM OpportunityContactRole
      WHERE OpportunityId IN :opportunityIds AND IsPrimary = TRUE
    ]) {
      String phone = contactRole.Contact == null
        ? null
        : contactRole.Contact.Phone;
      if (String.isBlank(phone) && contactRole.Contact != null) {
        phone = contactRole.Contact.MobilePhone;
      }
      if (String.isNotBlank(phone)) {
        phoneByOpportunityId.put(contactRole.OpportunityId, phone);
      }
    }
    return phoneByOpportunityId;
  }

  /**
   * @description Formats Lead.Phone for messaging and suppresses numbers matching WhatsApp_From__c.
   * @param leadRecord Lead whose phone is resolved.
   * @param settings Messaging settings for country code and from-number checks.
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
   * @description Resolves Opportunity phone from primary contact, Phone__c, or related Lead phone.
   * @param opportunityRecord Opportunity being messaged.
   * @param primaryContactPhoneByOpportunityId Map of Opportunity Id to primary contact phone.
   * @param settings Messaging settings for country code and from-number checks.
   * @return Formatted phone, or null when blank/matching from number.
   */
  private static String resolveOpportunityPhone(
    Opportunity opportunityRecord,
    Map<Id, String> primaryContactPhoneByOpportunityId,
    BWM_Messaging_Settings__mdt settings
  ) {
    String rawPhone = primaryContactPhoneByOpportunityId.get(opportunityRecord.Id);
    if (String.isBlank(rawPhone)) {
      rawPhone = opportunityRecord.Phone__c;
    }
    if (String.isBlank(rawPhone)) {
      rawPhone = BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        'Lead__r.Phone'
      );
    }

    String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
      rawPhone,
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
   * @description Loads messaging settings and requires a configured API bearer token.
   * @return Active BWM_Messaging_Settings__mdt row.
   */
  private static BWM_Messaging_Settings__mdt getSettings() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || String.isBlank(settings.API_Bearer_Token__c)) {
      throw new AuraHandledException('Messaging API settings are not configured.');
    }
    return settings;
  }
}