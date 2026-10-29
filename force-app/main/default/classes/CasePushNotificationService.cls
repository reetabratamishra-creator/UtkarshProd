/**
 * @description Sends Case custom push notifications to the Case Owner (Employee).
 * @author Anshita Chanda
 * @date 2026-08-17
 */
public without sharing class CasePushNotificationService {
  public static final String NOTIF_TYPE_EMPLOYEE = 'Case_Employee_Push_Notification';
  public static final String NOTIF_TYPE_OWNER_CHANGE = 'Case_Owner_Change_Push_Notification';

  public static final String TITLE_UPDATED = 'Case Updated';
  public static final String TITLE_REASSIGNED = 'Case Assigned';
  public static final String TITLE_FOLLOW_UP = 'Follow-up Due Today';
  public static final String TITLE_SLA_BREACHED = 'SLA Breached';
  public static final String TITLE_RESOLVED = 'Case Resolved';
  public static final String TITLE_REOPENED = 'Case Reopened';
  public static final String TITLE_NO_UPDATE = 'Case Update Pending';

  public static final String BODY_UPDATED =
    'Your Case details have been updated successfully.';
  public static final String BODY_REASSIGNED =
    'A case has been assigned to you. Please review and initiate action.';
  public static final String BODY_NO_UPDATE =
    'This case has had no activity for 36 hours. Please take the necessary action.';

  @TestVisible
  private static final Set<String> IGNORED_UPDATE_FIELDS = new Set<String>{
    'LastModifiedDate',
    'LastModifiedById',
    'SystemModstamp',
    'Response_Esc_Owner_Sent__c',
    'Response_Esc_HOD_Sent__c',
    'Response_Esc_Sir_Sent__c',
    'SLA_Breached_Push_Sent__c',
    'SLA_Breached_HOD_Push_Sent__c',
    'SLA_Breached_CRM_Head_Push_Sent__c',
    'No_Update_36h_Push_Sent__c',
    'No_Update_36h_HOD_Push_Sent__c',
    'No_Update_36h_CRM_Head_Push_Sent__c',
    'Follow_Up_Due_Push_Sent_On__c'
  };

  /**
   * @description Sends owner push notifications for qualifying Case updates.
   */
  public static void sendForUpdatedCases(
    List<Case> newRecords,
    Map<Id, Case> oldRecordsById
  ) {
    if (newRecords == null || newRecords.isEmpty() || oldRecordsById == null) {
      return;
    }

    Set<Id> reassignedCaseIds = new Set<Id>();
    Set<Id> resolvedCaseIds = new Set<Id>();
    Set<Id> reopenedCaseIds = new Set<Id>();
    Set<Id> updatedCaseIds = new Set<Id>();

    for (Case caseRecord : newRecords) {
      Case oldCase = oldRecordsById.get(caseRecord.Id);
      if (oldCase == null) {
        continue;
      }

      if (isReassignment(caseRecord, oldCase)) {
        reassignedCaseIds.add(caseRecord.Id);
      } else if (isNewlyResolved(caseRecord, oldCase)) {
        resolvedCaseIds.add(caseRecord.Id);
      } else if (isNewlyReopened(caseRecord, oldCase)) {
        reopenedCaseIds.add(caseRecord.Id);
      } else if (hasMeaningfulUpdate(caseRecord, oldCase)) {
        updatedCaseIds.add(caseRecord.Id);
      }
    }

    sendByScenario(reassignedCaseIds, TITLE_REASSIGNED, BODY_REASSIGNED, NOTIF_TYPE_OWNER_CHANGE);
    sendByScenario(
      resolvedCaseIds,
      TITLE_RESOLVED,
      'Case #Case Number has been resolved successfully.',
      NOTIF_TYPE_EMPLOYEE
    );
    sendByScenario(
      reopenedCaseIds,
      TITLE_REOPENED,
      'Case #Case Number has been reopened. Please continue the required action.',
      NOTIF_TYPE_EMPLOYEE
    );
    sendByScenario(updatedCaseIds, TITLE_UPDATED, BODY_UPDATED, NOTIF_TYPE_EMPLOYEE);
  }

  /**
   * @description Sends follow-up-due-today push notifications and updates dedup fields.
   */
  public static void processFollowUpDueToday(List<Case> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    Date today = Date.today();
    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      if (!isFollowUpDueToday(caseRecord, today)) {
        continue;
      }

      String body =
        'Reminder: Follow-up is due today for Case #' +
        caseRecord.CaseNumber +
        '.';

      if (
        sendToOwner(
          caseRecord,
          TITLE_FOLLOW_UP,
          body,
          NOTIF_TYPE_EMPLOYEE
        )
      ) {
        casesToUpdate.add(
          new Case(
            Id = caseRecord.Id,
            Follow_Up_Due_Push_Sent_On__c = today
          )
        );
      }
    }

    if (!casesToUpdate.isEmpty()) {
      updateCasesAllowPartial(casesToUpdate);
    }
  }

  /**
   * @description Sends SLA-breached owner push notifications and updates dedup fields.
   */
  public static void processSlaBreached(List<Case> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      if (
        caseRecord.SLA_Breached_Push_Sent__c == true ||
        caseRecord.First_Response__c == true ||
        !CaseSLAEscalationEmailService.isTierDue(
          caseRecord,
          CaseSLAEscalationEmailService.EscalationTier.OWNER
        )
      ) {
        continue;
      }

      String body =
        'Case #' +
        caseRecord.CaseNumber +
        ' has exceeded the SLA. Immediate action is required.';

      if (
        sendToOwner(
          caseRecord,
          TITLE_SLA_BREACHED,
          body,
          NOTIF_TYPE_EMPLOYEE
        )
      ) {
        casesToUpdate.add(
          new Case(Id = caseRecord.Id, SLA_Breached_Push_Sent__c = true)
        );
      }
    }

    if (!casesToUpdate.isEmpty()) {
      updateCasesAllowPartial(casesToUpdate);
    }
  }

  /**
   * @description Sends 36-hour no-update push notifications and updates dedup fields.
   */
  public static void processNoUpdate36h(List<Case> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<Case> casesToUpdate = new List<Case>();

    for (Case caseRecord : scope) {
      if (caseRecord.No_Update_36h_Push_Sent__c == true) {
        continue;
      }

      if (
        sendToOwner(
          caseRecord,
          TITLE_NO_UPDATE,
          BODY_NO_UPDATE,
          NOTIF_TYPE_EMPLOYEE
        )
      ) {
        casesToUpdate.add(
          new Case(Id = caseRecord.Id, No_Update_36h_Push_Sent__c = true)
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
    String bodyTemplate,
    String notificationTypeDevName
  ) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }

    for (Case caseRecord : [
      SELECT Id, CaseNumber, OwnerId
      FROM Case
      WHERE Id IN :caseIds
    ]) {
      sendToOwner(
        caseRecord,
        title,
        formatBody(bodyTemplate, caseRecord.CaseNumber),
        notificationTypeDevName
      );
    }
  }

  @TestVisible
  private static Boolean sendToOwner(
    Case caseRecord,
    String title,
    String body,
    String notificationTypeDevName
  ) {
    if (caseRecord == null || !isUserOwner(caseRecord.OwnerId)) {
      return false;
    }

    return CrmPushNotificationService.send(
      caseRecord.OwnerId,
      caseRecord.Id,
      title,
      body,
      notificationTypeDevName
    );
  }

  @TestVisible
  private static String formatBody(String bodyTemplate, String caseNumber) {
    if (String.isBlank(bodyTemplate)) {
      return bodyTemplate;
    }
    return bodyTemplate.replace('#Case Number', String.valueOf(caseNumber));
  }

  @TestVisible
  private static Boolean isUserOwner(Id ownerId) {
    return ownerId != null && String.valueOf(ownerId).startsWith('005');
  }

  @TestVisible
  private static Boolean isReassignment(Case caseRecord, Case oldCase) {
    return caseRecord.OwnerId != null &&
      caseRecord.OwnerId != oldCase.OwnerId;
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
  private static Boolean hasMeaningfulUpdate(Case caseRecord, Case oldCase) {
    Map<String, Object> populatedFields = caseRecord.getPopulatedFieldsAsMap();

    for (String fieldName : populatedFields.keySet()) {
      if (IGNORED_UPDATE_FIELDS.contains(fieldName)) {
        continue;
      }

      Object newValue = caseRecord.get(fieldName);
      Object oldValue = oldCase.get(fieldName);
      if (newValue != oldValue) {
        return true;
      }
    }

    return false;
  }

  @TestVisible
  private static Boolean isFollowUpDueToday(Case caseRecord, Date today) {
    if (
      caseRecord == null ||
      caseRecord.IsClosed == true ||
      caseRecord.Due_Date_Time__c == null
    ) {
      return false;
    }

    if (
      caseRecord.Follow_Up_Due_Push_Sent_On__c != null &&
      caseRecord.Follow_Up_Due_Push_Sent_On__c == today
    ) {
      return false;
    }

    return caseRecord.Due_Date_Time__c >= Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0)) &&
      caseRecord.Due_Date_Time__c < Datetime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));
  }

  @TestVisible
  static void clearTestState() {
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
        'Case owner push flag update failed for ' +
          casesToUpdate[index].Id +
          ': ' +
          errorMessage
      );
    }
  }
}