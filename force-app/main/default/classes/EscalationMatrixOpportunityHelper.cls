/**
 * @description   Shared helper methods for opportunity activity calculations in escalation batches.
 * @author        Anshita Chanda
 * @date          2026-08-10
 */
public without sharing class EscalationMatrixOpportunityHelper {
  @TestVisible
  private static Map<Id, Date> testLastActivityDateOverrides;

  public static Map<Id, Date> getLastActivityDates(Set<Id> opportunityIds) {
    Map<Id, Date> lastActivityByOpportunityId = new Map<Id, Date>();

    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return lastActivityByOpportunityId;
    }

    if (Test.isRunningTest() && testLastActivityDateOverrides != null) {
      for (Id opportunityId : opportunityIds) {
        if (testLastActivityDateOverrides.containsKey(opportunityId)) {
          lastActivityByOpportunityId.put(
            opportunityId,
            testLastActivityDateOverrides.get(opportunityId)
          );
        }
      }
      if (lastActivityByOpportunityId.size() == opportunityIds.size()) {
        return lastActivityByOpportunityId;
      }
      lastActivityByOpportunityId.clear();
    }

    for (Opportunity opportunityRecord : [
      SELECT Id, LastActivityDate, CreatedDate
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ]) {
      if (opportunityRecord.LastActivityDate != null) {
        lastActivityByOpportunityId.put(
          opportunityRecord.Id,
          opportunityRecord.LastActivityDate
        );
      } else {
        lastActivityByOpportunityId.put(
          opportunityRecord.Id,
          opportunityRecord.CreatedDate.date()
        );
      }
    }

    for (Task taskRecord : [
      SELECT WhatId, ActivityDate
      FROM Task
      WHERE WhatId IN :opportunityIds AND ActivityDate != NULL
    ]) {
      Date existingDate = lastActivityByOpportunityId.get(taskRecord.WhatId);
      if (existingDate == null || taskRecord.ActivityDate > existingDate) {
        lastActivityByOpportunityId.put(taskRecord.WhatId, taskRecord.ActivityDate);
      }
    }

    for (Event eventRecord : [
      SELECT WhatId, ActivityDate
      FROM Event
      WHERE WhatId IN :opportunityIds AND ActivityDate != NULL
    ]) {
      Date existingDate = lastActivityByOpportunityId.get(eventRecord.WhatId);
      if (existingDate == null || eventRecord.ActivityDate > existingDate) {
        lastActivityByOpportunityId.put(eventRecord.WhatId, eventRecord.ActivityDate);
      }
    }

    return lastActivityByOpportunityId;
  }

  public static Long hoursSinceDate(Date activityDate) {
    if (activityDate == null) {
      return 0;
    }

    Datetime activityDateTime = Datetime.newInstance(
      activityDate,
      Time.newInstance(0, 0, 0, 0)
    );
    return EscalationMatrixEmailService.hoursSince(activityDateTime);
  }

  @TestVisible
  static void setTestLastActivityDate(Id opportunityId, Date activityDate) {
    if (testLastActivityDateOverrides == null) {
      testLastActivityDateOverrides = new Map<Id, Date>();
    }
    testLastActivityDateOverrides.put(opportunityId, activityDate);
  }

  @TestVisible
  static void clearTestLastActivityDates() {
    testLastActivityDateOverrides = null;
  }
}