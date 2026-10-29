public with sharing class BWM_EmailSettingsService {
  private static BWM_Email_Settings__mdt cachedSettings;

  public static BWM_Email_Settings__mdt getSettings() {
    if (cachedSettings == null) {
      List<BWM_Email_Settings__mdt> rows = [
        SELECT
          Is_Enabled__c,
          Endpoint_Path__c,
          API_App_Key__c,
          Central_Sender_Email__c,
          API_Key_Header__c,
          Corporate_Brochure_Static_Resource__c,
          Corporate_Brochure_File_Title__c,
          Corporate_Brochure_Public_Url__c
        FROM BWM_Email_Settings__mdt
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