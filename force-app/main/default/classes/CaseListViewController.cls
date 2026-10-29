public with sharing class CaseListViewController {

    public static final String VIEW_ALL      = 'ALL_CASES';
    public static final String VIEW_OPEN     = 'OPEN_CASES';
    public static final String VIEW_RESOLVED = 'RESOLVED_CASES';
    public static final String VIEW_MY       = 'MY_CASES';

    @TestVisible private static final String CASE_RT_NAME     = 'Case';
    @TestVisible private static final String INTERNAL_RT_NAME = 'Internal Ticket';
    @TestVisible private static final String RESOLVED_STATUS  = 'Resolved';
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE     = 200;

    private static final String SELECT_CLAUSE =
        'SELECT Id, CaseNumber, ContactId, Contact.Name, Subject, Status, Priority, ' +
        'Department__c, CreatedDate, OwnerId, Owner.Alias, Owner.Name FROM Case';

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) { this.label = label; this.value = value; }
    }

    public class InitData {
        @AuraEnabled public Id caseRecordTypeId;
        @AuraEnabled public Id internalTicketRecordTypeId;
        @AuraEnabled public List<Option> statusOptions;
        @AuraEnabled public List<Option> priorityOptions;
        @AuraEnabled public List<Option> departmentOptions;
    }

    public class QueryRequest {
        @AuraEnabled public String viewKey;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public String sortField;
        @AuraEnabled public String sortDirection;
        @AuraEnabled public String cursorValue;
        @AuraEnabled public String cursorId;
        @AuraEnabled public String searchTerm;
        @AuraEnabled public List<String> statuses;
        @AuraEnabled public List<String> priorities;
        @AuraEnabled public List<String> departments;
    }

    public class CaseRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String contactName;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String department;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String ownerAlias;
    }

    public class PageResult {
        @AuraEnabled public List<CaseRow> rows = new List<CaseRow>();
        @AuraEnabled public Boolean hasMore = false;
        @AuraEnabled public String nextCursorValue;
        @AuraEnabled public String nextCursorId;
    }

    public class StatusCount {
        @AuraEnabled public String status;
        @AuraEnabled public Integer total;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        InitData d = new InitData();
        d.caseRecordTypeId           = recordTypeId(CASE_RT_NAME, true);
        d.internalTicketRecordTypeId = recordTypeId(INTERNAL_RT_NAME, false);
        d.statusOptions     = picklist(Case.Status);
        d.priorityOptions   = picklist(Case.Priority);
        d.departmentOptions = picklist(Case.Department__c);
        return d;
    }

    public static PageResult fetchCases(QueryRequest request) {
        try {
            if (request == null) {
                throw new AuraHandledException('Missing request.');
            }
            Integer pageSize = request.pageSize == null ? DEFAULT_PAGE_SIZE
                             : Math.min(Math.max(request.pageSize, 1), MAX_PAGE_SIZE);

            Map<String, Object> binds = new Map<String, Object>();
            String whereClause = buildWhere(request, binds, true);

            String sortField = (request.sortField == 'CreatedDate') ? 'CreatedDate' : 'CaseNumber';
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
                    : last.CaseNumber;
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

    private static String buildWhere(QueryRequest req, Map<String, Object> binds, Boolean includeCursor) {
        if (req == null) {
            throw new AuraHandledException('Missing request.');
        }
        List<String> c = new List<String>();

        binds.put('rtId', recordTypeId(CASE_RT_NAME, true));
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
            c.add('(CaseNumber LIKE :searchTerm OR Subject LIKE :searchTerm OR Contact.Name LIKE :searchTerm)');
        }

        if (req.statuses != null && !req.statuses.isEmpty()) {
            binds.put('fStatuses', req.statuses);
            c.add('Status IN :fStatuses');
        }
        if (req.priorities != null && !req.priorities.isEmpty()) {
            binds.put('fPriorities', req.priorities);
            c.add('Priority IN :fPriorities');
        }
        if (req.departments != null && !req.departments.isEmpty()) {
            binds.put('fDepartments', req.departments);
            c.add('Department__c IN :fDepartments');
        }

        if (includeCursor && String.isNotBlank(req.cursorId) && req.cursorValue != null) {
            String op = (req.sortDirection == 'desc') ? '<' : '>';
            binds.put('cursorId', (Id) req.cursorId);
            if (req.sortField == 'CreatedDate') {
                binds.put('cursorDt', Datetime.valueOfGmt(req.cursorValue));
                c.add('(CreatedDate ' + op + ' :cursorDt OR (CreatedDate = :cursorDt AND Id ' + op + ' :cursorId))');
            } else {
                binds.put('cursorStr', req.cursorValue);
                c.add('(CaseNumber ' + op + ' :cursorStr OR (CaseNumber = :cursorStr AND Id ' + op + ' :cursorId))');
            }
        }
        return String.join(c, ' AND ');
    }

    private static CaseRow toRow(Case c) {
        CaseRow r = new CaseRow();
        r.id          = c.Id;
        r.caseNumber  = c.CaseNumber;
        r.contactName = c.Contact != null ? c.Contact.Name : null;
        r.subject     = c.Subject;
        r.status      = c.Status;
        r.priority    = c.Priority;
        r.department  = c.Department__c;
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

    private static Id recordTypeId(String rtLabel, Boolean required) {
        Schema.RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByName().get(rtLabel);
        if (info == null) {
            if (required) {
                throw new AuraHandledException('Case record type "' + rtLabel + '" was not found.');
            }
            return null;
        }
        return info.getRecordTypeId();
    }
    
    
    
    @AuraEnabled
    public static PageResult getCases(String requestJson) {
        return fetchCases(parseRequest(requestJson));
    }
    
    @AuraEnabled
    public static List<StatusCount> getStatusSummary(String requestJson) {
        return fetchStatusSummary(parseRequest(requestJson));
    }
    
    private static QueryRequest parseRequest(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Missing request.');
        }
        return (QueryRequest) JSON.deserialize(requestJson, QueryRequest.class);
    }

    private static List<Option> picklist(Schema.SObjectField field) {
        List<Option> options = new List<Option>();
        for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                options.add(new Option(pe.getLabel(), pe.getValue()));
            }
        }
        return options;
    }

    private static AuraHandledException buildAuraException(Exception e) {
        AuraHandledException ae = new AuraHandledException(e.getMessage());
        ae.setMessage(e.getMessage());
        return ae;
    }
}