public without sharing class BWM_EmailLeadTriggerHandler {
  @TestVisible
  private static Boolean skipEnqueueForTests = false;

  @TestVisible
  private static Boolean throwForTriggerTest = false;

  private static Set<Id> processedLeadIds = new Set<Id>();

  public static void handleAfterInsert(List<Lead> newLeads) {
    if (Test.isRunningTest() && throwForTriggerTest) {
      throw new BWM_EmailException('Forced trigger test exception.');
    }
    if (Test.isRunningTest() && skipEnqueueForTests) {
      return;
    }
    if (newLeads == null || newLeads.isEmpty()) {
      return;
    }

    List<Id> exotelLeadIds = new List<Id>();
    for (Lead leadRecord : newLeads) {
      if (!isExotelLeadEligible(leadRecord)) {
        continue;
      }
      if (processedLeadIds.contains(leadRecord.Id)) {
        continue;
      }
      processedLeadIds.add(leadRecord.Id);
      exotelLeadIds.add(leadRecord.Id);
    }

    if (!exotelLeadIds.isEmpty()) {
      BWM_EmailEnqueueService.enqueueLeadCreate(exotelLeadIds);
    }
  }

  @TestVisible
  private static Boolean isExotelLeadEligible(Lead leadRecord) {
    if (leadRecord == null || leadRecord.Id == null) {
      return false;
    }
    if (String.isBlank(leadRecord.Email)) {
      return false;
    }
    if (leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECT) {
      return false;
    }
    return String.isNotBlank(leadRecord.LeadSource) &&
      leadRecord.LeadSource.trim()
        .equalsIgnoreCase(BWM_EmailConstants.LEAD_SOURCE_EXOTEL);
  }
}