/**
 * @description Sends Case push notifications to the Department HOD for all scenarios.
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CaseHodPushService {
  public static final String NOTIF_TYPE = 'Case_Employee_Push_Notification';
  public static final String NOTIF_TYPE_DEPT_ASSIGNMENT =
    'Department_Changed_Notification';

  public static final String TITLE_DEPT_ASSIGNMENT =
    'New Case Assigned to Department';
  public static final String BODY_DEPT_ASSIGNMENT =
    'A new case has been assigned to your department.';

  public static final String TITLE_RESOLVED = 'Case Resolved';
  public static final String TITLE_REOPENED = 'Case Reopened';
  public static final String TITLE_NO_UPDATE = 'Case Update Pending';

  public static final String BODY_RESOLVED =
    'Case #Case Number has been resolved successfully.';
  public static final String BODY_REOPENED =
    'Case #Case Number has been reopened by the customer.';
  public static final String BODY_NO_UPDATE =
    'A case under your department has had no activity for the last 36 hours. Please review and ensure necessary action is taken.';

  /**
   * @description Sends HOD push notifications when a Case is newly assigned to a department.
   */
  public static void sendForNewDepartmentAssignments(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Case caseRecord : newRecords) {
      Case oldCase = oldRecordsById == null
        ? null
        : oldRecordsById.get(caseRecord.Id);
      if (isNewDepartmentAssignment(caseRecord, oldCase)) {
        caseIds.add(caseRecord.Id);
      }
    }

    if (caseIds.isEmpty()) {
      return;
    }

    for (Case caseRecord : [
      SELECT
        Id,
        CaseNumber,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c
      FROM Case
      WHERE Id IN :caseIds
    ]) {
      sendToDepartmentHod(
        caseRecord,
        TITLE_DEPT_ASSIGNMENT,
        BODY_DEPT_ASSIGNMENT,
        NOTIF_TYPE_DEPT_ASSIGNMENT
      );
    }
  }

  /**
   * @description Sends HOD push notifications when a Case is resolved or reopened.
   */
  public static void sendForUpdatedCases(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (newRecords == null || newRecords.isEmpty() || oldRecordsById == null) {
      return;
    }

    Set<Id> resolvedCaseIds = new Set<Id>();
    Set<Id> reopenedCaseIds = new Set<Id>();

    for (Case caseRecord : newRecords) {
      Case oldCase = oldRecordsById.get(caseRecord.Id);
      if (oldCase == null) {
        continue;
      }

      if (isNewlyResolved(caseRecord, oldCase)) {
        resolvedCaseIds.add(caseRecord.Id);
      } else if (isNewlyReopened(caseRecord, oldCase)) {
        reopenedCaseIds.add(caseRecord.Id);
      }
    }

    sendByScenario(resolvedCaseIds, TITLE_RESOLVED, BODY_RESOLVED);
    sendByScenario(reopenedCaseIds, TITLE_REOPENED, BODY_REOPENED);
  }

  /**
   * @description Sends priority-specific SLA-breached HOD push notifications.
   */
  public static void processSlaBreached(List<Case> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      if (
        caseRecord.SLA_Breached_HOD_Push_Sent__c == true ||
        caseRecord.First_Response__c == true ||
        !hasDepartment(caseRecord) ||
        !CaseSLAEscalationEmailService.isTierDue(
          caseRecord,
          CaseSLAEscalationEmailService.EscalationTier.OWNER
        )
      ) {
        continue;
      }

      String title = resolveSlaBreachedTitle(caseRecord.Priority);
      String body = resolveSlaBreachedBody(caseRecord);
      if (String.isBlank(title) || String.isBlank(body)) {
        continue;
      }

      if (sendToDepartmentHod(caseRecord, title, body)) {
        casesToUpdate.add(
          new Case(Id = caseRecord.Id, SLA_Breached_HOD_Push_Sent__c = true)
        );
      }
    }

    if (!casesToUpdate.isEmpty()) {
      updateCasesAllowPartial(casesToUpdate);
    }
  }

  /**
   * @description Sends 36-hour no-update HOD push notifications.
   */
  public static void processNoUpdate36h(List<Case> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      if (
        caseRecord.No_Update_36h_HOD_Push_Sent__c == true ||
        !hasDepartment(caseRecord)
      ) {
        continue;
      }

      if (sendToDepartmentHod(caseRecord, TITLE_NO_UPDATE, BODY_NO_UPDATE)) {
        casesToUpdate.add(
          new Case(Id = caseRecord.Id, No_Update_36h_HOD_Push_Sent__c = true)
        );
      }
    }

    if (!casesToUpdate.isEmpty()) {
      updateCasesAllowPartial(casesToUpdate);
    }
  }

  @TestVisible
  private static void sendByScenario(
    Set<Id> caseIds,
    String title,
    String bodyTemplate
  ) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }

    for (Case caseRecord : [
      SELECT
        Id,
        CaseNumber,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c
      FROM Case
      WHERE Id IN :caseIds
    ]) {
      if (!hasDepartment(caseRecord)) {
        continue;
      }

      sendToDepartmentHod(
        caseRecord,
        title,
        formatBody(bodyTemplate, caseRecord.CaseNumber)
      );
    }
  }

  @TestVisible
  private static Boolean sendToDepartmentHod(
    Case caseRecord,
    String title,
    String body
  ) {
    return sendToDepartmentHod(caseRecord, title, body, NOTIF_TYPE);
  }

  @TestVisible
  private static Boolean sendToDepartmentHod(
    Case caseRecord,
    String title,
    String body,
    String notifType
  ) {
    if (
      caseRecord == null ||
      String.isBlank(title) ||
      String.isBlank(body) ||
      String.isBlank(notifType)
    ) {
      return false;
    }

    Set<Id> recipientUserIds = CrmPushRecipientService.resolveCaseDepartmentHodUserIds(
      caseRecord
    );
    if (recipientUserIds.isEmpty()) {
      return false;
    }

    Integer sentCount = CrmPushNotificationService.sendToUsers(
      recipientUserIds,
      caseRecord.Id,
      title,
      body,
      notifType
    );
    return sentCount > 0;
  }

  @TestVisible
  private static String resolveSlaBreachedTitle(String priority) {
    if (priority == 'Critical') {
      return 'Critical Priority Case: SLA Breached';
    }
    if (priority == 'High') {
      return 'High Priority Case: SLA Breached';
    }
    if (priority == 'Medium') {
      return 'Medium Priority Case: SLA Breached';
    }
    if (priority == 'Low') {
      return 'Low Priority Case: SLA Breached';
    }
    return null;
  }

  @TestVisible
  private static String resolveSlaBreachedBody(Case caseRecord) {
    if (caseRecord == null || String.isBlank(caseRecord.CaseNumber)) {
      return null;
    }

    String prefix;
    if (caseRecord.Priority == 'Critical') {
      prefix = 'Critical Case';
    } else if (caseRecord.Priority == 'High') {
      prefix = 'High Priority';
    } else if (caseRecord.Priority == 'Medium') {
      prefix = 'Medium Priority';
    } else if (caseRecord.Priority == 'Low') {
      prefix = 'Low Priority Critical Case';
    } else {
      return null;
    }

    return prefix +
      ': #' +
      caseRecord.CaseNumber +
      ' has exceeded the SLA. Immediate action is required.';
  }

  @TestVisible
  private static String formatBody(String bodyTemplate, String caseNumber) {
    if (String.isBlank(bodyTemplate)) {
      return bodyTemplate;
    }
    return bodyTemplate.replace('#Case Number', String.valueOf(caseNumber));
  }

  @TestVisible
  private static Boolean hasDepartment(Case caseRecord) {
    return caseRecord != null &&
      (String.isNotBlank(caseRecord.Department__c) ||
      String.isNotBlank(caseRecord.Department_formula__c));
  }

  @TestVisible
  private static Boolean isNewDepartmentAssignment(Case caseRecord, Case oldCase) {
    String newDepartment = resolveDepartmentKey(caseRecord);
    if (String.isBlank(newDepartment)) {
      return false;
    }

    if (oldCase == null) {
      return true;
    }

    String oldDepartment = resolveDepartmentKey(oldCase);
    return String.isBlank(oldDepartment) || oldDepartment != newDepartment;
  }

  @TestVisible
  private static String resolveDepartmentKey(Case caseRecord) {
    if (caseRecord == null) {
      return null;
    }
    if (String.isNotBlank(caseRecord.Department_formula__c)) {
      return caseRecord.Department_formula__c.trim();
    }
    if (String.isNotBlank(caseRecord.Department__c)) {
      return caseRecord.Department__c.trim();
    }
    return null;
  }

  @TestVisible
  private static Boolean isNewlyResolved(Case caseRecord, Case oldCase) {
    if (caseRecord.IsClosed == true && oldCase.IsClosed != true) {
      return true;
    }
    return caseRecord.Status == 'Resolved' && oldCase.Status != 'Resolved';
  }

  @TestVisible
  private static Boolean isNewlyReopened(Case caseRecord, Case oldCase) {
    if (oldCase.IsClosed == true && caseRecord.IsClosed != true) {
      return true;
    }
    return oldCase.Status == 'Resolved' &&
      caseRecord.Status != 'Resolved' &&
      caseRecord.IsClosed != true;
  }

  @TestVisible
  static void clearTestState() {
    CrmPushRecipientService.clearTestState();
    CrmPushNotificationService.clearTestState();
  }

  /**
   * @description Partial Case flag updates so one Contact lookup-filter failure
   *              (Case Contact junction / mismatched Account) cannot block other Cases.
   */
  private static void updateCasesAllowPartial(List<Case> casesToUpdate) {
    if (casesToUpdate == null || casesToUpdate.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = Database.update(casesToUpdate, false);
    for (Integer index = 0; index < results.size(); index++) {
      if (results[index].isSuccess()) {
        continue;
      }
      String errorMessage = results[index].getErrors().isEmpty()
        ? 'Unknown error'
        : results[index].getErrors()[0].getMessage();
      System.debug(
        LoggingLevel.WARN,
        'Case HOD push flag update failed for ' +
          casesToUpdate[index].Id +
          ': ' +
          errorMessage
      );
    }
  }
}