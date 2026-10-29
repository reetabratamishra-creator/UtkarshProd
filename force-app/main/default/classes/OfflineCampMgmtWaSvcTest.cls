/**
 * @description   Test class for OfflineCampaignManagementWhatsAppService WhatsApp
 *                send wrapper.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class OfflineCampMgmtWaSvcTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  @IsTest
  static void testSendToOfflineCampaigns_HappyPathWithMock() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'Offline WA',
      Phone__c = '9876543260',
      Email__c = 'offline.wa@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert offlineRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      OfflineCampaignManagementWhatsAppService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void testSendToOfflineCampaigns_NoPhone_Skipped() {
    seedTemplateCache('u_dealer_enq_dept');

    Offline_Campaign__c offlineRecord = new Offline_Campaign__c(
      Name = 'Offline WA No Phone',
      Email__c = 'offline.nophone@example.com',
      Department__c = 'Crash Barrier',
      Active__c = true
    );
    insert offlineRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      OfflineCampaignManagementWhatsAppService.sendToOfflineCampaigns(
        new List<Id>{ offlineRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void testSendToOfflineCampaigns_EmptyIds_ThrowsError() {
    Boolean threw = false;

    Test.startTest();
    try {
      OfflineCampaignManagementWhatsAppService.sendToOfflineCampaigns(
        new List<Id>(),
        'u_dealer_enq_dept'
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw);
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