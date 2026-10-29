@isTest
private class TargetManagerControllerTest {

    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User manager = new User(
            Alias = 'tmgr',
            Email = 'target.manager@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TargetManager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'target.manager.' + DateTime.now().getTime() + '@example.com',
            Target_Manager__c = true
        );
        insert manager;

        User assignee = new User(
            Alias = 'tasgn',
            Email = 'target.assignee@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TargetAssignee',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'target.assignee.' + DateTime.now().getTime() + '@example.com',
            ManagerId = manager.Id
        );
        insert assignee;
    }

    private static User getManager() {
        return [SELECT Id FROM User WHERE Alias = 'tmgr' LIMIT 1];
    }

    private static User getAssignee() {
        return [SELECT Id FROM User WHERE Alias = 'tasgn' LIMIT 1];
    }

    @isTest
    static void testGetAvailableEntities() {
        Test.startTest();
        List<TargetManagerController.EntityWrapper> users =
            TargetManagerController.getAvailableEntities('Users');
        List<TargetManagerController.EntityWrapper> teams =
            TargetManagerController.getAvailableEntities('Team');
        Test.stopTest();

        System.assert(!users.isEmpty(), 'Should return active users');
        System.assertNotEquals(null, teams);
    }

    @isTest
    static void testGetDynamicPicklists() {
        Test.startTest();
        Map<String, List<TargetManagerController.PicklistOption>> picklists =
            TargetManagerController.getDynamicPicklists(
                'Target__c',
                new List<String>{ 'Frequency__c', 'Metric__c', 'Assign_To_Type__c' }
            );
        Test.stopTest();

        System.assert(picklists.containsKey('Frequency__c'));
        System.assert(!picklists.get('Frequency__c').isEmpty());
    }

    @isTest
    static void testSaveAndLoadTarget() {
        User manager = getManager();
        User assignee = getAssignee();
        Date startDate = Date.today().toStartOfMonth();
        Date endDate = startDate.addMonths(1).addDays(-1);

        System.runAs(manager) {
            Target__c target = new Target__c(
                Name = 'Test Target',
                Target_Module__c = 'Task',
                Frequency__c = 'Monthly',
                Metric__c = 'Number of task completed',
                Assign_To_Type__c = 'Users',
                Status__c = 'Active'
            );

            List<Object> periods = new List<Object>{
                new Map<String, Object>{
                    'id' => 'p1',
                    'label' => 'Cycle 1',
                    'isPast' => false,
                    'inputValue' => '10',
                    'startDate' => String.valueOf(startDate),
                    'endDate' => String.valueOf(endDate)
                }
            };
            List<Object> assignments = new List<Object>{
                new Map<String, Object>{
                    'Id' => assignee.Id,
                    'periods' => periods
                }
            };

            Test.startTest();
            String saveResult = TargetManagerController.saveTargetData(
                target,
                JSON.serialize(assignments),
                'Users'
            );
            Test.stopTest();

            System.assertEquals('Success', saveResult);

            TargetManagerController.TargetListWrapper existing =
                TargetManagerController.getExistingTargets();
            System.assertEquals(true, existing.isManager);
            /*System.assert(!existing.targets.isEmpty());

            TargetManagerController.EditPayload details =
                TargetManagerController.getFullTargetDetails(existing.targets[0].Id);
            System.assertEquals(existing.targets[0].Id, details.target.Id);
            System.assertEquals(1, details.assignments.size());
            System.assertEquals(assignee.Id, details.assignments[0].entityId);

            TargetManagerController.DashboardWrapper stats =
                TargetManagerController.getDashboardStats(
                    existing.targets[0].Id,
                    String.valueOf(startDate),
                    String.valueOf(endDate)
                );
            System.assertNotEquals(null, stats);
            System.assertNotEquals(null, stats.employees);*/
        }
    }

    @isTest
    static void testGetPunchDataAndTeamMembers() {
        User assignee = getAssignee();
        Punch_Record__c punch = new Punch_Record__c(
            User__c = assignee.Id,
            Action__c = 'IN',
            Punch_Time__c = System.now(),
            Punch_Type__c = 'Market Visit'
        );
        insert punch;

        Account acc = new Account(Name = 'Target Client');
        insert acc;
        insert new Task_Log__c(
            Punch_Record__c = punch.Id,
            Account__c = acc.Id,
            Description__c = 'Completed visit',
            IsCheckout__c = true,
            Is_schedule__c = false,
            Logged_At__c = System.now()
        );

        Test.startTest();
        List<TargetManagerController.PunchResult> punchData =
            TargetManagerController.getPunchData(new List<String>{ assignee.Id }, 'Users');
        Map<String, List<TargetManagerController.EntityWrapper>> emptyTeams =
            TargetManagerController.getTeamMembers(new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, punchData);
        System.assertNotEquals(null, emptyTeams);
    }

    @isTest
    static void testTeamAssignmentPaths() {
        User manager = getManager();
        User assignee = getAssignee();
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Group g;
        System.runAs(thisUser) {
            g = new Group(Name = 'FF Target Team ' + DateTime.now().getTime(), Type = 'Regular');
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = assignee.Id);
        }

        Date startDate = Date.today().toStartOfMonth();
        Date endDate = startDate.addMonths(1).addDays(-1);

        System.runAs(manager) {
            List<TargetManagerController.EntityWrapper> teams =
                TargetManagerController.getAvailableEntities('Team');
            Map<String, List<TargetManagerController.EntityWrapper>> members =
                TargetManagerController.getTeamMembers(new List<String>{ g.Id });
            List<TargetManagerController.PunchResult> teamPunch =
                TargetManagerController.getPunchData(new List<String>{ g.Id }, 'Team');

            Target__c target = new Target__c(
                Name = 'Team Target',
                Target_Module__c = 'Task',
                Frequency__c = 'Monthly',
                Metric__c = 'Number of task completed',
                Assign_To_Type__c = 'Team',
                Status__c = 'Active'
            );
            String assignmentsJSON = JSON.serialize(new List<Object>{
                new Map<String, Object>{
                    'Id' => g.Id,
                    'periods' => new List<Object>{
                        new Map<String, Object>{
                            'id' => 't1',
                            'label' => 'Month',
                            'isPast' => false,
                            'inputValue' => '8',
                            'startDate' => String.valueOf(startDate),
                            'endDate' => String.valueOf(endDate)
                        }
                    }
                }
            });

            Test.startTest();
            String saveResult = TargetManagerController.saveTargetData(target, assignmentsJSON, 'Team');
            Target__c saved = [SELECT Id FROM Target__c WHERE Name = 'Team Target' LIMIT 1];
            TargetManagerController.EditPayload details = TargetManagerController.getFullTargetDetails(saved.Id);
            TargetManagerController.DashboardWrapper stats =
                TargetManagerController.getDashboardStats(
                    saved.Id,
                    String.valueOf(startDate),
                    String.valueOf(endDate)
                );
            Test.stopTest();

            System.assertNotEquals(null, teams);
            System.assert(members.containsKey(g.Id));
            System.assertNotEquals(null, teamPunch);
            System.assertEquals('Success', saveResult);
            System.assertEquals(1, details.assignments.size());
            System.assertNotEquals(null, stats);
        }
    }

    @isTest
    static void testUpdateTargetAndWeeklyDashboard() {
        User manager = getManager();
        User assignee = getAssignee();
        Date weekStart = Date.today().toStartOfWeek();
        Date weekEnd = weekStart.addDays(6);

        System.runAs(manager) {
            Target__c target = new Target__c(
                Name = 'Weekly Target',
                Target_Module__c = 'Task',
                Frequency__c = 'Weekly',
                Metric__c = 'Number of task completed',
                Assign_To_Type__c = 'Users',
                Status__c = 'Active'
            );
            List<Object> periods = new List<Object>{
                new Map<String, Object>{
                    'id' => 'w1',
                    'label' => 'This Week',
                    'isPast' => false,
                    'inputValue' => '5',
                    'startDate' => String.valueOf(weekStart),
                    'endDate' => String.valueOf(weekEnd)
                }
            };
            String assignmentsJSON = JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'Id' => assignee.Id, 'periods' => periods }
            });

            TargetManagerController.saveTargetData(target, assignmentsJSON, 'Users');
            Target__c saved = [SELECT Id, Name FROM Target__c WHERE Name = 'Weekly Target' LIMIT 1];
            saved.Name = 'Weekly Target Updated';

            Test.startTest();
            String updateResult = TargetManagerController.saveTargetData(saved, assignmentsJSON, 'Users');
            TargetManagerController.DashboardWrapper stats =
                TargetManagerController.getDashboardStats(
                    saved.Id,
                    String.valueOf(weekStart),
                    String.valueOf(weekEnd)
                );
            TargetManagerController.TargetListWrapper asAssignee;
            System.runAs(assignee) {
                asAssignee = TargetManagerController.getExistingTargets();
            }
            Test.stopTest();

            System.assertEquals('Success', updateResult);
            System.assertNotEquals(null, stats.trendLines);
            System.assertEquals(false, asAssignee.isManager);
            System.assert(!asAssignee.targets.isEmpty());
        }
    }

    // ─── Utkarsh HOD / CRM Head visibility ────────────────────────────────────

    private static Id getProfileIdOrNull(String profileName) {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        return profiles.isEmpty() ? null : profiles[0].Id;
    }

    private static User buildDeptUser(Id profileId, String department, String departments) {
        String rand = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8);
        return new User(
            Alias = rand,
            Email = rand + '@tmcdept.test',
            Username = rand + '@tmcdept.test.' + System.currentTimeMillis(),
            LastName = 'TmcDept' + rand,
            ProfileId = profileId,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department = department,
            Departments__c = departments,
            IsActive = true
        );
    }

    private static void insertUsers(List<User> users) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert users;
        }
    }

    // Creates a Users target assigned to the given user (as the running user)
    private static void createTargetFor(Id assigneeId, String targetName) {
        Date startDate = Date.today().toStartOfMonth();
        Date endDate = startDate.addMonths(1).addDays(-1);
        Target__c target = new Target__c(
            Name = targetName,
            Target_Module__c = 'Task',
            Frequency__c = 'Monthly',
            Metric__c = 'Number of task completed',
            Assign_To_Type__c = 'Users',
            Status__c = 'Active'
        );
        String assignmentsJSON = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'Id' => assigneeId,
                'periods' => new List<Object>{
                    new Map<String, Object>{
                        'id' => 'd1',
                        'label' => 'Month',
                        'isPast' => false,
                        'inputValue' => '5',
                        'startDate' => String.valueOf(startDate),
                        'endDate' => String.valueOf(endDate)
                    }
                }
            }
        });
        TargetManagerController.saveTargetData(target, assignmentsJSON, 'Users');
    }

    @isTest
    static void testGetExistingTargets_HodDepartment() {
        Id hodProfileId = getProfileIdOrNull('Utkarsh HOD');
        Id standardProfileId = getProfileIdOrNull('Standard User');
        if (hodProfileId == null || standardProfileId == null) {
            return;
        }

        String dept = 'TMC HOD Dept ' + System.currentTimeMillis();
        User hod = buildDeptUser(hodProfileId, dept, null);
        User deptUser = buildDeptUser(standardProfileId, dept, null);
        insertUsers(new List<User>{ hod, deptUser });

        createTargetFor(deptUser.Id, 'HOD Dept Target');

        TargetManagerController.TargetListWrapper result;
        Test.startTest();
        System.runAs(hod) {
            result = TargetManagerController.getExistingTargets();
        }
        Test.stopTest();

        System.assertNotEquals(null, result, 'HOD should get a result');
        System.assertNotEquals(null, result.targets, 'HOD should get a targets list');
    }

    @isTest
    static void testGetExistingTargets_HodWithoutDepartment() {
        Id hodProfileId = getProfileIdOrNull('Utkarsh HOD');
        if (hodProfileId == null) {
            return;
        }

        User hod = buildDeptUser(hodProfileId, null, null);
        insertUsers(new List<User>{ hod });

        TargetManagerController.TargetListWrapper result;
        Test.startTest();
        System.runAs(hod) {
            result = TargetManagerController.getExistingTargets();
        }
        Test.stopTest();

        System.assert(result.targets.isEmpty(), 'HOD without a Department should see no targets');
    }

    @isTest
    static void testGetExistingTargets_CrmHead() {
        Id crmHeadProfileId = getProfileIdOrNull('CRM Head');
        Id standardProfileId = getProfileIdOrNull('Standard User');
        if (crmHeadProfileId == null || standardProfileId == null) {
            return;
        }

        User crmHead = buildDeptUser(crmHeadProfileId, null, 'Solar_Structure_Department;HDPE_Pipe_Department');
        User deptUser = buildDeptUser(standardProfileId, 'HDPE', null);
        insertUsers(new List<User>{ crmHead, deptUser });

        createTargetFor(deptUser.Id, 'CRM Head Dept Target');
        createTargetFor(crmHead.Id, 'CRM Head Own Target');

        TargetManagerController.TargetListWrapper result;
        Test.startTest();
        System.runAs(crmHead) {
            result = TargetManagerController.getExistingTargets();
        }
        Test.stopTest();

        System.assertNotEquals(null, result, 'CRM Head should get a result');
        System.assertNotEquals(null, result.targets, 'CRM Head should get a targets list');
    }

    @isTest
    static void testGetAvailableEntities_CrmHead() {
        Id crmHeadProfileId = getProfileIdOrNull('CRM Head');
        Id standardProfileId = getProfileIdOrNull('Standard User');
        if (crmHeadProfileId == null || standardProfileId == null) {
            return;
        }

        User crmHead = buildDeptUser(crmHeadProfileId, null, 'Solar_Structure_Department;HDPE_Pipe_Department');
        User deptUser = buildDeptUser(standardProfileId, 'Solar Structure', null);
        insertUsers(new List<User>{ crmHead, deptUser });

        List<TargetManagerController.EntityWrapper> users;
        Test.startTest();
        System.runAs(crmHead) {
            users = TargetManagerController.getAvailableEntities('Users');
        }
        Test.stopTest();

        Set<String> returnedIds = new Set<String>();
        for (TargetManagerController.EntityWrapper w : users) {
            returnedIds.add(w.Id);
        }
        System.assert(returnedIds.contains(crmHead.Id), 'CRM Head should see themselves');
    }

    @isTest
    static void testGetAvailableEntities_DepartmentUser() {
        Id standardProfileId = getProfileIdOrNull('Standard User');
        if (standardProfileId == null) {
            return;
        }

        String dept = 'TMC Picker Dept ' + System.currentTimeMillis();
        User viewer = buildDeptUser(standardProfileId, dept, null);
        User colleague = buildDeptUser(standardProfileId, dept, null);
        insertUsers(new List<User>{ viewer, colleague });

        List<TargetManagerController.EntityWrapper> users;
        Test.startTest();
        System.runAs(viewer) {
            users = TargetManagerController.getAvailableEntities('Users');
        }
        Test.stopTest();

        System.assertEquals(2, users.size(), 'Should see only active users of the same Department');
    }

    @isTest
    static void testGetAvailableEntities_NoDepartment() {
        // Setup assignee has no Department and is not an unrestricted profile
        User assignee = getAssignee();

        List<TargetManagerController.EntityWrapper> users;
        Test.startTest();
        System.runAs(assignee) {
            users = TargetManagerController.getAvailableEntities('Users');
        }
        Test.stopTest();

        System.assert(users.isEmpty(), 'User without a Department should see no users');
    }
}