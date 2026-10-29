public with sharing class BWM_CampaignFilterService {
    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLeadLostReasonOptions() {
        return getPicklistOptions(Lead.SObjectType, 'Lost_Reason__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOpportunityLostReasonOptions() {
        return getPicklistOptions(Opportunity.SObjectType, 'Lost_Reason__c');
    }

    private static List<PicklistOption> getPicklistOptions(
        Schema.SObjectType objectType,
        String fieldApiName
    ) {
        List<PicklistOption> options = new List<PicklistOption>();
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return options;
        }

        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldApiName).getDescribe();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
        }
        return options;
    }
}