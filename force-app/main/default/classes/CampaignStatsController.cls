public with sharing class CampaignStatsController {
  @AuraEnabled(cacheable=true)
  public static List<CampaignStatsService.CampaignOption> getCampaignOptions(
    List<Id> campaignIds
  ) {
    return CampaignStatsService.getCampaignOptions(campaignIds);
  }

  @AuraEnabled
  public static CampaignStatsService.FetchResult fetchCampaignStats(
    Id campaignId,
    String campaignName,
    String productName
  ) {
    return CampaignStatsService.fetchAndSave(
      campaignId,
      campaignName,
      productName
    );
  }
}