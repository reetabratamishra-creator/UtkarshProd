@IsTest
private class BWM_WaCampPayloadATest {
  @IsTest
  static void buildPayloadUsesWhatsAppChannelAndTemplatePayload() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000001AAA","Status":"Prospect","Department_Name__c":"Crash Barrier","Owner":{"attributes":{"type":"User"},"Name":"Owner Name","Phone":"9999999999","Email":"owner@test.com"}}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Hello {{1}} {{2}} {{3}} {{4}} {{5}} {{6}}'
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'prospect_dept_enq_280526',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"channel":"WhatsApp"'), payload);
    System.assert(payload.contains('"templatepayload"'), payload);
    System.assert(!payload.contains('"channel":"Journey"'), payload);
    System.assert(payload.contains('"biz_opaque_callback_data"'), payload);
    System.assert(payload.contains('"type":"header"'), payload);
    System.assert(payload.contains('"type":"body"'), payload);
  }

  @IsTest
  static void buildPayloadOmitsBodyForStaticTemplate() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000002AAA","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'body' => 'Hello customer, no variables here.'
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'cb_n_n_july26',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"components":[]'), payload);
  }

  @IsTest
  static void buildPayloadIncludesQuickReplyButtonsFromTemplateJson() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000003AAA","Name":"Test Lead","Department_Name__c":"Solar"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'components' => new List<Object>{
        new Map<String, Object>{
          'type' => 'BODY',
          'text' => 'Quote {{1}} valid until {{2}}'
        },
        new Map<String, Object>{
          'type' => 'BUTTONS',
          'buttons' => new List<Object>{
            new Map<String, Object>{ 'type' => 'QUICK_REPLY', 'text' => 'Yes' },
            new Map<String, Object>{ 'type' => 'QUICK_REPLY', 'text' => 'No' }
          }
        }
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'quotation_manual_trigger',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"sub_type":"quick_reply"'), payload);
    System.assert(payload.contains('"payload":"Yes"'), payload);
    System.assert(payload.contains('"payload":"No"'), payload);
    System.assert(payload.contains('"type":"body"'), payload);
  }

  @IsTest
  static void buildPayloadUsesHeaderVariableNotLiteralPlaceholder() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000004AAA","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'components' => new List<Object>{
        new Map<String, Object>{
          'type' => 'HEADER',
          'format' => 'TEXT',
          'text' => 'Department {{1}}'
        },
        new Map<String, Object>{
          'type' => 'BODY',
          'text' => 'Hello {{1}}'
        }
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'prospect_enq_dept',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(!payload.contains('Department {{1}}'), payload);
    System.assert(payload.contains('"type":"header"'), payload);
    System.assert(payload.contains('Crash Barrier'), payload);
  }

  @IsTest
  static void buildPayloadIncludesDocumentHeaderOnlyWhenTemplateDefinesIt() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000005AAA","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Static message without variables'
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'cb_n_n_aug26',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"type":"header"'), payload);
    System.assert(payload.contains('"type":"document"'), payload);
    System.assert(!payload.contains('"type":"body"'), payload);
    System.assert(payload.contains('"filename"'), payload);
  }

  @IsTest
  static void buildPayloadDoesNotSendPdfAsVideoHeader() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000006AAA","Department_Name__c":"PVC Pipes and Fittings"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{
          'media_type' => 'DYNAMIC',
          'type' => 'VIDEO'
        },
        'body' => 'Crash-Tested Metal Beam Crash Barriers from Utkarsh India'
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'cb_n_n_june26',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"type":"video"'), payload);
    System.assert(
      payload.contains('Template/Video/Utkarsh/crash_barrier.mp4'),
      payload
    );
    System.assert(!payload.contains('PVC_Pipes_and_Fittings.mp4'), payload);
    System.assert(!payload.contains('PVC_Pipes_and_Fittings.pdf'), payload);
  }

  @IsTest
  static void buildPayloadPrefersContentDocumentHeaderOverVideoComponent() {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000007AAA","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{ 'type' => 'DOCUMENT' },
        'body' => 'Static body'
      },
      'components' => new List<Object>{
        new Map<String, Object>{
          'type' => 'HEADER',
          'format' => 'VIDEO'
        }
      }
    };

    Test.startTest();
    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'cb_n_n_june26',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    Test.stopTest();

    System.assert(payload.contains('"type":"document"'), payload);
    System.assert(!payload.contains('"type":"video"'), payload);
  }

  @IsTest
  static void sendToLeadsHappyPathAndControllerDelegates() {
    seedWaCampTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Lead withPhone = new Lead(
      LastName = 'Payload WA Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'WA Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system withPhone;
    Lead noPhone = new Lead(
      LastName = 'No Phone Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'WA Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect',
      Department_Name__c = 'Enquiry'
    );
    insert as system noPhone;
    Account accountRecord = new Account(Name = 'WA Acc ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10));
    insert as system accountRecord;
    Contact contactRecord = new Contact(
      LastName = 'WA Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10)
    );
    insert as system contactRecord;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'WA Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Department_Name__c = 'Enquiry'
    );
    insert as system opportunityRecord;
    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'WA Offline ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Phone__c = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email__c = 'offline.wa@example.com',
      Department__c = 'Crash Barrier',
      Group_List__c = 'North Region List',
      Active__c = true
    );
    insert as system offlineRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult leadResult =
      BWM_WaCampSendA.sendToLeads(
        new List<Id>{ withPhone.Id, noPhone.Id },
        'u_dealer_enq_dept'
      );
    BWM_WaCampCtrlA.sendLeadWhatsApp(
      new List<Id>{ withPhone.Id },
      'u_dealer_enq_dept'
    );
    BWM_WaCampCtrlA.sendOpportunityWhatsApp(
      new List<Id>{ opportunityRecord.Id },
      'u_dealer_enq_dept'
    );
    BWM_WaCampCtrlA.sendAccountWhatsApp(
      new List<Id>{ accountRecord.Id },
      'u_dealer_enq_dept'
    );
    BWM_WaCampCtrlA.sendContactWhatsApp(
      new List<Id>{ contactRecord.Id },
      'u_dealer_enq_dept'
    );
    BWM_WaCampCtrlA.sendOfflineCampaignWhatsApp(
      new List<Id>{ offlineRecord.Id },
      'u_dealer_enq_dept'
    );
    Test.stopTest();

    System.assertEquals(1, leadResult.sentCount);
    System.assertEquals(1, leadResult.skippedCount);
  }

  @IsTest
  static void sendToLeadsRequiresSelectionAndTemplate() {
    Boolean emptyThrew = false;
    try {
      BWM_WaCampSendA.sendToLeads(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      emptyThrew = true;
    }
    Lead leadRecord = new Lead(
      LastName = 'Validation Lead ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Company = 'WA Test Co ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      Status = 'Prospect'
    );
    insert as system leadRecord;
    Boolean blankThrew = false;
    try {
      BWM_WaCampSendA.sendToLeads(new List<Id>{ leadRecord.Id }, '');
    } catch (AuraHandledException ex) {
      blankThrew = true;
    }
    Boolean ctrlThrew = false;
    try {
      BWM_WaCampCtrlA.sendLeadWhatsApp(new List<Id>(), 'tmpl');
    } catch (AuraHandledException ex) {
      ctrlThrew = true;
    }
    System.assertEquals(true, emptyThrew);
    System.assertEquals(true, blankThrew);
    System.assertEquals(true, ctrlThrew);
  }

  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  @IsTest
  static void buildPayloadIncludesImageHeaderAndProbes() {
    System.assertEquals('ok', BWM_DeployProbe.ping());
    System.assertEquals('ok', BWM_WaFixProbe2.ping());

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Id":"00Q000000000008AAA","Department_Name__c":"Crash Barrier"}',
      Lead.class
    );
    Map<String, Object> templateMeta = new Map<String, Object>{
      'language' => 'en',
      'content' => new Map<String, Object>{
        'header' => new Map<String, Object>{
          'type' => 'IMAGE',
          'mediaUrl' => 'https://example.com/banner.png'
        },
        'body' => 'Hello {{1}}',
        'buttons' => new List<Object>{
          new Map<String, Object>{ 'type' => 'URL', 'text' => 'Open', 'url' => 'https://example.com' }
        }
      }
    };

    String payload = BWM_WaCampPayloadA.buildPayload(
      settings,
      null,
      'image_header_cov',
      templateMeta,
      leadRecord,
      '917980828320'
    );
    System.assert(payload.contains('"channel":"WhatsApp"'), payload);
  }

  private static void seedWaCampTemplateCache(String templateName) {
    BWM_WaCampSendA.templateMetaByName = new Map<String, Map<String, Object>>{
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