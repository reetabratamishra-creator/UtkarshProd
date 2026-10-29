/**
 * @description   Test class for BWM_CampaignEmailService Infobip campaign email
 *                send paths.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_CampaignEmailServiceTest {
  private static final String SUCCESS_BODY = '{"messages":[{"status":"PENDING_ACCEPTED"}]}';
  private static final String TEMPLATE_ID = '205000000067199';
  private static final String TEMPLATE_SUBJECT = 'Welcome to Utkarsh Steel';
  private static final String TEMPLATE_FROM =
    'Subhajit Ghosh <subhajit.ghosh@utkarshbharath.com>';
  private static final String TEMPLATE_REPLY_TO = 'sougata.das@utkarshindia.in';
  private static final String TEMPLATE_DETAIL_BODY =
    '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"' +
    TEMPLATE_SUBJECT +
    '","from":"' +
    TEMPLATE_FROM +
    '","replyTo":"' +
    TEMPLATE_REPLY_TO +
    '"}';

  private static HttpCalloutMock buildCampaignEmailMock(
    String sendResponseBody,
    Integer sendStatusCode
  ) {
    return new BWM_EmailRouteCalloutMock(
      TEMPLATE_DETAIL_BODY,
      sendResponseBody,
      sendStatusCode
    );
  }

  @TestSetup
  static void setupCommonData() {
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;

    Lead leadWithEmail = new Lead(
      LastName = 'Campaign Email Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company_Name__c = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Crash Barrier',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'campaign.lead+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    Lead leadNoEmail = new Lead(
      LastName = 'No Email Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company_Name__c = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Crash Barrier',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system new List<Lead>{ leadWithEmail, leadNoEmail };

    Account accountRecord = new Account(
      Name = 'Campaign Email Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'campaign.account@example.com'
    );
    insert as system accountRecord;

    Contact contactWithEmail = new Contact(
      LastName = 'Campaign Email Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'campaign.contact+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    Contact contactNoEmail = new Contact(
      LastName = 'No Email Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system new List<Contact>{ contactWithEmail, contactNoEmail };

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Campaign Email Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Crash Barrier'
    );
    insert as system opportunityRecord;

    insert as system new OpportunityContactRole(
      OpportunityId = opportunityRecord.Id,
      ContactId = contactWithEmail.Id,
      IsPrimary = true,
      Role = 'Decision Maker'
    );

    insert as system new Offline_Campaign__c(
      Name = 'Campaign Email Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'campaign.offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system new Offline_Campaign__c(
      Name = 'No Email Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Department__c = 'Crash Barrier',
      Active__c = true
    );
  }

  /**
   * Scenario: Validation requires at least one record Id and a template Id.
   */
  @IsTest
  static void testValidateRequest_EmptyIdsOrBlankTemplate_ThrowsError() {
    Boolean emptyIdsThrew = false;
    Boolean blankTemplateThrew = false;
    Lead leadRecord = [SELECT Id FROM Lead WHERE Email != null LIMIT 1];

    Test.startTest();
    try {
      BWM_CampaignEmailService.sendToLeads(new List<Id>(), TEMPLATE_ID);
    } catch (AuraHandledException ex) {
      emptyIdsThrew = true;
    }
    try {
      BWM_CampaignEmailService.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (AuraHandledException ex) {
      blankTemplateThrew = true;
    }
    Test.stopTest();

    System.assertEquals(true, emptyIdsThrew);
    System.assertEquals(true, blankTemplateThrew);
  }

  /**
   * Scenario: Lead with email sends successfully via Infobip mock; lead without email is skipped.
   */
  @IsTest
  static void testSendToLeads_HappyPathAndSkipNoEmail() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Lead withEmail = [SELECT Id FROM Lead WHERE Email != null LIMIT 1];
    Lead noEmail = [SELECT Id FROM Lead WHERE Email = null LIMIT 1];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      BWM_CampaignEmailService.sendToLeads(
        new List<Id>{ withEmail.Id, noEmail.Id },
        TEMPLATE_ID
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(1, result.skippedCount);
    System.assert(!result.messages.isEmpty());

    List<Email_Log__c> logs = [
      SELECT
        Campaign_Email_Subject__c,
        Template_Name__c,
        Status__c,
        From_Email__c,
        Request_Payload__c
      FROM Email_Log__c
      WHERE Related_Record_Id__c = :String.valueOf(withEmail.Id)
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('NABL_HIGH_MAST_2026', logs[0].Template_Name__c);
    System.assertEquals(TEMPLATE_SUBJECT, logs[0].Campaign_Email_Subject__c);
    System.assertEquals('Sent', logs[0].Status__c);
    System.assertEquals(TEMPLATE_FROM, logs[0].From_Email__c);
    System.assert(logs[0].Request_Payload__c.contains(TEMPLATE_FROM));
    System.assert(logs[0].Request_Payload__c.contains(TEMPLATE_REPLY_TO));
  }

  /**
   * Scenario: A scheduled campaign email sends options.schedule.sendAt in Infobip format.
   */
  @IsTest
  static void testScheduledLeadEmailAddsSendAt() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Lead withEmail = [SELECT Id FROM Lead WHERE Email != null WITH SYSTEM_MODE LIMIT 1];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      LeadManagementController.sendLeadCampaignEmailScheduled(
        new List<Id>{ withEmail.Id },
        TEMPLATE_ID,
        '2026-10-26T13:20:00Z'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(null, BWM_CampaignScheduleContext.scheduledDateTime, 'Schedule must be cleared.');
    Email_Log__c log = [
      SELECT Request_Payload__c
      FROM Email_Log__c
      WHERE Related_Record_Id__c = :String.valueOf(withEmail.Id)
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    System.assert(
      log.Request_Payload__c.contains('"sendAt":"2026-10-26T13:20:00.000Z"'),
      log.Request_Payload__c
    );
  }

  /**
   * Scenario: An unscheduled campaign email has no schedule option, and sendAt keeps the Infobip format.
   */
  @IsTest
  static void testSendAtFormatAndUnscheduledEmailHasNoSchedule() {
    System.assertEquals(null, BWM_CampaignEmailService.toInfobipSendAt(null));
    System.assertEquals(null, BWM_CampaignEmailService.toInfobipSendAt(' '));
    System.assertEquals(
      '2026-10-26T13:20:00.000Z',
      BWM_CampaignEmailService.toInfobipSendAt('2026-10-26T13:20:00Z')
    );
    System.assertEquals(
      '2026-10-26T13:20:00.000Z',
      BWM_CampaignEmailService.toInfobipSendAt('2026-10-26T13:20:00.000Z')
    );

    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Lead withEmail = [SELECT Id FROM Lead WHERE Email != null WITH SYSTEM_MODE LIMIT 1];

    Test.startTest();
    BWM_CampaignEmailService.sendToLeads(new List<Id>{ withEmail.Id }, TEMPLATE_ID);
    Test.stopTest();

    Email_Log__c log = [
      SELECT Request_Payload__c
      FROM Email_Log__c
      WHERE Related_Record_Id__c = :String.valueOf(withEmail.Id)
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    System.assert(!log.Request_Payload__c.contains('sendAt'), log.Request_Payload__c);
  }

  /**
   * Scenario: Opportunity campaign email uses primary contact email with mock callout.
   */
  @IsTest
  static void testSendToOpportunities_HappyPathWithPrimaryContact() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Campaign Email Opp%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      BWM_CampaignEmailService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        TEMPLATE_ID
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(0, result.skippedCount);
  }

  /**
   * Scenario: Account campaign email sends when Email__c is populated.
   */
  @IsTest
  static void testSendToAccounts_HappyPath() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Campaign Email Account%'
      LIMIT 1
    ];

    System.runAs(getAdminUser()) {
      Test.startTest();
      BWM_CampaignEmailService.SendCampaignEmailResult result =
        BWM_CampaignEmailService.sendToAccounts(
          new List<Id>{ accountRecord.Id },
          TEMPLATE_ID
        );
      Test.stopTest();

      System.assertEquals(1, result.sentCount);
    }
  }

  /**
   * Scenario: Contact campaign email sends or skips based on email presence.
   */
  @IsTest
  static void testSendToContacts_HappyPathAndSkipNoEmail() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Contact withEmail = [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE 'Campaign Email Contact%'
      LIMIT 1
    ];
    Contact noEmail = [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE 'No Email Contact%'
      LIMIT 1
    ];

    System.runAs(getAdminUser()) {
      Test.startTest();
      BWM_CampaignEmailService.SendCampaignEmailResult result =
        BWM_CampaignEmailService.sendToContacts(
          new List<Id>{ withEmail.Id, noEmail.Id },
          TEMPLATE_ID
        );
      Test.stopTest();

      System.assertEquals(1, result.sentCount);
      System.assertEquals(1, result.skippedCount);
    }
  }

  /**
   * Scenario: Offline campaign email sends or skips based on email presence.
   */
  @IsTest
  static void testSendToOfflineCampaigns_HappyPathAndSkipNoEmail() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock(SUCCESS_BODY, 200)
    );
    Offline_Campaign__c withOfflineEmail = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Campaign Email Offline%'
      LIMIT 1
    ];
    Offline_Campaign__c noOfflineEmail = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'No Email Offline%'
      LIMIT 1
    ];

    System.runAs(getAdminUser()) {
      Test.startTest();
      BWM_CampaignEmailService.SendCampaignEmailResult result =
        BWM_CampaignEmailService.sendToOfflineCampaigns(
          new List<Id>{ withOfflineEmail.Id, noOfflineEmail.Id },
          TEMPLATE_ID
        );
      Test.stopTest();

      System.assertEquals(1, result.sentCount);
      System.assertEquals(1, result.skippedCount);
    }
  }

  /**
   * Scenario: API failure response increments skipped count for Lead campaign email.
   */
  @IsTest
  static void testSendToLeads_ApiFailure_IncrementsSkipped() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock('{"description":"send failed"}', 500)
    );
    Lead withEmail = [SELECT Id FROM Lead WHERE Email != null LIMIT 1];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      BWM_CampaignEmailService.sendToLeads(new List<Id>{ withEmail.Id }, TEMPLATE_ID);
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void testSendToLeads_HandlesCalloutException() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(HttpCalloutMock.class, new ThrowingEmailPostCalloutMock());
    Lead withEmail = [
      SELECT Id
      FROM Lead
      WHERE LastName LIKE 'Campaign Email Lead%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      BWM_CampaignEmailService.sendToLeads(new List<Id>{ withEmail.Id }, TEMPLATE_ID);
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
    System.assertEquals(1, result.messages.size());
  }

  @IsTest
  static void testSendToOpportunities_SkipsWhenNoPrimaryContact() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Account accountRecord = new Account(Name = 'Opp Without Primary Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'No Primary Contact Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Crash Barrier'
    );
    insert as system opportunityRecord;

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      BWM_CampaignEmailService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        TEMPLATE_ID
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void testValidateRequest_EmptyAccountIds_ThrowsError() {
    Boolean threw = false;
    try {
      BWM_CampaignEmailService.sendToAccounts(new List<Id>(), TEMPLATE_ID);
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendToAccounts_ApiFailure_IncrementsSkipped() {
    BWM_CampaignEmailService.resetTemplateSubjectCacheForTests();
    Test.setMock(
      HttpCalloutMock.class,
      buildCampaignEmailMock('{"description":"send failed"}', 500)
    );
    Account accountRecord = [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Campaign Email Account%'
      LIMIT 1
    ];

    System.runAs(getAdminUser()) {
      Test.startTest();
      BWM_CampaignEmailService.SendCampaignEmailResult result =
        BWM_CampaignEmailService.sendToAccounts(
          new List<Id>{ accountRecord.Id },
          TEMPLATE_ID
        );
      Test.stopTest();

      System.assertEquals(0, result.sentCount);
      System.assertEquals(1, result.skippedCount);
    }
  }

  private class ThrowingEmailPostCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      if ('POST'.equalsIgnoreCase(request.getMethod())) {
        throw new CalloutException('Simulated email callout failure');
      }

      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody(TEMPLATE_DETAIL_BODY);
      return response;
    }
  }

  private static User getAdminUser() {
    return [
      SELECT Id
      FROM User
      WHERE Profile.Name LIKE 'System Administrator%' AND IsActive = TRUE
      LIMIT 1
    ];
  }
}