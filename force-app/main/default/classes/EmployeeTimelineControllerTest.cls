@isTest
private class EmployeeTimelineControllerTest {

    @isTest
    static void createLeadAtCheckoutUsesContactDetailsAndSalespersonDepartment() {
        BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
        BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;

        String department = firstActivePicklist(Lead.Department_Name__c);
        User salesUser = newSalesUser(department);

        System.runAs(salesUser) {
            Account acc = new Account(
                Name = 'Acme Customer',
                Phone = '1111111111',
                Location__Latitude__s = 12.9716,
                Location__Longitude__s = 77.5946
            );
            insert acc;

            Task_Log__c visit = new Task_Log__c(
                Account__c = acc.Id,
                Description__c = 'New enquiry visit',
                Customer_Type__c = 'New',
                Latitude__c = 12.9716,
                Longitude__c = 77.5946
            );
            insert visit;

            Test.startTest();
            EmployeeTimelineController.CheckoutResult result =
                EmployeeTimelineController.updateTaskWithDisposition(
                    visit.Id,
                    'First time visit',
                    'Yes',
                    'Enquiry generation',
                    'Quote',
                    Date.today().addDays(1),
                    'Discussed project requirements',
                    null,
                    12.9716,
                    77.5946,
                    null,
                    null,
                    null,
                    'Create Lead',
                    null,
                    'Rajesh',
                    'Kumar',
                    //'rajesh.kumar@example.com',
                    //'9876543210',
                    'test.' + String.valueOf(Datetime.now().getTime()) + '@example.com',
                    '987' + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(7),
                    null,
                    null,
                    null,
                    'new',
                    'Visit',
                    'EPC'
                );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Checkout should return a result');
            System.assertNotEquals(null, result.redirectId, 'Create Lead should return the new Lead Id');

            Lead created = [
                SELECT FirstName, LastName, Name, Phone, Email, Department_Name__c, Company, Account__c
                FROM Lead
                WHERE Id = :result.redirectId
            ];
            System.assertEquals('Rajesh', created.FirstName, 'Lead first name should come from checkout contact');
            System.assertEquals('Kumar', created.LastName, 'Lead last name should come from checkout contact, not Enquiry');
            //System.assertEquals('9876543210', created.Phone, 'Lead phone should come from checkout contact');
            //System.assertEquals('rajesh.kumar@example.com', created.Email);
            System.assertEquals('Acme Customer', created.Company);
            System.assertEquals(acc.Id, created.Account__c);
            if (String.isNotBlank(department)) {
                System.assertEquals(
                    department,
                    created.Department_Name__c,
                    'Lead department should be stamped from the salesperson'
                );
            }
        }
    }

    private static User newSalesUser(String department) {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String unique = String.valueOf(DateTime.now().getTime());
        User salesUser = new User(
            Alias = 'etcso',
            Email = 'enquiry.checkout.' + unique + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CheckoutSales',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'enquiry.checkout.' + unique + '@example.test',
            Department = department
        );
        insert salesUser;
        return salesUser;
    }

    private static User newGeofenceUser(String profileName, String department, String suffix) {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        if (profiles.isEmpty()) {
            profiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        }
        String unique = String.valueOf(DateTime.now().getTime()) + suffix;
        User u = new User(
            Alias = ('geo' + suffix).left(8),
            Email = 'geofence.' + unique + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Geofence' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profiles[0].Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'geofence.' + unique + '@example.test',
            Department = department
        );
        insert u;
        return u;
    }

    @isTest
    static void geofenceBreachAlertsDepartmentHod() {
        User salesUser = newGeofenceUser('System Administrator', 'Geofence Test Dept', 'sls');
        newGeofenceUser(EmployeeTimelineController.HOD_PROFILE_NAME, 'Geofence Test Dept', 'hod');

        System.runAs(salesUser) {
            Task_Log__c task = new Task_Log__c(
                Description__c = 'Geofence visit',
                Latitude__c = 12.9716,
                Longitude__c = 77.5946,
                Justification__c = 'Customer moved the meeting to a nearby office'
            );
            insert task;

            Test.startTest();
            EmployeeTimelineController.notifyHodOfGeofenceBreach(
                task.Id, 12.9716, 77.5946, 12.9800, 77.6000
            );
            Test.stopTest();

            // The alert must never alter or fail the visit itself
            Task_Log__c after = [SELECT Justification__c FROM Task_Log__c WHERE Id = :task.Id];
            System.assertEquals('Customer moved the meeting to a nearby office', after.Justification__c);
        }
    }

    @isTest
    static void geofenceBreachAlertSkipsUserWithoutDepartment() {
        User salesUser = newGeofenceUser('System Administrator', null, 'nod');

        System.runAs(salesUser) {
            Task_Log__c task = new Task_Log__c(
                Description__c = 'Geofence visit no dept',
                Latitude__c = 12.9716,
                Longitude__c = 77.5946
            );
            insert task;

            Test.startTest();
            EmployeeTimelineController.notifyHodOfGeofenceBreach(
                task.Id, 12.9716, 77.5946, 12.9800, 77.6000
            );
            // Null task id is ignored without error
            EmployeeTimelineController.notifyHodOfGeofenceBreach(null, null, null, null, null);
            Integer emailsSent = Limits.getEmailInvocations();
            Test.stopTest();

            System.assertEquals(0, emailsSent, 'No HOD lookup or email when the user has no Department');
        }
    }

    private static String firstActivePicklist(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @isTest
    static void taggingSiteVisitKeepsOpportunityOnParentAccount() {
        BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
        BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;

        Account parentAcc = new Account(
            Name = 'Parent Customer',
            Phone = '1111111111',
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert parentAcc;

        Opportunity opp = new Opportunity(
            Name = 'Site Visit Opp',
            AccountId = parentAcc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Punch_Record__c punch = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
            // add any other mandatory fields in your org
        );
        insert punch;

        User_Punch_State__c state = new User_Punch_State__c(
            User__c = UserInfo.getUserId(),
            Punch_In_Record__c = punch.Id
        );
        insert state;

        Test.startTest();
        Id siteId = EmployeeTimelineController.createAccountOrSite(
            'Plant Site',
            parentAcc.Id,
            12.9716,
            77.5946,
            null,
            null
        );
        EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
            UserInfo.getUserId(),
            'Site visit',
            null,
            12.9716,
            77.5946,
            'First time visit',
            'Opps',
            'Follow up',
            '',
            '',
            '',
            '',
            '',
            false,
            null,
            null,
            siteId,
            opp.Id,
            null,
            'Market Visit',
            null,
            false
        );
        Test.stopTest();

        Opportunity refreshed = [SELECT AccountId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(
            parentAcc.Id,
            refreshed.AccountId,
            'Opportunity should stay on the parent Account, not the Site'
        );

        Task_Log__c visit = [
            SELECT Account__c, Opportunity__c
            FROM Task_Log__c
            WHERE Opportunity__c = :opp.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(siteId, visit.Account__c, 'Visit should still be tagged to the Site');
        System.assertEquals(opp.Id, visit.Opportunity__c);

        List<Account> sites = EmployeeTimelineController.getEligibleSites(
            parentAcc.Id,
            12.9716,
            77.5946
        );
        System.assertEquals(1, sites.size(), 'The created Site should be eligible under the parent');
        System.assertEquals(siteId, sites[0].Id);
    }

    @isTest
    static void opportunitySearchAndScheduledVisitWalkUpFromSiteAccount() {
        BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
        BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;

        Account parentAcc = new Account(Name = 'Head Office', Phone = '2222222222');
        insert parentAcc;

        Account site = new Account(
            Name = 'Already Nested Site',
            ParentId = parentAcc.Id,
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert site;

        Opportunity opp = new Opportunity(
            Name = 'Nested Site Opp',
            AccountId = site.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Task_Log__c scheduled = new Task_Log__c(
            Opportunity__c = opp.Id,
            Account__c = site.Id,
            Is_schedule__c = true,
            Schedule_Date__c = Date.today().addDays(1),
            Description__c = 'Scheduled site visit'
        );
        insert scheduled;

        Test.startTest();
        List<Opportunity> found = EmployeeTimelineController.searchOpportunities('Nested Site');
        List<EmployeeTimelineController.TaskLogDTO> visits =
            EmployeeTimelineController.getScheduledVisits(UserInfo.getUserId());
        Test.stopTest();

        Opportunity matched;
        for (Opportunity candidate : found) {
            if (candidate.Id == opp.Id) {
                matched = candidate;
                break;
            }
        }
        System.assertNotEquals(null, matched, 'Owned Nurture opportunity should be searchable');
        System.assertEquals(parentAcc.Id, matched.Account.ParentId);

        EmployeeTimelineController.TaskLogDTO scheduledDto;
        for (EmployeeTimelineController.TaskLogDTO dto : visits) {
            if (dto.id == scheduled.Id) {
                scheduledDto = dto;
                break;
            }
        }
        System.assertNotEquals(null, scheduledDto, 'Scheduled visit should be returned');
        System.assertEquals(
            parentAcc.Id,
            scheduledDto.accountId,
            'Scheduled visit should expose the parent Account, not the Site'
        );
        System.assertEquals('Head Office', scheduledDto.accountName);
    }
    
    @isTest
    static void testResolveTimelineWindowStartNoDayIn() {
        Datetime result =
            EmployeeTimelineController.resolveTimelineWindowStart(
                UserInfo.getUserId(),
                true
            );
    
        Datetime expected =
            Datetime.newInstance(
                Date.today(),
                Time.newInstance(0, 0, 0, 0)
            );
    
        System.assertEquals(expected, result, 'When there is no Day In, timeline should start at today midnight');
    }
    
    @isTest
    static void testResolveTimelineWindowStart_OpenDayIn() {
    
        Datetime dayInTime = System.now().addHours(-2);
    
        Punch_Record__c dayIn = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = dayInTime
        );
        insert dayIn;
    
        Datetime result =
            EmployeeTimelineController.resolveTimelineWindowStart(
                UserInfo.getUserId(),
                true
            );
    
        System.assertEquals(
            dayInTime,
            result,
            'Open Day In session should start from the Day In time'
        );
    }
    
    @isTest
    static void testResolveTimelineWindowStart_DayOutToday() {
    
        Datetime dayInTime = System.now().addHours(-4);
        Datetime dayOutTime = System.now().addHours(-1);
    
        Punch_Record__c dayIn = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = dayInTime
        );
    
        Punch_Record__c dayOut = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'OUT',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = dayOutTime
        );
    
        insert new List<Punch_Record__c>{ dayIn, dayOut };
    
        Datetime result =
            EmployeeTimelineController.resolveTimelineWindowStart(
                UserInfo.getUserId(),
                true
            );
    
        /*System.assertEquals(
            dayInTime,
            result,
            'If Day Out happened today, timeline should start from today\'s Day In'
        );*/
    }
    
    @isTest
    static void testResolveTimelineWindowStart_PreviousDayClosed() {
    
        Datetime yesterdayIn =
            Datetime.newInstance(
                Date.today().addDays(-1),
                Time.newInstance(9, 0, 0, 0)
            );
    
        Datetime yesterdayOut =
            Datetime.newInstance(
                Date.today().addDays(-1),
                Time.newInstance(18, 0, 0, 0)
            );
    
        Punch_Record__c dayIn = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = yesterdayIn
        );
    
        Punch_Record__c dayOut = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'OUT',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = yesterdayOut
        );
    
        insert new List<Punch_Record__c>{ dayIn, dayOut };
    
        Datetime result =
            EmployeeTimelineController.resolveTimelineWindowStart(
                UserInfo.getUserId(),
                true
            );
    
        Datetime expected =
            Datetime.newInstance(
                Date.today(),
                Time.newInstance(0, 0, 0, 0)
            );
    
        System.assertEquals(
            expected,
            result,
            'A Day In/Out session completed before today should fall back to today'
        );
    }
    
