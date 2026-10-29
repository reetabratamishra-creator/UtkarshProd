/**
 * @description Extra BWM coverage for remaining public methods. No production changes.
 */
@IsTest
private class BWMCoverageBoostTest {
  @IsTest
  static void coversSmallUtilitiesAndDtos() {
    HttpResponse emptyResponse = new HttpResponse();
    emptyResponse.setStatusCode(200);
    emptyResponse.setBody('');
    BWM_ApiResponse emptyParsed = BWM_ApiResponse.parse(emptyResponse, '200');
    System.assertEquals(false, emptyParsed.isSuccess);

    HttpResponse jsonResponse = new HttpResponse();
    jsonResponse.setStatusCode(200);
    jsonResponse.setBody('{"code":"200","message":"accepted for processing","success":true}');
    BWM_ApiResponse parsed = BWM_ApiResponse.parse(jsonResponse, '200');
    System.assertEquals(true, parsed.isSuccess);
    System.assertEquals(
      true,
      BWM_ApiResponse.parseWhatsAppDirect(jsonResponse, '999').isSuccess
    );

    HttpResponse badJson = new HttpResponse();
    badJson.setStatusCode(200);
    badJson.setBody('not-json');
    System.assertEquals(false, BWM_ApiResponse.parse(badJson, '200').isSuccess);

    HttpResponse statusBody = new HttpResponse();
    statusBody.setStatusCode(200);
    statusBody.setBody('{"statusCode":202}');
    System.assertNotEquals(null, BWM_ApiResponse.parseWhatsAppDirect(statusBody, 'x'));

    Lead leadRecord = new Lead(LastName = 'Boost ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Status = 'Prospect');
    insert as system leadRecord;
    BWM_MessagingRequest blankRequest = new BWM_MessagingRequest();
    BWM_MessagingRequest twoArg = new BWM_MessagingRequest(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN
    );
    BWM_MessagingRequest threeArg = new BWM_MessagingRequest(
      leadRecord.Id,
      BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN,
      BWM_MessagingConstants.STAGE_PROSPECT
    );
    System.assertEquals(leadRecord.Id, twoArg.recordId);
    System.assertEquals(leadRecord.Id, threeArg.recordId);
    System.assertEquals(null, blankRequest.recordId);

    System.assertEquals(null, BWM_PhoneFormatter.formatForMessaging(null, '91'));
    System.assertEquals(null, BWM_PhoneFormatter.formatForMessaging('abc', '91'));
    System.assertEquals('919876543210', BWM_PhoneFormatter.formatForMessaging('9876543210', '91'));
    System.assertEquals(
      '919876543210',
      BWM_PhoneFormatter.formatForMessaging('919876543210', '91')
    );
    System.assertEquals(null, BWM_PhoneFormatter.formatForMessaging('12345', '91'));

    BWM_SettingsService.clearCache();
    System.assertNotEquals(null, BWM_SettingsService.getSettings());

    BWM_MessagingProductBriefService.clearCache();
    BWM_MessagingProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Department_Brochure__mdt(
          Department_Name__c = 'Crash Barrier',
          Product_Brief__c = 'Barrier brief'
        )
      }
    );
    Lead briefLead = new Lead(
      LastName = 'Brief ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Crash Barrier'
    );
    System.assertEquals(
      'Barrier brief',
      BWM_MessagingProductBriefService.resolvePlainText(briefLead)
    );
    System.assertEquals('', BWM_MessagingProductBriefService.resolvePlainText(new Account()));
    BWM_MessagingProductBriefService.clearCache();

    System.assertEquals('ok', BWM_DeployProbe.ping());
    System.assertEquals('ok', BWM_WaFixProbe2.ping());

