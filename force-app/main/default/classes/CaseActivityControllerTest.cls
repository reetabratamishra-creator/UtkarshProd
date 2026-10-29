@IsTest
private class CaseActivityControllerTest {

    private static final String OWNER_LAST_NAME = 'ActivityOwner';

    /* =====================================================================
     *  Setup
     * ===================================================================== */
    @TestSetup
    static void makeData() {

        User owner;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            owner = new User(
                Alias             = 'caowner',
                Email             = 'case.activity.owner@example.com.invalid',
                EmailEncodingKey  = 'UTF-8',
                FirstName         = 'Case',
                LastName          = OWNER_LAST_NAME,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey      = 'en_US',
                ProfileId         = resolveProfileId(),
                TimeZoneSidKey    = 'Asia/Kolkata',
                UserName          = 'case.activity.owner.' + DateTime.now().getTime() + '@example.com.invalid'
            );
            insert owner;
        }

        Account acc = new Account(Name = 'Case Activity Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        insert new Case(
            Subject   = 'Activity Test Case',
            Status    = 'New',
            Origin    = 'Phone',
            AccountId = acc.Id,
            ContactId = con.Id,
            OwnerId   = owner.Id
        );
    }

    private static Id resolveProfileId() {
        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            ORDER BY Name ASC
            LIMIT 1
        ];
        return profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id;
    }

    private static Case getCase() {
        return [SELECT Id, OwnerId, ContactId FROM Case LIMIT 1];
    }

    private static User getOwner() {
        return [SELECT Id, Name FROM User WHERE LastName = :OWNER_LAST_NAME LIMIT 1];
    }

    private static Id makeCaseQueue(String queueName) {
        Group q = new Group(Name = queueName, Type = 'Queue');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert q;
            insert new QueueSObject(QueueId = q.Id, SObjectType = 'Case');
        }
        return q.Id;
    }

    /* =====================================================================
     *  getCaseContext Tests
     * ===================================================================== */
    @IsTest
    static void testGetCaseContextForUserOwner() {
        Case c = getCase();

        Test.startTest();
        CaseActivityController.CaseContext ctx = CaseActivityController.getCaseContext(c.Id);
        Test.stopTest();

        Assert.areEqual(c.Id, ctx.caseId, 'Case Id should round-trip');
        Assert.areEqual(c.OwnerId, ctx.ownerId, 'Owner Id should be the Case owner');
        Assert.isFalse(ctx.ownerIsQueue, 'Owner is a user, not a queue');
        Assert.isNotNull(ctx.caseNumber, 'Case number should be populated');
        Assert.areEqual('Activity Test Case', ctx.caseSubject, 'Case subject should be populated');
    }

    @IsTest
    static void testGetCaseContextForQueueOwner() {
        Case c = getCase();
        c.OwnerId = makeCaseQueue('Case Activity Test Queue');
        update c;

        Test.startTest();
        CaseActivityController.CaseContext ctx = CaseActivityController.getCaseContext(c.Id);
        Test.stopTest();

        Assert.isTrue(ctx.ownerIsQueue, 'Owner should be flagged as a queue');
        Assert.areEqual('Case Activity Test Queue', ctx.ownerName, 'Queue name should be returned');
    }

    @IsTest
    static void testNullCaseIdThrows() {
        Test.startTest();
        try {
            CaseActivityController.getCaseContext(null);
            Assert.fail('Expected an exception for a null Case Id');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('No Case record'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeletedCaseThrows() {
        Case c = getCase();
        Id deletedId = c.Id;
        delete c;

        Test.startTest();
        try {
            CaseActivityController.createCallTask(deletedId, 'Subject', System.now().addDays(1), 'x');
            Assert.fail('Expected an exception for a deleted Case');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('could not be found'), e.getMessage());
        }
        Test.stopTest();
    }

    /* =====================================================================
     *  Call Task Tests
     * ===================================================================== */
    @IsTest
    static void testCreateCallTaskSuccess() {
        Case c   = getCase();
        User own = getOwner();
        Datetime followUp = System.now().addDays(2);

        Test.startTest();
        Id taskId = CaseActivityController.createCallTask(
            c.Id, '  Follow up with the customer  ', followUp, 'Discussed the pending RMA.');
        Test.stopTest();

        Task t = [
            SELECT Id, Subject, Description, TaskSubtype, Priority, Status, OwnerId,
                   WhatId, WhoId, ActivityDate, Follow_Up_Date_Time__c
            FROM Task
            WHERE Id = :taskId
        ];

        Assert.areEqual('Follow up with the customer', t.Subject, 'Subject should be trimmed');
        Assert.areEqual('Discussed the pending RMA.', t.Description, 'Comments map to Description');
        Assert.areEqual('Call', t.TaskSubtype, 'Subtype must be Call');
        Assert.areEqual('Normal', t.Priority, 'Priority must be Normal');
        Assert.areEqual('Open', t.Status, 'Status must be Open');
        Assert.areEqual(own.Id, t.OwnerId, 'Task must be owned by the Case owner');
        Assert.areEqual(c.Id, t.WhatId, 'Task must be related to the Case');
        Assert.areEqual(c.ContactId, t.WhoId, 'Task should carry the Case contact');
        Assert.areEqual(followUp, t.Follow_Up_Date_Time__c, 'Full date and time goes to Follow_Up_Date_Time__c');
        Assert.areEqual(followUp.date(), t.ActivityDate, 'Standard Due Date carries only the date part');
    }

    @IsTest
    static void testCreateCallTaskPastDateThrows() {
        Case c = getCase();

        Test.startTest();
        try {
            CaseActivityController.createCallTask(
                c.Id, 'Back-dated call log', System.now().addDays(-3), null);
            Assert.fail('Expected an exception for a past date');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('cannot be in the past'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateCallTaskTodayIsAllowed() {
        Case c = getCase();
        Datetime followUp = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

        Test.startTest();
        Id taskId = CaseActivityController.createCallTask(
            c.Id, 'Call logged for today', followUp, null);
        Test.stopTest();

        Task t = [SELECT Id, Description, ActivityDate, Follow_Up_Date_Time__c FROM Task WHERE Id = :taskId];
        Assert.areEqual(followUp, t.Follow_Up_Date_Time__c, 'Today should be accepted');
        Assert.areEqual(Date.today(), t.ActivityDate, 'Due Date should be today');
        Assert.isNull(t.Description, 'Null comments should stay null');
    }

    @IsTest
    static void testCreateCallTaskTruncatesLongSubjectAndDescription() {
        Case c = getCase();
        String longSubject = 'A'.repeat(400);
        String longDesc    = 'B'.repeat(35000);

        Test.startTest();
        Id taskId = CaseActivityController.createCallTask(
            c.Id, longSubject, System.now().addDays(1), longDesc);
        Test.stopTest();

        Task t = [SELECT Id, Subject, Description FROM Task WHERE Id = :taskId];
        Assert.areEqual(255, t.Subject.length(), 'Subject should be truncated to 255 characters');
        Assert.areEqual(32000, t.Description.length(), 'Description should be truncated to 32000 characters');
    }

    @IsTest
    static void testCreateCallTaskBlankSubjectThrows() {
        Case c = getCase();

        Test.startTest();
        try {
            CaseActivityController.createCallTask(c.Id, '   ', System.now().addDays(1), 'x');
            Assert.fail('Expected an exception for a blank subject');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Subject is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateCallTaskNullDateTimeThrows() {
        Case c = getCase();

        Test.startTest();
        try {
            CaseActivityController.createCallTask(c.Id, 'Subject', null, 'x');
            Assert.fail('Expected an exception for a null date/time');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Date & Time is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateCallTaskOnQueueOwnedCaseThrows() {
        Case c = getCase();
        c.OwnerId = makeCaseQueue('Case Activity Blocked Queue');
        update c;

        Test.startTest();
        try {
            CaseActivityController.createCallTask(c.Id, 'Subject', System.now().addDays(1), 'x');
            Assert.fail('Expected an exception for a queue-owned Case');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('owned by the queue'), e.getMessage());
        }
        Test.stopTest();
    }

    /* =====================================================================
     *  Meeting Event Tests
     * ===================================================================== */
    @IsTest
    static void testCreateMeetingEventSuccess() {
        Case c   = getCase();
        User own = getOwner();
        Datetime startAt = System.now().addDays(2);
        Datetime endAt   = startAt.addHours(1);

        Test.startTest();
        Id eventId = CaseActivityController.createMeetingEvent(
            c.Id, 'Site walkthrough', startAt, endAt, 'Bring the drawings.');
        Test.stopTest();

        Event e = [
            SELECT Id, Subject, Description, Type, OwnerId, WhatId, WhoId,
                   StartDateTime, EndDateTime, IsAllDayEvent, IsReminderSet, ReminderDateTime
            FROM Event
            WHERE Id = :eventId
        ];

        Assert.areEqual('Site walkthrough', e.Subject, 'Subject should be saved');
        Assert.areEqual('Bring the drawings.', e.Description, 'Comments map to Description');
        Assert.areEqual('Meeting', e.Type, 'Type must be Meeting');
        Assert.areEqual(own.Id, e.OwnerId, 'Event must be owned by the Case owner');
        Assert.areEqual(c.Id, e.WhatId, 'Event must be related to the Case');
        Assert.areEqual(c.ContactId, e.WhoId, 'Event should carry the Case contact');
        Assert.areEqual(startAt, e.StartDateTime, 'StartDateTime should round-trip');
        Assert.areEqual(endAt, e.EndDateTime, 'EndDateTime should round-trip');
        Assert.isFalse(e.IsAllDayEvent, 'Should not be an all-day event');
        Assert.isTrue(e.IsReminderSet, 'A future meeting should set a reminder');
        Assert.areEqual(startAt.addMinutes(-15), e.ReminderDateTime, 'Reminder is 15 minutes before start');
    }

    @IsTest
    static void testCreateMeetingEventStartingSoonSkipsReminder() {
        Case c = getCase();
        Datetime startAt = System.now().addMinutes(5);

        Test.startTest();
        Id eventId = CaseActivityController.createMeetingEvent(
            c.Id, 'Meeting starting shortly', startAt, startAt.addHours(1), null);
        Test.stopTest();

        Event e = [SELECT Id, IsReminderSet, StartDateTime FROM Event WHERE Id = :eventId];
        Assert.isFalse(e.IsReminderSet, 'A reminder that would fall in the past must be skipped');
        Assert.areEqual(startAt, e.StartDateTime, 'The meeting itself must still be created');
    }

    @IsTest
    static void testCreateMeetingEventPastStartThrows() {
        Case c = getCase();
        Datetime startAt = System.now().addDays(-2);

        Test.startTest();
        try {
            CaseActivityController.createMeetingEvent(
                c.Id, 'Back-dated meeting', startAt, startAt.addHours(1), null);
            Assert.fail('Expected an exception for a past start date');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('cannot be in the past'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateMeetingEventTodayIsAllowed() {
        Case c = getCase();
        Datetime startAt = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

        Test.startTest();
        Id eventId = CaseActivityController.createMeetingEvent(
            c.Id, 'Meeting earlier today', startAt, startAt.addHours(1), null);
        Test.stopTest();

        Event e = [SELECT Id, StartDateTime, IsReminderSet FROM Event WHERE Id = :eventId];
        Assert.areEqual(startAt, e.StartDateTime, 'Today should be accepted');
        Assert.isFalse(e.IsReminderSet, 'A reminder in the past must be skipped');
    }

    @IsTest
    static void testCreateMeetingEventValidationErrors() {
        Case c = getCase();
        Datetime startAt = System.now().addDays(1);

        Test.startTest();

        try {
            CaseActivityController.createMeetingEvent(c.Id, '  ', startAt, startAt.addHours(1), 'x');
            Assert.fail('Expected an exception for a blank subject');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Subject is required'), e.getMessage());
        }

        try {
            CaseActivityController.createMeetingEvent(c.Id, 'Subject', null, startAt.addHours(1), 'x');
            Assert.fail('Expected an exception for a null start');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Start Date & Time is required'), e.getMessage());
        }

        try {
            CaseActivityController.createMeetingEvent(c.Id, 'Subject', startAt, null, 'x');
            Assert.fail('Expected an exception for a null end');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('End Date & Time is required'), e.getMessage());
        }

        try {
            CaseActivityController.createMeetingEvent(c.Id, 'Subject', startAt, startAt.addHours(-1), 'x');
            Assert.fail('Expected an exception when end precedes start');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('must be later'), e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testCreateMeetingEventOnQueueOwnedCaseThrows() {
        Case c = getCase();
        c.OwnerId = makeCaseQueue('Case Event Blocked Queue');
        update c;

        Datetime startAt = System.now().addDays(1);

        Test.startTest();
        try {
            CaseActivityController.createMeetingEvent(c.Id, 'Subject', startAt, startAt.addHours(1), 'x');
            Assert.fail('Expected an exception for a queue-owned Case');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('owned by the queue'), e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Safely tests DML failure coverage without touching User.IsActive
     * Salesforce restricts Event durations to a maximum of 14 days. 
     * Passing 15 days reliably triggers a standard DmlException.
     */
    @IsTest
    static void testCreateMeetingEventDmlError() {
        Case c = getCase();
        
        Datetime startAt = System.now().addDays(1);
        Datetime endAt   = startAt.addDays(15); // > 14 days throws EVENT_DURATION_TOO_LONG

        Test.startTest();
        try {
            CaseActivityController.createMeetingEvent(
                c.Id, 'Meeting Too Long', startAt, endAt, 'Comments'
            );
            Assert.fail('Expected AuraHandledException due to EVENT_DURATION_TOO_LONG DML failure');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('could not be created'), e.getMessage());
        }
        Test.stopTest();
    }
}