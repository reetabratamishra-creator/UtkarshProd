public class LeadPicklistValuesAction {

    public class Request {
        @InvocableVariable(label='Input' description='Not used, leave blank')
        public String dummyValue;
    }

    public class Response {
        @InvocableVariable(label='Lead Source Values')
        public List<String> leadSourceValues;

        @InvocableVariable(label='Department Values')
        public List<String> departmentValues;

        @InvocableVariable(label='Previous Source Values')
        public List<String> previousSourceValues;
    }

    @InvocableMethod(label='Get Lead Picklist Values' description='Returns active picklist values for LeadSource, Department, and PreviousSource fields on Lead object')
    public static List<Response> getLeadPicklistValues(List<Request> requests) {
        Response res = new Response();

        res.leadSourceValues = getPicklistValues('Lead', 'LeadSource');
        res.departmentValues = getPicklistValues('Lead', 'Department_Name__c');
        res.previousSourceValues = getPicklistValues('Lead', 'Previous_Source__c');

        return new List<Response>{ res };
    }

    private static List<String> getPicklistValues(String objectApiName, String fieldApiName) {
        List<String> values = new List<String>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        if (objType != null) {
            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            if (fieldMap.containsKey(fieldApiName)) {
                Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldApiName).getDescribe();
                for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
                    if (entry.isActive()) {
                        values.add(entry.getValue());
                    }
                }
            }
        }
        return values;
    }
}