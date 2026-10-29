/**
 * @description   List-view bridge controller that opens the email campaign report
 *                (Infobip last-48-hours report; not campaign-scoped).
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class CampaignEmailReportListBridgeController {
  private final ApexPages.StandardSetController setController;
  public String redirectUrl { get; private set; }
  public String errorMessage { get; private set; }

  public CampaignEmailReportListBridgeController(
    ApexPages.StandardSetController setController
  ) {
    this.setController = setController;
  }

  public PageReference redirectToLwc() {
    PageReference target = new PageReference(
      '/lightning/cmp/c__campaignEmailReport?c__ts=' +
      String.valueOf(Datetime.now().getTime())
    );
    target.setRedirect(true);
    redirectUrl = target.getUrl();
    return target;
  }
}