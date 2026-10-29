/**
 * @description   Test class for ContactManagementWhatsAppService thin WhatsApp
 *                send wrapper.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class ContactManagementWhatsAppServiceTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  @IsTest
  static void testSendToContacts_HappyPathWithMock() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Contact contactRecord = new Contact(
      LastName = 'WA Contact',
      Phone = '9876543250',
      MobilePhone = '9876543250',
      Email = 'wa.contact@example.com'
    );
    insert contactRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      ContactManagementWhatsAppService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void testSendToContacts_NoPhone_Skipped() {
    seedTemplateCache('u_dealer_enq_dept');

    Contact contactRecord = new Contact(LastName = 'WA Contact No Phone');
    insert contactRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      ContactManagementWhatsAppService.sendToContacts(
        new List<Id>{ contactRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
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