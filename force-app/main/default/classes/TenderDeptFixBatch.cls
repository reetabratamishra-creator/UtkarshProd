public without sharing class TenderDeptFixBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String LOG = '[TenderDeptFixBatch] ';
    private static final String TZ_NAME = 'Asia/Kolkata';

    // ---- Settings (change here) ----
    private static final List<String> ALERT_EMAILS = new List<String>{
        'Ayantika.Chakraborty@halsaglobal.io',
            'deepanjan.dey@halsaglobal.io'
    };
    private static final String NAMED_CREDENTIAL_NAME = 'Gemini External Credential';
    private static final Integer MAX_EMAIL_ROWS = 100;

    private static final List<String> PRODUCT_VALUES = new List<String>{
        'HDPE', 'Polymer', 'Polymer,HDPE', 'Polymer, HDPE'
    };

    // ---- Filter ----
    private Date runDate;        // day to process (IST)
    private Boolean allData;     // true = ignore date

    // ---- Counters kept across batches ----
    private Integer totalScanned = 0;
    private Integer skippedNoSummary = 0;
    private Integer updatedPolymer = 0;
    private Integer updatedHdpe = 0;
    private Integer updateFailed = 0;
    private Integer scopeCount = 0;
    private List<String> quotaIssues = new List<String>();
    //private Map<String, Id> ownerMap = new Map<String, Id>();
    @TestVisible private Map<String, Id> ownerMap = new Map<String, Id>();
        
        
    // No date given -> TODAY (IST)
    public TenderDeptFixBatch() {
        this(null, false);
    }

    // Date given -> that day (IST). null -> TODAY (IST)
    public TenderDeptFixBatch(Date runDate) {
        this(runDate, false);
    }

    // allData = true -> all tenders, no date filter
    /*public TenderDeptFixBatch(Date runDate, Boolean allData) {
        this.allData = (allData == true);
        this.runDate = (runDate == null) ? todayIST() : runDate;
    }*/
    /*public TenderDeptFixBatch(Date runDate, Boolean allData) {
        if (!Test.isRunningTest()) {
            for (Tender_Polymer_HDPE_Owner_Assignment__mdt m : [
                SELECT DeveloperName, Owner__c
                FROM Tender_Polymer_HDPE_Owner_Assignment__mdt
            ]) {
                if (String.isNotBlank(m.Owner__c)) {
                    try {
                        ownerMap.put(m.DeveloperName, (Id) m.Owner__c.trim());
                    } catch (Exception e) {
                        System.debug(LOG + 'Invalid Owner Id for ' + m.DeveloperName + ': ' + m.Owner__c);
                    }
                }
            }
        }
        this.allData = (allData == true);
        this.runDate = (runDate == null) ? todayIST() : runDate;
        
        for (Tender_Polymer_HDPE_Owner_Assignment__mdt m : [
            SELECT DeveloperName, Owner__c
            FROM Tender_Polymer_HDPE_Owner_Assignment__mdt
        ]) {
            if (String.isNotBlank(m.Owner__c)) {
                try {
                    ownerMap.put(m.DeveloperName, (Id) m.Owner__c.trim());
                } catch (Exception e) {
                    System.debug(LOG + 'Invalid Owner Id for ' + m.DeveloperName + ': ' + m.Owner__c);
                }
            }
        }
    }*/
        public TenderDeptFixBatch(Date runDate, Boolean allData) {
            this.allData = (allData == true);
            this.runDate = (runDate == null) ? todayIST() : runDate;
            loadOwnerMap();
        }
        
        private void loadOwnerMap() {
            // Tests control ownerMap themselves (it is @TestVisible),
            // so they don't depend on real org metadata.
            if (Test.isRunningTest()) {
                // Tests don't read org metadata; use a valid owner so
                // owner-dependent rules/triggers on Tender__c are satisfied
                ownerMap.put('Polymer', UserInfo.getUserId());
                ownerMap.put('HDPE', UserInfo.getUserId());
                return;
            }
            for (Tender_Polymer_HDPE_Owner_Assignment__mdt m : [
                SELECT DeveloperName, Owner__c
                FROM Tender_Polymer_HDPE_Owner_Assignment__mdt
            ]) {
                if (String.isNotBlank(m.Owner__c)) {
                    try {
                        ownerMap.put(m.DeveloperName, (Id) m.Owner__c.trim());
                    } catch (Exception e) {
                        System.debug(LOG + 'Invalid Owner Id for ' + m.DeveloperName + ': ' + m.Owner__c);
                    }
                }
            }
        }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> products = PRODUCT_VALUES;

        System.debug(LOG + 'START | Job Id: ' + bc.getJobId()
            + ' | Mode: ' + (allData ? 'ALL DATA' : 'DATE ' + runDate + ' (IST)')
            + ' | Products: ' + products);

        if (allData) {
            return Database.getQueryLocator([
                SELECT Id, Name, Product_Name__c, Department_Name__c,
                       Reading_Polymer_HDPE_Summary__c
                FROM Tender__c
                WHERE Department_Name__c = NULL
                AND Product_Name__c IN :products
                WITH SYSTEM_MODE
            ]);
        }

        // IST day: 00:00 IST to next 00:00 IST, converted to real points in time
        TimeZone tz = TimeZone.getTimeZone(TZ_NAME);
        Datetime gmtMidnight = Datetime.newInstanceGmt(runDate.year(), runDate.month(), runDate.day());
        Integer offsetSeconds = tz.getOffset(gmtMidnight) / 1000;
        Datetime dayStart = gmtMidnight.addSeconds(-offsetSeconds);
        Datetime dayEnd = dayStart.addDays(1);

        System.debug(LOG + 'START | IST range: '
            + dayStart.format('yyyy-MM-dd HH:mm:ss', TZ_NAME) + ' to '
            + dayEnd.format('yyyy-MM-dd HH:mm:ss', TZ_NAME) + ' IST'
            + ' | (GMT: ' + dayStart.formatGmt('yyyy-MM-dd HH:mm:ss') + ' to '
            + dayEnd.formatGmt('yyyy-MM-dd HH:mm:ss') + ')');

        return Database.getQueryLocator([
            SELECT Id, Name, Product_Name__c, Department_Name__c,
                   Reading_Polymer_HDPE_Summary__c
            FROM Tender__c
            WHERE Department_Name__c = NULL
            AND Product_Name__c IN :products
            AND CreatedDate >= :dayStart
            AND CreatedDate < :dayEnd
            WITH SYSTEM_MODE
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Tender__c> scope) {
        scopeCount++;

        if (scope == null || scope.isEmpty()) {
            System.debug(LOG + 'EXECUTE #' + scopeCount + ' | Scope is empty, nothing to do');
            return;
        }

        totalScanned += scope.size();
        System.debug(LOG + 'EXECUTE #' + scopeCount + ' | Scope size: ' + scope.size());

        List<Tender__c> toUpdate = new List<Tender__c>();
        Map<Id, String> newDeptById = new Map<Id, String>();

        try {
            for (Tender__c t : scope) {
                String summary = t.Reading_Polymer_HDPE_Summary__c;

                if (String.isBlank(summary)) {
                    skippedNoSummary++;
                    System.debug(LOG + 'SKIPPED (summary blank) | ' + t.Name + ' | ' + t.Id);
                    continue;
                }

                String quotaLine = findQuotaLine(summary);
                if (quotaLine != null) {
                    quotaIssues.add(t.Name + ' | ' + t.Id + ' | ' + quotaLine);
                    System.debug(LoggingLevel.WARN, LOG + 'QUOTA ERROR FOUND | '
                        + t.Name + ' | ' + t.Id + ' | ' + quotaLine);
                }

                String dept = resolveDepartment(summary);
                System.debug(LOG + 'RESOLVED | ' + t.Name + ' | ' + t.Id
                    + ' | Product: ' + t.Product_Name__c + ' -> Department: ' + dept);

                //toUpdate.add(new Tender__c(Id = t.Id, Department_Name__c = dept));
                Tender__c upd = new Tender__c(Id = t.Id, Department_Name__c = dept);
                Id ownerId = ownerMap.get(dept);
                if (ownerId != null) {
                    upd.OwnerId = ownerId;
                }
                toUpdate.add(upd);
                newDeptById.put(t.Id, dept);
            }

            if (toUpdate.isEmpty()) {
                System.debug(LOG + 'EXECUTE #' + scopeCount + ' | No records to update');
                return;
            }

            Database.SaveResult[] results =
                Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);

            Integer okCount = 0;
            Integer failCount = 0;

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    okCount++;
                    if (newDeptById.get(toUpdate[i].Id) == 'Polymer') updatedPolymer++;
                    else updatedHdpe++;
                } else {
                    failCount++;
                    updateFailed++;
                    for (Database.Error err : results[i].getErrors()) {
                        System.debug(LoggingLevel.ERROR, LOG + 'UPDATE FAILED | '
                            + toUpdate[i].Id + ' | ' + err.getStatusCode()
                            + ' | ' + err.getMessage() + ' | Fields: ' + err.getFields());
                    }
                }
            }

            System.debug(LOG + 'EXECUTE #' + scopeCount + ' | Updated OK: ' + okCount
                + ' | Failed: ' + failCount);

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, LOG + 'EXECUTE #' + scopeCount
                + ' FAILED | ' + ex.getTypeName() + ': ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LOG + 'FINISH | Job Id: ' + bc.getJobId()
            + ' | Mode: ' + (allData ? 'ALL DATA' : 'DATE ' + runDate + ' (IST)')
            + ' | Scopes run: ' + scopeCount
            + ' | Scanned: ' + totalScanned
            + ' | Skipped (no summary): ' + skippedNoSummary
            + ' | Polymer: ' + updatedPolymer
            + ' | HDPE: ' + updatedHdpe
            + ' | Update failed: ' + updateFailed
            + ' | Quota issues: ' + quotaIssues.size());

        if (quotaIssues.isEmpty()) {
            System.debug(LOG + 'FINISH | No quota issues, email not sent');
            return;
        }

        try {
            sendQuotaEmail();
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, LOG + 'EMAIL FAILED | '
                + ex.getTypeName() + ': ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }

    // ---------- Helpers ----------

    // Today's date in IST (not GMT)
    private static Date todayIST() {
        return Date.valueOf(Datetime.now().format('yyyy-MM-dd', TZ_NAME));
    }

    private static String resolveDepartment(String summary) {
        Pattern p = Pattern.compile('(?i)Product Name updated to\\s*"?([^"\\r\\n]+?)"?\\s*(?:\\.|\\r|\\n|$)');
        Matcher m = p.matcher(summary);

        if (m.find()) {
            String value = m.group(1).trim();
            System.debug(LOG + 'resolveDepartment | Text found: "' + value + '"');

            if (value.equalsIgnoreCase('Polymer')) return 'Polymer';
            if (value.equalsIgnoreCase('HDPE')) return 'HDPE';

            System.debug(LOG + 'resolveDepartment | Unknown value, defaulting to HDPE');
            return 'HDPE';
        }

        System.debug(LOG + 'resolveDepartment | "Product Name updated to" not found, defaulting to HDPE');
        return 'HDPE';
    }

    private static String findQuotaLine(String summary) {
        for (String line : summary.split('\n')) {
            if (isQuotaLine(line)) {
                String clean = line.trim();
                return clean.length() > 200 ? clean.substring(0, 200) : clean;
            }
        }
        return null;
    }

    /*
    private static Boolean isQuotaLine(String line) {
        String l = line.toLowerCase();
        return l.contains('resource_exhausted')
            || l.contains('quota')
            || l.contains('api key expired')
            || l.contains('api_key_invalid')
            || l.contains('api key not valid')
            || Pattern.compile('status:\\s*429').matcher(l).find();
    }
    */
    private static Boolean isQuotaLine(String line) {
        String l = line.toLowerCase();
        return l.contains('resource_exhausted')
            || l.contains('exceeded your current quota')
            || l.contains('quota exceeded')
            || l.contains('check your plan and billing')
            || l.contains('api key expired')
            || l.contains('api_key_invalid')
            || l.contains('api key not valid')
            || l.contains('rate-limits')
            || Pattern.compile('status:\\s*429').matcher(l).find()
            || Pattern.compile('"code"\\s*:\\s*429').matcher(l).find();
    }

    private void sendQuotaEmail() {
    if (ALERT_EMAILS.isEmpty()) {
        System.debug(LoggingLevel.WARN, LOG + 'EMAIL | No recipient configured');
        return;
    }

    // ---- Affected tenders (HTML + plain) ----
    String rowsHtml = '';
    String rowsText = '';
    Integer shown = 0;
    for (String row : quotaIssues) {
        if (shown >= MAX_EMAIL_ROWS) {
            Integer more = quotaIssues.size() - MAX_EMAIL_ROWS;
            rowsHtml += '<li>... and ' + more + ' more.</li>';
            rowsText += '... and ' + more + ' more.\n';
            break;
        }
        rowsHtml += '<li>' + row.escapeHtml4() + '</li>';
        rowsText += '- ' + row + '\n';
        shown++;
    }

    String runFilter = allData ? 'All data' : String.valueOf(runDate) + ' (IST)';

    // ---- HTML body ----
    String html = '<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.6;color:#222;">'
        + '<p>Hello,</p>'
        + '<p>Your Gemini free API key has expired or its free credits are exhausted. '
        + '<b>Please change the key.</b></p>'

        + '<p><b>Affected tenders (' + quotaIssues.size() + ') | Run filter: ' + runFilter + '</b></p>'

        + '<h3 style="margin-bottom:4px;">Part 1: How to get a new API key</h3>'
        + '<ol>'
        + '<li>Open <a href="https://aistudio.google.com/app/apikey">https://aistudio.google.com/app/apikey</a> '
        + 'and sign in with your Google account.</li>'
        + '<li>Click <b>Create API key</b>.</li>'
        + '<li>Select a Google Cloud project (or create a new one) and confirm.</li>'
        + '<li><b>Copy</b> the new key and keep it safe. Do not share it over chat or email.</li>'
        + '</ol>'

        + '<h3 style="margin-bottom:4px;">Part 2: Where and how to add the key in Salesforce</h3>'
        + '<ol>'
        + '<li>Go to <b>Setup</b> &gt; <b>Quick Find</b> &gt; search <b>Named Credentials</b>.</li>'
        + '<li>Click the <b>External Credentials</b> tab and open <b>' + NAMED_CREDENTIAL_NAME + '</b>.</li>'
        + '<li>Scroll to the <b>Principals</b> section, click the dropdown arrow next to the principal and choose <b>Edit</b>.</li>'
        + '<li>Delete the old key, paste the new key into the <b>Authentication Parameter</b> value (API key field) and click <b>Save</b>.</li>'
        + '</ol>'
        + '<p>If you face any issue while updating the key, please contact the Salesforce admin team.</p>'
        + '<p>Thanks,<br/>Salesforce Automation</p>'
        + '</div>';

    // ---- Plain text fallback ----
    String text = 'Hello,\n\n'
        + 'Your Gemini free API key has expired or its free credits are exhausted. Please change the key.\n\n'
        + 'Affected tenders (' + quotaIssues.size() + ') | Run filter: ' + runFilter + '\n'
        + 'PART 1: HOW TO GET A NEW API KEY\n'
        + '1. Open https://aistudio.google.com/app/apikey and sign in with your Google account.\n'
        + '2. Click "Create API key".\n'
        + '3. Select a Google Cloud project (or create a new one) and confirm.\n'
        + '4. Copy the new key and keep it safe.\n\n'
        + 'PART 2: WHERE AND HOW TO ADD THE KEY IN SALESFORCE\n'
        + '1. Setup > Quick Find > Named Credentials.\n'
        + '2. Click the External Credentials tab and open "' + NAMED_CREDENTIAL_NAME + '".\n'
        + '3. In the Principals section, click the dropdown arrow next to the principal and choose Edit.\n'
        + '4. Delete the old key, paste the new key into the Authentication Parameter value and click Save.\n';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(ALERT_EMAILS);
    mail.setSubject('Action needed: Gemini free API key expired');
    mail.setHtmlBody(html);
    mail.setPlainTextBody(text);
    mail.setSaveAsActivity(false);

    Messaging.SendEmailResult[] results =
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);

    for (Messaging.SendEmailResult r : results) {
        if (r.isSuccess()) {
            System.debug(LOG + 'EMAIL SENT to ' + ALERT_EMAILS + ' | Tenders listed: ' + quotaIssues.size());
        } else {
            for (Messaging.SendEmailError e : r.getErrors()) {
                System.debug(LoggingLevel.ERROR, LOG + 'EMAIL ERROR | '
                    + e.getStatusCode() + ' | ' + e.getMessage());
            }
        }
    }
}
}