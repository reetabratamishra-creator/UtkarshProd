/**
 * @description   Offline Campaign WhatsApp template fetch and direct send logic.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OfflineCampaignManagementWhatsAppService {
  /**
   * @description Sends a WhatsApp template to Offline Campaigns by delegating to BWM_CampaignWhatsAppSendService.
   * @param offlineCampaignIds Offline_Campaign__c Ids to message.
   * @param templateName Approved WhatsApp template name.
   * @return SendWhatsAppResult with send outcome details.
   */
  public static LeadManagementWhatsAppService.SendWhatsAppResult sendToOfflineCampaigns(
    List<Id> offlineCampaignIds,
    String templateName
  ) {
    return BWM_DirectWaCampaignSend.sendToRecords(
      BWM_CampaignRecordSupport.queryOfflineCampaignsByIds(offlineCampaignIds),
      templateName,
      BWM_MessagingConstants.TRIGGER_OFFLINE_CAMPAIGN
    );
  }
}