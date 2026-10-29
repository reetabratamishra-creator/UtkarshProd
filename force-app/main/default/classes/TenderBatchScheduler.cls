/*
CLASS: TenderBatchScheduler
SCENARIO / OWNER: Ayantika

Entry point for the daily Tender247 integration. Runs twice a day via two
separate scheduled jobs (set up once, see instructions below):
- 8:00 AM run  -> MailType = 1 (Morning data)
- 4:00 PM run  -> MailType = 2 (Noon/Afternoon data)

Each run enqueues TenderListingBatch (Stage 1 of 3) with scope size = 1,
so Stage 1 processes exactly one Product per execute() call.
*/
public class TenderBatchScheduler implements Schedulable {
    
    // MailType values per Tender247 update: 0=Whole-day, 1=Morning, 2=Noon
    public static final Integer MAILTYPE_MORNING   = 1;
    public static final Integer MAILTYPE_AFTERNOON = 2;
    
    // Which run this is - set via the two separate scheduled jobs (see bottom).
    private Integer mailType;
    
    public TenderBatchScheduler(Integer mailType) {
        this.mailType = mailType;
    }
    
    
    public void execute(SchedulableContext sc) {
        
        System.debug(
            '[TenderBatchScheduler] Firing Tender247 pipeline at: '
            + DateTime.now()
            + ' | MailType=' + mailType
        );
        
        Integer batchSize = 1;
        
        // In test context, make sure all CMDT records
        // are processed in a single execute() invocation.
        if (Test.isRunningTest()) {
            
            Integer productCount = [
                SELECT COUNT()
                FROM Tender_Product_Mapping__mdt
            ];
            
            batchSize = Math.max(1, productCount);
        }
        
        Database.executeBatch(
            new TenderListingBatch(mailType),
            batchSize
        );
    }
}


/*
// ================================================================
// EVERY DAY (starting today): 4:00 PM run - unchanged, recurring
// ================================================================
System.schedule(
'Tender247 Integration - 4PM Run',
'0 0 16 * * ?',
new TenderBatchScheduler(TenderBatchScheduler.MAILTYPE_AFTERNOON)
);

// ================================================================
// EVERY DAY (starting tomorrow): 8:00 AM run - recurring
// Since today's 8AM has already passed, this recurring cron will
// simply skip today and fire for the first time tomorrow morning -
// no special "start date" logic needed.
// ================================================================
System.schedule(
'Tender247 Integration - 8AM Run',
'0 0 8 * * ?',
new TenderBatchScheduler(TenderBatchScheduler.MAILTYPE_MORNING)
);

*/