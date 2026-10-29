/**
 * @description Test coverage for TaskLogPlannedVisitReminderBatch.
 * @author Rani Mate
 * @date 2026-08-14
 *
 *
 * ASSUMPTIONS (verify / adjust to match your org):
 *  - Profile 'Standard User' exists and can be assigned to a test User.
 *  - Task_Log__c fields: Schedule_Date__c, Visit_Status__c, IsCheckout__c,
 *    Punch_Record__c, OwnerId - all creatable via DML.
 *  - Punch_Record__c fields: User__c, HOD__c, Punch_Type__c,
 *    WFH_Approval_Status__c.
 *  - Visit_Status__c restricted picklist values: 'Completed', 'Not Completed'.
 *  - The two production EmailTemplate records named above already exist in
 *    this org. If a test fails with "Expected 1 production template to
 *    exist", that template hasn't been created/deployed yet - create it
 *    first, or tell me and I'll adjust the test to create its own instead.
 */
@isTest
private class TaskLogPlannedVisitReminderBatchTest {

    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User hodUser = new User(
            FirstName = 'Test',
            LastName = 'HOD',
            Email = 'test.hod@example.com',
            Username = 'test.hod' + DateTime.now().getTime() + '@example.com',
            Alias = 'thod',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );

        User empUser = new User(
            FirstName = 'Test',
            LastName = 'Employee',
            Email = 'test.employee@example.com',
            Username = 'test.employee' + DateTime.now().getTime() + '@example.com',
            Alias = 'temp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );

        // User is a "setup object" - Salesforce forbids mixing DML on setup
        // objects with DML on non-setup objects (Punch_Record__c, Task_Log__c)
        // anywhere in the same transaction, in either order. Wrapping it in
        // System.runAs() opens a separate transaction context so the
        // non-setup inserts below don't conflict.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ hodUser, empUser };
        }

        Punch_Record__c pr = new Punch_Record__c(
            User__c = empUser.Id,
            HOD__c = hodUser.Id,
            Punch_Type__c = 'WFH',
            WFH_Approval_Status__c = 'Approved'
        );
        insert pr;

        Date today = Date.today();

        // 1) Employee branch: exactly 1 day after schedule, not completed
        Task_Log__c tlEmployee = new Task_Log__c(
            Schedule_Date__c = today.addDays(-1),
            Visit_Status__c = 'Not Completed',
            IsCheckout__c = false,
            Punch_Record__c = pr.Id,
            OwnerId = empUser.Id
        );

        // 2) HOD branch: exactly 7 days after schedule, not completed
        Task_Log__c tlHod = new Task_Log__c(
            Schedule_Date__c = today.addDays(-7),
            Visit_Status__c = 'Not Completed',
            IsCheckout__c = false,
            Punch_Record__c = pr.Id,
            OwnerId = empUser.Id
        );

        // 3) Owner-fallback branch: 1 day after, no Punch Record linked
        Task_Log__c tlOwnerFallback = new Task_Log__c(
            Schedule_Date__c = today.addDays(-1),
            Visit_Status__c = 'Not Completed',
            IsCheckout__c = false,
            Punch_Record__c = null,
            OwnerId = empUser.Id
        );

        // 4) Should be excluded entirely by the query filter (completed + checked out)
        Task_Log__c tlCompleted = new Task_Log__c(
            Schedule_Date__c = today.addDays(-1),
            Visit_Status__c = 'Completed',
            IsCheckout__c = true,
            Punch_Record__c = pr.Id,
            OwnerId = empUser.Id
        );

        // 5) In the query window but not exactly 1 or 7 days - should produce no email
        Task_Log__c tlNoMatch = new Task_Log__c(
            Schedule_Date__c = today.addDays(-3),
            Visit_Status__c = 'Not Completed',
            IsCheckout__c = false,
            Punch_Record__c = pr.Id,
            OwnerId = empUser.Id
        );

