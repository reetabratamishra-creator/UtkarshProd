public without sharing class BWM_EmailService {
  public class SendResult {
    public Boolean sent = false;
    public String skipReason;
    public List<Email_Log__c> logs = new List<Email_Log__c>();
    public Boolean scheduledDelayed = false;
  }

  public static SendResult sendForLeadCreate(Id leadId) {
    SendResult result = new SendResult();
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();

    if (settings == null || settings.Is_Enabled__c != true) {
      result.skipReason = 'Email is disabled or settings are missing.';
      return result;
    }

    Lead leadRecord = BWM_EmailRecordQueryService.queryLead(leadId);
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolveForLeadCreate(
      leadRecord
    );

    if (!resolveResult.shouldSend) {
      result.skipReason = resolveResult.skipReason;
      return result;
    }

    return sendEmail(
      settings,
      leadRecord,
      BWM_EmailConstants.TRIGGER_LEAD_CREATE,
      resolveResult.mapping
    );
  }

  public static SendResult send(Id recordId, String triggerPoint) {
    return send(recordId, triggerPoint, null);
  }

  public static SendResult send(
    Id recordId,
    String triggerPoint,
    String stageAtAction
  ) {
    SendResult result = new SendResult();
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();

    if (settings == null || settings.Is_Enabled__c != true) {
      result.skipReason = 'Email is disabled or settings are missing.';
      return result;
    }

    if (recordId == null || String.isBlank(triggerPoint)) {
      result.skipReason = 'Record Id and trigger point are required.';
      return result;
    }

    SObject record = queryRecord(recordId);
    BWM_EmailTemplateResolver.ResolveResult resolveResult = BWM_EmailTemplateResolver.resolve(
      triggerPoint,
      record,
      stageAtAction
    );

    if (!resolveResult.shouldSend) {
      result.skipReason = resolveResult.skipReason;
      return result;
    }

    result = sendEmail(settings, record, triggerPoint, resolveResult.mapping);
    maybeScheduleCompanionDelayedSend(record, triggerPoint, result);
    return result;
  }

  public static SendResult sendScheduled(Id recordId, String triggerPoint) {
    return send(recordId, triggerPoint);
  }

  public static Boolean scheduleDelayedSend(
    Id recordId,
    String triggerPoint,
    Integer delayHours
  ) {
    if (recordId == null || String.isBlank(triggerPoint) || delayHours == null) {
      return false;
    }

    if (hasPendingScheduledSend(recordId, triggerPoint)) {
      return false;
    }

    BWM_Email_Scheduled_Send__c scheduled = new BWM_Email_Scheduled_Send__c();
    scheduled.Related_Record_Id__c = String.valueOf(recordId);
    scheduled.Trigger_Point__c = triggerPoint;
    scheduled.Process_After__c = System.now().addHours(delayHours);
    scheduled.Status__c = BWM_EmailConstants.SCHEDULE_STATUS_PENDING;

    if (recordId.getSObjectType() == Lead.SObjectType) {
      scheduled.Lead__c = recordId;
    } else if (recordId.getSObjectType() == Opportunity.SObjectType) {
      scheduled.Opportunity__c = recordId;
    }

    insert scheduled;
    return true;
  }

  private static SObject queryRecord(Id recordId) {
    String objectName = recordId.getSObjectType().getDescribe().getName();

    if (objectName == BWM_EmailConstants.OBJECT_LEAD) {
      return BWM_EmailRecordQueryService.queryLead(recordId);
    }
    if (objectName == BWM_EmailConstants.OBJECT_OPPORTUNITY) {
      return BWM_EmailRecordQueryService.queryOpportunity(recordId);
    }
    if (objectName == BWM_EmailConstants.OBJECT_ACCOUNT) {
      return BWM_EmailRecordQueryService.queryAccount(recordId);
    }

    throw new BWM_EmailException(
      'Unsupported object type for email: ' + objectName
    );
  }

  private static SendResult sendEmail(
    BWM_Email_Settings__mdt settings,
    SObject record,
    String triggerPoint,
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    SendResult result = new SendResult();
    BWM_EmailPayloadBuilder.BuiltEmail built = BWM_EmailPayloadBuilder.build(
      settings,
      mapping,
      record
    );

    if (!hasValidRecipient(built)) {
      result.skipReason = 'Record does not have a valid recipient email.';
      result.logs.add(
        BWM_EmailLogService.buildLog(
          record,
          triggerPoint,
          mapping,
          built.senderEmail,
          formatRecipientEmailForLog(built),
          BWM_EmailConstants.LOG_STATUS_SKIPPED,
          null,
          null,
          built.payloadJson
        )
      );
      BWM_EmailLogService.applyResolvedTemplateId(
        result.logs[0],
        built.templateIdUsed
      );
      result.logs[0].Response_Message__c = result.skipReason;
      return result;
    }

    String requestCurl = 'Salesforce Native Email';
    BWM_EmailApiResponse apiResponse;
    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      settings,
      mapping,
      record
    );
    BWM_EmailNativeSender.SendOutcome nativeOutcome = BWM_EmailNativeSender.send(
      settings,
      built,
      mapping,
      record,
      attachments
    );

    apiResponse = new BWM_EmailApiResponse();
    apiResponse.message = nativeOutcome.message;
    apiResponse.rawBody = nativeOutcome.auditPayload;
    apiResponse.httpStatus = nativeOutcome.success ? 200 : 400;
    apiResponse.isSuccess = nativeOutcome.success;

    result.logs.add(
      BWM_EmailLogService.buildLog(
        record,
        triggerPoint,
        mapping,
        built.senderEmail,
        formatRecipientEmailForLog(built),
        apiResponse.isSuccess
          ? BWM_EmailConstants.LOG_STATUS_SENT
          : BWM_EmailConstants.LOG_STATUS_FAILED,
        apiResponse,
        requestCurl,
        nativeOutcome.auditPayload
      )
    );
    BWM_EmailLogService.applyResolvedTemplateId(
      result.logs[0],
      built.templateIdUsed
    );
    result.sent = nativeOutcome.success;
    return result;
  }

  private static void maybeScheduleCompanionDelayedSend(
    SObject record,
    String triggerPoint,
    SendResult result
  ) {
    if (result == null || !result.sent) {
      return;
    }

    if (
      triggerPoint ==
      BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING
    ) {
      result.scheduledDelayed = scheduleDelayedSend(
        record.Id,
        BWM_EmailConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING_DELAYED,
        24
      );
    } else if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE
    ) {
      result.scheduledDelayed = scheduleDelayedSend(
        record.Id,
        BWM_EmailConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE_DELAYED,
        48
      );
    }
  }

  private static Boolean hasPendingScheduledSend(
    Id recordId,
    String triggerPoint
  ) {
    Integer pendingCount = [
      SELECT COUNT()
      FROM BWM_Email_Scheduled_Send__c
      WHERE
        Related_Record_Id__c = :String.valueOf(recordId)
        AND Trigger_Point__c = :triggerPoint
        AND Status__c = :BWM_EmailConstants.SCHEDULE_STATUS_PENDING
    ];
    return pendingCount > 0;
  }

  @TestVisible
  private static Boolean hasValidRecipient(
    BWM_EmailPayloadBuilder.BuiltEmail built
  ) {
    if (built == null) {
      return false;
    }
    if (built.recipientEmails != null) {
      for (String emailAddress : built.recipientEmails) {
        if (isValidEmail(emailAddress)) {
          return true;
        }
      }
    }
    return isValidEmail(built.recipientEmail);
  }

  @TestVisible
  private static String formatRecipientEmailForLog(
    BWM_EmailPayloadBuilder.BuiltEmail built
  ) {
    if (built == null) {
      return null;
    }
    if (built.recipientEmails != null && !built.recipientEmails.isEmpty()) {
      return String.join(built.recipientEmails, '; ');
    }
    return built.recipientEmail;
  }

  @TestVisible
  private static Boolean isValidEmail(String emailAddress) {
    if (String.isBlank(emailAddress)) {
      return false;
    }
    String trimmed = emailAddress.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }
}