@isTest
public class TaskRecordDetailControllerTest {
    
    @testSetup
    static void setup() {
        Task t = new Task(
            Subject = 'Test Task Subject',
            Priority = 'Normal',
            Status = 'Open'
        );
        insert t;
    }
    
    @isTest
    static void testGetTaskLayoutAdmin() {
        Task t = [SELECT Id FROM Task LIMIT 1];
        Test.startTest();
        try {
            List<TaskRecordDetailController.SectionWrapper> result = TaskRecordDetailController.getTaskLayout(t.Id);
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assert(!result.isEmpty(), 'Result sections should not be empty');
        } catch (Exception e) {
            System.assert(false, 'Admin test threw unexpected exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTaskLayoutStandard() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'CRM Head' LIMIT 1];
        User standardUser = new User(
            Alias = 'stdusr',
            Email = 'stduser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'stduser_test_' + DateTime.now().getTime() + '@testorg.com'
        );
        
        System.runAs(standardUser) {
            // Create Task as the standard user so they own it and pass sharing rules
            Task t = new Task(
                Subject = 'Standard User Test Task',
                Priority = 'Normal',
                Status = 'Open'
            );
            insert t;
            
            Test.startTest();
            try {
                List<TaskRecordDetailController.SectionWrapper> result = TaskRecordDetailController.getTaskLayout(t.Id);
                System.assertNotEquals(null, result, 'Result should not be null');
                System.assert(!result.isEmpty(), 'Result sections should not be empty');
            } catch (Exception e) {
                System.assert(false, 'Standard user test threw unexpected exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
            Test.stopTest();
        }
    }
}