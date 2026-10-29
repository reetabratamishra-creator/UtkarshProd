/**
 * @description Holds the campaign schedule timestamp for the current send transaction.
 */
public with sharing class BWM_CampaignScheduleContext {
  public static String scheduledDateTime;

  public static void setScheduledDateTime(String value) {
    scheduledDateTime = value;
  }

  public static void clear() {
    scheduledDateTime = null;
  }
}