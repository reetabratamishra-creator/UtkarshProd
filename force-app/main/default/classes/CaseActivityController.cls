/**
 * Controller for the caseActivityLauncher quick action on Case.
 *
 * Creates either:
 *   - a Call Task  (TaskSubtype = Call, Priority = Normal, Status = Open)
 *   - a Meeting Event (Type = Meeting, reminder 15 minutes before start)
 *
 * Both records are always owned by the CASE OWNER - there is no assignee picker.
 *
 * Runs `without sharing` deliberately: the running user may not have access to
 * the owner record or to the Case itself under sharing. All SOQL runs
 * WITH SYSTEM_MODE and all DML runs with AccessLevel.SYSTEM_MODE so reads and
 * writes behave alike.
 *
 * NOTE: `WITH SYSTEM_MODE` and `AccessLevel` need apiVersion >= 55.0 in the
 * .cls-meta.xml or this will not compile.
 * 
 * test class: CaseActivityControllerTest
 */
public without sharing class CaseActivityController {

    private static final Integer SUBJECT_MAX  = 255;
    private static final Integer DESC_MAX     = 32000;
    private static final Integer REMINDER_MIN = 15;

    /* =====================================================================
     *  Wrapper
     * ===================================================================== */
    public class CaseContext {
        @AuraEnabled public Id      caseId;
        @AuraEnabled public String  caseNumber;
        @AuraEnabled public String  caseSubject;
        @AuraEnabled public Id      ownerId;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public Boolean ownerIsQueue;
    }

    /* =====================================================================
     *  Read
     * ===================================================================== */
    @AuraEnabled(cacheable=true)
    public static CaseContext getCaseContext(Id caseId) {
        Case c = fetchCase(caseId);

        CaseContext ctx  = new CaseContext();
        ctx.caseId       = c.Id;
        ctx.caseNumber   = c.CaseNumber;
        ctx.caseSubject  = c.Subject;
        ctx.ownerId      = c.OwnerId;
        ctx.ownerName    = c.Owner.Name;
        ctx.ownerIsQueue = !isUserId(c.OwnerId);
        return ctx;
    }

    /* =====================================================================
     *  Call Task
     * ===================================================================== */
    @AuraEnabled
    public static Id createCallTask(Id caseId, String subject, Datetime followUpDateTime, String comments) {

        Case c     = fetchCase(caseId);
        Id ownerId = resolveOwner(c);

        subject = safeTrim(subject);
        if (String.isBlank(subject)) {
            throw error('Subject is required.');
        }
        if (followUpDateTime == null) {
            throw error('Date & Time is required.');
        }
        if (followUpDateTime.date() < Date.today()) {
            throw error('Date & Time cannot be in the past.');
        }

        Task t                   = new Task();
        t.WhatId                 = c.Id;
        t.WhoId                  = c.ContactId;             // null-safe
        t.OwnerId                = ownerId;
        t.Subject                = truncate(subject, SUBJECT_MAX);
        t.Description            = truncate(safeTrim(comments), DESC_MAX);
        t.TaskSubtype            = 'Call';
        t.Priority               = 'Normal';
        t.Status                 = 'Open';
        t.Follow_Up_Date_Time__c = followUpDateTime;        // full date + time
        t.ActivityDate           = followUpDateTime.date(); // standard Due Date

        saveRecord(t, 'Call Task');
        return t.Id;
    }

    /* =====================================================================
     *  Meeting Event
     * ===================================================================== */
    @AuraEnabled
    public static Id createMeetingEvent(Id caseId, String subject, Datetime startDateTime,
                                        Datetime endDateTime, String comments) {

        Case c     = fetchCase(caseId);
        Id ownerId = resolveOwner(c);

        subject = safeTrim(subject);
        if (String.isBlank(subject)) {
            throw error('Subject is required.');
        }
        if (startDateTime == null) {
            throw error('Start Date & Time is required.');
        }
        if (startDateTime.date() < Date.today()) {
            throw error('Start Date & Time cannot be in the past.');
        }
        if (endDateTime == null) {
            throw error('End Date & Time is required.');
        }
        if (endDateTime <= startDateTime) {
            throw error('End Date & Time must be later than the Start Date & Time.');
        }

        Event e         = new Event();
        e.WhatId        = c.Id;
        e.WhoId         = c.ContactId;
        e.OwnerId       = ownerId;
        e.Subject       = truncate(subject, SUBJECT_MAX);
        e.Description   = truncate(safeTrim(comments), DESC_MAX);
        e.Type          = 'Meeting';
        e.IsAllDayEvent = false;
        e.StartDateTime = startDateTime;
        e.EndDateTime   = endDateTime;   // do NOT also set DurationInMinutes

        Datetime remindAt = startDateTime.addMinutes(-REMINDER_MIN);
        if (remindAt > System.now()) {
            e.IsReminderSet    = true;
            e.ReminderDateTime = remindAt;
        }

        saveRecord(e, 'Event');
        return e.Id;
    }

    /* =====================================================================
     *  Helpers
     * ===================================================================== */
    private static Case fetchCase(Id caseId) {
        if (caseId == null) {
            throw error('No Case record was supplied.');
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, OwnerId, Owner.Name, ContactId, IsClosed
            FROM Case
            WHERE Id = :caseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw error('This Case could not be found. It may have been deleted.');
        }
        return cases[0];
    }

    /**
     * Activities cannot be owned by a queue, so a queue-owned Case is a hard stop.
     */
    private static Id resolveOwner(Case c) {
        if (isUserId(c.OwnerId)) {
            return c.OwnerId;
        }
        throw error('This Case is owned by the queue "' + c.Owner.Name +
                    '". An activity can only be assigned to a user, so please accept ' +
                    'ownership of the Case first.');
    }

    private static Boolean isUserId(Id recordId) {
        return recordId != null && recordId.getSObjectType() == User.SObjectType;
    }

    private static void saveRecord(SObject rec, String label) {
        try {
            Database.insert(rec, true, AccessLevel.SYSTEM_MODE);
        } catch (DmlException de) {
            throw error(dmlMessage(de, label));
        } catch (Exception ex) {
            throw error('The ' + label + ' could not be created: ' +
                        ex.getTypeName() + ' - ' + ex.getMessage() +
                        ' (line ' + ex.getLineNumber() + ')');
        }
    }

    private static String dmlMessage(DmlException de, String label) {
        List<String> parts = new List<String>();
        for (Integer i = 0; i < de.getNumDml(); i++) {
            String msg = de.getDmlMessage(i);
            List<String> fields = de.getDmlFieldNames(i);
            if (fields != null && !fields.isEmpty()) {
                msg += ' [' + String.join(fields, ', ') + ']';
            }
            parts.add(msg);
        }
        if (parts.isEmpty()) {
            parts.add(de.getMessage());
        }
        return 'The ' + label + ' could not be created: ' + String.join(parts, ' | ');
    }

    private static String safeTrim(String value) {
        return value == null ? null : value.trim();
    }

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }

    /** setMessage() is required, otherwise the LWC only sees "Script-thrown exception". */
    private static AuraHandledException error(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}