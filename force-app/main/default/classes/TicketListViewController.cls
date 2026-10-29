public with sharing class TicketListViewController {

    public static final String VIEW_ALL      = 'ALL_TICKETS';
    public static final String VIEW_OPEN     = 'OPEN_TICKETS';
    public static final String VIEW_RESOLVED = 'RESOLVED_TICKETS';
    public static final String VIEW_MY       = 'MY_TICKETS';

    @TestVisible private static final String TICKET_RT_NAME    = 'Internal Ticket';
    @TestVisible private static final String RESOLVED_STATUS   = 'Resolved';

    // If your ticket number is the standard CaseNumber, change this one line to 'CaseNumber'
    private static final String TICKET_NO_FIELD = 'Ticket_No__c';

    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE     = 200;

    private static final String SELECT_CLAUSE =
        'SELECT Id, ' + TICKET_NO_FIELD + ', Subject, Department__c, Module__c, Status, Priority, ' +
        'CreatedDate, OwnerId, Owner.Alias, Owner.Name FROM Case';

    public class QueryRequest {
        public String viewKey;
        public Integer pageSize;
        public String sortField;      // TicketNo | CreatedDate
        public String sortDirection;  // asc | desc
        public String cursorValue;
        public String cursorId;
        public String searchTerm;
    }

    public class TicketRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String ticketNo;
        @AuraEnabled public String subject;
        @AuraEnabled public String department;
        @AuraEnabled public String module;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String ownerAlias;
    }

    public class PageResult {
        @AuraEnabled public List<TicketRow> rows = new List<TicketRow>();
        @AuraEnabled public Boolean hasMore = false;
        @AuraEnabled public String nextCursorValue;
        @AuraEnabled public String nextCursorId;
    }

    public class StatusCount {
        @AuraEnabled public String status;
        @AuraEnabled public Integer total;
    }

    // ---------- Methods called from the LWC ----------

    @AuraEnabled
    public static PageResult getTickets(String requestJson) {
        return fetchTickets(parseRequest(requestJson));
    }

    @AuraEnabled
    public static List<StatusCount> getStatusSummary(String requestJson) {
        return fetchStatusSummary(parseRequest(requestJson));
    }

    // ---------- Logic ----------

    public static PageResult fetchTickets(QueryRequest request) {
        try {
            if (request == null) {
                throw new AuraHandledException('Missing request.');
            }
            Integer pageSize = request.pageSize == null ? DEFAULT_PAGE_SIZE
                             : Math.min(Math.max(request.pageSize, 1), MAX_PAGE_SIZE);

            Map<String, Object> binds = new Map<String, Object>();
            String whereClause = buildWhere(request, binds, true);

            String sortField = (request.sortField == 'CreatedDate') ? 'CreatedDate' : TICKET_NO_FIELD;
            String dir = (request.sortDirection == 'desc') ? 'DESC' : 'ASC';

            binds.put('lim', pageSize + 1);
            String soql = SELECT_CLAUSE + ' WHERE ' + whereClause +
                          ' ORDER BY ' + sortField + ' ' + dir + ', Id ' + dir + ' LIMIT :lim';

            List<Case> records = (List<Case>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

            PageResult result = new PageResult();
            if (records.size() > pageSize) {
                result.hasMore = true;
                while (records.size() > pageSize) {
                    records.remove(records.size() - 1);
                }
            }
            for (Case c : records) {
                result.rows.add(toRow(c));
            }
            if (result.hasMore && !records.isEmpty()) {
                Case last = records[records.size() - 1];
                result.nextCursorId = last.Id;
                result.nextCursorValue = (sortField == 'CreatedDate')
                    ? last.CreatedDate.formatGmt('yyyy-MM-dd HH:mm:ss')
                    : String.valueOf(last.get(TICKET_NO_FIELD));
            }
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    public static List<StatusCount> fetchStatusSummary(QueryRequest request) {
        try {
            Map<String, Object> binds = new Map<String, Object>();
            String whereClause = buildWhere(request, binds, false);
            String soql = 'SELECT Status s, COUNT(Id) c FROM Case WHERE ' + whereClause + ' GROUP BY Status';
            List<StatusCount> out = new List<StatusCount>();
            for (SObject so : Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)) {
                AggregateResult ar = (AggregateResult) so;
                StatusCount sc = new StatusCount();
                sc.status = (String) ar.get('s');
                sc.total  = (Integer) ar.get('c');
                out.add(sc);
            }
            return out;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    private static QueryRequest parseRequest(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Missing request.');
        }
        return (QueryRequest) JSON.deserialize(requestJson, QueryRequest.class);
    }

    private static String buildWhere(QueryRequest req, Map<String, Object> binds, Boolean includeCursor) {
        if (req == null) {
            throw new AuraHandledException('Missing request.');
        }
        List<String> c = new List<String>();

        binds.put('rtId', recordTypeId(TICKET_RT_NAME));
        c.add('RecordTypeId = :rtId');

        if (req.viewKey == VIEW_OPEN) {
            c.add('IsClosed = false');
        } else if (req.viewKey == VIEW_RESOLVED) {
            binds.put('resolvedStatus', RESOLVED_STATUS);
            c.add('Status = :resolvedStatus');
        } else if (req.viewKey == VIEW_MY) {
            binds.put('currentUserId', UserInfo.getUserId());
            c.add('OwnerId = :currentUserId');
        } else if (req.viewKey != VIEW_ALL) {
            throw new AuraHandledException('Unknown list view: ' + req.viewKey);
        }

        if (String.isNotBlank(req.searchTerm)) {
            binds.put('searchTerm', '%' + req.searchTerm.trim() + '%');
            c.add('(' + TICKET_NO_FIELD + ' LIKE :searchTerm OR Subject LIKE :searchTerm OR Module__c LIKE :searchTerm)');
        }

        if (includeCursor && String.isNotBlank(req.cursorId) && req.cursorValue != null) {
            String op = (req.sortDirection == 'desc') ? '<' : '>';
            binds.put('cursorId', (Id) req.cursorId);
            if (req.sortField == 'CreatedDate') {
                binds.put('cursorDt', Datetime.valueOfGmt(req.cursorValue));
                c.add('(CreatedDate ' + op + ' :cursorDt OR (CreatedDate = :cursorDt AND Id ' + op + ' :cursorId))');
            } else {
                binds.put('cursorStr', req.cursorValue);
                c.add('(' + TICKET_NO_FIELD + ' ' + op + ' :cursorStr OR (' + TICKET_NO_FIELD +
                      ' = :cursorStr AND Id ' + op + ' :cursorId))');
            }
        }
        return String.join(c, ' AND ');
    }

    private static TicketRow toRow(Case c) {
        TicketRow r = new TicketRow();
        r.id          = c.Id;
        r.ticketNo    = String.valueOf(c.get(TICKET_NO_FIELD));
        r.subject     = c.Subject;
        r.department  = c.Department__c;
        r.module      = c.Module__c;
        r.status      = c.Status;
        r.priority    = c.Priority;
        r.createdDate = c.CreatedDate;

        SObject owner = c.getSObject('Owner');
        if (owner != null) {
            if (owner instanceof User) {
                r.ownerAlias = ((User) owner).Alias;
            } else {
                r.ownerAlias = (String) owner.get('Name');
            }
        }
        return r;
    }

    private static Id recordTypeId(String rtLabel) {
        Schema.RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByName().get(rtLabel);
        if (info == null) {
            throw new AuraHandledException('Case record type "' + rtLabel + '" was not found.');
        }
        return info.getRecordTypeId();
    }

    private static AuraHandledException buildAuraException(Exception e) {
        AuraHandledException ae = new AuraHandledException(e.getMessage());
        ae.setMessage(e.getMessage());
        return ae;
    }
}