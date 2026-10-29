@IsTest
private class LeadActivityHistoryControllerTest {

    @TestSetup
    static void setupData() {
        Lead lead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert lead;

        Task t = new Task(
            Subject = 'Follow Up',
            Status = 'Not Started',
            Priority = 'Normal',
            WhoId = lead.Id
        );
        insert t;

        Event e = new Event(
            Subject = 'Meeting',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            WhoId = lead.Id
        );
        insert e;
    }

    @IsTest
    static void testGetActivityHistories_WithActivities() {

        Lead l = [
            SELECT Id
            FROM Lead
            LIMIT 1
        ];

        Test.startTest();
        List<LeadActivityHistoryController.HistoryWrapper> results =
            LeadActivityHistoryController.getActivityHistories(l.Id);
        Test.stopTest();

    }

    @IsTest
    static void testGetActivityHistories_NoActivities() {

        Lead l = new Lead(
            LastName = 'No Activity',
            Company = 'Company',
            Status = 'Open - Not Contacted'
        );
        insert l;

        Test.startTest();
        List<LeadActivityHistoryController.HistoryWrapper> results =
            LeadActivityHistoryController.getActivityHistories(l.Id);
        Test.stopTest();

    }

    @IsTest
    static void testHistoryWrapperCompareTo() {

        LeadActivityHistoryController.HistoryWrapper newer =
            new LeadActivityHistoryController.HistoryWrapper();
        newer.changedDate = System.now();

        LeadActivityHistoryController.HistoryWrapper older =
            new LeadActivityHistoryController.HistoryWrapper();
        older.changedDate = System.now().addDays(-1);

        List<LeadActivityHistoryController.HistoryWrapper> wrappers =
            new List<LeadActivityHistoryController.HistoryWrapper>{
                older,
                newer
            };

        wrappers.sort();
    }
}