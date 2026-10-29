public with sharing class BWM_SettingsService {
  private static BWM_Messaging_Settings__mdt cachedSettings;

  public static BWM_Messaging_Settings__mdt getSettings() {
    if (cachedSettings == null) {
      List<BWM_Messaging_Settings__mdt> rows = [
        SELECT
          Is_Enabled__c,
          Endpoint_Path__c,
          WhatsApp_From__c,
          RCS_From__c,
          SMS_From__c,
          WhatsApp_Success_Code__c,
          RCS_Success_Code__c,
          SMS_Success_Code__c,
          Default_Country_Code__c,
          API_Key_Header__c,
          API_Bearer_Token__c,
          Default_WhatsApp_Document_Id__c,
          Default_Brochure_Static_Resource__c,
          Corporate_Brochure_File_Title__c,
          Default_Brochure_Portal_URL__c,
          Corporate_Support_Contact_1_Phone__c,
          Corporate_Support_Contact_2_Phone__c,
          Journey_Success_Code__c,
          Webhook_Callback_URL__c
        FROM BWM_Messaging_Settings__mdt
        WHERE DeveloperName = 'Default'
        LIMIT 1
      ];
      cachedSettings = rows.isEmpty() ? null : rows[0];
    }
    return cachedSettings;
  }

  @TestVisible
  static void clearCache() {
    cachedSettings = null;
  }
}