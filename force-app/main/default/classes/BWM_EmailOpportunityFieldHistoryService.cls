public without sharing class BWM_EmailOpportunityFieldHistoryService {
  /**
   * Returns true when StageName has not changed within the given number of days.
   * Uses OpportunityFieldHistory; falls back to CreatedDate when no history exists.
   */
  public static Boolean isStageStaleForDays(Id opportunityId, Integer staleDays) {
    if (opportunityId == null || staleDays == null || staleDays <= 0) {
      return false;
    }

    DateTime cutoff = System.now().addDays(-staleDays);
    List<OpportunityFieldHistory> stageHistory = [
      SELECT CreatedDate
      FROM OpportunityFieldHistory
      WHERE OpportunityId = :opportunityId AND Field = 'StageName'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    if (!stageHistory.isEmpty()) {
      return stageHistory[0].CreatedDate <= cutoff;
    }

    List<Opportunity> opportunities = [
      SELECT CreatedDate
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    return !opportunities.isEmpty() && opportunities[0].CreatedDate <= cutoff;
  }

  public static Map<Id, Boolean> buildStageStaleMap(
    Set<Id> opportunityIds,
    Integer staleDays
  ) {
    Map<Id, Boolean> staleById = new Map<Id, Boolean>();
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return staleById;
    }

    Map<Id, DateTime> lastStageChangeById = new Map<Id, DateTime>();
    for (OpportunityFieldHistory historyRow : [
      SELECT OpportunityId, CreatedDate
      FROM OpportunityFieldHistory
      WHERE OpportunityId IN :opportunityIds AND Field = 'StageName'
      ORDER BY CreatedDate DESC
    ]) {
      if (!lastStageChangeById.containsKey(historyRow.OpportunityId)) {
        lastStageChangeById.put(historyRow.OpportunityId, historyRow.CreatedDate);
      }
    }

    DateTime cutoff = System.now().addDays(-staleDays);
    for (Opportunity opportunityRecord : [
      SELECT Id, CreatedDate
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ]) {
      DateTime lastChange = lastStageChangeById.containsKey(opportunityRecord.Id)
        ? lastStageChangeById.get(opportunityRecord.Id)
        : opportunityRecord.CreatedDate;
      staleById.put(opportunityRecord.Id, lastChange <= cutoff);
    }

    return staleById;
  }
}