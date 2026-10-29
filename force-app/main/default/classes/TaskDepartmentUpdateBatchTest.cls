@isTest
private class TaskDepartmentUpdateBatchTest {

    @testSetup
    static void setupData() {

        // Create Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Create Lead
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Department_Name__c = 'High Mast & Polygonal'
        );
        insert ld;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Department_Name__c = 'High Mast & Polygonal'
        );
        insert opp;

        // Create Tasks
        insert new List<Task>{
            new Task(
                Subject = 'Lead Task',
                Status = 'Not Started',
                Priority = 'Normal',
                WhoId = ld.Id
            ),
            new Task(
                Subject = 'Opportunity Task',
                Status = 'Not Started',
                Priority = 'Normal',
                WhatId = opp.Id
            )
        };
    }

    @isTest
    static void testBatchExecution() {

        Test.startTest();
        Database.executeBatch(new TaskDepartmentUpdateBatch(), 200);
        Test.stopTest();

        Map<String, Task> taskMap = new Map<String, Task>();

        for (Task t : [
            SELECT Subject, Department__c
            FROM Task
            WHERE Subject IN ('Lead Task', 'Opportunity Task')
        ]) {
            taskMap.put(t.Subject, t);
        }

        Lead ld = [
            SELECT Department_NameFormula__c
            FROM Lead
            LIMIT 1
        ];

        Opportunity opp = [
            SELECT Department_NameFormula__c
            FROM Opportunity
            LIMIT 1
        ];

        System.assertEquals(
            ld.Department_NameFormula__c,
            taskMap.get('Lead Task').Department__c,
            'Lead task should inherit department from Lead.'
        );

        System.assertEquals(
            opp.Department_NameFormula__c,
            taskMap.get('Opportunity Task').Department__c,
            'Opportunity task should inherit department from Opportunity.'
        );
    }
}