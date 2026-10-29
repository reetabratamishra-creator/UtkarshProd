/**
 * @description   Test class for BWM_CampaignRecordSupport query and phone/email
 *                resolution helpers.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_CampaignRecordSupportTest {
  @TestSetup
  static void setupCommonData() {
    Account accountRecord = new Account(
      Name = 'Support Account',
      Phone = '9876543210',
      Email__c = 'support.account@example.com'
    );
    BWM_TestDml.insertSys(accountRecord);

    Contact contactRecord = new Contact(
      LastName = 'Support Contact',
      AccountId = accountRecord.Id,
      Phone = '9876543211',
      MobilePhone = '9876543212',
      Email = 'support.contact@example.com'
    );
    BWM_TestDml.insertSys(contactRecord);

    BWM_TestDml.insertSys(new Offline_Campaign__c(
      Name = 'Support Offline',
      Phone__c = '9876543213',
      Email__c = 'support.offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    ));
  }

  /**
   * Scenario: Messaging settings load successfully when CMDT is configured.
   */
  @IsTest
  static void testGetMessagingSettings_ReturnsConfiguredSettings() {
    Test.startTest();
    BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
    Test.stopTest();

    System.assertNotEquals(null, settings);
    System.assert(String.isNotBlank(settings.API_Bearer_Token__c));
  }

  /**
   * Scenario: Account/Contact/Offline queries return hydrated owner and contact fields.
   */
  @IsTest
  static void testQueryHelpers_ReturnMatchingRecords() {
    Account accountRecord = [SELECT Id FROM Account WHERE Name LIKE 'Support Account%' LIMIT 1];
    Contact contactRecord = [SELECT Id FROM Contact WHERE LastName LIKE 'Support Contact%' LIMIT 1];
    Offline_Campaign__c offlineRecord = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Support Offline%'
      LIMIT 1
    ];

    Test.startTest();
    List<Account> accounts = BWM_CampaignRecordSupport.queryAccountsByIds(
      new List<Id>{ accountRecord.Id }
    );
    List<Contact> contacts = BWM_CampaignRecordSupport.queryContactsByIds(
      new List<Id>{ contactRecord.Id }
    );
    List<Offline_Campaign__c> offlineCampaigns = BWM_CampaignRecordSupport.queryOfflineCampaignsByIds(
      new List<Id>{ offlineRecord.Id }
    );
    Test.stopTest();

    System.assertEquals(1, accounts.size());
    System.assertEquals(1, contacts.size());
    System.assertEquals(1, offlineCampaigns.size());
    System.assert(accounts[0].Name != null && accounts[0].Name.startsWith('Support Account'));
    System.assert(
      contacts[0].Email != null && contacts[0].Email.contains('support.contact'),
      contacts[0].Email
    );
  }

  /**
   * Scenario: Phone/email resolvers format valid values and skip blank ones.
   */
  @IsTest
  static void testResolvePhoneAndEmail_HappyPathAndBlankSkip() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Account accountRecord = [
      SELECT Id, Phone, Email__c
      FROM Account
      WHERE Name LIKE 'Support Account%'
      LIMIT 1
    ];
    Contact contactRecord = [
      SELECT Id, Phone, MobilePhone, Email
      FROM Contact
      WHERE LastName LIKE 'Support Contact%'
      LIMIT 1
    ];
    Offline_Campaign__c offlineRecord = [
      SELECT Id, Phone__c, Email__c
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Support Offline%'
      LIMIT 1
    ];
    Account blankAccount = new Account(Name = 'Blank Phone');
    Contact blankContact = new Contact(LastName = 'Blank Contact');
    Offline_Campaign__c blankOffline = new Offline_Campaign__c(Name = 'Blank Offline');

    Test.startTest();
    String accountPhone = BWM_CampaignRecordSupport.resolveAccountPhone(
      accountRecord,
      settings
    );
    String contactPhone = BWM_CampaignRecordSupport.resolveContactPhone(
      contactRecord,
      settings
    );
    String offlinePhone = BWM_CampaignRecordSupport.resolveOfflinePhone(
      offlineRecord,
      settings
    );
    String accountEmail = BWM_CampaignRecordSupport.resolveAccountEmail(accountRecord);
    String contactEmail = BWM_CampaignRecordSupport.resolveContactEmail(contactRecord);
    String offlineEmail = BWM_CampaignRecordSupport.resolveOfflineEmail(offlineRecord);
    String blankPhone = BWM_CampaignRecordSupport.resolveAccountPhone(blankAccount, settings);
    String blankEmail = BWM_CampaignRecordSupport.resolveContactEmail(blankContact);
    String blankOfflineEmail = BWM_CampaignRecordSupport.resolveOfflineEmail(blankOffline);
    Boolean samePhone = BWM_CampaignRecordSupport.isSamePhoneNumber(
      '919876543210',
      '+91 98765-43210'
    );
    Boolean blankCompare = BWM_CampaignRecordSupport.isSamePhoneNumber(null, '123');
    Test.stopTest();

    System.assert(String.isNotBlank(accountPhone));
    System.assert(String.isNotBlank(contactPhone), 'MobilePhone should be preferred.');
    System.assert(String.isNotBlank(offlinePhone));
    System.assert(accountEmail != null && accountEmail.contains('support.account'), accountEmail);
    System.assert(contactEmail != null && contactEmail.contains('support.contact'), contactEmail);
    System.assert(offlineEmail != null && offlineEmail.contains('support.offline'), offlineEmail);
    System.assertEquals(null, blankPhone);
    System.assertEquals(null, blankEmail);
    System.assertEquals(null, blankOfflineEmail);
    System.assertEquals(true, samePhone);
    System.assertEquals(false, blankCompare);
  }
}