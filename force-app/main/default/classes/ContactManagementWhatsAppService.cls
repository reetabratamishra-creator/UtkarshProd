/**
 * @description   Contact campaign WhatsApp send logic for campaign management UI.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class ContactManagementWhatsAppService {
  /**
   * @description Sends a WhatsApp template to Contacts by delegating to BWM_CampaignWhatsAppSendService.
   * @param contactIds Contact Ids to message.
   * @param templateName Approved WhatsApp template name.
   * @return SendWhatsAppResult with send outcome details.
   */
  public static LeadManagementWhatsAppService.SendWhatsAppResult sendToContacts(
    List<Id> contactIds,
    String templateName
  ) {
    return BWM_DirectWaCampaignSend.sendToRecords(
      BWM_CampaignRecordSupport.queryContactsByIds(contactIds),
      templateName,
      BWM_MessagingConstants.TRIGGER_CONTACT_CAMPAIGN
    );
  }
}