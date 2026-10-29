@isTest
private class PunchRecordHodHandlerTest {

    @isTest
    static void testHodRoleNameFromUserRole() {
        System.assertEquals(
            'Crash Barrier HOD',
            PunchRecordHodHandler.hodRoleNameFromUserRole('Crash Barrier Sales User')
        );
        System.assertEquals(
            'Crash Barrier HOD',
            PunchRecordHodHandler.hodRoleNameFromUserRole('Crash Barrier CRM Head')
        );
        System.assertEquals(
            'High Mast & Polygonal HOD',
            PunchRecordHodHandler.hodRoleNameFromUserRole('High Mast & Polygonal Sales User')
        );
        System.assertEquals(
            'Steel Tubular Poles HOD',
            PunchRecordHodHandler.hodRoleNameFromUserRole('Steel Tubular Poles HOD')
        );
        System.assertEquals(null, PunchRecordHodHandler.hodRoleNameFromUserRole(null));
    }

    @isTest
    static void testPopulateHodFromManager() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long stamp = DateTime.now().getTime();

        User hodUser = new User(
            Alias = 'hodu',
            Email = 'hoduser' + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HodUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'hoduser_' + stamp + '@example.com'
        );
        insert hodUser;

        User salesUser = new User(
            Alias = 'salesu',
            Email = 'salesuser' + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'SalesUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'salesuser_' + stamp + '@example.com',
            ManagerId = hodUser.Id
        );
        insert salesUser;

        Punch_Record__c punch;
        System.runAs(salesUser) {
            punch = new Punch_Record__c(
                User__c = salesUser.Id,
                Action__c = 'IN',
                Status__c = 'IN',
                Punch_Type__c = 'Day In / Out',
                Punch_Time__c = System.now()
            );
            PunchRecordHodHandler.applyHod(punch);
            insert punch;
        }

        Punch_Record__c stored = [SELECT HOD__c FROM Punch_Record__c WHERE Id = :punch.Id];
        System.assertEquals(hodUser.Id, stored.HOD__c, 'HOD should fall back to the user manager');
    }

    @isTest
    static void testDoesNotOverwriteExistingHod() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long stamp = DateTime.now().getTime();

        User existingHod = new User(
            Alias = 'exhod',
            Email = 'exhod' + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExistingHod',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'exhod_' + stamp + '@example.com'
        );
        insert existingHod;

        Punch_Record__c punch = new Punch_Record__c(
            User__c = UserInfo.getUserId(),
            Action__c = 'IN',
            Status__c = 'IN',
            Punch_Type__c = 'Day In / Out',
            Punch_Time__c = System.now(),
            HOD__c = existingHod.Id
        );
        PunchRecordHodHandler.applyHod(punch);
        insert punch;

        Punch_Record__c stored = [SELECT HOD__c FROM Punch_Record__c WHERE Id = :punch.Id];
        System.assertEquals(existingHod.Id, stored.HOD__c, 'Explicit HOD should be kept');
    }
}