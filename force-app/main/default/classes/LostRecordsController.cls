/**
 * @description Controller for the lostRecords LWC component.
 *              Dynamically reads Lost_Record_Field__mdt to determine which fields
 *              to query and display for Lost Leads and Closed Lost Opportunities.
 *
 *              Key design decisions:
 *              - Related fields (e.g. Account.Name) are flattened to underscore
 *                notation (Account_Name) for lightning-datatable compatibility.
 *              - Name fields (own record + related) are rendered as clickable
 *                hyperlinks navigating to the record page.
 *              - Uses 'with sharing' so record visibility follows the running
 *                user's org-level security (OWD, sharing rules, role hierarchy).
 */
public with sharing class LostRecordsController {

    // ─── Public Wired Methods ───────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> getLostLeadsData() {
        return buildObjectData('Lead', 'Status = \'Lost\'');
    }

    @AuraEnabled
    public static Map<String, Object> getClosedLostOpportunitiesData() {
        return buildObjectData('Opportunity', 'StageName = \'Closed Lost\'');
    }

    @AuraEnabled
    public static Map<String, Boolean> getObjectAccess() {
        return new Map<String, Boolean>{
            'Lead' => Schema.sObjectType.Lead.isAccessible(),
            'Opportunity' => Schema.sObjectType.Opportunity.isAccessible()
        };
    }

    // ─── Private Helpers ────────────────────────────────────────────────────

    /**
     * @description Generic method that:
     *   1. Reads CMT to get ordered field list for the given object
     *   2. Dynamically builds and executes a SOQL query with the filter
     *   3. Flattens related fields (dot notation → underscore)
     *   4. Adds record URLs for Name fields (hyperlinks)
     *   5. Returns { columns, data } consumed by the LWC datatable
     */
    private static Map<String, Object> buildObjectData(String objectName, String filterClause) {

        // Step 1 – Read Custom Metadata
        List<Lost_Record_Field__mdt> fieldMetas = [
            SELECT Field_API_Name__c, Column_Label__c, Column_Order__c
            FROM   Lost_Record_Field__mdt
            WHERE  Object_Name__c = :objectName
            ORDER BY Column_Order__c ASC NULLS LAST
        ];

        if (fieldMetas.isEmpty()) {
            return new Map<String, Object>{
                'columns' => new List<Object>(),
                'data'    => new List<Object>()
            };
        }

        // Step 2 – Build SOQL field list (always include Id)
        List<String> soqlFields = new List<String>{ 'Id' };
        for (Lost_Record_Field__mdt fm : fieldMetas) {
            String fieldApiName = fm.Field_API_Name__c;
            if (!soqlFields.contains(fieldApiName)) {
                soqlFields.add(fieldApiName);
            }
        }

        String soql = 'SELECT '  + String.join(soqlFields, ', ')
                    + ' FROM '   + String.escapeSingleQuotes(objectName)
                    + ' WHERE '  + filterClause
                    + ' ORDER BY CreatedDate DESC'
                    + ' LIMIT 500';

        List<SObject> records = Database.query(soql);

        // Step 3 – Build column definitions
        // Name fields become 'url' type with typeAttributes so they render
        // as clickable hyperlinks pointing to the record page.
        List<Map<String, Object>> columns = new List<Map<String, Object>>();
        for (Lost_Record_Field__mdt fm : fieldMetas) {
            String fieldApiName = fm.Field_API_Name__c;
            String flatKey      = fieldApiName.replace('.', '_');

            Map<String, Object> colDef = new Map<String, Object>();
            colDef.put('label', fm.Column_Label__c);

            if (fieldApiName == 'Name') {
                // Main record Name → hyperlink to the record
                colDef.put('fieldName', 'recordLink');
                colDef.put('type', 'url');
                colDef.put('typeAttributes', new Map<String, Object>{
                    'label' => new Map<String, String>{ 'fieldName' => 'Name' },
                    'target' => '_self'
                });
            } else if (fieldApiName.contains('.') && fieldApiName.endsWith('.Name')) {
                // Related record Name (e.g. Account.Name) → hyperlink to related record
                String relName = fieldApiName.split('\\.')[0];
                String linkKey = relName + '_Link';
                colDef.put('fieldName', linkKey);
                colDef.put('type', 'url');
                colDef.put('typeAttributes', new Map<String, Object>{
                    'label' => new Map<String, String>{ 'fieldName' => flatKey },
                    'target' => '_self'
                });
            } else {
                // Normal field
                colDef.put('fieldName', flatKey);
                colDef.put('type', resolveColumnType(fieldApiName));
            }

            columns.add(colDef);
        }

        // Step 4 – Flatten records and add record URLs for hyperlinks
        List<Map<String, Object>> flatRecords = new List<Map<String, Object>>();
        for (SObject record : records) {
            Map<String, Object> flatRecord = new Map<String, Object>();
            flatRecord.put('Id', record.Id);

            // Add main record hyperlink URL
            flatRecord.put('recordLink', '/lightning/r/' + objectName + '/' + record.Id + '/view');

            for (Lost_Record_Field__mdt fm : fieldMetas) {
                String fieldApiName = fm.Field_API_Name__c;
                String flatKey      = fieldApiName.replace('.', '_');

                if (fieldApiName.contains('.')) {
                    // Related field — traverse one level (e.g. Account.Name)
                    List<String> parts = fieldApiName.split('\\.');
                    SObject relObj = record.getSObject(parts[0]);
                    flatRecord.put(flatKey, relObj != null ? relObj.get(parts[1]) : null);

                    // If this is a related Name field, add its hyperlink URL
                    if (parts[1] == 'Name' && relObj != null && relObj.Id != null) {
                        String linkKey = parts[0] + '_Link';
                        flatRecord.put(linkKey, '/lightning/r/' + relObj.Id + '/view');
                    }
                } else {
                Object val = record.get(fieldApiName);
                if (val instanceof Datetime) {
                    flatRecord.put(flatKey, ((Datetime) val).format('dd/MM/yyyy, h:mm a').replace('AM','am').replace('PM','pm'));
                } else if (val instanceof Date) {
                    flatRecord.put(flatKey, Datetime.newInstance(((Date)val).year(), ((Date)val).month(), ((Date)val).day()).format('dd/MM/yyyy'));
                } else {
                    flatRecord.put(flatKey, val);
                }
            }
            }

            flatRecords.add(flatRecord);
        }

        return new Map<String, Object>{
            'columns' => columns,
            'data'    => flatRecords
        };
    }

    /**
     * @description Returns the lightning-datatable column type based on field name heuristics.
     */
    private static String resolveColumnType(String fieldApiName) {
        String lower = fieldApiName.toLowerCase();
        if (lower.contains('date')) {
            return 'text';
        }
        if (lower == 'phone') {
            return 'phone';
        }
        if (lower == 'email') {
            return 'email';
        }
        return 'text';
    }
}