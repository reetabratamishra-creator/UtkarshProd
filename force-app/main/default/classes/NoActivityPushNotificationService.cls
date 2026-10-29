/**
 * @description   Sends custom push notifications when no activity is detected on Leads or Opportunities.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class NoActivityPushNotificationService {
  private static final String LEAD_NOTIF_TYPE = 'Prospecting_Lead_Push_Notification';
  private static final String OPP_NOTIF_TYPE = 'Activity_Assignment';
  private static final String LEAD_TITLE = 'No Activity Detected';
  private static final String OPP_TITLE = 'No Activity Detected';

  @TestVisible
  private static Map<Id, Datetime> testLastProspectingActivityOverrides;

  public static void processLeads(List<Lead> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<Lead> leadsToUpdate = new List<Lead>();

    for (Lead leadRecord : scope) {
      Datetime activityAnchor = resolveProspectingActivityAnchor(leadRecord);
      Long hoursSinceActivity = EscalationMatrixEmailService.hoursSince(activityAnchor);

      if (hoursSinceActivity < 24) {
        continue;
      }

      String body =
        'No activity recorded in 24 hours in this lead. please take necessary action. Click below ' +
        leadRecord.Name +
        '.';

      if (
        CrmPushNotificationService.send(
          leadRecord.OwnerId,
          leadRecord.Id,
          LEAD_TITLE,
          body,
          LEAD_NOTIF_TYPE
        )
      ) {
        leadsToUpdate.add(
          new Lead(
            Id = leadRecord.Id,
            Prospecting_No_Activity_Push_24_Sent__c = true
          )
        );
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      Database.update(leadsToUpdate, false);
    }
  }

  public static void processOpportunities(List<Opportunity> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    Map<Id, Date> lastActivityByOpportunityId = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Map<Id, Opportunity>(scope).keySet()
    );
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    for (Opportunity opportunityRecord : scope) {
      Date lastActivityDate = lastActivityByOpportunityId.containsKey(opportunityRecord.Id)
        ? lastActivityByOpportunityId.get(opportunityRecord.Id)
        : opportunityRecord.CreatedDate.date();
      Long hoursSinceActivity = EscalationMatrixOpportunityHelper.hoursSinceDate(
        lastActivityDate
      );
      Integer daysSinceActivity = lastActivityDate == null
        ? 0
        : lastActivityDate.daysBetween(Date.today());

      Opportunity updateRecord = new Opportunity(Id = opportunityRecord.Id);
      Boolean changed = false;

      if (
        isActiveOpportunity(opportunityRecord) &&
        !opportunityRecord.Active_No_Activity_Push_72_Sent__c &&
        hoursSinceActivity >= 72
      ) {
        String body =
          'No activity recorded in 72 hours in this Opportunity. please take necessary action. Click below ' +
          opportunityRecord.Name +
          '.';

        if (
          CrmPushNotificationService.send(
            opportunityRecord.OwnerId,
            opportunityRecord.Id,
            OPP_TITLE,
            body,
            OPP_NOTIF_TYPE
          )
        ) {
          updateRecord.Active_No_Activity_Push_72_Sent__c = true;
          changed = true;
        }
      }

      if (
        isProjectOrTenderOpportunity(opportunityRecord) &&
        !opportunityRecord.Project_Tender_No_Activity_Push_90d_Sent__c &&
        daysSinceActivity >= 90
      ) {
        String body =
          'No activity recorded in 3 months in this Opportunity. please take necessary action. Click below ' +
          opportunityRecord.Name +
          '.';

        if (
          CrmPushNotificationService.send(
            opportunityRecord.OwnerId,
            opportunityRecord.Id,
            OPP_TITLE,
            body,
            OPP_NOTIF_TYPE
          )
        ) {
          updateRecord.Project_Tender_No_Activity_Push_90d_Sent__c = true;
          changed = true;
        }
      }

      if (changed) {
        opportunitiesToUpdate.add(updateRecord);
      }
    }

    if (!opportunitiesToUpdate.isEmpty()) {
      List<Opportunity> safeUpdates = new List<Opportunity>();
      for (Opportunity opportunityRecord : opportunitiesToUpdate) {
        if (opportunityRecord.Id != null && Approval.isLocked(opportunityRecord.Id)) {
          System.debug(
            LoggingLevel.WARN,
            'Skipped no-activity push flag update for locked Opportunity ' +
              opportunityRecord.Id
          );
          continue;
        }
        safeUpdates.add(opportunityRecord);
      }
      if (!safeUpdates.isEmpty()) {
        Database.update(safeUpdates, false);
      }
    }
  }

  @TestVisible
  static Boolean isActiveOpportunity(Opportunity opportunityRecord) {
    return opportunityRecord.StageName == 'Nurture' &&
      opportunityRecord.RecordType != null &&
      opportunityRecord.RecordType.DeveloperName != 'Tender_Opportunity' &&
      opportunityRecord.Budget_Confirmed__c == false;
  }

  @TestVisible
  static Boolean isProjectOrTenderOpportunity(Opportunity opportunityRecord) {
    if (opportunityRecord.RecordType == null) {
      return false;
    }

    String recordTypeDeveloperName = opportunityRecord.RecordType.DeveloperName;
    return recordTypeDeveloperName == 'Project_Opportunity' ||
      recordTypeDeveloperName == 'Tender_Opportunity';
  }

  private static Datetime resolveProspectingActivityAnchor(Lead leadRecord) {
    if (
      Test.isRunningTest() &&
      testLastProspectingActivityOverrides != null &&
      testLastProspectingActivityOverrides.containsKey(leadRecord.Id)
    ) {
      return testLastProspectingActivityOverrides.get(leadRecord.Id);
    }

    return leadRecord.Last_Prospecting_Activity__c;
  }

  @TestVisible
  static void setTestLastProspectingActivity(Id leadId, Datetime activityDate) {
    if (testLastProspectingActivityOverrides == null) {
      testLastProspectingActivityOverrides = new Map<Id, Datetime>();
    }
    testLastProspectingActivityOverrides.put(leadId, activityDate);
  }

  @TestVisible
  static void clearTestState() {
    testLastProspectingActivityOverrides = null;
    CrmPushNotificationService.clearTestState();
  }
}