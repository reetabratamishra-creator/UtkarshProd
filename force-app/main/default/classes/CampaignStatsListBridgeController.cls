public with sharing class CampaignStatsListBridgeController {
  private final ApexPages.StandardSetController setController;
  public String redirectUrl { get; private set; }
  public String errorMessage { get; private set; }

  public CampaignStatsListBridgeController(
    ApexPages.StandardSetController setController
  ) {
    this.setController = setController;
  }

  public PageReference redirectToLwc() {
    List<Campaign> selected = (List<Campaign>) setController.getSelected();
    if (selected == null || selected.isEmpty()) {
      errorMessage = 'Select at least one Campaign, then click Campaign Report.';
      return null;
    }

    List<String> ids = new List<String>();
    for (Campaign campaignRecord : selected) {
      if (campaignRecord.Id != null) {
        ids.add(String.valueOf(campaignRecord.Id));
      }
    }

    if (ids.isEmpty()) {
      errorMessage = 'No valid Campaign Ids were selected.';
      return null;
    }

    PageReference target = new PageReference(
      '/lightning/cmp/c__campaignStatsReport'
    );
    target.getParameters().put('c__recordIds', String.join(ids, ','));
    target.setRedirect(true);
    redirectUrl = target.getUrl();
    return target;
  }
}