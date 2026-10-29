/**
 * @description Controller for the qualifiedLeads LWC component.
 *              Dynamically reads Qualified_Lead_Field__mdt to determine which fields
 *              to query and display for Qualified Leads.
 */
public with sharing class QualifiedLeadsController {

    /**
     * @description Retrieves the column definitions and data for Leads with status = filterValue.
     */
    @AuraEnabled
    public static Map<String, Object> getQualifiedLeadsData(String filterValue) {
        String val = String.isBlank(filterValue) ? 'Qualified' : filterValue;
        return buildObjectData('Lead', 'Status = \'' + String.escapeSingleQuotes(val) + '\'');
    }

    /**
     * @description Checks read access to Lead.
     */
    @AuraEnabled
    public static Map<String, Boolean> getObjectAccess() {
        return new Map<String, Boolean>{
            'Lead' => Schema.sObjectType.Lead.isAccessible()
        };
    }

    /**
     * @description Generic helper that:
     *   1. Reads Qualified_Lead_Field__mdt for the object.
     *   2. Builds a SOQL query.
     *   3. Formats & flattens fields.
     */
    private static Map<String, Object> buildObjectData(String objectName, String filterClause) {
        // Step 1 – Read Custom Metadata (Qualified_Lead_Field__mdt)
        List<Qualified_Lead_Field__mdt> fieldMetas = [
            SELECT Field_API_Name__c, Column_Label__c, Column_Order__c
            FROM   Qualified_Lead_Field__mdt
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
        for (Qualified_Lead_Field__mdt fm : fieldMetas) {
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
        List<Map<String, Object>> columns = new List<Map<String, Object>>();
        for (Qualified_Lead_Field__mdt fm : fieldMetas) {
            String fieldApiName = fm.Field_API_Name__c;
            String flatKey      = fieldApiName.replace('.', '_');

            Map<String, Object> colDef = new Map<String, Object>();
            colDef.put('label', fm.Column_Label__c);

            if (fieldApiName == 'Name') {
                colDef.put('fieldName', 'recordLink');
                colDef.put('type', 'url');
                colDef.put('typeAttributes', new Map<String, Object>{
                    'label' => new Map<String, String>{ 'fieldName' => 'Name' },
                    'target' => '_self'
                });
            } else if (fieldApiName.contains('.') && fieldApiName.endsWith('.Name')) {
                String relName = fieldApiName.split('\\.')[0];
                String linkKey = relName + '_Link';
                colDef.put('fieldName', linkKey);
                colDef.put('type', 'url');
                colDef.put('typeAttributes', new Map<String, Object>{
                    'label' => new Map<String, String>{ 'fieldName' => flatKey },
                    'target' => '_self'
                });
            } else {
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
            flatRecord.put('recordLink', '/lightning/r/' + objectName + '/' + record.Id + '/view');

            for (Qualified_Lead_Field__mdt fm : fieldMetas) {
                String fieldApiName = fm.Field_API_Name__c;
                String flatKey      = fieldApiName.replace('.', '_');

                if (fieldApiName.contains('.')) {
                    List<String> parts = fieldApiName.split('\\.');
                    SObject relObj = record.getSObject(parts[0]);
                    flatRecord.put(flatKey, relObj != null ? relObj.get(parts[1]) : null);

                    if (parts[1] == 'Name' && relObj != null && relObj.Id != null) {
                        String linkKey = parts[0] + '_Link';
                        flatRecord.put(linkKey, '/lightning/r/' + relObj.Id + '/view');
                    }
                } else {
                    flatRecord.put(flatKey, record.get(fieldApiName));
                }
            }

            flatRecords.add(flatRecord);
        }

        return new Map<String, Object>{
            'columns' => columns,
            'data'    => flatRecords
        };
    }

    private static String resolveColumnType(String fieldApiName) {
        String lower = fieldApiName.toLowerCase();
        if (lower.contains('date') && !lower.contains('datetime')) {
            return 'date-local';
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