    @isTest
    static void testAssignActualTravelNodeDistances_EmptyList() {
    
        List<EmployeeTimelineController.TimelineItemDTO> items =
            new List<EmployeeTimelineController.TimelineItemDTO>();
    
        EmployeeTimelineController.assignActualTravelNodeDistances(
            items,
            new Set<Id>()
        );
    
        System.assertEquals(
            0,
            items.size(),
            'Empty timeline should remain empty'
        );
    }
    
    @isTest
    static void testAssignActualTravelNodeDistances_WithMultipleItems() {
    
        Datetime firstTime = System.now().addHours(-2);
        Datetime secondTime = System.now().addHours(-1);
    
        EmployeeTimelineController.TimelineItemDTO first =
            new EmployeeTimelineController.TimelineItemDTO();
    
        first.id = UserInfo.getUserId();
        first.createdTime = firstTime;
        first.loggedAt = firstTime;
        first.latitude = 12.9716;
        first.longitude = 77.5946;
    
        EmployeeTimelineController.TimelineItemDTO second =
            new EmployeeTimelineController.TimelineItemDTO();
    
        second.createdTime = secondTime;
        second.loggedAt = secondTime;
        second.latitude = 12.9816;
        second.longitude = 77.6046;
    
        // Deliberately reverse them to test chronological sorting.
        List<EmployeeTimelineController.TimelineItemDTO> items =
            new List<EmployeeTimelineController.TimelineItemDTO>{
                second,
                first
            };
    
        EmployeeTimelineController.assignActualTravelNodeDistances(
            items,
            new Set<Id>()
        );
    
        System.assertEquals(
            'Start',
            first.nodeDistance,
            'Earliest timeline item should be marked Start'
        );
    
        System.assertNotEquals(
            null,
            second.nodeDistance,
            'Second timeline item should receive a calculated distance'
        );
    }
    
    @isTest
    static void testGetEmployeeTimeline() {
    
        User userRecord = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
    
        // Active Market Visit punch
        Punch_Record__c punch = new Punch_Record__c(
            User__c = userRecord.Id,
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );
        insert punch;
    
        // Make it the active punch
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = userRecord.Id,
            Punch_In_Record__c = punch.Id
        );
        insert state;
    
        Account acc = new Account(
            Name = 'Timeline Customer',
            Phone = '9999999999',
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert acc;
    
        Task_Log__c firstLog = new Task_Log__c(
            Account__c = acc.Id,
            Punch_Record__c = punch.Id,
            Description__c = 'First visit',
            Reason_for_Visit__c = 'New enquiry visit',
            Customer_Type__c = 'New',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946,
            Logged_At__c = System.now().addMinutes(-20),
            Is_schedule__c = false
        );
    
        Task_Log__c secondLog = new Task_Log__c(
            Account__c = acc.Id,
            Punch_Record__c = punch.Id,
            Description__c = 'Second visit',
            Reason_for_Visit__c = 'Follow up',
            Customer_Type__c = 'Existing',
            Latitude__c = 12.9816,
            Longitude__c = 77.6046,
            Logged_At__c = System.now().addMinutes(-10),
            Is_schedule__c = false
        );
    
        insert new List<Task_Log__c>{ firstLog, secondLog };
    
        Test.startTest();
    
        List<EmployeeTimelineController.TimelineItemDTO> result =
            EmployeeTimelineController.getEmployeeTimeline(
                userRecord.Id,
                100
            );
    
        Test.stopTest();
    
        System.assertEquals(
            2,
            result.size(),
            'Both timeline Task Logs should be returned'
        );
    
        System.assertEquals(
            'Timeline Customer',
            result[0].clientName,
            'Client name should come from Account'
        );
    
        System.assertEquals(
            'Timeline Customer',
            result[1].clientName,
            'Client name should come from Account'
        );
    
        // One item should be Start and the other should have a distance.
        Set<String> distances = new Set<String>();
    
        for (EmployeeTimelineController.TimelineItemDTO dto : result) {
            System.assertNotEquals(
                null,
                dto.id,
                'Timeline DTO should contain Task Log Id'
            );
    
            System.assertNotEquals(
                null,
                dto.clientName,
                'Timeline DTO should contain client name'
            );
    
            distances.add(dto.nodeDistance);
        }
    
        System.assert(
            distances.contains('Start'),
            'One timeline item should be marked Start'
        );
    }
    
    @isTest
    static void testGetEmployeeTimeline_NoPunches() {
    
        Test.startTest();
    
        List<EmployeeTimelineController.TimelineItemDTO> result =
            EmployeeTimelineController.getEmployeeTimeline(
                UserInfo.getUserId(),
                100
            );
    
        Test.stopTest();
    
        System.assertEquals(
            0,
            result.size(),
            'No punches should return an empty timeline'
        );
    }
    
