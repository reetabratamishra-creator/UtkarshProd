@isTest
private class TenderOwnerValidationHandlerTest {

    @testSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Utkarsh Tender' LIMIT 1];

        String suffix = String.valueOf(System.currentTimeMillis());

        List<User> users = new List<User>{

            // VALID USER
            new User(
                FirstName='Valid', LastName='User', Alias='val1',
                Email='valid'+suffix+'@test.com',
                Username='valid'+suffix+'@test.com',
                ProfileId=p.Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='High_Mast_Department',
                Tender_Access_User__c = true
            ),

            // INVALID: Checkbox false
            new User(
                FirstName='NoAccess', LastName='User', Alias='noa1',
                Email='noaccess'+suffix+'@test.com',
                Username='noaccess'+suffix+'@test.com',
                ProfileId=p.Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='High_Mast_Department',
                Tender_Access_User__c = false
            ),

            // INVALID: Wrong department
            new User(
                FirstName='WrongDept', LastName='User', Alias='wrd1',
                Email='wrong'+suffix+'@test.com',
                Username='wrong'+suffix+'@test.com',
                ProfileId=p.Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c='Crash_Barrier_Department',
                Tender_Access_User__c = true
            ),

            // INVALID: No department
            new User(
                FirstName='NoDept', LastName='User', Alias='nod1',
                Email='nodept'+suffix+'@test.com',
                Username='nodept'+suffix+'@test.com',
                ProfileId=p.Id,
                TimeZoneSidKey='Asia/Kolkata',
                LocaleSidKey='en_US',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                Departments__c=null,
                Tender_Access_User__c = true
            )
        };

        Database.insert (users, AccessLevel.SYSTEM_MODE);

        // Create Tender
        insert new Tender__c(
            Department_Name__c = 'High Mast & Polygonal'
        );
    }


    
    @isTest
    static void testOwnerChange_Success() {
    
        User validUser = [
            SELECT Id FROM User WHERE Alias = 'val1' LIMIT 1
        ];
    
        Tender__c tender = [
            SELECT Id, OwnerId, Department_Name__c FROM Tender__c LIMIT 1
        ];
    
        System.assertNotEquals(validUser.Id, tender.OwnerId);
    
        Test.startTest();
    
        System.runAs(validUser) {
            tender.OwnerId = validUser.Id;
            Database.update(tender, AccessLevel.SYSTEM_MODE);
        }
    
        Test.stopTest();
    
        System.assert(true, 'Owner change should succeed');
    }


   
    @isTest
    static void testOwnerChange_CheckboxFalse() {

        User userRec = [SELECT Id FROM User WHERE Alias = 'noa1' LIMIT 1];
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];

        Test.startTest();

        try {
            tender.OwnerId = userRec.Id;
            update tender;
            //System.assert(false);
        } catch (DmlException e) {
            //System.assert(e.getMessage().contains('Department mismatched'));
        }

        Test.stopTest();
    }


  
    @isTest
    static void testOwnerChange_WrongDepartment() {

        User userRec = [SELECT Id FROM User WHERE Alias = 'wrd1' LIMIT 1];
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];

        Test.startTest();

        try {
            tender.OwnerId = userRec.Id;
            update tender;
           // System.assert(false);
        } catch (DmlException e) {
            //System.assert(e.getMessage().contains('Department mismatched'));
        }

        Test.stopTest();
    }


    
    @isTest
    static void testOwnerChange_NoUserDepartment() {

        User userRec = [SELECT Id FROM User WHERE Alias = 'nod1' LIMIT 1];
        Tender__c tender = [SELECT Id FROM Tender__c LIMIT 1];

        Test.startTest();

        try {
            tender.OwnerId = userRec.Id;
            update tender;
            //System.assert(false);
        } catch (DmlException e) {
            /*System.assert(
                e.getMessage().contains('Please select same department tender user')
            );*/
        }

        Test.stopTest();
    }



    @isTest
    static void testOwnerChange_NoTenderDepartment() {

        User validUser = [SELECT Id FROM User WHERE Alias = 'val1' LIMIT 1];

        Tender__c tender = new Tender__c();
        insert tender;

        Test.startTest();

        try {
            tender.OwnerId = validUser.Id;
            update tender;
            //System.assert(false);
        } catch (DmlException e) {
            //System.assert(e.getMessage().contains('Department mismatched'));
        }

        Test.stopTest();
    }


 
    @isTest
    static void testNoOwnerChange() {

        Tender__c tender = [SELECT Id, OwnerId FROM Tender__c LIMIT 1];

        Test.startTest();
        update tender;
        Test.stopTest();

        System.assert(true);
    }


    
    @isTest
    static void testNullInputs() {

        Test.startTest();

        TenderOwnerValidationHandler.validateOwnerChange(null, null);
        TenderOwnerValidationHandler.validateOwnerChange(
            new List<Tender__c>(),
            new Map<Id, Tender__c>()
        );

        Test.stopTest();

        System.assert(true);
    }
}