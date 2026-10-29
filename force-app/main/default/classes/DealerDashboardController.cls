/**
 * @description Controller for the dealerDashboardViewer LWC component.
 *              Dynamically reads Dealer_Dashboard_Field__mdt to determine which fields
 *              to query and display for opportunities whose Customer Journey is set to 'Refer to Dealer'.
 *
 *              Key design decisions:
 *              - Related fields (e.g. Account.Name) are flattened to underscore
 *                notation (Account_Name) for lightning-datatable compatibility.
 *              - Name fields (own record + related) are rendered as clickable
 *                hyperlinks navigating to the record page.
 *              - Uses 'with sharing' so record visibility follows the running
 *                user's org-level security.
 */
public without sharing class DealerDashboardController {

    @AuraEnabled
    public static Map<String, Object> getDealerOpportunitiesData() {
        String objectName = 'Opportunity';
        String filterClause = 'Customer_Journey__c = \'Refer to Dealer\'';

        // Step 1 – Read Custom Metadata
        List<Dealer_Dashboard_Field__mdt> fieldMetas = [
            SELECT Field_API_Name__c, Column_Label__c, Column_Order__c
            FROM   Dealer_Dashboard_Field__mdt
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
        for (Dealer_Dashboard_Field__mdt fm : fieldMetas) {
            String fieldApiName = fm.Field_API_Name__c;
            if (!soqlFields.contains(fieldApiName)) {
                soqlFields.add(fieldApiName);
            }
        }

        String soql = 'SELECT '  + String.join(soqlFields, ', ')
                    + ' FROM '   + String.escapeSingleQuotes(objectName)
                    + ' WHERE '  + filterClause
                    + ' ORDER BY CreatedDate DESC'
                    + ' LIMIT 1000';

        List<SObject> records = Database.query(soql);

        // Step 3 – Build column definitions
        List<Map<String, Object>> columns = new List<Map<String, Object>>();
        for (Dealer_Dashboard_Field__mdt fm : fieldMetas) {
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

            for (Dealer_Dashboard_Field__mdt fm : fieldMetas) {
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

    /**
     * @description Returns the lightning-datatable column type based on field name heuristics.
     */
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
        if (lower.contains('amount') || lower.contains('price')) {
            return 'currency';
        }
        return 'text';
    }
}