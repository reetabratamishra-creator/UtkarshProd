/*
================================================================================
CLASS: TenderAISummaryScheduler
--------------------------------------------------------------------------------
Entry point to run TenderAISummaryBatch on a schedule.
Scope size = 50 (safely under Salesforce's 100-callouts-per-transaction limit,
leaving headroom for the logging + update DML in the same transaction).
================================================================================
*/
public class TenderAISummaryScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        System.debug('[TenderAISummaryScheduler] Firing TenderAISummaryBatch at: ' + DateTime.now());
        Database.executeBatch(new TenderAISummaryBatch(), 5);
    }
}

/*
// ================================================================
// 8:30 AM - Daily recurring
// ================================================================
System.schedule(
    'Tender AI Summary Fetch - 8:30 AM',
    '0 30 8 * * ?',
    new TenderAISummaryScheduler()
);

// ================================================================
// 4:30 PM - Daily recurring
// ================================================================
System.schedule(
    'Tender AI Summary Fetch - 4:30 PM',
    '0 30 16 * * ?',
    new TenderAISummaryScheduler()
);

// ================================================================
// 7:30 PM - Daily recurring
// ================================================================
System.schedule(
    'Tender AI Summary Fetch - 7:30 PM',
    '0 30 19 * * ?',
    new TenderAISummaryScheduler()
);

// Database.executeBatch(new TenderAISummaryBatch(), 50);
*/