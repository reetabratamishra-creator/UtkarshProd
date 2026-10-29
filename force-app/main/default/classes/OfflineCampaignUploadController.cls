/**
 * @description   AuraEnabled controller for offline campaign upload — department
 *                picklist and row insert entry points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OfflineCampaignUploadController {
  /**
   * @description Returns department picklist options for the offline campaign upload UI.
   * @return List of PicklistOption values for department selection.
   */
  @AuraEnabled(cacheable=true)
  public static List<OfflineCampaignUploadService.PicklistOption> getDepartmentOptions() {
    return OfflineCampaignUploadService.getDepartmentOptions();
  }

  /**
   * @description Parses uploaded offline campaign JSON rows and inserts them via the upload service.
   * @param rowsJson JSON string of upload row payloads from the LWC.
   * @return InsertSummary with success/failure counts from the insert operation.
   */
  @AuraEnabled
  public static OfflineCampaignUploadService.InsertSummary insertOfflineCampaignRows(
    String rowsJson,
    String groupList
  ) {
    return OfflineCampaignUploadService.insertRows(
      OfflineCampaignUploadService.parseUploadRows(rowsJson),
      groupList
    );
  }
}