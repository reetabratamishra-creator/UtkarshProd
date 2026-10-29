/**
 * @description   Test class for AccountManagementWhatsAppService thin WhatsApp
 *                send wrapper.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class AccountManagementWhatsAppServiceTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  /**
   * Scenario: Account with phone sends WhatsApp campaign template via mock callout.
   */
  @IsTest
  static void testSendToAccounts_HappyPathWithMock() {
    seedTemplateCache('u_dealer_enq_dept');
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Account accountRecord = new Account(
      Name = 'WA Account',
      Phone = '9876543240'
    );
    insert accountRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      AccountManagementWhatsAppService.sendToAccounts(
        new List<Id>{ accountRecord.Id },
        'u_dealer_enq_dept'
      );
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
    System.assertEquals(0, result.skippedCount);
  }

  /**
   * Scenario: Account without phone is skipped.
   */
  @IsTest
  static void testSendToAccounts_NoPhone_Skipped() {
    seedTemplateCache('u_dealer_enq_dept');

    Account accountRecord = new Account(Name = 'WA Account No Phone');
    insert accountRecord;

    Test.startTest();
    LeadManagementWhatsAppService.SendWhatsAppResult result =
      AccountManagementWhatsAppService.sendToAccounts(
        new List<Id>{ accountRecord.Id },
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