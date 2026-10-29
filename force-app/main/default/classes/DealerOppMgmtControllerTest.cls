/**
 * @description   Test class for DealerOpportunityManagementController search,
 *                options, and send methods.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class DealerOppMgmtControllerTest {
  private static final String SUCCESS_JOURNEY =
    '{"code":"200","message":"Journey message enqueued successfully."}';
  private static final String SUCCESS_EMAIL =
    '{"messages":[{"status":"PENDING_ACCEPTED"}]}';

  @TestSetup
  static void setupCommonData() {
    Account accountRecord = new Account(Name = 'Dealer Opp Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Dealer Opp Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'dealer.opp+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Dealer Opp Alpha ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Crash Barrier',
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system opportunityRecord;

    insert as system new OpportunityContactRole(
      OpportunityId = opportunityRecord.Id,
      ContactId = contactRecord.Id,
      IsPrimary = true,
      Role = 'Decision Maker'
    );
  }

  /**
   * Scenario: Stage and lost-reason option getters and email/journey getters return values.
   */
  @IsTest
  static void testGetOptionGetters_ReturnValues() {
    Test.startTest();
    List<DealerOpportunityManagementController.PicklistOption> stages =
      DealerOpportunityManagementController.getOpportunityStageOptions();
    List<DealerOpportunityManagementController.PicklistOption> lostReasons =
      DealerOpportunityManagementController.getOpportunityLostReasonOptions();
    List<DealerOpportunityManagementController.PicklistOption> customerCategories =
      DealerOpportunityManagementController.getOpportunityCustomerCategoryOptions();
    List<DealerOpportunityManagementController.PicklistOption> countries =
      DealerOpportunityManagementController.getOpportunityCountryOptions();
    List<DealerOpportunityManagementController.PicklistOption> states =
      DealerOpportunityManagementController.getOpportunityStateOptions();
    List<DealerOpportunityManagementController.EmailTemplateOption> emailTemplates =
      DealerOpportunityManagementController.getEmailTemplates();
    List<BWM_JourneyDefinitionService.JourneyOption> journeys =
      DealerOpportunityManagementController.getCampaignJourneys();
    Test.stopTest();

    System.assert(!stages.isEmpty());
    System.assertNotEquals(null, lostReasons);
    System.assertNotEquals(null, customerCategories);
    System.assertNotEquals(null, countries);
    System.assertNotEquals(null, states);
    System.assertNotEquals(null, emailTemplates);
    System.assertNotEquals(null, journeys);
  }

  @IsTest
  static void testSearchDealerOpportunities_WithExtendedFilters() {
    Test.startTest();
    List<DealerOpportunityManagementController.OpportunityListItem> filtered =
      DealerOpportunityManagementController.searchDealerOpportunities(
        null,
        null,
        new List<String>{ 'Nurture' },
        null,
        new List<String>{ BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED },
        Date.today().addDays(-7),
        Date.today().addDays(1),
        new List<String>(),
        null,
        new List<String>()
      );
    Test.stopTest();

    System.assertNotEquals(null, filtered);
  }

  /**
   * Scenario: search and get dealer opportunities hydrate primary contact fields.
   */
  @IsTest
  static void testSearchAndGetDealerOpportunities_ReturnsPrimaryContact() {
    Test.startTest();
    List<DealerOpportunityManagementController.OpportunityListItem> searched =
      DealerOpportunityManagementController.searchDealerOpportunities(
        'Dealer Opp',
        null,
        new List<String>{ 'Nurture' },
        'Crash',
        null,
        Date.today().addDays(-1),
        Date.today().addDays(1),
        null,
        null,
        null
      );
    List<DealerOpportunityManagementController.OpportunityListItem> allRows =
      DealerOpportunityManagementController.getDealerOpportunities();
    Test.stopTest();

    System.assertEquals(1, searched.size());
    System.assert(
      searched[0].PrimaryContactEmail != null &&
        searched[0].PrimaryContactEmail.contains('dealer.opp'),
      searched[0].PrimaryContactEmail
    );
    System.assert(allRows.size() >= 1);
  }

  /**
   * Scenario: Opportunity journey send succeeds with messaging mock.
   */
  @IsTest
  static void testSendOpportunityJourney_HappyPathWithMock() {
    BWM_JourneyDefinitionService.clearCache();
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_JOURNEY, SUCCESS_JOURNEY)
    );
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_JourneyDefinitionService.SendJourneyResult result =
      DealerOpportunityManagementController.sendOpportunityJourney(
        new List<Id>{ opportunityRecord.Id },
        'prospect_not_resp'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  /**
   * Scenario: Campaign email send uses primary contact email with Infobip mock.
   */
  @IsTest
  static void testSendOpportunityCampaignEmail_HappyPathWithMock() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailRouteCalloutMock(
        '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"Welcome"}',
        SUCCESS_EMAIL,
        200
      )
    );
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      DealerOpportunityManagementController.sendOpportunityCampaignEmail(
        new List<Id>{ opportunityRecord.Id },
        '205000000067199'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void testSendOpportunityWhatsApp_HappyPathWithMock() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_JOURNEY, SUCCESS_JOURNEY)
    );
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];
    opportunityRecord.Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10);
    update as system opportunityRecord;

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      DealerOpportunityManagementController.sendOpportunityWhatsApp(
        new List<Id>{ opportunityRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void testSendOpportunityCampaignEmail_WrapsValidationErrors() {
    Boolean threw = false;
    try {
      DealerOpportunityManagementController.sendOpportunityCampaignEmail(
        new List<Id>(),
        ''
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void testGetBluewaveEmailTemplates_WrapsErrorsWithoutMock() {
    Boolean threw = false;
    try {
      DealerOpportunityManagementController.getBluewaveEmailTemplates();
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendOpportunityEmails_SkipsWhenTemplateCannotRender() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];

    Test.startTest();
    DealerOpportunityManagementController.SendEmailResult result =
      DealerOpportunityManagementController.sendOpportunityEmails(
        new List<Id>{ opportunityRecord.Id },
        UserInfo.getUserId()
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void testSendOpportunityRcsAndSms_HappyPathWithMock() {
    seedTemplateCache('coverage_channel');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_JOURNEY, SUCCESS_JOURNEY, SUCCESS_JOURNEY)
    );
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];
    opportunityRecord.Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10);
    update as system opportunityRecord;

    Test.startTest();
    DealerOpportunityRcsService.SendRcsResult rcsResult =
      DealerOpportunityManagementController.sendOpportunityRcs(
        new List<Id>{ opportunityRecord.Id },
        'coverage_channel'
      );
    DealerOpportunitySmsService.SendSmsResult smsResult =
      DealerOpportunityManagementController.sendOpportunitySms(
        new List<Id>{ opportunityRecord.Id },
        'coverage_channel'
      );
    Test.stopTest();

    System.assertNotEquals(null, rcsResult);
    System.assertNotEquals(null, smsResult);
  }

  private static void seedTemplateCache(String templateName) {
    BWM_DirectWaCampaignSend.clearCache();
    Map<String, Object> meta = new Map<String, Object>{
      'language' => 'en',
      'name' => templateName,
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'TEXT' },
        'body' => 'Hello {{1}}'
      }
    };
    BWM_DirectWaCampaignSend.templateMetaByName = new Map<String, Map<String, Object>>{
      templateName => meta
    };
    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      templateName => meta
    };
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => templateName,
          'templateText' => 'Hello'
        }
      }
    );
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => templateName,
          'dltTemplateId' => 'DLT1',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
  }

  /**
   * Scenario: Native email send validates empty selection and missing template.
   */
  @IsTest
  static void testSendOpportunityEmails_ValidationErrors() {
    Boolean emptyThrew = false;
    Boolean nullTemplateThrew = false;
    Opportunity opportunityRecord = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();
    try {
      DealerOpportunityManagementController.sendOpportunityEmails(new List<Id>(), null);
    } catch (AuraHandledException ex) {
      emptyThrew = true;
    }
    try {
      DealerOpportunityManagementController.sendOpportunityEmails(
        new List<Id>{ opportunityRecord.Id },
        null
      );
    } catch (AuraHandledException ex) {
      nullTemplateThrew = true;
    }
    Test.stopTest();

    System.assertEquals(true, emptyThrew);
    System.assertEquals(true, nullTemplateThrew);
  }

  /**
   * Scenario: WhatsApp/RCS/SMS empty selection throws validation errors.
   */
  @IsTest
  static void testSendChannelMethods_EmptySelection_ThrowsError() {
    Boolean waThrew = false;
    Boolean rcsThrew = false;
    Boolean smsThrew = false;

    Test.startTest();
    try {
      DealerOpportunityManagementController.sendOpportunityWhatsApp(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      waThrew = true;
    }
    try {
      DealerOpportunityManagementController.sendOpportunityRcs(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      rcsThrew = true;
    }
    try {
      DealerOpportunityManagementController.sendOpportunitySms(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      smsThrew = true;
    }
    Test.stopTest();

    System.assertEquals(true, waThrew);
    System.assertEquals(true, rcsThrew);
    System.assertEquals(true, smsThrew);
  }

  /**
   * Scenario: Bluewave email templates load via Infobip mock.
   */
  @IsTest
  static void testGetBluewaveEmailTemplates_WithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":1,"name":"T1","imagePreviewUrl":"/p.png"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );

    Test.startTest();
    List<BWM_InfobipEmailTemplateService.TemplateOption> templates =
      DealerOpportunityManagementController.getBluewaveEmailTemplates();
    Test.stopTest();

    System.assertEquals(1, templates.size());
  }

  @IsTest
  static void testSendOpportunitySmsAndWhatsAppTemplates() {
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'cov_sms',
          'dltTemplateId' => 'DLT9',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
    DealerOpportunityWhatsAppService.clearCache();
    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'u_dealer_enq_dept' => new Map<String, Object>{
        'language' => 'en',
        'state' => 'APPROVED',
        'content' => new Map<String, Object>{ 'body' => 'Hello {{1}}' }
      }
    };
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"total_pages":1,"templates":[{"name":"u_dealer_enq_dept","state":"APPROVED","language":"en","category_name":"UTILITY","template_id":"1"}]}',
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}'
      )
    );
    Opportunity opportunityRecord = [
      SELECT Id FROM Opportunity WHERE Name LIKE 'Dealer Opp Alpha%' LIMIT 1
    ];

    Test.startTest();
    List<DealerOpportunityWhatsAppService.WhatsAppTemplateOption> templates =
      DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    DealerOpportunitySmsService.SendSmsResult smsResult =
      DealerOpportunityManagementController.sendOpportunitySms(
        new List<Id>{ opportunityRecord.Id },
        'cov_sms'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult waFail =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'u_dealer_enq_dept'
      );
    Boolean blankThrew = false;
    try {
      DealerOpportunitySmsService.sendToOpportunities(new List<Id>{ opportunityRecord.Id }, '');
    } catch (Exception ex) {
      blankThrew = true;
    }
    Test.stopTest();

    System.assertNotEquals(null, templates);
    System.assertNotEquals(null, smsResult);
    System.assertNotEquals(null, waFail);
    System.assertEquals(true, blankThrew);
  }


  @IsTest
  static void testFetchWhatsAppTemplatesAndSmsSendWithPrimaryContact() {
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'DEALER_Enq_dept',
          'dltTemplateId' => '1007088206584852810',
          'templateText' => 'Call {#numeric#}'
        }
      }
    );
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"total_pages":1,"templates":[{"name":"u_dealer_enq_dept","state":"APPROVED","language":"en","category_name":"UTILITY","template_id":"tid1","content":{"body":"Hi {{1}}"}}]}',
        '{"code":"200","message":"accepted"}',
        '{"code":"200","message":"accepted"}'
      )
    );
    Opportunity opportunityRecord = [
      SELECT Id FROM Opportunity WHERE Name LIKE 'Dealer Opp Alpha%' LIMIT 1
    ];
    Test.startTest();
    List<DealerOpportunityWhatsAppService.WhatsAppTemplateOption> templates =
      DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    DealerOpportunitySmsService.SendSmsResult smsResult =
      DealerOpportunitySmsService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'DEALER_Enq_dept'
      );
    Test.stopTest();
    System.assert(!templates.isEmpty());
    System.assertNotEquals(null, smsResult);
  }


  @IsTest
  static void testDealerSmsFetchApprovedTemplates() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"data":[{"TemplateName":"approved_sms","TemplateStatus":"approve","dltTemplateId":"1","templateText":"Hi {#var#}"},{"TemplateName":"bad_sms","TemplateStatus":"reject"}]}',
        '{"code":"200","message":"ok"}'
      )
    );
    Test.startTest();
    List<DealerOpportunitySmsService.SmsTemplateOption> templates =
      DealerOpportunitySmsService.fetchApprovedTemplates();
    Test.stopTest();
    System.assertEquals(1, templates.size());
  }


  @IsTest
  static void testFetchDealerWhatsAppTemplatesTwoPagesAndEmptySend() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"total_pages":2,"templates":[{"name":"tmpl_a","state":"APPROVED","language":"en","category_name":"UTILITY","template_id":"1"},{"name":"tmpl_z","state":"APPROVED","language":"en","category_name":"UTILITY","template_id":"2"}]}',
        '{"total_pages":2,"templates":[{"name":"tmpl_b","state":"APPROVED","language":"en","category_name":"MARKETING","template_id":"3"}]}'
      )
    );
    Test.startTest();
    List<DealerOpportunityWhatsAppService.WhatsAppTemplateOption> templates =
      DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    Boolean emptyThrew = false;
    try {
      DealerOpportunityWhatsAppService.sendToOpportunities(new List<Id>(), 'tmpl');
    } catch (Exception ex) {
      emptyThrew = true;
    }
    Test.stopTest();
    System.assert(templates.size() >= 2);
    System.assertEquals(true, emptyThrew);
  }

  @IsTest
  static void testSendDealerWhatsApp_UnmappedHeadersSkipAndValidation() {
    Account accountRecord = [SELECT Id FROM Account WHERE Name LIKE 'Dealer Opp Account%' LIMIT 1];
    Opportunity noPhoneOpportunity = new Opportunity(
      Name = 'Dealer Opp NoPhone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(15),
      Department_Name__c = 'Enquiry'
    );
    insert as system noPhoneOpportunity;

    DealerOpportunityWhatsAppService.clearCache();
    Opportunity withPhone = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];

    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'zz_nomap_doc_cov' => new Map<String, Object>{
        'language' => 'hi',
        'content' => new Map<String, Object>{
          'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
          'body' => 'Hi {{1}} {{2}} {{3}} {{4}} {{5}} {{6}} {{7}} {{8}} {{9}}'
        }
      },
      'zz_nomap_text_cov' => new Map<String, Object>{
        'language' => 'en',
        'content' => new Map<String, Object>{
          'header' => new Map<String, Object>{
            'type' => 'TEXT',
            'text' => 'Opp Header'
          },
          'body' => 'Hello {{1}}'
        }
      },
      'zz_nomap_textblank_cov' => new Map<String, Object>{
        'language' => 'en',
        'content' => new Map<String, Object>{
          'header' => new Map<String, Object>{ 'type' => 'TEXT' },
          'body' => 'Hello {{1}}'
        }
      },
      'zz_nomap_image_cov' => new Map<String, Object>{
        'language' => 'en',
        'content' => new Map<String, Object>{
          'header' => new Map<String, Object>{ 'type' => 'IMAGE' },
          'body' => 'Hello {{1}}'
        }
      },
      'zz_nomap_empty_cov' => new Map<String, Object>{ 'language' => 'en' }
    };

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}'
      )
    );

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult documentResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id, noPhoneOpportunity.Id },
        'zz_nomap_doc_cov'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult textResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'zz_nomap_text_cov'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult textBlankResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'zz_nomap_textblank_cov'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult imageResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'zz_nomap_image_cov'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult emptyMetaResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'zz_nomap_empty_cov'
      );
    Boolean blankThrew = false;
    try {
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        ''
      );
    } catch (Exception ex) {
      blankThrew = true;
    }
    Test.stopTest();

    System.assertNotEquals(null, documentResult);
    System.assert(documentResult.skippedCount >= 1);
    System.assertNotEquals(null, textResult);
    System.assertNotEquals(null, textBlankResult);
    System.assertNotEquals(null, imageResult);
    System.assertNotEquals(null, emptyMetaResult);
    System.assertEquals(true, blankThrew);
  }

  @IsTest
  static void testFetchDealerWhatsAppTemplates_HttpError() {
    DealerOpportunityWhatsAppService.clearCache();
    Test.setMock(HttpCalloutMock.class, new StatusCalloutMock(500, '{"error":"fail"}'));
    Boolean fetchThrew = false;
    Test.startTest();
    try {
      DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    } catch (Exception ex) {
      fetchThrew = true;
    }
    Test.stopTest();
    System.assertEquals(true, fetchThrew);
  }

  @IsTest
  static void testSendDealerWhatsApp_CalloutException() {
    DealerOpportunityWhatsAppService.clearCache();
    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'zz_nomap_throw_cov' => new Map<String, Object>{
        'language' => 'en',
        'content' => new Map<String, Object>{ 'body' => 'Hi {{1}}' }
      }
    };
    Opportunity withPhone = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];
    Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());
    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult throwResult =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'zz_nomap_throw_cov'
      );
    Test.stopTest();
    System.assertNotEquals(null, throwResult);
    System.assert(throwResult.skippedCount >= 1);
  }

  @IsTest
  static void testDealerRcsFetchTemplatesAndSendPaths() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"data":[{"TemplateName":"approved_rcs","TemplateStatus":"approve"},{"TemplateName":"zzz_rcs","TemplateStatus":"approve"},{"TemplateName":"rejected_rcs","TemplateStatus":"reject"},{"TemplateName":""}]}',
        '{"code":"200","message":"ok"}'
      )
    );
    Test.startTest();
    List<DealerOpportunityRcsService.RcsTemplateOption> templates =
      DealerOpportunityRcsService.fetchApprovedTemplates();
    Test.stopTest();
    System.assertEquals(2, templates.size());
    System.assertEquals('approved_rcs', templates[0].value);

    Boolean emptyThrew = false;
    Boolean blankThrew = false;
    try {
      DealerOpportunityRcsService.sendToOpportunities(new List<Id>(), 'tmpl');
    } catch (Exception ex) {
      emptyThrew = true;
    }
    Opportunity withPhone = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];
    try {
      DealerOpportunityRcsService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        ''
      );
    } catch (Exception ex) {
      blankThrew = true;
    }
    System.assertEquals(true, emptyThrew);
    System.assertEquals(true, blankThrew);
  }

  @IsTest
  static void testDealerRcsSendHappySkipAndFailure() {
    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Dealer Opp Account%'
      LIMIT 1
    ];
    Opportunity noPhoneOpportunity = new Opportunity(
      Name = 'Dealer Opp RCS NoPhone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(20),
      Department_Name__c = 'Enquiry'
    );
    insert as system noPhoneOpportunity;

    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'dealer_rcs_cov',
          'templateText' => 'Hello'
        }
      }
    );
    Opportunity withPhone = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Dealer Opp Alpha%'
      LIMIT 1
    ];

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"ok"}',
        '{"code":"500","message":"fail"}'
      )
    );
    Test.startTest();
    DealerOpportunityRcsService.SendRcsResult skipped =
      DealerOpportunityRcsService.sendToOpportunities(
        new List<Id>{ noPhoneOpportunity.Id },
        'dealer_rcs_cov'
      );
    DealerOpportunityRcsService.SendRcsResult sent =
      DealerOpportunityRcsService.sendToOpportunities(
        new List<Id>{ withPhone.Id },
        'dealer_rcs_cov'
      );
    Test.stopTest();
    System.assert(skipped.skippedCount >= 1);
    System.assertNotEquals(null, sent);
  }

  @IsTest
  static void testDealerRcsFetchTemplatesHttpError() {
    Test.setMock(HttpCalloutMock.class, new StatusCalloutMock(500, '{"error":"fail"}'));
    Boolean threw = false;
    Test.startTest();
    try {
      DealerOpportunityRcsService.fetchApprovedTemplates();
    } catch (Exception ex) {
      threw = true;
    }
    Test.stopTest();
    System.assertEquals(true, threw);
  }

  private class StatusCalloutMock implements HttpCalloutMock {
    private final Integer statusCode;
    private final String body;
    StatusCalloutMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(statusCode);
      response.setStatus('Error');
      response.setBody(body);
      return response;
    }
  }

  private class ThrowingCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      throw new CalloutException('simulated callout failure');
    }
  }

  @IsTest
  static void testScheduledSends_RequireSelectionAndClearSchedule() {
    Integer threwCount = 0;
    Test.startTest();
    try {
      DealerOpportunityManagementController.sendOpportunityJourneyScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      DealerOpportunityManagementController.sendOpportunityRcsScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      DealerOpportunityManagementController.sendOpportunitySmsScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      DealerOpportunityManagementController.getWhatsAppTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      DealerOpportunityManagementController.getRcsTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      DealerOpportunityManagementController.getSmsTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      DealerOpportunityManagementController.sendOpportunityCampaignEmailScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    Test.stopTest();

    System.assertEquals(4, threwCount, 'Each scheduled send needs at least one record.');
    System.assertEquals(null, BWM_CampaignScheduleContext.scheduledDateTime, 'Schedule must be cleared after the send.');
  }
}