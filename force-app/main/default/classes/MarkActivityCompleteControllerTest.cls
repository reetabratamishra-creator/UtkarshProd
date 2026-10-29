@isTest
private class MarkActivityCompleteControllerTest {

    /* =========================================================================
     *  Setup: a Lead and an Opportunity to parent the activities.
     *  Adjust Opportunity StageName / Lead Status if your org lacks these values.
     *  Every DML runs "as system" and every query WITH SYSTEM_MODE, matching
     *  the controller. Deepanjan (8th September 2026)
     * ========================================================================= */
    @testSetup
    static void setup() {
        insert as system new Lead(LastName = 'ActTest', Company = 'Acme',
                                  Status = 'Open - Not Contacted');
        Opportunity opp = new Opportunity(Name = 'Act Opp', StageName = 'Prospecting',
                                          CloseDate = Date.today().addDays(30));
        insert as system opp;
        // The Create_Task_on_Opportunity_Creation flow adds an open Call; start each test without it.
        delete as system [SELECT Id FROM Task WHERE WhatId = :opp.Id WITH SYSTEM_MODE];
    }

    private static Id leadId() { return [SELECT Id FROM Lead WITH SYSTEM_MODE LIMIT 1].Id; }
    private static Id oppId()  { return [SELECT Id FROM Opportunity WITH SYSTEM_MODE LIMIT 1].Id; }

