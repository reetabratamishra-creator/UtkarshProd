/**
 * LeadCsvImportController
 * Backing Apex for the leadCsvImport LWC.
 * Responsibilities: expose LeadSource picklist values, validate + bulk insert
 * Leads from CSV data, and (optionally) attach a single supporting file to
 * every inserted Lead via ContentDocumentLink.
 */
public with sharing class LeadCsvImportController {

    // ---- Configurable constants -------------------------------------------------
    // Keep in sync with MAX_CSV_ROWS in leadCsvImportConstants.js (client-side check
    // is the first line of defense; this is the server-side guardrail).
    public static final Integer MAX_CSV_ROWS = 50;

    private static final Pattern PHONE_PATTERN = Pattern.compile('^\\d{10}$');
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');

    // ---- Wrappers -----------------------------------------------------------------
    public class LeadRowWrapper {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String phone;
        @AuraEnabled public String departmentName;
        @AuraEnabled public String email;
    }

    public class RowError {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String message;
        public RowError(String rowKey, String message) {
            this.rowKey = rowKey;
            this.message = message;
        }
    }

    public class ImportResult {
        @AuraEnabled public Integer totalProcessed;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failCount;
        @AuraEnabled public List<RowError> errors;
        public ImportResult() {
            this.errors = new List<RowError>();
        }
    }

    // ---- Public API -----------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadSourceOptions() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Lead.LeadSource.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(entry.getValue());
            }
        }
        return options;
    }

    @AuraEnabled
    public static ImportResult processLeadImport(String leadsJson, String leadSourceValue, String fileName, String fileBase64) {
        List<LeadRowWrapper> rows;
        try {
            rows = (List<LeadRowWrapper>) JSON.deserialize(leadsJson, List<LeadRowWrapper>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to read lead data: ' + e.getMessage());
        }

        if (rows == null || rows.isEmpty()) {
            throw new AuraHandledException('No lead rows were provided.');
        }
        if (rows.size() > MAX_CSV_ROWS) {
            throw new AuraHandledException('Row count (' + rows.size() + ') exceeds the maximum allowed (' + MAX_CSV_ROWS + ').');
        }
        if (String.isBlank(leadSourceValue)) {
            throw new AuraHandledException('Lead Source is required.');
        }

        ImportResult result = new ImportResult();
        result.totalProcessed = rows.size();
        result.successCount = 0;
        result.failCount = 0;

        List<Lead> leadsToInsert = new List<Lead>();
        List<String> orderedRowKeys = new List<String>();

        for (LeadRowWrapper row : rows) {

            // Phone validation
            if (String.isBlank(row.phone) ||
                !PHONE_PATTERN.matcher(row.phone.trim()).matches()) {

                result.failCount++;
                result.errors.add(
                    new RowError(
                        row.rowKey,
                        'CSV Row ' + (Integer.valueOf(row.rowKey.split('-')[1]) + 2) +
                        ': Phone number must contain exactly 10 digits.'
                    )
                );
                continue;
            }

            // Email validation (only if provided)
            if (String.isNotBlank(row.email) &&
                !EMAIL_PATTERN.matcher(row.email.trim()).matches()) {

                result.failCount++;
                result.errors.add(
                    new RowError(
                        row.rowKey,
                        'CSV Row ' + (Integer.valueOf(row.rowKey.split('-')[1]) + 2) +
                        ': Email address is invalid.'
                    )
                );
                continue;
            }


            Lead ld = new Lead();
            ld.FirstName = row.firstName;
            ld.LastName = row.lastName;
            ld.Phone = row.phone;
            ld.Department_Name__c = row.departmentName;
            // Lead.Company is a required standard field regardless of page layout;
            // default it from Department Name so inserts don't fail on that constraint.
            ld.Company = String.isNotBlank(row.departmentName) ? row.departmentName : 'Unknown';
            if (String.isNotBlank(row.email)) {
                ld.Email = row.email;
            }
            ld.LeadSource = leadSourceValue;
            leadsToInsert.add(ld);
            orderedRowKeys.add(row.rowKey);
        }

        List<Database.SaveResult> saveResults = Database.insert(leadsToInsert, false);

        List<Id> insertedLeadIds = new List<Id>();
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult sr = saveResults[i];
            if (sr.isSuccess()) {
                result.successCount++;
                insertedLeadIds.add(sr.getId());
            } else {
                result.failCount++;
                String errMsg = sr.getErrors().isEmpty()
                    ? 'Unknown error'
                    : sr.getErrors()[0].getMessage();

                Integer rowNumber =
                    Integer.valueOf(orderedRowKeys[i].split('-')[1]) + 2;

                result.errors.add(
                    new RowError(
                        orderedRowKeys[i],
                        'CSV Row ' + rowNumber + ': ' + errMsg
                    )
                );
            }
        }

        if (!insertedLeadIds.isEmpty() && String.isNotBlank(fileBase64) && String.isNotBlank(fileName)) {
            attachFileToLeads(fileName, fileBase64, insertedLeadIds);
        }

        return result;
    }

    public static void attachFileToLeads(String fileName, String fileBase64, List<Id> leadIds) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(fileBase64);
        insert cv;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id leadId : leadIds) {
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = contentDocumentId;
            link.LinkedEntityId = leadId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            links.add(link);
        }
        if (!links.isEmpty()) {
            insert links;
        }
    }
}