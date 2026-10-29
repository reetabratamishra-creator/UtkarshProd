/**
 * @description   Shared settings and SOQL helpers used by campaign management object
 *                services.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_CampaignRecordSupport {
  public static BWM_Messaging_Settings__mdt getMessagingSettings() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || String.isBlank(settings.API_Bearer_Token__c)) {
      throw new AuraHandledException('Messaging API settings are not configured.');
    }
    return settings;
  }

  public static List<Account> queryAccountsByIds(List<Id> accountIds) {
    return [
      SELECT
        Id,
        Name,
        Phone,
        Email__c,
        OwnerId,
        Owner.Name,
        Owner.FirstName,
        Owner.LastName,
        Owner.Email,
        Owner.Phone,
        CreatedDate
      FROM Account
      WHERE Id IN :accountIds
    ];
  }

  public static List<Contact> queryContactsByIds(List<Id> contactIds) {
    return [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        Email,
        Phone,
        MobilePhone,
        AccountId,
        Account.Name,
        OwnerId,
        Owner.Name,
        Owner.FirstName,
        Owner.LastName,
        Owner.Email,
        Owner.Phone,
        CreatedDate
      FROM Contact
      WHERE Id IN :contactIds
    ];
  }

  public static List<Offline_Campaign__c> queryOfflineCampaignsByIds(
    List<Id> offlineCampaignIds
  ) {
    return [
      SELECT
        Id,
        Name,
        Phone__c,
        Email__c,
        Department__c,
        Active__c,
        OwnerId,
        Owner.Name,
        Owner.FirstName,
        Owner.LastName,
        Owner.Email,
        Owner.Phone,
        CreatedDate
      FROM Offline_Campaign__c
      WHERE Id IN :offlineCampaignIds
    ];
  }

  public static String resolveAccountPhone(
    Account accountRecord,
    BWM_Messaging_Settings__mdt settings
  ) {
    return formatAndValidatePhone(accountRecord.Phone, settings);
  }

  public static String resolveContactPhone(
    Contact contactRecord,
    BWM_Messaging_Settings__mdt settings
  ) {
    String rawPhone = String.isNotBlank(contactRecord.MobilePhone)
      ? contactRecord.MobilePhone
      : contactRecord.Phone;
    return formatAndValidatePhone(rawPhone, settings);
  }

  public static String resolveAccountEmail(Account accountRecord) {
    return accountRecord == null || String.isBlank(accountRecord.Email__c)
      ? null
      : accountRecord.Email__c.trim();
  }

  public static String resolveContactEmail(Contact contactRecord) {
    return contactRecord == null || String.isBlank(contactRecord.Email)
      ? null
      : contactRecord.Email.trim();
  }

  public static String resolveOfflinePhone(
    Offline_Campaign__c offlineCampaignRecord,
    BWM_Messaging_Settings__mdt settings
  ) {
    return formatAndValidatePhone(offlineCampaignRecord.Phone__c, settings);
  }

  public static String resolveOfflineEmail(Offline_Campaign__c offlineCampaignRecord) {
    return offlineCampaignRecord == null || String.isBlank(offlineCampaignRecord.Email__c)
      ? null
      : offlineCampaignRecord.Email__c.trim();
  }

  public static String formatAndValidatePhone(
    String rawPhone,
    BWM_Messaging_Settings__mdt settings
  ) {
    String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
      rawPhone,
      settings == null ? null : settings.Default_Country_Code__c
    );
    if (String.isBlank(formattedPhone)) {
      return null;
    }
    if (
      settings != null &&
      (isSamePhoneNumber(formattedPhone, settings.WhatsApp_From__c) ||
      isSamePhoneNumber(formattedPhone, settings.RCS_From__c) ||
      isSamePhoneNumber(formattedPhone, '9830637280'))
    ) {
      return null;
    }
    return formattedPhone;
  }

  public static Boolean isSamePhoneNumber(String phoneA, String phoneB) {
    if (String.isBlank(phoneA) || String.isBlank(phoneB)) {
      return false;
    }
    return phoneA.replaceAll('[^0-9]', '') == phoneB.replaceAll('[^0-9]', '');
  }
}