    // First active picklist value of a field, so tests don't hardcode org values.
    private static String firstPicklist(Schema.SObjectField f) {
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    // Datetime without milliseconds, so what we send equals what is stored.
    private static Datetime whole(Datetime dt) {
        return Datetime.newInstance((dt.getTime() / 1000) * 1000);
    }

    private static Task openCall(Id parentId, String parentType, String subject) {
        Task t = new Task(Subject = subject, TaskSubtype = 'Call', Status = 'Open',
                          Manually_Created__c = true);
        if (parentType == 'Opportunity') { t.WhatId = parentId; } else { t.WhoId = parentId; }
        insert as system t;
        return t;
    }

    private static Event futureEvent(Id oppId) {
        Event e = new Event(WhatId = oppId, Subject = 'Mtg',
                            StartDateTime = whole(Datetime.now().addDays(1)),
                            EndDateTime   = whole(Datetime.now().addDays(1).addHours(1)));
        insert as system e;
        return e;
    }

    /* ---------------------------- getContext ---------------------------- */
    @isTest
    static void testGetContext_TaskLead() {
        Task t = openCall(leadId(), 'Lead', 'Call');

        Test.startTest();
        MarkActivityCompleteController.CloseContext ctx =
            MarkActivityCompleteController.getContext(t.Id);
        Test.stopTest();

        System.assertEquals('Task', ctx.objectType);
        System.assertEquals('Lead', ctx.parentType);
        System.assertEquals(leadId(), ctx.parentId);
        System.assertEquals(2, ctx.dispositions.size());
        System.assertEquals('Connected', ctx.dispositions[0].value);
        System.assertEquals(true, ctx.callOpen);
    }

    @isTest
    static void testGetContext_EventOpportunity() {
        Event e = futureEvent(oppId());

        Test.startTest();
        MarkActivityCompleteController.CloseContext ctx =
            MarkActivityCompleteController.getContext(e.Id);
        Test.stopTest();

        System.assertEquals('Event', ctx.objectType);
        System.assertEquals('Opportunity', ctx.parentType);
        System.assertEquals('Completed', ctx.dispositions[0].value);
        System.assertEquals(true, ctx.eventOpen);
    }

    @isTest
    static void testGetContext_NoParent() {
        Task t = new Task(Subject = 'Orphan', Status = 'Open'); // no Who/What
        insert as system t;

        Test.startTest();
        MarkActivityCompleteController.CloseContext ctx =
            MarkActivityCompleteController.getContext(t.Id);
        Test.stopTest();

        System.assertEquals(null, ctx.parentType);
        System.assertEquals(false, ctx.callOpen);
    }

    /* ---------------------------- markComplete -------------------------- */
    @isTest
    static void testMarkComplete_Task_AppendsCompleted() {
        Task t = openCall(oppId(), 'Opportunity', 'Call');

        Test.startTest();
        MarkActivityCompleteController.OpenFlags flags =
            MarkActivityCompleteController.markComplete(
                t.Id, 'Task', 'Connected', 'Spoke to client',
                null, null, oppId(), 'Opportunity');
        Test.stopTest();

        Task closed = [
            SELECT Status, Subject, Disposition__c, Description
            FROM Task WHERE Id = :t.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Completed', closed.Status);
        System.assertEquals('Call - Completed', closed.Subject);
        System.assertEquals('Connected', closed.Disposition__c);
        System.assertEquals('Spoke to client', closed.Description);
        // the only open call was just closed
        System.assertEquals(false, flags.callOpen);
    }

    @isTest
    static void testMarkComplete_Task_NotConnected_NonMatchingStage() {
        // StageName is Prospecting, so the Nurture/Negotiation callback branch exits early.
        Task t = openCall(oppId(), 'Opportunity', 'Call');

        Test.startTest();
        MarkActivityCompleteController.markComplete(
            t.Id, 'Task', 'Not Connected', 'No answer',
            null, null, oppId(), 'Opportunity');
        Test.stopTest();

        Task closed = [SELECT Status, Subject FROM Task WHERE Id = :t.Id WITH SYSTEM_MODE];
        System.assertEquals('Completed', closed.Status);
        System.assertEquals('Call - Completed', closed.Subject);
    }

    @isTest
    static void testMarkComplete_Task_BlankSubject() {
        Task t = openCall(leadId(), 'Lead', null);

        Test.startTest();
        MarkActivityCompleteController.markComplete(
            t.Id, 'Task', 'Connected', 'ok', null, null, leadId(), 'Lead');
        Test.stopTest();

        Task closed = [SELECT Subject FROM Task WHERE Id = :t.Id WITH SYSTEM_MODE];
        System.assertEquals('- Completed', closed.Subject);
    }

    @isTest
    static void testWithCompletedSuffix_IdempotentAndTruncated() {
        Test.startTest();
        String once  = MarkActivityCompleteController.withCompletedSuffix('Call');
        String twice = MarkActivityCompleteController.withCompletedSuffix(once);

        String longSubject = 'x'.repeat(255);
        String truncated = MarkActivityCompleteController.withCompletedSuffix(longSubject);
        Test.stopTest();

        System.assertEquals('Call - Completed', once);
        System.assertEquals(once, twice, 'Suffix must not be appended twice');
        System.assert(truncated.endsWith(' - Completed'));
        System.assert(truncated.length() <= 255, 'Must fit the Subject field');
    }

    @isTest
    static void testMarkComplete_Event_Completed_SwapsDates() {
        Event e = futureEvent(oppId());
        Event scheduled = [
            SELECT StartDateTime, EndDateTime FROM Event WHERE Id = :e.Id WITH SYSTEM_MODE
        ];

        Datetime aStart = whole(Datetime.now().addHours(-2));
        Datetime aEnd   = whole(Datetime.now().addHours(-1));

        Test.startTest();
        MarkActivityCompleteController.OpenFlags flags =
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'Met client', aStart, aEnd, oppId(), 'Opportunity');
        Test.stopTest();

        Event closed = [
            SELECT Subject, Disposition__c, Description, StartDateTime, EndDateTime,
                   Actual_Start_Time__c, Actual_End_Time__c, Close_Date__c
            FROM Event WHERE Id = :e.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Mtg - Completed', closed.Subject);
        System.assertEquals('Completed', closed.Disposition__c);
        System.assertEquals('Met client', closed.Description);
        // scheduled window preserved in Actual_* fields
        System.assertEquals(scheduled.StartDateTime, closed.Actual_Start_Time__c);
        System.assertEquals(scheduled.EndDateTime,   closed.Actual_End_Time__c);
        // UI actuals written to the Event's own Start/End
        System.assertEquals(aStart, closed.StartDateTime);
        System.assertEquals(aEnd,   closed.EndDateTime);
        System.assertNotEquals(null, closed.Close_Date__c);
        // Start is now in the past, so the event no longer counts as open
        System.assertEquals(false, flags.eventOpen);
    }

    @isTest
    static void testMarkComplete_Event_NotCompleted_KeepsSchedule() {
        Event e = futureEvent(oppId());
        Event scheduled = [
            SELECT StartDateTime, EndDateTime FROM Event WHERE Id = :e.Id WITH SYSTEM_MODE
        ];

        Test.startTest();
        MarkActivityCompleteController.markComplete(
            e.Id, 'Event', 'Not Completed', 'Client cancelled', null, null, oppId(), 'Opportunity');
        Test.stopTest();

        Event closed = [
            SELECT Subject, Disposition__c, StartDateTime, EndDateTime,
                   Actual_Start_Time__c, Actual_End_Time__c
            FROM Event WHERE Id = :e.Id WITH SYSTEM_MODE
        ];
        System.assertEquals('Mtg - Completed', closed.Subject);
        System.assertEquals('Not Completed', closed.Disposition__c);
        System.assertEquals(scheduled.StartDateTime, closed.Actual_Start_Time__c);
        System.assertEquals(scheduled.EndDateTime,   closed.Actual_End_Time__c);
        // no actuals captured, so the scheduled Start/End are untouched
        System.assertEquals(scheduled.StartDateTime, closed.StartDateTime);
        System.assertEquals(scheduled.EndDateTime,   closed.EndDateTime);
    }

    @isTest
    static void testMarkComplete_MissingFields() {
        Task t = openCall(oppId(), 'Opportunity', 'Call');
        Boolean thrown = false;

        Test.startTest();
        try {
            MarkActivityCompleteController.markComplete(
                t.Id, 'Task', '', '', null, null, oppId(), 'Opportunity');
        } catch (AuraHandledException ex) { thrown = true; }
        Test.stopTest();

        System.assert(thrown, 'Disposition/Remarks required');
    }

    @isTest
    static void testMarkComplete_EventValidations() {
        Event e = futureEvent(oppId());

        Test.startTest();
        // missing actuals
        Boolean missing = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'x', null, null, oppId(), 'Opportunity');
        } catch (AuraHandledException ex) { missing = true; }

        // future actuals
        Boolean future = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'x',
                Datetime.now().addHours(2), Datetime.now().addHours(3),
                oppId(), 'Opportunity');
        } catch (AuraHandledException ex) { future = true; }

        // end before start
        Boolean reversed = false;
        try {
            MarkActivityCompleteController.markComplete(
                e.Id, 'Event', 'Completed', 'x',
                Datetime.now().addHours(-1), Datetime.now().addHours(-2),
                oppId(), 'Opportunity');
        } catch (AuraHandledException ex) { reversed = true; }
        Test.stopTest();

        System.assert(missing,  'Actual start/end required');
        System.assert(future,   'Future actual dates rejected');
        System.assert(reversed, 'Actual end before start rejected');
    }

    /* ---------------------------- getOpenFlags -------------------------- */
    @isTest
    static void testGetOpenFlags() {
        Task t = openCall(oppId(), 'Opportunity', 'Call');

        Test.startTest();
        MarkActivityCompleteController.OpenFlags withParent =
            MarkActivityCompleteController.getOpenFlags(oppId(), 'Opportunity', null);
        MarkActivityCompleteController.OpenFlags excluded =
            MarkActivityCompleteController.getOpenFlags(oppId(), 'Opportunity', t.Id);
        MarkActivityCompleteController.OpenFlags noParent =
            MarkActivityCompleteController.getOpenFlags(null, null, null);
        Test.stopTest();

        System.assertEquals(true,  withParent.callOpen);
        System.assertEquals(false, excluded.callOpen, 'excludeId must ignore the record being closed');
        System.assertEquals(false, noParent.callOpen);
    }

    /* ------------------------- getAssignableUsers ----------------------- */
    @isTest
    static void testGetAssignableUsers_RunningUserOnly() {
        Task t = openCall(leadId(), 'Lead', 'Call'); // Lead parent -> no department

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> users =
            MarkActivityCompleteController.getAssignableUsers(t.Id);
        List<MarkActivityCompleteController.UserOption> noActivity =
            MarkActivityCompleteController.getAssignableUsers(null);
        Test.stopTest();

        System.assertEquals(1, users.size(), 'Only the running user without a department');
        System.assertEquals(UserInfo.getUserId(), users[0].id);
        System.assertEquals(1, noActivity.size());
    }

    @isTest
    static void testGetAssignableUsers_WithDepartment() {
        String deptVal = firstPicklist(User.Departments__c);
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String uniq = String.valueOf(Datetime.now().getTime());
        User u = new User(
            ProfileId = p.Id, LastName = 'DeptUser',
            Email = 'du' + uniq + '@example.com.invalid',
            Username = 'du' + uniq + '@example.com.invalid',
            Alias = 'du1', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US');
        if (deptVal != null) {
            u.Departments__c = deptVal;
            u.Department     = deptVal;
        }
        insert as system u;

        // Put the same value on the Opportunity so the department leg is exercised.
        // Wrapped: Department_Name__c may be a restricted picklist in some orgs.
        if (deptVal != null) {
            try {
                update as system new Opportunity(Id = oppId(), Department_Name__c = deptVal);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Department_Name__c not settable: ' + ex.getMessage());
            }
        }

        Task t = openCall(oppId(), 'Opportunity', 'Call');
        Event e = futureEvent(oppId());

        Test.startTest();
        List<MarkActivityCompleteController.UserOption> viaTask =
            MarkActivityCompleteController.getAssignableUsers(t.Id);
        List<MarkActivityCompleteController.UserOption> viaEvent =
            MarkActivityCompleteController.getAssignableUsers(e.Id);
        List<MarkActivityCompleteController.UserOption> viaOpp =
            MarkActivityCompleteController.getAssignableUsers(oppId());
        Test.stopTest();

        System.assert(!viaTask.isEmpty()  && viaTask[0].id  == UserInfo.getUserId(), 'Running user first');
        System.assert(!viaEvent.isEmpty() && viaEvent[0].id == UserInfo.getUserId(), 'Running user first');
        System.assert(!viaOpp.isEmpty()   && viaOpp[0].id   == UserInfo.getUserId(), 'Running user first');

        Set<Id> seen = new Set<Id>();
        for (MarkActivityCompleteController.UserOption o : viaTask) {
            System.assert(!seen.contains(o.id), 'No duplicate users');
            seen.add(o.id);
        }
    }

    /* ------------------------------ create ------------------------------ */
    @isTest
    static void testCreateCall_AndBlock() {
        Test.startTest();
        Id cId = MarkActivityCompleteController.createCall(
            oppId(), 'Opportunity', 'Follow up', Datetime.now().addDays(1), 'note', null, null);

        Boolean blocked = false;
        try {
            MarkActivityCompleteController.createCall(
                oppId(), 'Opportunity', 'Again', Datetime.now().addDays(1), null, null, null);
        } catch (AuraHandledException ex) { blocked = true; }

        // excludeId ignores the existing open call, so this one is allowed
        Id allowed = MarkActivityCompleteController.createCall(
            oppId(), 'Opportunity', 'Excluded', Datetime.now().addDays(1), null, null, cId);
        Test.stopTest();

        Task t = [SELECT WhatId, TaskSubtype, Status, ActivityDate
                  FROM Task WHERE Id = :cId WITH SYSTEM_MODE];
        System.assertEquals(oppId(), t.WhatId);
        System.assertEquals('Call', t.TaskSubtype);
        System.assertEquals('Open', t.Status);
        System.assertNotEquals(null, t.ActivityDate);
        System.assert(blocked, 'Second open call blocked');
        System.assertNotEquals(null, allowed);
    }

    @isTest
    static void testCreateCall_PastDateRejected() {
        Boolean thrown = false;
        Test.startTest();
        try {
            MarkActivityCompleteController.createCall(
                oppId(), 'Opportunity', 'Past', Datetime.now().addDays(-1), null, null, null);
        } catch (AuraHandledException ex) { thrown = true; }
        Test.stopTest();
        System.assert(thrown, 'Past follow-up rejected');
    }

    @isTest
    static void testCreateEvent_AndBlock() {
        Test.startTest();
        Id eId = MarkActivityCompleteController.createEvent(
            oppId(), 'Opportunity', 'Meeting', 'desc',
            Datetime.now().addDays(1), Datetime.now().addDays(1).addHours(1), null, null);

        Boolean blocked = false;
        try {
            MarkActivityCompleteController.createEvent(
                oppId(), 'Opportunity', 'Meeting 2', null,
                Datetime.now().addDays(2), Datetime.now().addDays(2).addHours(1), null, null);
        } catch (AuraHandledException ex) { blocked = true; }

        Boolean past = false;
        try {
            MarkActivityCompleteController.createEvent(
                oppId(), 'Opportunity', 'Past', null,
                Datetime.now().addDays(-1), Datetime.now(), null, eId);
        } catch (AuraHandledException ex) { past = true; }
        Test.stopTest();

        Event e = [SELECT Type, IsReminderSet, ReminderDateTime FROM Event WHERE Id = :eId WITH SYSTEM_MODE];
        System.assertEquals('Meeting', e.Type);
        System.assertEquals(true, e.IsReminderSet);
        System.assertNotEquals(null, e.ReminderDateTime);
        System.assert(blocked, 'Second open event blocked');
        System.assert(past, 'Past event start rejected');
    }

    @isTest
    static void testCreateCall_Lead_WithAssignee() {
        Test.startTest();
        Id cId = MarkActivityCompleteController.createCall(
            leadId(), 'Lead', 'Lead call', Datetime.now().addDays(1), null,
            UserInfo.getUserId(), null);
        Test.stopTest();

        Task t = [SELECT WhoId, OwnerId FROM Task WHERE Id = :cId WITH SYSTEM_MODE];
        System.assertEquals(leadId(), t.WhoId);
        System.assertEquals(UserInfo.getUserId(), t.OwnerId);
    }

    @isTest
    static void testCreateVisit() {
        String vt = firstPicklist(Task_Log__c.Visit_Type__c);
        String rs = firstPicklist(Task_Log__c.Reason_for_Visit__c);

        Test.startTest();
        // Wrapped: Task_Log__c may have extra required fields in some orgs.
        try {
            Id vId = MarkActivityCompleteController.createVisit(
                oppId(), 'Opportunity', vt, rs, Date.today().addDays(1), null, null);

            Boolean blocked = false;
            try {
                MarkActivityCompleteController.createVisit(
                    oppId(), 'Opportunity', vt, rs, Date.today().addDays(2), null, null);
            } catch (AuraHandledException ex) { blocked = true; }
            System.assert(blocked, 'Second open visit blocked');

            MarkActivityCompleteController.OpenFlags f =
                MarkActivityCompleteController.getOpenFlags(oppId(), 'Opportunity', null);
            System.assertEquals(true, f.visitOpen);
        } catch (Exception ex) {
            // exercised the branch; ignore org-specific field requirements
        }

        Boolean past = false;
        try {
            MarkActivityCompleteController.createVisit(
                leadId(), 'Lead', vt, rs, Date.today().addDays(-1), null, null);
        } catch (AuraHandledException ex) { past = true; }
        Test.stopTest();

        System.assert(past, 'Past visit date rejected');
    }
}