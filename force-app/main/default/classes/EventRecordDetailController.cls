public without sharing class EventRecordDetailController {

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
    public static List<SectionWrapper> getEventLayout(Id recordId) {

        List<Event_Record_Fields__mdt> configs = [
            SELECT Section_Name__c,
                   Field_Label__c,
                   Field_API_Name__c,
                   Field_Order__c
            FROM Event_Record_Fields__mdt
            ORDER BY Field_Order__c
        ];

        Set<String> fieldsToQuery = new Set<String>();

        for (Event_Record_Fields__mdt cfg : configs) {
            if (String.isBlank(cfg.Field_API_Name__c)) continue;

            String api = cfg.Field_API_Name__c;
            fieldsToQuery.add(api);

            if (api == 'OwnerId') fieldsToQuery.add('Owner.Name');
            if (api == 'WhoId') fieldsToQuery.add('Who.Name');
            if (api == 'WhatId') fieldsToQuery.add('What.Name');
            if (api == 'CreatedById') {
                fieldsToQuery.add('CreatedBy.Name');
                fieldsToQuery.add('CreatedDate');
            }
            if (api == 'LastModifiedById') {
                fieldsToQuery.add('LastModifiedBy.Name');
                fieldsToQuery.add('LastModifiedDate');
            }
        }

        String soql =
            'SELECT ' + String.join(new List<String>(fieldsToQuery), ',') +
            ' FROM Event WHERE Id = :recordId';

        Event e = Database.query(soql);

        Map<String, SectionWrapper> sectionMap = new Map<String, SectionWrapper>();
        List<SectionWrapper> result = new List<SectionWrapper>();

        for (Event_Record_Fields__mdt cfg : configs) {

            String section = cfg.Section_Name__c;

            if (!sectionMap.containsKey(section)) {
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
            f.isLookup = false;
            f.value = '';

            if (api == 'OwnerId') {
                f.isLookup = true;
                f.recordId = (String)e.OwnerId;
                f.value = e.Owner != null ? e.Owner.Name : '';

            } else if (api == 'WhoId') {
                f.isLookup = true;
                f.recordId = (String)e.WhoId;
                f.value = e.Who != null ? e.Who.Name : '';

            } else if (api == 'WhatId') {
                f.isLookup = true;
                f.recordId = (String)e.WhatId;
                f.value = e.What != null ? String.valueOf(e.What.get('Name')) : '';

            } else if (api == 'CreatedById') {
                f.isLookup = true;
                f.recordId = (String)e.CreatedById;
                f.value = e.CreatedBy != null ? e.CreatedBy.Name : '';
                f.subValue = e.CreatedDate != null ? e.CreatedDate : null;

            } else if (api == 'LastModifiedById') {
                f.isLookup = true;
                f.recordId = (String)e.LastModifiedById;
                f.value = e.LastModifiedBy != null ? e.LastModifiedBy.Name : '';
                f.subValue = e.LastModifiedDate != null ? e.LastModifiedDate : null;

            } else if (api == 'IsReminderSet') {
                Object val = e.get(api);
                Boolean isSet = val != null ? (Boolean)val : false;
                f.value = isSet ? 'Reminder Set' : 'No Reminder Set';

            } else {
                Schema.DisplayType type =
                    Event.SObjectType.getDescribe()
                        .fields.getMap()
                        .get(api)
                        .getDescribe()
                        .getType();

                Object val = e.get(api);

                if (type == Schema.DisplayType.DATETIME) {
                    f.value = val != null ? ((Datetime)val).format() : '';
                } else if (type == Schema.DisplayType.DATE) {
                    f.value = val != null ? ((Date)val).format() : '';
                } else if (type == Schema.DisplayType.BOOLEAN) {
                    f.value = val != null ? String.valueOf(val) : 'false';
                } else {
                    f.value = val != null ? String.valueOf(val) : '';
                }
            }

            sectionMap.get(section).fields.add(f);
        }

        return result;
    }
}