/**
 * @description   Account campaign WhatsApp send wrapper delegating to
 *                BWM_CampaignWhatsAppSendService.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class AccountManagementWhatsAppService {
  /**
   * @description Sends a WhatsApp template to Accounts by delegating to BWM_CampaignWhatsAppSendService.
   * @param accountIds Account Ids to message.
   * @param templateName Approved WhatsApp template name.
   * @return SendWhatsAppResult with send outcome details.
   */
  public static LeadManagementWhatsAppService.SendWhatsAppResult sendToAccounts(
    List<Id> accountIds,
    String templateName
  ) {
    return BWM_DirectWaCampaignSend.sendToRecords(
      BWM_CampaignRecordSupport.queryAccountsByIds(accountIds),
      templateName,
      BWM_MessagingConstants.TRIGGER_ACCOUNT_CAMPAIGN
    );
  }
}