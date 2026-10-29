@IsTest
private class TicketListViewControllerTest {

    @TestSetup
    static void setup() {
        Id rtId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get(TicketListViewController.TICKET_RT_NAME).getRecordTypeId();
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            cases.add(new Case(RecordTypeId = rtId, Subject = 'TK Test ' + i, Status = 'Open', Priority = 'High'));
        }
        cases.add(new Case(RecordTypeId = rtId, Subject = 'TK Resolved',
            Status = TicketListViewController.RESOLVED_STATUS, Priority = 'High'));
        insert cases;
    }

    private static TicketListViewController.QueryRequest req(String viewKey) {
        TicketListViewController.QueryRequest r = new TicketListViewController.QueryRequest();
        r.viewKey = viewKey;
        r.pageSize = 50;
        r.sortField = 'TicketNo';
        r.sortDirection = 'asc';
        return r;
    }

    @IsTest
    static void allViewReturnsAllRows() {
        TicketListViewController.PageResult res = TicketListViewController.fetchTickets(req(TicketListViewController.VIEW_ALL));
        System.assertEquals(6, res.rows.size());
        System.assertEquals(false, res.hasMore);
    }

    @IsTest
    static void openAndResolvedViewsFilterCorrectly() {
        System.assertEquals(5, TicketListViewController.fetchTickets(req(TicketListViewController.VIEW_OPEN)).rows.size());
        System.assertEquals(1, TicketListViewController.fetchTickets(req(TicketListViewController.VIEW_RESOLVED)).rows.size());
    }

    @IsTest
    static void myViewReturnsOwnedTickets() {
        System.assertEquals(6, TicketListViewController.fetchTickets(req(TicketListViewController.VIEW_MY)).rows.size());
    }

    @IsTest
    static void keysetPaginationByTicketNo() {
        TicketListViewController.QueryRequest r = req(TicketListViewController.VIEW_ALL);
        r.pageSize = 4;
        TicketListViewController.PageResult p1 = TicketListViewController.fetchTickets(r);
        System.assertEquals(4, p1.rows.size());
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        TicketListViewController.PageResult p2 = TicketListViewController.fetchTickets(r);
        System.assertEquals(2, p2.rows.size());
        System.assertEquals(false, p2.hasMore);
    }

    @IsTest
    static void keysetPaginationByCreatedDateDescending() {
        TicketListViewController.QueryRequest r = req(TicketListViewController.VIEW_ALL);
        r.pageSize = 4;
        r.sortField = 'CreatedDate';
        r.sortDirection = 'desc';
        TicketListViewController.PageResult p1 = TicketListViewController.fetchTickets(r);
        System.assertEquals(true, p1.hasMore);

        r.cursorValue = p1.nextCursorValue;
        r.cursorId = p1.nextCursorId;
        System.assertEquals(2, TicketListViewController.fetchTickets(r).rows.size());
    }

    @IsTest
    static void searchApplies() {
        TicketListViewController.QueryRequest r = req(TicketListViewController.VIEW_ALL);
        r.searchTerm = 'TK Resolved';
        System.assertEquals(1, TicketListViewController.fetchTickets(r).rows.size());
    }

    @IsTest
    static void statusSummaryGroupsByStatus() {
        System.assertEquals(2, TicketListViewController.fetchStatusSummary(req(TicketListViewController.VIEW_ALL)).size());
    }

    @IsTest
    static void jsonEntryPointsWork() {
        String json = JSON.serialize(req(TicketListViewController.VIEW_ALL));
        System.assertEquals(6, TicketListViewController.getTickets(json).rows.size());
        System.assertEquals(2, TicketListViewController.getStatusSummary(json).size());
    }

    @IsTest
    static void unknownViewThrows() {
        try {
            TicketListViewController.fetchTickets(req('NOPE'));
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}