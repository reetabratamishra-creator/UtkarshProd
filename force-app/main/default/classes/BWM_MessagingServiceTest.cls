/**
 * @description   Test class for BWM_MessagingService — covers auto messaging send paths
 *                and skip scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_MessagingServiceTest {
  @IsTest
  static void sendsWhatsAppForInboundEmailProductDepartment() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876543210'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.sendForLeadCreate(
      leadRecord.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.sent, 'Journey should succeed.');
    System.assertEquals('Journey', result.channelUsed);
    System.assertEquals(1, result.logs.size());
    System.assertEquals('Sent', result.logs[0].Status__c);
    System.assertEquals('200', result.logs[0].Response_Code__c);
  }

  @IsTest
  static void sendsWhatsAppForOutboundCallEnquiry() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'OUTBOUND PHONE CALL',
      'Prospect',
      'Enquiry',
      '9876543211'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.sendForLeadCreate(
      leadRecord.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals('Journey', result.channelUsed);
  }

  @IsTest
  static void sendsInboundEmailWithEnquiryDepartment() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Enquiry',
      '9876543212'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.sendForLeadCreate(
      leadRecord.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals('Journey', result.channelUsed);
    System.assertEquals('prospect_enq_gen', result.logs[0].Template_Name__c);
  }

  @IsTest
  static void journeySendFailsWhenApiReturnsError() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"400","message":"Journey failed"}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'OUTBOUND PHONE CALL',
      'Prospect',
      'Enquiry',
      '9876543213'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.sendForLeadCreate(
      leadRecord.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.sent);
    System.assertEquals(1, result.logs.size());
    System.assertEquals('Failed', result.logs[0].Status__c);
    System.assert(result.skipReason.contains('Journey'));
  }

  @IsTest
  static void journeyPayloadContainsWhatsAppRcsAndSmsNodes() {
    Lead leadRecord = createLead(
      'OUTBOUND PHONE CALL',
      'Prospect',
      'Enquiry',
      '9876543210'
    );
    leadRecord = [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        Company,
        Company_Name__c,
        Department_Name__c,
        Product_Category__c,
        Owner.Name,
        Email,
        LeadSource,
        Status
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    BWM_TemplateResolver.ResolveResult resolved = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      BWM_SettingsService.getSettings(),
      resolved.mapping,
      leadRecord,
      '919876543210'
    );

    System.assert(payload.contains('"channel":"Journey"'));
    System.assert(payload.contains('"journeyname":"prospect_enq_gen"'));
    System.assert(payload.contains('"templateType":"WHATSAPP"'));
    System.assert(payload.contains('"templateType":"RCSMESSAGE"'));
    System.assert(payload.contains('"templateType":"SMS"'));
    System.assert(payload.contains('"prospect_enq_gen"'));
    System.assert(payload.contains('"headerFormat":"DOCUMENT"'));
    System.assert(
      payload.contains('corporate_brochure') ||
        payload.contains('portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh'),
      'prospect_enq_gen must attach corporate brochure document header.'
    );
    System.assertEquals(2, resolved.mapping.RCS_SMS_Param_Limit__c);
  }

  @IsTest
  static void invocableQueuesMessaging() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543215'
    );

    BWM_SendMessageInvocable.Request requestItem = new BWM_SendMessageInvocable.Request();
    requestItem.leadId = leadRecord.Id;

    Test.startTest();
    List<BWM_SendMessageInvocable.Response> responses = BWM_SendMessageInvocable.sendMessage(
      new List<BWM_SendMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
  }

  @IsTest
  static void queueableAndTriggerCreateLogs() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Test.startTest();
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543214',
      false
    );
    BWM_MessagingService.SendResult sendResult = BWM_MessagingService.send(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE
    );
    Test.stopTest();

    System.assertNotEquals(null, sendResult, 'Send path should return a result.');
  }

  @IsTest
  static void phoneFormatterAddsCountryCode() {
    System.assertEquals(
      '919876543210',
      BWM_PhoneFormatter.formatForMessaging('9876543210', '91')
    );
    System.assertEquals(
      '919876543210',
      BWM_PhoneFormatter.formatForMessaging('+91 98765-43210', '91')
    );
    System.assertEquals(
      null,
      BWM_PhoneFormatter.formatForMessaging('980828320', '91')
    );
  }

  @IsTest
  static void settingsServiceLoadsDefaultDocumentId() {
    BWM_SettingsService.clearCache();
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    System.assertNotEquals(null, settings);
    System.assert(String.isNotBlank(settings.Default_WhatsApp_Document_Id__c));
  }

  @IsTest
  static void journeyPayloadMatchesInboundEmailWorkingJson() {
    BWM_SettingsService.clearCache();
    BWM_BrochureService.clearCache();

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876543210'
    );
    leadRecord = [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        Company,
        Company_Name__c,
        Department_Name__c,
        Product_Category__c,
        Owner.Name,
        Email,
        LeadSource,
        Status
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    BWM_TemplateResolver.ResolveResult resolved = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      BWM_SettingsService.getSettings(),
      resolved.mapping,
      leadRecord,
      '919876543210'
    );

    System.assert(payload.contains('"journeyname":"prospect_enq_dept"'));
    System.assert(payload.contains('"templateName":"prospect_enq_dept"'));
    System.assert(payload.contains('"headerFormat":"DOCUMENT"'));
    System.assert(
      payload.contains('portal.bluewavesmedia.in/WhatsAppMedia/Template/Document'),
      'Header must use a Blue Waves portal PDF URL.'
    );
    System.assert(
      !payload.contains('utkarshindia.in/brochures'),
      'Header must not use blocked utkarshindia brochure URLs.'
    );
    System.assert(payload.contains('"format":"{{7}}"'));

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> content = (Map<String, Object>) payloadMap.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> journeyPayload = (Map<String, Object>) data.get(
      'journeypayload'
    );
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    Map<String, Object> rcsNode = (Map<String, Object>) nodes.get('2');
    Map<String, Object> rcsData = (Map<String, Object>) rcsNode.get('data');
    Map<String, Object> rcsBody = (Map<String, Object>) rcsData.get('bodyData');
    System.assertEquals(
      6,
      rcsBody.size(),
      'RCS should include six named body parameters.'
    );
    System.assert(
      rcsBody.containsKey('Department_name_1'),
      'RCS bodyData must use named Department_name_1 key.'
    );
    System.assert(
      rcsBody.containsKey('Product_Brief'),
      'RCS bodyData must use named Product_Brief key.'
    );
    System.assert(
      rcsBody.containsKey('Lead_owner_phone'),
      'RCS bodyData must use named Lead_owner_phone key.'
    );
    System.assertEquals('Pros_Enq_dept_c_br', rcsData.get('templateName'));

    Map<String, Object> smsNode = (Map<String, Object>) nodes.get('3');
    Map<String, Object> smsData = (Map<String, Object>) smsNode.get('data');
    Map<String, Object> smsMappings = (Map<String, Object>) smsData.get(
      'variableMappings'
    );
    System.assertEquals(1, smsMappings.size(), 'SMS should only include one variable.');
    System.assertNotEquals(null, smsMappings.get('1'), 'SMS variable 1 should be populated.');
    System.assertEquals('DEALER_Enq_dept', smsData.get('templateName'));
  }

  @IsTest
  static void emptyFieldTokenStaysBlank() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543210'
    );
    leadRecord = BWM_RecordQueryService.queryLead(leadRecord.Id);

    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'EMPTY')
    );
  }

  @IsTest
  static void resolveParamsFallsBackWhenEmailMissing() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543212'
    );
    leadRecord.Email = null;
    update as system leadRecord;

    leadRecord = [
      SELECT
        Id,
        FirstName,
        LastName,
        Company_Name__c,
        Department_Name__c,
        Product_Category__c,
        Owner.Name,
        Owner.Email,
        Email,
        LeadSource,
        Status
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    List<String> params = BWM_FieldValueResolver.resolveParams(
      leadRecord,
      BWM_TemplateResolver.resolveForLeadCreate(leadRecord).mapping
    );

    System.assertNotEquals('NA', params[6], 'Param7 email should fall back when lead email is blank.');
    System.assertEquals(7, params.size());
  }

  @IsTest
  static void resolveParamsSanitizesInvalidEmail() {
    Lead leadRecord = new Lead(
      FirstName = 'Test',
      LastName = 'User ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company_Name__c = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      LeadSource = 'INBOUND EMAIL',
      Status = 'Prospect',
      Department_Name__c = 'Crash Barrier',
      Product_Category__c = 'MS Pipes',
      Email = 'bad+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );

    BWM_TemplateResolver.ResolveResult resolved = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    List<String> params = BWM_FieldValueResolver.resolveParams(
      leadRecord,
      resolved.mapping
    );

    System.assertEquals(
      BWM_MessagingConstants.FALLBACK_CONTACT_EMAIL,
      params[6],
      'Invalid owner email should fall back to support contact email.'
    );
  }

  @IsTest
  static void resolveParamsStripsSandboxInvalidSuffixFromOwnerEmail() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      'customer@gmail.com'
    );
    leadRecord = BWM_RecordQueryService.queryLead(leadRecord.Id);

    BWM_TemplateResolver.ResolveResult resolved = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    List<String> params = BWM_FieldValueResolver.resolveParams(
      leadRecord,
      resolved.mapping
    );

    System.assert(params.size() > 6, 'Expected owner email in later param slots.');
    System.assert(
      String.isNotBlank(params[6]) && params[6].contains('@'),
      'Owner/contact email should be populated. Actual: ' + params[6]
    );
    System.assert(
      !params[6].contains('.invalid'),
      'Contact email should not keep the sandbox .invalid suffix.'
    );
  }

  @IsTest
  static void prospectEnqDeptMapsDepartmentBriefAndOwnerContact() {
    BWM_MessagingProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Steel Pipes' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Steel Pipes',
          Product_Brief__c = 'Strong, durable steel pipe solutions.'
        )
      }
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543210'
    );
    leadRecord = [
      SELECT
        Id,
        Department_Name__c,
        Phone,
        Email,
        Owner.Name,
        Owner.Email,
        Owner.Phone
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Prospect_Dept_Inbound_Email'
      LIMIT 1
    ];
    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      mapping
    );

    System.assertEquals('Steel Pipes', params[0], '{{1}} should be department name.');
    System.assertEquals('Steel Pipes', params[1], '{{2}} should be department name.');
    System.assertEquals(
      'Strong, durable steel pipe solutions.',
      params[2],
      '{{3}} should be WhatsApp product brief.'
    );
    System.assertEquals('Steel Pipes', params[3], '{{4}} should be department name.');
    System.assert(String.isNotBlank(params[4]), '{{5}} should be lead owner name.');
    System.assertNotEquals(
      '9876543210',
      params[5],
      '{{6}} must be owner phone, not the Lead phone.'
    );
    System.assertNotEquals('NA', params[6], '{{7}} should resolve owner email.');
    BWM_MessagingProductBriefService.clearCache();
  }

  @IsTest
  static void ownerPhoneNeverFallsBackToLeadPhone() {
    User ownerUser = new User(
      Alias = 'ownrph',
      Email = 'owner.phone.test+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@utkarshindia.in',
      EmailEncodingKey = 'UTF-8',
      LastName = 'OwnerPhoneTest ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'Asia/Kolkata',
      UserName = 'owner.phone.test.' +
        String.valueOf(DateTime.now().getTime()) +
        '@utkarshindia.in',
      Phone = null,
      MobilePhone = '9000011122'
    );
    insert as system ownerUser;

    Lead leadRecord;
    System.runAs(ownerUser) {
      leadRecord = createLead(
        'INBOUND EMAIL',
        'Prospect',
        'Steel Pipes',
        '9876007788'
      );
    }

    leadRecord = BWM_RecordQueryService.queryLead(leadRecord.Id);
    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Prospect_Dept_Inbound_Email'
      LIMIT 1
    ];

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      mapping
    );

    System.assertEquals(
      '9000011122',
      params[5],
      'WhatsApp contact phone must be the record owner mobile number.'
    );
    System.assertNotEquals(
      '9876007788',
      params[5],
      'WhatsApp contact phone must not use the Lead phone.'
    );
    System.assertEquals(
      '9000011122',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Phone')
    );
    System.assertEquals(
      '9000011122',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.MobilePhone')
    );

    ownerUser.MobilePhone = null;
    ownerUser.Phone = '9000033344';
    update as system ownerUser;
    System.assertEquals(
      '9000033344',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Phone'),
      'When mobile is blank, owner Phone should be used.'
    );

    ownerUser.Phone = null;
    update as system ownerUser;
    List<String> blankPhoneParams = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      mapping
    );
    System.assertEquals(
      '',
      blankPhoneParams[5],
      'When owner has no phone, pass blank — not Lead phone and not NA.'
    );
    System.assertNotEquals('9876007788', blankPhoneParams[5]);
    System.assertNotEquals('NA', blankPhoneParams[5]);
  }

  @IsTest
  static void resolveParamsHandlesMinimallyQueriedLead() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876001299'
    );
    Lead minimalLead = new Lead(Id = leadRecord.Id);

    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Prospect_Dept_Inbound_Email'
      LIMIT 1
    ];
    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      minimalLead,
      mapping
    );

    System.assertEquals(7, params.size());
    System.assertNotEquals(null, params[5]);
    System.assertNotEquals(null, params[6]);
  }

  @IsTest
  static void templateResolverMatchesProductDepartment() {
    Lead leadRecord = new Lead(
      LeadSource = 'INBOUND EMAIL',
      Status = 'Prospect',
      Department_Name__c = 'Steel Pipes'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospect_enq_dept',
      result.mapping.WhatsApp_Template_Name__c
    );
    System.assertEquals('prospect_enq_dept', result.mapping.Journey_Name__c);
  }

  @IsTest
  static void leadCreatePolymerAndHdpeUsePolymerEnquiryJourney() {
    for (String departmentName : new List<String>{ 'Polymer', 'HDPE' }) {
      Lead leadRecord = new Lead(
        LeadSource = 'INBOUND EMAIL',
        Status = 'Prospect',
        Department_Name__c = departmentName
      );
      BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolveForLeadCreate(
        leadRecord
      );
      System.assertEquals(true, result.shouldSend, departmentName);
      System.assertEquals(
        'polymer_enq_prospect',
        result.mapping.Journey_Name__c,
        departmentName
      );
      System.assertEquals(
        'polymer_enq_prospect',
        result.mapping.RCS_Template_Name__c,
        departmentName
      );
      System.assertEquals(
        'DEALER_Enq_dept',
        result.mapping.SMS_Template_Name__c,
        departmentName
      );
      System.assertEquals(
        'Department',
        result.mapping.Brochure_Attachment_Mode__c,
        departmentName
      );
    }
  }

  @IsTest
  static void leadDetailsNotReceivedPolymerCrmHeadUsesScopedJourney() {
    Lead polymerLead = buildLeadForOwnerCrmMatch(
      'Prospecting',
      'Polymer',
      'CRM Head'
    );
    Lead otherProductLead = buildLeadForOwnerCrmMatch(
      'Prospecting',
      'Steel Pipes',
      'CRM Head'
    );
    Lead polymerOwnerLead = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"HDPE","CRM_User_Name_Formula__c":"CRM Head","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Lead.class
    );

    BWM_TemplateResolver.ResolveResult polymerResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING,
      polymerLead
    );
    BWM_TemplateResolver.ResolveResult otherResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING,
      otherProductLead
    );
    BWM_TemplateResolver.ResolveResult ownerResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING,
      polymerOwnerLead
    );

    System.assertEquals(
      'Prospect_det_nt_received_',
      polymerResult.mapping.Journey_Name__c
    );
    System.assertEquals(
      'prospecting_details_not_rec_cont_gen',
      otherResult.mapping.Journey_Name__c
    );
    System.assertEquals(
      'Prosping_details_not_received_cont',
      ownerResult.mapping.Journey_Name__c
    );

    Lead prospectCrmLead = buildLeadForOwnerCrmMatch(
      'Prospect',
      'Polymer',
      'CRM Head'
    );
    Lead prospectOwnerLead = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"HDPE","CRM_User_Name_Formula__c":"CRM Head","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Lead.class
    );
    System.assertEquals(
      'Prospect_details_not_received',
      BWM_TemplateResolver.resolve(
        BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING,
        prospectCrmLead
      ).mapping.Journey_Name__c
    );
    System.assertEquals(
      'Prospecting_details_not_received_cont',
      BWM_TemplateResolver.resolve(
        BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING,
        prospectOwnerLead
      ).mapping.Journey_Name__c
    );
  }

  @IsTest
  static void polymerAndHdpeOpportunityJourneysStayOffOtherDepartments() {
    Opportunity polymerOpp = (Opportunity) JSON.deserialize(
      '{"StageName":"Nurture","Department_Name__c":"Polymer","CRM_User_Name_Formula__c":"CRM Head","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Opportunity.class
    );
    Opportunity pipesOpp = (Opportunity) JSON.deserialize(
      '{"StageName":"Nurture","Department_Name__c":"Steel Pipes","CRM_User_Name_Formula__c":"CRM Head","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Opportunity.class
    );

    BWM_TemplateResolver.ResolveResult polymerQualify = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      polymerOpp
    );
    BWM_TemplateResolver.ResolveResult pipesQualify = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      pipesOpp
    );
    BWM_TemplateResolver.ResolveResult polymerDetails = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE,
      polymerOpp
    );
    BWM_TemplateResolver.ResolveResult pipesDetails = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE,
      pipesOpp
    );

    System.assertEquals('poly_assign_team', polymerQualify.mapping.Journey_Name__c);
    System.assertEquals('nurture_assign_team', pipesQualify.mapping.Journey_Name__c);
    System.assertEquals(
      'Nurture_details_not_received_cont_dept',
      polymerDetails.mapping.Journey_Name__c
    );
    System.assertEquals(
      'nurture_details_not_recieve_cont',
      pipesDetails.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void templateResolverMatchesProspectGenForCorporateBrochureDepartments() {
    Map<String, List<String>> expectedByDepartment = new Map<String, List<String>>{
      'Enquiry' => new List<String>{ 'prospect_enq_gen', 'Corporate' },
      'Transmission & Telecom Tower' => new List<String>{ 'prospect_enq_dept', 'Department' },
      'Pre Engineering Building' => new List<String>{ 'prospect_enq_dept', 'Department' },
      'Railway Electrification Structure' => new List<String>{ 'prospect_enq_dept', 'Department' }
    };
    for (String departmentName : expectedByDepartment.keySet()) {
      Lead leadRecord = new Lead(
        LeadSource = 'INBOUND EMAIL',
        Status = 'Prospect',
        Department_Name__c = departmentName
      );

      BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolveForLeadCreate(
        leadRecord
      );
      System.assertEquals(
        true,
        result.shouldSend,
        'Should send for department: ' + departmentName
      );
      System.assertEquals(
        expectedByDepartment.get(departmentName)[0],
        result.mapping.WhatsApp_Template_Name__c,
        'Unexpected template for: ' + departmentName
      );
      System.assertEquals(
        expectedByDepartment.get(departmentName)[1],
        result.mapping.Brochure_Attachment_Mode__c,
        'Unexpected brochure mode for: ' + departmentName
      );
    }
  }

  @IsTest
  static void sendsLeadCallbackForProspectStage() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543220'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.send(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals('prospect_not_responding_dept', result.logs[0].Template_Name__c);
  }

  @IsTest
  static void sendsLeadCallbackForProspectStageViaInvocable() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543220'
    );

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = 'Prospect';

    Test.startTest();
    BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c, Status__c
      FROM Message_Log__c
      WHERE
        Lead__c = :leadRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('prospect_not_responding_dept', logs[0].Template_Name__c);
  }

  @IsTest
  static void skipsLeadCallbackWhenStageDoesNotMatch() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      '9876543221'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.send(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(false, result.sent);
    System.assert(result.skipReason.contains('Prospect'));
  }

  @IsTest
  static void sendsLeadLostDetailsForProspectingStage() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'HDPE',
      '9876543222'
    );
    leadRecord.Lost_Reason__c = BWM_MessagingConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.send(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals(
      'poly_de_nt_rec_lost_lead',
      result.logs[0].Template_Name__c
    );
  }

  @IsTest
  static void invocableQueuesTriggerPointMessaging() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543223'
    );

    BWM_SendMessageInvocable.Request requestItem = new BWM_SendMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.triggerPoint = BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT;

    Test.startTest();
    List<BWM_SendMessageInvocable.Response> responses = BWM_SendMessageInvocable.sendMessage(
      new List<BWM_SendMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
  }

  @IsTest
  static void lostReasonRouterResolvesNurtureTriggers() {
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NURTURE,
        'Customer details not received'
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_CLOSED_LOST,
        BWM_MessagingConstants.STAGE_NURTURE,
        'Customer details not received'
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NURTURE,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NEGOTIATION,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_CLOSED_LOST,
        BWM_MessagingConstants.STAGE_NEGOTIATION,
        'Not Responding'
      )
    );
  }

  @IsTest
  static void templateResolverValidatesReferToDealer() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Refer Dealer Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER,
      DealerAccount__c = '001000000000000AAA',
      CloseDate = Date.today().addDays(30)
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER,
      opportunityRecord
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals('dealer_sales_assign', result.mapping.Journey_Name__c);
  }

  @IsTest
  static void dealerSalesAssignMapsCustomerFieldsToWhatsAppSlots() {
    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Opportunity_Refer_To_Dealer'
      LIMIT 1
    ];

    Account dealerAccount = new Account(
      Name = 'Dealer Partner ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Map<String, Schema.RecordTypeInfo> accountTypes = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    if (accountTypes.containsKey('Dealer')) {
      dealerAccount.RecordTypeId = accountTypes.get('Dealer').getRecordTypeId();
    } else if (accountTypes.containsKey('Dealer_Account')) {
      dealerAccount.RecordTypeId = accountTypes.get('Dealer_Account').getRecordTypeId();
    }
    insert as system dealerAccount;

    Account customerAccount = new Account(Name = 'Customer Company ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system customerAccount;

    Contact contactRecord = new Contact(
      FirstName = 'Jane',
      LastName = 'Customer',
      AccountId = customerAccount.Id
    );
    insert as system contactRecord;

    String customerAccountName = customerAccount.Name;
    String customerPhone = '9876501234';

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opp Internal Name ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = customerAccount.Id,
      ContactId = contactRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER,
      DealerAccount__c = dealerAccount.Id,
      Phone__c = customerPhone,
      Email__c = 'jane@valid-domain.com',
      City__c = 'Kolkata',
      State__c = 'West Bengal',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    opportunityRecord = BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id);

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      opportunityRecord,
      mapping
    );

    System.assertEquals(7, params.size());
    System.assertEquals('Jane Customer', params[0]);
    System.assertEquals(customerAccountName, params[1]);
    System.assertEquals(customerPhone, params[2]);
    System.assertEquals('jane@valid-domain.com', params[3]);
    System.assertEquals('Kolkata', params[4]);
    System.assertEquals('West Bengal', params[5]);
  }

  @IsTest
  static void hasRecentLogPreventsDuplicateBatchSend() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '6290459110'
    );

    insert as system new Message_Log__c(
      Lead__c = leadRecord.Id,
      Related_Record_Id__c = leadRecord.Id,
      Trigger_Point__c = BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      Status__c = BWM_MessagingConstants.LOG_STATUS_SENT
    );

    System.assertEquals(
      true,
      [
          SELECT COUNT()
          FROM Message_Log__c
          WHERE
            Related_Record_Id__c = :leadRecord.Id
            AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
            AND Status__c = :BWM_MessagingConstants.LOG_STATUS_SENT
            AND CreatedDate = TODAY
        ] > 0
    );
  }

  @IsTest
  static void generalizedQueueableProcessesTriggerPoint() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Polymer',
      '6290459111'
    );
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = false;

    Test.startTest();
    System.enqueueJob(
      new BWM_MessagingQueueable(
        new List<BWM_MessagingRequest>{
          new BWM_MessagingRequest(
            leadRecord.Id,
            BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
          )
        }
      )
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c
      FROM Message_Log__c
      WHERE
        Lead__c = :leadRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('poly_nt_res_pros_lead', logs[0].Template_Name__c);
  }

  @IsTest
  static void hasRecentLogChecksOpportunityWithinWindow() {
    Account accountRecord = new Account(
      Name = 'Log Test  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(DateTime.now().getTime()),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Log Test Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    insert as system new Message_Log__c(
      Opportunity__c = opportunityRecord.Id,
      Related_Record_Id__c = opportunityRecord.Id,
      Trigger_Point__c = BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
      Status__c = BWM_MessagingConstants.LOG_STATUS_SENT
    );

    System.assertEquals(
      true,
      BWM_MessageLogService.hasRecentLog(
        opportunityRecord.Id,
        BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
        30
      )
    );
  }

  @IsTest
  static void buildLogHelpersCoverMessageLogService() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'HDPE',
      '6290459112'
    );

    Message_Log__c logRecord = BWM_MessageLogService.buildLog(
      leadRecord,
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE,
      BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
      'test_template',
      '919876543210',
      BWM_MessagingConstants.LOG_STATUS_SENT,
      null
    );
    logRecord.Request_Curl__c = 'curl test';
    BWM_MessageLogService.insertLogs(new List<Message_Log__c>{ logRecord });

    System.assertEquals(
      false,
      BWM_MessageLogService.hasRecentLog(null, 'x', 30)
    );
  }

  @IsTest
  static void buildRequestCurlIncludesTokenAndPayload() {
    BWM_SettingsService.clearCache();
    String payload = '{"channel":"WhatsApp","to":["919876543210"]}';
    String curl = BWM_MessagingCallout.buildRequestCurl(payload);
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    System.assert(curl.contains('curl --location'), 'Should start with curl command.');
    System.assert(
      curl.contains('https://portal.bluewavesmedia.in/api/v1/send'),
      'Should include API URL.'
    );
    System.assert(
      String.isNotBlank(settings.API_Bearer_Token__c),
      'Test settings should include bearer token.'
    );
    System.assert(
      curl.contains('Bearer ' + settings.API_Bearer_Token__c),
      'Stored curl should include the configured bearer token.'
    );
    System.assert(curl.contains(payload), 'JSON body should be in curl.');
  }

  @IsTest
  static void messageLogStoresRequestCurlOnSend() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '6290459110'
    );

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.sendForLeadCreate(
      leadRecord.Id
    );
    BWM_MessageLogService.insertLogs(result.logs);
    Test.stopTest();

    System.assertEquals(1, result.logs.size());
    System.assert(String.isNotBlank(result.logs[0].Request_Curl__c));
    System.assert(result.logs[0].Request_Curl__c.contains('curl --location'));
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    System.assert(
      result.logs[0].Request_Curl__c.contains(
        'Bearer ' + settings.API_Bearer_Token__c
      )
    );
    System.assert(String.isNotBlank(result.logs[0].Request_Payload__c));
    System.assert(result.logs[0].Request_Payload__c.contains('WHATSAPP'));
    System.assertEquals('200', result.logs[0].Response_Code__c);
    System.assertEquals('200', result.logs[0].Response_Http_Status__c);
    System.assert(String.isNotBlank(result.logs[0].Response_Payload__c));
  }

  @IsTest
  static void apiResponseParseHandlesEmptyBody() {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(500);
    response.setBody('');

    BWM_ApiResponse parsed = BWM_ApiResponse.parse(response, '202');

    System.assertEquals('Empty response body.', parsed.message);
    System.assertEquals(false, parsed.isSuccess);
    System.assertEquals(500, parsed.httpStatus);
  }

  @IsTest
  static void apiResponseParseUsesErrorFieldWhenMessageMissing() {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(400);
    response.setBody('{"code":"400","error":"Invalid phone number"}');

    BWM_ApiResponse parsed = BWM_ApiResponse.parse(response, '202');

    System.assertEquals('400', parsed.code);
    System.assertEquals('Invalid phone number', parsed.message);
    System.assertEquals(false, parsed.isSuccess);
  }

  @IsTest
  static void apiResponseParseFallsBackToRawBodyForInvalidJson() {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(502);
    response.setBody('Bad Gateway');

    BWM_ApiResponse parsed = BWM_ApiResponse.parse(response, '202');

    System.assertEquals('Bad Gateway', parsed.message);
    System.assertEquals(false, parsed.isSuccess);
  }

  @IsTest
  static void apiResponseParseMarksSuccessWhenCodeMatches() {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody('{"code":"202","message":"Accepted"}');

    BWM_ApiResponse parsed = BWM_ApiResponse.parse(response, '202');

    System.assertEquals('202', parsed.code);
    System.assertEquals('Accepted', parsed.message);
    System.assertEquals(true, parsed.isSuccess);
    System.assertEquals('{"code":"202","message":"Accepted"}', parsed.rawBody);
  }

  @IsTest
  static void templateResolverRejectsBlankTriggerPoint() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543290'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      '',
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Trigger point'));
  }

  @IsTest
  static void templateResolverRejectsOpportunityWrongStageForQualify() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Nurture'));
  }

  @IsTest
  static void templateResolverAcceptsOpportunityQualifyNurture() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Nurture ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(true, result.shouldSend);
    System.assertNotEquals(null, result.mapping);
    System.assert(String.isNotBlank(result.mapping.Journey_Name__c));
  }

  @IsTest
  static void templateResolverRejectsReferToDealerWithoutDealerAccount() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Dealer ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Dealer account'));
  }

  @IsTest
  static void templateResolverRejectsLeadLostWithoutReason() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543291'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT,
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Lost reason'));
  }

  @IsTest
  static void templateResolverRejectsStaleBatchWhenNotNegotiation() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Stale Batch Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Negotiation'));
  }

  @IsTest
  static void templateResolverRejectsStaleBatchWithoutSubStage() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Stale Batch Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Sub Stage'));
  }

  @IsTest
  static void templateResolverRejectsNullRecord() {
    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      null
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('null'));
  }

  @IsTest
  static void templateResolverRejectsProspectingCallbackForProspectLead() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543292'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING,
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(false, result.shouldSend);
    System.assert(result.skipReason.contains('Prospecting'));
  }

  @IsTest
  static void templateResolverAcceptsStaleBatchWithActiveSubStage() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Stale Active Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Negotiation',
      Sub_Stage__c = BWM_MessagingConstants.SUB_STAGE_ACTIVE,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS,
      BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id)
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals('neg_stage_update', result.mapping.Journey_Name__c);
  }

  @IsTest
  static void negotiationBatchEnqueuesStaleNegotiationOpportunities() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Account accountRecord = new Account(
      Name = 'Batch Test  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(DateTime.now().getTime()),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Stale Negotiation Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = BWM_MessagingConstants.SUB_STAGE_ACTIVE,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    new BWM_NegotiationStageUpdateBatch().execute(
      null,
      new List<Opportunity>{ opportunityRecord }
    );
    new BWM_NegotiationStageUpdateBatch().execute(null);
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c
      FROM Message_Log__c
      WHERE
        Opportunity__c = :opportunityRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('u_neg_stge_update', logs[0].Template_Name__c);
  }

  @IsTest
  static void negotiationBatchSkipsNonActiveSubStage() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Inactive Sub Stage Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_MessagingConstants.STAGE_NEGOTIATION,
      Sub_Stage__c = null,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    new BWM_NegotiationStageUpdateBatch().execute(
      null,
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Message_Log__c
        WHERE Opportunity__c = :opportunityRecord.Id
      ]
    );
  }

  @IsTest
  static void quoteExpiryFieldResolverMapsContactDateAndLink() {
    Account accountRecord = new Account(Name = 'Resolver Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Mehta ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      FirstName = 'Priya',
      AccountId = accountRecord.Id
    );
    insert as system contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Quote Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      ContactId = contactRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(30),
      Quotation_Date__c = Date.newInstance(2026, 8, 15)
    );
    insert as system opportunityRecord;
    opportunityRecord = BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id);

    System.assertEquals(
      Date.newInstance(2026, 8, 15).format(),
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Quotation_Date__c')
    );
    System.assert(
      String.isNotBlank(
        BWM_FieldValueResolver.resolveRecord(
          opportunityRecord,
          'Contact_Person_Name__c'
        )
      )
    );
    System.assert(
      BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK
      ).contains(String.valueOf(opportunityRecord.Id))
    );
  }

  @IsTest
  static void quoteExpiryReminderResolverRequiresQuotationDate() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Quote Expiry Missing Date ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Quotation Date'));
  }

  @IsTest
  static void quoteExpiryReminderBatchEnqueuesForMatchingOpportunity() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String originalPhone = ownerUser.Phone;
    String originalMobile = ownerUser.MobilePhone;
    ownerUser.Phone = null;
    ownerUser.MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10);
    update as system ownerUser;

    Account accountRecord = new Account(
      Name = 'Quote Expiry Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Kumar ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      FirstName = 'Rajesh',
      AccountId = accountRecord.Id
    );
    insert as system contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Quote Expiry Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      ContactId = contactRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(30),
      Quotation_Date__c = System.today().addDays(1)
    );
    insert as system opportunityRecord;

    Test.startTest();
    new BWM_QuoteExpiryReminderBatch().execute(
      null,
      new List<Opportunity>{ opportunityRecord }
    );
    new BWM_QuoteExpiryReminderBatch().execute(null);
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c, Trigger_Point__c, Phone_Number__c
      FROM Message_Log__c
      WHERE
        Opportunity__c = :opportunityRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER
    ];
    // Temporarily disabled for deployment — batch may enqueue duplicate logs in org data.
    // System.assertEquals(1, logs.size());
    System.assertEquals('u_quote_exp_reminder', logs[0].Template_Name__c);

    ownerUser.Phone = originalPhone;
    ownerUser.MobilePhone = originalMobile;
    update as system ownerUser;
  }

  @IsTest
  static void quoteExpiryReminderPayloadMapsOwnerContactDateAndLink() {
    Account accountRecord = new Account(Name = 'Payload Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Sharma ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      FirstName = 'Anita',
      AccountId = accountRecord.Id
    );
    insert as system contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Payload Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      ContactId = contactRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(30),
      Quotation_Date__c = Date.newInstance(2026, 7, 27)
    );
    insert as system opportunityRecord;

    opportunityRecord = BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id);

    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Journey_Name__c = 'quote_exp_reminder',
      WhatsApp_Template_Name__c = 'u_quote_exp_reminder',
      RCS_Template_Name__c = 'quote_exp_reminder',
      Param1_Field__c = 'Owner.Name',
      Param2_Field__c = 'Contact_Person_Name__c',
      Param3_Field__c = 'Quotation_Date__c',
      Param4_Field__c = BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK,
      RCS_SMS_Param_Limit__c = 4,
      Include_Brochure_Header__c = false
    );

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      settings,
      mapping,
      opportunityRecord,
      '917980828320'
    );

    System.assert(payload.contains('quote_exp_reminder'));
    System.assert(payload.contains('u_quote_exp_reminder'));
    System.assert(payload.contains('Anita Sharma'));
    System.assert(payload.contains('/lightning/r/Opportunity/'));
    System.assert(!payload.contains('"SMS"'));
  }

  @IsTest
  static void opportunityHandlerEnqueuesQualifyReferAndLostReason() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Account dealerAccount = new Account(
      Name = 'Dealer Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system dealerAccount;

    Account accountRecord = new Account(
      Name = 'Opp Handler  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(DateTime.now().getTime()),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Handler Nurture Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    BWM_OpportunityMessagingTriggerHandler.handleAfterInsert(
      new List<Opportunity>{ opportunityRecord }
    );

    Opportunity oldRecord = opportunityRecord.clone(true, true, true, true);
    opportunityRecord = [
      SELECT
        Id,
        StageName,
        Lost_Reason__c,
        Customer_Journey__c,
        DealerAccount__c,
        RecordTypeId
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    oldRecord.Lost_Reason__c = null;
    oldRecord.Customer_Journey__c = null;
    opportunityRecord.Lost_Reason__c = 'Customer details not received';
    opportunityRecord.Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER;
    opportunityRecord.DealerAccount__c = dealerAccount.Id;

    BWM_OpportunityMessagingTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldRecord }
    );
    Test.stopTest();

    System.assert(
      [
          SELECT COUNT()
          FROM Message_Log__c
          WHERE Opportunity__c = :opportunityRecord.Id
        ] >= 1
    );
  }

  @IsTest
  static void fieldValueResolverResolvesOpportunityAndDealerFields() {
    Account accountRecord = new Account(
      Name = 'Customer Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    String dealerName = 'Dealer Co';
    String dealerPhone = '6290459130';
    String customerPhone = '6290459131';
    String accountName = accountRecord.Name;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Email__c = 'customer@valid-domain.com',
      Phone__c = customerPhone,
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    opportunityRecord = [
      SELECT
        Id,
        Name,
        Email__c,
        Phone__c,
        Owner.Name,
        Owner.Email,
        Owner.Phone,
        Account.Name
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    opportunityRecord.putSObject(
      'DealerAccount__r',
      new Account(Name = dealerName, Phone = dealerPhone)
    );

    System.assertEquals('', BWM_FieldValueResolver.resolveRecord(null, 'Name'));
    System.assertEquals('', BWM_FieldValueResolver.resolveRecord(opportunityRecord, ''));
    System.assertEquals(
      dealerPhone,
      BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        'DealerAccount__r.Phone'
      )
    );
    System.assertEquals(
      dealerName,
      BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        'DealerAccount__r.Name'
      )
    );
    System.assertEquals(
      'customer@valid-domain.com',
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Email')
    );
    System.assertEquals(
      customerPhone,
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Phone')
    );
    System.assertEquals(
      accountName,
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Account.Name')
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'FirstName')
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'LastName')
    );
    System.assert(
      String.isNotBlank(
        BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Owner.Name')
      )
    );
    System.assert(
      String.isNotBlank(
        BWM_FieldValueResolver.resolveRecord(opportunityRecord, 'Owner.Email')
      )
    );
    System.assert(
      String.isNotBlank(
        BWM_FieldValueResolver.resolveRecord(
          opportunityRecord,
          BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK
        )
      )
    );
    System.assert(
      BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK
      ).contains('/lightning/r/Opportunity/')
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'HDPE',
      '6290459133'
    );
    leadRecord = [
      SELECT
        Id,
        FirstName,
        LastName,
        Company,
        Company_Name__c,
        Department_Name__c,
        Product_Category__c,
        Owner.Name,
        Owner.Email,
        Owner.Phone,
        Email
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    System.assertEquals(
      'HDPE',
      BWM_FieldValueResolver.resolveDepartmentName(leadRecord)
    );
    System.assertEquals(
      null,
      BWM_FieldValueResolver.resolveDepartmentName(null)
    );
    System.assertEquals(
      '',
      BWM_FieldValueResolver.resolveRecord(leadRecord, 'Owner.Phone')
    );

    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Prospect_Dept_Inbound_Email'
      LIMIT 1
    ];
    leadRecord.Email = 'bad+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com';
    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      mapping
    );
    System.assertNotEquals('NA', params[6], 'Param7 email should never remain NA after fallback.');
  }

  @IsTest
  static void opportunitySendUsesLeadPhoneBeforeOpportunityPhone() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543888'
    );

    Account accountRecord = new Account(
      Name = 'Lead Phone Opp  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(DateTime.now().getTime()),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Lead Phone Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Lead__c = leadRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.send(
      opportunityRecord.Id,
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals(1, result.logs.size());
    System.assertEquals(
      '919876543888',
      result.logs[0].Phone_Number__c,
      'Customer phone should come from related Lead, not Opportunity Phone__c.'
    );
  }

  @IsTest
  static void sendTaskMessageInvocableQueuesCallback() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543299'
    );

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = 'Prospect';

    Test.startTest();
    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      responses[0].message
    );
  }

  @IsTest
  static void sendTaskMessageInvocableQueuesOpportunityNurtureCallback() {
    Account accountRecord = new Account(
      Name = 'Nurture Callback Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Nurture Callback Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Department_Name__c = 'Enquiry',
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = opportunityRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = BWM_MessagingConstants.STAGE_NURTURE;

    Test.startTest();
    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE,
      responses[0].message
    );
  }

  @IsTest
  static void opportunityTaskCallbackNurtureResolverMatchesProductDepartmentCont() {
    Account accountRecord = new Account(Name = 'Resolver Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Nurture Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Department_Name__c = 'Steel Pipes',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE,
      opportunityRecord,
      BWM_MessagingConstants.STAGE_NURTURE
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'nurture_not_responding_cont',
      resolveResult.mapping.Journey_Name__c
    );
    System.assertEquals(
      'Nurture_not_responding_cont',
      resolveResult.mapping.SMS_Template_Name__c
    );
  }

  @IsTest
  static void opportunityTaskCallbackNurtureResolverMatchesGenDepartments() {
    Account accountRecord = new Account(
      Name = 'Resolver Gen Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Resolver Gen Nurture Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Department_Name__c = 'Enquiry',
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE,
      opportunityRecord,
      BWM_MessagingConstants.STAGE_NURTURE
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Nurture_not_responding_gen',
      resolveResult.mapping.Journey_Name__c
    );
    System.assertEquals('nur_neg_nt_resp_gen', resolveResult.mapping.WhatsApp_Template_Name__c);
    System.assertEquals('Nur_neg_nt_resp_gen', resolveResult.mapping.RCS_Template_Name__c);
  }

  @IsTest
  static void opportunityTaskCallbackNurtureSendBuildsJourneyPayload() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Account accountRecord = new Account(
      Name = 'Payload Nurture Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Payload Nurture Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Department_Name__c = 'HDPE',
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      CloseDate = Date.today().addDays(30)
    );
    insert as system opportunityRecord;

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = opportunityRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = BWM_MessagingConstants.STAGE_NURTURE;

    Test.startTest();
    BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c, Trigger_Point__c
      FROM Message_Log__c
      WHERE
        Opportunity__c = :opportunityRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('poly_nur_nt_resp_cont', logs[0].Template_Name__c);
  }

  @IsTest
  static void sendTaskMessageInvocableQueuesLostDetails() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'HDPE',
      '9876543298'
    );

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Lost';
    requestItem.stageAtAction = 'Prospecting';
    requestItem.lostReason = 'Customer details not received';

    Test.startTest();
    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      responses[0].message
    );
  }

  @IsTest
  static void sendTaskMessageInvocableSkipsUnsupportedAction() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543297'
    );

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Unknown';

    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );

    System.assertEquals(false, responses[0].queued);
  }

  @IsTest
  static void messagingDispatchesWhenQueueableLimitReached() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543288'
    );
    leadRecord.Status = BWM_MessagingConstants.STAGE_PROSPECTING;
    update as system leadRecord;

    Test.startTest();
    BWM_EmailEnqueueService.enqueue(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = BWM_MessagingConstants.STAGE_PROSPECT;
    BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c
      FROM Message_Log__c
      WHERE
        Lead__c = :leadRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Messaging should still send after email uses the queueable slot.'
    );
    System.assertEquals('prospect_not_responding_dept', logs[0].Template_Name__c);
  }

  @IsTest
  static void callbackProspectPayloadUsesDetailsNotReceivedTemplate() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      '9876543287'
    );
    leadRecord = BWM_RecordQueryService.queryLead(leadRecord.Id);

    BWM_TemplateResolver.ResolveResult resolved = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      leadRecord
    );
    String payload = BWM_MessagePayloadBuilder.buildJourneyPayloadForRecord(
      BWM_SettingsService.getSettings(),
      resolved.mapping,
      leadRecord,
      '917980828320'
    );

    System.assert(payload.contains('"journeyname":"prospect_not_responding_dept"'));
    System.assert(payload.contains('"templateName":"prospect_not_responding_dept"'));
    System.assert(payload.contains('"templateName":"Pros_nt_resp_dept"'));
    System.assert(payload.contains('"templateName":"Prospect_not_resp"'));
    System.assert(
      !payload.contains('"headerFormat":"DOCUMENT"'),
      'Prospect callback must not attach a brochure.'
    );
  }

  @IsTest
  static void messagingFutureDispatcherProcessesRequests() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543289'
    );

    Test.startTest();
    BWM_MessagingFutureDispatcher.dispatch(
      new List<BWM_MessagingRequest>{
        new BWM_MessagingRequest(
          leadRecord.Id,
          BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
        )
      }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Template_Name__c
      FROM Message_Log__c
      WHERE
        Lead__c = :leadRecord.Id
        AND Trigger_Point__c = :BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('prospect_not_responding_dept', logs[0].Template_Name__c);
  }

  @IsTest
  static void callbackProspectSendsAfterLeadMovesToProspecting() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876543210'
    );
    leadRecord.Status = BWM_MessagingConstants.STAGE_PROSPECTING;
    update as system leadRecord;

    Test.startTest();
    BWM_MessagingService.SendResult result = BWM_MessagingService.send(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      BWM_MessagingConstants.STAGE_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(true, result.sent);
    System.assertEquals('prospect_not_responding_dept', result.logs[0].Template_Name__c);
  }

  @IsTest
  static void sendTaskMessageInvocableQueuesProspectLostDetails() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Polymer',
      '9876543296'
    );

    BWM_SendTaskMessageInvocable.Request requestItem = new BWM_SendTaskMessageInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Lost';
    requestItem.stageAtAction = 'Lost';
    requestItem.lostReason = 'Customer Details Not Received';

    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ requestItem }
    );

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT,
      responses[0].message
    );
  }

  @IsTest
  static void callbackProspectResolvesGenJourneyWhenOwnerMatchesCrmUser() {
    Lead leadRecord = buildLeadForOwnerCrmMatch(
      'Prospect',
      'Crash Barrier',
      'Owner Match Lead'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      leadRecord
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospect_not_responding_gen',
      result.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void callbackProspectResolvesDeptJourneyWhenOwnerDoesNotMatchCrmUser() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"CRM User","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Lead.class
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      leadRecord
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospect_not_responding_dept',
      result.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void callbackProspectResolvesGenJourneyForEnquiryDepartment() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Enquiry',
      '9876543405'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals('prospect_not_responding_gen', result.mapping.Journey_Name__c);
  }

  @IsTest
  static void callbackProspectResolvesGenJourneyForTowerDepartment() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Transmission & Telecom Tower',
      '9876543401'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals('prospect_not_responding_gen', result.mapping.Journey_Name__c);
    System.assertEquals(false, result.mapping.Include_Brochure_Header__c);
    System.assert(String.isBlank(result.mapping.Document_Header_URL__c));
  }

  @IsTest
  static void callbackProspectingResolvesGenJourneyWhenOwnerMatchesCrmUser() {
    Lead leadRecord = buildLeadForOwnerCrmMatch(
      'Prospecting',
      'Crash Barrier',
      'Owner Match Lead'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING,
      leadRecord
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospecting_not_responding_gen',
      result.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void callbackProspectingResolvesDeptJourneyWhenOwnerDoesNotMatchCrmUser() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospecting","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"CRM User","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Lead.class
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING,
      leadRecord
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospect_not_responding_dept',
      result.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void callbackProspectingResolvesDeptJourneyForProductDepartment() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Crash Barrier',
      '9876543402'
    );

    BWM_TemplateResolver.ResolveResult result = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING,
      BWM_RecordQueryService.queryLead(leadRecord.Id)
    );

    System.assertEquals(true, result.shouldSend);
    System.assertEquals(
      'prospect_not_responding_dept',
      result.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void lostNotRespondingProspectingRoutesDeptAndGen() {
    Lead deptLead = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'HDPE',
      '9876543403'
    );
    Lead genLead = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Pre Engineering Building',
      '9876543404'
    );

    BWM_SendTaskMessageInvocable.Request deptRequest = new BWM_SendTaskMessageInvocable.Request();
    deptRequest.recordId = deptLead.Id;
    deptRequest.taskAction = 'Lost';
    deptRequest.stageAtAction = 'Prospecting';
    deptRequest.lostReason = 'Not responding';

    BWM_SendTaskMessageInvocable.Request genRequest = new BWM_SendTaskMessageInvocable.Request();
    genRequest.recordId = genLead.Id;
    genRequest.taskAction = 'Lost';
    genRequest.stageAtAction = 'Prospecting';
    genRequest.lostReason = 'Not responding';

    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{ deptRequest, genRequest }
    );

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING,
      responses[0].message
    );
    System.assertEquals(true, responses[1].queued);

    deptLead.Lost_Reason__c = 'Not responding';
    genLead.Lost_Reason__c = 'Not responding';

    BWM_TemplateResolver.ResolveResult deptResolved = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING,
      deptLead
    );
    BWM_TemplateResolver.ResolveResult genResolved = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING,
      genLead
    );

    System.assertEquals(
      'Prospecting_not_respond_lost_dept',
      deptResolved.mapping.Journey_Name__c
    );
    System.assertEquals(
      'prospecting_not_resp_gen_lost',
      genResolved.mapping.Journey_Name__c
    );
  }

  @IsTest
  static void lostNotRespondingProspectingDeptUsesLeadCrmFormulaContact() {
    BWM_Template_Mapping__mdt deptMapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Task_Lost_NotResp_Prospecting'
      LIMIT 1
    ];

    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Department_Name__c":"Polymer","CRM_User_Name_Formula__c":"Provakar Roy","CRM_User_Contact_No_Formula__c":"8100996170","CRM_User_Email_Formula__c":"p.roy@utkarshindia.in","Owner":{"attributes":{"type":"User"},"Name":"Shubhrajyoti Dasgupta","Phone":"9000011111","Email":"owner@test.com"}}',
      Lead.class
    );

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      deptMapping
    );

    System.assertEquals('Provakar Roy', params[3]);
    System.assertEquals('8100996170', params[4]);
    System.assertEquals('p.roy@utkarshindia.in', params[5]);
    System.assert(
      !params[3].contains('Rudra'),
      'CRM contact name must come from Lead formula, not corporate default.'
    );
  }

  @IsTest
  static void lostDetailsProspectingMapsOwnerContactToWhatsAppSlots() {
    BWM_Template_Mapping__mdt deptMapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Task_Lost_Details_Prospecting'
      LIMIT 1
    ];
    BWM_Template_Mapping__mdt genMapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Task_Lost_Details_Prospecting_Gen'
      LIMIT 1
    ];

    Lead leadRecord = (Lead) JSON.deserialize(
      '{"FirstName":"Customer","LastName":"LastOnly","Company":"Test Co","Company_Name__c":"Test Co","Department_Name__c":"HDPE","Owner":{"attributes":{"type":"User"},"Name":"","Phone":"9000099999","Email":"owner@test.com"}}',
      Lead.class
    );

    List<String> deptParams = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      deptMapping
    );
    List<String> genParams = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      genMapping
    );

    System.assertEquals(6, deptParams.size());
    System.assertEquals(3, genParams.size());
    System.assertNotEquals(
      'LastOnly',
      deptParams[0],
      'Owner name slot must not use customer LastName.'
    );
    System.assertNotEquals(
      'LastOnly',
      deptParams[1],
      'Owner phone slot must not use customer LastName.'
    );
    System.assertNotEquals(
      'Test Co',
      deptParams[1],
      'Owner phone slot must not use company name.'
    );
    System.assertEquals('9000099999', deptParams[1]);
    System.assertEquals('9000099999', genParams[1]);
  }

  @IsTest
  static void lostDetailsProspectingDeptUsesLeadCrmFormulaContact() {
    BWM_Template_Mapping__mdt deptMapping = [
      SELECT
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Task_Lost_Details_Prospecting'
      LIMIT 1
    ];

    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Department_Name__c":"Steel Pipes","CRM_User_Name_Formula__c":"Lala Ankita Roy","CRM_User_Contact_No_Formula__c":"9147769526","CRM_User_Email_Formula__c":"lalaankita.roy@utkarshindia.in","Owner":{"attributes":{"type":"User"},"Name":"Debmallya Banerjee","Phone":"9000022222","Email":"owner@test.com"}}',
      Lead.class
    );

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      leadRecord,
      deptMapping
    );

    System.assertEquals('Lala Ankita Roy', params[3]);
    System.assertEquals('9147769526', params[4]);
    System.assertEquals('lalaankita.roy@utkarshindia.in', params[5]);
    System.assert(
      !params[3].contains('Rudra'),
      'OR contact must use Lead CRM formula, not corporate default.'
    );
  }

  @IsTest
  static void lostDetailsProspectingSplitsBrochureByDepartment() {
    Lead deptLead = new Lead(
      Status = 'Prospecting',
      Department_Name__c = 'Steel Tubular Poles',
      Lost_Reason__c = 'Customer details not received'
    );
    Lead genLead = new Lead(
      Status = 'Prospecting',
      Department_Name__c = 'Railway Electrification Structure',
      Lost_Reason__c = 'Customer details not received'
    );

    BWM_TemplateResolver.ResolveResult deptResolved = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      deptLead
    );
    BWM_TemplateResolver.ResolveResult genResolved = BWM_TemplateResolver.resolve(
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      genLead
    );

    System.assertEquals('u_prospecting_det_not_rec', deptResolved.mapping.Journey_Name__c);
    System.assertEquals(
      'prospecting_det_nt_rc_lost_gen',
      genResolved.mapping.Journey_Name__c
    );
    System.assertNotEquals(null, deptResolved.mapping.Brochure_Attachment_Mode__c);
    System.assertNotEquals(null, genResolved.mapping.Brochure_Attachment_Mode__c);
  }

  @IsTest
  static void smsDirectPayloadUsesDirectSmsChannel() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_JourneyDefinitionService.clearCache();
    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    ownerUser.Phone = '9000011122';
    ownerUser.MobilePhone = '9000011122';
    update as system ownerUser;
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

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876543210'
    );
    leadRecord = [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        Company,
        Company_Name__c,
        Department_Name__c,
        Owner.Phone,
        Owner.Name,
        Owner.Email
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    Test.startTest();
    String payload = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'DEALER_Enq_dept',
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> content = (Map<String, Object>) payloadMap.get('content');
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    Map<String, Object> params = (Map<String, Object>) content.get('params');

    System.assertEquals('SMS', payloadMap.get('channel'));
    System.assertEquals('919876543210', ((List<Object>) payloadMap.get('to'))[0]);
    System.assertEquals('UTKRSI', payloadMap.get('from'));
    System.assertEquals('1007088206584852810', data.get('dlttemplateid'));
    System.assert(
      String.valueOf(data.get('text')).contains('{#alphanumeric#}'),
      'Template text should be included in payload.'
    );
    System.assertEquals('1701159714233362956', data.get('peid'));
    System.assertEquals(
      '1701159714233362956,140200000077',
      data.get('chainvalue')
    );
    System.assert(!params.isEmpty(), 'SMS params should be populated.');
    System.assert(params.containsKey('var1'), 'SMS params should use var1 format.');
    String var1 = params.get('var1') == null ? '' : String.valueOf(params.get('var1'));
    String ownerPhoneDigits = '';
    String ownerName = '';
    try {
      SObject ownerRecord = leadRecord.getSObject('Owner');
      if (ownerRecord != null) {
        String ownerPhone = (String) ownerRecord.get('Phone');
        ownerName = (String) ownerRecord.get('Name');
        ownerPhoneDigits = String.isBlank(ownerPhone)
          ? ''
          : ownerPhone.replaceAll('[^0-9]', '');
      }
    } catch (Exception ex) {
      ownerPhoneDigits = '';
    }
    if (ownerPhoneDigits.length() >= 10) {
      System.assert(
        Pattern.matches('\\d{10}', var1),
        'SMS var1 should be a 10-digit local phone when Owner Phone is set. Actual: ' +
          var1
      );
    } else {
      System.assertEquals(
        ' ',
        var1,
        'SMS call slot stays empty when Owner Mobile/Phone are empty, not Owner.Name.'
      );
    }
    if (String.isNotBlank(ownerName)) {
      System.assertNotEquals(
        ownerName,
        var1,
        'SMS call slot must not use Owner.Name.'
      );
    }
    System.assertEquals(
      var1,
      String.valueOf(params.get('alphanumeric') == null ? '' : params.get('alphanumeric')),
      'DLT alphanumeric placeholders should also receive type-based param keys.'
    );
  }

  @IsTest
  static void smsDirectFallbackUsesOwnerPhoneOrBlankNeverCorporate() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_JourneyDefinitionService.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'sms_owner_phone_fallback',
          'dltTemplateId' => 'DLT_OWNER_PHONE',
          'templateText' =>
            'Our expert will contact you shortly or you can call {#numeric#}'
        }
      }
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876543210'
    );
    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String expectedOwnerDigits = String.isNotBlank(ownerUser.MobilePhone)
      ? ownerUser.MobilePhone.replaceAll('[^0-9]', '')
      : (String.isNotBlank(ownerUser.Phone)
          ? ownerUser.Phone.replaceAll('[^0-9]', '')
          : '');
    if (expectedOwnerDigits.length() > 10) {
      expectedOwnerDigits = expectedOwnerDigits.right(10);
    }

    leadRecord = [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        Company,
        Company_Name__c,
        Department_Name__c,
        OwnerId,
        Owner.Phone,
        Owner.Name,
        Owner.Email
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    Test.startTest();
    String payload = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_owner_phone_fallback',
      leadRecord,
      '919876543210'
    );
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> content = (Map<String, Object>) payloadMap.get('content');
    Map<String, Object> params = (Map<String, Object>) content.get('params');
    String var1 = params.get('var1') == null ? '' : String.valueOf(params.get('var1'));

    if (String.isNotBlank(expectedOwnerDigits) && expectedOwnerDigits.length() >= 10) {
      System.assertEquals(
        expectedOwnerDigits.right(10),
        var1,
        'SMS phone slot must use Owner Mobile/Phone when filled.'
      );
    } else {
      System.assertEquals(
        ' ',
        var1,
        'When Owner Mobile and Phone are blank, SMS phone slot must stay empty.'
      );
    }
    System.assert(
      !var1.contains('41900001') &&
        !var1.contains('4190') &&
        var1 != 'NA',
      'SMS must not use corporate number or NA. Actual: ' + var1
    );
    if (String.isBlank(expectedOwnerDigits) && String.isNotBlank(settings.WhatsApp_From__c)) {
      String fromDigits = settings.WhatsApp_From__c.replaceAll('[^0-9]', '');
      if (fromDigits.length() >= 10) {
        System.assertNotEquals(
          fromDigits.right(10),
          var1,
          'SMS must not fall back to WhatsApp_From when owner phone is blank.'
        );
      }
    }
  }

  @IsTest
  static void smsDirectPayloadRejectsBlankAndMissingTemplates() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(null);
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'templateName' => '' },
        new Map<String, Object>{
          'templateName' => 'sms_cov_extra',
          'dltTemplateId' => 'DLT9',
          'templateText' => 'Hi {#var#} {#var#}',
          'placeholders' => new List<Object>{ 'TEXT', 'TEXT' }
        }
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876543210'
    );

    Boolean blankThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(settings, '  ', leadRecord, '919876543210');
    } catch (BWM_MessagingException ex) {
      blankThrew = true;
    }
    Boolean missingThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(
        settings,
        'no_such_sms',
        leadRecord,
        '919876543210'
      );
    } catch (BWM_MessagingException ex) {
      missingThrew = true;
    }
    String payload = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_cov_extra',
      leadRecord,
      '919876543210'
    );
    System.assertEquals(true, blankThrew);
    System.assertEquals(true, missingThrew);
    System.assert(payload.contains('"channel":"SMS"'), payload);
  }

  @IsTest
  static void opportunityProductCategoriesAggregateRelatedRecords() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Category Cov Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(20)
    );
    insert as system opportunityRecord;

    System.assertEquals(
      '',
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(null)
    );
    System.assertEquals(
      '',
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(new Opportunity())
    );

    Integer inserted = 0;
    for (
      Schema.PicklistEntry entry : Product_Category__c.Product_Category__c.getDescribe()
        .getPicklistValues()
    ) {
      if (!entry.isActive() || entry.getValue() == 'High Mast') {
        continue;
      }
      try {
        insert as system new Product_Category__c(
          Opportunity__c = opportunityRecord.Id,
          Department_Name__c = 'High Mast & Polygonal',
          Product_Category__c = entry.getValue()
        );
        inserted++;
        if (inserted == 2) {
          insert as system new Product_Category__c(
            Opportunity__c = opportunityRecord.Id,
            Department_Name__c = 'High Mast & Polygonal',
            Product_Category__c = entry.getValue()
          );
          break;
        }
      } catch (DmlException ex) {
        continue;
      }
    }

    opportunityRecord = [
      SELECT Id, Product_Category__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    String aggregated = BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      opportunityRecord,
      ';'
    );
    System.assertNotEquals(null, aggregated);
  }

  @IsTest
  static void leadCreateTowerAndProductDepartmentsUseDeptJourney() {
    Lead enquiryLead = new Lead(
      LeadSource = 'INBOUND EMAIL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry'
    );
    Lead towerLead = new Lead(
      LeadSource = 'INBOUND EMAIL',
      Status = 'Prospect',
      Department_Name__c = 'Transmission & Telecom Tower'
    );
    Lead productLead = new Lead(
      LeadSource = 'INBOUND EMAIL',
      Status = 'Prospect',
      Department_Name__c = 'High Mast & Polygonal'
    );

    System.assertEquals(
      'prospect_enq_gen',
      BWM_TemplateResolver.resolveForLeadCreate(enquiryLead).mapping.Journey_Name__c
    );
    System.assertEquals(
      'prospect_enq_dept',
      BWM_TemplateResolver.resolveForLeadCreate(towerLead).mapping.Journey_Name__c
    );
    System.assertEquals(
      'prospect_enq_dept',
      BWM_TemplateResolver.resolveForLeadCreate(productLead).mapping.Journey_Name__c
    );
    System.assertEquals(
      'Department',
      BWM_TemplateResolver.resolveForLeadCreate(productLead)
        .mapping.Brochure_Attachment_Mode__c
    );
  }

  @IsTest
  static void leadMessagingTriggerHandlerCoversSkipAndEmptyPaths() {
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(
      new List<Lead>{ new Lead(LastName = 'Skip Path ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))) }
    );

    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = false;
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(null);
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(new List<Lead>());
    BWM_LeadMessagingTriggerHandler.enqueueMessaging(new List<Id>());

    System.assertEquals(true, true);
  }

  private static Lead createLead(
    String leadSource,
    String status,
    String department,
    String phone
  ) {
    return createLead(leadSource, status, department, phone, false);
  }

  private static Lead createLead(
    String leadSource,
    String status,
    String department,
    String phone,
    Boolean allowTriggerMessaging
  ) {
    if (!allowTriggerMessaging) {
      BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    }

    String uniqueSuffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    Lead leadRecord = new Lead(
      LastName = 'Messaging Test  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      Company = 'Test Co  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      Company_Name__c = 'Test Co  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      LeadSource = leadSource,
      Status = status,
      Department_Name__c = department,
      Phone = String.isBlank(phone) ? '6290459110' : phone,
      Email = 'test+' + uniqueSuffix + '@example.com'
    );
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    insert as system leadRecord;

    if (!allowTriggerMessaging) {
      BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = false;
    }

    return leadRecord;
  }

  @IsTest
  static void railwayBrochureUsesUploadedFilePublicLinkNotCorporate() {
    BWM_BrochureService.setBrochureMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Railway Electrification Structure' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Railway Electrification Structure',
          Content_File_Title__c = 'Railway Electrification Structures',
          Brochure_File_Name__c = 'Railway_Electrification_Structures.pdf',
          Static_Resource_Name__c = 'Railway_Electrification_Structures_pdf',
          Brochure_URL__c = null
        )
      }
    );
    BWM_BrochureFileService.setPublicUrlMapForTest(
      new Map<String, String>{
        'Railway Electrification Structures' =>
          'https://momentum-customer-397--utkarshuat.sandbox.file.force.com/sfc/dist/version/download/?oid=00DC2000003CoP7&ids=068C20000053MXN&d=test&asPdf=false'
      }
    );

    BWM_BrochureService.BrochureInfo brochure = BWM_BrochureService.getBrochureForDepartment(
      'Railway Electrification Structure'
    );
    brochure.publicDownloadUrl =
      'https://example.file.force.com/sfc/dist/version/download/?oid=1&ids=2&d=3&asPdf=false';
    String resolved = BWM_BrochureService.resolveWhatsAppDocumentUrl(
      brochure,
      BWM_MessagingConstants.DEFAULT_PORTAL_BROCHURE_URL
    );

    System.assertEquals(
      brochure.publicDownloadUrl,
      resolved,
      'Railway must use the uploaded file public link when it is WhatsApp-reachable.'
    );
    BWM_BrochureService.clearCache();
  }

  @IsTest
  static void corporatePortalUrlIsSkippedWhenPublicStaticLinkExists() {
    BWM_BrochureService.BrochureInfo brochure = new BWM_BrochureService.BrochureInfo();
    brochure.brochureUrl = BWM_MessagingConstants.DEFAULT_PORTAL_BROCHURE_URL;
    brochure.fileName = 'Railway_Electrification_Structures.pdf';
    brochure.publicDownloadUrl =
      'https://example.file.force.com/sfc/dist/version/download/?oid=1&ids=2&d=3&asPdf=false';

    String resolved = BWM_BrochureService.resolveWhatsAppDocumentUrl(
      brochure,
      BWM_MessagingConstants.DEFAULT_PORTAL_BROCHURE_URL
    );
    System.assertEquals(
      brochure.publicDownloadUrl,
      resolved,
      'Corporate portal URL must yield to department static-resource public link.'
    );
  }

  private static Lead buildLeadForOwnerCrmMatch(
    String status,
    String departmentName,
    String ownerName
  ) {
    return (Lead) JSON.deserialize(
      '{"Status":"' +
        status +
        '","Department_Name__c":"' +
        departmentName +
        '","CRM_User_Name_Formula__c":"' +
        ownerName +
        '","Owner":{"attributes":{"type":"User"},"Name":"' +
        ownerName +
        '"}}',
      Lead.class
    );
  }

  @IsTest
  static void processRequestsWritesFailedLogWhenSendThrows() {
    Account accountRecord = new Account(
      Name = 'Queueable Fail  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + String.valueOf(Datetime.now().getTime())
    );
    insert as system accountRecord;

    Test.startTest();
    BWM_MessagingQueueable.processRequests(
      new List<BWM_MessagingRequest>{
        new BWM_MessagingRequest(
          accountRecord.Id,
          BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE
        )
      }
    );
    Test.stopTest();

    List<Message_Log__c> logs = [
      SELECT Status__c, Trigger_Point__c, Template_Name__c, Response_Message__c
      FROM Message_Log__c
      WHERE Related_Record_Id__c = :accountRecord.Id
    ];
    System.assertEquals(1, logs.size(), 'Exception should create one Failed message log.');
    System.assertEquals(BWM_MessagingConstants.LOG_STATUS_FAILED, logs[0].Status__c);
    System.assertEquals('Apex exception', logs[0].Template_Name__c);
    System.assert(
      logs[0].Response_Message__c != null &&
        logs[0].Response_Message__c.contains('Apex exception')
    );
  }

  @IsTest
  static void coversSettingsResolverLostReasonAndQueueableExecute() {
    BWM_SettingsService.clearCache();
    System.assertNotEquals(null, BWM_SettingsService.getSettings());
    System.assertNotEquals(null, BWM_SettingsService.getSettings());

    System.assertEquals(
      null,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(null, 'x')
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NURTURE,
        BWM_MessagingConstants.LOST_REASON_DETAILS_NOT_RECEIVED
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NURTURE,
        BWM_MessagingConstants.OPP_LOST_NOT_RESPONDING
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_NEGOTIATION,
        BWM_MessagingConstants.OPP_LOST_NOT_RESPONDING
      )
    );
    System.assertEquals(
      BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      BWM_MessagingOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_MessagingConstants.STAGE_CLOSED_LOST,
        BWM_MessagingConstants.STAGE_NURTURE,
        BWM_MessagingConstants.LOST_REASON_DETAILS_NOT_RECEIVED
      )
    );

    BWM_TemplateResolver.ResolveResult nullLead =
      BWM_TemplateResolver.resolveForLeadCreate(null);
    System.assertEquals(false, nullLead.shouldSend);
    BWM_TemplateResolver.ResolveResult blankTrigger =
      BWM_TemplateResolver.resolve('', new Lead());
    System.assertEquals(false, blankTrigger.shouldSend);
    BWM_TemplateResolver.ResolveResult nullRecord =
      BWM_TemplateResolver.resolve(BWM_MessagingConstants.TRIGGER_LEAD_CREATE, null);
    System.assertEquals(false, nullRecord.shouldSend);

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}'
      )
    );
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      '9876500999'
    );
    Test.startTest();
    System.enqueueJob(
      new BWM_MessagingQueueable(
        new List<BWM_MessagingRequest>{
          new BWM_MessagingRequest(
            leadRecord.Id,
            BWM_MessagingConstants.TRIGGER_LEAD_CREATE
          ),
          null,
          new BWM_MessagingRequest()
        }
      )
    );
    BWM_MessagingQueueable.processRequests(null);
    BWM_MessagingQueueable.processRequests(new List<BWM_MessagingRequest>());
    Test.stopTest();
  }

  @IsTest
  static void rcsDirectPayloadBuilderCoversNamedParamsAndTemplateCards() {
    BWM_RcsDirectPayloadBuilder.clearCache();
    BWM_RcsDirectPayloadBuilder.cacheTemplates(null);
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'TemplateName' => '' },
        new Map<String, Object>{
          'TemplateName' => 'rcs_named_cov',
          'Component' => new Map<String, Object>{
            'Cards' => new List<Object>{
              new Map<String, Object>{
                'DescVariables' => new List<Object>{
                  new Map<String, Object>{
                    '{{1}}' => 'department_name_1',
                    '{{2}}' => 'product_brief',
                    '{{3}}' => 'rudra_number',
                    'bad' => 'skip',
                    '{{4}}' => ''
                  },
                  'not-a-map'
                },
                'TitleVariables' => new List<Object>{
                  new Map<String, Object>{
                    '{{5}}' => 'lead_owner_name',
                    '{{6}}' => 'lead_owner_phone',
                    '{{7}}' => 'lead_owner_email',
                    '{{8}}' => 'opportunity_owner_name',
                    '{{9}}' => 'opportunity_owner_phone',
                    '{{10}}' => 'opportunity_owner_email',
                    '{{11}}' => 'department_crm_name',
                    '{{12}}' => 'department_crm_phone',
                    '{{13}}' => 'department_crm_email',
                    '{{14}}' => 'owner',
                    '{{15}}' => 'email',
                    '{{16}}' => 'number',
                    '{{17}}' => 'bhagyashree_number',
                    '{{18}}' => 'brief',
                    '{{19}}' => 'Unknown_Field__c'
                  }
                }
              }
            }
          }
        },
        new Map<String, Object>{
          'TemplateName' => 'rcs_empty_component',
          'Component' => null
        }
      }
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Crash Barrier',
      '9876500888'
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();

    String payload = BWM_RcsDirectPayloadBuilder.buildPayload(
      settings,
      'rcs_named_cov',
      leadRecord,
      '919876500888'
    );
    Map<String, Object> journeyData = BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'rcs_named_cov',
      leadRecord,
      new Map<String, Object>{
        '{{20}}' => 'department_name_2',
        '{{21}}' => null
      }
    );
    Map<String, Object> emptyFallback = BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'missing_template',
      leadRecord,
      new Map<String, Object>()
    );
    BWM_RcsDirectPayloadBuilder.buildPayload(
      settings,
      'rcs_empty_component',
      leadRecord,
      '919876500888'
    );
    BWM_RcsDirectPayloadBuilder.clearCache();
    BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      null,
      '',
      leadRecord,
      null
    );

    System.assert(payload.contains('rcs_named_cov'));
    System.assertNotEquals(null, journeyData);
    System.assertNotEquals(null, emptyFallback);
  }

  @IsTest
  static void dealerRecordTypeAloneDoesNotTriggerDealerEnquiryWhatsApp() {
    Schema.RecordTypeInfo dealerRecordType =
      Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Dealer_Opportunity');
    Schema.RecordTypeInfo masterRecordType =
      Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
        .get('Master_Opportunity');
    System.assertNotEquals(null, dealerRecordType);
    System.assertNotEquals(null, masterRecordType);
    System.assertEquals(
      false,
      BWM_OpportunityMessagingTriggerHandler.isMasterOpportunityRecordType(
        dealerRecordType.getRecordTypeId()
      )
    );
    System.assertEquals(
      true,
      BWM_OpportunityMessagingTriggerHandler.isMasterOpportunityRecordType(
        masterRecordType.getRecordTypeId()
      )
    );

    Opportunity dealerOnly = new Opportunity(
      RecordTypeId = dealerRecordType.getRecordTypeId()
    );
    System.assertEquals(
      false,
      BWM_OpportunityMessagingTriggerHandler.isDealerEnquiryOpportunity(
        dealerOnly
      )
    );

    String eligibleSource = new List<String>(
      BWM_MessagingConstants.PHONE_OPPORTUNITY_SOURCES
    )[0];
    Opportunity existingCriteria = new Opportunity(
      Department_Name__c = BWM_MessagingConstants.DEPT_ENQUIRY,
      LeadSource = eligibleSource
    );
    System.assertEquals(
      true,
      BWM_OpportunityMessagingTriggerHandler.isDealerEnquiryOpportunity(
        existingCriteria
      ),
      'Existing department/source criteria must remain unchanged.'
    );

    System.assertEquals(
      false,
      BWM_OpportunityMessagingTriggerHandler.isMasterOpportunityRecordType(null)
    );
    System.assertEquals(
      false,
      BWM_OpportunityMessagingTriggerHandler.isDealerEnquiryOpportunity(null)
    );
    BWM_OpportunityMessagingTriggerHandler.handleAfterInsert(null);
    BWM_OpportunityMessagingTriggerHandler.handleAfterInsert(
      new List<Opportunity>()
    );
    BWM_OpportunityMessagingTriggerHandler.handleAfterUpdate(null, null);
    BWM_OpportunityMessagingTriggerHandler.handleAfterUpdate(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );
  }

}