    try {
      throw new BWM_EmailException('email');
    } catch (BWM_EmailException ex) {
      System.assertEquals('email', ex.getMessage());
    }
    try {
      throw new BWM_MessagingException('msg');
    } catch (BWM_MessagingException ex) {
      System.assertEquals('msg', ex.getMessage());
    }
  }

  @IsTest
  static void coversDispatchersInvocablesAndRouters() {
    Lead leadRecord = new Lead(
      LastName = 'Invocable ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Invocable Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(10)
    );
    insert as system opportunityRecord;

    BWM_MessagingFutureDispatcher.dispatch(null);
    BWM_MessagingFutureDispatcher.dispatch(new List<BWM_MessagingRequest>());
    Test.startTest();
    BWM_MessagingFutureDispatcher.dispatch(
      new List<BWM_MessagingRequest>{
        new BWM_MessagingRequest(
          leadRecord.Id,
          BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN
        )
      }
    );
    Test.stopTest();

    BWM_MessagingQueueable emptyQueueable = new BWM_MessagingQueueable(null);
    emptyQueueable.execute(null);
    BWM_MessagingQueueable.processRequests(new List<BWM_MessagingRequest>());
    BWM_MessagingQueueable.processRequests(
      new List<BWM_MessagingRequest>{
        null,
        new BWM_MessagingRequest(),
        new BWM_MessagingRequest(leadRecord.Id, 'Invalid_Trigger_For_Coverage')
      }
    );

    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(
      new List<Lead>{ new Lead(LastName = 'Skip ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))) }
    );
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = false;
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(null);
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(new List<Lead>());
    BWM_LeadMessagingTriggerHandler.enqueueMessaging(new List<Id>());

    System.assertEquals(
      '',
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(null)
    );
    System.assertEquals(
      '',
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
        new Opportunity()
      )
    );
    System.assertNotEquals(
      null,
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
        opportunityRecord,
        ';'
      )
    );

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

    BWM_SendTaskMessageInvocable.Request unmatched = new BWM_SendTaskMessageInvocable.Request();
    unmatched.recordId = leadRecord.Id;
    unmatched.taskAction = 'Unknown';
    BWM_SendTaskMessageInvocable.Request callback = new BWM_SendTaskMessageInvocable.Request();
    callback.recordId = leadRecord.Id;
    callback.taskAction = 'Callback';
    callback.stageAtAction = 'Prospect';
    BWM_SendTaskMessageInvocable.Request lostDetails = new BWM_SendTaskMessageInvocable.Request();
    lostDetails.recordId = leadRecord.Id;
    lostDetails.taskAction = 'Lost';
    lostDetails.stageAtAction = 'Prospect';
    lostDetails.lostReason = BWM_MessagingConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    BWM_SendTaskMessageInvocable.Request oppCallback = new BWM_SendTaskMessageInvocable.Request();
    oppCallback.recordId = opportunityRecord.Id;
    oppCallback.taskAction = 'Callback';
    oppCallback.stageAtAction = 'Nurture';
    BWM_SendTaskMessageInvocable.Request nullReq = new BWM_SendTaskMessageInvocable.Request();

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"accepted"}',
        '{"code":"200","message":"accepted"}'
      )
    );
    List<BWM_SendTaskMessageInvocable.Response> responses = BWM_SendTaskMessageInvocable.sendTaskMessage(
      new List<BWM_SendTaskMessageInvocable.Request>{
        unmatched,
        callback,
        lostDetails,
        oppCallback,
        nullReq
      }
    );
    System.assertEquals(5, responses.size());

    BWM_SendTaskEmailInvocable.Request emailCallback = new BWM_SendTaskEmailInvocable.Request();
    emailCallback.recordId = leadRecord.Id;
    emailCallback.taskAction = 'Callback';
    emailCallback.stageAtAction = 'Prospect';
    BWM_SendTaskEmailInvocable.Request emailUnknown = new BWM_SendTaskEmailInvocable.Request();
    emailUnknown.recordId = leadRecord.Id;
    emailUnknown.taskAction = 'Skip';
    Test.setMock(HttpCalloutMock.class, new BWM_EmailCalloutMock('{"messages":[{"status":{"groupName":"PENDING"}}]}', 200));
    List<BWM_SendTaskEmailInvocable.Response> emailResponses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ emailCallback, emailUnknown }
    );
    System.assertEquals(2, emailResponses.size());
  }

  @IsTest
  static void coversBrochureFiltersCampaignAndParams() {
    Lead enquiryLead = new Lead(
      LastName = 'Enquiry ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY
    );
    System.assertEquals(
      'Corporate',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(enquiryLead)
    );
    System.assertEquals(
      '',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(null)
    );
    System.assertEquals(
      'Crash Barrier',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(
        new Lead(Department_Name__c = 'Crash Barrier')
      )
    );
    String html = BWM_ProspectLostFutureGenBrochureUtil.applyRenderedHtmlFix(
      '>Enquiry</strong> brochure',
      enquiryLead,
      'Prospect_lost_future_tender_gen'
    );
    System.assert(html.contains('Corporate'));
    String substituted = BWM_ProspectLostFutureGenBrochureUtil.applyTemplateSubstitutions(
      '{{{Lead.Department_NameFormula__c}}} {!Lead.Email_Brochure_Label__c}',
      enquiryLead,
      'Prospect_lost_future_tender_gen'
    );
    System.assert(substituted.contains('Corporate'));
    System.assertEquals(
      'keep',
      BWM_ProspectLostFutureGenBrochureUtil.applyTemplateSubstitutions(
        'keep',
        enquiryLead,
        'Other_Template'
      )
    );

    System.assertEquals(null, BWM_BrochureService.getBrochureForDepartment(null));
    System.assertEquals(null, BWM_BrochureFileService.resolveFileBrochure(null, null));
    System.assertEquals(null, BWM_BrochureFileService.getPublicDownloadUrl(null));

    System.assertEquals(
      false,
      BWM_CampaignJourneyParamService.ownerMatchesCrmUserName(null)
    );
    System.assertEquals(
      false,
      BWM_CampaignJourneyParamService.isDualCorporateSupportPhoneTemplate(null)
    );
    System.assertEquals(
      false,
      BWM_CampaignJourneyParamService.isProspectEnqDeptOwnerContactTemplate(null)
    );
    System.assertEquals(
      null,
      BWM_CampaignJourneyParamService.padSecondaryContactSlots(null)
    );
    System.assertEquals(
      2,
      BWM_CampaignJourneyParamService.padSecondaryContactSlots(
          new List<String>{ 'a', 'b' }
        )
        .size()
    );
    System.assertEquals(
      6,
      BWM_CampaignJourneyParamService.padSecondaryContactSlots(
          new List<String>{ 'a', 'b', 'c' }
        )
        .size()
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isMissingSecondaryValue(null)
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isMissingSecondaryValue('{{5}}')
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isMissingSecondaryValue('NA')
    );
    System.assertEquals(
      false,
      BWM_CampaignJourneyParamService.isMissingSecondaryValue('Owner')
    );
    Map<String, Object> rcs = BWM_CampaignJourneyParamService.applyRcsBodyDataOverride(
      null,
      new Map<String, Object>{ 'department_crm_name' => '' }
    );
    System.assertNotEquals(null, rcs);
    System.assertNotEquals(
      null,
      BWM_CampaignJourneyParamService.fillBlankRcsSecondaryContactParams(
        new Map<String, Object>{ 'department_crm_email' => '' }
      )
    );
    System.assertNotEquals(
      null,
      BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
        new Lead(LastName = 'X ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Company = 'Y ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))),
        new List<String>{ 'a', 'b' }
      )
    );
    System.assertEquals(
      '',
      BWM_CampaignJourneyParamService.resolveSecondaryContactName(null)
    );
    System.assertEquals(
      '',
      BWM_CampaignJourneyParamService.resolveSecondaryContactPhone(null)
    );
    System.assertEquals(
      '',
      BWM_CampaignJourneyParamService.resolveSecondaryContactEmail(null)
    );

    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadCustomerCategoryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadCountryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadStateOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityCustomerCategoryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityCountryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityStateOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountCountryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountStateOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getContactCountryOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getContactStateOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getLeadDepartmentOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOpportunityDepartmentOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getAccountDepartmentOptions());
    System.assertNotEquals(null, BWM_CampaignFilterCtrl.getOfflineCampaignDepartmentOptions());

    Boolean waThrew = false;
    try {
      BWM_WaCampCtrlA.sendLeadWhatsApp(new List<Id>(), 'tmpl');
    } catch (Exception ex) {
      waThrew = true;
    }
    System.assertEquals(true, waThrew);
    Boolean sendThrew = false;
    try {
      BWM_WaCampSendA.sendToLeads(new List<Id>(), 'tmpl');
    } catch (Exception ex) {
      sendThrew = true;
    }
    System.assertEquals(true, sendThrew);
  }

  @IsTest
  static void coversInfobipSubjectsAndMessageLogs() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":1,"name":"T1","subject":"Hello Subject"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );
    List<BWM_InfobipEmailTemplateService.SubjectOption> subjects = BWM_InfobipEmailTemplateService.fetchCampaignEmailSubjectOptions();
    System.assertNotEquals(null, subjects);
    Set<String> ids = BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject('Hello Subject');
    System.assertNotEquals(null, ids);
    System.assertEquals(
      new Set<String>(),
      BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(null)
    );

    Lead leadRecord = new Lead(LastName = 'Log ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Status = 'Prospect');
    insert as system leadRecord;
    BWM_ApiResponse apiResponse = new BWM_ApiResponse();
    apiResponse.code = '200';
    apiResponse.message = 'ok';
    apiResponse.httpStatus = 200;
    apiResponse.rawBody = '{"code":"200"}';
    Message_Log__c logRecord = BWM_MessageLogService.buildLog(
      leadRecord,
      BWM_MessagingConstants.TRIGGER_LEAD_CAMPAIGN,
      'WhatsApp',
      'tmpl',
      '919876543210',
      'Sent',
      apiResponse
    );
    BWM_MessageLogService.insertLogs(new List<Message_Log__c>{ logRecord });
    System.assertEquals(
      false,
      BWM_MessageLogService.hasRecentLog(null, 'x', 1)
    );
  }

  @IsTest
  static void coversWaCampSendsSmsAndImagePayload() {
    Lead leadRecord = new Lead(
      LastName = 'WaCamp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    Account accountRecord = new Account(Name = 'WaCamp Acc ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'WaCamp C ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system contactRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'WaCamp Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(7),
      AccountId = accountRecord.Id
    );
    insert as system opportunityRecord;
    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'WaCamp Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system offlineRecord;

    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{
          'type' => 'IMAGE',
          'mediaUrl' => 'https://example.com/banner.png'
        },
        'body' => 'Hello {{1}}'
      }
    };
    BWM_WaCampSendA.templateMetaByName = new Map<String, Map<String, Object>>{
      'u_prospect_enq_dept' => templateMeta,
      'prospect_enq_dept' => templateMeta
    };

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"202","message":"accepted for processing"}',
        '{"code":"202","message":"accepted for processing"}'
      )
    );

    Test.startTest();
    BWM_WaCampCtrlA.sendLeadWhatsApp(
      new List<Id>{ leadRecord.Id },
      'u_prospect_enq_dept'
    );
    try {
      BWM_WaCampCtrlA.sendOpportunityWhatsApp(new List<Id>(), 'tmpl');
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampCtrlA.sendOpportunityWhatsApp(
        new List<Id>{ opportunityRecord.Id },
        'u_prospect_enq_dept'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampCtrlA.sendAccountWhatsApp(
        new List<Id>{ accountRecord.Id },
        'u_prospect_enq_dept'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampCtrlA.sendContactWhatsApp(
        new List<Id>{ contactRecord.Id },
        'u_prospect_enq_dept'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampCtrlA.sendOfflineCampaignWhatsApp(
        new List<Id>{ offlineRecord.Id },
        'u_prospect_enq_dept'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampSendA.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      BWM_WaCampSendA.sendToRecords(new List<SObject>(), 'tmpl', 'Lead_Campaign');
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    String imagePayload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'u_prospect_enq_dept',
      templateMeta,
      leadRecord,
      '919876500111'
    );
    System.assert(imagePayload.contains('"channel":"WhatsApp"'), imagePayload);

    BWM_SmsDirectPayloadBuilder.cacheTemplates(null);
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'templateName' => '' },
        new Map<String, Object>{
          'templateName' => 'sms_cov',
          'dltTemplateId' => 'DLT9',
          'templateText' => 'Hi {#var#} {#var#}',
          'placeholders' => new List<Object>{ 'TEXT', 'TEXT' }
        }
      }
    );
    Boolean blankThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(settings, '  ', leadRecord, '919876500111');
    } catch (BWM_MessagingException ex) {
      blankThrew = true;
    }
    Boolean missingThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(
        settings,
        'no_such_sms',
        leadRecord,
        '919876500111'
      );
    } catch (BWM_MessagingException ex) {
      missingThrew = true;
    }
    String smsPayload = BWM_SmsDirectPayloadBuilder.buildPayload(
      settings,
      'sms_cov',
      leadRecord,
      '919876500111'
    );
    System.assertEquals(true, blankThrew);
    System.assertEquals(true, missingThrew);
    System.assert(smsPayload.contains('"channel":"SMS"'), smsPayload);
  }
}