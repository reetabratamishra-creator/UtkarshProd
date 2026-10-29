/**
 * @description SMS phone slots stay blank when Owner Mobile/Phone are empty —
 *              never Owner.Name.
 */
@IsTest
private class BWM_SmsOwnerPhoneBlankTest {
  @IsTest
  static void resolverBlanksOwnerNameWhenPhoneAndMobileEmpty() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"High Mast & Polygonal","Owner":{"attributes":{"type":"User"},"Name":"High Mast Owner"}}',
      Lead.class
    );

    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(leadRecord, 'High Mast Owner'),
      'Blank Owner Mobile/Phone must not fall back to Owner.Name.'
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(leadRecord, ''),
      'Blank current value stays blank.'
    );
    System.assertEquals(
      '9830481380',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(leadRecord, '9830481380'),
      'Static 10-digit numbers are kept when owner phone is blank.'
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Phone'),
      'Owner.Phone stays blank when Mobile and Phone are empty.'
    );
    System.assertEquals(
      '9830481380',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(null, '9830481380')
    );
  }

  @IsTest
  static void resolverUsesOwnerPhoneWhenPresent() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"Steel Tubular Poles","Owner":{"attributes":{"type":"User"},"Name":"STP Owner","Phone":"9123456780"}}',
      Lead.class
    );

    System.assertEquals(
      '9123456780',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(leadRecord, 'STP Owner')
    );
  }

  @IsTest
  static void prospectingNotRespondingSmsIsBlankWhenOwnerPhoneEmpty() {
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
    System.assertNotEquals(null, mapping, 'Prospecting not-responding mapping required.');

    Test.startTest();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    String smsVar1 = extractSmsMappingValue(payload, '1');
    System.assertNotEquals(
      'High Mast Owner',
      smsVar1,
      'SMS must not use Owner.Name when Owner phone/mobile are blank.'
    );
    System.assert(
      String.isBlank(smsVar1) || smsVar1 == 'null',
      'Expected blank SMS phone slot. Actual: ' + smsVar1
    );
  }

  @IsTest
  static void directSmsNumericSlotBlanksOwnerNameWhenPhoneEmpty() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_JourneyDefinitionService.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'DEALER_Enq_dept',
          'dltTemplateId' => '1007088206584852810',
          'templateText' =>
            'Thank you for your interest in Utkarsh India Ltd. Your enquiry has been registered. Our expert will contact you shortly or you can call {#alphanumeric#}'
        }
      }
    );
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"Steel Tubular Poles","Owner":{"attributes":{"type":"User"},"Name":"STP Owner"}}',
      Lead.class
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    Test.startTest();
    String payload = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'DEALER_Enq_dept',
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    System.assert(
      !payload.contains('STP Owner'),
      'Direct SMS call slot must not contain Owner.Name. Payload: ' + payload
    );
  }

  @IsTest
  static void directSmsCoversTemplateBranchesAndOwnerPhone() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(null);
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'templateName' => '' },
        new Map<String, Object>{
          'TemplateName' => 'sms_no_slot',
          'DltTemplateId' => 'DLT_NONE',
          'templateText' => 'Hello customer with no variables'
        },
        new Map<String, Object>{
          'templateName' => 'sms_incomplete',
          'dltTemplateId' => '',
          'templateText' => 'Hi {#var#}'
        },
        new Map<String, Object>{
          'templateName' => 'sms_var_name',
          'dltTemplateId' => 'DLT_VAR',
          'templateText' => 'Dear {#var#} please connect with us'
        },
        new Map<String, Object>{
          'templateName' => 'sms_two_var',
          'dltTemplateId' => 'DLT_TWO',
          'templateText' => 'Hi {#var#} for {#var#}'
        },
        new Map<String, Object>{
          'templateName' => 'sms_numeric_owner',
          'dltTemplateId' => 'DLT_NUM',
          'templateText' => 'Please call {#numeric#} or reach {#alphanumeric#}'
        },
        new Map<String, Object>{
          'templateName' => 'sms_dept_alpha',
          'dltTemplateId' => 'DLT_DEPT',
          'templateText' => 'Thanks for {#alphanumeric#} enquiry'
        }
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead namedLead = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Name":"Lead Name","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"919123456780"}}',
      Lead.class
    );
    Lead blankLead = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name"}}',
      Lead.class
    );

    Boolean blankNameThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(settings, '  ', namedLead, '919876543210');
    } catch (BWM_MessagingException ex) {
      blankNameThrew = true;
    }
    Boolean missingThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(
        settings,
        'no_such_sms',
        namedLead,
        '919876543210'
      );
    } catch (BWM_MessagingException ex) {
      missingThrew = true;
    }
    Boolean incompleteThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(
        settings,
        'sms_incomplete',
        namedLead,
        '919876543210'
      );
    } catch (BWM_MessagingException ex) {
      incompleteThrew = true;
    }

    String noSlot = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_no_slot',
      namedLead,
      '919876543210'
    );
    String varName = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_var_name',
      namedLead,
      '919876543210'
    );
    String twoVar = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_two_var',
      blankLead,
      '919876543210'
    );
    String numeric = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_numeric_owner',
      namedLead,
      '919876543210'
    );
    String deptAlpha = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_dept_alpha',
      namedLead,
      '919876543210'
    );

    System.assertEquals(true, blankNameThrew);
    System.assertEquals(true, missingThrew);
    System.assertEquals(true, incompleteThrew);
    System.assert(noSlot.contains('"channel":"SMS"'), noSlot);
    System.assert(varName.contains('Owner Name') || varName.contains('Crash Barrier'), varName);
    System.assert(twoVar.contains('"channel":"SMS"'), twoVar);
    System.assert(numeric.contains('9123456780'), numeric);
    System.assert(deptAlpha.contains('Crash Barrier'), deptAlpha);
  }

  @IsTest
  static void fieldValueResolverCoversSmsAndRelatedPaths() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","LastName":"LeadLast","Company":"Acme Co","Company_Name__c":"Acme Co","Department_Name__c":"Crash Barrier","Email":"lead@utkarshindia.in","MobilePhone":"9000011111","Phone":"9000022222","City":"Kolkata","State":"West Bengal","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","FirstName":"Own","LastName":"Er","Email":"owner@utkarshindia.in","Phone":"9123456780","MobilePhone":"9123456781"}}',
      Lead.class
    );
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Name":"Quote Opp","Department_Name__c":"Crash Barrier","Email__c":"opp@utkarshindia.in","Phone__c":"9333344444","City__c":"Howrah","State__c":"WB","Quote_Number__c":"Q-1","CloseDate":"2026-08-22","Contact_Person_Name__c":"Person One","Account":{"attributes":{"type":"Account"},"Name":"Dealer Acc","Phone":"9000033333"},"Contact":{"attributes":{"type":"Contact"},"Name":"Contact Full","FirstName":"Con","LastName":"Tact","Email":"contact@utkarshindia.in"},"DealerAccount__r":{"attributes":{"type":"Account"},"Name":"Dealer Acc","Phone":"9000033333"},"Lead__r":{"attributes":{"type":"Lead"},"FirstName":"LeadF","Phone":"9000044444"},"Owner":{"attributes":{"type":"User"},"Name":"Opp Owner","Email":"owner.invalid","Phone":""}}',
      Opportunity.class
    );

    System.assertEquals(
      'Owner Name',
      BWM_FieldValueResolver.resolve(leadRecord, 'Owner.Name')
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(null, 'Name')
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(leadRecord, '')
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(
        leadRecord,
        BWM_MessagingConstants.FIELD_EMPTY
      )
    );
    BWM_FieldValueResolver.resolveRecord(
      leadRecord,
      BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1
    );
    BWM_FieldValueResolver.resolveRecord(
      leadRecord,
      BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2
    );
    System.assertEquals(
      BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_1_DEFAULT,
      BWM_FieldValueResolver.resolveRecord(
        leadRecord,
        BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_NAME_1
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_2_DEFAULT,
      BWM_FieldValueResolver.resolveRecord(
        leadRecord,
        BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_NAME_2
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.FALLBACK_CONTACT_EMAIL,
      BWM_FieldValueResolver.resolveRecord(
        leadRecord,
        BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_EMAIL_1
      )
    );
    BWM_FieldValueResolver.resolveRecord(
      leadRecord,
      BWM_MessagingConstants.FIELD_LOCATION
    );
    BWM_FieldValueResolver.resolveRecord(
      leadRecord,
      BWM_EmailConstants.FIELD_PRODUCT_BRIEF
    );
    BWM_FieldValueResolver.resolveRecord(
      leadRecord,
      BWM_MessagingConstants.FIELD_WHATSAPP_PRODUCT_BRIEF
    );
    System.assertEquals(
      'Acme Co',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Account.Name')
    );
    System.assertEquals(
      'lead@utkarshindia.in',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Email')
    );
    System.assertEquals(
      'lead@utkarshindia.in',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Email__c')
    );
    System.assertEquals(
      '9000011111',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Phone__c')
    );
    System.assertEquals(
      'Own',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.FirstName')
    );
    System.assertEquals(
      'Crash Barrier',
      BWM_FieldValueResolver.resolveDepartmentName(leadRecord)
    );
    System.assertEquals(
      null,
      BWM_FieldValueResolver.resolveDepartmentName(null)
    );

    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Account.Name');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Account.Phone');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Contact.Name');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Contact.FirstName');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Contact.LastName');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Contact.Email');
    BWM_FieldValueResolver.resolveRecord(
      opportunityRecord,
      'DealerAccount__r.Phone'
    );
    BWM_FieldValueResolver.resolveRecord(
      opportunityRecord,
      'DealerAccount__r.Name'
    );
    BWM_FieldValueResolver.resolveRecord(
      opportunityRecord,
      'Contact_Person_Name__c'
    );
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Email');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Phone');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Quote_Number__c');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'CloseDate');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Lead__r.FirstName');
    BWM_FieldValueResolver.resolveRecord(
      opportunityRecord,
      BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK
    );
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'FirstName');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'LastName');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Product_Category__c');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'City__c');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'State__c');
    BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Quotation_Date__c');
    BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(opportunityRecord, 'Opp Owner');
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(null, 'notaphone')
    );

    Opportunity withId = (Opportunity) JSON.deserialize(
      '{"Id":"006000000000001AAA","Name":"Link Opp"}',
      Opportunity.class
    );
    BWM_FieldValueResolver.resolveRecord(
      withId,
      BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK
    );

    Lead phoneOnly = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Phone":"9111122233","LastName":"PhoneOnly"}',
      Lead.class
    );
    System.assertEquals(
      '9111122233',
      BWM_FieldValueResolver.resolveRecord(phoneOnly, 'Phone__c')
    );

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByJourneyName('dealer_enq_dept');
    System.assertNotEquals(null, mapping);
    List<String> leadParams = BWM_FieldValueResolver.resolveParams(
      leadRecord,
      mapping
    );
    List<String> oppParams = BWM_FieldValueResolver.resolveParamsForRecord(
      opportunityRecord,
      mapping
    );
    System.assertEquals(false, leadParams.isEmpty());
    System.assertEquals(false, oppParams.isEmpty());

    Lead firstNameOnly = (Lead) JSON.deserialize(
      '{"Status":"Prospect","LastName":"OnlyLast","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    BWM_FieldValueResolver.resolveParams(firstNameOnly, mapping);
  }

  private static String extractSmsMappingValue(String payload, String key) {
    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get(
      'journeypayload'
    );
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node.get('templateType') != 'SMS') {
        continue;
      }
      Map<String, Object> nodeData = (Map<String, Object>) node.get('data');
      Map<String, Object> smsMappings = (Map<String, Object>) nodeData.get(
        'variableMappings'
      );
      if (smsMappings == null || !smsMappings.containsKey(key)) {
        return '';
      }
      Object rawValue = smsMappings.get(key);
      return rawValue == null ? '' : String.valueOf(rawValue).trim();
    }
    return '';
  }
}