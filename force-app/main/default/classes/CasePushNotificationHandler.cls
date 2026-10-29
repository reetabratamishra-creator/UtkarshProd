/**
 * @description Trigger handler for all Case push notifications (Owner, HOD, CRM Head).
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CasePushNotificationHandler {
  private static final String CASE_RECORD_TYPE_DEV_NAME = 'Case';

  @TestVisible
  private static Boolean disableInTests = false;

  @TestVisible
  private static Boolean disableHodInTests = false;

  @TestVisible
  private static Boolean disableCrmHeadInTests = false;

  /**
   * @description Sends HOD and CRM Head push notifications on Case insert.
   */
  public static void handleAfterInsert(List<Case> newRecords) {
    List<Case> caseRecords = filterCaseRecordType(newRecords);
    if (caseRecords.isEmpty()) {
      return;
    }

    if (shouldRunHod()) {
      CaseHodPushService.sendForNewDepartmentAssignments(caseRecords, null);
    }

    if (shouldRunCrmHead()) {
      CaseCrmHeadPushService.sendForNewDepartmentAssignments(caseRecords, null);
    }
  }

  /**
   * @description Sends Owner, HOD, and CRM Head push notifications on Case update.
   */
  public static void handleAfterUpdate(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    List<Case> caseRecords = filterCaseRecordType(newRecords);
    if (caseRecords.isEmpty()) {
      return;
    }

    if (shouldRunOwner()) {
      CasePushNotificationService.sendForUpdatedCases(caseRecords, oldRecordsById);
    }

    if (shouldRunHod()) {
      CaseHodPushService.sendForNewDepartmentAssignments(
        caseRecords,
        oldRecordsById
      );
      CaseHodPushService.sendForUpdatedCases(caseRecords, oldRecordsById);
    }

    if (shouldRunCrmHead()) {
      CaseCrmHeadPushService.sendForNewDepartmentAssignments(
        caseRecords,
        oldRecordsById
      );
      CaseCrmHeadPushService.sendForUpdatedCases(caseRecords, oldRecordsById);
    }
  }

  private static List<Case> filterCaseRecordType(List<Case> cases) {
    if (cases == null || cases.isEmpty()) {
      return new List<Case>();
    }

    Id caseRecordTypeId = getCaseRecordTypeId();
    if (caseRecordTypeId == null) {
      return new List<Case>();
    }

    List<Case> filtered = new List<Case>();
    for (Case caseRecord : cases) {
      if (caseRecord.RecordTypeId == caseRecordTypeId) {
        filtered.add(caseRecord);
      }
    }
    return filtered;
  }

  private static Id getCaseRecordTypeId() {
    RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(CASE_RECORD_TYPE_DEV_NAME);
    return info == null ? null : info.getRecordTypeId();
  }

  @TestVisible
  private static Boolean shouldRunOwner() {
    return !(Test.isRunningTest() && disableInTests);
  }

  @TestVisible
  private static Boolean shouldRunHod() {
    return !(Test.isRunningTest() && disableHodInTests);
  }

  @TestVisible
  private static Boolean shouldRunCrmHead() {
    return !(Test.isRunningTest() && disableCrmHeadInTests);
  }
}