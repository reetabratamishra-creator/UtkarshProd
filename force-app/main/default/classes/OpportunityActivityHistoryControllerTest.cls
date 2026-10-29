@IsTest
private class OpportunityActivityHistoryControllerTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Task t = new Task(
            Subject = 'Follow Up',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = opp.Id
        );
        insert t;

        Event e = new Event(
            Subject = 'Meeting',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            WhatId = opp.Id
        );
        insert e;
    }

    @IsTest
    static void testGetActivityHistories_WithActivities() {

        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];

        Test.startTest();
        List<OpportunityActivityHistoryController.HistoryWrapper> results =
            OpportunityActivityHistoryController.getActivityHistories(opp.Id);
        Test.stopTest();

    }

    @IsTest
    static void testGetActivityHistories_NoActivities() {

        Account acc = new Account(Name = 'No Activity Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'No Activity Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        List<OpportunityActivityHistoryController.HistoryWrapper> results =
            OpportunityActivityHistoryController.getActivityHistories(opp.Id);
        Test.stopTest();

    }

    @IsTest
    static void testHistoryWrapperCompareTo() {

        OpportunityActivityHistoryController.HistoryWrapper newer =
            new OpportunityActivityHistoryController.HistoryWrapper();
        newer.changedDate = System.now();

        OpportunityActivityHistoryController.HistoryWrapper older =
            new OpportunityActivityHistoryController.HistoryWrapper();
        older.changedDate = System.now().addDays(-1);

        List<OpportunityActivityHistoryController.HistoryWrapper> wrappers =
            new List<OpportunityActivityHistoryController.HistoryWrapper>{
                older,
                newer
            };

        wrappers.sort();
    }
}