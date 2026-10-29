public without sharing class MarkActivityCompleteController {

    private static final String NOTIF_TYPE_DEV_NAME = 'Activity_Assignment';
    private static final String DISPOSITION_NOT_CONNECTED = 'Not Connected';
    private static final String TASK_ACTION_CALLBACK = 'Callback';
    private static final String COMPLETED_SUFFIX = ' - Completed';

    /* ---------- wrappers ---------- */
    public class CloseContext {
        @AuraEnabled public String  objectType;                 // 'Task' or 'Event'
        @AuraEnabled public Id      parentId;
        @AuraEnabled public String  parentType;                 // 'Lead' or 'Opportunity'
        @AuraEnabled public List<Option> dispositions = new List<Option>();
        @AuraEnabled public Boolean callOpen  = false;
        @AuraEnabled public Boolean eventOpen = false;
        @AuraEnabled public Boolean visitOpen = false;
    }
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String l, String v) { label = l; value = v; }
    }
    public class UserOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }
    public class OpenFlags {
        @AuraEnabled public Boolean callOpen  = false;
        @AuraEnabled public Boolean eventOpen = false;
        @AuraEnabled public Boolean visitOpen = false;
    }

    /* =========================================================================
     *  CONTEXT for the record being closed.
     * ========================================================================= */
    @AuraEnabled(cacheable=true)
    public static CloseContext getContext(Id recordId) {
        CloseContext ctx = new CloseContext();
        Id whoId;
        Id whatId;

        if (recordId.getSObjectType() == Task.SObjectType) {
            ctx.objectType = 'Task';
            Task t = [SELECT WhoId, WhatId FROM Task WHERE Id = :recordId WITH SYSTEM_MODE];
            whoId = t.WhoId;  whatId = t.WhatId;
            ctx.dispositions.add(new Option('Connected', 'Connected'));
            ctx.dispositions.add(new Option('Not Connected', 'Not Connected'));
        } else {
            ctx.objectType = 'Event';
            Event e = [SELECT WhoId, WhatId FROM Event WHERE Id = :recordId WITH SYSTEM_MODE];
            whoId = e.WhoId;  whatId = e.WhatId;
            ctx.dispositions.add(new Option('Completed', 'Completed'));
            ctx.dispositions.add(new Option('Not Completed', 'Not Completed'));
        }

        if (whatId != null && whatId.getSObjectType() == Opportunity.SObjectType) {
            ctx.parentType = 'Opportunity';
            ctx.parentId   = whatId;
        } else if (whoId != null && whoId.getSObjectType() == Lead.SObjectType) {
            ctx.parentType = 'Lead';
            ctx.parentId   = whoId;
        }

        if (ctx.parentId != null) {
            ctx.callOpen  = hasOpenCall(ctx.parentId, ctx.parentType, null);
            ctx.eventOpen = hasOpenEvent(ctx.parentId, ctx.parentType, null);
            ctx.visitOpen = hasOpenVisit(ctx.parentId, ctx.parentType, null);
        }
        return ctx;
    }

    /* =========================================================================
     *  MARK COMPLETE. Called AFTER a follow-up is created (deferred close).
     *  Event 'Not Completed' does not require/record Actual Start/End.
     *
     *  Both  : Subject gets ' - Completed' appended (once; never past 255 chars).
     *  Event : the scheduled StartDateTime/EndDateTime are preserved in
     *          Actual_Start_Time__c/Actual_End_Time__c, and the Actual Start/End
     *          captured on the UI are written to StartDateTime/EndDateTime so the
     *          calendar shows when the meeting really happened.
     *          Deepanjan (8th September 2026)
     * ========================================================================= */
    @AuraEnabled
    public static OpenFlags markComplete(Id recordId, String objectType,
                                         String disposition, String remarks,
                                         Datetime actualStart, Datetime actualEnd,
                                         Id parentId, String parentType) {
        if (String.isBlank(disposition) || String.isBlank(remarks)) {
            throw handled('Disposition and Remarks are both required.');
        }
        if (objectType == 'Task') {
            try {
                List<Task> rows = [
                    SELECT Subject FROM Task WHERE Id = :recordId WITH SYSTEM_MODE LIMIT 1
                ];
                if (rows.isEmpty()) {
                    throw handled('The Call could not be found.');
                }
                new ElevatedDml().doUpdate(
                    new Task(Id = recordId, Status = 'Completed',
                             Subject        = withCompletedSuffix(rows[0].Subject),
                             Disposition__c = disposition, Description = remarks));
            } catch (AuraHandledException ahe) {
                throw ahe;
            } catch (DmlException dmlErr) {
                throw dmlFailure('The Call could not be marked complete', dmlErr);
            } catch (Exception otherErr) {
                throw unexpected('The Call could not be marked complete', otherErr);
            }
        } else {
            List<Event> rows = [
                SELECT Subject, StartDateTime, EndDateTime
                FROM Event WHERE Id = :recordId WITH SYSTEM_MODE LIMIT 1
            ];
            if (rows.isEmpty()) {
                throw handled('The Event could not be found.');
            }
            Event ev = new Event(Id = recordId,
                                 Subject        = withCompletedSuffix(rows[0].Subject),
                                 Disposition__c = disposition,
                                 Description    = remarks,
                                 Close_Date__c  = Datetime.now());
            // Scheduled window -> Actual_* fields, whatever the disposition.
            ev.Actual_Start_Time__c = rows[0].StartDateTime;
            ev.Actual_End_Time__c   = rows[0].EndDateTime;

            if (disposition != 'Not Completed') {
                if (actualStart == null || actualEnd == null) {
                    throw handled('Actual Start Date and Actual End Date are required.');
                }
                if (actualStart > Datetime.now() || actualEnd > Datetime.now()) {
                    throw handled('Actual Start/End Date cannot be in the future.');
                }
                if (actualEnd <= actualStart) {
                    throw handled('Actual End Date must be after Actual Start Date.');
                }
                // UI-captured actuals -> the Event's own Start/End.
                ev.StartDateTime = actualStart;
                ev.EndDateTime   = actualEnd;
            }
            try {
                new ElevatedDml().doUpdate(ev);
            } catch (DmlException dmlErr) {
                throw dmlFailure('The Event could not be marked complete', dmlErr);
            } catch (Exception otherErr) {
                throw unexpected('The Event could not be marked complete', otherErr);
            }
        }
        maybeQueueOpportunityNotConnectedCallbacks(
            recordId,
            objectType,
            disposition,
            parentId,
            parentType
        );
        return getOpenFlags(parentId, parentType, null);
    }

    /* Appends ' - Completed' exactly once and keeps the result inside the Subject
       field length. Package-visible so the test class can cover the edge cases.
       Deepanjan (8th September 2026) */
    @TestVisible
    private static String withCompletedSuffix(String subject) {
        String base = String.isBlank(subject) ? '' : subject.trim();
        if (base.endsWith(COMPLETED_SUFFIX)) {
            return base;
        }
        Integer maxLen = Task.Subject.getDescribe().getLength();
        if (base.length() + COMPLETED_SUFFIX.length() > maxLen) {
            base = base.substring(0, maxLen - COMPLETED_SUFFIX.length()).trim();
        }
        return base + COMPLETED_SUFFIX;
    }

    /**
     * Mirrors Flow Task: Opportunity Task Completion -> Should_Send_Not_Connected_Email.
     * Template selection (dept vs gen) is handled by BWM_EmailTemplateResolver:
     *   Negotiation + product dept -> Negotiation_not_responding_dept
     *   Negotiation + enquiry/tower -> Negotiation_not_responding_gen
     *   Nurture + product dept -> Nurture_not_responding_dept
     *   Nurture + enquiry/tower -> Nurture_not_responding_gen
     */
    private static void maybeQueueOpportunityNotConnectedCallbacks(
        Id recordId,
        String objectType,
        String disposition,
        Id parentId,
        String parentType
    ) {
        if (
            objectType != 'Task' ||
            parentType != 'Opportunity' ||
            parentId == null ||
            disposition != DISPOSITION_NOT_CONNECTED
        ) {
            return;
        }

        List<Task> tasks = [
            SELECT TaskSubtype, WhatId
            FROM Task
            WHERE Id = :recordId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (tasks.isEmpty() || tasks[0].TaskSubtype != 'Call' || tasks[0].WhatId != parentId) {
            return;
        }

        List<Opportunity> opportunities = [
            SELECT StageName
            FROM Opportunity
            WHERE Id = :parentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (opportunities.isEmpty()) {
            return;
        }

        String stageName = opportunities[0].StageName;
        if (
            stageName != BWM_EmailConstants.STAGE_NURTURE &&
            stageName != BWM_EmailConstants.STAGE_NEGOTIATION
        ) {
            return;
        }

        BWM_SendTaskEmailInvocable.Request emailRequest = new BWM_SendTaskEmailInvocable.Request();
        emailRequest.recordId = parentId;
        emailRequest.taskAction = TASK_ACTION_CALLBACK;
        emailRequest.stageAtAction = stageName;
        BWM_SendTaskEmailInvocable.sendTaskEmail(
            new List<BWM_SendTaskEmailInvocable.Request>{ emailRequest }
        );

        if (
            stageName == BWM_EmailConstants.STAGE_NURTURE ||
            stageName == BWM_EmailConstants.STAGE_NEGOTIATION
        ) {
            BWM_SendTaskMessageInvocable.Request messageRequest = new BWM_SendTaskMessageInvocable.Request();
            messageRequest.recordId = parentId;
            messageRequest.taskAction = TASK_ACTION_CALLBACK;
            messageRequest.stageAtAction = stageName;
            BWM_SendTaskMessageInvocable.sendTaskMessage(
                new List<BWM_SendTaskMessageInvocable.Request>{ messageRequest }
            );
        }
    }

    /* =========================================================================
     *  OPEN status on the parent. excludeId lets the caller ignore the record
     *  that is about to be closed (still open during the deferred flow).
     * ========================================================================= */
    @AuraEnabled
    public static OpenFlags getOpenFlags(Id parentId, String parentType, Id excludeId) {
        OpenFlags f = new OpenFlags();
        if (parentId == null) {
            return f;
        }
        f.callOpen  = hasOpenCall(parentId, parentType, excludeId);
        f.eventOpen = hasOpenEvent(parentId, parentType, excludeId);
        f.visitOpen = hasOpenVisit(parentId, parentType, excludeId);
        return f;
    }

    /* =========================================================================
     *  ASSIGNABLE USERS
     *
     *  Always driven by the related Opportunity's Department_Name__c, whatever
     *  the running user's profile or Departments__c happens to be:
     *    - the Opportunity is resolved server-side from the Task/Event being closed
     *    - active users are matched on User.Department (CONTAINS) OR
     *      User.Departments__c (INCLUDES)
     *    - a multi-value Department_Name__c is split on ';' and every part matched
     *    - the running user is always first in the list, never duplicated
     * ========================================================================= */
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getAssignableUsers(Id activityId) {
        Id runningUserId = UserInfo.getUserId();
        User me = runningUser(runningUserId);

        List<UserOption> options = new List<UserOption>();
        Set<Id> seen = new Set<Id>();

        options.add(toOption(me));
        seen.add(me.Id);

        List<String> wanted = splitDepartments(departmentForActivity(activityId));
        if (!wanted.isEmpty()) {
            for (User u : (List<User>) Database.query(buildDepartmentMatchSoql(wanted))) {
                if (!seen.contains(u.Id)) {
                    options.add(toOption(u));
                    seen.add(u.Id);
                }
            }
        }
        return options;
    }

    private static User runningUser(Id userId) {
        return [
            SELECT Id, Name
            FROM User
            WHERE Id = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }

    // Resolves the department from the activity itself, so the component never has
    // to pass a parent that may not be loaded yet. Accepts a Task Id, an Event Id,
    // or an Opportunity Id.
    private static String departmentForActivity(Id activityId) {
        if (activityId == null) {
            return null;
        }
        Schema.SObjectType t = activityId.getSObjectType();
        Id whatId;
        if (t == Opportunity.SObjectType) {
            whatId = activityId;
        } else if (t == Task.SObjectType) {
            List<Task> rows = [SELECT WhatId FROM Task WHERE Id = :activityId WITH SYSTEM_MODE LIMIT 1];
            whatId = rows.isEmpty() ? null : rows[0].WhatId;
        } else if (t == Event.SObjectType) {
            List<Event> rows = [SELECT WhatId FROM Event WHERE Id = :activityId WITH SYSTEM_MODE LIMIT 1];
            whatId = rows.isEmpty() ? null : rows[0].WhatId;
        }
        return opportunityDepartment(whatId);
    }

    private static String opportunityDepartment(Id parentId) {
        if (parentId == null || parentId.getSObjectType() != Opportunity.SObjectType) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Department_Name__c
            FROM Opportunity
            WHERE Id = :parentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].Department_Name__c;
    }

    private static List<String> splitDepartments(String multi) {
        List<String> result = new List<String>();
        if (String.isNotBlank(multi)) {
            for (String d : multi.split(';')) {
                if (String.isNotBlank(d)) { result.add(d.trim()); }
            }
        }
        return result;
    }

    // Matches the Opportunity department against BOTH user department fields:
    //   - standard User.Department  -> CONTAINS (LIKE %value%)
    //   - custom  User.Departments__c (multi-select) -> INCLUDES
    // Orgs populate one or the other, so both legs are OR'd together.
    private static String buildDepartmentMatchSoql(List<String> departments) {
        List<String> conditions = new List<String>();
        for (String dept : departments) {
            String safe = String.escapeSingleQuotes(dept);
            conditions.add('Department LIKE \'%' + safe + '%\'');
            conditions.add('Departments__c INCLUDES (\'' + safe + '\')');
        }
        return 'SELECT Id, Name FROM User '
             + 'WHERE IsActive = true '
             + 'AND (' + String.join(conditions, ' OR ') + ') WITH SYSTEM_MODE ORDER BY Name';
    }

    private static UserOption toOption(User u) {
        UserOption o = new UserOption();
        o.id = u.Id;  o.name = u.Name;
        return o;
    }

    /* =========================================================================
     *  OPEN checks (parent may be a Lead or an Opportunity). excludeId optional.
     * ========================================================================= */
    private static Boolean hasOpenCall(Id parentId, String parentType, Id excludeId) {
        String f = (parentType == 'Opportunity') ? 'WhatId' : 'WhoId';
        String soql = 'SELECT COUNT() FROM Task WHERE ' + f + ' = :parentId '
            + 'AND TaskSubtype = \'Call\' AND Status = \'Open\' ';
        if (excludeId != null) { soql += 'AND Id != :excludeId '; }
        soql += 'WITH SYSTEM_MODE';
        return Database.countQuery(soql) > 0;
    }

    private static Boolean hasOpenEvent(Id parentId, String parentType, Id excludeId) {
        String f = (parentType == 'Opportunity') ? 'WhatId' : 'WhoId';
        Datetime nowDt = Datetime.now();
        String soql = 'SELECT COUNT() FROM Event WHERE ' + f + ' = :parentId '
            + 'AND (Disposition__c = null OR Disposition__c NOT IN (\'Completed\',\'Not Completed\')) '
            + 'AND StartDateTime >= :nowDt AND (EndDateTime >= :nowDt OR EndDateTime = null) ';
        if (excludeId != null) { soql += 'AND Id != :excludeId '; }
        soql += 'WITH SYSTEM_MODE';
        return Database.countQuery(soql) > 0;
    }

    private static Boolean hasOpenVisit(Id parentId, String parentType, Id excludeId) {
        String f = (parentType == 'Opportunity') ? 'Opportunity__c' : 'Lead__c';
        String soql = 'SELECT COUNT() FROM Task_Log__c WHERE ' + f + ' = :parentId '
            + 'AND Is_schedule__c = true AND Logged_At__c = null ';
        if (excludeId != null) { soql += 'AND Id != :excludeId '; }
        soql += 'WITH SYSTEM_MODE';
        return Database.countQuery(soql) > 0;
    }

    /* =========================================================================
     *  CREATE follow-up activities against the same parent.
     *  excludeId ignores the still-open record being closed in the block check.
     * ========================================================================= */
    @AuraEnabled
    public static Id createCall(Id parentId, String parentType, String subject,
                                Datetime followUp, String comments, Id assignedToId, Id excludeId) {
        if (hasOpenCall(parentId, parentType, excludeId)) {
            throw handled('An open Call already exists.');
        }
        if (followUp != null && followUp < Datetime.now()) {
            throw handled('Follow-up Call date/time cannot be in the past.');
        }
        Task t = new Task();
        setActivityParent(t, parentId, parentType);
        t.TaskSubtype            = 'Call';
        t.Subject                = subject;
        t.Status                 = 'Open';
        t.Manually_Created__c    = true;
        t.Follow_Up_Date_Time__c = followUp;
        if (followUp != null) { t.ActivityDate = followUp.date(); }
        t.Description = comments;
        if (assignedToId != null) { t.OwnerId = assignedToId; }
        try {
            new ElevatedDml().doInsert(t);
        } catch (DmlException dmlErr) {
            throw dmlFailure('The Call could not be created', dmlErr);
        } catch (Exception otherErr) {
            throw unexpected('The Call could not be created', otherErr);
        }
        return t.Id;
    }

    @AuraEnabled
    public static Id createEvent(Id parentId, String parentType, String subject, String comments,
                                 Datetime startDt, Datetime endDt, Id assignedToId, Id excludeId) {
        if (hasOpenEvent(parentId, parentType, excludeId)) {
            throw handled('An open Event already exists.');
        }
        if (startDt != null && startDt < Datetime.now()) {
            throw handled('Event start cannot be in the past.');
        }
        Event e = new Event();
        setActivityParent(e, parentId, parentType);
        e.Subject       = subject;
        e.Description   = comments;
        e.StartDateTime = startDt;
        e.EndDateTime   = endDt;
        e.Type          = 'Meeting';
        e.IsReminderSet = true;
        if (startDt != null) { e.ReminderDateTime = startDt.addMinutes(-15); }
        if (assignedToId != null) { e.OwnerId = assignedToId; }
        try {
            new ElevatedDml().doInsert(e);
        } catch (DmlException dmlErr) {
            throw dmlFailure('The Event could not be created', dmlErr);
        } catch (Exception otherErr) {
            throw unexpected('The Event could not be created', otherErr);
        }
        notifyOwner(effectiveOwner(assignedToId), e.Id, 'New Event assigned',
            String.isBlank(subject) ? 'An event has been assigned to you.' : subject);
        return e.Id;
    }

    @AuraEnabled
    public static Id createVisit(Id parentId, String parentType, String visitType,
                                 String reason, Date scheduleDate, Id assignedToId, Id excludeId) {
        if (hasOpenVisit(parentId, parentType, excludeId)) {
            throw handled('An open Visit already exists.');
        }
        if (scheduleDate != null && scheduleDate < Date.today()) {
            throw handled('Visit Schedule Date cannot be in the past.');
        }
        Task_Log__c v = new Task_Log__c();
        v.put((parentType == 'Opportunity') ? 'Opportunity__c' : 'Lead__c', parentId);
        v.Visit_Type__c       = visitType;
        v.Reason_for_Visit__c = reason;
        v.Schedule_Date__c    = scheduleDate;
        v.Is_schedule__c      = true;
        v.Manually_Created__c = true;
        if (assignedToId != null) { v.OwnerId = assignedToId; }
        try {
            new ElevatedDml().doInsert(v);
        } catch (DmlException dmlErr) {
            throw dmlFailure('The Visit could not be created', dmlErr);
        } catch (Exception otherErr) {
            throw unexpected('The Visit could not be created', otherErr);
        }
        String body = String.isBlank(visitType) ? 'A visit has been assigned to you.'
                                                 : 'Visit (' + visitType + ') has been assigned to you.';
        notifyOwner(effectiveOwner(assignedToId), v.Id, 'New Visit assigned', body);
        return v.Id;
    }

    private static void setActivityParent(SObject activity, Id parentId, String parentType) {
        if (parentType == 'Opportunity') {
            activity.put('WhatId', parentId);
        } else {
            activity.put('WhoId', parentId);
        }
    }

    /* ---- notification (non-blocking) ---- */
    private static Id effectiveOwner(Id assignedToId) {
        return assignedToId != null ? assignedToId : UserInfo.getUserId();
    }

    private static void notifyOwner(Id ownerId, Id targetRecordId, String title, String body) {
        if (ownerId == null) { return; }
        Id typeId = notificationTypeId();
        if (typeId == null) { return; }
        try {
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setTitle(title);
            n.setBody(body);
            n.setNotificationTypeId(typeId);
            n.setTargetId(targetRecordId);
            n.send(new Set<String>{ String.valueOf(ownerId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Owner notification failed: ' + e.getMessage());
        }
    }

    private static Id cachedNotifTypeId;
    private static Boolean notifTypeResolved = false;
    private static Id notificationTypeId() {
        if (!notifTypeResolved) {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIF_TYPE_DEV_NAME WITH SYSTEM_MODE LIMIT 1
            ];
            cachedNotifTypeId = types.isEmpty() ? null : types[0].Id;
            notifTypeResolved = true;
        }
        return cachedNotifTypeId;
    }

    /* EVERY DML in this class runs elevated. Two different things are being bypassed and they
       are NOT the same:

         - "as system"       -> ignores field level security and object CRUD. Needs API 55+.
         - "without sharing" -> ignores RECORD level sharing. A sharing keyword cannot sit on a
                                static method, so it has to be an inner class.

       Why both: closing an activity was failing with INSUFFICIENT_ACCESS_OR_READONLY after the
       follow-up had already been inserted - the "record created but error shown" case. Creating
       an activity only needs READ on the parent; editing one needs Edit or ownership. "as system"
       alone would not have fixed it, because what blocked the update was sharing, not FLS.

       Every SOQL in this class already reads WITH SYSTEM_MODE, so reads and writes now behave the
       same way. Deepanjan (17th August 2026) */
    private without sharing class ElevatedDml {
        void doInsert(SObject rec) {
            insert as system rec;
        }
        void doUpdate(SObject rec) {
            update as system rec;
        }
    }

    /* A raw DmlException reaches the LWC with its text in body.pageErrors / body.fieldErrors,
       never in body.message - which is why the browser only ever showed 'Unexpected error'.
       Re-throwing it as an AuraHandledException puts the real reason in body.message, where
       the component can read it. Every validation rule, required field and trigger message
       is preserved, with the field names that failed. Deepanjan (17th August 2026) */
    private static AuraHandledException dmlFailure(String action, DmlException e) {
        List<String> reasons = new List<String>();
        for (Integer i = 0; i < e.getNumDml(); i++) {
            String fields = '';
            List<String> names = e.getDmlFieldNames(i);
            if (names != null && !names.isEmpty()) {
                fields = ' [' + String.join(names, ', ') + ']';
            }
            reasons.add(e.getDmlMessage(i) + fields);
        }
        String detail = reasons.isEmpty() ? e.getMessage() : String.join(reasons, ' | ');
        return handled(action + ': ' + detail);
    }

    /* Same idea for anything that is not a DML failure - a query, a limit, a null. Without
       this the LWC gets 'An internal server error has occurred' with no clue where.
       Deepanjan (17th August 2026) */
    private static AuraHandledException unexpected(String action, Exception e) {
        return handled(action + ': ' + e.getTypeName() + ' - ' + e.getMessage()
                       + ' (line ' + e.getLineNumber() + ')');
    }

    private static AuraHandledException handled(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }
}