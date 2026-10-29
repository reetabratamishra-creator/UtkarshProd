@IsTest
private class CaseDepartmentAssignControllerTest {

    /* ------------------------------------------------------------------ */
    /*  Helpers                                                           */
    /* ------------------------------------------------------------------ */

    /**
     * Picks a real assignable department from the org's own picklist so the
     * test does not depend on any particular org configuration.
     */
    private static String assignableDepartment() {
        for (Schema.PicklistEntry entry : Case.Department__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !entry.getValue().equalsIgnoreCase('Enquiry')) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Map<String, User> usersByLastName() {
        Map<String, User> m = new Map<String, User>();
        for (User u : [SELECT Id, Name, LastName, Department FROM User WHERE Email LIKE 'dept.user%@example.com']) {
            m.put(u.LastName, u);
        }
        return m;
    }

    private static Case theCase() {
        return [SELECT Id, OwnerId, Department__c FROM Case WHERE Subject = 'Department assign test' LIMIT 1];
    }

    /* ------------------------------------------------------------------ */
    /*  Setup                                                             */
    /* ------------------------------------------------------------------ */

    @TestSetup
    static void makeData() {
        String dept = assignableDepartment();
        if (dept == null) {
            return;   // nothing assignable in this org; the tests below assert on that
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Long stamp = DateTime.now().getTime();

        List<User> users = new List<User>{
            buildUser(p.Id, stamp, 1, dept),                       // exact department
            buildUser(p.Id, stamp, 2, 'Logistics;' + dept),        // multi-department, contains match
            buildUser(p.Id, stamp, 3, 'Logistics'),                // different department
            buildUser(p.Id, stamp, 4, dept)                        // inactive, set below
        };
        users[3].IsActive = true;

        // Users are setup objects -> isolate the DML to avoid MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert users;
            users[3].IsActive = false;
            update users[3];
        }

        insert new Case(
            Subject  = 'Department assign test',
            Status   = 'New',
            Priority = 'Medium',
            OwnerId  = UserInfo.getUserId()
        );
    }

    private static User buildUser(Id profileId, Long stamp, Integer i, String department) {
        return new User(
            FirstName         = 'Dept',
            LastName          = 'User' + i,
            Email             = 'dept.user' + i + '@example.com',
            Username          = 'dept.user' + i + '.' + stamp + '@example.com.invalid',
            Alias             = 'dptu' + i,
            Department        = department,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = profileId,
            IsActive          = true
        );
    }

    /* ------------------------------------------------------------------ */
    /*  Departments                                                       */
    /* ------------------------------------------------------------------ */

    @IsTest
    static void departmentListExcludesEnquiry() {
        Case c = theCase();

        Test.startTest();
        CaseDepartmentAssignController.AssignContext ctx =
            CaseDepartmentAssignController.getAssignContext(c.Id);
        Test.stopTest();

        Assert.isNull(ctx.blockReason, 'Screen should be usable');
        Assert.isFalse(ctx.departments.isEmpty(), 'At least one department should be assignable');

        for (CaseDepartmentAssignController.Option o : ctx.departments) {
            Assert.isFalse(
                o.value.equalsIgnoreCase('Enquiry'),
                'Enquiry must never appear in the department list'
            );
        }
    }

    @IsTest
    static void missingCaseIsBlocked() {
        Id fakeId = (Id) (Case.SObjectType.getDescribe().getKeyPrefix() + '000000000000');

        Test.startTest();
        CaseDepartmentAssignController.AssignContext ctx =
            CaseDepartmentAssignController.getAssignContext(fakeId);
        Test.stopTest();

        Assert.isNotNull(ctx.blockReason, 'Unknown Case id should block the screen');
    }

    @IsTest
    static void wrongObjectIdIsBlocked() {
        Test.startTest();
        CaseDepartmentAssignController.AssignContext ctx =
            CaseDepartmentAssignController.getAssignContext(UserInfo.getUserId());
        Test.stopTest();

        Assert.isNotNull(ctx.blockReason, 'A non-Case id should block the screen');
    }

    /* ------------------------------------------------------------------ */
    /*  User lookup                                                       */
    /* ------------------------------------------------------------------ */

    @IsTest
    static void usersMatchDepartmentIncludingMultiValue() {
        String dept = assignableDepartment();
        Map<String, User> u = usersByLastName();

        Test.startTest();
        List<CaseDepartmentAssignController.Option> options =
            CaseDepartmentAssignController.getUsersByDepartment(dept);
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        for (CaseDepartmentAssignController.Option o : options) {
            ids.add((Id) o.value);
        }

        Assert.isTrue(ids.contains(u.get('User1').Id), 'Exact department match should be returned');
        Assert.isTrue(ids.contains(u.get('User2').Id), 'Multi-department user should be returned');
        Assert.isFalse(ids.contains(u.get('User3').Id), 'Other department must not be returned');
        Assert.isFalse(ids.contains(u.get('User4').Id), 'Inactive user must not be returned');
    }

    @IsTest
    static void excludedAndBlankDepartmentsReturnNothing() {
        Test.startTest();
        List<CaseDepartmentAssignController.Option> excluded =
            CaseDepartmentAssignController.getUsersByDepartment('Enquiry');
        List<CaseDepartmentAssignController.Option> blank =
            CaseDepartmentAssignController.getUsersByDepartment(null);
        Test.stopTest();

        Assert.areEqual(0, excluded.size(), 'Enquiry must never resolve users');
        Assert.areEqual(0, blank.size(), 'A blank department must never resolve users');
    }

    /* ------------------------------------------------------------------ */
    /*  Assignment                                                        */
    /* ------------------------------------------------------------------ */

    @IsTest
    static void assignCaseUpdatesOwnerAndDepartment() {
        String dept = assignableDepartment();
        Map<String, User> u = usersByLastName();
        Case c = theCase();

        Test.startTest();
        CaseDepartmentAssignController.AssignResult result =
            CaseDepartmentAssignController.assignCase(c.Id, dept, u.get('User1').Id);
        Test.stopTest();

        Case reloaded = [SELECT OwnerId, Department__c FROM Case WHERE Id = :c.Id LIMIT 1];
        Assert.areEqual(u.get('User1').Id, reloaded.OwnerId, 'Owner should be the selected user');
        Assert.areEqual(dept, reloaded.Department__c, 'Department should be written to the Case');
        Assert.areEqual(u.get('User1').Name, result.ownerName, 'New owner name should be returned');
    }

    @IsTest
    static void assignRejectsUserOutsideDepartment() {
        String dept = assignableDepartment();
        Map<String, User> u = usersByLastName();
        Case c = theCase();
        Id originalOwner = c.OwnerId;

        Boolean threw = false;
        Test.startTest();
        try {
            CaseDepartmentAssignController.assignCase(c.Id, dept, u.get('User3').Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'A user from another department must be rejected');
        Case reloaded = [SELECT OwnerId FROM Case WHERE Id = :c.Id LIMIT 1];
        Assert.areEqual(originalOwner, reloaded.OwnerId, 'Owner must stay unchanged');
    }

    @IsTest
    static void assignRejectsInactiveUser() {
        String dept = assignableDepartment();
        Map<String, User> u = usersByLastName();
        Case c = theCase();

        Boolean threw = false;
        Test.startTest();
        try {
            CaseDepartmentAssignController.assignCase(c.Id, dept, u.get('User4').Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'An inactive user must be rejected');
    }

    @IsTest
    static void assignRejectsEnquiryDepartment() {
        Map<String, User> u = usersByLastName();
        Case c = theCase();

        Boolean threw = false;
        Test.startTest();
        try {
            CaseDepartmentAssignController.assignCase(c.Id, 'Enquiry', u.get('User1').Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'Enquiry must never be assignable');
    }

    @IsTest
    static void assignRejectsUnknownDepartment() {
        Map<String, User> u = usersByLastName();
        Case c = theCase();

        Boolean threw = false;
        Test.startTest();
        try {
            CaseDepartmentAssignController.assignCase(c.Id, 'Not A Real Department', u.get('User1').Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'A value outside the picklist must be rejected');
    }

    @IsTest
    static void assignRejectsWrongObjectId() {
        String dept = assignableDepartment();
        Map<String, User> u = usersByLastName();

        Boolean threw = false;
        Test.startTest();
        try {
            CaseDepartmentAssignController.assignCase(UserInfo.getUserId(), dept, u.get('User1').Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'A non-Case id must be rejected');
    }
}