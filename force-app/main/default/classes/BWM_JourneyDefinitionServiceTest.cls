/**
 * @description   Test class for BWM_JourneyDefinitionService — journey definition and
 *                alias resolution scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_JourneyDefinitionServiceTest {
  @IsTest
  static void fetchActiveJourneysReturnsOptions() {
    BWM_JourneyDefinitionService.clearCache();
    Test.startTest();
    List<BWM_JourneyDefinitionService.JourneyOption> options =
      BWM_JourneyDefinitionService.fetchActiveJourneys();
    Test.stopTest();
    System.assertNotEquals(null, options);
  }

  @IsTest
  static void buildPayloadUsesStoredDefinitionWhenNoMapping() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = new Lead(
      LastName = 'Journey Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Status = 'Prospect'
    );
    insert as system leadRecord;
    leadRecord = [
      SELECT Id, Name, Phone, Company, Department_Name__c, Owner.Name, Owner.Phone, Owner.Email
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    Test.startTest();
    String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
      settings,
      leadRecord,
      'cb_PT_250626',
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
    System.assert(payload.contains('"journeyname":"cb_PT_250626"'));
  }

  @IsTest
  static void buildPayloadResolvesWhatsAppTemplateAliasToJourney() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Contact contactRecord = new Contact(
      LastName = 'Campaign Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system contactRecord;
    contactRecord = [
      SELECT Id, Name, Phone, Email, Owner.Name, Owner.Phone, Owner.Email
      FROM Contact
      WHERE Id = :contactRecord.Id
    ];

    Test.startTest();
    String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
      settings,
      contactRecord,
      'u_dealer_enq_dept',
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
    System.assert(payload.contains('dealer_Enq_dept'));
  }

  @IsTest
  static void findJourneyNameByWhatsAppTemplateNameResolvesAlias() {
    BWM_JourneyDefinitionService.clearCache();

    Test.startTest();
    String journeyName = BWM_JourneyDefinitionService.findJourneyNameByWhatsAppTemplateName(
      'u_dealer_enq_dept'
    );
    BWM_Template_Mapping__mdt mapping = BWM_JourneyDefinitionService.findMappingByWhatsAppTemplateName(
      'u_dealer_enq_dept'
    );
    BWM_Journey_Definition__mdt definition = BWM_JourneyDefinitionService.getDefinitionByJourneyName(
      journeyName
    );
    Test.stopTest();

    System.assertNotEquals(null, journeyName);
    System.assertEquals('dealer_enq_dept', journeyName.toLowerCase());
    if (mapping != null && String.isNotBlank(mapping.Journey_Name__c)) {
      System.assertEquals('dealer_enq_dept', mapping.Journey_Name__c.toLowerCase());
    }
    System.assertNotEquals(null, definition);
  }

  @IsTest
  static void getJourneyNodeDataTemplateReturnsWhatsAppNode() {
    BWM_JourneyDefinitionService.clearCache();
    String journeyName = BWM_JourneyDefinitionService.findJourneyNameByWhatsAppTemplateName(
      'u_dealer_enq_dept'
    );

    Test.startTest();
    Map<String, Object> nodeData = BWM_JourneyDefinitionService.getJourneyNodeDataTemplate(
      journeyName,
      'WHATSAPP'
    );
    Map<String, Object> smsMappings = BWM_JourneyDefinitionService.getSmsVariableMappingsTemplate(
      journeyName
    );
    Map<String, Object> rcsBody = BWM_JourneyDefinitionService.getRcsBodyDataTemplate(
      journeyName
    );
    Test.stopTest();

    System.assertEquals('dealer_enq_dept', String.valueOf(nodeData.get('templateName')).toLowerCase());
    System.assertNotEquals(null, smsMappings);
    System.assertNotEquals(null, rcsBody);
  }

  @IsTest
  static void buildPayloadResolvesCampaignJourneyVariablesFromTemplateMapping() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = new Lead(
      LastName = 'Campaign Var Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Status = 'Prospect',
      Department_Name__c = 'Crash Barrier'
    );
    insert as system leadRecord;
    leadRecord = [
      SELECT
        Id,
        Name,
        Phone,
        Company,
        Department_Name__c,
        Owner.Name,
        Owner.Phone,
        Owner.Email,
        CRM_User_Name_Formula__c,
        CRM_User_Contact_No_Formula__c,
        CRM_User_Email_Formula__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    Test.startTest();
    String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
      settings,
      leadRecord,
      'prospect_not_resp',
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"journeyname":"prospect_not_resp"'));
    System.assert(!payload.contains('"value":"1","format":"{{1}}"'));
    System.assert(!payload.contains('"value":"2","format":"{{2}}"'));
  }

  @IsTest
  static void findJourneyNameBySmsTemplateNameResolvesMapping() {
    BWM_JourneyDefinitionService.clearCache();

    Test.startTest();
    String journeyName = BWM_JourneyDefinitionService.findJourneyNameBySmsTemplateName(
      'DEALER_Enq_dept'
    );
    Test.stopTest();

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(journeyName);
    System.assertNotEquals(null, mapping, 'Journey should resolve to an active mapping.');
    System.assertEquals('DEALER_Enq_dept', mapping.SMS_Template_Name__c);
  }

  @IsTest
  static void buildCampaignPayloadUsesStaticSecondaryContactWhenOwnerMatchesCrm() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"Sudip Datta","CRM_User_Contact_No_Formula__c":"9999999999","CRM_User_Email_Formula__c":"sudip@test.com","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );

    Test.startTest();
    String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
      settings,
      leadRecord,
      'prospect_not_responding_dept',
      '919876543210',
      true
    );
    Test.stopTest();

    System.assert(payload.contains('info@utkarshindia.in'));
    System.assert(payload.contains('+91 33 4190 0001'));
    System.assert(!payload.contains('Rudra Narayan Chakraborty'));
    System.assert(payload.contains('prospect_not_responding_dept'));
  }

  @IsTest
  static void buildCampaignPayloadUsesLeadCrmUserWhenOwnerDoesNotMatchCrm() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"Sreya Banerjee","CRM_User_Contact_No_Formula__c":"9876543210","CRM_User_Email_Formula__c":"sreya@test.com","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );

    Test.startTest();
    String payload = BWM_JourneyDefinitionService.buildPayloadForRecord(
      settings,
      leadRecord,
      'prospect_not_responding_dept',
      '919876543210',
      true
    );
    Test.stopTest();

    System.assert(payload.contains('Sreya Banerjee'));
    System.assert(payload.contains('9876543210'));
    System.assert(!payload.contains('Rudra Narayan Chakraborty'));
    System.assert(!payload.contains('info@utkarshindia.in'));
  }
}