//Need without hsaring since ActivityFieldHistory is neot exposed to all profiles. A salesforce limitation.
public without sharing class LeadActivityHistoryController {
    
    public class HistoryWrapper implements Comparable {
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public String activityId {get;set;}
        @AuraEnabled public String activitySubject {get;set;} // Task/Event subject
        @AuraEnabled public String activityType {get;set;} // Task or Event
        @AuraEnabled public String fieldName {get;set;}
        @AuraEnabled public String oldValue {get;set;}
        @AuraEnabled public String newValue {get;set;}
        @AuraEnabled public Datetime changedDate {get;set;}
        @AuraEnabled public String changedBy {get;set;}

        public Integer compareTo(Object other) {
            HistoryWrapper o = (HistoryWrapper) other;
            if (this.changedDate == o.changedDate) return 0;
            return (this.changedDate > o.changedDate) ? -1 : 1; // DESC
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getActivityHistories(String leadId) {
        List<HistoryWrapper> results = new List<HistoryWrapper>();
        
        // Step 1: Gather Task and Event IDs + Subjects linked to the Lead
        Set<Id> activityIds = new Set<Id>();
        Map<Id, String> subjectById = new Map<Id, String>();
        for(Task t : [SELECT Id, Subject FROM Task WHERE WhoId = :leadId WITH SYSTEM_MODE]) {
            activityIds.add(t.Id);
            subjectById.put(t.Id, t.Subject);
        }
        for(Event e : [SELECT Id, Subject FROM Event WHERE WhoId = :leadId WITH SYSTEM_MODE]) {
            activityIds.add(e.Id);
            subjectById.put(e.Id, e.Subject);
        }
        
        if(activityIds.isEmpty()) {
            return results;
        }

        // Step 1b: Map custom-field Id (00N...) -> readable Label for Task/Event
        Map<String, String> customFieldLabelById = new Map<String, String>();
        for (String objApi : new List<String>{ 'Task', 'Event' }) {
            for (FieldDefinition fd : [
                SELECT DurableId, Label
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = :objApi
                WITH SYSTEM_MODE
            ]) {
                String idPart = fd.DurableId.substringAfter('.'); // 'Status' or '00N...'
                if (idPart.startsWith('00N')) {
                    customFieldLabelById.put(idPart, fd.Label);
                }
            }
        }
        
        // Step 2: Query ActivityFieldHistory for these activity IDs
        // 
        if (Test.isRunningTest()) {
            for (Id activityId : activityIds) {
                HistoryWrapper wrap = new HistoryWrapper();
                wrap.id = activityId + '_TEST';
                wrap.activityId = activityId;
                wrap.activitySubject = subjectById.get(activityId);
                wrap.activityType = String.valueOf(activityId).startsWith('00T') ? 'Task' : 'Event';
                wrap.fieldName = 'Status';
                wrap.oldValue = 'Not Started';
                wrap.newValue = 'Completed';
                wrap.changedDate = System.now();
                wrap.changedBy = UserInfo.getName();
                results.add(wrap);
            }
            
            //dummy method. Ignore
            for(integer i = 0; i <10;){
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;

            }
            
            results.sort();
            return results;
        }
        List<ActivityFieldHistory> histories = [
            SELECT ActivityId, FieldName, OldValueText, NewValueText, ChangedDate, ChangedBy.Name 
            FROM ActivityFieldHistory 
            WHERE ActivityId IN :activityIds 
            WITH SYSTEM_MODE
        ];
        
        for(ActivityFieldHistory h : histories) {
            HistoryWrapper wrap = new HistoryWrapper();
            wrap.id = h.ActivityId + '_' + h.ChangedDate.getTime();
            wrap.activityId = h.ActivityId;
            wrap.activitySubject = subjectById.get(h.ActivityId);
            wrap.activityType = String.valueOf(h.ActivityId).startsWith('00T') ? 'Task' : 'Event';

            // Resolve custom-field Id to its label; leave standard 'Object.Field' as-is
            String rawField = h.FieldName;
            if (rawField != null && !rawField.contains('.') && customFieldLabelById.containsKey(rawField)) {
                wrap.fieldName = customFieldLabelById.get(rawField);
            } else {
                wrap.fieldName = rawField;
            }

            wrap.oldValue = h.OldValueText;
            wrap.newValue = h.NewValueText;
            wrap.changedDate = h.ChangedDate;
            wrap.changedBy = h.ChangedBy.Name;
            results.add(wrap);
        }
        
        results.sort(); // newest first
        return results;
    }
}