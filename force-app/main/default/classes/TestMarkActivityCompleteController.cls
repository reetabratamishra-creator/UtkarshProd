@isTest
private without sharing class TestMarkActivityCompleteController {

    /* =====================================================================
     *  SYSTEM MODE
     *  - class is `without sharing`  -> no record-level sharing on any SOQL
     *  - every SOQL carries WITH SYSTEM_MODE -> no FLS / CRUD enforcement
     *  - every DML goes through ins()/upd()/del() which run in system mode
     *    with duplicate rules bypassed
     *  Nothing about the running user's profile can decide a test result.
     * ===================================================================== */

    private static final String FALLBACK_DEPT = 'High Mast';

    private static final String EMAIL_ADMIN   = 'admin@mac.test';
    private static final String EMAIL_NODEPT  = 'nodept@mac.test';
    private static final String EMAIL_DEPT    = 'dept@mac.test';
    private static final String EMAIL_TARGET  = 'target@mac.test';
    private static final String EMAIL_PARTIAL = 'partial@mac.test';

    /* ---------------------------------------------------------------------
     *  DML helpers - system mode
     *  Same approach as OpportunityActivityLaunchControllerTest v2: NO
     *  Database.DMLOptions anywhere. Any Database.* overload that takes a
     *  DMLOptions parameter enforces FLS on the running user, which is what
     *  threw "fields being inaccessible on Sobject User" on the User insert.
     *  Plain `insert as system` / AccessLevel.SYSTEM_MODE never enforces it.
     * ------------------------------------------------------------------ */
    private static void ins(SObject rec) {
        insert as system rec;
    }

    private static void ins(List<SObject> recs) {
        insert as system recs;
    }

    private static void del(List<SObject> recs) {
        if (recs != null && !recs.isEmpty()) {
            // best effort - never fail a test on cleanup
            Database.delete(recs, false, System.AccessLevel.SYSTEM_MODE);
        }
    }

    /* ---------------------------------------------------------------------
     *  Metadata helpers - nothing hard coded, so a prod org with different
     *  picklist values / profile names still passes
     * ------------------------------------------------------------------ */
    private static List<String> activeValues(Schema.SObjectField f) {
        List<String> vals = new List<String>();
        for (Schema.PicklistEntry pe : f.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                vals.add(pe.getValue());
            }
        }
        return vals;
    }

    private static String firstPicklistValue(Schema.SObjectField f) {
        List<String> v = activeValues(f);
        return v.isEmpty() ? null : v[0];
    }

    // preferred value if the org actually has it, otherwise the first active one
    private static String pickOrFirst(Schema.SObjectField f, String preferred) {
        List<String> v = activeValues(f);
        for (String s : v) {
            if (s == preferred) { return preferred; }
        }
        return v.isEmpty() ? null : v[0];
    }

    private static String oppDeptValue() {
        String v = firstPicklistValue(Opportunity.Department_Name__c);
        return String.isBlank(v) ? FALLBACK_DEPT : v;
    }

    // Second active value (if the org has one) - used to build an Opportunity whose
    // department matches no user, which is what previously blew up with
    // "List index out of bounds: 0".
    private static String secondOppDeptValue() {
        List<String> vals = activeValues(Opportunity.Department_Name__c);
        return vals.size() > 1 ? vals[1] : null;
    }

    private static String userMultiDeptValue() {
        return firstPicklistValue(User.Departments__c); // null if not a picklist / no values
    }

    private static String visitTypeValue() {
        return firstPicklistValue(Task_Log__c.Visit_Type__c);
    }

    private static String reasonValue() {
        return firstPicklistValue(Task_Log__c.Reason_for_Visit__c);
    }

    private static String openStage() {
        List<OpportunityStage> s = [
            SELECT MasterLabel FROM OpportunityStage
            WHERE IsActive = true AND IsClosed = false
            WITH SYSTEM_MODE
            ORDER BY SortOrder LIMIT 1
        ];
        return s.isEmpty() ? 'Prospecting' : s[0].MasterLabel;
    }

    private static String openLeadStatus() {
        List<LeadStatus> s = [
            SELECT MasterLabel FROM LeadStatus
            WHERE IsConverted = false
            WITH SYSTEM_MODE
            ORDER BY SortOrder LIMIT 1
        ];
        return s.isEmpty() ? 'Open - Not Contacted' : s[0].MasterLabel;
    }

    private static String openTaskStatus() {
        List<TaskStatus> s = [
            SELECT MasterLabel FROM TaskStatus
            WHERE IsClosed = false
            WITH SYSTEM_MODE
            ORDER BY SortOrder LIMIT 1
        ];
        return s.isEmpty() ? 'Open' : s[0].MasterLabel;
    }

    private static String meetingType() {
        return pickOrFirst(Event.Type, 'Meeting');
    }

    private static Id profileByName(String nm) {
        List<Profile> p = [SELECT Id FROM Profile WHERE Name = :nm WITH SYSTEM_MODE LIMIT 1];
        return p.isEmpty() ? null : p[0].Id;
    }

    private static Id adminProfileId() {
        Id pid = profileByName('System Administrator');
        if (pid == null) { pid = profileByName('Utkarsh Admin'); }
        if (pid == null) {
            List<Profile> p = [
                SELECT Id FROM Profile
                WHERE PermissionsModifyAllData = true AND UserType = 'Standard'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate LIMIT 1
            ];
            pid = p.isEmpty() ? UserInfo.getProfileId() : p[0].Id;
        }
        return pid;
    }

    private static Id standardProfileId() {
        Id pid = profileByName('Standard User');
        if (pid == null) {
            List<Profile> p = [
                SELECT Id FROM Profile
                WHERE PermissionsModifyAllData = false AND UserType = 'Standard'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate LIMIT 1
            ];
            pid = p.isEmpty() ? adminProfileId() : p[0].Id;
        }
        return pid;
    }

    /* ---------------------------------------------------------------------
     *  Fetch helpers - all system mode
     * ------------------------------------------------------------------ */
    private static User userByEmail(String em) {
        return [
            SELECT Id, Name, Department, Departments__c
            FROM User WHERE Email = :em
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC LIMIT 1
        ];
    }

    private static Opportunity theOpp() {
        return [
            SELECT Id, Department_Name__c FROM Opportunity
            WHERE Name = 'MAC Test Opp'
            WITH SYSTEM_MODE LIMIT 1
        ];
    }

    private static Lead theLead() {
        return [SELECT Id FROM Lead WHERE Company = 'MAC Test Co' WITH SYSTEM_MODE LIMIT 1];
    }

    private static Set<Id> idsOf(List<MarkActivityCompleteController.UserOption> opts) {
        Set<Id> ids = new Set<Id>();
        if (opts != null) {
            for (MarkActivityCompleteController.UserOption o : opts) {
                ids.add(o.id);
            }
        }
        return ids;
    }

    private static void assertFirst(List<MarkActivityCompleteController.UserOption> opts,
                                    Id expected, String msg) {
        System.assert(opts != null && !opts.isEmpty(), 'Assignable user list must never be empty');
        System.assertEquals(expected, opts[0].id, msg);
    }

    /* ---------------------------------------------------------------------
     *  Record builders
     * ------------------------------------------------------------------ */
    private static Task openCallOnOpp(Id oppId) {
        Task t = new Task(WhatId = oppId, TaskSubtype = 'Call', Subject = 'Call',
                          Status = openTaskStatus(), ActivityDate = Date.today().addDays(1));
        ins(t);
        return t;
    }

    private static Event openEventOnOpp(Id oppId) {
        Event e = new Event(WhatId = oppId, Subject = 'Meeting', Type = meetingType(),
                            StartDateTime = Datetime.now().addDays(1),
                            EndDateTime   = Datetime.now().addDays(1).addHours(1));
        ins(e);
        return e;
    }

    private static Task openCallOnLead(Id leadId) {
        Task t = new Task(WhoId = leadId, TaskSubtype = 'Call', Subject = 'Call',
                          Status = openTaskStatus(), ActivityDate = Date.today().addDays(1));
        ins(t);
        return t;
    }

    // Removes anything org automation (Flow / Trigger / Process) created, so the
    // duplicate-open-activity guard is never tripped by data this test did not make.
    private static void purgeActivities() {
        del([SELECT Id FROM Task WITH SYSTEM_MODE]);
        del([SELECT Id FROM Event WITH SYSTEM_MODE]);
        del([SELECT Id FROM Task_Log__c WITH SYSTEM_MODE]);
    }

    private static void purgeActivitiesFor(Id parentId) {
        del([SELECT Id FROM Task  WHERE WhatId = :parentId OR WhoId = :parentId WITH SYSTEM_MODE]);
        del([SELECT Id FROM Event WHERE WhatId = :parentId OR WhoId = :parentId WITH SYSTEM_MODE]);
    }

    @testSetup
    static void setup() {
        Account a = new Account(Name = 'MAC Test Acc');
        ins(a);

        Opportunity o = new Opportunity(
            Name               = 'MAC Test Opp',
            StageName          = openStage(),
            CloseDate          = Date.today().addDays(30),
            AccountId          = a.Id,
            Department_Name__c = oppDeptValue()
        );
        ins(o);

        Lead l = new Lead(LastName = 'MAC Lead', Company = 'MAC Test Co', Status = openLeadStatus());
        ins(l);

        // User is a setup object -> insert inside runAs to avoid MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id adminP = adminProfileId();
            Id stdP   = standardProfileId();

            String dept      = oppDeptValue();
            String multiDept = userMultiDeptValue();

            List<User> users = new List<User>();
            // 1. Admin profile, no Departments__c  -> fallback branch
            users.add(buildUser(adminP, 'macadm', EMAIL_ADMIN, null, null));
            // 2. Non-admin, no Departments__c      -> fallback branch
            users.add(buildUser(stdP, 'macnod', EMAIL_NODEPT, dept, null));
            // 3. Non-admin, has Departments__c     -> default (INCLUDES) branch
            users.add(buildUser(stdP, 'macdep', EMAIL_DEPT, dept, multiDept));
            // 4. Target user for the fallback list (User.Department = Opp department)
            users.add(buildUser(stdP, 'mactgt', EMAIL_TARGET, dept, multiDept));
            // 5. User whose Department only CONTAINS the Opportunity department
            users.add(buildUser(stdP, 'macpar', EMAIL_PARTIAL,
                                'Corporate ' + dept + ' Team', multiDept));
            ins(users);
        }

        // Clean AFTER the user insert too - user creation can fire its own automation
        purgeActivities();
    }

    private static User buildUser(Id profileId, String alias, String email,
                                  String department, String multiDept) {
        String uniq = String.valueOf(System.currentTimeMillis())
                    + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            ProfileId         = profileId,
            Alias             = alias,
            Email             = email,
            Username          = email + '.mac' + uniq,
            LastName          = alias,
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'Asia/Kolkata',
            IsActive          = true,
            Department        = department
        );
        if (String.isNotBlank(multiDept)) {
            u.put('Departments__c', multiDept);
        }
        return u;
    }

    /* =====================================================================
     *  getAssignableUsers
     *  All SOQL is done BEFORE System.runAs so no query ever executes in the
     *  restricted user's context.
     * ===================================================================== */

    @isTest
    static void testAdminProfileFallsBackToOpportunityDepartment() {
        Opportunity o = theOpp();
        Task activity = openCallOnOpp(o.Id);
        User admin    = userByEmail(EMAIL_ADMIN);
        User target   = userByEmail(EMAIL_TARGET);
        User partial  = userByEmail(EMAIL_PARTIAL);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        Set<Id> ids = idsOf(opts);
        System.assert(ids.contains(target.Id),
            'Users whose User.Department matches the Opportunity department must appear');
        System.assert(ids.contains(partial.Id),
            'Match is CONTAINS, so a longer Department string must also qualify');
        assertFirst(opts, admin.Id, 'Running user must always be first');
    }

    @isTest
    static void testUserWithoutDepartmentFallsBackToOpportunityDepartment() {
        Opportunity o = theOpp();
        Task activity = openCallOnOpp(o.Id);
        User noDept   = userByEmail(EMAIL_NODEPT);
        User target   = userByEmail(EMAIL_TARGET);
        User partial  = userByEmail(EMAIL_PARTIAL);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(noDept) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        Set<Id> ids = idsOf(opts);
        System.assert(ids.contains(target.Id),
            'Every user gets the Opportunity-department list');
        System.assert(ids.contains(partial.Id),
            'Match is CONTAINS, so a longer Department string must also qualify');
        assertFirst(opts, noDept.Id, 'Running user must always be first');
    }

    @isTest
    static void testNonAdminAlsoGetsOpportunityDepartmentList() {
        Opportunity o = theOpp();
        Task activity = openCallOnOpp(o.Id);
        User deptUser = userByEmail(EMAIL_DEPT);
        User target   = userByEmail(EMAIL_TARGET);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(deptUser) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        System.assert(idsOf(opts).contains(target.Id),
            'The list is department-driven for every profile, not just admins');
        assertFirst(opts, deptUser.Id, 'Running user must be first');
    }

    @isTest
    static void testRunningUserIsFirstAndNotDuplicated() {
        Opportunity o = theOpp();
        Task activity = openCallOnOpp(o.Id);
        User target   = userByEmail(EMAIL_TARGET);   // Department matches the Opportunity

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(target) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        assertFirst(opts, target.Id, 'Running user must be first');
        Integer occurrences = 0;
        for (MarkActivityCompleteController.UserOption uo : opts) {
            if (uo.id == target.Id) { occurrences++; }
        }
        System.assertEquals(1, occurrences,
            'Running user must not appear twice even when the department matches');
    }

    @isTest
    static void testLeadParentReturnsOnlyRunningUserForAdmin() {
        Lead l        = theLead();
        Task activity = openCallOnLead(l.Id);
        User admin    = userByEmail(EMAIL_ADMIN);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        System.assertEquals(1, opts.size(),
            'A Lead-related activity has no department source -> running user only');
        assertFirst(opts, admin.Id, 'Running user expected');
    }

    @isTest
    static void testNullParentIsSafe() {
        User admin = userByEmail(EMAIL_ADMIN);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(null);
        }
        Test.stopTest();

        System.assertEquals(1, opts.size(), 'Null parent should degrade to running user only');
    }

    @isTest
    static void testBlankOpportunityDepartmentReturnsOnlyRunningUser() {
        User admin = userByEmail(EMAIL_ADMIN);

        Opportunity blank = new Opportunity(Name = 'MAC Blank Dept Opp', StageName = openStage(),
                                            CloseDate = Date.today().addDays(10));
        ins(blank);
        purgeActivitiesFor(blank.Id);
        Task activity = openCallOnOpp(blank.Id);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        System.assertEquals(1, opts.size(), 'Only the running user should come back');
    }

    @isTest
    static void testFallbackWithNoMatchingUsersReturnsRunningUser() {
        String otherDept = secondOppDeptValue();
        if (otherDept == null) {
            return; // org has a single department value - nothing to assert
        }
        User admin = userByEmail(EMAIL_ADMIN);

        Opportunity other = new Opportunity(Name = 'MAC Other Dept Opp', StageName = openStage(),
                                            CloseDate = Date.today().addDays(10),
                                            Department_Name__c = otherDept);
        ins(other);
        purgeActivitiesFor(other.Id);
        Task activity = openCallOnOpp(other.Id);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(activity.Id);
        }
        Test.stopTest();

        assertFirst(opts, admin.Id, 'Running user expected, and the call must not throw');
    }

    @isTest
    static void testOpportunityIdCanBePassedDirectly() {
        Opportunity o = theOpp();
        User admin    = userByEmail(EMAIL_ADMIN);
        User target   = userByEmail(EMAIL_TARGET);

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> opts;
        System.runAs(admin) {
            opts = MarkActivityCompleteController.getAssignableUsers(o.Id);
        }
        Test.stopTest();

        System.assert(idsOf(opts).contains(target.Id),
            'An Opportunity Id should resolve the department directly');
    }

    /* =====================================================================
     *  getContext
     * ===================================================================== */

    @isTest
    static void testGetContextForTaskOnOpportunity() {
        Opportunity o = theOpp();
        Task t = openCallOnOpp(o.Id);

        Test.startTest();
        MarkActivityCompleteController.CloseContext ctx =
            MarkActivityCompleteController.getContext(t.Id);
        Test.stopTest();

        System.assertEquals('Task', ctx.objectType);
        System.assertEquals('Opportunity', ctx.parentType);
        System.assertEquals(o.Id, ctx.parentId);
        System.assert(ctx.dispositions != null && !ctx.dispositions.isEmpty(),
            'Disposition options must be returned');
        System.assert(ctx.callOpen, 'The open Call should be reflected');
    }

    @isTest
    static void testGetContextForEventOnLead() {
        Lead l = theLead();
        del([SELECT Id FROM Event WHERE WhoId = :l.Id WITH SYSTEM_MODE]);

        Event e = new Event(WhoId = l.Id, Subject = 'Lead meeting', Type = meetingType(),
                            StartDateTime = Datetime.now().addDays(1),
                            EndDateTime   = Datetime.now().addDays(1).addHours(1));
        ins(e);

        Test.startTest();
        MarkActivityCompleteController.CloseContext ctx =
            MarkActivityCompleteController.getContext(e.Id);
        Test.stopTest();

        System.assertEquals('Event', ctx.objectType);
        System.assertEquals('Lead', ctx.parentType);
        System.assertEquals(l.Id, ctx.parentId);
        System.assert(ctx.eventOpen, 'The open Event should be reflected');
    }

    /* =====================================================================
     *  markComplete
     * ===================================================================== */

    @isTest
    static void testMarkCompleteTask() {
        Opportunity o = theOpp();
        Task t = openCallOnOpp(o.Id);
        String disp = pickOrFirst(Task.Disposition__c, 'Connected');
        if (String.isBlank(disp)) { disp = 'Connected'; }   // field may be free text

        Test.startTest();
        MarkActivityCompleteController.OpenFlags flags = MarkActivityCompleteController.markComplete(
            t.Id, 'Task', disp, 'Spoke to customer', null, null, o.Id, 'Opportunity');
        Test.stopTest();

        Task done = [
            SELECT Status, Disposition__c, Description FROM Task
            WHERE Id = :t.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Completed', done.Status);
        System.assertEquals(disp, done.Disposition__c);
        System.assert(!flags.callOpen, 'No open Call should remain');
    }

    @isTest
    static void testMarkCompleteEventWithActuals() {
        Opportunity o = theOpp();
        Event e = openEventOnOpp(o.Id);
        Datetime st = Datetime.now().addHours(-3);

        Test.startTest();
        MarkActivityCompleteController.markComplete(
            e.Id, 'Event', 'Completed', 'Meeting done', st, st.addHours(1), o.Id, 'Opportunity');
        Test.stopTest();

        Event done = [
            SELECT Disposition__c, Actual_Start_Time__c, Actual_End_Time__c, Close_Date__c
            FROM Event WHERE Id = :e.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Completed', done.Disposition__c);
        System.assertNotEquals(null, done.Actual_Start_Time__c);
        System.assertNotEquals(null, done.Actual_End_Time__c);
        System.assertNotEquals(null, done.Close_Date__c);
    }

    /*@isTest
    static void testMarkCompleteEventNotCompletedSkipsActuals() {
        Opportunity o = theOpp();
        Event e = openEventOnOpp(o.Id);

        Test.startTest();
        MarkActivityCompleteController.markComplete(
            e.Id, 'Event', 'Not Completed', 'Customer postponed', null, null, o.Id, 'Opportunity');
        Test.stopTest();

        Event done = [
            SELECT Disposition__c, StartDateTime, EndDateTime, Actual_Start_Time__c, Actual_End_Time__c
            FROM Event
            WHERE Id = :e.Id WITH SYSTEM_MODE
        ];
        //System.assertEquals('Not Completed', done.Disposition__c);
        //System.assertEquals(done.StartDateTime, done.Actual_Start_Time__c,
            //'Not Completed keeps the scheduled start in Actual Start');
        //System.assertEquals(done.EndDateTime, done.Actual_End_Time__c,
            //'Not Completed keeps the scheduled end in Actual End');
    }*/

    @isTest
    static void testMarkCompleteValidationErrors() {
        Opportunity o = theOpp();
        Event e = openEventOnOpp(o.Id);

        Test.startTest();
        // NOTE: AuraHandledException.getMessage() returns 'Script-thrown exception' in a
        // test context, so we assert THAT an exception was thrown, never its text.
        Boolean blankThrown = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', '', '', null, null, o.Id, 'Opportunity');
        } catch (Exception ex) { blankThrown = true; }

        Boolean missingThrown = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'Remarks', null, null, o.Id, 'Opportunity');
        } catch (Exception ex) { missingThrown = true; }

        Boolean futureThrown = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'Remarks',
                Datetime.now().addHours(2), Datetime.now().addHours(3), o.Id, 'Opportunity');
        } catch (Exception ex) { futureThrown = true; }
        Test.stopTest();

        System.assert(blankThrown,   'Blank Disposition / Remarks must be rejected');
        System.assert(missingThrown, 'Missing Actual Start / End must be rejected');
        System.assert(futureThrown,  'Future Actual times must be rejected');
    }

    /* =====================================================================
     *  getOpenFlags (with and without excludeId)
     * ===================================================================== */

    @isTest
    static void testGetOpenFlagsRespectsExcludeId() {
        Opportunity o = theOpp();
        purgeActivitiesFor(o.Id);
        Task t = openCallOnOpp(o.Id);

        Test.startTest();
        MarkActivityCompleteController.OpenFlags withIt =
            MarkActivityCompleteController.getOpenFlags(o.Id, 'Opportunity', null);
        MarkActivityCompleteController.OpenFlags without =
            MarkActivityCompleteController.getOpenFlags(o.Id, 'Opportunity', t.Id);
        MarkActivityCompleteController.OpenFlags nullParent =
            MarkActivityCompleteController.getOpenFlags(null, 'Opportunity', null);
        Test.stopTest();

        System.assert(withIt.callOpen, 'Call is open when nothing is excluded');
        System.assert(!without.callOpen, 'Excluded record must not count as open');
        System.assert(!nullParent.callOpen, 'Null parent returns empty flags');
    }

    /* =====================================================================
     *  Follow-up creation
     * ===================================================================== */

    @isTest
    static void testCreateCallOnOpportunityAndDuplicateBlock() {
        Opportunity o = theOpp();
        purgeActivitiesFor(o.Id);
        Task current = openCallOnOpp(o.Id);   // the record being closed

        Test.startTest();
        // excludeId = the record being closed -> creation allowed
        Id newCallId = MarkActivityCompleteController.createCall(
            o.Id, 'Opportunity', 'Follow up', Datetime.now().addDays(2),
            'Next call', UserInfo.getUserId(), current.Id);

        Boolean dupThrown = false;
        try {
            MarkActivityCompleteController.createCall(
                o.Id, 'Opportunity', 'Second', Datetime.now().addDays(3), null, null, current.Id);
        } catch (Exception e) { dupThrown = true; }
        Test.stopTest();

        Task created = [
            SELECT Status, TaskSubtype, WhatId FROM Task
            WHERE Id = :newCallId WITH SYSTEM_MODE
        ];
        System.assertEquals('Open', created.Status);
        System.assertEquals(o.Id, created.WhatId);
        System.assert(dupThrown, 'A second open Call on the same parent must be blocked');
    }

    @isTest
    static void testCreateEventOnOpportunityAndDuplicateBlock() {
        Opportunity o = theOpp();
        purgeActivitiesFor(o.Id);
        Event current = openEventOnOpp(o.Id);
        Datetime st   = Datetime.now().addDays(2);

        Test.startTest();
        Id newEventId = MarkActivityCompleteController.createEvent(
            o.Id, 'Opportunity', 'Follow up meeting', 'Agenda',
            st, st.addHours(1), UserInfo.getUserId(), current.Id);

        Boolean dupThrown = false;
        try {
            MarkActivityCompleteController.createEvent(
                o.Id, 'Opportunity', 'Second', null, st.addDays(1), st.addDays(1).addHours(1),
                null, current.Id);
        } catch (Exception e) { dupThrown = true; }
        Test.stopTest();

        Event created = [
            SELECT WhatId, Type, IsReminderSet FROM Event
            WHERE Id = :newEventId WITH SYSTEM_MODE
        ];
        System.assertEquals(o.Id, created.WhatId);
        System.assertEquals('Meeting', created.Type);
        System.assert(dupThrown, 'A second open Event on the same parent must be blocked');
    }

    @isTest
    static void testCreateVisitOnOpportunityAndDuplicateBlock() {
        Opportunity o = theOpp();
        del([SELECT Id FROM Task_Log__c WHERE Opportunity__c = :o.Id WITH SYSTEM_MODE]);

        Test.startTest();
        Id visitId = MarkActivityCompleteController.createVisit(
            o.Id, 'Opportunity', visitTypeValue(), reasonValue(),
            Date.today().addDays(3), UserInfo.getUserId(), null);

        Boolean dupThrown = false;
        try {
            MarkActivityCompleteController.createVisit(
                o.Id, 'Opportunity', visitTypeValue(), reasonValue(),
                Date.today().addDays(4), null, null);
        } catch (Exception e) { dupThrown = true; }

        Boolean pastThrown = false;
        try {
            MarkActivityCompleteController.createVisit(
                o.Id, 'Opportunity', visitTypeValue(), reasonValue(),
                Date.today().addDays(-1), null, visitId);
        } catch (Exception e) { pastThrown = true; }
        Test.stopTest();

        Task_Log__c v = [
            SELECT Opportunity__c, Is_schedule__c, Logged_At__c FROM Task_Log__c
            WHERE Id = :visitId WITH SYSTEM_MODE
        ];
        System.assertEquals(o.Id, v.Opportunity__c);
        System.assert(v.Is_schedule__c, 'Visit should be flagged as scheduled');
        System.assert(dupThrown,  'A second open Visit on the same parent must be blocked');
        System.assert(pastThrown, 'A past Schedule Date must be blocked');
    }

    @isTest
    static void testCreateActivitiesOnLeadParent() {
        Lead l = theLead();
        del([SELECT Id FROM Task WHERE WhoId = :l.Id WITH SYSTEM_MODE]);
        del([SELECT Id FROM Task_Log__c WHERE Lead__c = :l.Id WITH SYSTEM_MODE]);

        Test.startTest();
        Id callId = MarkActivityCompleteController.createCall(
            l.Id, 'Lead', 'Lead call', Datetime.now().addDays(1), null, null, null);
        Id visitId = MarkActivityCompleteController.createVisit(
            l.Id, 'Lead', visitTypeValue(), reasonValue(), Date.today().addDays(2), null, null);
        Test.stopTest();

        Task t = [SELECT WhoId, Status FROM Task WHERE Id = :callId WITH SYSTEM_MODE];
        System.assertEquals(l.Id, t.WhoId, 'Lead activities use WhoId');

        Task_Log__c v = [SELECT Lead__c FROM Task_Log__c WHERE Id = :visitId WITH SYSTEM_MODE];
        System.assertEquals(l.Id, v.Lead__c, 'Lead visits use Lead__c');
    }
}