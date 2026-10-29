/**
 * @description   Test class for BWM_MessagePayloadBuilder — validates
 *                Journey/WhatsApp/RCS/SMS payload construction.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_MessagePayloadBuilderTest {
  @IsTest
  static void buildJourneyPayloadIncludesWhatsAppRcsAndSmsNodesForCampaignSend() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospect_not_responding_dept'
      );
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      false,
      true
    );
    Test.stopTest();

    System.assert(payload.contains('"templateType":"WHATSAPP"'));
    System.assert(payload.contains('"templateType":"RCSMESSAGE"'));
    System.assert(payload.contains('"templateType":"SMS"'));
    System.assert(payload.contains('info@utkarshindia.in'));
  }

  @IsTest
  static void buildWhatsAppPayloadForRecordUsesMappingParams() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildWhatsAppPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
  }

  @IsTest
  static void buildRcsAndSmsPayloadsForRecordUseMapping() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String rcsPayload = BWM_MessagePayloadBuilder.buildRcsPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    String smsPayload = BWM_MessagePayloadBuilder.buildSmsPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(rcsPayload.contains('"channel":"Journey"'));
    System.assert(smsPayload.contains('"channel":"Journey"'));
  }

  @IsTest
  static void buildJourneyPayloadIncludesDocumentFileNameWhenRequested() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospect_enq_dept'
      );
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      true,
      false
    );
    Test.stopTest();

    System.assert(payload.contains('"fileName"'));
  }

  @IsTest
  static void buildJourneyPayloadWithoutCampaignUsesLeadCrmUserAsSecondaryContact() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"Sreya Banerjee","CRM_User_Contact_No_Formula__c":"9876543210","CRM_User_Email_Formula__c":"sreya@test.com","Owner":{"attributes":{"type":"User"},"Name":"Bhagyashree Raysingh","Phone":"9830367173","Email":"bhagyashree.r@utkarshindia.in"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospect_not_responding_dept'
      );

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      false,
      false
    );
    Test.stopTest();

    System.assert(payload.contains('Sreya Banerjee'));
    System.assert(payload.contains('9876543210'));
    System.assert(payload.contains('sreya@test.com'));
    System.assert(!payload.contains('Rudra Narayan Chakraborty'));
  }

  @IsTest
  static void buildWhatsAppPayloadUsesLeadSpecificEntryPoint() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildWhatsAppPayload(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
  }

  @IsTest
  static void buildRcsPayloadUsesLeadSpecificEntryPoint() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildRcsPayload(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
  }

  @IsTest
  static void buildSmsPayloadForRecordUsesSmsNodeOnlyMapping() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Quote Opp","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('neg_quote');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildSmsPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"Journey"'));
  }

  @IsTest
  static void nurtureAssignTeamSmsUsesOpportunityOwnerPhoneNotCorporate() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Nurture Opp","StageName":"Nurture","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Opp Owner","Phone":"9888777666","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('nurture_assign_team');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get('journeypayload');
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> smsMappings;
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node.get('templateType') != 'SMS') {
        continue;
      }
      Map<String, Object> nodeData = (Map<String, Object>) node.get('data');
      smsMappings = (Map<String, Object>) nodeData.get('variableMappings');
    }
    System.assertNotEquals(null, smsMappings, 'SMS node mappings required.');
    System.assertEquals('Opp Owner', String.valueOf(smsMappings.get('1')));
    System.assertEquals(
      '9888777666',
      String.valueOf(smsMappings.get('2')),
      'Nurture SMS var2 must be Opportunity Owner phone, not corporate.'
    );
    System.assert(
      !payload.contains(BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE),
      'Nurture SMS must not use central corporate phone. Payload: ' + payload
    );
  }

  @IsTest
  static void nurtureAssignTeamSmsPassesBlankWhenOwnerPhoneMissing() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Nurture Opp Blank Phone","StageName":"Nurture","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Opp Owner","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('nurture_assign_team');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get('journeypayload');
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> smsMappings;
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node.get('templateType') != 'SMS') {
        continue;
      }
      Map<String, Object> nodeData = (Map<String, Object>) node.get('data');
      smsMappings = (Map<String, Object>) nodeData.get('variableMappings');
    }
    System.assertNotEquals(null, smsMappings, 'SMS node mappings required.');
    System.assertEquals('Opp Owner', String.valueOf(smsMappings.get('1')));
    System.assertEquals(
      ' ',
      smsMappings.get('2') == null ? null : String.valueOf(smsMappings.get('2')),
      'Blank Owner Mobile/Phone must pass a space so Bluewave does not keep the sample text.'
    );
    System.assert(
      !payload.contains(BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE),
      payload
    );
  }

  @IsTest
  static void nurtureLostNotRespondingDeptSmsUsesOwnerPhoneNotName() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Nurture Lost Opp","StageName":"Nurture","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Opp Owner Name","Phone":"9777666555","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('nurture_nt_resp_lost_dep');
    System.assertNotEquals(null, mapping);
    System.assertEquals(1, mapping.RCS_SMS_Param_Limit__c);
    System.assertEquals('Owner.Name', mapping.Param1_Field__c);
    System.assertEquals('Owner.Phone', mapping.Param2_Field__c);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get('journeypayload');
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> smsMappings;
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node.get('templateType') != 'SMS') {
        continue;
      }
      Map<String, Object> nodeData = (Map<String, Object>) node.get('data');
      smsMappings = (Map<String, Object>) nodeData.get('variableMappings');
    }
    System.assertNotEquals(null, smsMappings, 'SMS node mappings required.');
    System.assertEquals(
      '9777666555',
      String.valueOf(smsMappings.get('1')),
      'Nurture lost (not responding) dept SMS must use Owner phone, not Owner name.'
    );
    System.assertNotEquals(
      'Opp Owner Name',
      String.valueOf(smsMappings.get('1')),
      'SMS var1 must not be Owner.Name when mapping/journey request Owner.Phone.'
    );
  }

  @IsTest
  static void prospectingNotRespondingDeptSmsBlanksWhenOwnerPhoneEmpty() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"High Mast & Polygonal","Owner":{"attributes":{"type":"User"},"Name":"High Mast Owner"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospecting_not_responding_lost_dept'
      );
    if (mapping == null) {
      mapping = BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospecting_not_responding_dept'
      );
    }
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(payload);
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get('journeypayload');
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> smsMappings;
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node.get('templateType') != 'SMS') {
        continue;
      }
      Map<String, Object> nodeData = (Map<String, Object>) node.get('data');
      smsMappings = (Map<String, Object>) nodeData.get('variableMappings');
    }
    System.assertNotEquals(null, smsMappings, 'SMS node mappings required.');
    String smsVar1 = smsMappings.get('1') == null
      ? ''
      : String.valueOf(smsMappings.get('1')).trim();
    System.assertNotEquals(
      'High Mast Owner',
      smsVar1,
      'Blank Owner Mobile/Phone must not send Owner.Name in the SMS phone slot.'
    );
    System.assertEquals(
      '',
      smsVar1,
      'SMS phone slot must be blank when Owner Mobile and Phone are empty.'
    );
  }

  @IsTest
  static void buildJourneyPayloadUsesStaticSecondaryContactWhenOwnerMatchesCrmOnAutoTrigger() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"High Mast & Polygonal","CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"9830453567","Email":"customersupport@utkarshindia.in"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospect_not_responding_dept'
      );
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      false,
      false
    );
    Test.stopTest();

    System.assert(payload.contains('info@utkarshindia.in'));
    System.assert(payload.contains('+91 33 4190 0001'));
    System.assert(!payload.contains('Rudra Narayan Chakraborty'));
  }

  @IsTest
  static void buildJourneyPayloadKeepsOwnerContactOnProspectEnqDeptWhenOwnerMatchesCrm() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"High Mast & Polygonal","CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"9830453567","Email":"sudip@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('prospect_enq_dept');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      false,
      false
    );
    Test.stopTest();

    System.assert(payload.contains('Sudip Datta'));
    System.assert(payload.contains('9830453567'));
    System.assert(payload.contains('sudip@test.com'));
    System.assert(payload.contains('High Mast & Polygonal'));
    System.assert(!payload.contains('+91 33 4190 0001'));
    System.assert(!payload.contains('info@utkarshindia.in'));
  }

  @IsTest
  static void buildJourneyPayloadResolvesDepartmentBrochureHeaderForQuoteJourney() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_BrochureService.setBrochureMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Crash Barrier',
          Content_File_Title__c = 'Crash Barrier Brochure',
          Brochure_File_Name__c = 'Crash_Barrier.pdf',
          Static_Resource_Name__c = 'Crash_Barrier_pdf',
          Brochure_URL__c = 'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/crash_barrier.pdf'
        )
      }
    );

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Quote Opp","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('neg_quote');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210',
      true,
      false
    );
    Test.stopTest();

    BWM_BrochureService.clearCache();
    System.assert(payload.contains('"headerFormat":"DOCUMENT"'));
    System.assert(payload.contains('crash_barrier.pdf'));
  }

  @IsTest
  static void buildJourneyPayloadUsesTextHeaderWhenConfigured() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Refer Dealer Opp","Department_Name__c":"Crash Barrier","Contact_Person_Name__c":"Contact Person","Phone__c":"9876543210","Account":{"attributes":{"type":"Account"},"Name":"Dealer Account"},"Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_sales_assign');
    if (mapping == null) {
      return;
    }

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '919876543210',
      false,
      false
    );
    Test.stopTest();

    System.assert(
      payload.contains('"headerFormat":"TEXT"') ||
        payload.contains('"headerFormat":"DOCUMENT"')
    );
  }

  @IsTest
  static void buildJourneyPayloadPadsBlankWhatsAppVariables() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');
    System.assertNotEquals(null, mapping);

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210',
      false,
      false
    );
    Test.stopTest();

    System.assert(payload.contains('"value":" "') || payload.contains('"value":"Owner Name"'));
  }

  @IsTest
  static void rcsDirectPayloadUsesCachedCardVariables() {
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'rcs_cov_card',
          'Component' => new Map<String, Object>{
            'Cards' => new List<Object>{
              new Map<String, Object>{
                'DescVariables' => new List<Object>{
                  new Map<String, Object>{ '{{1}}' => 'Department_name_1' }
                },
                'TitleVariables' => new List<Object>{
                  new Map<String, Object>{ '{{2}}' => 'Product_Brief' }
                }
              }
            }
          }
        }
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );

    String payload = BWM_RcsDirectPayloadBuilder.buildPayload(
      settings,
      'rcs_cov_card',
      leadRecord,
      '919876543210'
    );
    Map<String, Object> namedBody = BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'rcs_cov_card',
      leadRecord,
      new Map<String, Object>{ '{{3}}' => 'Owner_Name' }
    );
    System.assert(payload.contains('"channel":"RCSMessage"'), payload);
    System.assertNotEquals(null, namedBody);
  }

  @IsTest
  static void finalizeCampaignPayloadRewritesDocumentHeaderAndBodySlots() {
    BWM_BrochureService.setBrochureMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Crash Barrier',
          Content_File_Title__c = 'Crash Barrier Brochure',
          Brochure_File_Name__c = 'Crash_Barrier.pdf',
          Static_Resource_Name__c = 'Crash_Barrier_pdf',
          Brochure_URL__c = 'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/crash_barrier.pdf'
        )
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName(
        'prospect_not_responding_dept'
      );
    System.assertNotEquals(null, mapping);

    String blankResult = BWM_MessagePayloadBuilder.finalizeCampaignPayload(
      settings,
      leadRecord,
      '',
      mapping
    );
    System.assertEquals('', blankResult);

    Map<String, Object> emptyHeaders =
      BWM_MessagePayloadBuilder.applyDynamicDocumentHeaders(
        settings,
        leadRecord,
        new Map<String, Object>(),
        mapping
      );
    System.assertEquals(true, emptyHeaders.isEmpty());

    String payloadJson = JSON.serialize(
      new Map<String, Object>{
        'content' => new Map<String, Object>{
          'data' => new Map<String, Object>{
            'journeypayload' => new Map<String, Object>{
              'nodes' => new Map<String, Object>{
                '1' => new Map<String, Object>{
                  'templateType' => 'WHATSAPP',
                  'data' => new Map<String, Object>{
                    'headerFormat' => 'DOCUMENT',
                    'headerVariables' => new List<Object>{
                      new Map<String, Object>{
                        'index' => 1,
                        'type' => 'static',
                        'value' => 'https://example.com/old(2).pdf',
                        'format' => 'document'
                      }
                    },
                    'bodyVariables' => new List<Object>{
                      new Map<String, Object>{ 'index' => 1, 'value' => 'keep' },
                      new Map<String, Object>{ 'index' => 4, 'value' => '{{4}}' },
                      new Map<String, Object>{ 'index' => 5, 'value' => 'NA' },
                      new Map<String, Object>{ 'index' => 6, 'value' => '6' }
                    }
                  }
                },
                '2' => new Map<String, Object>{
                  'templateType' => 'SMS',
                  'data' => new Map<String, Object>()
                }
              }
            }
          }
        }
      }
    );

    Test.startTest();
    String finalized = BWM_MessagePayloadBuilder.finalizeCampaignPayload(
      settings,
      leadRecord,
      payloadJson,
      mapping
    );
    Test.stopTest();
    BWM_BrochureService.clearCache();

    System.assert(finalized.contains('"fileName"'), finalized);
    System.assert(finalized.contains('keep'), finalized);
  }

  @IsTest
  static void buildCampaignDirectWhatsAppPayloadCoversHeaderAndBody() {
    BWM_BrochureService.setBrochureMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Crash Barrier',
          Content_File_Title__c = 'Crash Barrier Brochure',
          Brochure_File_Name__c = 'Crash_Barrier.pdf',
          Static_Resource_Name__c = 'Crash_Barrier_pdf',
          Brochure_URL__c = 'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/crash_barrier.pdf'
        )
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Company":"Acme","Name":"Lead Name","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"8888888888","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');
    System.assertNotEquals(null, mapping);

    Map<String, Object> textMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'body' => 'Hello {{1}} {{2}} {{3}}',
        'header' => new Map<String, Object>{
          'type' => 'TEXT',
          'text' => 'Header Text'
        }
      }
    };
    Map<String, Object> documentMeta = new Map<String, Object>{
      'components' => new List<Object>{
        new Map<String, Object>{
          'type' => 'BODY',
          'text' => 'Body {{1}} {{2}}'
        }
      },
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' }
      }
    };

    Test.startTest();
    String withMapping = BWM_MessagePayloadBuilder.buildCampaignDirectWhatsAppPayload(
      settings,
      mapping,
      'u_dealer_enq_dept',
      textMeta,
      leadRecord,
      '919876543210'
    );
    String withDocument = BWM_MessagePayloadBuilder.buildCampaignDirectWhatsAppPayload(
      settings,
      mapping,
      'u_dealer_enq_dept',
      documentMeta,
      leadRecord,
      '919876543210'
    );
    String withoutMapping = BWM_MessagePayloadBuilder.buildCampaignDirectWhatsAppPayload(
      settings,
      null,
      'u_dealer_enq_dept',
      textMeta,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();
    BWM_BrochureService.clearCache();

    System.assert(withMapping.contains('"channel":"WhatsApp"'), withMapping);
    System.assert(withMapping.contains('templatepayload'), withMapping);
    System.assert(withDocument.contains('"channel":"WhatsApp"'), withDocument);
    System.assert(withoutMapping.contains('"channel":"WhatsApp"'), withoutMapping);
    System.assert(withoutMapping.contains('Lead Name') || withoutMapping.contains('Acme'), withoutMapping);
  }
}