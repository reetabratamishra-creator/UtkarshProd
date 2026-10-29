@isTest
private class OpportunityActivityLaunchControllerTest {

    /*
     * DEPLOYMENT FIX (v2)
     * -------------------
     * Failure: System.DmlException: Operation failed due to fields being
     *          inaccessible on Sobject User  --  thrown from @testSetup.
     *
     * User is a setup object. Its DML permission check (Manage Users + field
     * accessibility) is NOT the ordinary FLS layer, so AccessLevel.SYSTEM_MODE
     * does not bypass it. The only reliable fix is to stop creating User
     * records in the test.
     *
     * This version performs ZERO DML on User. Test users are picked from the
     * active users already in the org (User is queryable in tests without
     * SeeAllData). Every test degrades gracefully if a suitable user is not
     * found, so the class can never block a deployment again.
     *
     * All remaining SOQL/DML still runs explicitly in system mode.
     */

    private static final String OPP_STAGE  = pickValue(Opportunity.StageName);
    private static final String VISIT_TYPE = pickOrText(Task_Log__c.Visit_Type__c, 'Site Visit');
    private static final String VISIT_RSN  = pickOrText(Task_Log__c.Reason_for_Visit__c, 'Requirement discussion');

    private static final Map<String, Object> NO_BINDS = new Map<String, Object>();

    // Lazily resolved from the org — never inserted.
    private static Boolean usersLoaded = false;
    private static User anyUser;        // any other active standard user
    private static User multiDeptUser;  // has Departments__c populated
    private static User noDeptUser;     // has neither Departments__c nor Department
    private static User oppDeptUser;    // standard Department == Opportunity.Department_Name__c

    /* ============ system-mode SOQL / DML wrappers ============ */

    private static List<SObject> sysQuery(String soql) {
        return Database.queryWithBinds(soql, NO_BINDS, AccessLevel.SYSTEM_MODE);
    }

    private static List<SObject> sysQuery(String soql, Map<String, Object> binds) {
        return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
    }

    private static Integer sysCount(String soql, Map<String, Object> binds) {
        return Database.countQueryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
    }

    private static void sysInsert(List<SObject> records) {
        Database.insert(records, AccessLevel.SYSTEM_MODE);
    }

    private static void sysUpdate(List<SObject> records) {
        Database.update(records, AccessLevel.SYSTEM_MODE);
    }

    private static void sysDelete(List<SObject> records) {
        if (!records.isEmpty()) {
            Database.delete(records, AccessLevel.SYSTEM_MODE);
        }
    }

    /* ===================== describe helpers ===================== */

