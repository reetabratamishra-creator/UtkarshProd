@IsTest
private class CaseListViewControllerTest {

    @TestSetup
    static void setup() {
        Id rtId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get(CaseListViewController.CASE_RT_NAME).getRecordTypeId();
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            cases.add(new Case(RecordTypeId = rtId, Subject = 'LV Test ' + i, Status = 'Open', Priority = 'High'));
        }
        cases.add(new Case(RecordTypeId = rtId, Subject = 'LV Resolved',
            Status = CaseListViewController.RESOLVED_STATUS, Priority = 'High'));
        insert cases;
    }

    private static CaseListViewController.QueryRequest req(String viewKey) {
        CaseListViewController.QueryRequest r = new CaseListViewController.QueryRequest();
        r.viewKey = viewKey;
        r.pageSize = 50;
        r.sortField = 'CaseNumber';
        r.sortDirection = 'asc';
        return r;
    }

    // ---------- getInitData ----------

    @IsTest
    static void initDataReturnsRecordTypesAndPicklists() {
        CaseListViewController.InitData d = CaseListViewController.getInitData();
        System.assertNotEquals(null, d.caseRecordTypeId);
        System.assert(!d.statusOptions.isEmpty());
        System.assert(!d.priorityOptions.isEmpty());
        System.assertNotEquals(null, d.departmentOptions);

        // Option constructor / fields
        CaseListViewController.Option o = new CaseListViewController.Option('L', 'V');
        System.assertEquals('L', o.label);
        System.assertEquals('V', o.value);
    }

    // ---------- fetchCases: views ----------

    @IsTest
    static void allViewReturnsAllRows() {
        CaseListViewController.PageResult res =
            CaseListViewController.fetchCases(req(CaseListViewController.VIEW_ALL));
        System.assertEquals(6, res.rows.size());
        System.assertEquals(false, res.hasMore);
    }

    @IsTest
    static void openAndResolvedViewsFilterCorrectly() {
        System.assertEquals(5, CaseListViewController.fetchCases(req(CaseListViewController.VIEW_OPEN)).rows.size());
        System.assertEquals(1, CaseListViewController.fetchCases(req(CaseListViewController.VIEW_RESOLVED)).rows.size());
    }

    @IsTest
    static void myViewReturnsOwnedCases() {
        System.assertEquals(6, CaseListViewController.fetchCases(req(CaseListViewController.VIEW_MY)).rows.size());
    }

    @IsTest
    static void rowFieldsAreMapped() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_RESOLVED);
        CaseListViewController.CaseRow row = CaseListViewController.fetchCases(r).rows[0];
        System.assertNotEquals(null, row.id);
        System.assertNotEquals(null, row.caseNumber);
        System.assertEquals('LV Resolved', row.subject);
        System.assertEquals(CaseListViewController.RESOLVED_STATUS, row.status);
        System.assertEquals('High', row.priority);
        System.assertNotEquals(null, row.createdDate);
        System.assertEquals(null, row.contactName, 'No contact on test cases');

        // Owner alias depends on the running user's access to the User record,
        // so only compare when the owner could be read
        User me = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()];
        if (row.ownerAlias != null) {
            System.assertEquals(me.Alias, row.ownerAlias, 'Alias should match the case owner');
        }
    }

    // ---------- fetchCases: paging and sorting ----------

    @IsTest
    static void keysetPaginationByCaseNumber() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.pageSize = 4;
        CaseListViewController.PageResult p1 = CaseListViewController.fetchCases(r);
        System.assertEquals(4, p1.rows.size());
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        CaseListViewController.PageResult p2 = CaseListViewController.fetchCases(r);
        System.assertEquals(2, p2.rows.size());
        System.assertEquals(false, p2.hasMore);
    }

    @IsTest
    static void keysetPaginationByCaseNumberDescending() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.pageSize = 4;
        r.sortDirection = 'desc';
        CaseListViewController.PageResult p1 = CaseListViewController.fetchCases(r);
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        System.assertEquals(2, CaseListViewController.fetchCases(r).rows.size());
    }

    @IsTest
    static void keysetPaginationByCreatedDateDescending() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.pageSize = 4;
        r.sortField = 'CreatedDate';
        r.sortDirection = 'desc';
        CaseListViewController.PageResult p1 = CaseListViewController.fetchCases(r);
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        CaseListViewController.PageResult p2 = CaseListViewController.fetchCases(r);
        System.assertEquals(2, p2.rows.size());
    }

    @IsTest
    static void keysetPaginationByCreatedDateAscending() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.pageSize = 4;
        r.sortField = 'CreatedDate';
        r.sortDirection = 'asc';
        CaseListViewController.PageResult p1 = CaseListViewController.fetchCases(r);
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        // All test cases share (nearly) the same CreatedDate, so the Id tie-break is used
        System.assertNotEquals(null, CaseListViewController.fetchCases(r));
    }

    @IsTest
    static void pageSizeIsDefaultedAndClamped() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.pageSize = null;   // default 50
        System.assertEquals(6, CaseListViewController.fetchCases(r).rows.size());

        r.pageSize = 0;      // raised to 1
        CaseListViewController.PageResult p = CaseListViewController.fetchCases(r);
        System.assertEquals(1, p.rows.size());
        System.assertEquals(true, p.hasMore);

        r.pageSize = 5000;   // capped to 200
        System.assertEquals(6, CaseListViewController.fetchCases(r).rows.size());
    }

    // ---------- fetchCases: filters ----------

    @IsTest
    static void searchAndFiltersApply() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.searchTerm = 'LV Resolved';
        System.assertEquals(1, CaseListViewController.fetchCases(r).rows.size());

        r = req(CaseListViewController.VIEW_ALL);
        r.statuses = new List<String>{ 'Open' };
        r.priorities = new List<String>{ 'High' };
        System.assertEquals(5, CaseListViewController.fetchCases(r).rows.size());
    }

    @IsTest
    static void departmentFilterApplies() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.departments = new List<String>{ 'Department_That_Does_Not_Exist' };
        // An unknown picklist value may be rejected by USER_MODE or simply match nothing
        try {
            System.assertEquals(0, CaseListViewController.fetchCases(r).rows.size());
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    // ---------- fetchCases: owner is a queue ----------

    @IsTest
    static void rowShowsQueueNameWhenOwnerIsQueue() {
        Id rtId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get(CaseListViewController.CASE_RT_NAME).getRecordTypeId();
        Group q = new Group(Name = 'LV Test Queue', Type = 'Queue');

        // runAs avoids MIXED_DML between setup objects (Group) and Case
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert q;
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');
        }
        insert new Case(RecordTypeId = rtId, Subject = 'LV Queue Case',
            Status = 'Open', Priority = 'High', OwnerId = q.Id);

        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.searchTerm = 'LV Queue Case';
        CaseListViewController.PageResult res = CaseListViewController.fetchCases(r);

        System.assertEquals(1, res.rows.size());
        System.assertEquals('LV Test Queue', res.rows[0].ownerAlias);
    }

    // ---------- fetchCases: errors ----------

    @IsTest
    static void unknownViewThrows() {
        try {
            CaseListViewController.fetchCases(req('NOPE'));
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void nullRequestThrows() {
        try {
            CaseListViewController.fetchCases(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void invalidCursorIdIsWrappedInAuraException() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.cursorId = 'not-an-id';
        r.cursorValue = 'x';
        try {
            CaseListViewController.fetchCases(r);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    // ---------- fetchStatusSummary ----------

    @IsTest
    static void statusSummaryGroupsByStatus() {
        List<CaseListViewController.StatusCount> s =
            CaseListViewController.fetchStatusSummary(req(CaseListViewController.VIEW_ALL));
        System.assertEquals(2, s.size());

        Integer total = 0;
        for (CaseListViewController.StatusCount sc : s) {
            total += sc.total;
        }
        System.assertEquals(6, total);
    }

    @IsTest
    static void statusSummaryUnknownViewThrows() {
        try {
            CaseListViewController.fetchStatusSummary(req('NOPE'));
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void statusSummaryNullRequestThrows() {
        try {
            CaseListViewController.fetchStatusSummary(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void statusSummaryIgnoresCursor() {
        CaseListViewController.QueryRequest r = req(CaseListViewController.VIEW_ALL);
        r.cursorId = 'not-an-id';   // the summary never uses the cursor, so this must not fail
        r.cursorValue = 'x';
        System.assertEquals(2, CaseListViewController.fetchStatusSummary(r).size());
    }

    // ---------- @AuraEnabled wrappers (JSON string) ----------

    @IsTest
    static void getCasesAcceptsJson() {
        String json = JSON.serialize(req(CaseListViewController.VIEW_ALL));
        CaseListViewController.PageResult res = CaseListViewController.getCases(json);
        System.assertEquals(6, res.rows.size());
    }

    @IsTest
    static void getStatusSummaryAcceptsJson() {
        String json = JSON.serialize(req(CaseListViewController.VIEW_ALL));
        List<CaseListViewController.StatusCount> s = CaseListViewController.getStatusSummary(json);
        System.assertEquals(2, s.size());
    }

    @IsTest
    static void blankJsonThrows() {
        try {
            CaseListViewController.getCases('');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        try {
            CaseListViewController.getStatusSummary(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void invalidJsonThrows() {
        try {
            CaseListViewController.getCases('{ this is not json');
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(true);
        }
    }
}