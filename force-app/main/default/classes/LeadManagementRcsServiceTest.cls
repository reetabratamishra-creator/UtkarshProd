/**
 * @description   Test class for LeadManagementRcsService RCS validation and send
 *                scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class LeadManagementRcsServiceTest {
  @TestSetup
  static void setupCommonData() {
    BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;

    insert as system new List<Lead>{
      new Lead(
        LastName = 'RCS Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company = 'RCS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company_Name__c = 'RCS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Status = 'Prospect',
        Department_Name__c = 'Crash Barrier',
        Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
        Email = 'rcs.lead+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
      ),
      new Lead(
        LastName = 'RCS No Phone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company = 'RCS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company_Name__c = 'RCS Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Status = 'Prospect',
        Department_Name__c = 'Crash Barrier',
        Email = 'rcs.nophone+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
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
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'RCS Lead%' LIMIT 1];

    Test.startTest();
    try {
      LeadManagementRcsService.sendToLeads(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      emptyThrew = true;
    }
    try {
      LeadManagementRcsService.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (AuraHandledException ex) {
      blankThrew = true;
    }
    Test.stopTest();

    System.assertEquals(true, emptyThrew);
    System.assertEquals(true, blankThrew);
  }

  /**
   * Scenario: Lead without phone is skipped for RCS send.
   */
  @IsTest
  static void testSendToLeads_NoPhone_Skipped() {
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'RCS No Phone%' LIMIT 1];

    Test.startTest();
    LeadManagementRcsService.SendRcsResult result = LeadManagementRcsService.sendToLeads(
      new List<Id>{ leadRecord.Id },
      'test_rcs_template'
    );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  /**
   * Scenario: Lead with phone sends RCS when template cache and mock callout succeed.
   */
  @IsTest
  static void testSendToLeads_HappyPathWithMockAndCachedTemplate() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"200","message":"RCS enqueued successfully."}',
        '{"code":"200","message":"unused"}'
      )
    );
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'test_rcs_template',
          'TemplateStatus' => 'approve'
        }
      }
    );
    Lead leadRecord = [SELECT Id FROM Lead WHERE LastName LIKE 'RCS Lead%' LIMIT 1];

    Test.startTest();
    LeadManagementRcsService.SendRcsResult result = LeadManagementRcsService.sendToLeads(
      new List<Id>{ leadRecord.Id },
      'test_rcs_template'
    );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(0, result.skippedCount);
  }

  /**
   * Scenario: fetchApprovedTemplates parses approved rows from mock RCS template API.
   */
  @IsTest
  static void testFetchApprovedTemplates_WithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"data":[{"TemplateName":"approved_rcs","TemplateStatus":"approve"},{"TemplateName":"rejected_rcs","TemplateStatus":"reject"}]}',
        '{"code":"200","message":"unused"}'
      )
    );

    Test.startTest();
    List<LeadManagementRcsService.RcsTemplateOption> templates =
      LeadManagementRcsService.fetchApprovedTemplates();
    Test.stopTest();

    System.assertEquals(1, templates.size());
    System.assertEquals('approved_rcs', templates[0].value);
  }
}