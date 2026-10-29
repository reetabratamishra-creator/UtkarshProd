/**
 * @description   Shared helper for sending Salesforce custom (push) notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
public without sharing class CrmPushNotificationService {
  @TestVisible
  private static Map<String, Id> testNotificationTypeIds;

  @TestVisible
  private static List<NotificationSendRequest> testSentRequests;

  @TestVisible
  private static Boolean simulateProductionSend = false;

  private static Map<String, Id> notificationTypeIdByDeveloperName = new Map<String, Id>();

  public class NotificationSendRequest {
    public Id recipientId;
    public Id targetId;
    public String title;
    public String body;
    public String notificationTypeDevName;
  }

  /**
   * @description Sends a custom notification to one or more recipients.
   * @return count of recipients notified (or recorded in test context).
   */
  public static Integer sendToUsers(
    Set<Id> recipientIds,
    Id targetId,
    String title,
    String body,
    String notificationTypeDevName
  ) {
    if (recipientIds == null || recipientIds.isEmpty()) {
      return 0;
    }

    Integer sentCount = 0;
    for (Id recipientId : recipientIds) {
      if (send(recipientId, targetId, title, body, notificationTypeDevName)) {
        sentCount++;
      }
    }
    return sentCount;
  }

  /**
   * @description Sends a custom notification to a single recipient.
   * @return true when the notification was sent (or recorded in test context).
   */
  public static Boolean send(
    Id recipientId,
    Id targetId,
    String title,
    String body,
    String notificationTypeDevName
  ) {
    if (
      recipientId == null ||
      targetId == null ||
      String.isBlank(title) ||
      String.isBlank(body) ||
      String.isBlank(notificationTypeDevName)
    ) {
      return false;
    }

    if (Test.isRunningTest() && !simulateProductionSend) {
      recordTestSend(recipientId, targetId, title, body, notificationTypeDevName);
      return true;
    }

    Id notificationTypeId = resolveNotificationTypeId(notificationTypeDevName);
    if (notificationTypeId == null) {
      return false;
    }

    try {
      Messaging.CustomNotification notification = new Messaging.CustomNotification();
      notification.setTitle(title);
      notification.setBody(body);
      notification.setNotificationTypeId(notificationTypeId);
      notification.setTargetId(targetId);
      notification.setSenderId(UserInfo.getUserId());
      notification.send(new Set<String>{ String.valueOf(recipientId) });
      return true;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        'Custom push notification failed: ' + ex.getMessage()
      );
      return false;
    }
  }

  private static Id resolveNotificationTypeId(String notificationTypeDevName) {
    if (Test.isRunningTest() && testNotificationTypeIds != null) {
      return testNotificationTypeIds.get(notificationTypeDevName);
    }

    if (notificationTypeIdByDeveloperName.containsKey(notificationTypeDevName)) {
      return notificationTypeIdByDeveloperName.get(notificationTypeDevName);
    }

    List<CustomNotificationType> types = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :notificationTypeDevName
      LIMIT 1
    ];
    Id typeId = types.isEmpty() ? null : types[0].Id;
    notificationTypeIdByDeveloperName.put(notificationTypeDevName, typeId);
    return typeId;
  }

  /**
   * @description Updates Case reminder flags without failing the whole batch when
   *              one record hits a lookup-filter or validation error.
   */
  public static void updateCasesAllowPartial(List<Case> casesToUpdate) {
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
        'Case push flag update failed for ' +
          casesToUpdate[index].Id +
          ': ' +
          errorMessage
      );
    }
  }

  @TestVisible
  private static void recordTestSend(
    Id recipientId,
    Id targetId,
    String title,
    String body,
    String notificationTypeDevName
  ) {
    if (testSentRequests == null) {
      testSentRequests = new List<NotificationSendRequest>();
    }

    NotificationSendRequest request = new NotificationSendRequest();
    request.recipientId = recipientId;
    request.targetId = targetId;
    request.title = title;
    request.body = body;
    request.notificationTypeDevName = notificationTypeDevName;
    testSentRequests.add(request);
  }

  public static void clearTestState() {
    testNotificationTypeIds = null;
    testSentRequests = null;
    simulateProductionSend = false;
    notificationTypeIdByDeveloperName.clear();
  }
}