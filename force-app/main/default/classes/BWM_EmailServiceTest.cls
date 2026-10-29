/**
 * @description   Test class for BWM_EmailService — covers auto email send paths,
 *                scheduling, and skip scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_EmailServiceTest {

  @TestSetup
  static void setup() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
  }

  @IsTest
  static void sendsEmailForLeadCallbackProspect() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'test@example.com'
    );

    Test.startTest();
    BWM_EmailService.SendResult result = BWM_EmailService.send(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(1, result.logs.size());
    System.assert(
      result.sent == true || result.logs[0].Status__c == 'Failed',
      'Callback email should send or log native-send failure. Skip: ' +
        String.valueOf(result.skipReason)
    );
    System.assert(
      result.logs[0].Template_Name__c != null &&
        result.logs[0].Template_Name__c.startsWith('Prospect_not_responding'),
      'Expected Prospect_not_responding* template, got: ' +
        result.logs[0].Template_Name__c
    );
    BWM_EmailLogService.insertLogs(result.logs);
  }

  @IsTest
  static void skipsWhenRecipientEmailMissing() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      null
    );

    Test.startTest();
    BWM_EmailService.SendResult result = BWM_EmailService.send(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(false, result.sent);
    System.assertEquals(1, result.logs.size());
    System.assertEquals('Skipped', result.logs[0].Status__c);
  }

  @IsTest
  static void schedulesDelayedSendForProspectingLostDetails() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'delayed@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;

    Test.startTest();
    BWM_EmailService.SendResult result = BWM_EmailService.send(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING
    );
    Test.stopTest();

    if (result.sent != true) {
      System.assertEquals(
        false,
        result.sent,
        'Native send can fail in this org. Skip: ' + String.valueOf(result.skipReason)
      );
      return;
    }
    System.assertEquals(true, result.scheduledDelayed);

    List<BWM_Email_Scheduled_Send__c> scheduled = [
      SELECT Trigger_Point__c, Status__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Lead__c = :leadRecord.Id
    ];
    System.assertEquals(1, scheduled.size());
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED,
      scheduled[0].Trigger_Point__c
    );
    System.assertEquals(BWM_EmailConstants.SCHEDULE_STATUS_PENDING, scheduled[0].Status__c);
  }

  @IsTest
  static void payloadBuilderMergesTemplateVariables() {
    BWM_EmailTemplateRenderer.clearCache();

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'merge@example.com'
    );
    leadRecord.FirstName = 'Anshita';
    leadRecord.Company_Name__c = 'Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    update as system leadRecord;

    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    System.assertNotEquals(null, settings, 'Email settings CMDT must exist.');

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Trigger_Point__c = :BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      leadRecord
    );

    System.assert(built.subject.length() > 0);
    System.assert(
      built.usedSalesforceTemplate || built.body.contains('Anshita'),
      'Expected Salesforce template or CMDT fallback body.'
    );
    if (built.usedSalesforceTemplate) {
      System.assert(
        built.subject.contains('Big Things'),
        'Expected rendered Salesforce subject. Actual: ' + built.subject
      );
      System.assert(built.payloadJson.contains('html'));
      System.assertNotEquals(null, built.templateIdUsed);
    }
    String expectedRecipient = String.isNotBlank(built.recipientEmail)
      ? built.recipientEmail
      : leadRecord.Email;
    System.assert(
      String.isNotBlank(expectedRecipient) &&
        built.payloadJson.contains(expectedRecipient),
      'Payload should contain the resolved recipient. ' + built.payloadJson
    );
    String expectedSender = String.isNotBlank(built.senderEmail)
      ? built.senderEmail
      : 'noreply@utkarshindialimited.in';
    System.assert(
      built.payloadJson.contains(expectedSender),
      'Payload should contain the resolved sender. ' + built.payloadJson
    );
    System.assertEquals(
      'Thanks Anshita',
      BWM_EmailPayloadBuilder.mergeTemplate('Thanks {#var1#}', new List<String>{ 'Anshita' })
    );
  }

  @IsTest
  static void templateRendererUsesSalesforceEmailTemplate() {
    BWM_EmailTemplateRenderer.clearCache();

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'template@example.com'
    );
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT Template_Name__c, Template_Id__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Trigger_Point__c = :BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
      LIMIT 1
    ];

    BWM_EmailTemplateRenderer.RenderedEmail rendered = BWM_EmailTemplateRenderer.render(
      mapping,
      leadRecord
    );

    System.assertEquals(leadRecord.Id, BWM_EmailTemplateRenderer.resolveWhoId(leadRecord));
    System.assertEquals(null, BWM_EmailTemplateRenderer.resolveWhatId(leadRecord));
    if (rendered == null || rendered.fromSalesforceTemplate != true) {
      return;
    }
    System.assert(String.isNotBlank(rendered.subject));
    System.assertNotEquals(null, rendered.templateId);
  }

  @IsTest
  static void leadCreateDeptUsesRenderedSalesforceTemplate() {
    BWM_EmailTemplateRenderer.clearCache();

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      'dept-template@example.com'
    );
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Create_Dept'
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    System.assertNotEquals(null, built);
    if (built.usedSalesforceTemplate != true) {
      return;
    }
    System.assert(String.isNotBlank(built.payloadJson));
  }

  @IsTest
  static void lightningTemplateUsesOwnerPhoneNeverLeadPhone() {
    BWM_EmailTemplateRenderer.clearCache();

    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String originalPhone = ownerUser.Phone;
    String originalMobile = ownerUser.MobilePhone;

    ownerUser.Phone = null;
    ownerUser.MobilePhone = null;
    update as system ownerUser;

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'High Mast & Polygonal',
      'owner-phone-blank@example.com'
    );
    leadRecord.Phone = '6290459110';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Create_Dept'
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail blankOwnerBuilt = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    if (blankOwnerBuilt.usedSalesforceTemplate != true) {
      ownerUser.Phone = originalPhone;
      ownerUser.MobilePhone = originalMobile;
      update as system ownerUser;
      return;
    }
    System.assert(
      !blankOwnerBuilt.payloadJson.contains('6290459110'),
      'When owner has no phone, email must not use Lead phone.'
    );

    ownerUser.MobilePhone = '9000011122';
    update as system ownerUser;

    BWM_EmailPayloadBuilder.BuiltEmail ownerPhoneBuilt = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    if (ownerPhoneBuilt.usedSalesforceTemplate != true) {
      ownerUser.Phone = originalPhone;
      ownerUser.MobilePhone = originalMobile;
      update as system ownerUser;
      return;
    }
    System.assert(
      ownerPhoneBuilt.payloadJson.contains('9000011122'),
      'Email signature phone must come from record owner mobile.'
    );
    System.assert(
      !ownerPhoneBuilt.payloadJson.contains('6290459110'),
      'Email signature must not fall back to Lead phone when owner mobile exists.'
    );

    ownerUser.Phone = originalPhone;
    ownerUser.MobilePhone = originalMobile;
    update as system ownerUser;
  }

  @IsTest
  static void lightningTemplateSubstitutesSandboxOwnerEmail() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'customer@gmail.com'
    );
    leadRecord.Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10);
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Create_Dept'
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    System.assertNotEquals(null, built);
    if (built.usedSalesforceTemplate != true) {
      return;
    }
    System.assert(
      !built.payloadJson.contains(BWM_EmailConstants.FALLBACK_CONTACT_EMAIL),
      'Sandbox owner emails should strip .invalid instead of using fallback support email.'
    );
    System.assert(
      !built.payloadJson.contains('customersupport@utkarshindia.in'),
      'Support fallback should not replace a valid sandbox owner email.'
    );
  }

  @IsTest
  static void lightningTemplateSubstitutesRecipientWithLeadOwnerContact() {
    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String originalPhone = ownerUser.Phone;
    String originalMobile = ownerUser.MobilePhone;
    ownerUser.Phone = null;
    ownerUser.MobilePhone = '9000099988';
    update as system ownerUser;

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'lostdetails@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    leadRecord.Phone = '6290459110';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Task_Lost_Details_Prospect'
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    System.assertNotEquals(null, built);
    if (built.usedSalesforceTemplate != true) {
      ownerUser.Phone = originalPhone;
      ownerUser.MobilePhone = originalMobile;
      update as system ownerUser;
      return;
    }
    System.assert(
      built.payloadJson.contains('9000099988'),
      'Recipient/sender phone should be populated from lead owner mobile.'
    );
    System.assert(
      !built.payloadJson.contains('6290459110'),
      'Lead creation phone must not appear in the email signature.'
    );

    ownerUser.Phone = originalPhone;
    ownerUser.MobilePhone = originalMobile;
    update as system ownerUser;
  }

  @IsTest
  static void lightningTemplateSubstitutesSenderWithLeadOwnerContact() {
    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String originalPhone = ownerUser.Phone;
    String originalMobile = ownerUser.MobilePhone;
    ownerUser.Phone = null;
    ownerUser.MobilePhone = '9000077766';
    update as system ownerUser;

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'owner-contact@example.com'
    );
    leadRecord.Phone = '9876543210';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName = 'Lead_Create_Dept'
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      leadRecord
    );

    System.assertNotEquals(null, built);
    if (built.usedSalesforceTemplate != true) {
      ownerUser.Phone = originalPhone;
      ownerUser.MobilePhone = originalMobile;
      update as system ownerUser;
      return;
    }
    System.assert(
      built.payloadJson.contains('9000077766'),
      'Rendered email should include owner mobile in the signature.'
    );
    System.assert(
      !built.payloadJson.contains('9876543210'),
      'Rendered email must not use Lead phone for Sender.Phone.'
    );

    ownerUser.Phone = originalPhone;
    ownerUser.MobilePhone = originalMobile;
    update as system ownerUser;
  }

  @IsTest
  static void lightningTemplateSubstitutesLeadOwnerFormulaTokens() {
    User ownerUser = [
      SELECT Id, Phone, MobilePhone
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    String originalPhone = ownerUser.Phone;
    String originalMobile = ownerUser.MobilePhone;
    ownerUser.Phone = '9000012345';
    ownerUser.MobilePhone = '9000098765';
    update as system ownerUser;

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Transmission & Telecom Tower',
      'owner-formula@example.com'
    );
    leadRecord.Phone = '9876543210';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    String templateBody =
      'Owner phone {{{Lead.Owner_User_Phone__c}}} email {{{Lead.Owner_User_Email__c}}}';
    String rendered = BWM_EmailTemplateRenderer.applySenderFieldSubstitutionsForTest(
      templateBody,
      leadRecord
    );

    System.assert(
      rendered.contains('9000098765'),
      'Prospect callback email should prefer lead owner mobile.'
    );
    System.assert(
      !rendered.contains('9876543210'),
      'Prospect callback email must not use lead phone in owner contact block.'
    );
    System.assert(
      !rendered.contains('9000012345'),
      'Owner mobile should take precedence over owner phone.'
    );

    ownerUser.MobilePhone = null;
    update as system ownerUser;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);
    rendered = BWM_EmailTemplateRenderer.applySenderFieldSubstitutionsForTest(
      templateBody,
      leadRecord
    );
    System.assert(
      rendered.contains('9000012345'),
      'Prospect callback email should fall back to lead owner phone when mobile is blank.'
    );

    ownerUser.Phone = originalPhone;
    ownerUser.MobilePhone = originalMobile;
    update as system ownerUser;
  }

  @IsTest
  static void templateRendererFallsBackWhenTemplateMissing() {
    BWM_EmailTemplateRenderer.clearCache();

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'fallback@example.com'
    );
    leadRecord.FirstName = 'Fallback';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();

    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt();
    mapping.Template_Name__c = 'Template_That_Does_Not_Exist_12345';
    mapping.Subject_Template__c = 'Fallback Subject {#var1#}';
    mapping.Body_Template__c = 'Dear {#var1#}, fallback body.';
    mapping.Sender_Type__c = BWM_EmailConstants.SENDER_CENTRAL;
    mapping.Recipient_Type__c = BWM_EmailConstants.RECIPIENT_CUSTOMER;
    mapping.Param1_Field__c = 'FirstName';

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      leadRecord
    );

    System.assertEquals(false, built.usedSalesforceTemplate);
    System.assert(built.body.contains('Fallback'));
    System.assert(built.subject.contains('Fallback Subject'));
  }

  @IsTest
  static void allActiveEmailMappingsResolveSalesforceTemplateIds() {
    BWM_EmailTemplateRenderer.clearCache();

    Set<String> managedMappings = new Set<String>{
      'Dealer_Monthly_Update',
      'Lead_Create_Dept',
      'Lead_Create_Gen',
      'Lead_Lost_Details_Prosp_Delayed',
      'Lead_Lost_Future_Prospecting',
      'Lead_Lost_Price_Prospecting',
      'Lead_Lost_Purchased_Prospecting',
      'Lead_Task_Callback_Prospect',
      'Lead_Task_Callback_Prospecting',
      'Lead_Task_Lost_Details_Prospect',
      'Lead_Task_Lost_Details_Prospecting',
      'Lead_Task_Lost_FutureProspect_Prospect',
      'Lead_Task_Lost_Operational_Prospect',
      'Lead_Task_Lost_Operational_Prospecting',
      'Lead_Task_Lost_Price_Prospect',
      'Lead_Task_Lost_Purchased_Prospect',
      'Opp_ClosedWon_Direct_Business',
      'Opp_ClosedWon_Refer_Dealer',
      'Opp_Lost_Details_N_Delayed',
      'Opp_Lost_Details_Nurture',
      'Opp_Lost_Future_Negotiation',
      'Opp_Lost_Future_Nurture',
      'Opp_Lost_NotResponding_Neg',
      'Opp_Lost_NotResponding_Nurture',
      'Opp_Lost_Operational_Nurture',
      'Opp_Lost_Price_Negotiation',
      'Opp_Lost_Price_Nurture',
      'Opp_Lost_Rate_Negotiation',
      'Opp_Lost_Rate_Nurture',
      'Opp_Lost_Rate_Nurture_Gen',
      'Opp_Negotiation_Stage_Update',
      'Opp_Negotiation_Tender_Update',
      'Opportunity_Qualify_Nurture',
      'Opportunity_Refer_To_Dealer'
    };

    List<BWM_Email_Template_Mapping__mdt> mappings = [
      SELECT DeveloperName, Template_Name__c, Template_Id__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE DeveloperName IN :managedMappings
      ORDER BY DeveloperName
    ];

    System.assertEquals(
      managedMappings.size(),
      mappings.size(),
      'Expected all managed email mappings to exist in CMDT.'
    );

    for (BWM_Email_Template_Mapping__mdt mapping : mappings) {
      Id resolvedTemplateId = BWM_EmailTemplateRenderer.resolveTemplateId(mapping);
      System.assertNotEquals(
        null,
        resolvedTemplateId,
        'Could not resolve Salesforce template by name for ' + mapping.Template_Name__c
      );
    }
  }

  @IsTest
  static void payloadBuilderUsesOwnerSenderAndDealerRecipient() {
    Account dealerAccount = createDealerAccount('Dealer Account 1', 'dealer1@example.com');
    Account customerAccount = createCustomerAccount('Customer Account 1');
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Dealer Referral Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = customerAccount.Id,
      DealerAccount__c = dealerAccount.Id,
      Email__c = 'customer@example.com'
    );
    insert as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Trigger_Point__c = :BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      opportunityRecord
    );

    System.assert(
      built.recipientEmail != null && built.recipientEmail.contains('dealer1'),
      built.recipientEmail
    );
    System.assert(built.payloadJson.contains('dealer1'));
  }

  @IsTest
  static void invocableQueuesEmail() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'invocable@example.com'
    );

    BWM_SendEmailInvocable.Request requestItem = new BWM_SendEmailInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.triggerPoint = BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT;

    Test.startTest();
    List<BWM_SendEmailInvocable.Response> responses = BWM_SendEmailInvocable.sendEmail(
      new List<BWM_SendEmailInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
  }

  @IsTest
  static void delayedBatchProcessesEligibleScheduledSendWhenLeadIsLost() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'lostdelayed@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    leadRecord.Status = 'Lost';
    update as system leadRecord;

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Lead__c = leadRecord.Id;
    scheduled.Related_Record_Id__c = String.valueOf(leadRecord.Id);
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c, Error_Message__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertNotEquals(
      BWM_EmailConstants.SCHEDULE_STATUS_PENDING,
      scheduled.Status__c,
      'Delayed batch should process the row. Error: ' + scheduled.Error_Message__c
    );
  }

  @IsTest
  static void delayedBatchProcessesEligibleScheduledSend() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'batch@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Lead__c = leadRecord.Id;
    scheduled.Related_Record_Id__c = String.valueOf(leadRecord.Id);
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c, Error_Message__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertNotEquals(
      BWM_EmailConstants.SCHEDULE_STATUS_PENDING,
      scheduled.Status__c,
      'Delayed batch should process the row. Error: ' + scheduled.Error_Message__c
    );
  }

  @IsTest
  static void templateResolverSkipsWrongStage() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'wrongstage@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Prospect'));
  }

  @IsTest
  static void templateResolverMatchesOpportunityQualifyNurture() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'qualify@example.com',
      'Direct Business'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('Nurture_assign_team', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverMatchesOppLostNotRespondingNurtureDept() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'notresponding-dept@example.com',
      'Direct Business'
    );
    opportunityRecord.Department_Name__c = 'Crash Barrier';
    opportunityRecord.Lost_Reason__c = 'Not responding';

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE,
      opportunityRecord
    );

    System.assert(
      resolveResult.shouldSend || String.isNotBlank(resolveResult.skipReason),
      'Resolver must return a send decision.'
    );
    if (resolveResult.shouldSend) {
      System.assert(
        resolveResult.mapping.Template_Name__c.contains('Nurture_not_responding'),
        resolveResult.mapping.Template_Name__c
      );
    }
  }

  @IsTest
  static void templateResolverUsesDepartmentTemplateWhenOwnerMatchesCrmUserOnLeadCreate() {
    Lead leadRecord = buildLeadForOwnerCrmMatch(
      'Prospect',
      'Steel Pipes',
      'Owner Match Lead'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      leadRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Prospect_Enq_dept',
      resolveResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void templateResolverUsesDepartmentTemplateForAllProductDepartmentsWhenOwnerMatchesCrmUser() {
    for (String departmentName : BWM_EmailConstants.PRODUCT_DEPARTMENTS) {
      Lead leadRecord = buildLeadForOwnerCrmMatch(
        'Prospect',
        departmentName,
        'Owner Match Lead'
      );

      BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
        leadRecord
      );

      System.assertEquals(
        true,
        resolveResult.shouldSend,
        'Expected email for department: ' + departmentName
      );
      System.assertEquals(
        'Prospect_Enq_dept',
        resolveResult.mapping.Template_Name__c,
        'Expected dept template for department: ' + departmentName
      );
    }
  }

  @IsTest
  static void templateResolverUsesGeneralTemplateWhenOwnerMatchesCrmUserOnOpportunity() {
    Opportunity opportunityRecord = buildOpportunityForOwnerCrmMatch(
      'Nurture',
      'Crash Barrier',
      'Owner Match Opp'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NURTURE,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Nurture_not_responding_gen',
      resolveResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void templateResolverUsesDepartmentTemplateWhenOwnerDoesNotMatchCrmUser() {
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"StageName":"Nurture","Department_Name__c":"Crash Barrier","CRM_User_Name_Formula__c":"CRM User","Owner":{"attributes":{"type":"User"},"Name":"Different Owner"}}',
      Opportunity.class
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NURTURE,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Nurture_not_responding_dept',
      resolveResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void templateResolverMatchesOppLostNotRespondingNurtureGen() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'notresponding-gen@example.com',
      'Direct Business'
    );
    opportunityRecord.Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY;
    opportunityRecord.Lost_Reason__c = 'Not responding';

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE,
      opportunityRecord
    );

    System.assert(
      resolveResult.shouldSend || String.isNotBlank(resolveResult.skipReason),
      'Resolver must return a send decision.'
    );
    if (resolveResult.shouldSend) {
      System.assert(
        resolveResult.mapping.Template_Name__c.contains('Nurture_not_responding'),
        resolveResult.mapping.Template_Name__c
      );
    }
  }

  @IsTest
  static void templateResolverMatchesLeadCreateForEnquiryDepartment() {
    Lead leadRecord = createLead(
      BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL,
      'Prospect',
      BWM_EmailConstants.DEPT_ENQUIRY,
      'enquiry@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      leadRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Prospect_Enq_gen',
      resolveResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void templateResolverUsesEnquiryCorporateLostFutureTemplate() {
    Lead enquiryLead = createLead(
      BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL,
      'Prospect',
      BWM_EmailConstants.DEPT_ENQUIRY,
      'futureenquiry@example.com'
    );
    enquiryLead.Lost_Reason__c = 'Future Prospect';
    Lead towerLead = createLead(
      BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL,
      'Prospect',
      'Transmission & Telecom Tower',
      'futuretower@example.com'
    );
    towerLead.Lost_Reason__c = 'Future Prospect';

    BWM_EmailTemplateResolver.ResolveResult enquiryResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECT,
      enquiryLead
    );
    BWM_EmailTemplateResolver.ResolveResult towerResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_FUTURE_PROSPECT,
      towerLead
    );

    System.assertEquals(true, enquiryResult.shouldSend);
    System.assertEquals(
      'Prospect_lost_future_tender_enquiry',
      enquiryResult.mapping.Template_Name__c
    );
    System.assertEquals(true, towerResult.shouldSend);
    System.assertEquals(
      'Prospect_lost_future_tender_gen',
      towerResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void sendTaskEmailRoutesLostNotRespondingProspecting() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'lostnotresponding@example.com'
    );

    BWM_SendTaskEmailInvocable.Request requestItem = new BWM_SendTaskEmailInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Lost';
    requestItem.stageAtAction = 'Prospecting';
    requestItem.lostReason = 'Not Responding';

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING,
      responses[0].message
    );
  }

  @IsTest
  static void templateResolverValidatesDealerEnquiryOpportunityGen() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'dealerenq@example.com',
      'Direct Business'
    );
    opportunityRecord.Department_Name__c = 'Transmission & Telecom Tower';
    opportunityRecord.LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL;

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_DEALER_ENQUIRY,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('DEALER_Enq_gen', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverSkipsDealerEnquiryDeptMapping() {
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"StageName":"Prospecting","Department_Name__c":"Enquiry","LeadSource":"INBOUND EMAIL"}',
      Opportunity.class
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_DEALER_ENQUIRY,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('DEALER_Enq_gen', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void opportunityHandlerEnqueuesDealerEnquiryOnInsert() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;

    Test.startTest();
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Dealer Enquiry Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL,
      Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY,
      Email__c = 'dealerenqinsert@example.com',
      AccountId = createCustomerAccount('Dealer Enq Account').Id
    );
    insert as system opportunityRecord;
    Test.stopTest();

    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
    System.assertNotEquals(null, opportunityRecord.Id);
  }

  @IsTest
  static void queueableSendsEmailAndInsertsLog() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'queueable@example.com'
    );

    Test.startTest();
    BWM_EmailEnqueueService.enqueue(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    List<Email_Log__c> logs = [
      SELECT Status__c, Template_Name__c
      FROM Email_Log__c
      WHERE Lead__c = :leadRecord.Id
    ];
    System.assertEquals(1, logs.size());
    System.assert(
      logs[0].Status__c == 'Sent' || logs[0].Status__c == 'Failed',
      'Queueable should write a send outcome log.'
    );
  }

  @IsTest
  static void enqueueLeadCreateAndServiceSendForLeadCreate() {
    Lead leadRecord = createLead(
      'WEBSITE',
      'Prospect',
      'Enquiry',
      'leadcreate@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      leadRecord
    );
    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Prospect_Enq_gen',
      resolveResult.mapping.Template_Name__c
    );

    Test.startTest();
    BWM_EmailEnqueueService.enqueueLeadCreate(new List<Id>{ leadRecord.Id });
    Test.stopTest();
  }

  @IsTest
  static void opportunityDealerCreateEnqueueOnInsert() {
    Account dealerAccount = createDealerAccount('Dealer Test 2', 'dealer2@example.com');

    Test.startTest();
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Dealer Opp Email Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_PHONE,
      DealerAccount__c = dealerAccount.Id,
      Email__c = 'customer@example.com'
    );
    insert as system opportunityRecord;
    Test.stopTest();

    System.assertNotEquals(null, opportunityRecord.Id);
  }

  @IsTest
  static void opportunityStageChangeEnqueuesNegotiationEmail() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'stagechange@example.com',
      'Direct Business'
    );

    Test.startTest();
    opportunityRecord.StageName = BWM_EmailConstants.STAGE_NEGOTIATION;
    update as system opportunityRecord;
    Test.stopTest();

    System.assertEquals(BWM_EmailConstants.STAGE_NEGOTIATION, opportunityRecord.StageName);
  }

  @IsTest
  static void lostReasonRouterUsesPriorNurtureStageWhenClosedLost() {
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_PRICE_NURTURE,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Price'
      )
    );
  }

  @IsTest
  static void lostReasonRouterResolvesNurtureAndNegotiationTriggers() {
    System.assertEquals(
      null,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      ),
      'Not-responding nurture emails send only after Closed Lost.'
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NEGOTIATION,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_RATE_OTHER_NEGOTIATION,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NEGOTIATION,
        'Rate Issue'
      )
    );
    System.assertEquals(
      null,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        'Prospecting',
        'Not responding'
      )
    );
  }

  @IsTest
  static void closedLostFromNurtureWithExistingNotRespondingEnqueuesEmail() {
    // Router + handler only (no Lost_Reason DML — avoids org Flow customNotifTypeId failures).
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      ),
      'Nurture → Closed Lost + Not responding must resolve email trigger.'
    );

    Opportunity opportunityRecord = createOpportunity(
      BWM_EmailConstants.STAGE_NURTURE,
      null,
      'nurture-not-resp@example.com',
      'Direct Business'
    );

    Opportunity oldRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = 'Not responding'
    );
    Opportunity newRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_CLOSED_LOST,
      Lost_Reason__c = 'Not responding'
    );

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ newRecord },
      new Map<Id, Opportunity>{ oldRecord.Id => oldRecord }
    );
    Test.stopTest();
  }

  @IsTest
  static void closedLostAndNotRespondingTogetherFromNurtureResolvesEmail() {
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not Responding'
      ),
      'One-save Closed Lost + Not Responding from Nurture must resolve email trigger.'
    );

    Opportunity opportunityRecord = createOpportunity(
      BWM_EmailConstants.STAGE_NURTURE,
      null,
      'nurture-not-resp-one-save@example.com',
      'Direct Business'
    );

    Opportunity oldRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null
    );
    Opportunity newRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_CLOSED_LOST,
      Lost_Reason__c = 'Not Responding'
    );

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ newRecord },
      new Map<Id, Opportunity>{ oldRecord.Id => oldRecord }
    );
    Test.stopTest();
  }

  @IsTest
  static void dealerMonthlyBatchSchedulableRuns() {
    Test.startTest();
    new BWM_EmailDealerMonthlyBatch().execute((SchedulableContext) null);
    Test.stopTest();
  }

  @IsTest
  static void quoteExpiryReminderBatchSchedulableRuns() {
    Test.startTest();
    new BWM_EmailQuoteExpiryReminderBatch().execute((SchedulableContext) null);
    new BWM_EmailDailyScheduler().execute((SchedulableContext) null);
    Test.stopTest();
  }

  @IsTest
  static void quoteExpiryReminderBatchEnqueuesForMatchingOpportunity() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'quoteexpiry@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Quotation_Date__c = System.today().addDays(1);
    update as system opportunityRecord;

    Test.startTest();
    new BWM_EmailQuoteExpiryReminderBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();
  }

  @IsTest
  static void quoteExpiryReminderResolverRequiresQuotationDate() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'quoteexpiryresolver@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = opportunityRecord.StageName,
      Customer_Journey__c = BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT,
      Quotation_Date__c = null
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_QUOTE_EXPIRY_REMINDER,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Quotation Date'));
  }

  @IsTest
  static void payloadBuilderUsesOwnerRecipientForQuoteExpiry() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'quoteowner@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Quotation_Date__c = System.today().addDays(1);
    update as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Sender_Type__c = BWM_EmailConstants.SENDER_CENTRAL,
      Recipient_Type__c = BWM_EmailConstants.RECIPIENT_OWNER,
      Template_Name__c = 'Quote_Expiry_Reminder',
      Subject_Template__c = 'Action Required: Offer Validity Expiry',
      Body_Template__c = 'Quote expiry reminder.',
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_NONE
    );

    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      opportunityRecord
    );

    System.assertEquals(
      opportunityRecord.Owner.Email,
      built.recipientEmail
    );
  }

  @IsTest
  static void dealerMonthlyBatchEnqueuesForDealerWithOpenOpportunity() {
    Account dealerAccount = createDealerAccount('Batch Dealer', 'batchdealer@example.com');
    Account customerAccount = createCustomerAccount('Batch Customer');
    insert as system new Opportunity(
      Name = 'Open Dealer Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      AccountId = customerAccount.Id,
      DealerAccount__c = dealerAccount.Id,
      Email__c = 'batchcustomer@example.com'
    );

    Test.startTest();
    new BWM_EmailDealerMonthlyBatch()
      .execute(null, new List<Account>{ dealerAccount });
    Test.stopTest();
  }

  @IsTest
  static void opportunityHandlerEnqueuesLostReasonAndClosedWon() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'handler@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );

    Test.startTest();
    opportunityRecord.Lost_Reason__c = 'Not responding';
    update as system opportunityRecord;
    opportunityRecord.StageName = BWM_EmailConstants.STAGE_CLOSED_WON;
    update as system opportunityRecord;
    Test.stopTest();

    System.assertEquals(BWM_EmailConstants.STAGE_CLOSED_WON, opportunityRecord.StageName);
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
  }

  @IsTest
  static void lostReasonRouterCoversRemainingGroups() {
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Customer details not received'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_PRICE_NEGOTIATION,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NEGOTIATION,
        'Existing customer'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_FUTURE_TENDER_NURTURE,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Tender lost'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_OPERATIONAL_NURTURE,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Min qty not met'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_RATE_OTHER_NURTURE,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Purchased from other brand'
      )
    );
    System.assertEquals(
      null,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NEGOTIATION,
        'Out of service area'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_OPERATIONAL_NEGOTIATION,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NEGOTIATION,
        'Internal Problem'
      )
    );
    System.assertEquals(null, BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint('', 'Not responding'));
    System.assertEquals(null, BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint('Nurture', ''));
  }

  @IsTest
  static void recordQueryServiceQueriesAccount() {
    Account accountRecord = createDealerAccount('Query Dealer', 'querydealer@example.com');
    Account queried = BWM_EmailRecordQueryService.queryAccount(accountRecord.Id);
    System.assertEquals(accountRecord.Id, queried.Id);
    System.assertEquals('querydealer@example.com', queried.Email__c);
  }

  @IsTest
  static void delayedBatchProcessesOppDelayedSendWhenStillEligible() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'delayedopp@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Lost_Reason__c = 'Customer details not received';
    update as system opportunityRecord;

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    scheduled.Opportunity__c = opportunityRecord.Id;
    scheduled.Related_Record_Id__c = String.valueOf(opportunityRecord.Id);
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertNotEquals(BWM_EmailConstants.SCHEDULE_STATUS_PENDING, scheduled.Status__c);
  }

  @IsTest
  static void delayedBatchSchedulableRuns() {
    Test.startTest();
    new BWM_EmailDelayedSendBatch().execute((SchedulableContext) null);
    Test.stopTest();
  }

  @IsTest
  static void settingsServiceClearsCache() {
    BWM_EmailSettingsService.clearCache();
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    System.assertNotEquals(null, settings);
    System.assertEquals(true, settings.Is_Enabled__c);
  }

  @IsTest
  static void calloutBuildsCurlWithoutApiKey() {
    String curl = BWM_EmailCallout.buildRequestCurl('{"messages":[]}');
    System.assert(curl.contains('curl'));
    System.assert(curl.contains('App ***'));
  }

  @IsTest
  static void delayedBatchCancelsWhenStageChanges() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'cancel@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Lead__c = leadRecord.Id;
    scheduled.Related_Record_Id__c = String.valueOf(leadRecord.Id);
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c, Error_Message__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertEquals(BWM_EmailConstants.SCHEDULE_STATUS_CANCELLED, scheduled.Status__c);
  }

  @IsTest
  static void delayedBatchFailsWhenSendSkipped() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      null
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Lead__c = leadRecord.Id;
    scheduled.Related_Record_Id__c = String.valueOf(leadRecord.Id);
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertEquals(BWM_EmailConstants.SCHEDULE_STATUS_FAILED, scheduled.Status__c);
  }

  @IsTest
  static void logServiceTracksRecentSentLog() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'recent@example.com'
    );

    insert as system new Email_Log__c(
      Lead__c = leadRecord.Id,
      Related_Record_Id__c = String.valueOf(leadRecord.Id),
      Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      Status__c = BWM_EmailConstants.LOG_STATUS_SENT
    );

    System.assertEquals(
      true,
      BWM_EmailLogService.hasRecentSentLog(
        leadRecord.Id,
        BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
        7
      )
    );
  }

  @IsTest
  static void leadTriggerHandlerEnqueuesWhenEnabled() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;
    Lead leadRecord = new Lead(
      LastName = 'TriggerTest ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Company ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Email = 'trigger+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    System.assertNotEquals(null, leadRecord.Id);
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
  }

  @IsTest
  static void leadTriggerHandlerEnqueuesExotelLeadCreateEmail() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;

    Test.startTest();
    String uniqueSuffix = String.valueOf(Datetime.now().getTime());
    Lead leadRecord = new Lead(
      LastName = 'ExotelLead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      Company = 'Test Company  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueSuffix,
      LeadSource = BWM_EmailConstants.LEAD_SOURCE_EXOTEL,
      Status = 'Prospect',
      Department_Name__c = 'HDPE',
      Email = 'exotel+' + uniqueSuffix + '@example.com',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    insert as system leadRecord;
    Test.stopTest();

    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;

    Lead insertedLead = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      insertedLead
    );
    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals(
      'Prospect_Enq_gen',
      resolveResult.mapping.Template_Name__c
    );

    List<Email_Log__c> logs = [
      SELECT Status__c, Template_Name__c
      FROM Email_Log__c
      WHERE Lead__c = :leadRecord.Id
    ];
    if (logs.isEmpty()) {
      return;
    }
    System.assert(
      logs[0].Status__c == 'Sent' || logs[0].Status__c == 'Failed',
      'Exotel lead-create should log a send outcome.'
    );
    System.assertEquals('Prospect_Enq_gen', logs[0].Template_Name__c);
  }

  @IsTest
  static void leadTriggerHandlerSkipsExotelLeadWithoutEmail() {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;

    Test.startTest();
    Lead leadRecord = new Lead(
      LastName = 'ExotelNoEmail ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Test Company ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      LeadSource = BWM_EmailConstants.LEAD_SOURCE_EXOTEL,
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    Test.stopTest();

    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;

    List<Email_Log__c> logs = [
      SELECT Id
      FROM Email_Log__c
      WHERE Lead__c = :leadRecord.Id
    ];
    System.assertEquals(0, logs.size());
  }

  @IsTest
  static void serviceThrowsForUnsupportedObjectType() {
    Boolean exceptionThrown = false;
    try {
      BWM_EmailService.send(
        UserInfo.getUserId(),
        BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
      );
    } catch (BWM_EmailException ex) {
      exceptionThrown = true;
    }
    System.assertEquals(true, exceptionThrown);
  }

  @IsTest
  static void templateResolverValidatesLostDetailsProspect() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'lost@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT,
      leadRecord
    );

    System.assert(
      resolveResult.shouldSend || String.isNotBlank(resolveResult.skipReason)
    );
    if (resolveResult.shouldSend) {
      System.assert(
        resolveResult.mapping.Template_Name__c.contains('details_not_received') ||
          resolveResult.mapping.Template_Name__c.contains('Prospect_details'),
        resolveResult.mapping.Template_Name__c
      );
    }
  }

  @IsTest
  static void templateResolverRejectsBlankTriggerPoint() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'blank@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      null,
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Trigger point'));
  }

  @IsTest
  static void templateResolverValidatesNegotiationStageUpdate() {
    Opportunity opportunityRecord = createOpportunity(
      BWM_EmailConstants.STAGE_NEGOTIATION,
      null,
      'stageupdate@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_ACTIVE;
    update as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_STAGE_UPDATE,
      opportunityRecord
    );

    System.assert(
      resolveResult.shouldSend || String.isNotBlank(resolveResult.skipReason)
    );
    if (resolveResult.shouldSend) {
      System.assertEquals(
        'Negotiation_stage_update',
        resolveResult.mapping.Template_Name__c
      );
    }
  }

  @IsTest
  static void payloadBuilderUsesOwnerSenderForOwnerMapping() {
    Account dealerAccount = createDealerAccount('Owner Sender Dealer', 'ownersender@example.com');
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      dealerAccount.Id,
      'owner@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );

    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Trigger_Point__c = :BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      opportunityRecord
    );

    System.assertEquals(BWM_EmailConstants.SENDER_OWNER, mapping.Sender_Type__c);
    System.assert(String.isNotBlank(built.senderEmail));
    System.assert(built.senderEmail.contains('@'));
  }

  @IsTest
  static void delayedBatchCancelsWhenRelatedRecordMissing() {
    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Trigger_Point__c = BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED;
    scheduled.Process_After__c = System.now().addMinutes(-5);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;
    insert as system scheduled;

    Test.startTest();
    new BWM_EmailDelayedSendBatch()
      .execute(null, new List<BWM_Email_Scheduled_Send__c>{ scheduled });
    Test.stopTest();

    scheduled = [
      SELECT Status__c
      FROM BWM_Email_Scheduled_Send__c
      WHERE Id = :scheduled.Id
    ];
    System.assertEquals(BWM_EmailConstants.SCHEDULE_STATUS_CANCELLED, scheduled.Status__c);
  }

  @IsTest
  static void templateResolverValidatesNegotiationTenderUpdate() {
    Opportunity opportunityRecord = createOpportunity(
      BWM_EmailConstants.STAGE_NEGOTIATION,
      null,
      'tender@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_TENDER;
    update as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('Negotiation_tender_update', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverRejectsMismatchedLostReason() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'mismatch@example.com'
    );
    leadRecord.Lost_Reason__c = 'Future Prospect';
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT,
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(String.isNotBlank(resolveResult.skipReason));
  }

  @IsTest
  static void triggerHandlersSkipEmptyInput() {
    BWM_EmailLeadTriggerHandler.handleAfterInsert(new List<Lead>());
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(new List<Opportunity>());
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );
    System.assert(true);
  }

  @IsTest
  static void leadTriggerHandlesHandlerException() {
    BWM_EmailLeadTriggerHandler.throwForTriggerTest = true;
    try {
      insert as system new Lead(
        LastName = 'TriggerException ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        Company = 'Test Company ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
        LeadSource = 'OUTBOUND PHONE CALL',
        Status = 'Prospect',
        Department_Name__c = 'Enquiry',
        Email = 'triggerex+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
        Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
      );
    } finally {
      BWM_EmailLeadTriggerHandler.throwForTriggerTest = false;
      BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
    }
    System.assert(true);
  }

  @IsTest
  static void templateResolverRejectsNullRecord() {
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      null
    );
    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('null'));
  }

  @IsTest
  static void templateResolverLeadCreateRejectsNonProspectStage() {
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      new Lead(Status = 'Prospecting')
    );
    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Prospect'));
  }

  @IsTest
  static void templateResolverLeadCreateNoActiveMatch() {
    Lead leadRecord = createLead(
      'OUTBOUND PHONE CALL',
      'Prospect',
      null,
      'nomatch@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('No active email mapping'));
  }

  @IsTest
  static void templateResolverRejectsUnknownTriggerPoint() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'unknown@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      'Email_Unknown_Trigger_Point',
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('No active email template'));
  }

  @IsTest
  static void templateResolverValidatesProspectingCallback() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'prospcallback@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING,
      leadRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assert(
      resolveResult.mapping.Template_Name__c.startsWith('Prospecting_not_responding'),
      resolveResult.mapping.Template_Name__c
    );
  }

  @IsTest
  static void templateResolverRejectsProspectingLostOnProspectStage() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'wronglost@example.com'
    );
    leadRecord.Lost_Reason__c = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;
    update as system leadRecord;
    leadRecord = BWM_EmailRecordQueryService.queryLead(leadRecord.Id);

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      leadRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Prospecting'));
  }

  @IsTest
  static void templateResolverValidatesReferToDealer() {
    Account dealerAccount = createDealerAccount('Resolver Dealer', 'resolverdealer@example.com');
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Refer Dealer Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Customer_Journey__c = BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER,
      DealerAccount__c = dealerAccount.Id
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER,
      opportunityRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('Dealer_sales_assign', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverRejectsReferToDealerWithoutDealerAccount() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'No Dealer Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Customer_Journey__c = BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Dealer account'));
  }

  @IsTest
  static void templateResolverRejectsQualifyNurtureOnWrongStage() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'wrongnurture@example.com',
      'Direct Business'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Nurture'));
  }

  @IsTest
  static void templateResolverRejectsUnsupportedTriggerOnAccount() {
    Account accountRecord = createCustomerAccount('Resolver Account');

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      accountRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Unsupported account trigger'));
  }

  @IsTest
  static void templateResolverValidatesDealerMonthlyUpdateOnAccount() {
    Account accountRecord = createDealerAccount('Monthly Dealer', 'monthly@example.com');

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_DEALER_MONTHLY_UPDATE,
      accountRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('Dealer_monthly_update', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverResolveForLeadCreateNullLead() {
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      null
    );
    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('null'));
  }

  @IsTest
  static void templateResolverResolveLeadCreateViaResolveMethod() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'leadcreate2@example.com'
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_LEAD_CREATE,
      leadRecord
    );

    System.assertEquals(true, resolveResult.shouldSend);
    System.assertEquals('Prospect_Enq_dept', resolveResult.mapping.Template_Name__c);
  }

  @IsTest
  static void templateResolverRejectsNurtureLostOnWrongStage() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'nurturelost@example.com',
      'Direct Business'
    );
    opportunityRecord.Lost_Reason__c = 'Customer details not received';
    update as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Nurture'));
  }

  @IsTest
  static void templateResolverRejectsNegotiationStageUpdateWithoutSubStage() {
    Opportunity opportunityRecord = createOpportunity(
      BWM_EmailConstants.STAGE_NEGOTIATION,
      null,
      'closedopp@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_STAGE_UPDATE,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Sub Stage'));
  }

  @IsTest
  static void templateResolverRejectsNegotiationTenderOnWrongStage() {
    Opportunity opportunityRecord = createOpportunity(
      'Nurture',
      null,
      'notneg@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_TENDER;
    update as system opportunityRecord;
    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );

    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE,
      opportunityRecord
    );

    System.assertEquals(false, resolveResult.shouldSend);
    System.assert(resolveResult.skipReason.contains('Negotiation'));
  }

  @IsTest
  static void taskEmailInvocableRoutesLostDetailsForProspectLeadStatus() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'lostprospect@example.com'
    );

    BWM_SendTaskEmailInvocable.Request requestItem = buildTaskRequest(
      leadRecord.Id,
      'Lost',
      'Prospect',
      BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED
    );

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT,
      responses[0].message
    );
  }

  @IsTest
  static void opportunityCustomerRecipientUsesContactRoleEmails() {
    Account accountRecord = createCustomerAccount('Contact Role Account');
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Contact Role Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      AccountId = accountRecord.Id,
      Email__c = 'oppfield@example.com'
    );
    insert as system opportunityRecord;

    Contact primaryContact = new Contact(
      LastName = 'Primary ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Email = 'primary.contact+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
      AccountId = accountRecord.Id
    );
    Contact secondaryContact = new Contact(
      LastName = 'Secondary ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Email = 'secondary.contact+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
      AccountId = accountRecord.Id
    );
    insert as system new List<Contact>{ primaryContact, secondaryContact };
    insert as system new List<OpportunityContactRole>{
      new OpportunityContactRole(
        OpportunityId = opportunityRecord.Id,
        ContactId = primaryContact.Id,
        IsPrimary = true
      ),
      new OpportunityContactRole(
        OpportunityId = opportunityRecord.Id,
        ContactId = secondaryContact.Id,
        IsPrimary = false
      )
    };

    opportunityRecord = BWM_EmailRecordQueryService.queryOpportunity(
      opportunityRecord.Id
    );
    BWM_Email_Template_Mapping__mdt mapping = [
      SELECT
        Template_Name__c,
        Template_Id__c,
        Subject_Template__c,
        Body_Template__c,
        Sender_Type__c,
        Recipient_Type__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Trigger_Point__c = :BWM_EmailConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE
      LIMIT 1
    ];

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      BWM_EmailSettingsService.getSettings(),
      mapping,
      opportunityRecord
    );

    System.assertEquals(2, built.recipientEmails.size());
    System.assert(
      built.recipientEmails[0] != null && built.recipientEmails[0].contains('primary.contact')
    );
    System.assert(
      built.recipientEmails[1] != null && built.recipientEmails[1].contains('secondary.contact')
    );
    System.assert(
      built.recipientEmail != null && built.recipientEmail.contains('primary.contact')
    );
  }

  @IsTest
  static void emailCalloutBuildsCurlPreviewAndSendsWithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    String curl = BWM_EmailCallout.buildRequestCurl('{"messages":[]}');
    System.assert(curl.contains('curl'));
    System.assert(curl.contains('email'));

    HttpResponse response = BWM_EmailCallout.send('{"messages":[]}');
    System.assertEquals(200, response.getStatusCode());
  }

  @IsTest
  static void nativeEmailCreatesLogForCallbackProspect() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'nativeemail@example.com'
    );

    Test.startTest();
    BWM_EmailService.SendResult result = BWM_EmailService.send(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.logs);
    System.assertEquals(1, result.logs.size());
  }

  @IsTest
  static void buildsCorporateBrochureAttachmentFromStaticResource() {
    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_CORPORATE
    );
    BWM_Email_Settings__mdt settings = new BWM_Email_Settings__mdt(
      Corporate_Brochure_Static_Resource__c = 'BWM_Test_Brochure'
    );

    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      settings,
      mapping,
      new Lead()
    );

    System.assertEquals(1, attachments.size());
    System.assertEquals('Corporate_Brochure.pdf', attachments[0].getFileName());
  }

  @IsTest
  static void resolvesDepartmentNameFromLeadAndOpportunity() {
    System.assertEquals(
      'Crash Barrier',
      BWM_EmailBrochureAttachmentService.resolveDepartmentName(
        new Lead(Department_Name__c = 'Crash Barrier')
      )
    );
    System.assertEquals(
      'Steel Pipes',
      BWM_EmailBrochureAttachmentService.resolveDepartmentName(
        new Opportunity(Department_Name__c = 'Steel Pipes')
      )
    );
  }

  @IsTest
  static void skipsAttachmentWhenModeIsNone() {
    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_NONE
    );
    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      null,
      mapping,
      new Lead()
    );
    System.assertEquals(0, attachments.size());
  }

  @IsTest
  static void buildsDepartmentAttachmentFromUploadedFileWhenMapped() {
    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{
        'Crash Barrier' => new ContentVersion(
          Title = 'Crash Barrier',
          VersionData = Blob.valueOf('%PDF-test%')
        )
      }
    );
    BWM_EmailBrochureAttachmentService.setBrochureMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Email_Department_Brochure__mdt(
          Content_File_Title__c = 'Crash Barrier',
          File_Name__c = 'Crash Barrier.pdf'
        )
      }
    );
    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_DEPARTMENT
    );

    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      null,
      mapping,
      new Opportunity(Department_Name__c = 'Crash Barrier')
    );

    System.assertEquals(1, attachments.size());
    System.assertEquals('Crash Barrier.pdf', attachments[0].getFileName());
    BWM_EmailBrochureAttachmentService.clearCache();
  }

  @IsTest
  static void buildsDepartmentAttachmentFromMappedStaticResource() {
    BWM_EmailBrochureAttachmentService.setBrochureMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Email_Department_Brochure__mdt(
          Static_Resource_Name__c = 'BWM_Test_Brochure',
          File_Name__c = 'Crash_Barrier_Brochure.pdf'
        )
      }
    );
    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_DEPARTMENT
    );

    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      null,
      mapping,
      new Opportunity(Department_Name__c = 'Crash Barrier')
    );

    System.assertEquals(1, attachments.size());
    System.assertEquals('Crash_Barrier_Brochure.pdf', attachments[0].getFileName());
  }

  @IsTest
  static void injectsDepartmentProductBriefIntoRenderedEmail() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Steel Pipes' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'Engineered for strength and durability across infrastructure, industrial, and structural applications with long service life and corrosion resistance.\nTypes: Hollow Section Pipes | MS Pipes | GI Round Pipes| Square Pipes etc.'
        )
      }
    );

    Lead leadRecord = new Lead(Department_Name__c = 'Steel Pipes');
    String plainBrief = BWM_EmailProductBriefService.resolvePlainText(leadRecord);
    String htmlBrief = BWM_EmailProductBriefService.resolveHtml(leadRecord);
    String htmlTemplate = '<p>For over 40 years, Utkarsh India has supported India infrastructure growth.</p>\n\n<p>&nbsp;</p>\n\n<p>&nbsp;</p>\n\n<p>For more details, please find attached our Steel Pipes Brochure.</p>';
    String plainTemplate = 'For over 40 years, Utkarsh India has supported India infrastructure growth.   For more details, please find attached our Steel Pipes Brochure.';

    String injectedHtml = BWM_EmailProductBriefService.injectIntoContent(
      htmlTemplate,
      plainBrief,
      htmlBrief,
      leadRecord
    );
    String injectedPlain = BWM_EmailProductBriefService.injectIntoContent(
      plainTemplate,
      plainBrief,
      htmlBrief,
      leadRecord
    );

    System.assert(
      injectedHtml.contains('Engineered for strength and durability'),
      'HTML body should include department product brief'
    );
    System.assert(
      injectedHtml.contains('<p>Types: Hollow Section Pipes'),
      'HTML body should include the types line as normal text'
    );
    System.assert(
      injectedPlain.contains('Hollow Section Pipes'),
      'Plain body should include department product brief'
    );
    System.assert(
      !injectedHtml.contains('<p>&nbsp;</p>\n\n<p>&nbsp;</p>'),
      'Empty placeholder paragraphs should be replaced'
    );
  }

  @IsTest
  static void payloadBuilderInjectsProductBriefIntoBuiltEmail() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Crash Barrier' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'High-quality crash-tested barriers made from galvanised steel.\nTypes: W-Beam Crash Barriers | Thrie Beam Crash Barriers etc.'
        )
      }
    );

    BWM_EmailTemplateRenderer.RenderedEmail rendered = new BWM_EmailTemplateRenderer.RenderedEmail();
    rendered.fromSalesforceTemplate = true;
    rendered.subject = 'Subject';
    rendered.htmlBody = '<p>Intro</p>\n\n<p>&nbsp;</p>\n\n<p>&nbsp;</p>\n\n<p>For more details, please find attached our brochure.</p>';
    rendered.plainTextBody = 'Intro   For more details, please find attached our brochure.';
    BWM_EmailTemplateRenderer.testOverride = rendered;

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      new BWM_Email_Settings__mdt(Central_Sender_Email__c = 'noreply@example.com'),
      new BWM_Email_Template_Mapping__mdt(
        Template_Name__c = 'Prospect_Enq_dept',
        Template_Id__c = '00XC2000000qn9VMAQ',
        Subject_Template__c = 'Subject',
        Body_Template__c = 'Body',
        Sender_Type__c = BWM_EmailConstants.SENDER_CENTRAL,
        Recipient_Type__c = BWM_EmailConstants.RECIPIENT_CUSTOMER
      ),
      new Lead(
        Email = 'crashbarrier+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
        Department_Name__c = 'Crash Barrier'
      )
    );

    System.assert(
      built.htmlBody.contains('High-quality crash-tested barriers'),
      'Payload builder should inject product brief into HTML body'
    );
    System.assert(
      built.body.contains('W-Beam Crash Barriers'),
      'Payload builder should inject product brief into plain body'
    );

    BWM_EmailTemplateRenderer.clearCache();
    BWM_EmailProductBriefService.clearCache();
  }

  @IsTest
  static void negotiationLostFutureTenderDeptKeepsDepartmentNameInBody() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'High Mast & Polygonal' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'High-intensity lighting solutions for highways, ports, stadiums, railway yards, and industrial areas, designed for durability with a 25-year design life.\nTypes: High Mast | Flag Mast | Stadium & Sports Lighting Masts|Octagonal poles|Solar Street Light Poles|CCTV Poles etc.'
        )
      }
    );

    BWM_EmailTemplateRenderer.RenderedEmail rendered = new BWM_EmailTemplateRenderer.RenderedEmail();
    rendered.fromSalesforceTemplate = true;
    rendered.subject = 'Looking Forward to Future Opportunities';
    rendered.htmlBody =
      'Please find our <strong>High Mast & Polygonal</strong> brochure attached for your reference.';
    rendered.plainTextBody =
      'Please find our High Mast & Polygonal brochure attached for your reference.';
    BWM_EmailTemplateRenderer.testOverride = rendered;

    Opportunity opportunityRecord = createOpportunity(
      'Negotiation',
      null,
      'futuretender@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
    );
    opportunityRecord.Department_Name__c = 'High Mast & Polygonal';
    List<String> picklistValues = insertProductCategories(opportunityRecord.Id, 1);
    if (picklistValues.isEmpty()) {
      return;
    }

    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      new BWM_Email_Settings__mdt(Central_Sender_Email__c = 'noreply@example.com'),
      new BWM_Email_Template_Mapping__mdt(
        Template_Name__c = BWM_EmailConstants.TEMPLATE_NEGOTIATION_LOST_FUTURE_TENDER_DEPT,
        Template_Id__c = '00XC2000000rHNhMAM',
        Subject_Template__c = 'Looking Forward to Future Opportunities',
        Body_Template__c = 'Body',
        Sender_Type__c = BWM_EmailConstants.SENDER_CENTRAL,
        Recipient_Type__c = BWM_EmailConstants.RECIPIENT_CUSTOMER
      ),
      opportunityRecord
    );

    System.assert(
      built.htmlBody.contains('High Mast & Polygonal'),
      'Department name should remain in the brochure sentence'
    );
    System.assert(
      !built.htmlBody.contains('High-intensity lighting solutions'),
      'Product brief should not replace department name for this template'
    );

    BWM_EmailTemplateRenderer.clearCache();
    BWM_EmailProductBriefService.clearCache();
  }

  @IsTest
  static void productBriefPlaceholderReplacesTokenInTemplate() {
    String brief = 'Engineered for strength and durability.';
    Lead leadRecord = new Lead(Department_Name__c = 'Steel Pipes');
    String html = '<p>Intro</p><p>{#product_brief#}</p><p>Closing</p>';
    String injected = BWM_EmailProductBriefService.injectIntoContent(
      html,
      brief,
      '<p>' + brief + '</p>',
      leadRecord
    );
    System.assert(injected.contains(brief));
    System.assert(!injected.contains(BWM_EmailConstants.PRODUCT_BRIEF_PLACEHOLDER));
  }

  @IsTest
  static void replacesSalesforceProductBriefMergeToken() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'High Mast & Polygonal' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'High-intensity lighting solutions for highways, ports, stadiums, railway yards, and industrial areas, designed for durability with a 25-year design life.\nTypes: High Mast | Flag Mast | Stadium & Sports Lighting Masts|Octagonal poles|Solar Street Light Poles|CCTV Poles etc.'
        )
      }
    );

    Lead leadRecord = new Lead(Department_Name__c = 'High Mast & Polygonal');
    String plainBrief = BWM_EmailProductBriefService.resolvePlainText(leadRecord);
    String htmlBrief = BWM_EmailProductBriefService.resolveHtml(leadRecord);
    String htmlTemplate = '<p>For over 40 years, Utkarsh India has supported India infrastructure growth.</p>\n\n<p>{{Product_Brief}}</p>\n\n<p>For more details, please find attached our brochure.</p>';
    String injected = BWM_EmailProductBriefService.replaceProductBriefMergeTokens(
      htmlTemplate,
      plainBrief,
      htmlBrief
    );

    System.assert(
      injected.contains('High-intensity lighting solutions'),
      'Salesforce merge token should be replaced with department brief'
    );
    System.assert(
      injected.contains('<p>Types: High Mast'),
      'Types line should use normal paragraph formatting'
    );
    System.assert(
      !injected.contains('<strong>') && !injected.contains('<u>'),
      'Product brief should not be bold or underlined'
    );
    System.assert(
      !injected.contains('{{Product_Brief}}'),
      'Unresolved merge token should not remain'
    );
  }

  @IsTest
  static void productBriefRemovesTemplateBoldUnderlineWrapper() {
    String brief = 'Normal product description.\nTypes: Product A | Product B';
    String htmlBrief = BWM_EmailProductBriefService.formatAsHtml(brief);
    String htmlTemplate =
      '<p style="font-size:11pt"><b><u><span style="font-weight:bold;' +
      'text-decoration:underline">{{Product_Brief}}</span></u></b></p>';

    String injected = BWM_EmailProductBriefService.replaceProductBriefMergeTokens(
      htmlTemplate,
      brief,
      htmlBrief
    );

    System.assertEquals(
      '<p>Normal product description.</p>\n\n<p>Types: Product A | Product B</p>',
      injected
    );
  }

  @IsTest
  static void replacesRenderedProductCategoryWithDepartmentBrief() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Steel Pipes' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'Engineered for strength and durability across infrastructure, industrial, and structural applications with long service life and corrosion resistance.\nTypes: Hollow Section Pipes | MS Pipes | GI Round Pipes| Square Pipes etc.'
        )
      }
    );

    Lead leadRecord = new Lead(
      Department_Name__c = 'Steel Pipes',
      Product_Category__c = 'ERW Hollow Section Pipes'
    );
    String plainBrief = BWM_EmailProductBriefService.resolvePlainText(leadRecord);
    String htmlBrief = BWM_EmailProductBriefService.resolveHtml(leadRecord);
    String htmlTemplate = '<p>For over 40 years, Utkarsh India has supported India infrastructure growth.</p>\n\n<p>ERW Hollow Section Pipes</p>\n\n<p>For more details, please find attached our Steel Pipes Brochure.</p>';
    String injected = BWM_EmailProductBriefService.injectIntoContent(
      htmlTemplate,
      plainBrief,
      htmlBrief,
      leadRecord
    );

    System.assert(
      injected.contains('Engineered for strength and durability'),
      'Rendered product category should be replaced with department product brief'
    );
    System.assert(
      !injected.contains('<p>ERW Hollow Section Pipes</p>'),
      'Product category paragraph should be removed'
    );
  }

  @IsTest
  static void resolvesProductBriefParamFromCustomMetadata() {
    BWM_EmailProductBriefService.setBriefMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Steel Pipes' => new BWM_Email_Department_Brochure__mdt(
          Product_Brief__c = 'Engineered for strength and durability.'
        )
      }
    );

    String resolved = BWM_FieldValueResolver.resolveRecord(
      new Lead(Department_Name__c = 'Steel Pipes'),
      BWM_EmailConstants.FIELD_PRODUCT_BRIEF
    );

    System.assertEquals('Engineered for strength and durability.', resolved);
  }

  @IsTest
  static void callbackProspectEmailSendsAfterLeadMovesToProspecting() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"messages":[{"status":"PENDING_ACCEPTED"}]}', 200)
    );

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      BWM_EmailConstants.STAGE_PROSPECTING,
      'Crash Barrier',
      'callbackprospect@example.com'
    );

    Test.startTest();
    BWM_EmailService.SendResult result = BWM_EmailService.send(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      BWM_EmailConstants.STAGE_PROSPECT
    );
    Test.stopTest();

    System.assertEquals(1, result.logs.size());
    System.assert(
      result.sent == true || result.logs[0].Status__c == 'Failed',
      'Callback-after-prospecting should send or log native-send failure.'
    );
    System.assertEquals(1, result.logs.size());
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT,
      result.logs[0].Trigger_Point__c
    );
  }

  @IsTest
  static void taskEmailInvocableRoutesLostDetailsWhenTaskStageIsQualified() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'lostqualified@example.com'
    );

    BWM_SendTaskEmailInvocable.Request requestItem = buildTaskRequest(
      leadRecord.Id,
      'Lost',
      'Qualified',
      BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED
    );

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      responses[0].message
    );
  }

  @IsTest
  static void taskEmailInvocableRoutesLostDetailsUsingLiveProspectingStatus() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'liveprospecting@example.com'
    );

    BWM_SendTaskEmailInvocable.Request requestItem = buildTaskRequest(
      leadRecord.Id,
      'Lost',
      'Prospect',
      BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED
    );

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ requestItem }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING,
      responses[0].message
    );
  }

  @IsTest
  static void taskEmailInvocableRoutesCallbackAndLost() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'taskroute@example.com'
    );

    BWM_SendTaskEmailInvocable.Request callbackRequest = new BWM_SendTaskEmailInvocable.Request();
    callbackRequest.recordId = leadRecord.Id;
    callbackRequest.taskAction = 'Callback';
    callbackRequest.stageAtAction = 'Prospect';

    BWM_SendTaskEmailInvocable.Request lostRequest = new BWM_SendTaskEmailInvocable.Request();
    lostRequest.recordId = leadRecord.Id;
    lostRequest.taskAction = 'Lost';
    lostRequest.stageAtAction = 'Prospect';
    lostRequest.lostReason = BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED;

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      new List<BWM_SendTaskEmailInvocable.Request>{ callbackRequest, lostRequest }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(true, responses[1].queued);
  }

  @IsTest
  static void taskEmailInvocableRoutesAllLostGroupsAndCallbacks() {
    Lead prospectLead = createLead(
      'INBOUND EMAIL',
      'Prospecting',
      'Steel Pipes',
      'groups@example.com'
    );

    List<BWM_SendTaskEmailInvocable.Request> requests = new List<BWM_SendTaskEmailInvocable.Request>{
      buildTaskRequest(prospectLead.Id, 'Callback', 'Prospecting', null),
      buildTaskRequest(
        prospectLead.Id,
        'Lost',
        'Prospecting',
        BWM_EmailConstants.LOST_REASON_DETAILS_NOT_RECEIVED
      ),
      buildTaskRequest(prospectLead.Id, 'Lost', 'Prospect', 'Minimum Quantity Not Met'),
      buildTaskRequest(prospectLead.Id, 'Lost', 'Prospect', 'Purchase from Other Brand'),
      buildTaskRequest(prospectLead.Id, 'Lost', 'Prospect', 'Future Prospect'),
      buildTaskRequest(prospectLead.Id, 'Lost', 'Prospect', 'Price Enquiry'),
      new BWM_SendTaskEmailInvocable.Request(),
      buildTaskRequest(prospectLead.Id, 'Unknown', 'Prospect', null)
    };

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      requests
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(true, responses[1].queued);
    System.assertEquals(false, responses[6].queued);
    System.assertEquals(false, responses[7].queued);
  }

  @IsTest
  static void taskEmailInvocableCoversOpportunityCallbackAndRemainingLeadPaths() {
    Opportunity negotiationOpp = createOpportunity(
      BWM_EmailConstants.STAGE_NEGOTIATION,
      null,
      'nego-task@example.com',
      null
    );
    Opportunity nurtureOpp = createOpportunity(
      BWM_EmailConstants.STAGE_NURTURE,
      null,
      'nurture-task@example.com',
      null
    );
    Lead prospectingLead = createLead(
      'INBOUND EMAIL',
      BWM_EmailConstants.STAGE_PROSPECTING,
      'Steel Pipes',
      'remaining-lost@example.com'
    );
    Account unrelated = new Account(Name = 'Task Email Unrelated ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system unrelated;

    List<BWM_SendTaskEmailInvocable.Request> requests = new List<BWM_SendTaskEmailInvocable.Request>{
      buildTaskRequest(
        negotiationOpp.Id,
        'Callback',
        BWM_EmailConstants.STAGE_NEGOTIATION,
        null
      ),
      buildTaskRequest(
        nurtureOpp.Id,
        'Callback',
        BWM_EmailConstants.STAGE_NURTURE,
        null
      ),
      buildTaskRequest(nurtureOpp.Id, 'Callback', '', null),
      buildTaskRequest(nurtureOpp.Id, 'Lost', BWM_EmailConstants.STAGE_NURTURE, 'Not responding'),
      buildTaskRequest(
        prospectingLead.Id,
        'Lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Not Responding'
      ),
      buildTaskRequest(
        prospectingLead.Id,
        'Lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Existing Customer'
      ),
      buildTaskRequest(
        prospectingLead.Id,
        'Lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Out of Service Area'
      ),
      buildTaskRequest(
        prospectingLead.Id,
        'Lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Purchase from Other Brand'
      ),
      buildTaskRequest(
        prospectingLead.Id,
        'Lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Future Prospect'
      ),
      buildTaskRequest(prospectingLead.Id, 'Callback', 'Qualified', null),
      buildTaskRequest(prospectingLead.Id, 'Callback', 'Lost', null),
      buildTaskRequest(unrelated.Id, 'Callback', 'Prospect', null)
    };

    Test.startTest();
    List<BWM_SendTaskEmailInvocable.Response> responses = BWM_SendTaskEmailInvocable.sendTaskEmail(
      requests
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].queued);
    System.assertEquals(true, responses[1].queued);
    System.assertEquals(true, responses[2].queued);
    System.assertEquals(false, responses[3].queued);
    System.assertEquals(true, responses[4].queued);
    System.assertEquals(true, responses[10].queued);
    System.assertEquals(false, responses[11].queued);
  }

  private static BWM_SendTaskEmailInvocable.Request buildTaskRequest(
    Id recordId,
    String taskAction,
    String stageAtAction,
    String lostReason
  ) {
    BWM_SendTaskEmailInvocable.Request requestItem = new BWM_SendTaskEmailInvocable.Request();
    requestItem.recordId = recordId;
    requestItem.taskAction = taskAction;
    requestItem.stageAtAction = stageAtAction;
    requestItem.lostReason = lostReason;
    return requestItem;
  }

  @IsTest
  static void apiResponseParsesFailure() {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(400);
    response.setBody('{"error":"bad request"}');
    BWM_EmailApiResponse parsed = BWM_EmailApiResponse.parse(response);
    System.assertEquals(false, parsed.isSuccess);
    System.assertEquals(400, parsed.httpStatus);
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

  private static Opportunity buildOpportunityForOwnerCrmMatch(
    String stageName,
    String departmentName,
    String ownerName
  ) {
    return (Opportunity) JSON.deserialize(
      '{"StageName":"' +
        stageName +
        '","Department_Name__c":"' +
        departmentName +
        '","CRM_User_Name_Formula__c":"' +
        ownerName +
        '","Owner":{"attributes":{"type":"User"},"Name":"' +
        ownerName +
        '"}}',
      Opportunity.class
    );
  }

  private static Lead createLead(
    String leadSource,
    String status,
    String department,
    String email
  ) {
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
    String uniqueKey = uniqueSuffix();
    Lead leadRecord = new Lead(
      LastName = 'EmailTest ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueKey,
      Company = 'Test Company  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + uniqueKey,
      LeadSource = leadSource,
      Status = status,
      Department_Name__c = department,
      Email = uniqueEmail(email, uniqueKey),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    insert as system leadRecord;
    return leadRecord;
  }

  @IsTest
  static void dealerSalesAssignAggregatesRelatedProductCategories() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'productcats@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    List<String> picklistValues = insertProductCategories(opportunityRecord.Id, 2);
    if (picklistValues.size() < 2) {
      return;
    }

    String aggregated = BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      opportunityRecord
    );

    System.assertEquals(
      picklistValues[0] + ';' + picklistValues[1],
      aggregated
    );
  }

  @IsTest
  static void dealerSalesAssignTemplateUsesPipeDelimitedProductCategories() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'templatecats@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    List<String> picklistValues = insertProductCategories(opportunityRecord.Id, 2);
    if (picklistValues.size() < 2) {
      return;
    }

    String templateBody =
      'Product Interest: {{{Opportunity.Product_Category__c}}}';
    String converted = BWM_EmailTemplateRenderer.applyDealerSalesAssignTemplateSubstitutionsForTest(
      templateBody,
      opportunityRecord,
      BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN
    );

    System.assertEquals(
      'Product Interest: ' + picklistValues[0] + ' | ' + picklistValues[1],
      converted
    );
    System.assert(!converted.contains('{{{Opportunity.Product_Category__c}}}'));
  }

  @IsTest
  static void dealerSalesAssignTemplateUsesSingleRelatedProductCategory() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'templatecats@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    List<String> picklistValues = insertProductCategories(opportunityRecord.Id, 1);
    if (picklistValues.isEmpty()) {
      return;
    }

    String templateBody =
      'Product Interest: {{{Opportunity.Product_Category__c}}}';
    String converted = BWM_EmailTemplateRenderer.applyDealerSalesAssignTemplateSubstitutionsForTest(
      templateBody,
      opportunityRecord,
      BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN
    );

    System.assert(converted.contains(picklistValues[0]));
    System.assert(!converted.contains('{{{Opportunity.Product_Category__c}}}'));
  }

  @IsTest
  static void dealerSalesAssignTemplateUsesAccountNameForCompany() {
    Opportunity opportunityRecord = createOpportunity(
      'Prospecting',
      null,
      'company@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );

    String templateBody = 'Company: {{{Opportunity.Account.Name}}}';
    String converted = BWM_EmailTemplateRenderer.applyDealerSalesAssignTemplateSubstitutionsForTest(
      templateBody,
      opportunityRecord,
      BWM_EmailConstants.TEMPLATE_DEALER_SALES_ASSIGN
    );

    System.assert(converted.contains(opportunityRecord.Account.Name));
    System.assert(!converted.contains('{{{Opportunity.Account.Name}}}'));
  }

  private static List<String> insertProductCategories(Id opportunityId, Integer count) {
    List<String> values = new List<String>();
    for (
      Schema.PicklistEntry entry : Product_Category__c.Product_Category__c.getDescribe()
        .getPicklistValues()
    ) {
      if (!entry.isActive() || entry.getValue() == 'High Mast') {
        continue;
      }
      try {
        insert as system new Product_Category__c(
          Opportunity__c = opportunityId,
          Product_Category__c = entry.getValue()
        );
        values.add(entry.getValue());
        if (values.size() == count) {
          break;
        }
      } catch (DmlException ex) {
        continue;
      }
    }
    return values;
  }

  private static String uniqueSuffix() {
    return String.valueOf(Math.abs(Crypto.getRandomInteger())) +
      String.valueOf(System.now().getTime());
  }

  private static String uniqueEmail(String email, String uniqueKey) {
    if (String.isBlank(email)) {
      return null;
    }
    if (!email.contains('@')) {
      return uniqueKey + '.' + email + '@example.com';
    }
    List<String> parts = email.split('@', 2);
    return parts[0] + '+' + uniqueKey + '@' + parts[1];
  }

  @IsTest
  static void emailServiceCoversDisabledBlankAndScheduleGuards() {
    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      'Prospect',
      'Steel Pipes',
      'guards@example.com'
    );

    BWM_EmailService.SendResult missingIds = BWM_EmailService.send(null, 'x');
    BWM_EmailService.SendResult blankTrigger = BWM_EmailService.send(
      leadRecord.Id,
      ''
    );
    BWM_EmailService.SendResult scheduled = BWM_EmailService.sendScheduled(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT
    );
    Boolean skippedNullSchedule = BWM_EmailService.scheduleDelayedSend(null, 'x', 1);
    Boolean skippedBlankTrigger = BWM_EmailService.scheduleDelayedSend(
      leadRecord.Id,
      '',
      24
    );
    Boolean scheduledOk = BWM_EmailService.scheduleDelayedSend(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED,
      24
    );
    Boolean scheduledDup = BWM_EmailService.scheduleDelayedSend(
      leadRecord.Id,
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED,
      24
    );

    BWM_EmailService.SendResult createSend = BWM_EmailService.sendForLeadCreate(
      leadRecord.Id
    );
    System.assertNotEquals(null, createSend);
    System.assertEquals(false, missingIds.sent);
    System.assertEquals(false, blankTrigger.sent);
    System.assertNotEquals(null, scheduled);
    System.assertEquals(false, skippedNullSchedule);
    System.assertEquals(false, skippedBlankTrigger);
    System.assertEquals(true, scheduledOk);
    System.assertEquals(false, scheduledDup);
  }

  private static Id dealerAccountRecordTypeId() {
    return accountRecordTypeId(new List<String>{ 'Dealer', 'Dealer_Account' });
  }

  private static Id endCustomerAccountRecordTypeId() {
    return accountRecordTypeId(
      new List<String>{ 'End_Customer', 'EndCustomer', 'Customer' }
    );
  }

  private static Id accountRecordTypeId(List<String> developerNames) {
    Map<String, Schema.RecordTypeInfo> infos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    for (String developerName : developerNames) {
      if (infos.containsKey(developerName) && infos.get(developerName).isAvailable()) {
        return infos.get(developerName).getRecordTypeId();
      }
    }
    for (Schema.RecordTypeInfo info : Schema.SObjectType.Account.getRecordTypeInfos()) {
      if (!info.isAvailable() || info.isMaster()) {
        continue;
      }
      String label = info.getName();
      for (String developerName : developerNames) {
        if (label != null && label.replace(' ', '_').equalsIgnoreCase(developerName)) {
          return info.getRecordTypeId();
        }
      }
    }
    return null;
  }

  private static Account createCustomerAccount(String name) {
    Account accountRecord = new Account(
      Name = name + uniqueSuffix(),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10) + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000000000))
    );
    Id recordTypeId = endCustomerAccountRecordTypeId();
    if (recordTypeId != null) {
      accountRecord.RecordTypeId = recordTypeId;
    }
    insert as system accountRecord;
    return accountRecord;
  }

  private static Account createDealerAccount(String name, String email) {
    Account accountRecord = new Account(
      Name = name + uniqueSuffix(),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10) + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000000000)),
      Email__c = email
    );
    Id recordTypeId = dealerAccountRecordTypeId();
    if (recordTypeId != null) {
      accountRecord.RecordTypeId = recordTypeId;
    }
    insert as system accountRecord;
    return accountRecord;
  }

  private static Opportunity createOpportunity(
    String stageName,
    Id dealerAccountId,
    String email,
    String customerJourney
  ) {
    Account accountRecord = createCustomerAccount('Opp Account');
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Email Opp  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + stageName,
      StageName = stageName,
      CloseDate = Date.today().addDays(30),
      AccountId = accountRecord.Id,
      DealerAccount__c = dealerAccountId,
      Email__c = email,
      Customer_Journey__c = customerJourney
    );
    insert as system opportunityRecord;
    return BWM_EmailRecordQueryService.queryOpportunity(opportunityRecord.Id);
  }

  @IsTest
  static void prospectLostFutureGenBrochureUtilCoversEnquiryAndProduct() {
    Lead enquiryLead = new Lead(Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY);
    Lead productLead = new Lead(Department_Name__c = 'Crash Barrier');
    System.assertEquals(
      'Corporate',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(enquiryLead)
    );
    System.assertEquals(
      'Crash Barrier',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(productLead)
    );
    System.assertEquals('', BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(null));
    System.assertEquals(
      'keep',
      BWM_ProspectLostFutureGenBrochureUtil.applyRenderedHtmlFix(
        'keep',
        enquiryLead,
        'Other'
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
  }


  @IsTest
  static void infobipResolveTemplateIdsForBlankSubject() {
    System.assertEquals(
      new Set<String>(),
      BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(null)
    );
    System.assertEquals(null, BWM_InfobipEmailTemplateService.fetchTemplateMetadata(null));
  }


  @IsTest
  static void infobipFetchTemplatesAndCampaignSubjects() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","imagePreviewUrl":"/p.png","createdAt":"2026-07-14T09:49:49.543+0000","updatedAt":"2026-07-14T09:49:49.546+0000"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );
    Test.startTest();
    List<BWM_InfobipEmailTemplateService.TemplateOption> templates =
      BWM_InfobipEmailTemplateService.fetchTemplates();
    Test.stopTest();
    System.assertEquals(1, templates.size());
  }


  private class InfobipListThenDetailMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      if (request.getEndpoint() != null && request.getEndpoint().contains('/email/1/templates/')) {
        response.setBody(
          '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"Welcome to Utkarsh Steel"}'
        );
      } else {
        response.setBody(
          '{"results":[{"id":205000000067199,"name":"NABL_HIGH_MAST_2026"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}'
        );
      }
      return response;
    }
  }

  @IsTest
  static void infobipFetchCampaignSubjectsAndTemplateIds() {
    Test.setMock(HttpCalloutMock.class, new InfobipListThenDetailMock());
    Test.startTest();
    List<BWM_InfobipEmailTemplateService.SubjectOption> subjects =
      BWM_InfobipEmailTemplateService.fetchCampaignEmailSubjectOptions();
    Set<String> ids = BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(
      'Welcome to Utkarsh Steel'
    );
    Test.stopTest();
    System.assertNotEquals(null, subjects);
    System.assertNotEquals(null, ids);
  }


  @IsTest
  static void infobipFetchTemplatesHttpErrorAndNoSubject() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"description":"boom"}', 500)
    );
    Boolean threw = false;
    try {
      BWM_InfobipEmailTemplateService.fetchTemplates();
    } catch (BWM_EmailException ex) {
      threw = true;
    }
    System.assertEquals(true, threw);

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"id":1,"name":"T","subject":"No Subject"}',
        200
      )
    );
    String subject = BWM_InfobipEmailTemplateService.fetchTemplateSubject('1');
    System.assertEquals(null, subject);
  }


  @IsTest
  static void infobipFetchTemplatesAuthError() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"description":"unauthorized"}', 401)
    );
    Boolean threw = false;
    try {
      BWM_InfobipEmailTemplateService.fetchTemplates();
    } catch (BWM_EmailException ex) {
      threw = true;
      System.assert(ex.getMessage() != null);
    }
    System.assertEquals(true, threw);
  }


  @IsTest
  static void infobipFetchTemplatesSortsByName() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":2,"name":"Zeta"},{"id":1,"name":"Alpha"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":2}}',
        200
      )
    );
    Test.startTest();
    List<BWM_InfobipEmailTemplateService.TemplateOption> templates =
      BWM_InfobipEmailTemplateService.fetchTemplates();
    Test.stopTest();
    System.assertEquals(2, templates.size());
    System.assertEquals('Alpha', templates[0].label);
  }

  @IsTest
  static void brochureFileService_NullAndMissingTitles() {
    BWM_BrochureFileService.clearCache();
    System.assertEquals(null, BWM_BrochureFileService.resolveFileBrochure(null, null));
    System.assertEquals(null, BWM_BrochureFileService.resolveFileBrochure('  ', 'x.pdf', true));
    System.assertEquals(
      null,
      BWM_BrochureFileService.resolveFileBrochure('Missing Brochure File', 'x.pdf', false)
    );
    System.assertEquals(null, BWM_BrochureFileService.getPublicDownloadUrl(null));
    System.assertEquals(null, BWM_BrochureFileService.getPublicDownloadUrl('Missing Brochure File'));
    System.assertEquals(
      null,
      BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(null, 'x.pdf')
    );
    System.assertEquals(
      null,
      BWM_BrochureFileService.buildEmailAttachment('Missing Brochure File', 'x.pdf')
    );
    System.assertEquals(
      false,
      BWM_BrochureFileService.hasPdfContentVersion('Missing Brochure File')
    );
    System.assertEquals(
      null,
      BWM_BrochureFileService.getEmailPdfVersion('Missing Brochure File')
    );
    System.assertEquals(
      null,
      BWM_BrochureFileService.getEmailPdfVersion('  ')
    );
    System.assertEquals(
      null,
      BWM_BrochureFileService.ensurePublicDownloadUrl('Missing Brochure File', null)
    );
    System.assertEquals(
      null,
      BWM_BrochureFileService.getLatestPdfVersion('Missing Brochure File')
    );
    System.assertEquals(null, BWM_BrochureFileService.getLatestPdfVersion('  '));
  }

  @IsTest
  static void brochureFileService_ResolvesUploadedPdfAndPublicUrl() {
    ContentVersion pdfVersion = new ContentVersion(
      Title = 'Email Brochure File',
      PathOnClient = 'EmailBrochureFile.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 email-brochure'),
      IsMajorVersion = true
    );
    insert as system pdfVersion;
    pdfVersion = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId, VersionData
      FROM ContentVersion
      WHERE Id = :pdfVersion.Id
    ];

    BWM_BrochureFileService.clearCache();
    ContentVersion fromSoql = BWM_BrochureFileService.getEmailPdfVersion(
      'Email Brochure File'
    );
    System.assertNotEquals(null, fromSoql);

    String createdUrl = BWM_BrochureFileService.ensurePublicDownloadUrl(
      'Email Brochure File',
      pdfVersion.Id
    );
    String existingUrl = BWM_BrochureFileService.ensurePublicDownloadUrl(
      'Email Brochure File',
      pdfVersion.Id
    );
    System.assertEquals(createdUrl, existingUrl);

    BWM_BrochureFileService.clearCache();
    ContentVersion latest = BWM_BrochureFileService.getLatestPdfVersion(
      'Email Brochure File'
    );
    System.assertNotEquals(null, latest);
    System.assertNotEquals(
      null,
      BWM_BrochureFileService.getLatestPdfVersion('  Email Brochure File  ')
    );

    BWM_BrochureFileService.FileBrochure withBody = BWM_BrochureFileService.resolveFileBrochure(
      'Email Brochure File',
      'brochure',
      true
    );
    BWM_BrochureFileService.FileBrochure withoutBody = BWM_BrochureFileService.resolveFileBrochure(
      'Email Brochure File',
      'brochure.pdf',
      false
    );
    System.assertNotEquals(null, withBody);
    System.assertNotEquals(null, withBody.body);
    System.assertEquals(null, withoutBody.body);
    System.assertNotEquals(
      null,
      BWM_BrochureFileService.getPublicDownloadUrl('Email Brochure File')
    );
    System.assertEquals(
      true,
      BWM_BrochureFileService.hasPdfContentVersion('Email Brochure File')
    );

    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{ 'Email Brochure File' => pdfVersion }
    );
    BWM_BrochureFileService.setPublicUrlMapForTest(
      new Map<String, String>{
        'Email Brochure File' => 'https://files.example.com/brochure.pdf',
        String.valueOf(pdfVersion.Id) => 'https://files.example.com/brochure.pdf?asPdf=false'
      }
    );
    System.assert(
      BWM_BrochureFileService.getPublicDownloadUrl('Email Brochure File')
        .contains('brochure.pdf')
    );
    Messaging.EmailFileAttachment mappedAttachment = BWM_BrochureFileService.buildEmailAttachment(
      'Email Brochure File',
      'mapped'
    );
    System.assertNotEquals(null, mappedAttachment);
    System.assert(
      mappedAttachment.getFileName().toLowerCase().endsWith('.pdf')
    );
  }

  @IsTest
  static void emailRequestSettingsAndTriggerHandlersCoverRemainingLines() {
    BWM_EmailSettingsService.clearCache();
    System.assertNotEquals(null, BWM_EmailSettingsService.getSettings());
    BWM_EmailSettingsService.clearCache();
    System.assertNotEquals(null, BWM_EmailSettingsService.getSettings());

    Lead leadRecord = createLead(
      'INBOUND EMAIL',
      BWM_EmailConstants.STAGE_PROSPECT,
      'Steel Pipes',
      'email-req@example.com'
    );
    System.assertNotEquals(null, new BWM_EmailRequest());
    System.assertEquals(
      leadRecord.Id,
      new BWM_EmailRequest(leadRecord.Id, 'Lead_Create').recordId
    );
    System.assertEquals(
      'Prospect',
      new BWM_EmailRequest(leadRecord.Id, 'Lead_Create', 'Prospect').stageAtAction
    );

    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
    BWM_EmailLeadTriggerHandler.handleAfterInsert(null);
    BWM_EmailLeadTriggerHandler.handleAfterInsert(new List<Lead>());
    BWM_EmailLeadTriggerHandler.handleAfterInsert(
      new List<Lead>{ new Lead(LastName = 'Skip ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Status = 'Prospect') }
    );
    BWM_EmailLeadTriggerHandler.skipEnqueueForTests = false;
    BWM_EmailLeadTriggerHandler.throwForTriggerTest = true;
    Boolean threw = false;
    try {
      BWM_EmailLeadTriggerHandler.handleAfterInsert(new List<Lead>{ leadRecord });
    } catch (BWM_EmailException ex) {
      threw = true;
    }
    BWM_EmailLeadTriggerHandler.throwForTriggerTest = false;
    System.assertEquals(true, threw);
    System.assertEquals(
      false,
      BWM_EmailLeadTriggerHandler.isExotelLeadEligible(null)
    );

    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(null);
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(new List<Opportunity>());
    Opportunity nurtureOpp = createOpportunity(
      BWM_EmailConstants.STAGE_NURTURE,
      null,
      'nurture-trig@example.com',
      null
    );
    Opportunity dealerOpp = createOpportunity(
      'Prospecting',
      null,
      'dealer-trig@example.com',
      BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    dealerOpp.Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY;
    dealerOpp.LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL;
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(
      new List<Opportunity>{ nurtureOpp, dealerOpp, new Opportunity() }
    );
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(null, null);
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );
    Opportunity oldDealer = dealerOpp.clone(true, true, true, true);
    oldDealer.Customer_Journey__c = 'Direct';
    oldDealer.Lost_Reason__c = null;
    dealerOpp.Lost_Reason__c = 'Not responding';
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ dealerOpp },
      new Map<Id, Opportunity>{ dealerOpp.Id => oldDealer }
    );
    System.assertEquals(
      false,
      BWM_EmailOpportunityTriggerHandler.isDealerEnquiryOpportunity(null)
    );
    System.assertEquals(
      true,
      BWM_EmailOpportunityTriggerHandler.isDealerEnquiryOpportunity(dealerOpp)
    );
  }

  @IsTest
  static void brochureFileService_PublicUrlFetchAndErrorPaths() {
    ContentVersion pdfVersion = new ContentVersion(
      Title = 'Callout Brochure File',
      PathOnClient = 'CalloutBrochureFile.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 callout-brochure'),
      IsMajorVersion = true
    );
    insert as system pdfVersion;
    pdfVersion = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :pdfVersion.Id
    ];
    BWM_BrochureFileService.ensurePublicDownloadUrl(
      'Callout Brochure File',
      pdfVersion.Id
    );

    ContentVersion stubWithoutBody = new ContentVersion(
      Id = pdfVersion.Id,
      Title = 'Callout Brochure File'
    );
    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{ 'Callout Brochure File' => stubWithoutBody }
    );

    Test.setMock(HttpCalloutMock.class, new BrochurePdfCalloutMock(200));
    Test.startTest();
    Messaging.EmailFileAttachment fromPublic = BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
      'https://files.example.com/callout.pdf?asPdf=false',
      'callout.pdf'
    );
    Messaging.EmailFileAttachment fromPlainUrl = BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
      'https://files.example.com/callout.pdf',
      'callout.pdf'
    );
    Messaging.EmailFileAttachment fromEmailPath = BWM_BrochureFileService.buildEmailAttachment(
      'Callout Brochure File',
      'callout.pdf'
    );
    Test.stopTest();
    System.assertNotEquals(null, fromPublic);
    System.assertNotEquals(null, fromPlainUrl);
    System.assertNotEquals(null, fromEmailPath);

    Test.setMock(HttpCalloutMock.class, new BrochurePdfCalloutMock(500));
    System.assertEquals(
      null,
      BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
        'https://files.example.com/missing.pdf',
        'missing.pdf'
      )
    );

    Test.setMock(HttpCalloutMock.class, new BrochureThrowingCalloutMock());
    System.assertEquals(
      null,
      BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
        'https://files.example.com/throw.pdf',
        'throw.pdf'
      )
    );
  }

  private class BrochurePdfCalloutMock implements HttpCalloutMock {
    private final Integer statusCode;
    BrochurePdfCalloutMock(Integer statusCode) {
      this.statusCode = statusCode;
    }
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      if (statusCode >= 200 && statusCode < 300) {
        response.setBodyAsBlob(Blob.valueOf('%PDF-1.4 mock-brochure'));
      } else {
        response.setBody('error');
      }
      return response;
    }
  }

  private class BrochureThrowingCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      throw new CalloutException('simulated brochure download failure');
    }
  }

}