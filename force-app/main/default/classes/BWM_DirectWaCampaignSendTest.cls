@IsTest
private class BWM_DirectWaCampaignSendTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  @IsTest
  static void sendToLeadsRequiresSelection() {
    Boolean threw = false;
    try {
      BWM_DirectWaCampaignSend.sendToLeads(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToLeadsRequiresTemplateName() {
    Lead leadRecord = createLead();
    Boolean threw = false;

    try {
      BWM_DirectWaCampaignSend.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (AuraHandledException ex) {
      threw = true;
    }

    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToLeadsHappyPathAndSkipNoPhone() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Lead withPhone = createLead();
    Lead noPhone = new Lead(
      LastName = 'No Phone Lead',
      Company = 'WA Test Co',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry'
    );
    insert noPhone;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToLeads(
        new List<Id>{ withPhone.Id, noPhone.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void sendToOpportunitiesHappyPath() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Account accountRecord = new Account(Name = 'WA Opp Account', Phone = '9876543210');
    insert accountRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'WA Opp',
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30),
      Phone__c = '9876543211',
      Department_Name__c = 'Enquiry'
    );
    insert opportunityRecord;

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void sendToRecordsHappyPath() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Account accountRecord = new Account(
      Name = 'Generic WA Account',
      Phone = '9876543222'
    );
    insert accountRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToRecords(
        new List<SObject>{ accountRecord },
        'u_dealer_enq_dept',
        'Account_Campaign'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void sendToRecordsRequiresSelection() {
    Boolean threw = false;
    try {
      BWM_DirectWaCampaignSend.sendToRecords(
        new List<SObject>(),
        'u_dealer_enq_dept',
        'Account_Campaign'
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToOpportunitiesRequiresSelection() {
    Boolean threw = false;
    try {
      BWM_DirectWaCampaignSend.sendToOpportunities(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToOpportunitiesRequiresTemplateName() {
    Account accountRecord = new Account(Name = 'Validation Opp Account');
    insert accountRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Validation Opp',
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30)
    );
    insert opportunityRecord;

    Boolean threw = false;
    try {
      BWM_DirectWaCampaignSend.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        ''
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToOpportunitiesSkipsWhenNoPhone() {
    seedTemplateCache('u_dealer_enq_dept');

    Account accountRecord = new Account(Name = 'No Phone Opp Account');
    insert accountRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'No Phone Opp',
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Enquiry'
    );
    insert opportunityRecord;

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void sendToLeadsHandlesFailedApiResponse() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock('INVALID_JSON_BODY', 'INVALID_JSON_BODY')
    );

    Lead leadRecord = createLead();

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void sendToLeadsLoadsTemplateCacheFromApi() {
    BWM_DirectWaCampaignSend.clearCache();
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(TEMPLATES_BODY, SUCCESS_BODY)
    );

    Lead leadRecord = createLead();

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertNotEquals(null, BWM_DirectWaCampaignSend.templateMetaByName);
  }

  @IsTest
  static void sendToLeadsSkipsWhenPhoneMatchesFromNumber() {
    seedTemplateCache('u_dealer_enq_dept');

    Lead leadRecord = new Lead(
      LastName = 'From Number Lead',
      Company = 'WA Test Co',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Phone = '919830637280'
    );
    insert leadRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void sendToRecordsRequiresTemplateName() {
    Account accountRecord = new Account(Name = 'Template Validation Account');
    insert accountRecord;

    Boolean threw = false;
    try {
      BWM_DirectWaCampaignSend.sendToRecords(
        new List<SObject>{ accountRecord },
        '',
        'Account_Campaign'
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void sendToRecordsContactHappyPath() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Account accountRecord = new Account(Name = 'Contact WA Account');
    insert accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'WA Contact',
      AccountId = accountRecord.Id,
      Phone = '9876543244'
    );
    insert contactRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToRecords(
        new List<SObject>{ contactRecord },
        'u_dealer_enq_dept',
        'Contact_Campaign'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void sendToLeadsHandlesCalloutException() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(HttpCalloutMock.class, new ThrowingPostCalloutMock());

    Lead leadRecord = createLead();

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      BWM_DirectWaCampaignSend.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
    System.assertEquals(1, result.messages.size());
  }

  private static final String TEMPLATES_BODY =
    '{"total_pages":1,"templates":[{"name":"u_dealer_enq_dept","language":"en","content":{"header":{"type":"TEXT"},"body":"Hello"}}]}';

  private class ThrowingPostCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      if (request.getMethod() == 'POST') {
        throw new CalloutException('Simulated callout failure');
      }

      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody(TEMPLATES_BODY);
      return response;
    }
  }

  @IsTest
  static void clearCacheResetsTemplateMetadata() {
    seedTemplateCache('u_dealer_enq_dept');
    BWM_DirectWaCampaignSend.clearCache();
    System.assertEquals(null, BWM_DirectWaCampaignSend.templateMetaByName);
  }

  private static Lead createLead() {
    Lead leadRecord = new Lead(
      LastName = 'Direct WA Lead',
      Company = 'WA Test Co',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Phone = '9876543233',
      Email = 'directwa@example.com'
    );
    insert leadRecord;
    return leadRecord;
  }

  private static void seedTemplateCache(String templateName) {
    BWM_DirectWaCampaignSend.clearCache();
    BWM_DirectWaCampaignSend.templateMetaByName = new Map<String, Map<String, Object>>{
      templateName => new Map<String, Object>{
        'language' => 'en',
        'content' => new Map<String, Object>{
          'header' => new Map<String, Object>{ 'type' => 'TEXT' },
          'body' => 'Hello {{1}}'
        }
      }
    };
  }
}