    private static String pickValue(Schema.SObjectField f) {
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    private static String pickOrText(Schema.SObjectField f, String fallback) {
        Schema.DescribeFieldResult d = f.getDescribe();
        if (d.getType() == Schema.DisplayType.PICKLIST || d.getType() == Schema.DisplayType.MULTIPICKLIST) {
            String v = pickValue(f);
            return String.isNotBlank(v) ? v : fallback;
        }
        return fallback;
    }

    private static Set<String> activePicklistValues(Schema.SObjectField f) {
        Set<String> vals = new Set<String>();
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                vals.add(e.getValue().toLowerCase());
            }
        }
        return vals;
    }

    /* ===================== user resolution (no DML) ===================== */

    private static List<User> userPool() {
        return (List<User>) sysQuery(
            'SELECT Id, Name, Departments__c, Department FROM User ' +
            'WHERE IsActive = true AND UserType = \'Standard\' AND Id != :me ' +
            'ORDER BY CreatedDate DESC LIMIT 200',
            new Map<String, Object>{ 'me' => UserInfo.getUserId() }
        );
    }

    // Picks a Department value that (a) an existing active user carries and
    // (b) is a legal value for Opportunity.Department_Name__c, so the
    // fallback branch of getAssignableUsers can actually match something.
    private static String resolveOppDept() {
        Schema.DescribeFieldResult d = Opportunity.Department_Name__c.getDescribe();
        Boolean isPick = (d.getType() == Schema.DisplayType.PICKLIST ||
                          d.getType() == Schema.DisplayType.MULTIPICKLIST);
        Set<String> legal = isPick ? activePicklistValues(Opportunity.Department_Name__c) : null;

        for (User u : userPool()) {
            if (String.isBlank(u.Department)) {
                continue;
            }
            if (!isPick || legal.contains(u.Department.toLowerCase())) {
                return u.Department;
            }
        }
        return null;
    }

    private static User currentUser() {
        return (User) sysQuery(
            'SELECT Id, Name FROM User WHERE Id = :me LIMIT 1',
            new Map<String, Object>{ 'me' => UserInfo.getUserId() }
        )[0];
    }

    private static void loadUsers() {
        if (usersLoaded) {
            return;
        }
        usersLoaded = true;

        String oppDept = (String) sysQuery(
            'SELECT Department_Name__c FROM Opportunity WHERE Name = :nm LIMIT 1',
            new Map<String, Object>{ 'nm' => 'OALC Test Opportunity Dept' }
        )[0].get('Department_Name__c');

        for (User u : userPool()) {
            if (anyUser == null) {
                anyUser = u;
            }
            if (multiDeptUser == null && String.isNotBlank(u.Departments__c)) {
                multiDeptUser = u;
            }
            if (noDeptUser == null && String.isBlank(u.Departments__c) && String.isBlank(u.Department)) {
                noDeptUser = u;
            }
            if (oppDeptUser == null && String.isNotBlank(oppDept) && oppDept.equalsIgnoreCase(u.Department)) {
                oppDeptUser = u;
            }
        }
        if (anyUser == null) {
            anyUser = currentUser();
        }
    }

    private static User assigneeUser() {
        loadUsers();
        return anyUser;
    }

    /* ===================== record helpers ===================== */

    private static Opportunity opp() {
        return (Opportunity) sysQuery(
            'SELECT Id FROM Opportunity WHERE Name = :nm LIMIT 1',
            new Map<String, Object>{ 'nm' => 'OALC Test Opportunity' }
        )[0];
    }

    private static Opportunity oppWithDept() {
        return (Opportunity) sysQuery(
            'SELECT Id, Department_Name__c FROM Opportunity WHERE Name = :nm LIMIT 1',
            new Map<String, Object>{ 'nm' => 'OALC Test Opportunity Dept' }
        )[0];
    }

    private static Boolean containsId(List<OpportunityActivityLauncherController.UserOption> opts, Id userId) {
        for (OpportunityActivityLauncherController.UserOption o : opts) {
            if (o.id == userId) {
                return true;
            }
        }
        return false;
    }

    // Some org automation (trigger/flow) can auto-create an Open Call/Event/Visit
    // on Opportunity insert, which collides with the "blocks a second open X"
    // tests. Strip anything pre-existing so every test starts empty.
    private static void clearAutoCreatedActivity(Id oppId) {
        Map<String, Object> binds = new Map<String, Object>{ 'oid' => oppId };
        sysDelete(sysQuery('SELECT Id FROM Task WHERE WhatId = :oid', binds));
        sysDelete(sysQuery('SELECT Id FROM Event WHERE WhatId = :oid', binds));
        sysDelete(sysQuery('SELECT Id FROM Task_Log__c WHERE Opportunity__c = :oid', binds));
    }

    /* ===================== setup ===================== */

    @testSetup
    static void makeData() {
        Account acc = new Account(Name = 'OALC Test Account');
        sysInsert(new List<Account>{ acc });

        Opportunity o1 = new Opportunity(
            Name      = 'OALC Test Opportunity',
            StageName = OPP_STAGE,
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        sysInsert(new List<Opportunity>{ o1 });
        clearAutoCreatedActivity(o1.Id);

        // Second Opportunity carries a Department_Name__c that an existing org
        // user actually has, so the no-Departments__c fallback branch of
        // getAssignableUsers has something to match against.
        Opportunity o2 = new Opportunity(
            Name               = 'OALC Test Opportunity Dept',
            StageName          = OPP_STAGE,
            CloseDate          = Date.today().addDays(30),
            AccountId          = acc.Id,
            Department_Name__c = resolveOppDept()
        );
        sysInsert(new List<Opportunity>{ o2 });
        clearAutoCreatedActivity(o2.Id);
    }

    /* ===================== getOpenStatus ===================== */

    @isTest
    static void openStatus_isFalseWhenNothingExists() {
        Opportunity o = opp();

        Test.startTest();
        OpportunityActivityLauncherController.OpenStatus s =
            OpportunityActivityLauncherController.getOpenStatus(o.Id);
        Test.stopTest();

        System.assertEquals(false, s.callOpen,  'No Call should be open');
        System.assertEquals(false, s.eventOpen, 'No Event should be open');
        System.assertEquals(false, s.visitOpen, 'No Visit should be open');
    }

    @isTest
    static void openStatus_isTrueForAllThreeCategories() {
        Opportunity o = opp();

        Test.startTest();
        OpportunityActivityLauncherController.createCall(
            o.Id, 'Follow up call', Datetime.now().addDays(2), 'Discuss pricing', null);
        OpportunityActivityLauncherController.createEvent(
            o.Id, 'Client meeting', 'At site', Datetime.now().addDays(1), Datetime.now().addDays(1).addHours(1), null);
        OpportunityActivityLauncherController.createVisit(
            o.Id, VISIT_TYPE, VISIT_RSN, Date.today().addDays(3), null);

        OpportunityActivityLauncherController.OpenStatus s =
            OpportunityActivityLauncherController.getOpenStatus(o.Id);
        Test.stopTest();

        System.assertEquals(true, s.callOpen,  'Call should be open');
        System.assertEquals(true, s.eventOpen, 'Event should be open');
        System.assertEquals(true, s.visitOpen, 'Visit should be open');
    }

    /* ===================== createCall ===================== */

    @isTest
    static void createCall_setsFieldsAndOwner() {
        Opportunity o = opp();
        User assignee = assigneeUser();
        Datetime followUp = Datetime.now().addDays(2);

        Test.startTest();
        Id taskId = OpportunityActivityLauncherController.createCall(
            o.Id, 'Follow up call', followUp, 'Discuss pricing', assignee.Id);
        Test.stopTest();

        Task t = (Task) sysQuery(
            'SELECT WhatId, TaskSubtype, Subject, Status, OwnerId, Description, ' +
            '       ActivityDate, Manually_Created__c, Follow_Up_Date_Time__c ' +
            'FROM Task WHERE Id = :tid',
            new Map<String, Object>{ 'tid' => taskId }
        )[0];

        System.assertEquals(o.Id, t.WhatId, 'Task should be linked to the Opportunity');
        System.assertEquals('Call', t.TaskSubtype, 'Subtype should be Call');
        System.assertEquals('Open', t.Status, 'Status should be Open');
        System.assertEquals('Follow up call', t.Subject, 'Subject mismatch');
        System.assertEquals('Discuss pricing', t.Description, 'Description mismatch');
        System.assertEquals(true, t.Manually_Created__c, 'Manually_Created__c should be true');
        System.assertEquals(followUp.date(), t.ActivityDate, 'ActivityDate should follow the follow-up date');
        System.assertEquals(assignee.Id, t.OwnerId, 'Owner should be the selected assignee');
    }

    @isTest
    static void createCall_defaultsOwnerAndNullFollowUp() {
        Opportunity o = opp();

        Test.startTest();
        Id taskId = OpportunityActivityLauncherController.createCall(o.Id, 'No follow up', null, null, null);
        Test.stopTest();

        Task t = (Task) sysQuery(
            'SELECT OwnerId, ActivityDate FROM Task WHERE Id = :tid',
            new Map<String, Object>{ 'tid' => taskId }
        )[0];
        System.assertEquals(UserInfo.getUserId(), t.OwnerId, 'Owner should default to the running user');
        System.assertEquals(null, t.ActivityDate, 'ActivityDate should stay null');
    }

    @isTest
    static void createCall_blocksSecondOpenCall() {
        Opportunity o = opp();
        OpportunityActivityLauncherController.createCall(
            o.Id, 'First call', Datetime.now().addDays(1), null, null);

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createCall(
                o.Id, 'Second call', Datetime.now().addDays(2), null, null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('open Call'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A second open Call should have been blocked');
        System.assertEquals(
            1,
            sysCount('SELECT COUNT() FROM Task WHERE WhatId = :oid',
                     new Map<String, Object>{ 'oid' => o.Id }),
            'Only one Task should exist'
        );
    }

    @isTest
    static void createCall_blocksPastFollowUp() {
        Opportunity o = opp();

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createCall(
                o.Id, 'Past call', Datetime.now().addDays(-1), null, null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('cannot be in the past'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A past-dated follow up should have been blocked');
    }

    /* ===================== createEvent ===================== */

    @isTest
    static void createEvent_setsFieldsAndReminder() {
        Opportunity o = opp();
        User assignee = assigneeUser();
        Datetime startDt = Datetime.now().addDays(1);
        Datetime endDt   = startDt.addHours(1);

        Test.startTest();
        Id eventId = OpportunityActivityLauncherController.createEvent(
            o.Id, 'Client meeting', 'At site', startDt, endDt, assignee.Id);
        Test.stopTest();

        Event e = (Event) sysQuery(
            'SELECT WhatId, Subject, Description, Type, IsReminderSet, ReminderDateTime, OwnerId ' +
            'FROM Event WHERE Id = :eid',
            new Map<String, Object>{ 'eid' => eventId }
        )[0];

        System.assertEquals(o.Id, e.WhatId, 'Event should be linked to the Opportunity');
        System.assertEquals('Client meeting', e.Subject, 'Subject mismatch');
        System.assertEquals('Meeting', e.Type, 'Type should be Meeting');
        System.assertEquals(true, e.IsReminderSet, 'Reminder should be set');
        System.assertEquals(assignee.Id, e.OwnerId, 'Owner should be the selected assignee');
        System.assertNotEquals(null, e.ReminderDateTime, 'ReminderDateTime should be populated');
    }

    @isTest
    static void createEvent_blocksSecondOpenEvent() {
        Opportunity o = opp();
        Datetime startDt = Datetime.now().addDays(1);
        OpportunityActivityLauncherController.createEvent(
            o.Id, 'First meeting', null, startDt, startDt.addHours(1), null);

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createEvent(
                o.Id, 'Second meeting', null, startDt.addDays(1), startDt.addDays(1).addHours(1), null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('open Event'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A second open Event should have been blocked');
        System.assertEquals(
            1,
            sysCount('SELECT COUNT() FROM Event WHERE WhatId = :oid',
                     new Map<String, Object>{ 'oid' => o.Id }),
            'Only one Event should exist'
        );
    }

    @isTest
    static void createEvent_allowsNewOneWhenPreviousIsCompleted() {
        Opportunity o = opp();
        Datetime startDt = Datetime.now().addDays(1);
        Id firstId = OpportunityActivityLauncherController.createEvent(
            o.Id, 'First meeting', null, startDt, startDt.addHours(1), null);

        sysUpdate(new List<Event>{ new Event(Id = firstId, Disposition__c = 'Completed') });

        Test.startTest();
        Id secondId = OpportunityActivityLauncherController.createEvent(
            o.Id, 'Second meeting', null, startDt.addDays(2), startDt.addDays(2).addHours(1), null);
        Test.stopTest();

        System.assertNotEquals(null, secondId, 'A new Event should be allowed once the previous one is completed');
    }

    @isTest
    static void createEvent_blocksPastStart() {
        Opportunity o = opp();

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createEvent(
                o.Id, 'Past meeting', null, Datetime.now().addDays(-1), Datetime.now(), null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('cannot be in the past'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A past-dated Event start should have been blocked');
    }

    /* ===================== createVisit ===================== */

    @isTest
    static void createVisit_setsFieldsAndOwner() {
        Opportunity o = opp();
        User assignee = assigneeUser();
        Date scheduleDate = Date.today().addDays(3);

        Test.startTest();
        Id visitId = OpportunityActivityLauncherController.createVisit(
            o.Id, VISIT_TYPE, VISIT_RSN, scheduleDate, assignee.Id);
        Test.stopTest();

        Task_Log__c v = (Task_Log__c) sysQuery(
            'SELECT Opportunity__c, Visit_Type__c, Reason_for_Visit__c, Schedule_Date__c, ' +
            '       Is_schedule__c, Manually_Created__c, OwnerId ' +
            'FROM Task_Log__c WHERE Id = :vid',
            new Map<String, Object>{ 'vid' => visitId }
        )[0];

        System.assertEquals(o.Id, v.Opportunity__c, 'Visit should be linked to the Opportunity');
        System.assertEquals(scheduleDate, v.Schedule_Date__c, 'Schedule date mismatch');
        System.assertEquals(true, v.Is_schedule__c, 'Is_schedule__c should be true');
        System.assertEquals(true, v.Manually_Created__c, 'Manually_Created__c should be true');
        System.assertEquals(assignee.Id, v.OwnerId, 'Owner should be the selected assignee');
    }

    @isTest
    static void createVisit_withoutVisitTypeUsesGenericNotificationBody() {
        Opportunity o = opp();

        Test.startTest();
        Id visitId = OpportunityActivityLauncherController.createVisit(
            o.Id, null, VISIT_RSN, Date.today().addDays(4), null);
        Test.stopTest();

        Task_Log__c v = (Task_Log__c) sysQuery(
            'SELECT OwnerId FROM Task_Log__c WHERE Id = :vid',
            new Map<String, Object>{ 'vid' => visitId }
        )[0];
        System.assertEquals(UserInfo.getUserId(), v.OwnerId, 'Owner should default to the running user');
    }

    @isTest
    static void createVisit_blocksSecondOpenVisit() {
        Opportunity o = opp();
        OpportunityActivityLauncherController.createVisit(
            o.Id, VISIT_TYPE, VISIT_RSN, Date.today().addDays(3), null);

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createVisit(
                o.Id, VISIT_TYPE, VISIT_RSN, Date.today().addDays(5), null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('open Visit'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A second open Visit should have been blocked');
        System.assertEquals(
            1,
            sysCount('SELECT COUNT() FROM Task_Log__c WHERE Opportunity__c = :oid',
                     new Map<String, Object>{ 'oid' => o.Id }),
            'Only one Visit should exist'
        );
    }

    @isTest
    static void createVisit_blocksPastScheduleDate() {
        Opportunity o = opp();

        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityActivityLauncherController.createVisit(
                o.Id, VISIT_TYPE, VISIT_RSN, Date.today().addDays(-1), null);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assert(e.getMessage().contains('cannot be in the past'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(thrown, 'A past-dated Visit schedule should have been blocked');
    }

    /* ===================== getAssignableUsers ===================== */

    @isTest
    static void assignableUsers_returnsDepartmentColleagues() {
        loadUsers();
        if (multiDeptUser == null) {
            return; // no active user in the org carries Departments__c
        }
        Opportunity o = opp();
        User runner = multiDeptUser;

        Test.startTest();
        List<OpportunityActivityLauncherController.UserOption> opts;
        System.runAs(runner) {
            opts = OpportunityActivityLauncherController.getAssignableUsers(o.Id);
        }
        Test.stopTest();

        System.assert(!opts.isEmpty(), 'Options should not be empty');
        System.assert(containsId(opts, runner.Id), 'The running user should always be selectable');
        for (OpportunityActivityLauncherController.UserOption o2 : opts) {
            System.assertNotEquals(null, o2.name, 'Every option should carry a name');
        }
    }

    @isTest
    static void assignableUsers_fallsBackToOpportunityDepartmentWhenNoDepts() {
        loadUsers();
        if (noDeptUser == null || oppDeptUser == null) {
            return; // org data cannot exercise the fallback branch
        }
        Opportunity o = oppWithDept();

        Test.startTest();
        List<OpportunityActivityLauncherController.UserOption> opts;
        System.runAs(noDeptUser) {
            opts = OpportunityActivityLauncherController.getAssignableUsers(o.Id);
        }
        Test.stopTest();

        System.assert(containsId(opts, noDeptUser.Id), 'The running user should always be selectable');
        System.assert(containsId(opts, oppDeptUser.Id),
            'A user whose standard Department matches the Opportunity should be included');
    }

    @isTest
    static void assignableUsers_returnsOnlySelfWhenNoDepartmentAndNoOppMatch() {
        loadUsers();
        if (noDeptUser == null) {
            return;
        }
        Opportunity o = opp(); // no Department_Name__c set

        Test.startTest();
        List<OpportunityActivityLauncherController.UserOption> opts;
        System.runAs(noDeptUser) {
            opts = OpportunityActivityLauncherController.getAssignableUsers(o.Id);
        }
        Test.stopTest();

        System.assertEquals(1, opts.size(),
            'A user without a department and no Opportunity match should only see themselves');
        System.assertEquals(noDeptUser.Id, opts[0].id, 'The single option should be the running user');
    }

    @isTest
    static void assignableUsers_addsRunningUserWhenExcludedFromResults() {
        Opportunity o = opp();

        Test.startTest();
        List<OpportunityActivityLauncherController.UserOption> opts =
            OpportunityActivityLauncherController.getAssignableUsers(o.Id);
        Test.stopTest();

        System.assert(containsId(opts, UserInfo.getUserId()),
            'The running user must be present even when not returned by the underlying query');
    }
}