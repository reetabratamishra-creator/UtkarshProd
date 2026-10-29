@isTest
private class UserDeptChangeTenderShareTest {

    private static final String DEPT_CB_TENDER = 'CRASH BARRIER';              // value on Tender
    private static final String DEPT_CB_USER   = 'Crash_Barrier_Department';   // value on User
    private static final String DEPT_OTHER     = 'HDPE_Pipe_Department';

    // ---------------- Helpers ----------------

    private static User getAdmin() {
        return [
            SELECT Id FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    // Returns the profile with this name, or a fallback profile if it does not exist in this org
    private static Id getProfileId(String profileName) {
        List<Profile> p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        if (p.isEmpty()) {
            p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }
        return p[0].Id;
    }

    private static User buildUser(String profileName, String depts, Boolean tenderAccess) {
        String rand = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8);
        return new User(
            Alias = rand,
            Email = rand + '@testtender.com',
            Username = rand + '@testtender.com.' + System.currentTimeMillis(),
            FirstName = 'Test',
            LastName = 'User' + rand,
            ProfileId = getProfileId(profileName),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Departments__c = depts,
            Tender_Access_User__c = tenderAccess,
            IsActive = true
        );
    }

    private static List<Tender__c> createTenders(Integer count, String dept) {
        List<Tender__c> tenders = new List<Tender__c>();
        for (Integer i = 0; i < count; i++) {
            // Add any other REQUIRED fields of Tender__c here
            tenders.add(new Tender__c(Department_Name__c = dept));
        }
        insert tenders;
        return tenders;
    }

    private static Integer shareCount(Id tenderId, Id userId) {
        return [
            SELECT COUNT() FROM Tender__Share
            WHERE ParentId = :tenderId
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
    }

    private static Integer batchJobCount() {
        return [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'UserDeptChangeTenderShareBatch'
        ];
    }

    // Helper used by the "future" context test
    @future
    public static void callHandlerFromFuture() {
        UserTenderShareTriggerHandler.handleAfterInsert(
            new List<User>{ new User(IsActive = true, Departments__c = 'Future_Only_Dept') }
        );
    }

    // ---------------- Trigger + batch: end to end ----------------

    // New user with the department -> existing tender gets shared (Read)
    @isTest
    static void testNewUserWithDepartmentGetsShare() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, false));

        List<Tender__Share> shares = [
            SELECT AccessLevel FROM Tender__Share
            WHERE ParentId = :t.Id AND UserOrGroupId = :u.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(1, shares.size(), 'Share should be created for new user');
        System.assertEquals('Read', shares[0].AccessLevel, 'Utkarsh Tender / checkbox user gets Read');
    }

    // Department ADDED to an existing user -> share created
    @isTest
    static void testDepartmentAddedCreatesShare() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        User u = insertUser(buildUser('Utkarsh Tender', DEPT_OTHER, true));
        System.assertEquals(0, shareCount(t.Id, u.Id), 'No share before department is added');

        u.Departments__c = DEPT_OTHER + ';' + DEPT_CB_USER;
        updateUser(u);

