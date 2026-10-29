public with sharing class EmployeeTrackerCls {
    

    @AuraEnabled
    public static List<Employee__c> getEmployees() {
        // Implementation to fetch employee data
        return [SELECT Id, Name, Phone__c, Latitude__c, Longitude__c FROM Employee__c];
    }


}