/**
 * @description   Reads Trigger_Enable__mdt so Anshita-created triggers can be
 *                turned off during data loads without changing Apex.
 *                Missing metadata keeps the trigger ON so existing behaviour
 *                is unchanged.
 * @author        Anshita Chanda
 * @date          2026-08-23
 */
public without sharing class TriggerEnableService {
  public static final String BWM_TASK_LOG_UNOLO = 'BWM_TaskLogUnoloTrigger';
  public static final String CASE_TRIGGER = 'CaseTrigger';
  public static final String EXPENSE_TRIGGER = 'ExpenseTrigger';
  public static final String EXPENSE_LINE_TRIGGER = 'ExpenseLineTrigger';
  public static final String OPPORTUNITY_TEAM_MEMBER = 'OpportunityTeamMemberTrigger';
  public static final String PUNCH_RECORD_WFH_EMAIL = 'PunchRecordWfhEmployeeEmailTrigger';
  public static final String TASK_OVERDUE_TRIGGER = 'TaskOverdueTrigger';

  @TestVisible
  private static Map<String, Boolean> testOverrides;

  /**
   * @description Returns true when the named trigger should run.
   * @param developerName Trigger_Enable__mdt DeveloperName matching the trigger.
   */
  public static Boolean isEnabled(String developerName) {
    if (String.isBlank(developerName)) {
      return true;
    }

    if (Test.isRunningTest() && testOverrides != null && testOverrides.containsKey(developerName)) {
      return testOverrides.get(developerName) == true;
    }

    Trigger_Enable__mdt control = Trigger_Enable__mdt.getInstance(developerName);
    if (control == null) {
      return true;
    }
    return control.IsEnable__c == true;
  }

  @TestVisible
  static void setTestOverride(String developerName, Boolean isEnabled) {
    if (testOverrides == null) {
      testOverrides = new Map<String, Boolean>();
    }
    testOverrides.put(developerName, isEnabled);
  }

  @TestVisible
  static void clearTestOverrides() {
    testOverrides = null;
  }
}