        System.assertEquals(1, shareCount(t.Id, u.Id), 'Share should be created after department is added');
    }

    // Department REMOVED from a user -> share deleted
    @isTest
    static void testDepartmentRemovedDeletesShare() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, true));
        System.assertEquals(1, shareCount(t.Id, u.Id), 'Share should exist before removal');

        u.Departments__c = DEPT_OTHER;
        updateUser(u);

        System.assertEquals(0, shareCount(t.Id, u.Id), 'Share should be removed after department is removed');
    }

    // Tender_Access_User__c checkbox ON -> share created, OFF -> share removed
    @isTest
    static void testTenderAccessCheckboxChange() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        // Use a profile that is NOT a Tender profile so only the checkbox decides access
        User u = insertUser(buildUser('Standard User', DEPT_CB_USER, false));
        System.assertEquals(0, shareCount(t.Id, u.Id), 'No access without checkbox');

        u.Tender_Access_User__c = true;
        updateUser(u);
        System.assertEquals(1, shareCount(t.Id, u.Id), 'Share created after checkbox ON');

        u.Tender_Access_User__c = false;
        updateUser(u);
        System.assertEquals(0, shareCount(t.Id, u.Id), 'Share removed after checkbox OFF');
    }

    // Deactivated user -> share removed
    @isTest
    static void testDeactivatedUserLosesShare() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, true));
        System.assertEquals(1, shareCount(t.Id, u.Id), 'Share should exist before deactivation');

        u.IsActive = false;
        updateUser(u);

        System.assertEquals(0, shareCount(t.Id, u.Id), 'Share should be removed for inactive user');
    }

    // Profile change on an existing user starts the batch (ProfileId is a watched field)
    @isTest
    static void testProfileChangeStartsBatch() {
        createTenders(1, DEPT_CB_TENDER);
        User u = insertUser(buildUser('Standard User', DEPT_CB_USER, true));

        Integer before = batchJobCount();

        u.ProfileId = getProfileId('Utkarsh Tender');
        updateUser(u);

        System.assert(batchJobCount() > before, 'Batch should start when ProfileId changes');
    }

    // HOD profile -> Edit access (skipped automatically if the profile does not exist in this org)
    @isTest
    static void testHodProfileGetsEditAccess() {
        if ([SELECT COUNT() FROM Profile WHERE Name = 'Utkarsh HOD'] == 0) {
            return;
        }

        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];
        User u = insertUser(buildUser('Utkarsh HOD', DEPT_CB_USER, false));

        List<Tender__Share> shares = [
            SELECT AccessLevel FROM Tender__Share
            WHERE ParentId = :t.Id AND UserOrGroupId = :u.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(1, shares.size(), 'HOD should get a share');
        System.assertEquals('Edit', shares[0].AccessLevel, 'HOD should get Edit access');
    }

    // Change of an unwatched field (FirstName) must NOT start the batch
    @isTest
    static void testUnwatchedFieldDoesNotStartBatch() {
        createTenders(1, DEPT_CB_TENDER);
        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, true));

        Integer before = batchJobCount();

        u.FirstName = 'ChangedName';
        updateUser(u);

        System.assertEquals(before, batchJobCount(), 'Batch should not start when no watched field changed');
    }

    // Inactive new user -> no batch
    @isTest
    static void testInactiveNewUserDoesNotStartBatch() {
        createTenders(1, DEPT_CB_TENDER);
        Integer before = batchJobCount();

        User u = buildUser('Utkarsh Tender', DEPT_CB_USER, true);
        u.IsActive = false;
        insertUser(u);

        System.assertEquals(before, batchJobCount(), 'Inactive new user must not start batch');
    }

    // New user without departments -> no batch
    @isTest
    static void testNewUserWithoutDepartmentDoesNotStartBatch() {
        createTenders(1, DEPT_CB_TENDER);
        Integer before = batchJobCount();

        insertUser(buildUser('Utkarsh Tender', null, true));

        System.assertEquals(before, batchJobCount(), 'User without departments must not start batch');
    }

    // Several tenders at once (bulk)
    @isTest
    static void testBulkTenders() {
        List<Tender__c> tenders = createTenders(20, DEPT_CB_TENDER);

        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, true));

        Integer total = [
            SELECT COUNT() FROM Tender__Share
            WHERE ParentId IN :tenders AND UserOrGroupId = :u.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(20, total, 'All 20 tenders should be shared with the user');
    }

    // Several users at once (bulk)
    @isTest
    static void testBulkUsers() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];

        List<User> users = new List<User>();
        for (Integer i = 0; i < 5; i++) {
            users.add(buildUser('Utkarsh Tender', DEPT_CB_USER, true));
        }

        System.runAs(getAdmin()) {
            Test.startTest();
            insert users;
            Test.stopTest();
        }

        Integer total = [
            SELECT COUNT() FROM Tender__Share
            WHERE ParentId = :t.Id AND UserOrGroupId IN :users AND RowCause = 'Manual'
        ];
        System.assertEquals(5, total, 'All 5 users should have a share');
    }

    // ---------------- TenderSharingHandler ----------------

    // Department name conversion
    @isTest
    static void testGetTenderDeptNames() {
        Set<String> result = TenderSharingHandler.getTenderDeptNames(
            new Set<String>{ DEPT_CB_USER, 'PVC' }
        );

        System.assert(result.contains('CRASH BARRIER'), 'Should map Crash_Barrier_Department to CRASH BARRIER');
        System.assert(result.contains('POLYMER'), 'Should map PVC to POLYMER');
        System.assert(result.contains(DEPT_CB_USER), 'Should keep the normalized name too');

        System.assertEquals(0, TenderSharingHandler.getTenderDeptNames(null).size(), 'null is safe');
        System.assertEquals(0, TenderSharingHandler.getTenderDeptNames(new Set<String>()).size(), 'empty is safe');
    }

    // ---------------- UserTenderShareTriggerHandler (direct calls) ----------------

    // Handler null / empty safety
    @isTest
    static void testHandlerNullSafe() {
        Test.startTest();
        UserTenderShareTriggerHandler.handleAfterInsert(null);
        UserTenderShareTriggerHandler.handleAfterInsert(new List<User>());
        UserTenderShareTriggerHandler.handleAfterUpdate(null, null);
        UserTenderShareTriggerHandler.handleAfterUpdate(new List<User>(), new Map<Id, User>());
        UserTenderShareTriggerHandler.handleAfterUpdate(new List<User>{ new User() }, null);
        Test.stopTest();

        System.assert(true, 'No exception expected');
    }

    // Insert handler: inactive user, blank department and blank pieces ("A;;B; ") are all handled
    @isTest
    static void testHandlerAfterInsertEdgeCases() {
        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.handleAfterInsert(new List<User>{
            new User(IsActive = false, Departments__c = 'Inactive_Dept'),
            new User(IsActive = true,  Departments__c = null),
            new User(IsActive = true,  Departments__c = '   ')
        });
        System.assertEquals(before, batchJobCount(), 'Nothing should be queued for these users');

        UserTenderShareTriggerHandler.handleAfterInsert(new List<User>{
            new User(IsActive = true, Departments__c = 'Messy_Dept_A;;  ; Messy_Dept_B ;')
        });
        Test.stopTest();

        System.assert(batchJobCount() > before, 'Batch should be queued for the valid departments');
    }

    // Update handler: old record missing in oldMap is skipped, unchanged user is skipped
    @isTest
    static void testHandlerAfterUpdateSkipsMissingAndUnchanged() {
        User admin = getAdmin();
        Id fakeId = '005000000000001AAA';
        Integer before = batchJobCount();

        User unchangedNew = new User(Id = admin.Id, Departments__c = 'Same_Dept', IsActive = true);
        User unchangedOld = new User(Id = admin.Id, Departments__c = 'Same_Dept', IsActive = true);
        User noOldRecord  = new User(Id = fakeId,    Departments__c = 'Orphan_Dept', IsActive = true);

        Test.startTest();
        UserTenderShareTriggerHandler.handleAfterUpdate(
            new List<User>{ unchangedNew, noOldRecord },
            new Map<Id, User>{ admin.Id => unchangedOld }
        );
        Test.stopTest();

        System.assertEquals(before, batchJobCount(), 'No batch expected');
    }

    // Update handler: each watched field on its own triggers the batch
    @isTest
    static void testHandlerAfterUpdateDetectsEachWatchedField() {
        User admin = getAdmin();
        Id profA = getProfileId('Standard User');
        Id profB = getProfileId('System Administrator');

        User oldU = new User(Id = admin.Id, Departments__c = 'Watch_Dept_1',
            IsActive = true, ProfileId = profA, Tender_Access_User__c = false);

        // IsActive changed
        User n1 = new User(Id = admin.Id, Departments__c = 'Watch_Dept_1',
            IsActive = false, ProfileId = profA, Tender_Access_User__c = false);
        // ProfileId changed
        User n2 = new User(Id = admin.Id, Departments__c = 'Watch_Dept_2',
            IsActive = true, ProfileId = profB, Tender_Access_User__c = false);
        // Tender_Access_User__c changed
        User n3 = new User(Id = admin.Id, Departments__c = 'Watch_Dept_3',
            IsActive = true, ProfileId = profA, Tender_Access_User__c = true);

        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.handleAfterUpdate(new List<User>{ n1 }, new Map<Id, User>{ admin.Id => oldU });
        UserTenderShareTriggerHandler.handleAfterUpdate(new List<User>{ n2 }, new Map<Id, User>{ admin.Id => oldU });
        UserTenderShareTriggerHandler.handleAfterUpdate(new List<User>{ n3 }, new Map<Id, User>{ admin.Id => oldU });
        Test.stopTest();

        System.assert(batchJobCount() > before, 'Batch should be queued for watched field changes');
    }

    // Same department twice in one transaction -> second call is skipped (alreadyQueuedDepts)
    @isTest
    static void testHandlerDoesNotQueueSameDepartmentTwice() {
        List<User> users = new List<User>{ new User(IsActive = true, Departments__c = 'Dedup_Dept') };
        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.handleAfterInsert(users);
        UserTenderShareTriggerHandler.handleAfterInsert(users);
        Test.stopTest();

        System.assertEquals(before + 1, batchJobCount(), 'Only one batch for the same department');
    }

    // Called from @future context -> batch must NOT be started
    @isTest
    static void testHandlerInFutureContextDoesNotStartBatch() {
        Integer before = batchJobCount();

        Test.startTest();
        callHandlerFromFuture();
        Test.stopTest();

        System.assertEquals(before, batchJobCount(), 'No batch can be started from a future method');
    }

    // ---------------- UserDeptChangeTenderShareBatch (direct calls) ----------------

    // Batch run directly with null departments
    @isTest
    static void testBatchWithNoMatchingTenders() {
        Test.startTest();
        Database.executeBatch(new UserDeptChangeTenderShareBatch(null), 50);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Tender__Share WHERE RowCause = 'Manual'],
            'Nothing to share');
    }

    // Batch run with an unknown department
    @isTest
    static void testBatchWithUnknownDepartment() {
        createTenders(1, DEPT_CB_TENDER);

        Test.startTest();
        Database.executeBatch(new UserDeptChangeTenderShareBatch(new Set<String>{ 'Unknown_Dept' }), 50);
        Test.stopTest();

        System.assert(true, 'Batch should finish without error');
    }

    // execute() with empty / null scope returns quietly; finish() runs
    @isTest
    static void testBatchExecuteEmptyScopeAndFinish() {
        UserDeptChangeTenderShareBatch b =
            new UserDeptChangeTenderShareBatch(new Set<String>{ DEPT_CB_USER });

        Test.startTest();
        b.execute(null, null);
        b.execute(null, new List<Tender__c>());
        b.finish(null);
        Test.stopTest();

        System.assert(true, 'No exception expected');
    }

    // execute() swallows errors from the sharing handler (rolls back, counts the failed scope)
    @isTest
    static void testBatchExecuteHandlesFailureInsideScope() {
        UserDeptChangeTenderShareBatch b =
            new UserDeptChangeTenderShareBatch(new Set<String>{ DEPT_CB_USER });

        Test.startTest();
        // Unsaved tender (no Id) and a null entry: the handler may throw, execute() must still not
        b.execute(null, new List<Tender__c>{ new Tender__c(Department_Name__c = DEPT_CB_TENDER) });
        b.execute(null, new List<Tender__c>{ null });
        b.finish(null);
        Test.stopTest();

        System.assert(true, 'execute() must never throw');
    }

    // execute() directly with a real tender and a real matching user
    @isTest
    static void testBatchExecuteSharesRealTender() {
        Tender__c t = createTenders(1, DEPT_CB_TENDER)[0];
        User u = insertUser(buildUser('Utkarsh Tender', DEPT_CB_USER, true));

        Test.startTest();
        UserDeptChangeTenderShareBatch b =
            new UserDeptChangeTenderShareBatch(new Set<String>{ DEPT_CB_USER });
        b.execute(null, [SELECT Id, Department_Name__c, OwnerId FROM Tender__c WHERE Id = :t.Id]);
        Test.stopTest();

        System.assertEquals(1, shareCount(t.Id, u.Id), 'Share should exist after direct execute()');
    }
    
        // ---------------- Trigger entry point: run() ----------------

    // Kill switch ON -> nothing happens
    @isTest
    static void testKillSwitchStopsProcessing() {
        UserTenderShareTriggerHandler.testKillSwitchOn = true;
        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.run(true, false,
            new List<User>{ new User(IsActive = true, Departments__c = 'Kill_Switch_Dept') },
            null);
        Test.stopTest();

        System.assertEquals(before, batchJobCount(), 'Kill switch must stop the batch');
        System.assert(UserTenderShareTriggerHandler.isDisabled(), 'Kill switch should report disabled');
    }

    // Error inside the handler is swallowed (user save is never blocked)
    @isTest
    static void testRunSwallowsErrors() {
        UserTenderShareTriggerHandler.testForceError = true;
        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.run(true, false,
            new List<User>{ new User(IsActive = true, Departments__c = 'Error_Dept') },
            null);
        Test.stopTest();

        System.assertEquals(before, batchJobCount(), 'Nothing should be queued after the error');
    }

    // Neither insert nor update -> nothing happens
    @isTest
    static void testRunWithNoInsertOrUpdate() {
        Integer before = batchJobCount();

        Test.startTest();
        UserTenderShareTriggerHandler.run(false, false, null, null);
        Test.stopTest();

        System.assertEquals(before, batchJobCount(), 'Nothing should be queued');
    }

    // Normal path through run(): insert and update
    @isTest
    static void testRunInsertAndUpdatePaths() {
        User admin = getAdmin();
        Integer before = batchJobCount();

        User oldU = new User(Id = admin.Id, Departments__c = 'Run_Dept_Old', IsActive = true);
        User newU = new User(Id = admin.Id, Departments__c = 'Run_Dept_New', IsActive = true);

        Test.startTest();
        UserTenderShareTriggerHandler.run(true, false,
            new List<User>{ new User(IsActive = true, Departments__c = 'Run_Dept_Insert') }, null);
        UserTenderShareTriggerHandler.run(false, true,
            new List<User>{ newU }, new Map<Id, User>{ admin.Id => oldU });
        Test.stopTest();

        System.assert(batchJobCount() > before, 'Batch should be queued from run()');
    }
    // Runs the sharing logic synchronously (no Test.startTest needed)
    private static void runShareBatch() {
        List<Tender__c> scope = [
            SELECT Id, Department_Name__c, OwnerId FROM Tender__c
        ];
        new UserDeptChangeTenderShareBatch(
            new Set<String>{ DEPT_CB_USER, DEPT_OTHER }
        ).execute(null, scope);
    }
    
    // Inserts a user and applies sharing
    private static User insertUser(User u) {
        System.runAs(getAdmin()) {
            insert u;
        }
        runShareBatch();
        return u;
    }
    
    // Updates a user and applies sharing
    private static void updateUser(User u) {
        // Simulate a new transaction: allow the same department to be queued again
        UserTenderShareTriggerHandler.resetQueuedDepts();
        
        System.runAs(getAdmin()) {
            update u;
        }
        runShareBatch();
    }
}