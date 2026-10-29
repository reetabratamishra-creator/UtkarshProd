public with sharing class TaskRecordDetailController {

    public class SectionWrapper {
        @AuraEnabled public String sectionName;
        @AuraEnabled public List<FieldWrapper> fields;
    }

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public Integer order;

        @AuraEnabled public String value;
        @AuraEnabled public DateTime subValue;
        @AuraEnabled public String recordId;
        @AuraEnabled public Boolean isLookup;
    }

    @AuraEnabled(cacheable=true)
    public static List<SectionWrapper> getTaskLayout(Id recordId) {

        List<Task_Record_Field__mdt> configs = [
            SELECT Section_Name__c,
                   Field_Label__c,
                   Field_API_Name__c,
                   Field_Order__c
            FROM Task_Record_Field__mdt
            ORDER BY Field_Order__c
        ];

        Set<String> fieldsToQuery = new Set<String>();

        for(Task_Record_Field__mdt cfg : configs) {
            if(String.isBlank(cfg.Field_API_Name__c)) continue;

            String api = cfg.Field_API_Name__c;
            fieldsToQuery.add(api);

            // add relationship fields for lookups
            if(api == 'OwnerId') fieldsToQuery.add('Owner.Name');
            if(api == 'WhoId') fieldsToQuery.add('Who.Name');
            if(api == 'WhatId') fieldsToQuery.add('What.Name');
            if(api == 'CreatedById') {
                fieldsToQuery.add('CreatedBy.Name');
                fieldsToQuery.add('CreatedDate');
            }
            if(api == 'LastModifiedById'){
                fieldsToQuery.add('LastModifiedBy.Name');
                fieldsToQuery.add('LastModifiedDate'); 
            } 
        }

        String soql =
            'SELECT ' + String.join(new List<String>(fieldsToQuery), ',') +
            ' FROM Task WHERE Id = :recordId';

        Task t = Database.query(soql);

        Map<String, SectionWrapper> sectionMap = new Map<String, SectionWrapper>();
        List<SectionWrapper> result = new List<SectionWrapper>();

        for(Task_Record_Field__mdt cfg : configs) {

            String section = cfg.Section_Name__c;

            if(!sectionMap.containsKey(section)) {
                SectionWrapper sw = new SectionWrapper();
                sw.sectionName = section;
                sw.fields = new List<FieldWrapper>();
                sectionMap.put(section, sw);
                result.add(sw);
            }

            FieldWrapper f = new FieldWrapper();
            f.label = cfg.Field_Label__c;
            f.apiName = cfg.Field_API_Name__c;
            f.order = Integer.valueOf(cfg.Field_Order__c);

            String api = cfg.Field_API_Name__c;

            // DEFAULT
            f.isLookup = false;
            f.value = '';

            // LOOKUPS
            if(api == 'OwnerId') {
                f.isLookup = true;
                f.recordId = (String)t.OwnerId;
                f.value = t.Owner != null ? t.Owner.Name : '';

            } else if(api == 'WhoId') {
                f.isLookup = true;
                f.recordId = (String)t.WhoId;
                f.value = t.Who != null ? t.Who.Name : '';

            } else if(api == 'WhatId') {
                f.isLookup = true;
                f.recordId = (String)t.WhatId;
                f.value = t.What != null ? String.valueOf(t.What.get('Name')) : '';

            } else if(api == 'CreatedById') {
                f.isLookup = true;
                f.recordId = (String)t.CreatedById;
                f.value = t.CreatedBy != null ? t.CreatedBy.Name : '';
                f.subValue = t.CreatedDate != null ? t.CreatedDate : null;

            } else if(api == 'LastModifiedById') {
                f.isLookup = true;
                f.recordId = (String)t.LastModifiedById;
                f.value = t.LastModifiedBy != null ? t.LastModifiedBy.Name : '';
                f.subValue = t.LastModifiedDate != null ? t.LastModifiedDate : null;

            } else {
                Schema.DisplayType type =
                    Task.SObjectType.getDescribe()
                        .fields.getMap()
                        .get(api)
                        .getDescribe()
                        .getType();
                
                Object val = t.get(api);
                
                if(type == Schema.DisplayType.DATETIME) {
                    f.value = val != null ? ((Datetime)val).format() : '';
                }
                else if(type == Schema.DisplayType.DATE) {
                    f.value = val != null ? ((Date)val).format() : '';
                }
                else {
                    f.value = val != null ? String.valueOf(val) : '';
                }
            }

            sectionMap.get(section).fields.add(f);
        }

        return result;
    }
}