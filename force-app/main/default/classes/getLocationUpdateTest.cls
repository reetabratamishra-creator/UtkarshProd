@isTest
private class getLocationUpdateTest {

    @isTest
    static void testDoGet() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'GET';
        req.params.put('myId', 'testUserId');
        RestContext.request = req;

        Test.startTest();
        String result = getLocationUpdate.doGet();
        Test.stopTest();

        System.assert(result.contains('GET success'), 'Should return GET success message');
    }

    @isTest
    static void testDoPostNoUser() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"latitude":"28.123","longitude":"77.123"}');
        RestContext.request = req;

        Test.startTest();
        String result = getLocationUpdate.doPost();
        Test.stopTest();

        System.assert(result.contains('Error: myId parameter is missing'), 'Should fail when myId is missing');
    }

    @isTest
    static void testDoPostNoActivePunch() {
        // Create user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuser', Email='testuser@example.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='testuser_getLocationUpdate@example.com'
        );
        insert testUser;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'POST';
        req.params.put('myId', testUser.Id);
        req.requestBody = Blob.valueOf('{"latitude":"28.123","longitude":"77.123"}');
        RestContext.request = req;

        Test.startTest();
        String result = getLocationUpdate.doPost();
        Test.stopTest();

        System.assert(result.contains('Error: User is not currently punched in'), 'Should fail when user is not punched in');
    }

    @isTest
    static void testDoPostValidAndSkipped() {
        // Create user
        Profile pProfile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'tuser', Email='testuser@example.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = pProfile.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='testuser_getLocationUpdate2@example.com'
        );
        insert testUser;

        // Insert active punch-in
        Punch_Record__c punch = new Punch_Record__c(
            User__c = testUser.Id,
            Action__c = 'IN',
            Status__c = 'IN',
            Punch_Time__c = System.now(),
            Punch_Type__c = 'WFO'
        );
        insert punch;

        // Create User_Punch_State__c to set currentStatus to IN
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = testUser.Id,
            Current_Status__c = 'IN',
            Last_Punch_Time__c = System.now()
        );
        insert state;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'POST';
        req.params.put('myId', testUser.Id);
        RestContext.request = req;

        // 1. Post a new location
        req.requestBody = Blob.valueOf('{"latitude":"28.6139","longitude":"77.2090"}'); // New Delhi coordinates
        Test.startTest();
        String result1 = getLocationUpdate.doPost();
        
        // 2. Post same location (should be within 10 meters and get skipped)
        req.requestBody = Blob.valueOf('{"latitude":"28.61391","longitude":"77.20901"}'); // ~1 meter away
        String result2 = getLocationUpdate.doPost();

        // 3. Post a location that is far away (should succeed and insert)
        req.requestBody = Blob.valueOf('{"latitude":"28.6250","longitude":"77.2200"}'); // ~1.6 km away
        String result3 = getLocationUpdate.doPost();
        Test.stopTest();

        System.assert(result1.contains('location(s) logged') || result1.contains('logged'), 'First post should succeed: ' + result1);
        System.assert(result2.contains('Location updates skipped') || result2.contains('skipped'), 'Second post should be skipped: ' + result2);
        System.assert(result3.contains('location(s) logged') || result3.contains('logged'), 'Third post should succeed: ' + result3);

        List<Track_Location__c> logs = [SELECT Id FROM Track_Location__c WHERE Punch_Record__c = :punch.Id];
        System.assertEquals(2, logs.size(), 'Should have inserted exactly 2 logs, skipping the duplicate');
    }

    @isTest
    static void testDoPostNewAndroidFormat() {
        // Create user
        Profile pProfile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'tuser3', Email='testuser3@example.com',
            EmailEncodingKey='UTF-8', LastName='Testing3', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = pProfile.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='testuser_getLocationUpdate3@example.com'
        );
        insert testUser;

        // Insert active punch-in
        Punch_Record__c punch = new Punch_Record__c(
            User__c = testUser.Id,
            Action__c = 'IN',
            Status__c = 'IN',
            Punch_Time__c = System.now(),
            Punch_Type__c = 'WFO'
        );
        insert punch;

        // Create User_Punch_State__c to set currentStatus to IN
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = testUser.Id,
            Current_Status__c = 'IN',
            Last_Punch_Time__c = System.now()
        );
        insert state;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'POST';
        req.params.put('myId', testUser.Id);
        RestContext.request = req;

        // Post a new location with the new Android nested structure
        req.requestBody = Blob.valueOf('{"type":"single","session":{"clientSessionId":"0d074b6a-d299-4ff7-af71-71cf7762d2a3","startTimeEpochMs":1785678661079,"status":"Active","pointCount":1,"distanceMeters":0,"deviceInfo":"Google sdk_gphone16k_arm64 Android 17"},"point":{"clientId":"a3a73f9c-1517-4f82-8f7b-9aeef113634e","sessionClientId":"0d074b6a-d299-4ff7-af71-71cf7762d2a3","latitude":28.6139,"longitude":77.2090,"accuracyMeters":5,"speedMps":0,"altitudeMeters":5,"recordedAtEpochMs":1785678665853,"batteryPercent":100}}');
        
        Test.startTest();
        String result = getLocationUpdate.doPost();
        Test.stopTest();

        System.assert(result.contains('location(s) logged') || result.contains('logged'), 'Should successfully log nested point: ' + result);
        
        List<Track_Location__c> logs = [SELECT Latitude__c, Longitude__c FROM Track_Location__c WHERE Punch_Record__c = :punch.Id];
        System.assertEquals(1, logs.size(), 'Should have logged 1 location');
        System.assertEquals('28.6139', logs[0].Latitude__c);
        System.assertEquals('77.2090', logs[0].Longitude__c);

        User_Punch_State__c updatedState = [SELECT Battery_Percentage__c FROM User_Punch_State__c WHERE User__c = :testUser.Id LIMIT 1];
        System.assertEquals(100.0, updatedState.Battery_Percentage__c, 'Battery percentage should be updated to 100');
    }
    
    @isTest
    static void testDoPostIOSLocationsFormat() {

        // Create user
        Profile pProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    
        User testUser = new User(
            Alias = 'iosusr',
            Email = 'iosuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'IOSTesting',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = pProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'iosuser_getLocationUpdate@example.com'
        );
        insert testUser;
    
        // Create active punch
        Punch_Record__c punch = new Punch_Record__c(
            User__c = testUser.Id,
            Action__c = 'IN',
            Status__c = 'IN',
            Punch_Time__c = System.now(),
            Punch_Type__c = 'WFO'
        );
        insert punch;
    
        // Create punch state
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = testUser.Id,
            Current_Status__c = 'IN',
            Last_Punch_Time__c = System.now()
        );
        insert state;
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/updatelocation';
        req.httpMethod = 'POST';
        req.params.put('myId', testUser.Id);
    
        /*
         * iOS GeoJSON format
         *
         * IMPORTANT:
         * coordinates order is:
         * [longitude, latitude]
         */
        req.requestBody = Blob.valueOf(
            '{' +
                '"locations": [' +
                    '{' +
                        '"geometry": {' +
                            '"type": "Point",' +
                            '"coordinates": [77.2090, 28.6139]' +
                        '},' +
                        '"properties": {' +
                            '"battery_level": 0.85' +
                        '}' +
                    '}' +
                ']' +
            '}'
        );
    
        RestContext.request = req;
        RestContext.response = new RestResponse();
    
        Test.startTest();
        String result = getLocationUpdate.doPost();
        Test.stopTest();
    
        System.assert(result.contains('location(s) logged'), 'iOS location should be logged. Result: ' + result);
    
        // Verify Track_Location__c
        List<Track_Location__c> logs = [
            SELECT Id, Latitude__c, Longitude__c, Source__c, Punch_Record__c FROM Track_Location__c WHERE Punch_Record__c = :punch.Id
        ];
    
        System.assertEquals(1, logs.size(), 'Exactly one iOS location should be created');
    
        System.assertEquals('28.6139', logs[0].Latitude__c);
        System.assertEquals('77.2090', logs[0].Longitude__c);
        System.assertEquals('AppleApp', logs[0].Source__c);
    
        // Verify battery percentage
        User_Punch_State__c updatedState = [
            SELECT Battery_Percentage__c, Latitude__c, Longitude__c, Current_Status__c, Punch_In_Record__c
            FROM User_Punch_State__c WHERE User__c = :testUser.Id LIMIT 1
        ];
    
        // iOS sends 0.85 and Apex multiplies by 100
        System.assertEquals(85.0, updatedState.Battery_Percentage__c);
        System.assertEquals(Decimal.valueOf('28.6139'), updatedState.Latitude__c);
        System.assertEquals(Decimal.valueOf('77.2090'), updatedState.Longitude__c);
        System.assertEquals('IN', updatedState.Current_Status__c);
        System.assertEquals(punch.Id, updatedState.Punch_In_Record__c);
    }
}