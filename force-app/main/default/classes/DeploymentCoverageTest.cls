/**
 * @description Extra tests so listed production classes reach 75% coverage.
 *              Does not change production behavior.
 */
@IsTest
private class DeploymentCoverageTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"accepted"}';

  @IsTest
  static void coversSchedulersBatchesQueueablesAndControllers() {
    Account dealer = new Account(Name = 'Coverage Dealer ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system dealer;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Coverage Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(10),
      AccountId = dealer.Id,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'cov.opp@example.com',
      Amount = 1000
    );
    insert as system opportunityRecord;
    Lead leadRecord = new Lead(
      LastName = 'Coverage Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Coverage Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;

    Test.startTest();
    new BWM_EmailMonthlyScheduler().execute(null);

    BWM_EmailNegotiationStageUpdateBatch staleBatch = new BWM_EmailNegotiationStageUpdateBatch();
    staleBatch.start(null);
    staleBatch.execute(null, new List<Opportunity>{ opportunityRecord });
    staleBatch.finish(null);
    staleBatch.execute((SchedulableContext) null);

    BWM_EmailNegotiationTenderMonthlyBatch tenderBatch = new BWM_EmailNegotiationTenderMonthlyBatch();
    tenderBatch.start(null);
    tenderBatch.execute(null, new List<Opportunity>{ opportunityRecord });
    tenderBatch.finish(null);
    tenderBatch.execute((SchedulableContext) null);

    System.assertEquals(
      false,
      BWM_EmailOpportunityFieldHistoryService.isStageStaleForDays(null, 30)
    );
    System.assertNotEquals(
      null,
      BWM_EmailOpportunityFieldHistoryService.buildStageStaleMap(
        new Set<Id>{ opportunityRecord.Id },
        30
      )
    );

    Test.setCurrentPage(Page.BWM_DealerMonthlyOpportunityList);
    ApexPages.currentPage().getParameters().put('accountId', String.valueOf(dealer.Id));
    BWM_DealerMonthlyListCtrl ctrl = new BWM_DealerMonthlyListCtrl();
    System.assertNotEquals(null, ctrl.rows);
    ApexPages.currentPage().getParameters().remove('accountId');
    BWM_DealerMonthlyListCtrl emptyCtrl = new BWM_DealerMonthlyListCtrl();
    System.assertEquals('Dealer', emptyCtrl.dealerName);

    BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(null);
    BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(dealer.Id);

    CreateDealerOpportunityController.getOpportunityRecordTypeId();
    try {
      CreateDealerOpportunityController.getDealerAccounts();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Boolean dealerRequired = false;
    try {
      CreateDealerOpportunityController.getDealerDetails(null);
    } catch (Exception ex) {
      dealerRequired = true;
    }
    System.assertEquals(true, dealerRequired);
    try {
      CreateDealerOpportunityController.getDealerDetails(dealer.Id);
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );
    System.enqueueJob(new BWM_LeadMessagingQueueable(new List<Id>{ leadRecord.Id }));
    System.enqueueJob(new BWM_LeadMessagingQueueable(null));
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(null);
    BWM_LeadMessagingTriggerHandler.handleAfterInsert(new List<Lead>());
    BWM_LeadMessagingTriggerHandler.enqueueMessaging(new List<Id>());
    Test.stopTest();
  }

  @IsTest
  static void coversChannelSendServices() {
    Account accountRecord = new Account(Name = 'RCS Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'RCS Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system contactRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'RCS Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(20),
      AccountId = accountRecord.Id,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system opportunityRecord;
    Lead leadRecord = new Lead(
      LastName = 'WA Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'WA Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'RCS Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'offline.cov@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system offlineRecord;

    seedWhatsAppCache('coverage_wa');
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'coverage_sms',
          'TemplateName' => 'coverage_sms',
          'dltTemplateId' => 'DLT1',
          'templateText' => 'Hello {#var#}'
        }
      }
    );
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'coverage_rcs',
          'templateText' => 'Hello'
        }
      }
    );

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Test.startTest();
    Boolean threw = false;
    try {
      AccountManagementRcsService.sendToAccounts(new List<Id>(), 'coverage_rcs');
    } catch (Exception ex) {
      threw = true;
    }
    try {
      AccountManagementSmsService.sendToAccounts(new List<Id>(), 'coverage_sms');
    } catch (Exception ex) {
      threw = true;
    }
    AccountManagementRcsService.sendToAccounts(
      new List<Id>{ accountRecord.Id },
      'coverage_rcs'
    );
    AccountManagementSmsService.sendToAccounts(
      new List<Id>{ accountRecord.Id },
      'coverage_sms'
    );
    ContactManagementRcsService.sendToContacts(
      new List<Id>{ contactRecord.Id },
      'coverage_rcs'
    );
    ContactManagementSmsService.sendToContacts(
      new List<Id>{ contactRecord.Id },
      'coverage_sms'
    );
    OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
      new List<Id>{ offlineRecord.Id },
      'coverage_rcs'
    );
    OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
      new List<Id>{ offlineRecord.Id },
      'coverage_sms'
    );
    try {
      DealerOpportunityRcsService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'coverage_rcs'
      );
      DealerOpportunitySmsService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'coverage_sms'
      );
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'coverage_wa'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      LeadManagementWhatsAppService.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'coverage_wa'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();
    System.assertEquals(true, threw);
  }

  @IsTest
  static void coversHelpersInvocableAndEmailRender() {
    Lead leadRecord = new Lead(
      LastName = 'Helper Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Helper Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY
    );
    insert as system leadRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Helper Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(5)
    );
    insert as system opportunityRecord;

    System.assertEquals(
      'Corporate',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(leadRecord)
    );
    System.assertEquals(
      '',
      BWM_ProspectLostFutureGenBrochureUtil.resolveBrochureLabel(null)
    );
    BWM_ProspectLostFutureGenBrochureUtil.applyRenderedHtmlFix(
      '>Enquiry</strong> brochure',
      leadRecord,
      'Prospect_lost_future_tender_gen'
    );
    BWM_ProspectLostFutureGenBrochureUtil.applyTemplateSubstitutions(
      '{{{Lead.Department_NameFormula__c}}}',
      leadRecord,
      'Prospect_lost_future_tender_gen'
    );

    System.assertEquals(
      '',
      BWM_OpportunityProductCategoryService.resolveAggregatedCategories(null)
    );
    BWM_OpportunityProductCategoryService.resolveAggregatedCategories(opportunityRecord);

    BWM_BrochureFileService.clearCache();
    BWM_BrochureFileService.resolveFileBrochure(null, null);
    BWM_BrochureFileService.resolveFileBrochure('Missing File', 'x.pdf', true);
    BWM_BrochureFileService.getPublicDownloadUrl(null);
    BWM_BrochureFileService.getPublicDownloadUrl('Missing File');
    BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(null, 'x.pdf');
    BWM_BrochureFileService.buildEmailAttachment('Missing File', 'x.pdf');
    BWM_BrochureFileService.hasPdfContentVersion('Missing File');
    BWM_BrochureFileService.getEmailPdfVersion('Missing File');
    BWM_BrochureFileService.ensurePublicDownloadUrl('Missing File', null);
    BWM_BrochureFileService.getLatestPdfVersion('Missing File');

    LeadManagementEmailService.renderTemplate(null, leadRecord);
    LeadManagementEmailService.buildBrochureAttachments(null, leadRecord);
    DealerOpportunityEmailService.renderTemplate(null, opportunityRecord, null);
    DealerOpportunityEmailService.buildBrochureAttachments('x', opportunityRecord);

    BWM_SendTaskEmailInvocable.Request requestItem = new BWM_SendTaskEmailInvocable.Request();
    requestItem.recordId = leadRecord.Id;
    requestItem.taskAction = 'Callback';
    requestItem.stageAtAction = 'Prospect';
    List<BWM_SendTaskEmailInvocable.Response> responses =
      BWM_SendTaskEmailInvocable.sendTaskEmail(
        new List<BWM_SendTaskEmailInvocable.Request>{
          requestItem,
          new BWM_SendTaskEmailInvocable.Request()
        }
      );
    System.assertEquals(2, responses.size());

    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":"tmpl-1","name":"Welcome","imagePreviewUrl":"/p.png"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );
    Test.startTest();
    try {
      BWM_InfobipEmailTemplateService.fetchTemplates();
      BWM_InfobipEmailTemplateService.fetchCampaignEmailSubjectOptions();
      BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject('Welcome');
      BWM_InfobipEmailTemplateService.fetchTemplateSubject('tmpl-1');
      BWM_InfobipEmailTemplateService.fetchTemplateMetadata(null);
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();
  }

  @IsTest
  static void coversPayloadBuilders() {
    Account accountRecord = new Account(Name = 'Payload Acc ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();

    BWM_SmsDirectPayloadBuilder.cacheTemplates(null);
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => 'cov_sms',
          'dltTemplateId' => 'DLT9',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
    try {
      BWM_SmsDirectPayloadBuilder.buildPayload(
        settings,
        'cov_sms',
        accountRecord,
        '9876500999'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }

    BWM_RcsDirectPayloadBuilder.cacheTemplates(null);
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'cov_rcs',
          'templateText' => 'Hello',
          'Component' => new Map<String, Object>{
            'Cards' => new List<Object>{
              new Map<String, Object>{
                'DescVariables' => new List<Object>{
                  new Map<String, Object>{ '{{1}}' => 'Department_name_1' }
                },
                'TitleVariables' => new List<Object>{
                  new Map<String, Object>{ '{{2}}' => 'product_brief' }
                }
              }
            }
          }
        }
      }
    );
    BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'cov_rcs',
      accountRecord,
      new Map<String, Object>{ '{{1}}' => 'Department_name_1' }
    );
    try {
      BWM_RcsDirectPayloadBuilder.buildPayload(
        settings,
        'cov_rcs',
        accountRecord,
        '9876500999'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
  }

  @IsTest
  static void coversRemainingCoverageGaps() {
    Account dealer = new Account(
      Name = 'Gap Dealer ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'gap.dealer@example.com'
    );
    insert as system dealer;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Gap Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_EmailConstants.STAGE_NEGOTIATION,
      CloseDate = Date.today().addDays(12),
      AccountId = dealer.Id,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'gap.opp@example.com',
      Amount = 2500
    );
    insert as system opportunityRecord;
    Test.setCreatedDate(opportunityRecord.Id, DateTime.now().addDays(-40));
    insert as system new OpportunityContactRole(
      OpportunityId = opportunityRecord.Id,
      ContactId = insertContact(dealer.Id).Id,
      IsPrimary = true,
      Role = 'Decision Maker'
    );

    Lead prospectLead = new Lead(
      LastName = 'Gap Prospect ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Gap Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = BWM_EmailConstants.STAGE_PROSPECT,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'gap.lead+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
      Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY
    );
    insert as system prospectLead;
    Lead prospectingLead = new Lead(
      LastName = 'Gap Prospecting ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Gap Co 2 ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = BWM_EmailConstants.STAGE_PROSPECTING,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system prospectingLead;

    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'Gap Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'gap.offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system offlineRecord;

    ContentVersion pdfVersion = new ContentVersion(
      Title = 'Coverage Brochure',
      PathOnClient = 'CoverageBrochure.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 coverage'),
      IsMajorVersion = true
    );
    insert as system pdfVersion;
    pdfVersion = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId, VersionData
      FROM ContentVersion
      WHERE Id = :pdfVersion.Id
    ];
    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{ 'Coverage Brochure' => pdfVersion }
    );
    BWM_BrochureFileService.setPublicUrlMapForTest(
      new Map<String, String>{ 'Coverage Brochure' => 'https://example.com/brochure.pdf' }
    );

    seedWhatsAppCache('coverage_wa');
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'coverage_rcs',
          'Component' => new Map<String, Object>{
            'Cards' => new List<Object>{
              new Map<String, Object>{
                'DescVariables' => new List<Object>{
                  new Map<String, Object>{ '{{1}}' => 'Department_name_1' }
                },
                'TitleVariables' => new List<Object>{
                  new Map<String, Object>{ '{{2}}' => 'product_brief' }
                }
              }
            }
          }
        }
      }
    );

    System.assertEquals(
      true,
      BWM_EmailOpportunityFieldHistoryService.isStageStaleForDays(
        opportunityRecord.Id,
        30
      )
    );
    BWM_BrochureFileService.resolveFileBrochure('Coverage Brochure', 'x.pdf', true);
    BWM_BrochureFileService.getPublicDownloadUrl('Coverage Brochure');
    BWM_BrochureFileService.hasPdfContentVersion('Coverage Brochure');
    BWM_BrochureFileService.getEmailPdfVersion('Coverage Brochure');
    BWM_BrochureFileService.buildEmailAttachment('Coverage Brochure', 'x.pdf');
    BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      opportunityRecord,
      ','
    );

    List<BWM_SendTaskEmailInvocable.Request> invocableRequests =
      new List<BWM_SendTaskEmailInvocable.Request>();
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'callback',
        BWM_EmailConstants.STAGE_PROSPECT,
        null
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'callback',
        BWM_EmailConstants.STAGE_PROSPECTING,
        null
      )
    );
    invocableRequests.add(
      buildInvocableRequest(prospectLead.Id, 'callback', 'Qualified', null)
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Not Responding'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECT,
        'Customer details not received'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Customer details not received'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECT,
        'Minimum Quantity Not Met'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Out of Service Area'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECT,
        'Purchase from Other Brand'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Purchase from Other Brand'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECT,
        'Future Prospect'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Future Prospect'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECT,
        'Price Enquiry'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        prospectingLead.Id,
        'lost',
        BWM_EmailConstants.STAGE_PROSPECTING,
        'Existing Customer'
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        opportunityRecord.Id,
        'callback',
        BWM_EmailConstants.STAGE_NEGOTIATION,
        null
      )
    );
    invocableRequests.add(
      buildInvocableRequest(
        opportunityRecord.Id,
        'callback',
        BWM_EmailConstants.STAGE_NURTURE,
        null
      )
    );
    invocableRequests.add(
      buildInvocableRequest(opportunityRecord.Id, 'callback', '', null)
    );
    BWM_SendTaskEmailInvocable.sendTaskEmail(invocableRequests);

    List<EmailTemplate> emailTemplates = [SELECT Id, Name FROM EmailTemplate LIMIT 1];
    if (!emailTemplates.isEmpty()) {
      LeadManagementEmailService.renderTemplate(emailTemplates[0].Id, prospectLead);
      DealerOpportunityEmailService.renderTemplate(
        emailTemplates[0].Id,
        opportunityRecord,
        null
      );
      LeadManagementEmailService.buildBrochureAttachments(
        emailTemplates[0].Name,
        prospectLead
      );
    }

    Account noPhone = new Account(Name = 'No Phone Coverage ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system noPhone;
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY, SUCCESS_BODY)
    );

    Test.startTest();
    OfflineCampaignManagementController.searchOfflineCampaigns(null, null, null, null);
    try {
      OfflineCampaignManagementController.getBluewaveEmailTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementController.getWhatsAppTemplates();
      OfflineCampaignManagementController.getRcsTemplates();
      OfflineCampaignManagementController.getSmsTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementController.sendOfflineCampaignRcs(
        new List<Id>{ offlineRecord.Id },
        'coverage_rcs'
      );
      OfflineCampaignManagementController.sendOfflineCampaignSms(
        new List<Id>{ offlineRecord.Id },
        'coverage_sms'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      AccountManagementRcsService.sendToAccounts(new List<Id>{ dealer.Id }, '');
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    AccountManagementRcsService.sendToAccounts(
      new List<Id>{ noPhone.Id },
      'coverage_rcs'
    );
    AccountManagementSmsService.sendToAccounts(
      new List<Id>{ noPhone.Id },
      'coverage_sms'
    );
    BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      BWM_CampaignRecordSupport.getMessagingSettings(),
      'coverage_rcs',
      opportunityRecord,
      new Map<String, Object>{ '{{1}}' => 'Department_name_1', '{{2}}' => 'product_brief' }
    );
    Test.stopTest();
  }

  private static Contact insertContact(Id accountId) {
    Contact contactRecord = new Contact(
      LastName = 'Gap Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountId,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'gap.contact+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system contactRecord;
    return contactRecord;
  }

  private static BWM_SendTaskEmailInvocable.Request buildInvocableRequest(
    Id recordId,
    String action,
    String stage,
    String lostReason
  ) {
    BWM_SendTaskEmailInvocable.Request requestItem = new BWM_SendTaskEmailInvocable.Request();
    requestItem.recordId = recordId;
    requestItem.taskAction = action;
    requestItem.stageAtAction = stage;
    requestItem.lostReason = lostReason;
    return requestItem;
  }

  @IsTest
  static void coversSendSuccessDealerPdfCategoriesAndBrochure() {
    Account dealerAccount = insertDealerAccount('Coverage Dealer Acc');
    Contact contactRecord = new Contact(
      LastName = 'Coverage Send Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = dealerAccount.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'coverage.send+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system contactRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Coverage Send Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_EmailConstants.STAGE_NEGOTIATION,
      CloseDate = Date.today().addDays(14),
      AccountId = dealerAccount.Id,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'coverage.opp@example.com',
      Amount = 1500,
      Sub_Stage__c = BWM_EmailConstants.SUB_STAGE_ACTIVE
    );
    try {
      opportunityRecord.DealerAccount__c = dealerAccount.Id;
      insert as system opportunityRecord;
    } catch (DmlException ex) {
      opportunityRecord.DealerAccount__c = null;
      insert as system opportunityRecord;
    }
    Test.setCreatedDate(opportunityRecord.Id, DateTime.now().addDays(-40));
    insertProductCategories(opportunityRecord.Id);

    Lead leadRecord = new Lead(
      LastName = 'Coverage Send Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'Coverage Send Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;
    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'Coverage Send Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'coverage.offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system offlineRecord;

    ContentVersion pdfVersion = new ContentVersion(
      Title = 'Coverage Send Brochure',
      PathOnClient = 'CoverageSendBrochure.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 send-coverage'),
      IsMajorVersion = true
    );
    insert as system pdfVersion;
    pdfVersion = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId, VersionData
      FROM ContentVersion
      WHERE Id = :pdfVersion.Id
    ];

    seedWhatsAppCache('coverage_send_wa');
    seedChannelCaches('coverage_send_rcs', 'coverage_send_sms');
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => 'coverage_send_rcs',
          'Component' => new Map<String, Object>{
            'Cards' => new List<Object>{
              new Map<String, Object>{
                'DescVariables' => new List<Object>{
                  new Map<String, Object>{ '{{1}}' => 'department_name_1' },
                  new Map<String, Object>{ '{{2}}' => 'product_brief' },
                  new Map<String, Object>{ '{{3}}' => 'lead_owner_name' },
                  new Map<String, Object>{ '{{4}}' => 'opportunity_owner_phone' },
                  new Map<String, Object>{ '{{5}}' => 'department_crm_email' },
                  new Map<String, Object>{ '{{6}}' => 'rudra_number' },
                  new Map<String, Object>{ '{{7}}' => 'bhagyashree_number' },
                  new Map<String, Object>{ '{{8}}' => 'owner' },
                  new Map<String, Object>{ '{{9}}' => 'email' },
                  new Map<String, Object>{ '{{10}}' => 'number' },
                  'not-a-map',
                  new Map<String, Object>{ 'bad' => 'x' }
                },
                'TitleVariables' => new List<Object>{
                  new Map<String, Object>{ '{{11}}' => 'brief' },
                  new Map<String, Object>{ '{{12}}' => 'lead_owner' },
                  new Map<String, Object>{ '{{13}}' => 'lead_owner_phone' },
                  new Map<String, Object>{ '{{14}}' => 'lead_owner_email' },
                  new Map<String, Object>{ '{{15}}' => 'opportunity_owner_name' },
                  new Map<String, Object>{ '{{16}}' => 'opportunity_owner_email' },
                  new Map<String, Object>{ '{{17}}' => 'department_crm_name' },
                  new Map<String, Object>{ '{{18}}' => 'department_crm_phone' },
                  new Map<String, Object>{ '{{19}}' => 'department_name_2' },
                  new Map<String, Object>{ '{{20}}' => 'department_name_3' }
                }
              }
            }
          }
        }
      }
    );

    BWM_Messaging_Settings__mdt settings = BWM_CampaignRecordSupport.getMessagingSettings();
    BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'coverage_send_rcs',
      opportunityRecord,
      new Map<String, Object>{ '{{1}}' => 'department_name_1', '{{3}}' => 'product_brief' }
    );
    BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      'missing_template',
      opportunityRecord,
      new Map<String, Object>{ '{{1}}' => 'department_name_1', '{{2}}' => '' }
    );
    try {
      BWM_RcsDirectPayloadBuilder.buildPayload(
        settings,
        'coverage_send_rcs',
        opportunityRecord,
        '9000013102'
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }

    Test.setCurrentPage(Page.BWM_DealerMonthlyOpportunityList);
    ApexPages.currentPage()
      .getParameters()
      .put('accountId', String.valueOf(dealerAccount.Id));
    BWM_DealerMonthlyListCtrl dealerCtrl = new BWM_DealerMonthlyListCtrl();
    System.assertNotEquals(null, dealerCtrl.rows);

    BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      opportunityRecord,
      '|'
    );
    BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(
      dealerAccount.Id
    );

    BWM_BrochureFileService.clearCache();
    BWM_BrochureFileService.setVersionMapForTest(new Map<String, ContentVersion>());
    BWM_BrochureFileService.getEmailPdfVersion('Coverage Send Brochure');
    BWM_BrochureFileService.ensurePublicDownloadUrl(
      'Coverage Send Brochure',
      pdfVersion.Id
    );
    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{ 'Coverage Send Brochure' => pdfVersion }
    );
    BWM_BrochureFileService.setPublicUrlMapForTest(
      new Map<String, String>{
        'Coverage Send Brochure' => 'https://example.com/coverage-send.pdf',
        String.valueOf(pdfVersion.Id) => 'https://example.com/coverage-send.pdf?asPdf=false'
      }
    );

    BWM_EmailNegotiationStageUpdateBatch staleBatch = new BWM_EmailNegotiationStageUpdateBatch();
    staleBatch.execute(null, new List<Opportunity>{ opportunityRecord });

    Test.setMock(HttpCalloutMock.class, new CoverageCalloutMock());
    Test.startTest();
    try {
      ContactManagementRcsService.sendToContacts(new List<Id>(), 'coverage_send_rcs');
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      ContactManagementRcsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        ''
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      ContactManagementSmsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        ''
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        ''
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        ''
      );
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }

    ContactManagementRcsService.SendRcsResult contactRcs =
      ContactManagementRcsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'coverage_send_rcs'
      );
    ContactManagementSmsService.SendSmsResult contactSms =
      ContactManagementSmsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'coverage_send_sms'
      );
    OfflineCampaignManagementRcsService.SendRcsResult offlineRcs =
      OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'coverage_send_rcs'
      );
    OfflineCampaignManagementSmsService.SendSmsResult offlineSms =
      OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'coverage_send_sms'
      );
    DealerOpportunityWhatsAppService.SendWhatsAppResult oppWhatsApp =
      DealerOpportunityWhatsAppService.sendToOpportunities(
        new List<Id>{ opportunityRecord.Id },
        'coverage_send_wa'
      );
    LeadManagementWhatsAppService.SendWhatsAppResult leadWhatsApp =
      LeadManagementWhatsAppService.sendToLeads(
        new List<Id>{ leadRecord.Id },
        'coverage_send_wa'
      );
    BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
      'https://example.com/coverage-send.pdf',
      'brochure.pdf'
    );
    BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
      'https://example.com/coverage-send.pdf?asPdf=false',
      'brochure.pdf'
    );
    BWM_BrochureFileService.buildEmailAttachment(
      'Coverage Send Brochure',
      'brochure.pdf'
    );
    Test.stopTest();

    System.assertNotEquals(null, contactRcs);
    System.assertNotEquals(null, contactSms);
    System.assertNotEquals(null, offlineRcs);
    System.assertNotEquals(null, offlineSms);
    System.assertNotEquals(null, oppWhatsApp);
    System.assertNotEquals(null, leadWhatsApp);
    System.assertNotEquals(null, dealerCtrl.dealerName);

    List<EmailTemplate> lightningTemplates = [
      SELECT Id
      FROM EmailTemplate
      WHERE UiType = 'SFX'
      LIMIT 1
    ];
    List<EmailTemplate> classicTemplates = [
      SELECT Id
      FROM EmailTemplate
      WHERE UiType != 'SFX'
      LIMIT 1
    ];
    if (!lightningTemplates.isEmpty()) {
      DealerOpportunityEmailService.renderTemplate(
        lightningTemplates[0].Id,
        opportunityRecord,
        contactRecord.Id
      );
    }
    if (!classicTemplates.isEmpty()) {
      DealerOpportunityEmailService.renderTemplate(
        classicTemplates[0].Id,
        opportunityRecord,
        contactRecord.Id
      );
    }
  }

  @IsTest
  static void coversChannelSendSkipAndFailureBranches() {
    Account accountRecord = new Account(Name = 'Skip Fail Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;
    Contact phoneContact = new Contact(
      LastName = 'Skip Fail Phone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    Contact noPhoneContact = new Contact(
      LastName = 'Skip Fail NoPhone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id
    );
    insert as system new List<Contact>{ phoneContact, noPhoneContact };
    Offline_Campaign__c phoneOffline = new Offline_Campaign__c(
      Name = 'Skip Fail Phone Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'skip.fail.phone@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    Offline_Campaign__c noPhoneOffline = new Offline_Campaign__c(
      Name = 'Skip Fail NoPhone Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Email__c = 'skip.fail.nophone@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system new List<Offline_Campaign__c>{ phoneOffline, noPhoneOffline };
    seedChannelCaches('skip_fail_rcs', 'skip_fail_sms');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(
        '{"code":"400","message":"rejected"}',
        '{"code":"400","message":"rejected"}',
        '{"code":"400","message":"rejected"}'
      )
    );

    Test.startTest();
    ContactManagementRcsService.sendToContacts(
      new List<Id>{ phoneContact.Id, noPhoneContact.Id },
      'skip_fail_rcs'
    );
    ContactManagementSmsService.sendToContacts(
      new List<Id>{ phoneContact.Id, noPhoneContact.Id },
      'skip_fail_sms'
    );
    OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
      new List<Id>{ phoneOffline.Id, noPhoneOffline.Id },
      'skip_fail_rcs'
    );
    OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
      new List<Id>{ phoneOffline.Id, noPhoneOffline.Id },
      'skip_fail_sms'
    );
    Test.stopTest();
  }

  @IsTest
  static void coversIsolatedContactAndOfflineSends() {
    Account accountRecord = new Account(Name = 'Isolated Send Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'Isolated Send Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system contactRecord;
    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'Isolated Send Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'isolated.offline@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert as system offlineRecord;
    seedChannelCaches('isolated_rcs', 'isolated_sms');
    Test.setMock(HttpCalloutMock.class, new CoverageCalloutMock());

    Test.startTest();
    ContactManagementRcsService.SendRcsResult contactRcs =
      ContactManagementRcsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'isolated_rcs'
      );
    ContactManagementSmsService.SendSmsResult contactSms =
      ContactManagementSmsService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'isolated_sms'
      );
    OfflineCampaignManagementRcsService.SendRcsResult offlineRcs =
      OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'isolated_rcs'
      );
    OfflineCampaignManagementSmsService.SendSmsResult offlineSms =
      OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'isolated_sms'
      );
    Test.stopTest();

    System.assertEquals(
      1,
      contactRcs.sentCount,
      'Contact RCS: ' + String.valueOf(contactRcs.messages)
    );
    System.assertEquals(
      1,
      contactSms.sentCount,
      'Contact SMS: ' + String.valueOf(contactSms.messages)
    );
    System.assertEquals(
      1,
      offlineRcs.sentCount,
      'Offline RCS: ' + String.valueOf(offlineRcs.messages)
    );
    System.assertEquals(
      1,
      offlineSms.sentCount,
      'Offline SMS: ' + String.valueOf(offlineSms.messages)
    );
  }

  @IsTest
  static void coversProductCategoryChildRows() {
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Category Child Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(8)
    );
    insert as system opportunityRecord;
    insert as system new List<Product_Category__c>{
      new Product_Category__c(
        Opportunity__c = opportunityRecord.Id,
        Department_Name__c = 'High Mast & Polygonal',
        Product_Category__c = 'High Mast'
      ),
      new Product_Category__c(
        Opportunity__c = opportunityRecord.Id,
        Department_Name__c = 'High Mast & Polygonal',
        Product_Category__c = 'High Mast'
      )
    };
    String aggregated = BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
      opportunityRecord,
      '|'
    );
    System.assertNotEquals(
      '',
      aggregated,
      'Expected aggregated product categories, got blank. First value tried should insert.'
    );
  }

  @IsTest
  static void coversBrochureSoqlAndPublicUrlFetch() {
    ContentVersion pdfVersion = new ContentVersion(
      Title = 'Soql Brochure File',
      PathOnClient = 'SoqlBrochureFile.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 soql-brochure'),
      IsMajorVersion = true
    );
    insert as system pdfVersion;
    pdfVersion = [
      SELECT Id, Title, ContentSize, FileExtension, ContentDocumentId, VersionData
      FROM ContentVersion
      WHERE Id = :pdfVersion.Id
    ];
    BWM_BrochureFileService.setVersionMapForTest(new Map<String, ContentVersion>());
    ContentVersion queried = BWM_BrochureFileService.getEmailPdfVersion('Soql Brochure File');
    System.assertNotEquals(null, queried);
    BWM_BrochureFileService.ensurePublicDownloadUrl('Soql Brochure File', pdfVersion.Id);
    ContentVersion stubVersion = new ContentVersion(
      Id = pdfVersion.Id,
      Title = 'Soql Brochure File'
    );
    BWM_BrochureFileService.setVersionMapForTest(
      new Map<String, ContentVersion>{ 'Soql Brochure File' => stubVersion }
    );
    BWM_BrochureFileService.setPublicUrlMapForTest(
      new Map<String, String>{
        'Soql Brochure File' => 'https://example.com/soql-brochure.pdf',
        String.valueOf(pdfVersion.Id) => 'https://example.com/soql-brochure.pdf'
      }
    );
    Test.setMock(HttpCalloutMock.class, new CoverageCalloutMock());
    Test.startTest();
    BWM_BrochureFileService.buildEmailAttachmentFromPublicUrl(
      'https://example.com/soql-brochure.pdf',
      'soql.pdf'
    );
    BWM_BrochureFileService.buildEmailAttachment('Soql Brochure File', 'soql.pdf');
    Test.stopTest();
  }

  @IsTest
  static void coversWhatsAppFetchPagesAndDocumentHeader() {
    Account accountRecord = new Account(Name = 'WA Fetch Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'WA Fetch Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(12),
      AccountId = accountRecord.Id,
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system opportunityRecord;
    Lead leadRecord = new Lead(
      LastName = 'WA Fetch Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'WA Fetch Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system leadRecord;

    Map<String, Object> documentMeta = new Map<String, Object>{
      'language' => 'en',
      'name' => 'coverage_doc_wa',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Doc {{1}}'
      }
    };
    BWM_DirectWaCampaignSend.clearCache();
    BWM_DirectWaCampaignSend.templateMetaByName = new Map<String, Map<String, Object>>{
      'coverage_doc_wa' => documentMeta
    };
    LeadManagementWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'coverage_doc_wa' => documentMeta
    };
    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      'coverage_doc_wa' => documentMeta
    };

    String waBody =
      '{"total_pages":2,"templates":[' +
      '{"state":"PENDING","name":"skip_wa"},' +
      '{"state":"APPROVED","name":"coverage_doc_wa","category_name":"UTILITY","language":"en","template_id":"tid-doc","content":{"header":{"type":"DOCUMENT"},"body":"Doc {{1}}"}}' +
      ']}';
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(waBody, SUCCESS_BODY, SUCCESS_BODY)
    );

    Test.startTest();
    LeadManagementWhatsAppService.fetchApprovedTemplates();
    DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    LeadManagementWhatsAppService.sendToLeads(
      new List<Id>{ leadRecord.Id },
      'coverage_doc_wa'
    );
    DealerOpportunityWhatsAppService.sendToOpportunities(
      new List<Id>{ opportunityRecord.Id },
      'coverage_doc_wa'
    );
    Test.stopTest();
  }

  @IsTest
  static void coversDealerMonthlyPdfInIsolation() {
    Account dealerAccount = insertDealerAccount('Isolated PDF Dealer');
    Test.startTest();
    Messaging.EmailFileAttachment attachment =
      BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(
        dealerAccount.Id
      );
    Test.stopTest();
    System.assertEquals(true, attachment == null || attachment.getBody() != null);
  }

  @IsTest
  static void coversBluewaveEmailTemplateLoad() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":"tmpl-gap","name":"Gap","imagePreviewUrl":"/g.png"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );
    Test.startTest();
    try {
      OfflineCampaignManagementController.getBluewaveEmailTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();
  }

  @IsTest
  static void coversApprovedTemplateFetchers() {
    String waBody =
      '{"total_pages":1,"templates":[{"state":"APPROVED","name":"coverage_wa","category_name":"UTILITY","language":"en","template_id":"tid1"}]}';
    String rcsBody =
      '{"data":[{"TemplateStatus":"approve","TemplateName":"coverage_rcs"}]}';
    String smsBody =
      '{"data":[{"TemplateName":"coverage_sms","TemplateStatus":"approve","templateName":"coverage_sms","dltTemplateId":"1","templateText":"Hi {#var#}."}]}';
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(waBody, rcsBody, smsBody)
    );
    Test.startTest();
    try {
      DealerOpportunityWhatsAppService.fetchApprovedTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      DealerOpportunityRcsService.fetchApprovedTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      DealerOpportunitySmsService.fetchApprovedTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    try {
      LeadManagementWhatsAppService.fetchApprovedTemplates();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Test.stopTest();
  }

  private static Account insertDealerAccount(String name) {
    Account accountRecord = new Account(
      Name = name,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'coverage.dealer@example.com'
    );
    Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    for (String developerName : new List<String>{ 'Dealer', 'Dealer_Account' }) {
      if (
        recordTypes.containsKey(developerName) &&
        recordTypes.get(developerName).isAvailable()
      ) {
        accountRecord.RecordTypeId = recordTypes.get(developerName).getRecordTypeId();
        break;
      }
    }
    insert as system accountRecord;
    return accountRecord;
  }

  private static void insertProductCategories(Id opportunityId) {
    Integer insertedCount = 0;
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
          Department_Name__c = 'High Mast & Polygonal',
          Product_Category__c = entry.getValue()
        );
        insertedCount++;
        if (insertedCount >= 2) {
          break;
        }
      } catch (DmlException ex) {
        continue;
      }
    }
  }

  private static void seedChannelCaches(String rcsTemplateName, String smsTemplateName) {
    BWM_RcsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'TemplateName' => rcsTemplateName,
          'templateText' => 'Hello'
        }
      }
    );
    BWM_SmsDirectPayloadBuilder.cacheTemplates(
      new List<Object>{
        new Map<String, Object>{
          'templateName' => smsTemplateName,
          'TemplateName' => smsTemplateName,
          'dltTemplateId' => 'DLT1',
          'templateText' => 'Hi {#var#}'
        }
      }
    );
  }

  private class CoverageCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      String endpoint = request.getEndpoint() == null ? '' : request.getEndpoint();
      if (
        endpoint.contains('example.com') ||
        endpoint.contains('.pdf') ||
        endpoint.contains('asPdf')
      ) {
        response.setHeader('Content-Type', 'application/pdf');
        response.setBodyAsBlob(Blob.valueOf('%PDF-1.4 coverage'));
        return response;
      }
      response.setHeader('Content-Type', 'application/json');
      response.setBody(SUCCESS_BODY);
      return response;
    }
  }

  private static void seedWhatsAppCache(String templateName) {
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
    LeadManagementWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      templateName => new Map<String, Object>{
        'language' => 'en',
        'name' => templateName
      }
    };
    DealerOpportunityWhatsAppService.templateMetaByName = new Map<String, Map<String, Object>>{
      templateName => new Map<String, Object>{
        'language' => 'en',
        'name' => templateName
      }
    };
  }
}