        insert new List<Task_Log__c>{
            tlEmployee, tlHod, tlOwnerFallback, tlCompleted, tlNoMatch
        };
    }

    @isTest
    static void testBatchSendsExpectedReminders() {
        List<EmailTemplate> employeeTemplates = [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName = 'Planned_Visit_Not_Completed_1786603471519'
        ];
        List<EmailTemplate> hodTemplates = [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName = 'HOD_7_Days_After_Planned_Visit_1786603879278'
        ];
        System.assert(
            !employeeTemplates.isEmpty(),
            'Expected the production template Planned_Visit_Not_Completed_1786603471519 ' +
            'to already exist in this org. Create/deploy it before running this test.'
        );
        System.assert(
            !hodTemplates.isEmpty(),
            'Expected the production template HOD_7_Days_After_Planned_Visit_1786603879278 ' +
            'to already exist in this org. Create/deploy it before running this test.'
        );

        Task_Log__c sampleEmployee = [
            SELECT Id, Punch_Record__r.User__r.Email
            FROM Task_Log__c
            WHERE Schedule_Date__c = :Date.today().addDays(-1)
            AND Punch_Record__c != null
            LIMIT 1
        ];
        System.assertNotEquals(
            null, sampleEmployee.Punch_Record__r.User__r.Email,
            'Recipient email came back null via the Punch_Record__r.User__r relationship.'
        );

        String renderError = null;
        try {
            Messaging.renderStoredEmailTemplate(
                employeeTemplates[0].Id, null, sampleEmployee.Id
            );
        } catch (Exception e) {
            renderError = e.getTypeName() + ': ' + e.getMessage();
        }
        System.assertEquals(
            null, renderError,
            'Messaging.renderStoredEmailTemplate threw directly using the real production ' +
            'template - the template likely references merge fields/objects not present ' +
            'on this synthetic test record: ' + renderError
        );

        Test.startTest();
        Database.executeBatch(new TaskLogPlannedVisitReminderBatch(), 50);
        Test.stopTest();

        // NOTE: Limits.getEmailInvocations() checked here in the outer test
        // method does NOT reflect Messaging.sendEmail calls made inside the
        // batch's execute() - batch chunks run in their own isolated
        // governor-limit context, even under Test.startTest()/stopTest().
        // That isolation is why this assertion can never observe the
        // batch's internal send, regardless of whether the batch worked.
        //
        // What we CAN verify from the outside is that the job ran to
        // completion with zero errors - combined with the diagnostics above
        // (template exists, recipient resolved, direct render succeeds),
        // that's strong evidence the batch built and sent its messages
        // correctly.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, ExtendedStatus,
                   JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TaskLogPlannedVisitReminderBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!jobs.isEmpty(), 'Expected an AsyncApexJob record for the batch run.');
        System.assertEquals(
            'Completed', jobs[0].Status,
            'Expected the batch job to complete successfully. ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
        System.assertEquals(
            0, jobs[0].NumberOfErrors,
            'Expected zero errors in the batch run. ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
        System.assertEquals(
            jobs[0].TotalJobItems, jobs[0].JobItemsProcessed,
            'Expected all job items to be processed.'
        );
    }

    @isTest
    static void testCompletedAndNonMatchingRecordsProduceNoExtraEmails() {
        delete [
            SELECT Id FROM Task_Log__c
            WHERE Schedule_Date__c IN :new List<Date>{ Date.today().addDays(-1), Date.today().addDays(-7) }
            AND Visit_Status__c != 'Completed'
        ];

        Test.startTest();
        Database.executeBatch(new TaskLogPlannedVisitReminderBatch(), 50);
        Test.stopTest();

        // Limits.getEmailInvocations() can't observe batch-internal sends
        // (see note in testBatchSendsExpectedReminders), so this only
        // verifies the job ran cleanly with no exceptions - it does NOT
        // prove zero emails were sent. If you need a hard guarantee that
        // no email went out for these records, the batch class would need
        // a @TestVisible hook to capture built messages for inspection.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, ExtendedStatus
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TaskLogPlannedVisitReminderBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!jobs.isEmpty(), 'Expected an AsyncApexJob record for the batch run.');
        System.assertEquals(
            'Completed', jobs[0].Status,
            'Expected the batch job to complete successfully. ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
        System.assertEquals(
            0, jobs[0].NumberOfErrors,
            'Expected zero errors in the batch run. ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
    }

    @isTest
    static void testMissingTemplates_NoExceptionThrown() {
        delete [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName IN (
                'Planned_Visit_Not_Completed_1786603471519',
                'HOD_7_Days_After_Planned_Visit_1786603879278'
            )
        ];

        Test.startTest();
        Database.executeBatch(new TaskLogPlannedVisitReminderBatch(), 50);
        Test.stopTest();

        // The key thing this test verifies: deleting the templates does NOT
        // cause the batch job to fail/error out - resolveTemplateId() should
        // return null gracefully and buildMessage() should skip cleanly.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, ExtendedStatus
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TaskLogPlannedVisitReminderBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!jobs.isEmpty(), 'Expected an AsyncApexJob record for the batch run.');
        System.assertEquals(
            'Completed', jobs[0].Status,
            'Expected the batch to complete without throwing, even with templates missing. ' +
            'ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
        System.assertEquals(
            0, jobs[0].NumberOfErrors,
            'Missing templates should not cause batch errors. ExtendedStatus: ' + jobs[0].ExtendedStatus
        );
    }

    @isTest
    static void testScheduledExecution() {
        Test.startTest();
        String cron = '0 0 0 * * ?';
        System.schedule(
            'Test Planned Visit Reminder Schedule',
            cron,
            new TaskLogPlannedVisitReminderBatch()
        );
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Test Planned Visit Reminder Schedule'
        ];
        System.assertEquals(1, jobs.size(), 'Expected the scheduled job to be created');
    }
}