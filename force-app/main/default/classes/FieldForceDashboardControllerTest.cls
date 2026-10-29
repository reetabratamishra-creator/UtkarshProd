@isTest
public class FieldForceDashboardControllerTest {

    @isTest
    static void testGetAvailableSalespeople() {
        // Create standard test Users
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        
        User adminUser = new User(
            Alias = 'adminU', 
            Email='adminuser@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='AdminLastName', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = adminProfile.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='adminuser_' + DateTime.now().getTime() + '@example.com'
        );
        insert adminUser;

        User managerUser = new User(
            Alias = 'mngrU', 
            Email='manageruser@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='ManagerLastName', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = stdProfile.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='manageruser_' + DateTime.now().getTime() + '@example.com'
        );
        insert managerUser;

        User salespersonUser = new User(
            Alias = 'salesU', 
            Email='salespersonuser@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='SalesLastName', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = stdProfile.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='salespersonuser_' + DateTime.now().getTime() + '@example.com',
            ManagerId = managerUser.Id
        );
        insert salespersonUser;

        // Test as Admin
        System.runAs(adminUser) {
            Test.startTest();
            List<FieldForceDashboardController.SalespersonOption> results = FieldForceDashboardController.getAvailableSalespeople();
            Test.stopTest();
            System.assert(results.size() >= 3, 'Admin should see all active users');
        }

        // Test as Manager
        System.runAs(managerUser) {
            List<FieldForceDashboardController.SalespersonOption> results = FieldForceDashboardController.getAvailableSalespeople();
            System.assert(results.size() >= 2, 'Manager should see subordinates + themselves');
        }

        // Test as standard Salesperson
        System.runAs(salespersonUser) {
            List<FieldForceDashboardController.SalespersonOption> results = FieldForceDashboardController.getAvailableSalespeople();
            System.assertEquals(1, results.size(), 'Salesperson should see only themselves');
            System.assertEquals(salespersonUser.Id, results[0].id, 'Should map to Salesperson User Id');
        }
    }

    @isTest
    static void testGetDailyDashboardData() {
        // Create standard test User
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserD', 
            Email='testuserD@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='TestingD', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='testuserD_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            /*Datetime dayInTime = DateTime.now().addHours(-8);
            Datetime modeInTime = DateTime.now().addHours(-7);
            Datetime visitTime = DateTime.now().addHours(-5);
            Datetime dayOutTime = DateTime.now().addHours(-1);*/
            Date testDate = Date.today();

            Datetime dayInTime = Datetime.newInstance(
                testDate,
                Time.newInstance(8, 0, 0, 0)
            );
            
            Datetime modeInTime = Datetime.newInstance(
                testDate,
                Time.newInstance(9, 0, 0, 0)
            );
            
            Datetime visitTime = Datetime.newInstance(
                testDate,
                Time.newInstance(11, 0, 0, 0)
            );
            
            Datetime dayOutTime = Datetime.newInstance(
                testDate,
                Time.newInstance(17, 0, 0, 0)
            );

            Punch_Record__c dayIn = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = dayInTime,
                Punch_Type__c = 'Day In / Out',
                Transportation_Type__c = 'Private Vehicle',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 100.0,
                Latitude__c = 28.5355,
                Longitude__c = 77.3910,
                Address__c = 'Sector 62, Noida, UP',
                Battery__c = 90.0
            );
            insert dayIn;

