public without sharing class TenderDeptFixScheduler implements Schedulable {

    private Date runDate;

    // Nightly schedule: all data
    public TenderDeptFixScheduler() {
        this.runDate = null;
    }

    // Optional: schedule for one particular day
    public TenderDeptFixScheduler(Date runDate) {
        this.runDate = runDate;
    }

    public void execute(SchedulableContext sc) {
        try {
            // Scope 50: each update fires TenderShareTrigger (sharing rebuild)
            Database.executeBatch(new TenderDeptFixBatch(runDate), 50);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'TenderDeptFixScheduler failed: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }
}
/*
String cronExp = '0 0 23 * * ?';

System.schedule(
    'Tender Dept Fix - Daily 11 PM',
    cronExp,
    new TenderDeptFixScheduler()
);
*/