public without sharing class ParentProjectOpportunityTriggerHandler {

    private static final String PROJECT_RECORD_TYPE = 'Project_Opportunity';
    private static final String CLOSED_LOST = 'Closed Lost';

    // Fields allowed to change even when the record is locked
    private static final Set<Schema.SObjectField> ALLOWED_FIELDS =
        new Set<Schema.SObjectField>{
            Opportunity.StageName,
            Opportunity.Probability,
            Opportunity.IsClosed,
            Opportunity.Lost_Reason__c,
            Opportunity.Stage__c,
            Opportunity.Lost_Reason_Formula__c,
            Opportunity.ForecastCategory,
            Opportunity.ForecastCategoryName,
            Opportunity.Amount,
            Opportunity.Last_Open_Task_Activity__c,
            Opportunity.OppOverdueEsc96Sent__c,
            Opportunity.OppOverdueEsc36Sent__c,
            Opportunity.FirstOverdueTaskDate__c,
            Opportunity.ExpectedRevenue,
            Opportunity.Stage_Lost_From__c
        };

    public static void validateParentProjectOpportunity(
        List<Opportunity> newList,
        Map<Id, Opportunity> oldMap
    ) {

        // Metadata check
        Trigger_Enable__mdt config =
            Trigger_Enable__mdt.getInstance('ParentProjectOpportunityTrigger');

        if (config == null || !config.IsEnable__c) {
            System.debug(
                'ParentProjectOpportunityTriggerHandler: ' +
                'trigger disabled via metadata - skipping.'
            );
            return;
        }

        Id projectRecordTypeId =
            Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get(PROJECT_RECORD_TYPE)
                .getRecordTypeId();

        Map<String, Schema.SObjectField> fieldMap =
            Opportunity.SObjectType
                .getDescribe()
                .fields
                .getMap();

        for (Opportunity opp : newList) {

            Opportunity oldOpp = oldMap.get(opp.Id);

            // Only applies to locked Parent Project Opportunities
            if (oldOpp.RecordTypeId != projectRecordTypeId ||
                !oldOpp.isParent__c) {
                continue;
            }

        
            // Block if any non-allowed, updateable field has changed
            Boolean otherFieldChanged = false;

            for (String fieldName : fieldMap.keySet()) {

                Schema.SObjectField field = fieldMap.get(fieldName);

                // Skip fields that are explicitly allowed
                if (ALLOWED_FIELDS.contains(field)) {
                    continue;
                }

                Schema.DescribeFieldResult dfr = field.getDescribe();

                // Skip fields that users cannot update
                // and calculated/formula fields
                if (!dfr.isUpdateable() ||
                    dfr.isCalculated() ||
                    !dfr.isAccessible()) {
                    continue;
                }

                Object oldValue = oldOpp.get(fieldName);
                Object newValue = opp.get(fieldName);

                Boolean changed = (oldValue == null)
                    ? newValue != null
                    : !oldValue.equals(newValue);

                if (changed) {
                    otherFieldChanged = true;

                    System.debug(
                        'ParentProjectOpportunityTriggerHandler: ' +
                        'blocking ' + opp.Id +
                        ' - field changed: ' + fieldName +
                        ' (old: ' + oldValue +
                        ', new: ' + newValue + ')'
                    );

                    break;
                }
            }

            if (otherFieldChanged) {
                opp.addError('This Parent Project Opportunity is locked. ' );
                continue;
            }

            // If Stage is changed, it must be changed to Closed Lost
            /*if (opp.StageName != oldOpp.StageName &&
                opp.StageName != CLOSED_LOST) {

                System.debug(
                    'ParentProjectOpportunityTriggerHandler: ' +
                    'blocking ' + opp.Id +
                    ' - Stage changed to "' + opp.StageName +
                    '" instead of Closed Lost'
                );

                opp.addError(
                    'This Parent Project Opportunity is locked. ' +
                    'Stage can only be changed to Closed Lost.'
                );
            }*/
        }
    }
}