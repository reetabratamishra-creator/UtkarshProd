@isTest
private class MyExpensesControllerTest {

    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'myexu',
            Email = 'myexpenses.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'MyExpensesUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'myexpenses.user.' + DateTime.now().getTime() + '@example.com',
            Employee_Level__c = 'L6'
        );
        insert u;
    }

    @isTest
    static void testGetMyExpenses_FlagsRejectedAsEditable() {
        User u = [SELECT Id FROM User WHERE Alias = 'myexu' LIMIT 1];
        System.runAs(u) {
            insert new List<Expense__c>{
                new Expense__c(Subject__c = 'Rejected trip', Status__c = 'Rejected by HOD', Employee__c = u.Id, Remark__c = 'Missing bill'),
                new Expense__c(Subject__c = 'Pending trip', Status__c = 'Pending HOD Approval', Employee__c = u.Id)
            };

            Test.startTest();
            List<MyExpensesController.ExpenseRow> rows = MyExpensesController.getMyExpenses();
            Test.stopTest();

            System.assertEquals(2, rows.size());
            for (MyExpensesController.ExpenseRow row : rows) {
                if (row.Status == 'Rejected by HOD') {
                    System.assertEquals(true, row.canEdit, 'Rejected expense should be editable');
                    System.assertEquals('Missing bill', row.Remark);
                } else {
                    System.assertEquals(false, row.canEdit, 'Pending expense should not be editable');
                }
            }
        }
    }

    @isTest
    static void testGetMyExpenses_OnlyOwnExpenses() {
        User u = [SELECT Id FROM User WHERE Alias = 'myexu' LIMIT 1];
        insert new Expense__c(Subject__c = 'Someone else', Status__c = 'New', Employee__c = UserInfo.getUserId());

        System.runAs(u) {
            Test.startTest();
            List<MyExpensesController.ExpenseRow> rows = MyExpensesController.getMyExpenses();
            Test.stopTest();
            System.assertEquals(0, rows.size(), 'Only the running user\'s expenses should be returned');
        }
    }
}