@IsTest
private class BWM_DirectWaCampaignBuilderTest {
  @IsTest
  static void buildPayloadUsesWhatsAppChannelAndTemplatePayload() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000001AAA","Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"9999999999","Email":"owner@test.com"}}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Hello {{1}} {{2}} {{3}} {{4}} {{5}} {{6}}'
      }
    };

    Test.startTest();
    String payload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      null,
      'prospect_dept_enq_280526',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"WhatsApp"'), payload);
    System.assert(payload.contains('"templatepayload"'), payload);
    System.assert(!payload.contains('"channel":"Journey"'), payload);
    System.assert(payload.contains('"biz_opaque_callback_data"'), payload);
  }

  @IsTest
  static void buildPayloadForOpportunityRecord() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Id":"006000000000001AAA","Name":"Opp One","Department_Name__c":"Enquiry","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"9999999999","Email":"owner@test.com"}}',
      Opportunity.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'body' => 'Hello {{1}} {{2}}'
      }
    };

    Test.startTest();
    String payload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      null,
      'dealer_enq_dept',
      templateMeta,
      opportunityRecord,
      '917980828321'
    );
    Test.stopTest();

    System.assert(payload.contains('"to":["917980828321"]'), payload);
    System.assert(payload.contains('"name":"dealer_enq_dept"'), payload);
  }

  @IsTest
  static void buildPayloadWithMappingUsesMappingBrochureAndParams() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    BWM_Template_Mapping__mdt mapping = buildMapping(
      true,
      'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/pvc_pipes_and_fittings(28).pdf',
      'None'
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{ 'body' => 'Hi {{1}} call {{2}} or {{3}} ({{4}})' }
    };

    Test.startTest();
    String payload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      mapping,
      'poly_det_nt_rc_cont_lead',
      templateMeta,
      leadWithOwner(),
      '917980828322'
    );
    Test.stopTest();

    System.assert(payload.contains('pvc_pipes_and_fittings'), payload);
    System.assert(payload.contains('"type":"document"'), payload);
    System.assert(payload.contains('Owner Name'), payload);
  }

  @IsTest
  static void buildPayloadWithMappingWithoutUrlFallsBackToDepartmentBrochure() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    BWM_Template_Mapping__mdt mapping = buildMapping(true, null, 'Department');
    Map<String, Object> templateMeta = new Map<String, Object>{
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Hi {{1}}'
      }
    };

    Test.startTest();
    String payload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      mapping,
      'prospect_enq_dept',
      templateMeta,
      leadWithOwner(),
      '917980828323'
    );
    Test.stopTest();

    System.assert(payload.contains('"code":"en"'), 'Language defaults to en: ' + payload);
    System.assert(payload.contains('"type":"body"'), payload);
  }

  @IsTest
  static void buildPayloadTextHeaderAndComponentBodyCount() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Map<String, Object> withHeaderText = new Map<String, Object>{
      'language' => 'en_US',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'TEXT', 'text' => 'Utkarsh Update' }
      },
      'components' => new List<Object>{
        'not a map',
        new Map<String, Object>{ 'type' => 'HEADER', 'text' => 'Header {{1}}' },
        new Map<String, Object>{ 'type' => 'BODY', 'text' => 'Body {{1}} and {{2}}' }
      }
    };
    Map<String, Object> withoutHeaderText = new Map<String, Object>{
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'TEXT' }
      }
    };

    Test.startTest();
    String textPayload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      null,
      'text_header_template',
      withHeaderText,
      leadWithOwner(),
      '917980828324'
    );
    String departmentHeaderPayload = BWM_DirectWaCampaignBuilder.buildPayload(
      settings,
      null,
      'text_header_no_vars',
      withoutHeaderText,
      leadWithOwner(),
      '917980828325'
    );
    Test.stopTest();

    System.assert(textPayload.contains('Utkarsh Update'), textPayload);
    System.assert(textPayload.contains('"code":"en_US"'), textPayload);
    System.assert(textPayload.contains('"type":"body"'), textPayload);
    System.assert(departmentHeaderPayload.contains('Crash Barrier'), departmentHeaderPayload);
    System.assert(!departmentHeaderPayload.contains('"type":"body"'), 'No variables means no body component.');
  }

  @IsTest
  static void buildPayloadAddsScheduledDateTimeWhenSet() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Map<String, Object> templateMeta = new Map<String, Object>{
      'content' => new Map<String, Object>{ 'body' => 'Hello {{1}}' }
    };

    Test.startTest();
    BWM_CampaignScheduleContext.setScheduledDateTime('2026-10-24T05:30:00Z');
    String payload;
    try {
      payload = BWM_DirectWaCampaignBuilder.buildPayload(
        settings,
        null,
        'scheduled_template',
        templateMeta,
        leadWithOwner(),
        '917980828326'
      );
    } finally {
      BWM_CampaignScheduleContext.clear();
    }
    Test.stopTest();

    System.assert(payload.contains('"scheduledatetime":"2026-10-24T05:30:00Z"'), payload);
  }

  private static Lead leadWithOwner() {
    return (Lead) JSON.deserialize(
      '{"Id":"00Q000000000002AAA","Name":"Lead Two","Company":"Utkarsh Test Co","Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"9999999999","Email":"owner@test.com"}}',
      Lead.class
    );
  }

  private static BWM_Template_Mapping__mdt buildMapping(
    Boolean includeBrochure,
    String documentUrl,
    String brochureMode
  ) {
    Map<String, Object> fields = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'BWM_Template_Mapping__mdt' },
      'DeveloperName' => 'Direct_Wa_Test',
      'Include_Brochure_Header__c' => includeBrochure,
      'Brochure_Attachment_Mode__c' => brochureMode,
      'Param1_Field__c' => 'Owner.Name',
      'Param2_Field__c' => 'Owner.Phone',
      'Param3_Field__c' => 'Owner.Email',
      'Param4_Field__c' => 'Department_Name__c'
    };
    if (documentUrl != null) {
      fields.put('Document_Header_URL__c', documentUrl);
    }
    return (BWM_Template_Mapping__mdt) JSON.deserialize(
      JSON.serialize(fields),
      BWM_Template_Mapping__mdt.class
    );
  }
}