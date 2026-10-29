/**
 * @description AuraEnabled entry point for creating Campaign and Custom Campaign Member records.
 */
public with sharing class BWM_CustomCampaignMemberCtrl {
    /**
     * @description Creates a Campaign and Custom Campaign Member rows for selected recipients.
     * @param campaignName User-entered campaign name.
     * @param memberType LEAD, OPPORTUNITY, CONTACT, ACCOUNT, or OFFLINE_CAMPAIGN.
     * @param recordIds Selected recipient record ids.
     * @return CreateCampaignResult with campaign id and member count.
     */
    @AuraEnabled
    public static BWM_CustomCampaignMemberService.CreateCampaignResult createCampaignWithMembers(
        String campaignName,
        String memberType,
        List<Id> recordIds
    ) {
        try {
            return BWM_CustomCampaignMemberService.createCampaignWithMembers(
                campaignName,
                memberType,
                recordIds
            );
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}