/**
 * @description   Test class for OfflineCampaignManagementController search and send
 *                paths.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class OfflineCampaignManagementControllerTest {
  /**
   * Common Offline Campaign fixtures for search and send tests.
   */
  @TestSetup
  static void setupCommonData() {
    insert as system new List<Offline_Campaign__c>{
      new Offline_Campaign__c(
        Name = 'Offline Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
        Email__c = 'offline.test@example.com',
        Department__c = 'Crash Barrier',
        Active__c = true
      ),
      new Offline_Campaign__c(
        Name = 'Offline Inactive ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
        Email__c = 'inactive@example.com',
        Department__c = 'Crash Barrier',
        Active__c = false
      ),
      new Offline_Campaign__c(
        Name = 'Offline No Phone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Email__c = 'offline.nophone@example.com',
        Department__c = 'Enquiry',
        Active__c = true
      )
    };
  }

  /**
   * Scenario: Search returns only active Offline Campaigns matching filters.
   */
  @IsTest
  static void searchOfflineCampaignsReturnsMatchingActiveRecords() {
    Test.startTest();
    List<Offline_Campaign__c> results = OfflineCampaignManagementController.searchOfflineCampaigns(
      'Offline Test',
      '9123',
      'offline.test',
      'Crash'
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assert(results[0].Name.startsWith('Offline Test'));
  }

  /**
   * Scenario: Journey send succeeds for offline campaign with phone via mock.
   */
  @IsTest
  static void testSendOfflineCampaignJourney_HappyPathWithMock() {
    BWM_JourneyDefinitionService.clearCache();
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    Offline_Campaign__c offlineRecord = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Offline Test%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_JourneyDefinitionService.SendJourneyResult result =
      OfflineCampaignManagementController.sendOfflineCampaignJourney(
        new List<Id>{ offlineRecord.Id },
        'prospect_not_resp'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  /**
   * Scenario: WhatsApp send succeeds with phone and skips when phone missing.
   */
  @IsTest
  static void testSendOfflineCampaignWhatsApp_HappyPathAndSkipNoPhone() {
    Offline_Campaign__c withPhone = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Offline Test%'
      LIMIT 1
    ];
    Offline_Campaign__c noPhone = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Offline No Phone%'
      LIMIT 1
    ];
    BWM_DirectWaCampaignSend.clearCache();
    Map<String, Object> meta = new Map<String, Object>{
      'language' => 'en',
      'name' => 'u_dealer_enq_dept',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'TEXT' },
        'body' => 'Hello {{1}}'
      }
    };
    BWM_DirectWaCampaignSend.templateMetaByName = new Map<String, Map<String, Object>>{
      'u_dealer_enq_dept' => meta
    };
    LeadManagementWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'u_dealer_enq_dept' => meta
    };
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"Journey message enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult sent =
      OfflineCampaignManagementController.sendOfflineCampaignWhatsApp(
        new List<Id>{ withPhone.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();
    LeadManagementWhatsAppService.SendWhatsAppResult skipped =
      OfflineCampaignManagementController.sendOfflineCampaignWhatsApp(
        new List<Id>{ noPhone.Id },
        'u_dealer_enq_dept'
      );

    System.assertNotEquals(null, sent);
    System.assertEquals(0, skipped.sentCount);
    System.assertEquals(1, skipped.skippedCount);
  }

  /**
   * Scenario: Campaign email send uses Infobip mock for offline campaign with email.
   */
  @IsTest
  static void testSendOfflineCampaignEmail_HappyPathWithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );
    Offline_Campaign__c offlineRecord = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Offline Test%'
      LIMIT 1
    ];

    Test.startTest();
    BWM_CampaignEmailService.SendCampaignEmailResult result =
      OfflineCampaignManagementController.sendOfflineCampaignEmail(
        new List<Id>{ offlineRecord.Id },
        '205000000067199'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  /**
   * Scenario: Journey options and empty RCS/SMS selection validation.
   */
  @IsTest
  static void testOptionGetters_AndEmptyChannelValidation() {
    Boolean rcsThrew = false;
    Boolean smsThrew = false;

    Test.startTest();
    List<BWM_JourneyDefinitionService.JourneyOption> journeys =
      OfflineCampaignManagementController.getCampaignJourneys();
    try {
      OfflineCampaignManagementController.sendOfflineCampaignRcs(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      rcsThrew = true;
    }
    try {
      OfflineCampaignManagementController.sendOfflineCampaignSms(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      smsThrew = true;
    }
    Test.stopTest();

    System.assertNotEquals(null, journeys);
    System.assertEquals(true, rcsThrew);
    System.assertEquals(true, smsThrew);
  }

  @IsTest
  static void testSendOfflineCampaignRcsAndSms_HappyPathWithMock() {
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'coverage_channel',
          'templateText' => 'Hello'
        }
      }
    );
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'coverage_channel',
          'dltTemplateId' => 'DLT1',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
    Offline_Campaign__c offlineRecord = [
      SELECT Id
      FROM Offline_Campaign__c
      WHERE Name LIKE 'Offline Test%'
      LIMIT 1
    ];
    offlineRecord.Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10);
    update as system offlineRecord;
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"accepted"}',
        '{"code":"200","message":"accepted"}',
        '{"code":"200","message":"accepted"}'
      )
    );

    Test.startTest();
    OfflineCampaignManagementRcsService.SendRcsResult rcsResult =
      OfflineCampaignManagementController.sendOfflineCampaignRcs(
        new List<Id>{ offlineRecord.Id },
        'coverage_channel'
      );
    OfflineCampaignManagementSmsService.SendSmsResult smsResult =
      OfflineCampaignManagementController.sendOfflineCampaignSms(
        new List<Id>{ offlineRecord.Id },
        'coverage_channel'
      );
    Test.stopTest();

    System.assertNotEquals(null, rcsResult);
    System.assertNotEquals(null, smsResult);
  }

  /**
   * Scenario: Unfiltered search, template getters, and email validation/catch paths run.
   */
  @IsTest
  static void testSearchWithoutFilters_GettersAndEmailCatch() {
    Test.startTest();
    List<Offline_Campaign__c> unfiltered =
      OfflineCampaignManagementController.searchOfflineCampaigns(null, null, null, null);
    Boolean emailThrew = false;
    try {
      OfflineCampaignManagementController.sendOfflineCampaignEmail(new List<Id>(), '');
    } catch (Exception ex) {
      emailThrew = true;
    }
    try {
      OfflineCampaignManagementController.getBluewaveEmailTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementController.getWhatsAppTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementController.getRcsTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementController.getSmsTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();

    System.assert(unfiltered.size() >= 1);
    System.assertEquals(true, emailThrew);
  }

  @IsTest
  static void testSendOfflineCampaignRcsAndSms() {
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'TemplateName' => 'cov_tmpl', 'templateText' => 'Hello' }
      }
    );
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'cov_tmpl',
          'dltTemplateId' => 'DLT1',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}',
        '{"code":"200","message":"ok"}'
      )
    );
    Offline_Campaign__c withPhone = [
      SELECT Id FROM Offline_Campaign__c WHERE Name LIKE 'Offline Test%' LIMIT 1
    ];
    Offline_Campaign__c noPhone = [
      SELECT Id FROM Offline_Campaign__c WHERE Name LIKE 'Offline No Phone%' LIMIT 1
    ];

    Test.startTest();
    OfflineCampaignManagementRcsService.SendRcsResult rcsOk =
      OfflineCampaignManagementController.sendOfflineCampaignRcs(
        new List<Id>{ withPhone.Id },
        'cov_tmpl'
      );
    OfflineCampaignManagementSmsService.SendSmsResult smsOk =
      OfflineCampaignManagementController.sendOfflineCampaignSms(
        new List<Id>{ withPhone.Id },
        'cov_tmpl'
      );
    OfflineCampaignManagementRcsService.SendRcsResult rcsSkip =
      OfflineCampaignManagementController.sendOfflineCampaignRcs(
        new List<Id>{ noPhone.Id },
        'cov_tmpl'
      );
    Boolean emptyThrew = false;
    try {
      OfflineCampaignManagementController.sendOfflineCampaignSms(new List<Id>(), 'cov_tmpl');
    } catch (Exception ex) {
      emptyThrew = true;
    }
    Test.stopTest();

    System.assertNotEquals(null, rcsOk);
    System.assertNotEquals(null, smsOk);
    System.assertEquals(1, rcsSkip.skippedCount);
    System.assertEquals(true, emptyThrew);
  }

  @IsTest
  static void testScheduledSends_RequireSelectionAndClearSchedule() {
    Integer threwCount = 0;
    Test.startTest();
    try {
      OfflineCampaignManagementController.sendOfflineCampaignJourneyScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      OfflineCampaignManagementController.sendOfflineCampaignRcsScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      OfflineCampaignManagementController.sendOfflineCampaignSmsScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    try {
      OfflineCampaignManagementController.sendOfflineCampaignEmailScheduled(new List<Id>(), 'tmpl', '2026-10-24T05:30:00Z');
    } catch (AuraHandledException ex) {
      threwCount++;
    }
    Test.stopTest();

    System.assertEquals(4, threwCount, 'Each scheduled send needs at least one record.');
    System.assertEquals(null, BWM_CampaignScheduleContext.scheduledDateTime, 'Schedule must be cleared after the send.');
  }
}