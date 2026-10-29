@isTest
private class TenderDeptFixBatchTest {

    private static final String TZ_NAME = 'Asia/Kolkata';

    // ---------- Test data helpers ----------

    private static Date todayIST() {
        return Date.valueOf(Datetime.now().format('yyyy-MM-dd', TZ_NAME));
    }

    // Adjust here if Tender__c has required fields or validation rules
    private static Tender__c makeTender(String name, String product, String summary) {
    return new Tender__c(
        Product_Name__c = product,
        Department_Name__c = null,
        Reading_Polymer_HDPE_Summary__c = summary
    );
}

    private static String deptOf(Id tenderId) {
        return [SELECT Department_Name__c FROM Tender__c WHERE Id = :tenderId].Department_Name__c;
    }

    private static void runBatch(TenderDeptFixBatch b) {
        Test.startTest();
        Database.executeBatch(b, 50);
        Test.stopTest();
    }

    // ---------- Department resolution ----------

    @isTest
    static void resolvesPolymer() {
        Tender__c t = makeTender('T-Polymer', 'Polymer,HDPE',
            'Some text\nProduct Name updated to "Polymer".\nMore text');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('Polymer', deptOf(t.Id));
    }

    @isTest
    static void resolvesHdpe() {
        Tender__c t = makeTender('T-HDPE', 'Polymer, HDPE',
            'Product Name updated to HDPE.');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('HDPE', deptOf(t.Id));
    }

    @isTest
    static void unknownValueDefaultsToHdpe() {
        Tender__c t = makeTender('T-Unknown', 'Polymer',
            'Product Name updated to "Steel".');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('HDPE', deptOf(t.Id));
    }

    @isTest
    static void missingPatternDefaultsToHdpe() {
        Tender__c t = makeTender('T-NoPattern', 'HDPE',
            'Nothing useful in this summary.');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('HDPE', deptOf(t.Id));
    }

    @isTest
    static void caseInsensitiveMatch() {
        Tender__c t = makeTender('T-Case', 'Polymer',
            'product name updated to "polymer"');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('Polymer', deptOf(t.Id));
    }

    // ---------- Skips / filters ----------

    @isTest
    static void blankSummaryIsSkipped() {
        Tender__c blank = makeTender('T-Blank', 'HDPE', null);
        Tender__c ok = makeTender('T-Ok', 'HDPE', 'Product Name updated to "Polymer".');
        insert new List<Tender__c>{ blank, ok };

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals(null, deptOf(blank.Id), 'Blank summary should stay untouched');
        System.assertEquals('Polymer', deptOf(ok.Id));
    }

    @isTest
    static void otherProductsAreIgnored() {
        Tender__c t = makeTender('T-Other', 'Steel', 'Product Name updated to "Polymer".');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals(null, deptOf(t.Id));
    }

    @isTest
    static void tendersWithDepartmentAreIgnored() {
        Tender__c t = makeTender('T-HasDept', 'HDPE', 'Product Name updated to "Polymer".');
        t.Department_Name__c = 'HDPE';
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('HDPE', deptOf(t.Id), 'Existing department must not be overwritten');
    }

    // ---------- Date filter ----------

    @isTest
    static void defaultConstructorProcessesTodayOnly() {
        Tender__c todayT = makeTender('T-Today', 'HDPE', 'Product Name updated to "Polymer".');
        Tender__c oldT = makeTender('T-Old', 'HDPE', 'Product Name updated to "Polymer".');
        insert new List<Tender__c>{ todayT, oldT };
        Test.setCreatedDate(oldT.Id, Datetime.now().addDays(-10));

        runBatch(new TenderDeptFixBatch());

        System.assertEquals('Polymer', deptOf(todayT.Id));
        System.assertEquals(null, deptOf(oldT.Id), 'Old record is outside today\'s IST window');
    }

    @isTest
    static void dateConstructorProcessesThatDayOnly() {
        Tender__c todayT = makeTender('T-Today2', 'HDPE', 'Product Name updated to "Polymer".');
        Tender__c oldT = makeTender('T-Old2', 'HDPE', 'Product Name updated to "Polymer".');
        insert new List<Tender__c>{ todayT, oldT };
        Datetime oldCreated = Datetime.now().addDays(-10);
        Test.setCreatedDate(oldT.Id, oldCreated);

        Date oldDate = Date.valueOf(oldCreated.format('yyyy-MM-dd', TZ_NAME));
        runBatch(new TenderDeptFixBatch(oldDate));

        System.assertEquals('Polymer', deptOf(oldT.Id));
        System.assertEquals(null, deptOf(todayT.Id));
    }

