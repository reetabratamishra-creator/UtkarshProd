/**
 * @description   AuraEnabled API for Infobip/email campaign delivery report LWC.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class CampaignEmailReportController {
  /**
   * @description Returns campaign email subject options for the report filter dropdown.
   * @return Subject options from Infobip templates and sent Email Logs.
   */
  @AuraEnabled
  public static List<CampaignEmailReportService.SubjectOption> getCampaignEmailSubjectOptions() {
    return CampaignEmailReportService.getCampaignEmailSubjectOptions();
  }

  /**
   * @description Returns campaign email subject options from Email Logs without callouts.
   * @return Subject options for the LWC filter dropdown.
   */
  @AuraEnabled(cacheable=true)
  public static List<CampaignEmailReportService.SubjectOption> getCampaignEmailSubjectOptionsFromLogs() {
    return CampaignEmailReportService.getCampaignEmailSubjectOptionsFromLogs();
  }

  /**
   * @description Fetches and persists Infobip/email campaign delivery report data for the LWC.
   * @param campaignEmailSubject Selected campaign email subject used to filter results.
   * @return FetchResult with report rows and status from CampaignEmailReportService.
   */
  @AuraEnabled
  public static CampaignEmailReportService.FetchResult fetchEmailCampaignReport(
    String campaignEmailSubject
  ) {
    return CampaignEmailReportService.fetchAndSave(campaignEmailSubject);
  }
}