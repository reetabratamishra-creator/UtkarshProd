/**
 * @description Sends Day Start & Day End reminder emails based on reminder type.
 *              1. Day Start not done by 10:00 AM → Employee
 *              2. Day Start not done by 10:45 AM → HOD
 *              3. Day End not done by 12:00 Midnight → Employee
 * @author Rani Mate
 * @date 2026-08-14
 */
public without sharing class PunchRecordDayStartEndReminderBatch
    implements Database.Batchable<SObject>, Schedulable {

    public enum ReminderType {
        DAY_START_10AM,
        DAY_START_1045,
        DAY_END_MIDNIGHT
    }

    public static final String TEMPLATE_DAY_START_10AM =
        'Day_start_not_done_on_time_1786600176251';
    public static final String TEMPLATE_DAY_START_1045AM =
        'Day_start_not_done_within_10_45_AM_1786602337640';
    public static final String TEMPLATE_DAY_END_MIDNIGHT =
        'Day_end_not_done_by_12o_clock_midnight_1786603106530';

    public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

    @TestVisible
    private ReminderType reminderType;

    public PunchRecordDayStartEndReminderBatch() {
        this(null);
    }

    public PunchRecordDayStartEndReminderBatch(ReminderType reminderType) {
        this.reminderType = reminderType;
    }

    public void execute(SchedulableContext sc) {
        ReminderType scheduledType = resolveReminderTypeFromScheduleTime();
        if (scheduledType == null) {
            return;
        }
        Database.executeBatch(
            new PunchRecordDayStartEndReminderBatch(scheduledType),
            50
        );
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, User__c, HOD__c, Punch_Time__c, CreatedDate,
                   User__r.Email, HOD__r.Email
            FROM Punch_Record__c
            WHERE CreatedDate != TODAY
                AND Action__c = 'IN'
                AND Punch_Type__c = 'Day In / Out'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Punch_Record__c> scope) {
        ReminderType activeReminderType = reminderType == null
            ? resolveReminderTypeFromScheduleTime()
            : reminderType;
        if (activeReminderType == null || scope == null || scope.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (Punch_Record__c punchRecord : scope) {
            Boolean isDayStartDone = punchRecord.Punch_Time__c != null;

            if (
                activeReminderType ==
                    PunchRecordDayStartEndReminderBatch.ReminderType.DAY_START_10AM &&
                !isDayStartDone &&
                punchRecord.User__r.Email != null
            ) {
                Messaging.SingleEmailMessage mail = buildMessage(
                    TEMPLATE_DAY_START_10AM,
                    punchRecord.Id,
                    punchRecord.User__r.Email
                );
                if (mail != null) {
                    messages.add(mail);
                }
            } else if (
                activeReminderType ==
                    PunchRecordDayStartEndReminderBatch.ReminderType.DAY_START_1045 &&
                !isDayStartDone &&
                punchRecord.HOD__r.Email != null
            ) {
                Messaging.SingleEmailMessage mail = buildMessage(
                    TEMPLATE_DAY_START_1045AM,
                    punchRecord.Id,
                    punchRecord.HOD__r.Email
                );
                if (mail != null) {
                    messages.add(mail);
                }
            } else if (
                activeReminderType ==
                    PunchRecordDayStartEndReminderBatch.ReminderType.DAY_END_MIDNIGHT &&
                punchRecord.Punch_Time__c != null &&
                punchRecord.User__r.Email != null
            ) {
                Messaging.SingleEmailMessage mail = buildMessage(
                    TEMPLATE_DAY_END_MIDNIGHT,
                    punchRecord.Id,
                    punchRecord.User__r.Email
                );
                if (mail != null) {
                    messages.add(mail);
                }
            }
        }

        if (!messages.isEmpty()) {
            Messaging.sendEmail(messages);
        }
    }

    public void finish(Database.BatchableContext bc) {}

    @TestVisible
    private static ReminderType resolveReminderTypeFromScheduleTime() {
        Datetime now = System.now();
        Integer hour = now.hour();
        Integer minute = now.minute();

        if (hour == 0 && minute < 30) {
            return PunchRecordDayStartEndReminderBatch.ReminderType.DAY_END_MIDNIGHT;
        }
        if (hour == 10 && minute < 45) {
            return PunchRecordDayStartEndReminderBatch.ReminderType.DAY_START_10AM;
        }
        if (hour == 10 && minute >= 45) {
            return PunchRecordDayStartEndReminderBatch.ReminderType.DAY_START_1045;
        }
        return null;
    }

    private static Messaging.SingleEmailMessage buildMessage(
        String templateDeveloperName,
        Id punchRecordId,
        String recipientEmail
    ) {
        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null || String.isBlank(recipientEmail)) {
            return null;
        }

        Messaging.SingleEmailMessage message = Messaging.renderStoredEmailTemplate(
            templateId,
            null,
            punchRecordId
        );
        message.setToAddresses(new List<String>{ recipientEmail });
        message.setSaveAsActivity(false);
        message.setTreatTargetObjectAsRecipient(false);
        applyOrgWideSender(message);
        return message;
    }

    private static Id resolveTemplateId(String templateDeveloperName) {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :templateDeveloperName
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
        List<OrgWideEmailAddress> orgWideAddresses = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_SENDER_EMAIL
            LIMIT 1
        ];
        if (!orgWideAddresses.isEmpty()) {
            message.setOrgWideEmailAddressId(orgWideAddresses[0].Id);
        }
    }
}