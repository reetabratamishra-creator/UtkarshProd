/**
 * @description   Test class for LeadManagementSmsService SMS validation and send
 *                scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class LeadManagementSmsServiceTest {
  @TestSetup
  static void setupCommonData() {
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;

    insert as system new List<Lead>{
      new Lead(
        LastName = 'SMS Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company = 'SMS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company_Name__c = 'SMS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Status = 'Prospect',
        Department_Name__c = 'Crash Barrier',
        Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
        Email = 'sms.lead+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
      ),
      new Lead(
        LastName = 'SMS No Phone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company = 'SMS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company_Name__c = 'SMS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Status = 'Prospect',
        Department_Name__c = 'Crash Barrier',
        Email = 'sms.nophone+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
      )
    };
  }

  /**
   * Scenario: Empty lead Ids or blank template name throw AuraHandledException.
   */
  @IsTest
  static void testSendToLeads_EmptyIdsOrBlankTemplate_ThrowsError() {
    Boolean emptyThrew = false;
    Boolean blankThrew = false;
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'SMS Lead%' LIMIT 1];

    Test.startTest();
    try {
      LeadManagementSmsService.sendToLeads(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      emptyThrew = true;
    }
    try {
      LeadManagementSmsService.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (AuraHandledException ex) {
      blankThrew = true;
    }
    Test.stopTest();

    System.assertEquals(true, emptyThrew);
    System.assertEquals(true, blankThrew);
  }

  /**
   * Scenario: Lead without phone is skipped for SMS send.
   */
  @IsTest
  static void testSendToLeads_NoPhone_Skipped() {
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'SMS No Phone%' LIMIT 1];

    Test.startTest();
    LeadManagementSmsService.SendSmsResult result = LeadManagementSmsService.sendToLeads(
      new List<Id>{ leadRecord.Id },
      'DEALER_Enq_dept'
    );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  /**
   * Scenario: Lead with phone sends SMS when template cache and mock callout succeed.
   */
  @IsTest
  static void testSendToLeads_HappyPathWithMockAndCachedTemplate() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_JourneyDefinitionService.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'DEALER_Enq_dept',
          'dltTemplateId' => '1007088206584852810',
          'templateText' =>
            'Dear Customer, please call us on {#numeric#} for more details about {#alphanumeric#}.'
        }
      }
    );
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"SMS enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'SMS Lead%' LIMIT 1];

    Test.startTest();
    LeadManagementSmsService.SendSmsResult result = LeadManagementSmsService.sendToLeads(
      new List<Id>{ leadRecord.Id },
      'DEALER_Enq_dept'
    );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(0, result.skippedCount);
  }

  /**
   * Scenario: fetchApprovedTemplates parses approved SMS rows from mock API.
   */
  @IsTest
  static void testFetchApprovedTemplates_WithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"data":[{"TemplateName":"approved_sms","TemplateStatus":"approve","dltTemplateId":"1","templateText":"Hi"},{"TemplateName":"rejected_sms","TemplateStatus":"reject"}]}',
        '{"code":"200","message":"unused"}'
      )
    );

    Test.startTest();
    List<LeadManagementSmsService.SmsTemplateOption> templates =
      LeadManagementSmsService.fetchApprovedTemplates();
    Test.stopTest();

    System.assertEquals(1, templates.size());
    System.assertEquals('approved_sms', templates[0].value);
  }

  @IsTest
  static void testSmsBuilderIncompleteMetadataAndBlankName() {
    BWM_SmsDirectPayloadBuilder.clearCache();
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{ 'templateName' => 'incomplete_sms' }
      }
    );
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'SMS Lead%' LIMIT 1];
    Boolean incompleteThrew = false;
    Boolean blankThrew = false;
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(settings, 'incomplete_sms', leadRecord, '9198');
    } catch (BWM_MessagingException ex) {
      incompleteThrew = true;
    }
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(settings, '', leadRecord, '9198');
    } catch (BWM_MessagingException ex) {
      blankThrew = true;
    }
    System.assertEquals(true, incompleteThrew);
    System.assertEquals(true, blankThrew);
  }

}