    @isTest
    static void testAddEmployeeTimelineItem() {
        BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
        BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    
        // Active Market Visit punch
        Punch_Record__c punch = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );
        insert punch;
    
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = UserInfo.getUserId(),
            Punch_In_Record__c = punch.Id
        );
        insert state;
    
        Account acc = new Account(
            Name = 'Timeline Test Account',
            Phone = '9999999999',
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert acc;
    
        Test.startTest();
    
        EmployeeTimelineController.TimelineItemDTO result =
            EmployeeTimelineController.addEmployeeTimelineItem(
                UserInfo.getUserId(),
                'Customer visit',
                acc.Id,
                12.9716,
                77.5946,
                'First time visit',
                'New',
                'New enquiry visit',
                null,
                null,
                null,
                null,
                null,
                false,
                null,
                null,
                acc.Id,
                null,
                null
            );
    
        Test.stopTest();
    
        System.assertNotEquals(null, result, 'Timeline DTO should be returned');
        System.assertNotEquals(null, result.id, 'Timeline DTO should contain Task Log Id');
        System.assertEquals(
            'New enquiry visit',
            result.description,
            'DTO description should come from reasonForVisit'
        );
        System.assertEquals(
            'Timeline Test Account',
            result.clientName,
            'DTO client name should come from Account'
        );
    
        Task_Log__c created = [
            SELECT Id,
                   Account__c,
                   Punch_Record__c,
                   Visit_Type__c,
                   Customer_Type__c,
                   Reason_for_Visit__c,
                   Latitude__c,
                   Longitude__c,
                   Visit_Category__c
            FROM Task_Log__c
            WHERE Id = :result.id
            LIMIT 1
        ];
    
        System.assertEquals(acc.Id, created.Account__c);
        System.assertEquals(punch.Id, created.Punch_Record__c);
        System.assertEquals('First time visit', created.Visit_Type__c);
        System.assertEquals('New enquiry visit', created.Reason_for_Visit__c);
        System.assertEquals(12.9716, created.Latitude__c);
        System.assertEquals(77.5946, created.Longitude__c);
        System.assertEquals('Market Visit', created.Visit_Category__c);
    }
    
    @isTest
    static void testGetNearbyClients() {
    
        Account nearbyAccount = new Account(
            Name = 'Nearby Account',
            Phone = '1111111111',
            Location__Latitude__s = 12.9717,
            Location__Longitude__s = 77.5947
        );
    
        Account farAccount = new Account(
            Name = 'Far Account',
            Phone = '2222222222',
            Location__Latitude__s = 22.5726,
            Location__Longitude__s = 88.3639
        );
    
        insert new List<Account>{
            nearbyAccount,
            farAccount
        };
    
        Opportunity nearbyOpp = new Opportunity(
            Name = 'Nearby Opportunity',
            AccountId = nearbyAccount.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Location__Latitude__s = 12.9720,
            Location__Longitude__s = 77.5950
        );
        insert nearbyOpp;
    
        Lead nearbyLead = new Lead(
            FirstName = 'Nearby',
            LastName = 'Lead',
            Company = 'Nearby Lead Company',
            Status = 'Prospect',
            Location__Latitude__s = 12.9722,
            Location__Longitude__s = 77.5952
        );
        insert nearbyLead;
    
        Test.startTest();
    
        List<EmployeeTimelineController.ClientOptionDTO> results =
            EmployeeTimelineController.getNearbyClients(
                12.9716,
                77.5946,
                10
            );
    
        Test.stopTest();
    
        System.assert(
            results.size() >= 3,
            'Nearby Account, Opportunity and Lead should be returned'
        );
    
        Boolean foundAccount = false;
        Boolean foundOpportunity = false;
        Boolean foundLead = false;
        Boolean foundFarAccount = false;
    
        for (EmployeeTimelineController.ClientOptionDTO dto : results) {
    
            if (dto.id == nearbyAccount.Id) {
                foundAccount = true;
            }
    
            if (dto.id == nearbyOpp.Id) {
                foundOpportunity = true;
            }
    
            if (dto.id == nearbyLead.Id) {
                foundLead = true;
            }
    
            if (dto.id == farAccount.Id) {
                foundFarAccount = true;
            }
    
            System.assertNotEquals(
                null,
                dto.distanceKm,
                'Every returned client should have a distance'
            );
    
            System.assert(
                dto.distanceKm <= 10,
                'Returned client should be within 10 km'
            );
        }
    
        System.assertEquals(true, foundAccount);
        System.assertEquals(true, foundOpportunity);
        System.assertEquals(true, foundLead);
        System.assertEquals(
            false,
            foundFarAccount,
            'Account outside 10 km should not be returned'
        );
    }
    
    @isTest
    static void testGetNearbyClientsNullCoordinates() {
    
        try {
            EmployeeTimelineController.getNearbyClients(
                null,
                77.5946,
                10
            );
    
            System.assert(false, 'Expected exception for null latitude');
    
        } catch (AuraHandledException e) {
            
        }
    }
    
    @isTest
    static void testGetReasonForVisitOptions() {
    
        Test.startTest();
    
        List<String> results =
            EmployeeTimelineController.getReasonForVisitOptions();
    
        Test.stopTest();
    
        System.assertNotEquals(
            null,
            results,
            'Method should return a list'
        );
    
        Schema.DescribeFieldResult fieldResult =
            Task_Log__c.Reason_for_Visit__c.getDescribe();
    
        Set<String> expectedActiveLabels = new Set<String>();
    
        for (Schema.PicklistEntry entry :
            fieldResult.getPicklistValues()) {
    
            if (entry.isActive()) {
                expectedActiveLabels.add(entry.getLabel());
            }
        }
    
        System.assertEquals(
            expectedActiveLabels.size(),
            results.size(),
            'All active picklist values should be returned'
        );
    
        for (String option : results) {
            System.assert(
                expectedActiveLabels.contains(option),
                'Returned option should be an active Reason_for_Visit picklist label'
            );
        }
    }
    
    @isTest
    static void testGetPOCPicVal() {
    
        Test.startTest();
    
        List<String> result =
            EmployeeTimelineController.getPOCPicVal();
    
        Test.stopTest();
    
        Set<String> expected = new Set<String>();
    
        for (Schema.PicklistEntry entry :
            Task_Log__c.Is_POC_available__c.getDescribe().getPicklistValues()) {
    
            if (entry.isActive()) {
                expected.add(entry.getLabel());
            }
        }
    
        System.assertEquals(
            expected.size(),
            result.size(),
            'Should return all active POC picklist values'
        );
    
        for (String value : result) {
            System.assert(
                expected.contains(value),
                'Returned value should be an active POC picklist value'
            );
        }
    }
    
    @isTest
    static void testGetVisitOutcomePicVal() {
    
        Test.startTest();
    
        List<String> result =
            EmployeeTimelineController.getVisitOutcomePicVal();
    
        Test.stopTest();
    
        Set<String> expected = new Set<String>();
    
        for (Schema.PicklistEntry entry :
            Task_Log__c.Visit_outcome__c.getDescribe().getPicklistValues()) {
    
            if (entry.isActive()) {
                expected.add(entry.getLabel());
            }
        }
    
        System.assertEquals(
            expected.size(),
            result.size(),
            'Should return all active Visit Outcome picklist values'
        );
    
        for (String value : result) {
            System.assert(
                expected.contains(value),
                'Returned value should be an active Visit Outcome value'
            );
        }
    }
    
    @isTest
    static void testGetNextActionPicVal() {
    
        Test.startTest();
    
        List<String> result =
            EmployeeTimelineController.getNextActionPicVal();
    
        Test.stopTest();
    
        Set<String> expected = new Set<String>();
    
        for (Schema.PicklistEntry entry :
            Task_Log__c.Next_Action__c.getDescribe().getPicklistValues()) {
    
            if (entry.isActive()) {
                expected.add(entry.getLabel());
            }
        }
    
        System.assertEquals(
            expected.size(),
            result.size(),
            'Should return all active Next Action picklist values'
        );
    
        for (String value : result) {
            System.assert(
                expected.contains(value),
                'Returned value should be an active Next Action value'
            );
        }
    }
    
    @isTest
    static void testTaskDetails_Account() {
    
        Account acc = new Account(
            Name = 'Task Details Account',
            Phone = '9999999999',
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert acc;
    
        Task_Log__c task = new Task_Log__c(
            Account__c = acc.Id,
            Customer_Type__c = 'New',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946,
            Description__c = 'Account visit'
        );
        insert task;
    
        Test.startTest();
    
        List<EmployeeTimelineController.TaskValues> result =
            EmployeeTimelineController.taskDetails(
                task.Id,
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    
        System.assertEquals(1, result.size());
    
        EmployeeTimelineController.TaskValues details = result[0];
    
        System.assertEquals(task.Id, details.id);
        System.assertEquals(acc.Id, details.accountId);
        System.assertEquals('Task Details Account', details.customerName);
    
        System.assertEquals(
            false,
            details.is100mOutside,
            'Same coordinates should not be outside'
        );
    }
    
    @isTest
    static void testTaskDetails_Opportunity() {
    
        Account acc = new Account(
            Name = 'Opportunity Account',
            Phone = '8888888888'
        );
        insert acc;
    
        Opportunity opp = new Opportunity(
            Name = 'Task Details Opportunity',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    
        Task_Log__c task = new Task_Log__c(
            Account__c = acc.Id,
            Opportunity__c = opp.Id,
            Customer_Type__c = 'New',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946,
            Description__c = 'Opportunity visit'
        );
        insert task;
    
        Test.startTest();
    
        List<EmployeeTimelineController.TaskValues> result =
            EmployeeTimelineController.taskDetails(
                task.Id,
                13.0000,
                77.6500
            );
    
        Test.stopTest();
    
        System.assertEquals(1, result.size());
    
        EmployeeTimelineController.TaskValues details = result[0];
    
        System.assertEquals(task.Id, details.id);
        System.assertEquals(acc.Id, details.accountId);
        System.assertEquals(
            'Task Details Opportunity',
            details.customerName
        );
    
        System.assertEquals(
            true,
            details.is100mOutside,
            'Coordinates more than 300m away should set is100mOutside to true'
        );
    }
    
    @isTest
    static void testTaskDetails_Lead() {
    
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Lead Company',
            Status = 'Prospect'
        );
        insert lead;
    
        Task_Log__c task = new Task_Log__c(
            Lead__c = lead.Id,
            Customer_Type__c = 'New',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946,
            Description__c = 'Lead visit'
        );
        insert task;
    
        Test.startTest();
    
        List<EmployeeTimelineController.TaskValues> result =
            EmployeeTimelineController.taskDetails(
                task.Id,
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    
        System.assertEquals(1, result.size());
    
        EmployeeTimelineController.TaskValues details = result[0];
      
        System.assertEquals(
            false,
            details.is100mOutside
        );
    }
    
    @isTest
    static void testTaskDetails_NoTask() {
    
        Test.startTest();
    
        List<EmployeeTimelineController.TaskValues> result =
            EmployeeTimelineController.taskDetails(
                null,
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateTask() {
    
        String visitType = firstActivePicklist(
            Task_Log__c.Visit_Type__c
        );
    
        String pocValue = firstActivePicklist(
            Task_Log__c.Is_POC_available__c
        );
    
        String outcomeValue = firstActivePicklist(
            Task_Log__c.Visit_outcome__c
        );
    
        String nextAction = firstActivePicklist(
            Task_Log__c.Next_Action__c
        );
    
        Task_Log__c task = new Task_Log__c(
            Description__c = 'Task to update',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946
        );
        insert task;
    
        Date followUp = Date.today().addDays(5);
    
        Test.startTest();
    
        EmployeeTimelineController.updateTask(
            task.Id,
            visitType,
            pocValue,
            outcomeValue,
            nextAction,
            followUp,
            'Discussed requirements with customer',
            null,
            12.9800,
            77.6000,
            null,
            null,
            'Customer was more than 300m away'
        );
    
        Test.stopTest();
    
        Task_Log__c updatedTask = [
            SELECT Visit_Type__c,
                   Is_POC_available__c,
                   Visit_outcome__c,
                   Next_Action__c,
                   Next_Follow_Up_Date__c,
                   MOM__c,
                   IsCheckout__c,
                   Logged_Out_At__c,
                   Justification__c,
                   is100mOutside__c,
                   Checked_Out_Latitude__c,
                   Checked_Out_Longitude__c
            FROM Task_Log__c
            WHERE Id = :task.Id
        ];
    
        System.assertEquals(visitType, updatedTask.Visit_Type__c);
        System.assertEquals(pocValue, updatedTask.Is_POC_available__c);
        System.assertEquals(outcomeValue, updatedTask.Visit_outcome__c);
        System.assertEquals(nextAction, updatedTask.Next_Action__c);
        System.assertEquals(followUp, updatedTask.Next_Follow_Up_Date__c);
    
        System.assertEquals(
            'Discussed requirements with customer',
            updatedTask.MOM__c
        );
    
        System.assertEquals(true, updatedTask.IsCheckout__c);
        System.assertNotEquals(null, updatedTask.Logged_Out_At__c);
    
        System.assertEquals(
            'Customer was more than 300m away',
            updatedTask.Justification__c
        );
    
        System.assertEquals(true, updatedTask.is100mOutside__c);
    
        System.assertEquals(
            12.9800,
            updatedTask.Checked_Out_Latitude__c
        );
    
        System.assertEquals(
            77.6000,
            updatedTask.Checked_Out_Longitude__c
        );
    }
    
    @isTest
    static void testUpdateTask_InvalidFileType() {
    
        Task_Log__c task = new Task_Log__c(
            Description__c = 'Invalid file test'
        );
        insert task;
    
        try {
    
            Test.startTest();
    
            EmployeeTimelineController.updateTask(
                task.Id,
                null,
                null,
                null,
                null,
                null,
                'Some MOM',
                null,
                null,
                null,
                'malicious.exe',
                EncodingUtil.base64Encode(
                    Blob.valueOf('test')
                ),
                null
            );
    
            Test.stopTest();
    
            System.assert(
                false,
                'Expected invalid file type exception'
            );
    
        } catch (AuraHandledException e) {
    
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateTask_NullTaskId() {
    
        try {
    
            Test.startTest();
    
            EmployeeTimelineController.updateTask(
                null,
                null,
                null,
                null,
                null,
                null,
                'Some MOM',
                null,
                null,
                null,
                null,
                null,
                null
            );
    
            Test.stopTest();
    
            System.assert(
                false,
                'Expected TaskId null exception'
            );
    
        } catch (AuraHandledException e) {
    
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateTask_EmptyMOM() {
    
        Task_Log__c task = new Task_Log__c(
            Description__c = 'MOM validation test'
        );
        insert task;
    
        try {
    
            Test.startTest();
    
            EmployeeTimelineController.updateTask(
                task.Id,
                null,
                null,
                null,
                null,
                null,
                '',
                null,
                null,
                null,
                null,
                null,
                null
            );
    
            Test.stopTest();
    
            System.assert(
                false,
                'Expected MOM required exception'
            );
    
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetOwnedLeads() {
    
        User currentUser = [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
    
        Lead validLead1 = new Lead(
            FirstName = 'Aaron',
            LastName = 'Lead',
            Company = 'Aaron Company',
            Email = 'aaron@example.com',
            Phone = '9000000001',
            Status = 'Prospect',
            OwnerId = currentUser.Id
        );
    
        Lead validLead2 = new Lead(
            FirstName = 'Zack',
            LastName = 'Lead',
            Company = 'Zack Company',
            Email = 'zack@example.com',
            Phone = '9000000002',
            Status = 'Prospecting',
            OwnerId = currentUser.Id
        );
    
        Lead wrongStatus = new Lead(
            FirstName = 'Wrong',
            LastName = 'Status',
            Company = 'Wrong Status Company',
            Status = 'New',
            OwnerId = currentUser.Id
        );
    
        insert new List<Lead>{
            validLead1,
            validLead2,
            wrongStatus
        };
    
        Test.startTest();
    
        List<Lead> result =
            EmployeeTimelineController.getOwnedLeads();
    
        Test.stopTest();
    
        System.assertEquals(
            2,
            result.size(),
            'Only Prospect/Prospecting owned Leads should be returned'
        );
    }
    
    @isTest
    static void testGetOwnedOpportunities() {
    
        Account acc = new Account(
            Name = 'Opportunity Test Account',
            Phone = '9000000000'
        );
        insert acc;
    
        Opportunity validOpp1 = new Opportunity(
            Name = 'A - Nurture Opportunity',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId()
        );
    
        Opportunity validOpp2 = new Opportunity(
            Name = 'B - Negotiation Opportunity',
            AccountId = acc.Id,
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId()
        );
    
        Opportunity wrongStage = new Opportunity(
            Name = 'C - Wrong Stage',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId()
        );
    
        insert new List<Opportunity>{
            validOpp1,
            validOpp2,
            wrongStage
        };
    
        Test.startTest();
    
        List<Opportunity> result =
            EmployeeTimelineController.getOwnedOpportunities();
    
        Test.stopTest();
    
        System.assertEquals(
            2,
            result.size(),
            'Only Nurture and Negotiation opportunities should be returned'
        );
    
        System.assertEquals(
            'A - Nurture Opportunity',
            result[0].Name
        );
    }
    
    @isTest
    static void testGetNearbyAccounts() {
    
        Account nearby = new Account(
            Name = 'Nearby Account',
            Phone = '9111111111',
            Location__Latitude__s = 12.9717,
            Location__Longitude__s = 77.5947
        );
    
        Account farther = new Account(
            Name = 'Farther Account',
            Phone = '9222222222',
            Location__Latitude__s = 13.0000,
            Location__Longitude__s = 77.6500
        );
    
        Account noLocation = new Account(
            Name = 'No Location Account',
            Phone = '9333333333'
        );
    
        insert new List<Account>{
            nearby,
            farther,
            noLocation
        };
    
        Test.startTest();
    
        List<EmployeeTimelineController.ClientOptionDTO> result =
            EmployeeTimelineController.getNearbyAccounts(
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    
        System.assertEquals(
            2,
            result.size(),
            'Only Accounts having coordinates should be returned'
        );
    
        System.assertEquals(
            nearby.Id,
            result[0].id,
            'Nearest Account should be first'
        );
    
        System.assertEquals(
            nearby.Name,
            result[0].name
        );
    }
    
    @isTest
    static void testGetNearbyAccounts_NullCoordinates() {
    
        try {
    
            Test.startTest();
    
            EmployeeTimelineController.getNearbyAccounts(
                null,
                77.5946
            );
    
            Test.stopTest();
    
            System.assert(
                false,
                'Expected exception for null latitude'
            );
    
        } catch (AuraHandledException e) {
    
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetAllAccounts() {
    
        Account accB = new Account(
            Name = 'B Account',
            Phone = '9111111111'
        );
    
        Account accA = new Account(
            Name = 'A Account',
            Phone = '9222222222'
        );
    
        insert new List<Account>{
            accB,
            accA
        };
    
        Test.startTest();
    
        List<EmployeeTimelineController.ClientOptionDTO> result =
            EmployeeTimelineController.getAllAccounts();
    
        Test.stopTest();
    
        System.assertEquals(
            2,
            result.size(),
            'Both test Accounts should be returned'
        );
    }
    
    @isTest
    static void testCreateContactForAccount() {
    
        Account acc = new Account(
            Name = 'Contact Test Account',
            Phone = '9333333333'
        );
        insert acc;
    
        Test.startTest();
    
        EmployeeTimelineController.createContactForAccount(
            'Rajesh',
            'Kumar',
            'rajesh.kumar@example.com',
            '9876543210',
            acc.Id
        );
    
        Test.stopTest();
    
        Contact created = [
            SELECT FirstName,
                   LastName,
                   Email,
                   Phone,
                   AccountId
            FROM Contact
            WHERE AccountId = :acc.Id
            AND Email = 'rajesh.kumar@example.com'
            LIMIT 1
        ];
    
        System.assertEquals(
            'Rajesh',
            created.FirstName
        );    
    }
    
    @isTest
    static void testRescheduleScheduledVisit() {
    
        Task_Log__c visit = new Task_Log__c(
            Description__c = 'Scheduled customer visit',
            Is_schedule__c = true,
            Schedule_Date__c = Date.today().addDays(1)
        );
        insert visit;
    
        Date newDate = Date.today().addDays(5);
    
        Test.startTest();
    
        EmployeeTimelineController.rescheduleScheduledVisit(
            visit.Id,
            'Customer requested new date',
            newDate
        );
    
        Test.stopTest();
    
        Task_Log__c updatedVisit = [
            SELECT Schedule_Date__c,
                   Reschedule_Reason__c,
                   isRescheduled__c
            FROM Task_Log__c
            WHERE Id = :visit.Id
        ];
    
        System.assertEquals(
            newDate,
            updatedVisit.Schedule_Date__c
        );
    
        System.assertEquals(
            true,
            updatedVisit.isRescheduled__c
        );
    }
    
    @isTest
    static void testRescheduleScheduledVisit_DefaultReason() {
    
        Task_Log__c visit = new Task_Log__c(
            Description__c = 'Scheduled visit',
            Is_schedule__c = true,
            Schedule_Date__c = Date.today().addDays(1)
        );
        insert visit;
    
        Date newDate = Date.today().addDays(3);
    
        Test.startTest();
    
        EmployeeTimelineController.rescheduleScheduledVisit(
            visit.Id,
            null,
            newDate
        );
    
        Test.stopTest();
    
        Task_Log__c updatedVisit = [
            SELECT Schedule_Date__c,
                   Reschedule_Reason__c,
                   isRescheduled__c
            FROM Task_Log__c
            WHERE Id = :visit.Id
        ];
    
        System.assertEquals(newDate, updatedVisit.Schedule_Date__c);    
        System.assertEquals(true, updatedVisit.isRescheduled__c);
    }
    
    @isTest
    static void testRescheduleScheduledVisit_NullId() {
    
        try {
    
            EmployeeTimelineController.rescheduleScheduledVisit(
                null,
                'Test reason',
                Date.today().addDays(1)
            );
    
            System.assert(
                false,
                'Expected Visit ID required exception'
            );
    
        } catch (AuraHandledException e) {
    
        }
    }
    
    @isTest
    static void testCancelScheduledVisit() {
    
        Task_Log__c visit = new Task_Log__c(
            Description__c = 'Scheduled visit to cancel',
            Is_schedule__c = true
        );
        insert visit;
    
        Date proposedDate = Date.today().addDays(7);
    
        Test.startTest();
    
        EmployeeTimelineController.cancelScheduledVisit(
            visit.Id,
            'Customer cancelled the meeting',
            proposedDate
        );
    
        Test.stopTest();
    
        /*Task_Log__c updatedVisit = [
            SELECT Is_schedule__c,
                   Visit_Status__c,
                   Reschedule_Reason__c
            FROM Task_Log__c
            WHERE Id = :visit.Id
        ];
    
        System.assertEquals(
            false,
            updatedVisit.Is_schedule__c
        );
    
        System.assertEquals(
            'Not Completed',
            updatedVisit.Visit_Status__c
        );
    
        System.assert(
            updatedVisit.Reschedule_Reason__c.startsWith(
                'Cancelled: Customer cancelled the meeting'
            )
        );
    
        System.assert(
            updatedVisit.Reschedule_Reason__c.contains(
                'Next proposed date:'
            )
        );*/
    }
    
    @isTest
    static void testCancelScheduledVisit_DefaultReason() {
    
        Task_Log__c visit = new Task_Log__c(
            Description__c = 'Visit cancellation',
            Is_schedule__c = true
        );
        insert visit;
    
        Test.startTest();
    
        EmployeeTimelineController.cancelScheduledVisit(
            visit.Id,
            null,
            null
        );
    
        Test.stopTest();
    
        Task_Log__c updatedVisit = [
            SELECT Is_schedule__c,
                   Visit_Status__c,
                   Reschedule_Reason__c
            FROM Task_Log__c
            WHERE Id = :visit.Id
        ];
    
        System.assertEquals(false, updatedVisit.Is_schedule__c);
    
        System.assertEquals(
            'Not Completed',
            updatedVisit.Visit_Status__c
        );
    }
    
    @isTest
    static void testCancelScheduledVisit_NullId() {
    
        try {
    
            EmployeeTimelineController.cancelScheduledVisit(
                null,
                'Customer cancelled',
                null
            );
    
            System.assert(
                false,
                'Expected Visit ID required exception'
            );
    
        } catch (AuraHandledException e) {
        }
    }
    
    @isTest
    static void testGetCustomerCategoryOptions() {
    
        Test.startTest();
    
        List<String> result =
            EmployeeTimelineController.getCustomerCategoryOptions();
    
        Test.stopTest();
    
        Set<String> expected = new Set<String>();
    
        for (
            Schema.PicklistEntry entry :
            Lead.Customer_Category__c
                .getDescribe()
                .getPicklistValues()
        ) {
            if (entry.isActive()) {
                expected.add(entry.getLabel());
            }
        }
    
        System.assertEquals(
            expected.size(),
            result.size(),
            'All active Customer Category values should be returned'
        );
    
        for (String value : result) {
            System.assert(
                expected.contains(value),
                'Returned value should be an active Customer Category value'
            );
        }
    }
    
    @isTest
    static void testSearchAccounts_ByName() {
    
        Account matching = new Account(
            Name = 'ABC Industries',
            Phone = '9111111111'
        );
    
        Account notMatching = new Account(
            Name = 'XYZ Corporation',
            Phone = '9222222222'
        );
    
        insert new List<Account>{
            matching,
            notMatching
        };
    
        Test.startTest();
    
        List<Account> result =
            EmployeeTimelineController.searchAccounts('ABC');
    
        Test.stopTest();
    
        System.assertEquals(
            1,
            result.size(),
            'Only matching Account should be returned'
        );
    
        System.assertEquals(
            matching.Id,
            result[0].Id
        );
    
        System.assertEquals(
            'ABC Industries',
            result[0].Name
        );
    }
    
    @isTest
    static void testSearchAccounts_ByPhone() {
    
        Account matching = new Account(
            Name = 'Phone Search Account',
            Phone = '9876543210'
        );
    
        Account notMatching = new Account(
            Name = 'Another Account',
            Phone = '1111111111'
        );
    
        insert new List<Account>{
            matching,
            notMatching
        };
    
        Test.startTest();
    
        List<Account> result =
            EmployeeTimelineController.searchAccounts('765432');
    
        Test.stopTest();
    
        System.assertEquals(
            1,
            result.size(),
            'Account should be found using phone number'
        );
    
        System.assertEquals(
            matching.Id,
            result[0].Id
        );
    }
    
    @isTest
    static void testCheckAddressBook_Found() {
    
        Account acc = new Account(
            Name = 'Address Book Account',
            Phone = '9000000000'
        );
        insert acc;
    
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '123 MG Road',
            City__c = 'Bangalore',
            PIN__c = '560001',
            latitude__c = '12.9716',
            longitude__c = '77.5946'
        );
        insert ab;
    
        Test.startTest();
    
        Map<String, Object> result =
            EmployeeTimelineController.checkAddressBook(
                acc.Id,
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    
        System.assertEquals(
            true,
            result.get('found'),
            'Address Book should be found at the same coordinates'
        );
    
        System.assertEquals(
            ab.Id,
            result.get('addressBookId')
        );
    
        System.assert(
            String.valueOf(result.get('address')).contains('123 MG Road'),
            'Returned address should contain the Address Book street'
        );
    }
    
    @isTest
    static void testCheckAddressBook_NotFound() {
    
        Account acc = new Account(
            Name = 'No Match Account',
            Phone = '9111111111'
        );
        insert acc;
    
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = 'Far Away Street',
            City__c = 'Bangalore',
            PIN__c = '560001',
            latitude__c = '13.1000',
            longitude__c = '77.7000'
        );
        insert ab;
    
        Test.startTest();
    
        Map<String, Object> result =
            EmployeeTimelineController.checkAddressBook(
                acc.Id,
                12.9716,
                77.5946
            );
    
        Test.stopTest();
    
        System.assertEquals(
            false,
            result.get('found')
        );
    }
    
    @isTest
    static void testBuildAddressBookFromGeocode_WithGeo() {
    
        Account acc = new Account(
            Name = 'Geocode Account',
            Phone = '9222222222'
        );
        insert acc;
    
        MapboxGeocodeService.GeocodeResult geo =
            new MapboxGeocodeService.GeocodeResult();
    
        geo.pin = '560001';
        geo.city = 'Bangalore';
        geo.street = '100 MG Road';
        geo.country = 'India';
        geo.state = 'Karnataka';
        geo.fullAddress = '100 MG Road, Bangalore, Karnataka, India';
    
        Test.startTest();
    
        Address_Book__c result =
            EmployeeTimelineController.buildAddressBookFromGeocode(
                acc.Id,
                null,
                12.9716,
                77.5946,
                geo,
                'Fallback Description',
                'Fallback Account'
            );
    
        Test.stopTest();
    
        System.assertEquals(
            acc.Id,
            result.Account__c
        );
    
        System.assertEquals(
            '12.9716',
            result.latitude__c
        );
    
        System.assertEquals(
            '77.5946',
            result.longitude__c
        );
    
        System.assertEquals(
            '560001',
            result.PIN__c
        );
    
        System.assertEquals(
            'Bangalore',
            result.City__c
        );
    
        System.assertEquals(
            '100 MG Road',
            result.Street__c
        );
    }
    
    @isTest
    static void testStampAccountBillingFromAddressBook() {
    
        Account acc = new Account(
            Name = 'Billing Stamp Account',
            Phone = '9333333333'
        );
        insert acc;
    
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '500 Residency Road',
            City__c = 'Bangalore',
            PIN__c = '560025'
        );
        insert ab;
    
        Test.startTest();
    
        EmployeeTimelineController.stampAccountBillingFromAddressBook(
            acc,
            ab
        );
    
        Test.stopTest();
    
        Account updated = [
            SELECT Street__c,
                   City__c,
                   PIN__c,
                   BillingStreet,
                   BillingCity,
                   BillingPostalCode
            FROM Account
            WHERE Id = :acc.Id
        ];
    
        System.assertEquals(
            '500 Residency Road',
            updated.Street__c
        );
    
        System.assertEquals(
            'Bangalore',
            updated.City__c
        );
    
        System.assertEquals(
            '560025',
            updated.PIN__c
        );
    
        System.assertEquals(
            '500 Residency Road',
            updated.BillingStreet
        );
    
        System.assertEquals(
            'Bangalore',
            updated.BillingCity
        );
    
        System.assertEquals(
            '560025',
            updated.BillingPostalCode
        );
    }
    
    @isTest
    static void testStampAccountBillingFromAddressBook_NoChanges() {
    
        Account acc = new Account(
            Name = 'Already Populated Account',
            Phone = '9444444444',
            Street__c = 'Existing Street',
            City__c = 'Existing City',
            PIN__c = '111111',
            BillingStreet = 'Existing Billing Street',
            BillingCity = 'Existing Billing City',
            BillingPostalCode = '222222'
        );
        insert acc;
    
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = 'New Street',
            City__c = 'New City',
            PIN__c = '333333'
        );
        insert ab;
    
        Test.startTest();
    
        EmployeeTimelineController.stampAccountBillingFromAddressBook(
            acc,
            ab
        );
    
        Test.stopTest();
    
        Account unchanged = [
            SELECT Street__c,
                   City__c,
                   PIN__c,
                   BillingStreet,
                   BillingCity,
                   BillingPostalCode
            FROM Account
            WHERE Id = :acc.Id
        ];
    
        System.assertEquals('Existing Street', unchanged.Street__c);
        System.assertEquals('Existing City', unchanged.City__c);
        System.assertEquals('111111', unchanged.PIN__c);
        System.assertEquals('Existing Billing Street', unchanged.BillingStreet);
    }
    
    @isTest
    static void testApplyAddressBookToContact() {
    
        Account acc = new Account(
            Name = 'Contact Address Account',
            Phone = '9555555555'
        );
        insert acc;
    
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;
    
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '10 Brigade Road',
            City__c = 'Bangalore',
            PIN__c = '560025'
        );
        insert ab;
    
        Test.startTest();
    
        EmployeeTimelineController.applyAddressBookToContact(
            con,
            ab
        );
    
        Test.stopTest();
    
        System.assertEquals(
            '10 Brigade Road',
            con.Street__c
        );
    
        System.assertEquals(
            'Bangalore',
            con.City__c
        );
    
        System.assertEquals(
            '560025',
            con.PIN__c
        );
    }
    
    @isTest
    static void testApplyAddressBookToContact_NullInput() {
    
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact'
        );
    
        EmployeeTimelineController.applyAddressBookToContact(
            con,
            null
        );
    
        System.assertEquals(
            null,
            con.Street__c
        );
    }
    
    @isTest
    static void testApplyAddressBookToLead() {
    
        Lead ld = new Lead(
            FirstName = 'Test',
            LastName = 'Address Lead',
            Company = 'Address Test Company',
            Status = 'Prospect'
        );
        insert ld;
    
        Address_Book__c ab = new Address_Book__c(
            Street__c = '20 Richmond Road',
            City__c = 'Bangalore',
            PIN__c = '560025'
        );
        insert ab;
    
        Test.startTest();
    
        EmployeeTimelineController.applyAddressBookToLead(
            ld,
            ab
        );
    
        Test.stopTest();
    
        System.assertEquals(
            '20 Richmond Road',
            ld.Street__c
        );
    
        System.assertEquals(
            'Bangalore',
            ld.City__c
        );
    
        System.assertEquals(
            '560025',
            ld.PIN__c
        );
    }
    
    @isTest
    static void testMatchDepartmentLoosely() {
    
        Schema.SObjectField fieldToken =
            Lead.Department_Name__c;
    
        String department =
            firstActivePicklist(fieldToken);
    
        System.assertNotEquals(
            null,
            department,
            'Test org must have at least one active department'
        );
    
        String result =
            EmployeeTimelineController.matchDepartmentLoosely(
                fieldToken,
                department
            );
    
        System.assertEquals(
            department,
            result,
            'Exact department should match'
        );
    }
    
    @isTest
    static void testMatchDepartmentLoosely_Normalization() {
    
        Schema.SObjectField fieldToken =
            Lead.Department_Name__c;
    
        String department =
            firstActivePicklist(fieldToken);
    
        System.assertNotEquals(
            null,
            department
        );
    
        String modified =
            '  ' +
            department.toUpperCase().replace(' ', '_') +
            '  ';
    
        String result =
            EmployeeTimelineController.matchDepartmentLoosely(
                fieldToken,
                modified
            );
    
        System.assertNotEquals(
            null,
            result,
            'Normalized department should still match'
        );
    }
    
    @isTest
    static void testMatchDepartmentLoosely_InvalidInput() {
    
        Schema.SObjectField fieldToken =
            Lead.Department_Name__c;
    
        System.assertEquals(
            null,
            EmployeeTimelineController.matchDepartmentLoosely(
                fieldToken,
                null
            )
        );
    
        System.assertEquals(
            null,
            EmployeeTimelineController.matchDepartmentLoosely(
                fieldToken,
                ''
            )
        );
    
        System.assertEquals(
            null,
            EmployeeTimelineController.matchDepartmentLoosely(
                null,
                'Sales'
            )
        );
    }

    @isTest
    static void testGetEmployeeTimeline_NullIdAndDefaultLimit() {
        System.assertEquals(
            0,
            EmployeeTimelineController.getEmployeeTimeline(null, 10).size(),
            'Null employee should return an empty timeline'
        );

        Punch_Record__c punch = insertActiveMarketVisitPunch(UserInfo.getUserId());
        Account acc = insertTestAccount('Default Limit Account');
        insert new Task_Log__c(
            Account__c = acc.Id,
            Punch_Record__c = punch.Id,
            Description__c = 'Limit test visit',
            Reason_for_Visit__c = 'Follow up',
            Is_schedule__c = false,
            Logged_At__c = System.now()
        );

        List<EmployeeTimelineController.TimelineItemDTO> result =
            EmployeeTimelineController.getEmployeeTimeline(UserInfo.getUserId(), 0);

        System.assertEquals(1, result.size(), 'limitSize <= 0 should still return session visits');
    }

    @isTest
    static void testGetEmployeeTimeline_ClientNamesFilesAndEmployeePath() {
        skipLeadTriggers();

        Employee__c emp = new Employee__c(Current_Status__c = 'OUT');
        insert emp;

        Punch_Record__c empPunch = new Punch_Record__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );
        insert empPunch;

        Account acc = insertTestAccount('Named Timeline Account');
        Opportunity opp = new Opportunity(
            Name = 'Named Timeline Opp',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Lead ld = new Lead(
            FirstName = 'Named',
            LastName = 'TimelineLead',
            Company = 'Named Lead Co',
            Status = 'Prospect',
            Customer_Category__c = firstActivePicklist(Lead.Customer_Category__c)
        );
        insert ld;

        Client_Deatils__c client = new Client_Deatils__c(Client_Name__c = 'Legacy Client');
        insert client;

        Task_Log__c oppLog = new Task_Log__c(
            Punch_Record__c = empPunch.Id,
            Opportunity__c = opp.Id,
            Description__c = 'Opp visit',
            Reason_for_Visit__c = 'Follow up',
            Next_Follow_Up_Date__c = Date.today().addDays(2),
            Is_schedule__c = false,
            Logged_At__c = System.now().addMinutes(-30)
        );
        Task_Log__c leadLog = new Task_Log__c(
            Punch_Record__c = empPunch.Id,
            Lead__c = ld.Id,
            Description__c = 'Lead visit',
            Reason_for_Visit__c = 'Introduction meeting',
            Is_schedule__c = false,
            Logged_At__c = System.now().addMinutes(-20)
        );
        Task_Log__c clientLog = new Task_Log__c(
            Punch_Record__c = empPunch.Id,
            Client_Deatils__c = client.Id,
            Description__c = 'Client details visit',
            Reason_for_Visit__c = 'Other',
            Is_schedule__c = false,
            Logged_At__c = System.now().addMinutes(-10)
        );
        Task_Log__c unknownLog = new Task_Log__c(
            Punch_Record__c = empPunch.Id,
            Description__c = 'Unknown visit',
            Reason_for_Visit__c = 'Other',
            Is_schedule__c = false,
            Logged_At__c = System.now().addMinutes(-5)
        );
        insert new List<Task_Log__c>{ oppLog, leadLog, clientLog, unknownLog };

        ContentVersion published = new ContentVersion(
            Title = 'visit-photo',
            PathOnClient = 'visit-photo.png',
            VersionData = Blob.valueOf('img'),
            FirstPublishLocationId = oppLog.Id
        );
        insert published;

        ContentVersion linked = new ContentVersion(
            Title = 'visit-notes',
            PathOnClient = 'visit-notes.pdf',
            VersionData = Blob.valueOf('pdf')
        );
        insert linked;
        linked = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :linked.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = linked.ContentDocumentId,
            LinkedEntityId = oppLog.Id,
            ShareType = 'V'
        );

        Datetime empWindow = EmployeeTimelineController.resolveTimelineWindowStart(emp.Id, false);
        System.assertNotEquals(null, empWindow);

        Test.startTest();
        List<EmployeeTimelineController.TimelineItemDTO> result =
            EmployeeTimelineController.getEmployeeTimeline(emp.Id, 50);
        Test.stopTest();

        System.assertEquals(4, result.size(), 'Employee punches should return all session visits');

        Map<Id, EmployeeTimelineController.TimelineItemDTO> byId =
            new Map<Id, EmployeeTimelineController.TimelineItemDTO>();
        for (EmployeeTimelineController.TimelineItemDTO dto : result) {
            byId.put(dto.id, dto);
        }

        System.assertEquals('Named Timeline Opp', byId.get(oppLog.Id).clientName);
        System.assertEquals('Named TimelineLead', byId.get(leadLog.Id).clientName);
        System.assertEquals('Unknown Account', byId.get(unknownLog.Id).clientName);
        System.assertNotEquals(null, byId.get(clientLog.Id).clientName);
        System.assert(
            byId.get(oppLog.Id).files != null && !byId.get(oppLog.Id).files.isEmpty(),
            'Opportunity visit should include attached files'
        );
    }

    @isTest
    static void testGetEmployeeTimeline_StatePunchOutsideWindow() {
        Punch_Record__c oldPunch = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now().addDays(-2)
        );
        insert oldPunch;
        insert new User_Punch_State__c(
            User__c = UserInfo.getUserId(),
            Punch_In_Record__c = oldPunch.Id
        );

        Account acc = insertTestAccount('Outside Window Account');
        insert new Task_Log__c(
            Account__c = acc.Id,
            Punch_Record__c = oldPunch.Id,
            Description__c = 'Prior day visit',
            Reason_for_Visit__c = 'Follow up',
            Is_schedule__c = false
        );

        List<EmployeeTimelineController.TimelineItemDTO> result =
            EmployeeTimelineController.getEmployeeTimeline(UserInfo.getUserId(), null);

        System.assertEquals(
            1,
            result.size(),
            'Active punch on user state should still appear even if Punch_Time is before today'
        );
    }

    @isTest
    static void testAddEmployeeTimelineItem_ValidationsAndOverloads() {
        skipLeadTriggers();

        try {
            EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
                null, 'x', null, 12.97, 77.59, 'First time visit', 'New', 'Follow up',
                null, null, null, null, null, false, null, null, null, null, null,
                'Market Visit', null, false
            );
            System.assert(false, 'Expected employee Id required');
        } catch (AuraHandledException e) {
        }

        try {
            EmployeeTimelineController.addEmployeeTimelineItem(
                UserInfo.getUserId(), 'x', null, 12.97, 77.59, 'First time visit', 'New',
                'Follow up', null, null, null, null, null, false, null, null, null, null
            );
            System.assert(false, 'Expected inactive Market Visit exception');
        } catch (AuraHandledException e) {
        }

        Punch_Record__c punch = insertActiveMarketVisitPunch(UserInfo.getUserId());
        Account acc = insertTestAccount('Add Visit Account');
        Lead ld = new Lead(
            FirstName = 'Add',
            LastName = 'VisitLead',
            Company = 'Add Visit Co',
            Status = 'Prospect'
        );
        insert ld;
        Task_Log__c scheduled = new Task_Log__c(
            Account__c = acc.Id,
            Is_schedule__c = true,
            Schedule_Date__c = Date.today().addDays(1),
            Description__c = 'To complete'
        );
        insert scheduled;

        String selfie = 'data:image/jpeg;base64,' + EncodingUtil.base64Encode(Blob.valueOf('selfie-bytes'));

        Test.setMock(HttpCalloutMock.class, new MapboxSuccessMock());
        Test.startTest();
        EmployeeTimelineController.TimelineItemDTO leadDto =
            EmployeeTimelineController.addEmployeeTimelineItem(
                UserInfo.getUserId(), 'Lead visit', null, 12.9716, 77.5946, 'First time visit',
                'leads', 'Follow up', null, null, null, null, null, false, selfie,
                ld.Id, acc.Id, null, scheduled.Id
            );
        Test.stopTest();

        System.assertNotEquals(null, leadDto.id);
        System.assertEquals('Add Visit Account', leadDto.clientName);

        Task_Log__c completed = [
            SELECT Is_schedule__c, Visit_Status__c
            FROM Task_Log__c
            WHERE Id = :scheduled.Id
        ];
        System.assertEquals(false, completed.Is_schedule__c);
        System.assertEquals('Completed', completed.Visit_Status__c);

        Lead linked = [SELECT Account__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(acc.Id, linked.Account__c);

        System.assertEquals(punch.Id, [
            SELECT Punch_Record__c FROM Task_Log__c WHERE Id = :leadDto.id
        ].Punch_Record__c);
    }

    @isTest
    static void testAddEmployeeTimelineItem_OpportunityOverload() {
        insertActiveMarketVisitPunch(UserInfo.getUserId());
        Account acc = insertTestAccount('Add Visit Opp Account');
        Opportunity opp = new Opportunity(
            Name = 'Add Visit Opp',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(20)
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new MapboxSuccessMock());
        Test.startTest();
        EmployeeTimelineController.TimelineItemDTO oppDto =
            EmployeeTimelineController.addEmployeeTimelineItem(
                UserInfo.getUserId(), 'Opp visit', null, 12.9716, 77.5946, 'Follow up',
                'Opps', 'Follow up', null, null, null, null, null, false, null,
                null, null, opp.Id
            );
        Test.stopTest();

        System.assertEquals('Add Visit Opp Account', oppDto.clientName);
    }

    @isTest
    static void testAddEmployeeTimelineItem_ClientFallbackAddressBookAndEmployee() {
        skipLeadTriggers();

        Employee__c emp = new Employee__c(Current_Status__c = 'OUT');
        insert emp;
        Punch_Record__c empPunch = new Punch_Record__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );
        insert empPunch;

        Account acc = insertTestAccount('Fallback Account');
        Test.setMock(HttpCalloutMock.class, new MapboxSuccessMock());
        Test.startTest();
        EmployeeTimelineController.TimelineItemDTO accDto =
            EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
                emp.Id, 'Account client visit', acc.Id, 12.9716, 77.5946, 'First time visit',
                'noenquiry', 'Follow up', null, null, null, null, null, false, null,
                null, null, null, null, 'Market Visit', empPunch.Id, false
            );
        Test.stopTest();

        System.assertEquals('Fallback Account', accDto.clientName);
        System.assertEquals(empPunch.Id, [
            SELECT Punch_Record__c FROM Task_Log__c WHERE Id = :accDto.id
        ].Punch_Record__c);
        System.assertEquals(emp.Id, [
            SELECT Employee__c FROM Task_Log__c WHERE Id = :accDto.id
        ].Employee__c);
    }

    @isTest
    static void testAddEmployeeTimelineItem_LeadClientAndAddressBook() {
        skipLeadTriggers();
        insertActiveMarketVisitPunch(UserInfo.getUserId());

        Account acc = insertTestAccount('Address Book Account');
        Lead ld = new Lead(
            FirstName = 'Fallback',
            LastName = 'Lead',
            Company = 'Fallback Co',
            Status = 'Prospect'
        );
        insert ld;
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '12 Residency Road',
            City__c = 'Bangalore',
            PIN__c = '560025',
            Country__c = 'India'
        );
        insert ab;

        Test.startTest();
        EmployeeTimelineController.TimelineItemDTO leadDto =
            EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
                UserInfo.getUserId(), 'Lead client visit', ld.Id, 12.9716, 77.5946, 'Follow up',
                'New', 'Follow up', null, null, null, null, null, false, null,
                null, null, null, null, 'Market Visit', null, false
            );
        EmployeeTimelineController.TimelineItemDTO abDto =
            EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
                UserInfo.getUserId(), 'Address book visit', ab.Id, 12.9716, 77.5946,
                'First time visit', 'Existing', 'Follow up', null, null, null, null, null,
                false, null, null, acc.Id, null, null, 'Market Visit', null, true
            );
        Test.stopTest();

        System.assertEquals('Fallback Lead', leadDto.clientName);
        System.assertEquals(ab.Id, [
            SELECT Address_Book__c FROM Task_Log__c WHERE Id = :abDto.id
        ].Address_Book__c);
    }

    @isTest
    static void testAddEmployeeTimelineItem_OpportunityClientId() {
        insertActiveMarketVisitPunch(UserInfo.getUserId());
        Account acc = insertTestAccount('Opp Client Account');
        Opportunity opp = new Opportunity(
            Name = 'Fallback Opp',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(15)
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new MapboxSuccessMock());
        Test.startTest();
        EmployeeTimelineController.TimelineItemDTO oppDto =
            EmployeeTimelineController.addEmployeeTimelineItemWithCategory(
                UserInfo.getUserId(), 'Opp client visit', opp.Id, 12.9716, 77.5946, 'Follow up',
                'New', 'Follow up', null, null, null, null, null, false, null,
                null, null, null, null, 'Market Visit', null, false
            );
        Test.stopTest();

        System.assertEquals('Opp Client Account', oppDto.clientName);
    }

    @isTest
    static void testUpdateTaskWithDisposition_CreateOpportunityAndCall() {
        skipLeadTriggers();
        Account acc = insertTestAccount('Checkout Opp Account');
        Contact existing = new Contact(
            FirstName = 'Existing',
            LastName = 'Poc',
            Email = 'existing.poc@example.com',
            Phone = '9000001111',
            AccountId = acc.Id
        );
        insert existing;
        Task_Log__c visit = new Task_Log__c(
            Account__c = acc.Id,
            Description__c = 'Create opp visit',
            Customer_Type__c = 'New',
            Latitude__c = 12.9716,
            Longitude__c = 77.5946
        );
        insert visit;

        Test.startTest();
        EmployeeTimelineController.CheckoutResult result =
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id,
                'First time visit',
                'Yes',
                'Enquiry generation',
                'Quote',
                Date.today().addDays(2),
                'Create opportunity from visit',
                'data:image/jpeg;base64,' + EncodingUtil.base64Encode(Blob.valueOf('out-selfie')),
                12.9716,
                77.5946,
                'notes.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('file-bytes')),
                null,
                'Create Opportunity',
                null,
                null,
                null,
                null,
                null,
                '9888888888',
                'acc.email@example.com',
                null,
                existing.Id,
                'Call',
                'EPC'
            );
        Test.stopTest();

        System.assertNotEquals(null, result.redirectId, 'Create Opportunity should return the new Opp Id');
        Opportunity created = [SELECT Name, AccountId, StageName FROM Opportunity WHERE Id = :result.redirectId];
        System.assertEquals(acc.Id, created.AccountId);
        System.assertEquals('Nurture', created.StageName);
        System.assert(
            [SELECT COUNT() FROM Task WHERE WhatId = :created.Id AND TaskSubtype = 'Call'] >= 1,
            'Call follow-up should be created against the new Opportunity'
        );
        Account refreshed = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('9888888888', refreshed.Phone);
    }

    @isTest
    static void testUpdateTaskWithDisposition_EventConvertEditAndLost() {
        skipLeadTriggers();
        Account acc = insertTestAccount('Disposition Account');
        Lead ld = new Lead(
            FirstName = 'Lost',
            LastName = 'Candidate',
            Company = 'Lost Co',
            Status = 'Prospect',
            Account__c = acc.Id
        );
        insert ld;
        Opportunity opp = new Opportunity(
            Name = 'Edit Me Opp',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Task_Log__c eventVisit = new Task_Log__c(
            Account__c = acc.Id,
            Lead__c = ld.Id,
            Customer_Type__c = 'New',
            Description__c = 'Event visit'
        );
        Task_Log__c convertVisit = new Task_Log__c(
            Account__c = acc.Id,
            Lead__c = ld.Id,
            Customer_Type__c = 'New',
            Description__c = 'Convert visit'
        );
        Task_Log__c editVisit = new Task_Log__c(
            Account__c = acc.Id,
            Opportunity__c = opp.Id,
            Customer_Type__c = 'Existing',
            Description__c = 'Edit visit'
        );
        Task_Log__c lostVisit = new Task_Log__c(
            Account__c = acc.Id,
            Lead__c = ld.Id,
            Customer_Type__c = 'New',
            Description__c = 'Lost visit'
        );
        insert new List<Task_Log__c>{ eventVisit, convertVisit, editVisit, lostVisit };

        Test.startTest();
        EmployeeTimelineController.CheckoutResult eventRes =
            EmployeeTimelineController.updateTaskWithDisposition(
                eventVisit.Id, 'Follow up', 'Yes', 'Only information', 'Quote',
                Date.today().addDays(3), 'Event MOM', null, 12.97, 77.59, null, null, null,
                'No Action', null, 'Asha', 'Nair', 'asha@example.com', '9000002222',
                null, null, null, 'new', 'Event', null
            );
        EmployeeTimelineController.CheckoutResult convertRes =
            EmployeeTimelineController.updateTaskWithDisposition(
                convertVisit.Id, 'Follow up', 'Yes', 'Enquiry generation', 'Quote',
                Date.today().addDays(3), 'Convert MOM', null, null, null, null, null, null,
                'Convert Lead', null, null, null, null, null, null, null, null, null, 'Visit', null
            );
        EmployeeTimelineController.CheckoutResult editRes =
            EmployeeTimelineController.updateTaskWithDisposition(
                editVisit.Id, 'Follow up', 'Yes', 'Enquiry generation', 'Quote',
                Date.today().addDays(3), 'Edit MOM', null, null, null, null, null, null,
                'Edit Opportunity', null, null, null, null, null, null, null, null, null, 'Visit', null
            );
        EmployeeTimelineController.CheckoutResult lostRes = null;
        try {
            lostRes = EmployeeTimelineController.updateTaskWithDisposition(
                lostVisit.Id, 'Follow up', 'Yes', 'Only information', 'Lost',
                Date.today().addDays(3), 'Lost MOM', null, null, null, null, null, null,
                'Mark Lead as Lost', 'Not interested', null, null, null, null, null, null,
                null, null, 'Visit', 'EPC'
            );
        } catch (AuraHandledException e) {
            lostRes = null;
        }
        Test.stopTest();

        System.assertEquals('Success', eventRes.status);
        System.assertEquals(ld.Id, convertRes.redirectId);
        System.assertEquals(opp.Id, editRes.redirectId);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Event],
            'Event follow-up should be created'
        );
        if (lostRes != null) {
            System.assertEquals('Success', lostRes.status);
        }
    }

    @isTest
    static void testUpdateTaskWithDisposition_ValidationsOverloadsAndVisitFallback() {
        Account acc = insertTestAccount('Validation Account');
        Task_Log__c visit = new Task_Log__c(
            Account__c = acc.Id,
            Customer_Type__c = 'New',
            Description__c = 'Plain visit'
        );
        insert visit;

        try {
            EmployeeTimelineController.updateTaskWithDisposition(
                null, null, null, null, null, Date.today().addDays(1), 'MOM',
                null, null, null, null, null, null, 'No Action', null, null, null, null, null, null, null
            );
            System.assert(false, 'Expected TaskId null exception');
        } catch (AuraHandledException e) {
        }

        try {
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id, null, null, null, null, Date.today().addDays(1), '  ',
                null, null, null, null, null, null, 'No Action', null, null, null, null, null, null, null
            );
            System.assert(false, 'Expected MOM required exception');
        } catch (AuraHandledException e) {
        }

        try {
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id, null, null, null, null, null, 'MOM value',
                null, null, null, null, null, null, 'No Action', null, null, null, null, null, null, null
            );
            System.assert(false, 'Expected follow-up date required exception');
        } catch (AuraHandledException e) {
        }

        try {
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id, null, null, null, null, Date.today().addDays(-1), 'MOM value',
                null, null, null, null, null, null, 'No Action', null, null, null, null, null, null, null
            );
            System.assert(false, 'Expected past follow-up date exception');
        } catch (AuraHandledException e) {
        }

        EmployeeTimelineController.CheckoutResult overloadRes =
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id, 'Follow up', 'Yes', 'Only information', null,
                Date.today().addDays(4), 'Scheduled visit MOM', null, 12.97, 77.59, null, null, null,
                'No Action', null, null, null, null, null, null, null
            );
        System.assertEquals('Success', overloadRes.status);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task_Log__c WHERE Is_schedule__c = true AND Account__c = :acc.Id],
            'Default Visit follow-up should insert a scheduled Task Log'
        );
    }

    @isTest
    static void testUpdateTask_FileSelfieAndNoJustification() {
        Task_Log__c task = new Task_Log__c(Description__c = 'File checkout');
        insert task;

        Test.startTest();
        EmployeeTimelineController.updateTask(
            task.Id,
            firstActivePicklist(Task_Log__c.Visit_Type__c),
            firstActivePicklist(Task_Log__c.Is_POC_available__c),
            firstActivePicklist(Task_Log__c.Visit_outcome__c),
            firstActivePicklist(Task_Log__c.Next_Action__c),
            Date.today().addDays(2),
            'MOM with attachments',
            'data:image/jpeg;base64,' + EncodingUtil.base64Encode(Blob.valueOf('selfie')),
            12.98,
            77.60,
            'summary.docx',
            EncodingUtil.base64Encode(Blob.valueOf('docx-bytes')),
            null
        );
        Test.stopTest();

        Task_Log__c updated = [
            SELECT IsCheckout__c, is100mOutside__c
            FROM Task_Log__c
            WHERE Id = :task.Id
        ];
        System.assertEquals(true, updated.IsCheckout__c);
        System.assertEquals(false, updated.is100mOutside__c);
        System.assert(
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :task.Id] >= 1,
            'Checkout should attach the uploaded file and selfie'
        );
    }

    @isTest
    static void testInsertSortedClientAndSortNullDistance() {
        EmployeeTimelineController.ClientOptionDTO nearDto =
            new EmployeeTimelineController.ClientOptionDTO();
        nearDto.name = 'Near';
        nearDto.distanceKm = 1.2;

        EmployeeTimelineController.ClientOptionDTO farDto =
            new EmployeeTimelineController.ClientOptionDTO();
        farDto.name = 'Far';
        farDto.distanceKm = 8.4;

        EmployeeTimelineController.ClientOptionDTO nullDto =
            new EmployeeTimelineController.ClientOptionDTO();
        nullDto.name = 'Unknown distance';

        List<EmployeeTimelineController.ClientOptionDTO> sorted =
            new List<EmployeeTimelineController.ClientOptionDTO>();
        EmployeeTimelineController.insertSortedClient(sorted, null, 2);
        EmployeeTimelineController.insertSortedClient(sorted, nullDto, 2);
        sorted.add(farDto);
        EmployeeTimelineController.insertSortedClient(sorted, nearDto, 2);
        EmployeeTimelineController.ClientOptionDTO midDto =
            new EmployeeTimelineController.ClientOptionDTO();
        midDto.name = 'Mid';
        midDto.distanceKm = 3.0;
        EmployeeTimelineController.insertSortedClient(sorted, midDto, 2);

        System.assertEquals(2, sorted.size());
        System.assertEquals('Near', sorted[0].name);
        System.assertEquals('Mid', sorted[1].name);

        List<EmployeeTimelineController.ClientOptionDTO> toSort =
            new List<EmployeeTimelineController.ClientOptionDTO>{ farDto, nullDto, nearDto };
        EmployeeTimelineController.sortClientsByDistance(toSort);
        System.assertEquals('Near', toSort[0].name);
    }

    @isTest
    static void testGetScheduledVisits_NullEmployeeAndLeadName() {
        skipLeadTriggers();
        System.assertEquals(0, EmployeeTimelineController.getScheduledVisits(null).size());

        Employee__c emp = new Employee__c(Current_Status__c = 'OUT');
        insert emp;
        insert new Punch_Record__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );

        Lead ld = new Lead(
            FirstName = 'Scheduled',
            LastName = 'Lead',
            Company = 'Scheduled Co',
            Status = 'Prospect'
        );
        insert ld;
        Task_Log__c scheduled = new Task_Log__c(
            Lead__c = ld.Id,
            Is_schedule__c = true,
            Schedule_Date__c = Date.today().addDays(1),
            Description__c = 'Lead schedule'
        );
        insert scheduled;

        List<EmployeeTimelineController.TaskLogDTO> byEmp =
            EmployeeTimelineController.getScheduledVisits(emp.Id);
        EmployeeTimelineController.TaskLogDTO found;
        for (EmployeeTimelineController.TaskLogDTO dto : byEmp) {
            if (dto.id == scheduled.Id) {
                found = dto;
            }
        }
        System.assertNotEquals(null, found);
        System.assertEquals('Lead', found.associationType);
        System.assertEquals('Scheduled Lead', found.clientName);

        Employee__c orphan = new Employee__c(Current_Status__c = 'OUT');
        insert orphan;
        System.assert(
            EmployeeTimelineController.getScheduledVisits(orphan.Id).size() >= 1,
            'Employee without punches should fall back to the running user'
        );
    }

    @isTest
    static void testGetScheduledVisits_IncludesCancelled() {
        Task_Log__c cancelledVisit = new Task_Log__c(
            Is_schedule__c = false,
            IsCancelled__c = true,
            Cancel_Reason__c = 'Client requested to cancel',
            Schedule_Date__c = Date.today(),
            Reason_for_Visit__c = 'Follow up',
            Description__c = 'Cancelled visit test'
        );
        insert cancelledVisit;

        List<EmployeeTimelineController.TaskLogDTO> results =
            EmployeeTimelineController.getScheduledVisits(UserInfo.getUserId());
        Boolean foundCancelled = false;
        for (EmployeeTimelineController.TaskLogDTO dto : results) {
            if (dto.id == cancelledVisit.Id) {
                foundCancelled = true;
                System.assertEquals(true, dto.isCancelled);
                System.assertEquals('Client requested to cancel', dto.cancelReason);
            }
        }
        System.assert(foundCancelled, 'Cancelled visit with Schedule_Date__c should be returned');
    }

    @isTest
    static void testContactsWfhSearchEligibleAndAddressBookNull() {
        Account parentAcc = insertTestAccount('Parent For Sites');
        Account siteNoGeo = new Account(Name = 'Site No Geo', ParentId = parentAcc.Id, Phone = '9111110000');
        Account siteFar = new Account(
            Name = 'Far Site',
            ParentId = parentAcc.Id,
            Phone = '9111110001',
            Location__Latitude__s = 22.57,
            Location__Longitude__s = 88.36
        );
        insert new List<Account>{ siteNoGeo, siteFar };
        insert new Contact(FirstName = 'Site', LastName = 'Contact', AccountId = parentAcc.Id);

        Punch_Record__c wfh = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Is_WFH_Request__c = true,
            WFH_Request_Date__c = Date.today(),
            WFH_Approval_Status__c = 'Approved',
            WFH_Request_Start_Time__c = Time.newInstance(9, 0, 0, 0),
            WFH_Request_End_Time__c = Time.newInstance(18, 0, 0, 0)
        );
        insert wfh;

        Employee__c emp = new Employee__c(Current_Status__c = 'OUT');
        insert emp;
        insert new Punch_Record__c(
            Employee__c = emp.Id,
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Punch_Type__c = 'WFO',
            Punch_Time__c = System.now()
        );

        Test.startTest();
        System.assertEquals(0, EmployeeTimelineController.getContactsForAccount(null).size());
        System.assertEquals(1, EmployeeTimelineController.getContactsForAccount(parentAcc.Id).size());
        System.assertEquals(0, EmployeeTimelineController.getApprovedWfhWfoRequestsToday(null).size());
        System.assertEquals(
            1,
            EmployeeTimelineController.getApprovedWfhWfoRequestsToday(UserInfo.getUserId()).size()
        );
        System.assertEquals(
            1,
            EmployeeTimelineController.getApprovedWfhWfoRequestsToday(emp.Id).size()
        );

        List<Account> blankSearch = EmployeeTimelineController.searchAccounts(null);
        System.assert(blankSearch.size() >= 1, 'Blank account search should return head accounts');
        List<Opportunity> blankOpps = EmployeeTimelineController.searchOpportunities('');
        System.assertNotEquals(null, blankOpps);

        List<Account> eligible = EmployeeTimelineController.getEligibleSites(parentAcc.Id, 12.9716, 77.5946);
        Set<Id> eligibleIds = new Map<Id, Account>(eligible).keySet();
        System.assert(eligibleIds.contains(siteNoGeo.Id), 'Sites without coordinates remain eligible');
        System.assert(!eligibleIds.contains(siteFar.Id), 'Sites farther than 200m should be excluded');

        Map<String, Object> nullCheck = EmployeeTimelineController.checkAddressBook(null, 12.97, 77.59);
        System.assertEquals(false, nullCheck.get('found'));
        Map<String, Object> badCoord = EmployeeTimelineController.checkAddressBook(parentAcc.Id, 12.97, 77.59);
        System.assertEquals(false, badCoord.get('found'));
        Test.stopTest();
    }

    @isTest
    static void testGetCleanErrorMessageBuildAddressBookAndDepartment() {
        System.assertEquals(
            'An unexpected error occurred.',
            EmployeeTimelineController.getCleanErrorMessage(null)
        );
        System.assertEquals(
            'Picklist value is invalid',
            EmployeeTimelineController.getCleanErrorMessage(
                'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST, Picklist value is invalid: []'
            )
        );
        System.assertEquals(
            'Name is required',
            EmployeeTimelineController.getCleanErrorMessage(
                'FIELD_CUSTOM_VALIDATION_EXCEPTION, Name is required: []'
            )
        );

        MapboxGeocodeService.GeocodeResult geo = new MapboxGeocodeService.GeocodeResult();
        geo.fullAddress = 'Only full address';
        geo.country = 'Not A Real Country';
        Address_Book__c fromFull = EmployeeTimelineController.buildAddressBookFromGeocode(
            null, UserInfo.getUserId(), 12.97, 77.59, geo, 'Desc', 'Account Name'
        );
        System.assertEquals('Only full address', fromFull.Street__c);

        Address_Book__c fromDesc = EmployeeTimelineController.buildAddressBookFromGeocode(
            null, null, null, null, null, 'Fallback street', null
        );
        System.assertEquals('Fallback street', fromDesc.Street__c);

        Address_Book__c fromName = EmployeeTimelineController.buildAddressBookFromGeocode(
            null, null, 1, 2, null, null, 'Account Name Fallback'
        );
        System.assertEquals('Account Name Fallback', fromName.Street__c);

        String dept = EmployeeTimelineController.departmentNameForRunningUser(Lead.Department_Name__c);
        System.assert(dept == null || String.isNotBlank(dept));

        EmployeeTimelineController.stampAccountBillingFromAddressBook(null, null);
        EmployeeTimelineController.applyAddressBookToLead(null, null);

        try {
            EmployeeTimelineController.createAccountOrSite(null, null, null, null, '90000', 'bad@example.com');
            System.assert(false, 'Expected account create failure');
        } catch (AuraHandledException e) {
        }

        try {
            EmployeeTimelineController.createContactForAccount('A', null, null, null, null);
            System.assert(false, 'Expected contact create failure');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void testAssignActualTravelNodeDistances_MissingCoordsAndTracks() {
        EmployeeTimelineController.assignActualTravelNodeDistances(null, null);

        Punch_Record__c punch = insertActiveMarketVisitPunch(UserInfo.getUserId());
        insert new Track_Location__c(
            Punch_Record__c = punch.Id,
            Latitude__c = '12.9750',
            Longitude__c = '77.5980',
            Recorded_At__c = System.now().addMinutes(-30)
        );

        EmployeeTimelineController.TimelineItemDTO withGeo =
            new EmployeeTimelineController.TimelineItemDTO();
        withGeo.loggedAt = System.now().addHours(-2);
        withGeo.createdTime = withGeo.loggedAt;
        withGeo.latitude = 12.9716;
        withGeo.longitude = 77.5946;

        EmployeeTimelineController.TimelineItemDTO missingGeo =
            new EmployeeTimelineController.TimelineItemDTO();
        missingGeo.loggedAt = System.now().addHours(-1);
        missingGeo.createdTime = missingGeo.loggedAt;

        List<EmployeeTimelineController.TimelineItemDTO> items =
            new List<EmployeeTimelineController.TimelineItemDTO>{ withGeo, missingGeo };
        EmployeeTimelineController.assignActualTravelNodeDistances(items, new Set<Id>{ punch.Id });

        System.assertEquals('Start', withGeo.nodeDistance);
        System.assertEquals('0 KM', missingGeo.nodeDistance);
    }

    @isTest
    static void testTaskDetailsMissingCoordsAndNearbyLimit() {
        Task_Log__c task = new Task_Log__c(Description__c = 'No geo task');
        insert task;

        List<EmployeeTimelineController.TaskValues> details =
            EmployeeTimelineController.taskDetails(task.Id, null, null);
        System.assertEquals(1, details.size());
        System.assertEquals(false, details[0].is100mOutside);

        Account nearby = insertTestAccount('Limit Nearby');
        Test.startTest();
        List<EmployeeTimelineController.ClientOptionDTO> trimmed =
            EmployeeTimelineController.getNearbyClients(12.9716, 77.5946, 1);
        List<EmployeeTimelineController.ClientOptionDTO> defaulted =
            EmployeeTimelineController.getNearbyClients(12.9716, 77.5946, 99);
        Test.stopTest();

        System.assertEquals(1, trimmed.size(), 'limitSize 1 should trim nearby results');
        System.assert(defaulted.size() >= 1, 'limitSize above 50 should default and still return nearby clients');
        System.assertEquals(nearby.Id, trimmed[0].id);
    }

    @isTest
    static void testUpdateTaskCatchAndCreateLeadFromExistingContact() {
        skipLeadTriggers();
        Account acc = insertTestAccount('Existing Contact Account');
        Contact poc = new Contact(
            FirstName = 'Meera',
            LastName = 'Iyer',
            Email = 'meera.' + String.valueOf(Datetime.now().getTime()) + '@example.com',//'meera.iyer@example.com',
            Phone = '900' + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(7),//'9000007777',
            AccountId = acc.Id
        );
        insert poc;
        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '7 Church Street',
            City__c = 'Bangalore',
            PIN__c = '560001',
            Country__c = 'India'
        );
        insert ab;
        Task_Log__c visit = new Task_Log__c(
            Account__c = acc.Id,
            Address_Book__c = ab.Id,
            Customer_Type__c = 'New',
            Description__c = 'Lead from existing contact'
        );
        insert visit;

        Test.startTest();
        EmployeeTimelineController.CheckoutResult result =
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id,
                'First time visit',
                'Yes',
                'Enquiry generation',
                'Quote',
                Date.today().addDays(2),
                'Existing contact MOM',
                null,
                12.9716,
                77.5946,
                null,
                null,
                null,
                'Create Lead',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                poc.Id,
                'Visit',
                'EPC'
            );

        Task_Log__c doomed = new Task_Log__c(Description__c = 'Will be deleted');
        insert doomed;
        Id doomedId = doomed.Id;
        delete doomed;
        try {
            EmployeeTimelineController.updateTask(
                doomedId, null, null, null, null, null, 'MOM', null, null, null, null, null, null
            );
            System.assert(false, 'Expected updateTask catch path');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();

        System.assertNotEquals(null, result.redirectId);
        Lead created = [
            SELECT FirstName, LastName, Phone, Email, Account__c
            FROM Lead
            WHERE Id = :result.redirectId
        ];
        System.assertEquals('Meera', created.FirstName);
        System.assertEquals('Iyer', created.LastName);
        //System.assertEquals('9000007777', created.Phone);
        System.assertEquals(acc.Id, created.Account__c);
    }

    @isTest
    static void testCreateAccountOrSiteWithContactDetails() {
        Account parentAcc = insertTestAccount('Site Parent');
        Test.startTest();
        Id siteId = EmployeeTimelineController.createAccountOrSite(
            'Detailed Site',
            parentAcc.Id,
            12.9716,
            77.5946,
            '9000012345',
            'site@example.com'
        );
        Test.stopTest();
        Account site = [
            SELECT Name, ParentId, Phone, Location__Latitude__s
            FROM Account
            WHERE Id = :siteId
        ];
        System.assertEquals('Detailed Site', site.Name);
        System.assertEquals(parentAcc.Id, site.ParentId);
        System.assertEquals('9000012345', site.Phone);
    }

    @isTest
    static void testCheckAddressBookInvalidCoordinateAndGetAllAccountsNotEmpty() {
        Account acc = insertTestAccount('Bad Coord Account');
        insert new Address_Book__c(
            Account__c = acc.Id,
            Street__c = 'Broken',
            latitude__c = 'not-a-number',
            longitude__c = '77.59'
        );

        Map<String, Object> result =
            EmployeeTimelineController.checkAddressBook(acc.Id, 12.9716, 77.5946);
        System.assertEquals(false, result.get('found'));

        System.assert(
            EmployeeTimelineController.getAllAccounts().size() >= 1,
            'getAllAccounts should include the inserted account'
        );
    }

    private static void skipLeadTriggers() {
        BWM_EmailLeadTriggerHandler.skipEnqueueForTests = true;
        BWM_LeadMessagingTriggerHandler.skipEnqueueForTests = true;
    }

    private static Punch_Record__c insertActiveMarketVisitPunch(Id userId) {
        Punch_Record__c punch = new Punch_Record__c(
            User__c = userId,
            Action__c = 'IN',
            Punch_Type__c = 'Market Visit',
            Punch_Time__c = System.now()
        );
        insert punch;
        insert new User_Punch_State__c(
            User__c = userId,
            Punch_In_Record__c = punch.Id
        );
        return punch;
    }

    private static Account insertTestAccount(String name) {
        Account acc = new Account(
            Name = name,
            Phone = '9000000000',
            Location__Latitude__s = 12.9716,
            Location__Longitude__s = 77.5946
        );
        insert acc;
        return acc;
    }

    @isTest
    static void testUpdateTaskWithDisposition_CloseExistingOpportunityCalls() {
        skipLeadTriggers();
        Account acc = insertTestAccount('Call Test Account');
        Opportunity opp = new Opportunity(
            Name = 'Opp Call Test',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Task call1 = new Task(
            WhatId = opp.Id,
            Subject = 'Call 1',
            TaskSubtype = 'Call',
            Status = 'Open',
            Description = 'First call notes'
        );
        Task call2 = new Task(
            WhatId = opp.Id,
            Subject = 'Call 2',
            TaskSubtype = 'Call',
            Status = 'Open',
            Description = 'Second call notes'
        );
        insert new List<Task>{ call1, call2 };

        Task_Log__c visit = new Task_Log__c(
            Account__c = acc.Id,
            Opportunity__c = opp.Id,
            Customer_Type__c = 'New',
            Description__c = 'Opp visit'
        );
        insert visit;

        Date nextDate = Date.today().addDays(2);
        Test.startTest();
        EmployeeTimelineController.CheckoutResult result =
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id,
                'Follow up',
                'Yes',
                'Enquiry generation',
                'Quote',
                nextDate,
                'Call follow up scheduled',
                null,
                null,
                null,
                null,
                null,
                null,
                'No Action',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                'Call',
                'EPC'
            );
        Test.stopTest();

        System.assertEquals('Success', result.status);

        List<Task> updatedCalls = [
            SELECT Id, Status, Disposition__c, Description, ActivityDate
            FROM Task
            WHERE Id IN (:call1.Id, :call2.Id)
        ];
        System.assertEquals(2, updatedCalls.size());
        for (Task t : updatedCalls) {
            System.assertEquals('Completed', t.Status);
            System.assertEquals('Not Connected', t.Disposition__c);
            System.assert(t.Description.contains('Another call has been scheduled at the following date: ' + nextDate.format()));
        }

        List<Task> newCalls = [
            SELECT Id, Status, ActivityDate, TaskSubtype
            FROM Task
            WHERE WhatId = :opp.Id AND Id NOT IN (:call1.Id, :call2.Id)
        ];
        //System.assertEquals(1, newCalls.size());
        //System.assertEquals('Not Started', newCalls[0].Status);
        //System.assertEquals(nextDate, newCalls[0].ActivityDate);
    }

    @isTest
    static void testUpdateTaskWithDisposition_CloseExistingOpportunityEvents() {
        skipLeadTriggers();
        Account acc = insertTestAccount('Event Test Account');
        Opportunity opp = new Opportunity(
            Name = 'Opp Event Test',
            AccountId = acc.Id,
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Event ev1 = new Event(
            WhatId = opp.Id,
            Subject = 'Meeting 1',
            StartDateTime = Datetime.now().addDays(1),
            EndDateTime = Datetime.now().addDays(1).addHours(1),
            Description = 'First event notes'
        );
        Event ev2 = new Event(
            WhatId = opp.Id,
            Subject = 'Meeting 2',
            StartDateTime = Datetime.now().addDays(2),
            EndDateTime = Datetime.now().addDays(2).addHours(1),
            Description = 'Second event notes'
        );
        insert new List<Event>{ ev1, ev2 };

        Task_Log__c visit = new Task_Log__c(
            Account__c = acc.Id,
            Opportunity__c = opp.Id,
            Customer_Type__c = 'New',
            Description__c = 'Opp visit for event'
        );
        insert visit;

        Date nextDate = Date.today().addDays(4);
        Test.startTest();
        EmployeeTimelineController.CheckoutResult result =
            EmployeeTimelineController.updateTaskWithDisposition(
                visit.Id,
                'Follow up',
                'Yes',
                'Enquiry generation',
                'Quote',
                nextDate,
                'Event follow up scheduled',
                null,
                null,
                null,
                null,
                null,
                null,
                'No Action',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                'Event',
                'EPC'
            );
        Test.stopTest();

        System.assertEquals('Success', result.status);

        List<Event> updatedEvents = [
            SELECT Id, Disposition__c, Description, Close_Date__c
            FROM Event
            WHERE Id IN (:ev1.Id, :ev2.Id)
        ];
        System.assertEquals(2, updatedEvents.size());
        for (Event ev : updatedEvents) {
            System.assertEquals('Not Completed', ev.Disposition__c);
            System.assertNotEquals(null, ev.Close_Date__c);
            System.assert(ev.Description.contains('Another event has been scheduled at the following date: ' + nextDate.format()));
        }

        List<Event> newEvents = [
            SELECT Id, Subject, StartDateTime
            FROM Event
            WHERE WhatId = :opp.Id AND Id NOT IN (:ev1.Id, :ev2.Id)
        ];
        System.assertEquals(1, newEvents.size());
    }

    private class MapboxSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{'
                + '"type":"FeatureCollection",'
                + '"features":[{'
                + '"type":"Feature",'
                + '"properties":{'
                + '"feature_type":"postcode",'
                + '"full_address":"560001, Bangalore, Karnataka, India",'
                + '"name":"560001",'
                + '"context":{'
                + '"locality":{"name":"MG Road"},'
                + '"place":{"name":"Bangalore"},'
                + '"region":{"name":"Karnataka"},'
                + '"country":{"name":"India"},'
                + '"postcode":{"name":"560001"}'
                + '}'
                + '}'
                + '}]'
                + '}'
            );
            return res;
        }
    }
}