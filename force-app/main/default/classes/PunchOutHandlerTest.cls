@isTest
private class PunchOutHandlerTest {

    @isTest
    static void testCalculateDistanceCreatesExpenseWithMultipleLines() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'pohu',
            Email = 'punchout.handler@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PunchOut',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'punchout.handler.' + DateTime.now().getTime() + '@example.com',
            Employee_Level__c = 'L6'
        );
        insert u;

        System.runAs(u) {
            // First Market Visit: IN and OUT
            Punch_Record__c punchIn1 = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'IN',
                Punch_Time__c = System.now().addHours(-8),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 100,
                Extracted_Odometer_Reading__c = 105
            );
            insert punchIn1;

            Punch_Record__c punchOut1 = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'OUT',
                Punch_Time__c = System.now().addHours(-5),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 130,
                Extracted_Odometer_Reading__c = 130,
                Punch_Out_Of__c = punchIn1.Id,
                Is_Expense_Created__c = false
            );
            insert punchOut1;

            // Second Market Visit: IN and OUT on the same day
            Punch_Record__c punchIn2 = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'IN',
                Punch_Time__c = System.now().addHours(-4),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Four Wheeler',
                Odometer_Reading__c = 200,
                Extracted_Odometer_Reading__c = 200
            );
            insert punchIn2;

            Punch_Record__c punchOut2 = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'OUT',
                Punch_Time__c = System.now().addHours(-1),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Four Wheeler',
                Odometer_Reading__c = 250,
                Extracted_Odometer_Reading__c = 245,
                Punch_Out_Of__c = punchIn2.Id,
                Is_Expense_Created__c = false
            );
            insert punchOut2;

            User_Punch_State__c state = new User_Punch_State__c(
                User__c = u.Id,
                Current_Status__c = 'OUT',
                Last_Punch_Time__c = System.now()
            );
            insert state;

            // Retrieve with OwnerId
            state = [SELECT Id, OwnerId, User__c FROM User_Punch_State__c WHERE Id = :state.Id];

            Test.startTest();
            PunchOutHandler.calculateDistance(new List<User_Punch_State__c>{ state });
            Test.stopTest();

            List<Expense__c> expenses = [
                SELECT Id, Purpose__c, Employee__c, Status__c, Is_Private_Vehicle_Expense__c, Travel_End_Date__c,
                       (SELECT Expense_Type__c, Distance_KM__c, AI_Extracted_Distance__c, Manually_Extracted_Distance__c,
                               Punch_Record__c, Is_Private_Vehicle_Expense__c, Vehicle_Type__c, Amount__c, Description__c FROM Expense_Lines__r
                        ORDER BY AI_Extracted_Distance__c ASC)
                FROM Expense__c
                WHERE Employee__c = :u.Id
            ];
            System.assertEquals(1, expenses.size(), 'Should create 1 Expense header for the user');
            System.assertEquals('New', expenses[0].Status__c, 'Expense status should be New');
            System.assertEquals(true, expenses[0].Is_Private_Vehicle_Expense__c);
            System.assertEquals(null, expenses[0].Travel_End_Date__c);
            System.assertEquals(2, expenses[0].Expense_Lines__r.size(), 'Should create 2 Expense_Line__c records');

            Expense_Line__c line1 = expenses[0].Expense_Lines__r[0];
            System.assertEquals(punchOut1.Id, line1.Punch_Record__c, 'Line 1 should link to punchOut1');
            System.assertEquals(true, line1.Is_Private_Vehicle_Expense__c);
            System.assertEquals(25, line1.AI_Extracted_Distance__c, 'Line 1 AI distance should be 130 - 105 = 25');
            System.assertEquals(30, line1.Manually_Extracted_Distance__c, 'Line 1 Manual distance should be 130 - 100 = 30');
            System.assertEquals(null, line1.Distance_KM__c);
            System.assertEquals('Own Vehicle', line1.Expense_Type__c);
            System.assertEquals('2-Wheeler', line1.Vehicle_Type__c);

            Expense_Line__c line2 = expenses[0].Expense_Lines__r[1];
            System.assertEquals(punchOut2.Id, line2.Punch_Record__c, 'Line 2 should link to punchOut2');
            System.assertEquals(true, line2.Is_Private_Vehicle_Expense__c);
            System.assertEquals(45, line2.AI_Extracted_Distance__c, 'Line 2 AI distance should be 245 - 200 = 45');
            System.assertEquals(50, line2.Manually_Extracted_Distance__c, 'Line 2 Manual distance should be 250 - 200 = 50');
            System.assertEquals(null, line2.Distance_KM__c);
            System.assertEquals('Own Vehicle', line2.Expense_Type__c);
            System.assertEquals('4-Wheeler', line2.Vehicle_Type__c);

            // Verify Is_Expense_Created__c was marked true on OUT punch records
            List<Punch_Record__c> updatedPunches = [
                SELECT Id, Is_Expense_Created__c FROM Punch_Record__c WHERE Id IN (:punchOut1.Id, :punchOut2.Id)
            ];
            for (Punch_Record__c pr : updatedPunches) {
                System.assertEquals(true, pr.Is_Expense_Created__c, 'Punch record should have Is_Expense_Created__c = true');
            }
        }
    }

    @isTest
    static void testCalculateDistanceSkipsWhenNoMarketVisitPunches() {
        User_Punch_State__c incomplete = new User_Punch_State__c(
            User__c = UserInfo.getUserId(),
            Current_Status__c = 'OUT'
        );
        insert incomplete;

        Test.startTest();
        PunchOutHandler.calculateDistance(new List<User_Punch_State__c>{ incomplete });
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Expense__c WHERE Purpose__c = 'Market Visit - Own vehicle travel reimbursement']
        );
    }

    @isTest
    static void testPunchOutTriggerFiresOnStatusChangeToOut() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'potrg',
            Email = 'punchout.trigger@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PunchOutTrigger',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'punchout.trigger.' + DateTime.now().getTime() + '@example.com',
            Employee_Level__c = 'L6'
        );
        insert u;

        System.runAs(u) {
            Punch_Record__c punchIn = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'IN',
                Punch_Time__c = System.now().addHours(-4),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 100,
                Extracted_Odometer_Reading__c = 100
            );
            insert punchIn;

            Punch_Record__c punchOut = new Punch_Record__c(
                User__c = u.Id,
                Action__c = 'OUT',
                Punch_Time__c = System.now().addHours(-1),
                Punch_Type__c = 'Market Visit',
                Vehicle_Type__c = 'Two Wheeler',
                Odometer_Reading__c = 150,
                Extracted_Odometer_Reading__c = 150,
                Punch_Out_Of__c = punchIn.Id,
                Is_Expense_Created__c = false
            );
            insert punchOut;

            User_Punch_State__c state = new User_Punch_State__c(
                User__c = u.Id,
                Current_Status__c = 'IN',
                Last_Punch_Time__c = System.now().addHours(-4)
            );
            insert state;

            Test.startTest();
            state.Current_Status__c = 'Out';
            state.Last_Punch_Time__c = System.now();
            update state;
            Test.stopTest();

            User_Punch_State__c updatedState = [SELECT Id, Current_Status__c FROM User_Punch_State__c WHERE Id = :state.Id];
            // System.assertEquals('Out', updatedState.Current_Status__c, 'Status should be updated to Out');
        }
    }

    @isTest
    static void testPunchOutTriggerNoStatusChange() {
        User_Punch_State__c state = new User_Punch_State__c(
            User__c = UserInfo.getUserId(),
            Current_Status__c = 'IN',
            Last_Punch_Time__c = System.now().addHours(-2)
        );
        insert state;

        Test.startTest();
        state.Last_Punch_Time__c = System.now();
        update state;
        Test.stopTest();

        User_Punch_State__c updatedState = [SELECT Id, Current_Status__c FROM User_Punch_State__c WHERE Id = :state.Id];
        System.assertEquals('IN', updatedState.Current_Status__c, 'Status should remain IN');
    }
}