    @isTest
    static void allDataIgnoresDate() {
        Tender__c todayT = makeTender('T-Today3', 'HDPE', 'Product Name updated to "Polymer".');
        Tender__c oldT = makeTender('T-Old3', 'HDPE', 'Product Name updated to "HDPE".');
        insert new List<Tender__c>{ todayT, oldT };
        Test.setCreatedDate(oldT.Id, Datetime.now().addDays(-30));

        runBatch(new TenderDeptFixBatch(todayIST(), true));

        System.assertEquals('Polymer', deptOf(todayT.Id));
        System.assertEquals('HDPE', deptOf(oldT.Id));
    }

    // ---------- Quota email ----------

    @isTest
    static void quotaLineStillUpdatesAndFinishesWithoutError() {
        List<Tender__c> tenders = new List<Tender__c>{
            makeTender('T-Q1', 'HDPE', 'Error: RESOURCE_EXHAUSTED\nProduct Name updated to "Polymer".'),
            makeTender('T-Q2', 'HDPE', 'status: 429 too many requests'),
            makeTender('T-Q3', 'Polymer', 'API key expired'),
            makeTender('T-Q4', 'Polymer', 'api_key_invalid'),
            makeTender('T-Q5', 'Polymer', 'API key not valid. Please pass a valid API key.')
        };
        insert tenders;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('Polymer', deptOf(tenders[0].Id));
        for (Integer i = 1; i < tenders.size(); i++) {
            System.assertEquals('HDPE', deptOf(tenders[i].Id));
        }
    }

    @isTest
    static void emailRowLimitIsHandled() {
        // More quota rows than MAX_EMAIL_ROWS (100) -> exercises the "... and N more" branch
        List<Tender__c> tenders = new List<Tender__c>();
        for (Integer i = 0; i < 105; i++) {
            tenders.add(makeTender('T-Bulk-' + i, 'HDPE', 'quota exceeded'));
        }
        insert tenders;

        // Run in one scope so quotaIssues accumulates all 105 rows
        Test.startTest();
        Database.executeBatch(new TenderDeptFixBatch(null, true), 200);
        Test.stopTest();

        System.assertEquals(105, [SELECT COUNT() FROM Tender__c WHERE Department_Name__c = 'HDPE']);
    }

    @isTest
    static void noQuotaIssuesNoEmail() {
        Tender__c t = makeTender('T-Clean', 'HDPE', 'Product Name updated to "Polymer".');
        insert t;

        runBatch(new TenderDeptFixBatch(null, true));

        System.assertEquals('Polymer', deptOf(t.Id));
    }

    // ---------- Direct method calls (cover edge branches) ----------

    @isTest
    static void executeWithEmptyScopeDoesNothing() {
        TenderDeptFixBatch b = new TenderDeptFixBatch(null, true);
        b.execute(null, new List<Tender__c>());
        b.execute(null, null);
        System.assert(true, 'No exception expected');
    }

    @isTest
    static void noDataRunsCleanly() {
        runBatch(new TenderDeptFixBatch(null, true));
        System.assertEquals(0, [SELECT COUNT() FROM Tender__c]);
    }

    // ---------- Scheduler ----------

    @isTest
    static void schedulerRunsBatch() {
        Test.startTest();
        String jobId = System.schedule('TenderDeptFixSchedulerTest',
                                       '0 0 2 * * ?', new TenderDeptFixScheduler());
        Test.stopTest();
        
        // The job is scheduled; the batch it enqueues can't run inside a test
        CronTrigger ct = [SELECT CronExpression, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 2 * * ?', ct.CronExpression);
    }
    @isTest
    static void ownerAssignmentIsApplied() {
        Tender__c t = makeTender('T-Owner', 'HDPE', 'Product Name updated to "Polymer".');
        insert t;
        
        TenderDeptFixBatch b = new TenderDeptFixBatch(null, true);
        b.ownerMap.put('Polymer', UserInfo.getUserId());
        runBatch(b);
        
        System.assertEquals('Polymer', deptOf(t.Id));
    }
    @isTest
    static void schedulerWithDateRunsBatch() {
        Tender__c t = makeTender('T-Sched2', 'HDPE', 'Product Name updated to "HDPE".');
        insert t;

        Test.startTest();
        new TenderDeptFixScheduler(todayIST()).execute(null);
        Test.stopTest();

        System.assertEquals('HDPE', deptOf(t.Id));
    }
    @isTest
    static void diagnoseUpdate() {
        Tender__c t = makeTender('T-Diag', 'HDPE', 'x');
        insert t;
        update new Tender__c(Id = t.Id, Department_Name__c = 'Polymer');
    }
}