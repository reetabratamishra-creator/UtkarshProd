/*public without sharing class OpportunityActivityLauncherController {

    // Task_Log__c (Visit) lookup to Opportunity — adjust if named differently.
    private static final String TASKLOG_OPP_FIELD = 'Opportunity__c';

    private static final Set<String> ADMIN_PROFILES =
        new Set<String>{ 'Utkarsh Admin', 'System Administrator' };

    public class OpenStatus {
        @AuraEnabled public Boolean callOpen  = false;
        @AuraEnabled public Boolean eventOpen = false;
        @AuraEnabled public Boolean visitOpen = false;
    }

    public class UserOption {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static OpenStatus getOpenStatus(Id opportunityId) {
        OpenStatus s = new OpenStatus();
        s.callOpen  = hasOpenCall(opportunityId);
        s.eventOpen = hasOpenEvent(opportunityId);
        s.visitOpen = hasOpenVisit(opportunityId);
        return s;
    }

    // =========================================================================
     //  READ:  assignable users.
     //
     //  Rule 1 (default): active users whose Departments__c matches any of the
     //          running user's Departments__c, excluding admin profiles.
     //
     //  Rule 2 (fallback): if the running user has NO Departments__c, OR the
    //          running user's profile is 'System Administrator' / 'Utkarsh Admin',
     //         then list active users whose standard User.Department equals the
     //         Opportunity's Department_Name__c.
     //
     //  The running user is always included so they can be defaulted in the picker.
     // ========================================================================= 
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getAssignableUsers(Id opportunityId) {
        List<UserOption> options = new List<UserOption>();

        Id runningUserId = UserInfo.getUserId();
        User me = runningUser(runningUserId);

        List<String> depts   = splitDepartments(me.Departments__c);
        Boolean      isAdmin = me.Profile != null
                            && me.Profile.Name != null
                            && ADMIN_PROFILES.contains(me.Profile.Name);

        List<User> users = new List<User>();

        if (isAdmin || depts.isEmpty()) {
            String oppDept = opportunityDepartment(opportunityId);
            if (String.isNotBlank(oppDept)) {
                users = [
                    SELECT Id, Name
                    FROM User
                    WHERE IsActive = true
                      AND Department = :oppDept
                    WITH SYSTEM_MODE
                    ORDER BY Name
                ];
            }
        } else {
            users = (List<User>) Database.query(buildIncludesSoql(depts));
        }

        Boolean runningIncluded = false;
        for (User u : users) {
            options.add(toOption(u));
            if (u.Id == runningUserId) {
                runningIncluded = true;
            }
        }
        if (!runningIncluded) {
            options.add(0, toOption(me));
        }
        return options;
    }

    private static User runningUser(Id userId) {
        return [
            SELECT Id, Name, Department, Departments__c, Profile.Name
            FROM User
            WHERE Id = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }

    private static String opportunityDepartment(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Department_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].Department_Name__c;
    }

    private static List<String> splitDepartments(String multi) {
        List<String> result = new List<String>();
        if (String.isNotBlank(multi)) {
            for (String d : multi.split(';')) {
                if (String.isNotBlank(d)) {
                    result.add(d.trim());
                }
            }
        }
        return result;
    }

    private static String buildIncludesSoql(List<String> departments) {
        List<String> conditions = new List<String>();
        for (String dept : departments) {
            conditions.add('Departments__c INCLUDES (\'' + String.escapeSingleQuotes(dept) + '\')');
        }
        return 'SELECT Id, Name FROM User '
             + 'WHERE IsActive = true '
             + 'AND Profile.Name NOT IN (\'Utkarsh Admin\', \'System Administrator\') '
             + 'AND (' + String.join(conditions, ' OR ') + ') WITH SYSTEM_MODE ORDER BY Name';
    }

    private static UserOption toOption(User u) {
        UserOption opt = new UserOption();
        opt.id   = u.Id;
        opt.name = u.Name;
        return opt;
    }

    // ---- OPEN definitions (per category, for this Opportunity) ---- 
    private static Boolean hasOpenCall(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :opportunityId
              AND TaskSubtype = 'Call'
              AND Status = 'Open'
            WITH SYSTEM_MODE
        ] > 0;
    }

    private static Boolean hasOpenEvent(Id opportunityId) {
        Datetime nowDt = Datetime.now();
        return [
            SELECT COUNT()
            FROM Event
            WHERE WhatId = :opportunityId
              AND (Disposition__c = null
                   OR Disposition__c NOT IN ('Completed', 'Not Completed'))
              AND StartDateTime >= :nowDt
              AND (EndDateTime >= :nowDt OR EndDateTime = null)
            WITH SYSTEM_MODE
        ] > 0;
    }

    private static Boolean hasOpenVisit(Id opportunityId) {
        // COUNT() queries must use Database.countQuery(), not Database.query().
        return Database.countQuery(
            'SELECT COUNT() FROM Task_Log__c '
          + 'WHERE ' + TASKLOG_OPP_FIELD + ' = :opportunityId '
          + 'AND Is_schedule__c = true AND Logged_At__c = null '
          + 'WITH SYSTEM_MODE'
        ) > 0;
    }

    // ---- CREATE: Call ---- 
    @AuraEnabled
    public static Id createCall(Id opportunityId, String subject, Datetime followUp,
                                String comments, Id assignedToId) {
        if (hasOpenCall(opportunityId)) {
            throw handled('An open Call already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (followUp != null && followUp < Datetime.now()) {
            throw handled('Follow-up Call date/time cannot be in the past.');
        }
        Task t = new Task();
        t.WhatId                 = opportunityId;
        t.TaskSubtype            = 'Call';
        t.Subject                = subject;
        t.Status                 = 'Open';
        t.Manually_Created__c    = true;
        t.Follow_Up_Date_Time__c = followUp;
        if (followUp != null) {
            t.ActivityDate = followUp.date();
        }
        t.Description = comments;
        if (assignedToId != null) {
            t.OwnerId = assignedToId;
        }
        insert t;
        return t.Id;
    }

    // ---- CREATE: Event ---- 
    @AuraEnabled
    public static Id createEvent(Id opportunityId, String subject, String comments,
                                 Datetime startDt, Datetime endDt, Id assignedToId) {
        if (hasOpenEvent(opportunityId)) {
            throw handled('An open Event already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (startDt != null && startDt < Datetime.now()) {
            throw handled('Event start cannot be in the past.');
        }
        Event e = new Event();
        e.WhatId        = opportunityId;
        e.Subject       = subject;
        e.Description   = comments;
        e.StartDateTime = startDt;
        e.EndDateTime   = endDt;
        e.Type          = 'Meeting';
        e.IsReminderSet = true;
        if (startDt != null) {
            e.ReminderDateTime = startDt.addMinutes(-15);
        }
        if (assignedToId != null) {
            e.OwnerId = assignedToId;
        }
        insert e;

        notifyOwner(effectiveOwner(assignedToId), e.Id,
            'New Event assigned',
            String.isBlank(subject) ? 'An event has been assigned to you.' : subject);
        return e.Id;
    }

    // ---- CREATE: Visit ---- 
    @AuraEnabled
    public static Id createVisit(Id opportunityId, String visitType, String reason,
                                 Date scheduleDate, Id assignedToId) {
        if (hasOpenVisit(opportunityId)) {
            throw handled('An open Visit already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (scheduleDate != null && scheduleDate < Date.today()) {
            throw handled('Visit Schedule Date cannot be in the past.');
        }
        Task_Log__c v = new Task_Log__c();
        v.put(TASKLOG_OPP_FIELD, opportunityId);
        v.Visit_Type__c       = visitType;
        v.Reason_for_Visit__c = reason;
        v.Schedule_Date__c    = scheduleDate;
        v.Is_schedule__c      = true;
        v.Manually_Created__c = true;
        if (assignedToId != null) {
            v.OwnerId = assignedToId;
        }
        insert v;

        String body = 'A visit has been assigned to you.';
        if (String.isNotBlank(visitType)) {
            body = 'Visit (' + visitType + ') has been assigned to you.';
        }
        notifyOwner(effectiveOwner(assignedToId), v.Id, 'New Visit assigned', body);
        return v.Id;
    }

    // ---- push / custom notification to the owner (non-blocking) ---- 
    private static Id effectiveOwner(Id assignedToId) {
        return assignedToId != null ? assignedToId : UserInfo.getUserId();
    }

    private static void notifyOwner(Id ownerId, Id targetRecordId, String title, String body) {
        if (ownerId == null) {
            return;
        }
        Id typeId = notificationTypeId();
        if (typeId == null) {
            return;
        }
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(targetRecordId);
            notification.send(new Set<String>{ String.valueOf(ownerId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Owner notification failed: ' + e.getMessage());
        }
    }

    // CustomNotificationType is NOT queryable via standard SOQL, so its Id is
    // hardcoded. Get it once from Developer Console (Query Editor -> check
    // "Use Tooling API"):  SELECT Id, DeveloperName FROM CustomNotificationType
    // then paste the Id below. Leave blank to disable notifications (no error).
    private static final String NOTIF_TYPE_ID = '';
    private static Id notificationTypeId() {
        return String.isBlank(NOTIF_TYPE_ID) ? null : (Id) NOTIF_TYPE_ID;
    }

    private static AuraHandledException handled(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }
}*/
public without sharing class OpportunityActivityLauncherController {

    // Task_Log__c (Visit) lookup to Opportunity — adjust if named differently.
    private static final String TASKLOG_OPP_FIELD = 'Opportunity__c';

    private static final Set<String> ADMIN_PROFILES =
        new Set<String>{ 'Utkarsh Admin', 'System Administrator' };

    public class OpenStatus {
        @AuraEnabled public Boolean callOpen  = false;
        @AuraEnabled public Boolean eventOpen = false;
        @AuraEnabled public Boolean visitOpen = false;
    }

    public class UserOption {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static OpenStatus getOpenStatus(Id opportunityId) {
        OpenStatus s = new OpenStatus();
        s.callOpen  = hasOpenCall(opportunityId);
        s.eventOpen = hasOpenEvent(opportunityId);
        s.visitOpen = hasOpenVisit(opportunityId);
        return s;
    }

    /* =========================================================================
     *  READ:  assignable users.
     *
     *  Rule 1 (default): active users whose Departments__c matches any of the
     *          running user's Departments__c, excluding admin profiles.
     *
     *  Rule 2 (fallback): if the running user has NO Departments__c, OR the
     *          running user's profile is 'System Administrator' / 'Utkarsh Admin',
     *          then list active users whose standard User.Department equals the
     *          Opportunity's Department_Name__c.
     *
     *  The running user is always included so they can be defaulted in the picker.
     * ========================================================================= */
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getAssignableUsers(Id opportunityId) {
        List<UserOption> options = new List<UserOption>();

        Id runningUserId = UserInfo.getUserId();
        User me = runningUser(runningUserId);

        List<String> depts   = splitDepartments(me.Departments__c);
        Boolean      isAdmin = me.Profile != null
                            && me.Profile.Name != null
                            && ADMIN_PROFILES.contains(me.Profile.Name);

        List<User> users = new List<User>();

        if (isAdmin || depts.isEmpty()) {
            String oppDept = opportunityDepartment(opportunityId);
            if (String.isNotBlank(oppDept)) {
                users = [
                    SELECT Id, Name
                    FROM User
                    WHERE IsActive = true
                      AND Department = :oppDept
                    WITH SYSTEM_MODE
                    ORDER BY Name
                ];
            }
        } else {
            users = (List<User>) Database.query(buildIncludesSoql(depts));
        }

        Boolean runningIncluded = false;
        for (User u : users) {
            options.add(toOption(u));
            if (u.Id == runningUserId) {
                runningIncluded = true;
            }
        }

        // FIX: List.add(0, element) throws "List index out of bounds: 0" when
        // options is empty in Apex (unlike Java's ArrayList). Build a fresh
        // list with the running user first instead of inserting at index 0.
        if (!runningIncluded) {
            List<UserOption> withRunningUserFirst = new List<UserOption>();
            withRunningUserFirst.add(toOption(me));
            withRunningUserFirst.addAll(options);
            options = withRunningUserFirst;
        }
        return options;
    }

    private static User runningUser(Id userId) {
        return [
            SELECT Id, Name, Department, Departments__c, Profile.Name
            FROM User
            WHERE Id = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }

    private static String opportunityDepartment(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Department_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].Department_Name__c;
    }

    private static List<String> splitDepartments(String multi) {
        List<String> result = new List<String>();
        if (String.isNotBlank(multi)) {
            for (String d : multi.split(';')) {
                if (String.isNotBlank(d)) {
                    result.add(d.trim());
                }
            }
        }
        return result;
    }

    private static String buildIncludesSoql(List<String> departments) {
        List<String> conditions = new List<String>();
        for (String dept : departments) {
            conditions.add('Departments__c INCLUDES (\'' + String.escapeSingleQuotes(dept) + '\')');
        }
        return 'SELECT Id, Name FROM User '
             + 'WHERE IsActive = true '
             + 'AND Profile.Name NOT IN (\'Utkarsh Admin\', \'System Administrator\') '
             + 'AND (' + String.join(conditions, ' OR ') + ') WITH SYSTEM_MODE ORDER BY Name';
    }

    private static UserOption toOption(User u) {
        UserOption opt = new UserOption();
        opt.id   = u.Id;
        opt.name = u.Name;
        return opt;
    }

    /* ---- OPEN definitions (per category, for this Opportunity) ---- */
    private static Boolean hasOpenCall(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :opportunityId
              AND TaskSubtype = 'Call'
              AND Status = 'Open'
            WITH SYSTEM_MODE
        ] > 0;
    }

    private static Boolean hasOpenEvent(Id opportunityId) {
        Datetime nowDt = Datetime.now();
        return [
            SELECT COUNT()
            FROM Event
            WHERE WhatId = :opportunityId
              AND (Disposition__c = null
                   OR Disposition__c NOT IN ('Completed', 'Not Completed'))
              AND StartDateTime >= :nowDt
              AND (EndDateTime >= :nowDt OR EndDateTime = null)
            WITH SYSTEM_MODE
        ] > 0;
    }

    private static Boolean hasOpenVisit(Id opportunityId) {
        // COUNT() queries must use Database.countQuery(), not Database.query().
        return Database.countQuery(
            'SELECT COUNT() FROM Task_Log__c '
          + 'WHERE ' + TASKLOG_OPP_FIELD + ' = :opportunityId '
          + 'AND Is_schedule__c = true AND Logged_At__c = null '
          + 'WITH SYSTEM_MODE'
        ) > 0;
    }

    /* ---- CREATE: Call ---- */
    @AuraEnabled
    public static Id createCall(Id opportunityId, String subject, Datetime followUp,
                                String comments, Id assignedToId) {
        if (hasOpenCall(opportunityId)) {
            throw handled('An open Call already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (followUp != null && followUp < Datetime.now()) {
            throw handled('Follow-up Call date/time cannot be in the past.');
        }
        Task t = new Task();
        t.WhatId                 = opportunityId;
        t.TaskSubtype            = 'Call';
        t.Subject                = subject;
        t.Status                 = 'Open';
        t.Manually_Created__c    = true;
        t.Follow_Up_Date_Time__c = followUp;
        if (followUp != null) {
            t.ActivityDate = followUp.date();
        }
        t.Description = comments;
        if (assignedToId != null) {
            t.OwnerId = assignedToId;
        }
        insert t;
        return t.Id;
    }

    /* ---- CREATE: Event ---- */
    @AuraEnabled
    public static Id createEvent(Id opportunityId, String subject, String comments,
                                 Datetime startDt, Datetime endDt, Id assignedToId) {
        if (hasOpenEvent(opportunityId)) {
            throw handled('An open Event already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (startDt != null && startDt < Datetime.now()) {
            throw handled('Event start cannot be in the past.');
        }
        Event e = new Event();
        e.WhatId        = opportunityId;
        e.Subject       = subject;
        e.Description   = comments;
        e.StartDateTime = startDt;
        e.EndDateTime   = endDt;
        e.Type          = 'Meeting';
        e.IsReminderSet = true;
        if (startDt != null) {
            e.ReminderDateTime = startDt.addMinutes(-15);
        }
        if (assignedToId != null) {
            e.OwnerId = assignedToId;
        }
        insert e;

        notifyOwner(effectiveOwner(assignedToId), e.Id,
            'New Event assigned',
            String.isBlank(subject) ? 'An event has been assigned to you.' : subject);
        return e.Id;
    }

    /* ---- CREATE: Visit ---- */
    @AuraEnabled
    public static Id createVisit(Id opportunityId, String visitType, String reason,
                                 Date scheduleDate, Id assignedToId) {
        if (hasOpenVisit(opportunityId)) {
            throw handled('An open Visit already exists for this Opportunity. Complete it before creating a new one.');
        }
        if (scheduleDate != null && scheduleDate < Date.today()) {
            throw handled('Visit Schedule Date cannot be in the past.');
        }
        Task_Log__c v = new Task_Log__c();
        v.put(TASKLOG_OPP_FIELD, opportunityId);
        v.Visit_Type__c       = visitType;
        v.Reason_for_Visit__c = reason;
        v.Schedule_Date__c    = scheduleDate;
        v.Is_schedule__c      = true;
        v.Manually_Created__c = true;
        if (assignedToId != null) {
            v.OwnerId = assignedToId;
        }
        insert v;

        String body = 'A visit has been assigned to you.';
        if (String.isNotBlank(visitType)) {
            body = 'Visit (' + visitType + ') has been assigned to you.';
        }
        notifyOwner(effectiveOwner(assignedToId), v.Id, 'New Visit assigned', body);
        return v.Id;
    }

    /* ---- push / custom notification to the owner (non-blocking) ---- */
    private static Id effectiveOwner(Id assignedToId) {
        return assignedToId != null ? assignedToId : UserInfo.getUserId();
    }

    private static void notifyOwner(Id ownerId, Id targetRecordId, String title, String body) {
        if (ownerId == null) {
            return;
        }
        Id typeId = notificationTypeId();
        if (typeId == null) {
            return;
        }
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(targetRecordId);
            notification.send(new Set<String>{ String.valueOf(ownerId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Owner notification failed: ' + e.getMessage());
        }
    }

    // CustomNotificationType is NOT queryable via standard SOQL, so its Id is
    // hardcoded. Get it once from Developer Console (Query Editor -> check
    // "Use Tooling API"):  SELECT Id, DeveloperName FROM CustomNotificationType
    // then paste the Id below. Leave blank to disable notifications (no error).
    private static final String NOTIF_TYPE_ID = '';
    private static Id notificationTypeId() {
        return String.isBlank(NOTIF_TYPE_ID) ? null : (Id) NOTIF_TYPE_ID;
    }

    private static AuraHandledException handled(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }
}