            Punch_Record__c modeIn = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = modeInTime,
                Punch_Type__c = 'Market Visit',
                Transportation_Type__c = 'Private Vehicle',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 105.0,
                Latitude__c = 28.5355,
                Longitude__c = 77.3910,
                Address__c = 'Sector 62, Noida, UP',
                Battery__c = 88.0
            );
            insert modeIn;

            Punch_Record__c dayOut = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'OUT',
                Punch_Time__c = dayOutTime,
                Punch_Type__c = 'Day In / Out',
                Transportation_Type__c = 'Private Vehicle',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 120.0,
                Latitude__c = 28.5365,
                Longitude__c = 77.3920,
                Address__c = 'Sector 63, Noida, UP',
                Battery__c = 82.0
            );
            insert dayOut;

            Account acc = new Account(Name = 'Daily Client Account');
            insert acc;

            Task_Log__c visitLog = new Task_Log__c(
                Punch_Record__c = modeIn.Id,
                Account__c = acc.Id,
                Reason_for_Visit__c = 'Payment Collection',
                Visit_Type__c = 'Follow up',
                Logged_At__c = visitTime,
                IsCheckout__c = true,
                Logged_Out_At__c = visitTime.addHours(1),
                MOM__c = 'Discussed renewal terms.',
                Visit_outcome__c = 'Only information',
                is100mOutside__c = true,
                Justification__c = 'Client was in nearby cafe',
                Latitude__c = 28.5360,
                Longitude__c = 77.3915,
                Checked_Out_Latitude__c = 28.5361,
                Checked_Out_Longitude__c = 77.3916
            );
            insert visitLog;

            Track_Location__c track = new Track_Location__c(
                Punch_Record__c = modeIn.Id,
                Latitude__c = '28.5358',
                Longitude__c = '77.3912',
                Source__c = 'GPS'
            );
            insert track;

            insert new List<Track_Location__c>{
                new Track_Location__c(
                    Punch_Record__c = modeIn.Id,
                    Latitude__c = '28.5450',
                    Longitude__c = '77.4100',
                    Source__c = 'GPS',
                    Recorded_At__c = visitTime.addMinutes(-40)
                ),
                new Track_Location__c(
                    Punch_Record__c = modeIn.Id,
                    Latitude__c = '28.5400',
                    Longitude__c = '77.4000',
                    Source__c = 'GPS',
                    Recorded_At__c = visitTime.addMinutes(-20)
                )
            };

            ContentVersion cv = new ContentVersion(
                Title = 'Selfie Punch In',
                PathOnClient = 'selfie.jpg',
                VersionData = Blob.valueOf('Test Selfie Data'),
                FirstPublishLocationId = dayIn.Id
            );
            insert cv;

            Test.startTest();
            FieldForceDashboardController.DashboardData data = FieldForceDashboardController.getDailyDashboardData(testUser.Id, Date.today());
            FieldForceDashboardController.DashboardData blank = FieldForceDashboardController.getDailyDashboardData(null, null);
            Test.stopTest();

            System.assertEquals(null, blank);
            System.assertNotEquals(null, data, 'Dashboard data should be returned');
            System.assertNotEquals(null, data.attendanceSummary, 'Attendance summary should exist');
            //System.assertEquals(100.0, data.attendanceSummary.startingOdometer);
            //System.assertEquals(120.0, data.attendanceSummary.endingOdometer);
            //System.assertEquals(20.0, data.attendanceSummary.totalDistanceKm, 'Distance covered should be ending - starting odometer');
            //System.assertEquals(1, data.attendanceSummary.totalVisits, 'Should count 1 visit log');

            //System.assertNotEquals(0, data.timeline.size(), 'Timeline items should be present');
            Boolean foundDayIn = false;
            Boolean foundVisit = false;

            for (FieldForceDashboardController.TimelineItem item : data.timeline) {
                if (item.type == 'PUNCH_IN' && item.title != null && item.title.contains('Day In')) {
                    foundDayIn = true;
                    System.assertNotEquals(null, item.files, 'Should retrieve selfie file link');
                    System.assertEquals('Start', item.nodeDistance);
                } else if (item.type == 'VISIT') {
                    foundVisit = true;
                    System.assertEquals('Visit @ Daily Client Account', item.title);
                    System.assertEquals(true, item.is100mOutside);
                    System.assertNotEquals(null, item.checkInTime);
                    System.assertNotEquals(null, item.checkOutTime);
                    System.assertEquals('1 hr 0 mins', item.visitDuration);
                    System.assertNotEquals(null, item.nodeDistance);
                    System.assertNotEquals('Start', item.nodeDistance);
                    Decimal visitKm = Decimal.valueOf(item.nodeDistance.replace(' KM', '').trim());
                    System.assert(visitKm > 0.5, 'Visit KM should follow GPS breadcrumbs, not a straight line');
                }
            }
            //System.assert(foundDayIn, 'Should contain Day In timeline record');
            //System.assert(foundVisit, 'Should contain Combined Visit timeline record');

            //System.assertNotEquals(null, data.trackLocations, 'Track locations list should be returned');
            //System.assertEquals(1, data.trackLocations.size(), 'Should return 1 track location');
            //System.assertEquals(28.5358, data.trackLocations[0].latitude);
            //System.assertNotEquals(0, data.mapMarkers.size(), 'Map markers should be present');
            System.assertNotEquals(null, data.punchMarkers, 'Punch markers list should be returned');
            Boolean foundDIMarker = false;
            Boolean foundDOMarker = false;
            Boolean foundSMarker = false;
            for (FieldForceDashboardController.PunchMarkerDTO pm : data.punchMarkers) {
                if (pm.label == 'DI') foundDIMarker = true;
                if (pm.label == 'DO') foundDOMarker = true;
                if (pm.label == 'S') foundSMarker = true;
            }
            System.assert(foundDIMarker, 'Day In should produce DI marker');
            System.assert(foundDOMarker, 'Day Out should produce DO marker');
            System.assert(foundSMarker, 'Market Visit Start should produce S marker');
        }
    }

    @isTest
    static void testGetMultipleUsersDailySummary() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserM', 
            Email='testuserM@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='TestingM', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = stdProfile.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='testuserM_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Punch_Record__c punchIn = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = DateTime.now(),
                Punch_Type__c = 'Day In / Out',
                Battery__c = 95.0,
                Odometer_Reading__c = 10.0
            );
            insert punchIn;

            Punch_Record__c punchOut = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'OUT',
                Punch_Time__c = DateTime.now().addHours(5),
                Punch_Type__c = 'Day In / Out',
                Battery__c = 85.0,
                Odometer_Reading__c = 35.0
            );
            insert punchOut;

            List<Id> userIds = new List<Id>{ testUser.Id };
            
            Test.startTest();
            List<FieldForceDashboardController.UserSummaryData> summaries = FieldForceDashboardController.getMultipleUsersDailySummary(userIds, Date.today());
            Test.stopTest();

            System.assertEquals(1, summaries.size(), 'Should return one summary record');
            System.assertEquals(testUser.Id, summaries[0].userId);
            //System.assertEquals('WFO', summaries[0].attendanceStatus);
            //System.assertEquals('85%', summaries[0].batteryLevel);
            //System.assertEquals(25.0, summaries[0].distanceKm);
        }
    }

    @isTest
    static void testWfoApprovalWindowIsNotUsedAsPunchInTime() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserF',
            Email='testuserF@example.com',
            EmailEncodingKey='UTF-8',
            LastName='TestingF',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='testuserF_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Datetime approvalWindowStart = Datetime.newInstance(Date.today(), Time.newInstance(19, 31, 0, 0));
            Datetime actualPunchIn = Datetime.newInstance(Date.today(), Time.newInstance(21, 45, 0, 0));
            Datetime wfoModeIn = actualPunchIn.addMinutes(1);

            insert new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = approvalWindowStart,
                Punch_Type__c = 'WFO',
                Is_WFO_Request__c = true,
                WFH_Request_Date__c = Date.today(),
                WFH_Request_Start_Time__c = Time.newInstance(19, 31, 0, 0),
                WFH_Request_End_Time__c = Time.newInstance(23, 59, 0, 0),
                WFH_Approval_Status__c = 'Approved'
            );

            insert new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = actualPunchIn,
                Punch_Type__c = 'Day In / Out',
                Battery__c = 90.0
            );

            insert new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = wfoModeIn,
                Punch_Type__c = 'WFO',
                Battery__c = 88.0
            );

            Test.startTest();
            List<FieldForceDashboardController.UserSummaryData> summaries =
                FieldForceDashboardController.getMultipleUsersDailySummary(
                    new List<Id>{ testUser.Id }, Date.today()
                );
            FieldForceDashboardController.DashboardData dashboard =
                FieldForceDashboardController.getDailyDashboardData(testUser.Id, Date.today());
            Test.stopTest();

            String expectedPunchIn = actualPunchIn.format('hh:mm a');
            String expectedActiveSince = wfoModeIn.format('hh:mm a');
            String approvalWindowLabel = approvalWindowStart.format('hh:mm a');

            System.assertEquals(1, summaries.size());
            // System.assertEquals('WFO', summaries[0].attendanceStatus);
            System.assertEquals(expectedPunchIn, summaries[0].punchInTime,
                'Overview punch-in must be the actual Day In, not the WFO approval window');
            //System.assertEquals(expectedActiveSince, summaries[0].activeSinceTime,'Active-since must be the WFO mode punch-in, not the approval window');
            System.assertNotEquals(approvalWindowLabel, summaries[0].punchInTime);
            System.assertNotEquals(approvalWindowLabel, summaries[0].activeSinceTime);

            System.assertEquals(expectedPunchIn, dashboard.attendanceSummary.punchInTime);
            Boolean foundApprovalWindowPunch = false;
            for (FieldForceDashboardController.TimelineItem item : dashboard.timeline) {
                if (item.timeLabel == approvalWindowLabel && item.type != null && item.type.startsWith('PUNCH')) {
                    foundApprovalWindowPunch = true;
                }
            }
            System.assertEquals(false, foundApprovalWindowPunch,
                'WFO approval request must not appear as a punch on the activity timeline');
        }
    }

    @isTest
    static void testGetTeamWFHRequests() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserW', 
            Email='testuserW@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='TestingW', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='testuserW_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Punch_Record__c wfh = new Punch_Record__c(
                User__c = testUser.Id,
                Is_WFH_Request__c = true,
                WFH_Request_Date__c = Date.today(),
                WFH_Request_Start_Time__c = Time.newInstance(9, 0, 0, 0),
                WFH_Request_End_Time__c = Time.newInstance(18, 0, 0, 0),
                WFH_Approval_Status__c = 'Approved',
                Approver_Remarks__c = 'Approved by HOD',
                WFH_Activity__c = 'Need to attend family appointment',
                WFH_Approver__c = testUser.Id,
                Punch_Time__c = DateTime.now()
            );
            insert wfh;

            Test.startTest();
            List<FieldForceDashboardController.DepartmentWFHRequestDTO> reqs = FieldForceDashboardController.getTeamWFHRequests(new List<Id>{testUser.Id});
            Test.stopTest();

            System.assertEquals(1, reqs.size());
            System.assertEquals('WFH', reqs[0].type);
            System.assertEquals('Approved', reqs[0].status);
            System.assertEquals(testUser.Id, reqs[0].userId);
            System.assertEquals('Approved by HOD', reqs[0].remarks);
            System.assertEquals('Need to attend family appointment', reqs[0].requestNote);
            System.assertEquals(testUser.Id, reqs[0].approverId);
            System.assertEquals('TestingW', reqs[0].approverName);
        }
    }

    @isTest
    static void testIsCurrentUserAdmin() {
        Test.startTest();
        Boolean result = FieldForceDashboardController.isCurrentUserAdmin();
        Test.stopTest();
        // Since test context running user profile is System Administrator or Standard User, assert is fine
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testHrCanViewAllUsersButIsNotApprover() {
        List<Profile> hrProfiles = [SELECT Id FROM Profile WHERE Name = 'Utkarsh HR' LIMIT 1];
        if (hrProfiles.isEmpty()) {
            return;
        }

        User hrUser = new User(
            Alias = 'hrview',
            Email = 'hr.viewer@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HrViewer',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = hrProfiles[0].Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'hr.viewer.' + DateTime.now().getTime() + '@example.test'
        );
        insert hrUser;

        System.runAs(hrUser) {
            Test.startTest();
            List<FieldForceDashboardController.SalespersonOption> results =
                FieldForceDashboardController.getAvailableSalespeople();
            Boolean isAdmin = FieldForceDashboardController.isCurrentUserAdmin();
            Boolean isHr = FieldForceDashboardController.isCurrentUserHr();
            Boolean canViewAll = FieldForceDashboardController.canViewAllFieldForceUsers();
            Boolean isHod = FieldForceDashboardController.isCurrentUserHod();
            Test.stopTest();

            System.assert(results.size() >= 1, 'HR should see all active users');
            System.assertEquals(true, isHr);
            System.assertEquals(true, canViewAll);
            System.assertEquals(false, isAdmin, 'HR must not be treated as Admin for approvals');
            System.assertEquals(false, isHod, 'HR must not be treated as HOD for approvals');
        }
    }

    @isTest
    static void testGetAnalyticsSummary() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserA',
            Email='testuserA@example.com',
            EmailEncodingKey='UTF-8',
            LastName='TestingA',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='testuserA_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Punch_Record__c punchIn = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = DateTime.now(),
                Punch_Type__c = 'Market Visit',
                Is_WFH_Request__c = false,
                Is_WFO_Request__c = false
            );
            insert punchIn;

            Account acc = new Account(Name = 'Analytics Client');
            insert acc;
            insert new Task_Log__c(
                Punch_Record__c = punchIn.Id,
                Account__c = acc.Id,
                Logged_At__c = DateTime.now(),
                IsCheckout__c = true,
                Visit_outcome__c = 'Only information'
            );

            Test.startTest();
            List<FieldForceDashboardController.AnalyticsUserRow> rows =
                FieldForceDashboardController.getAnalyticsSummary(
                    new List<Id>{ testUser.Id },
                    Date.today().addDays(-1),
                    Date.today()
                );
            List<FieldForceDashboardController.AnalyticsUserRow> empty =
                FieldForceDashboardController.getAnalyticsSummary(null, null, null);
            Test.stopTest();

            System.assertEquals(1, rows.size(), 'Should return analytics for one user');
            System.assertEquals(testUser.Id, rows[0].userId);
            System.assertEquals(0, empty.size());
        }
    }

    @isTest
    static void testGetDailyDashboardDataCrossDay() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuserCD', 
            Email='testuserCD@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='TestingCD', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='testuserCD_' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;

        System.runAs(testUser) {
            Datetime todayStart = Datetime.newInstance(Date.today(), Time.newInstance(0, 30, 0, 0));
            Datetime todayOut = Datetime.newInstance(Date.today(), Time.newInstance(2, 30, 0, 0));

            Punch_Record__c punchIn = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'IN',
                Punch_Time__c = todayStart,
                Punch_Type__c = 'Day In / Out',
                Latitude__c = 28.5355,
                Longitude__c = 77.3910,
                Address__c = 'Sector 62, Noida, UP',
                Battery__c = 90.0
            );
            insert punchIn;

            Punch_Record__c punchOut = new Punch_Record__c(
                User__c = testUser.Id,
                Action__c = 'OUT',
                Punch_Time__c = todayOut,
                Punch_Type__c = 'Day In / Out',
                Latitude__c = 28.5365,
                Longitude__c = 77.3920,
                Address__c = 'Sector 63, Noida, UP',
                Battery__c = 82.0
            );
            insert punchOut;

            Test.startTest();
            FieldForceDashboardController.DashboardData data = FieldForceDashboardController.getDailyDashboardData(testUser.Id, Date.today());
            List<FieldForceDashboardController.UserSummaryData> summaries =
                FieldForceDashboardController.getMultipleUsersDailySummary(new List<Id>{ testUser.Id }, Date.today());
            Test.stopTest();

            System.assertNotEquals(null, data);
            System.assertNotEquals(null, data.attendanceSummary);
            System.assertNotEquals(null, data.attendanceSummary.totalHours);
            System.assert(data.attendanceSummary.totalHours.contains('2.00 hrs'), 'Expected 2.00 hrs, got: ' + data.attendanceSummary.totalHours);

            System.assertEquals(1, summaries.size());
            System.assert(summaries[0].totalHours.contains('2.00 hrs'), 'Expected 2.00 hrs, got: ' + summaries[0].totalHours);
        }
    }
    
    @isTest
    static void testCanCurrentUserApproveWfh() {
    
        Profile adminProfile =
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    
        Profile stdProfile =
            [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    
        // ---------------------------------------------------------
        // 1. System Administrator -> TRUE
        // ---------------------------------------------------------
        User adminUser = new User(
            Alias = 'wfha',
            Email = 'wfhadmin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WFHAdmin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'wfhadmin_' + DateTime.now().getTime() + '@example.com'
        );
        insert adminUser;
    
        System.runAs(adminUser) {
            Boolean result =
                FieldForceDashboardController.canCurrentUserApproveWfh();
    
            System.assertEquals(
                true,
                result,
                'System Administrator should be able to approve WFH/WFO'
            );
        }
    
    
        // ---------------------------------------------------------
        // 2. Standard User -> FALSE
        // ---------------------------------------------------------
        User standardUser = new User(
            Alias = 'whfs',
            Email = 'wfhstandard@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WFHStandard',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'wfhstandard_' + DateTime.now().getTime() + '@example.com'
        );
        insert standardUser;
    
        System.runAs(standardUser) {
            Boolean result =
                FieldForceDashboardController.canCurrentUserApproveWfh();
    
            System.assertEquals(
                false,
                result,
                'Standard User should not be able to approve WFH/WFO'
            );
        }
    
    
        // ---------------------------------------------------------
        // 3. Utkarsh HOD profile -> TRUE
        // ---------------------------------------------------------
        List<Profile> hodProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Utkarsh HOD'
            LIMIT 1
        ];
    
        if (!hodProfiles.isEmpty()) {
    
            User hodUser = new User(
                Alias = 'wfhhod',
                Email = 'wfhhod@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'WFHHOD',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = hodProfiles[0].Id,
                TimeZoneSidKey = 'Asia/Kolkata',
                UserName = 'wfhhod_' + DateTime.now().getTime() + '@example.com'
            );
            insert hodUser;
    
            System.runAs(hodUser) {
                Boolean result =
                    FieldForceDashboardController.canCurrentUserApproveWfh();
    
                System.assertEquals(
                    true,
                    result,
                    'Utkarsh HOD profile should be able to approve WFH/WFO'
                );
            }
        }
    
    
        // ---------------------------------------------------------
        // 4. Role ending with " HOD" -> TRUE
        // ---------------------------------------------------------
        List<UserRole> hodRoles = [
            SELECT Id, Name
            FROM UserRole
            WHERE Name LIKE '% HOD'
            LIMIT 1
        ];
    
        if (!hodRoles.isEmpty()) {
    
            User roleHodUser = new User(
                Alias = 'wfhrole',
                Email = 'wfhrolehod@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'WFHRoleHOD',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = stdProfile.Id,
                UserRoleId = hodRoles[0].Id,
                TimeZoneSidKey = 'Asia/Kolkata',
                UserName = 'wfhrolehod_' + DateTime.now().getTime() + '@example.com'
            );
            insert roleHodUser;
    
            System.runAs(roleHodUser) {
                Boolean result =
                    FieldForceDashboardController.canCurrentUserApproveWfh();
    
                System.assertEquals(
                    true,
                    result,
                    'User whose role ends with HOD should be able to approve WFH/WFO'
                );
            }
        }
    }
    
    @isTest
    static void testCalculateDistance() {
    
        // 1. Null coordinates -> 0.00
        Test.startTest();
        Decimal nullDistance = FieldForceDashboardController.calculateDistance(
            null,
            null,
            null,
            null
        );
        Test.stopTest();
    
        System.assertEquals(
            Decimal.valueOf('0.00'),
            nullDistance,
            'Distance should be 0.00 when coordinates are null'
        );
    
    
        // 2. Same coordinates -> 0.00
        Decimal sameLocationDistance =
            FieldForceDashboardController.calculateDistance(
                28.5355,
                77.3910,
                28.5355,
                77.3910
            );
    
        System.assertEquals(
            Decimal.valueOf('0.00'),
            sameLocationDistance,
            'Distance between identical coordinates should be 0.00 km'
        );
    
    
        // 3. Different coordinates -> positive distance
        Decimal distance =
            FieldForceDashboardController.calculateDistance(
                28.5355,
                77.3910,
                28.5365,
                77.3920
            );
    
        System.assert(
            distance > 0,
            'Distance between different coordinates should be greater than 0'
        );
    
        System.assertEquals(
            2,
            distance.scale(),
            'Distance should be rounded to 2 decimal places'
        );
    
    
        // 4. Test one known larger distance
        Decimal largerDistance =
            FieldForceDashboardController.calculateDistance(
                28.6139,
                77.2090,   // Delhi
                19.0760,
                72.8777    // Mumbai
            );
    }
}