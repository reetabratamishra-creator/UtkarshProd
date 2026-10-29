public with sharing class TenderDocumentDetailsController {
    @AuraEnabled(cacheable=true)
    public static List<Tender_Docoment_Details__c> getDocuments(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record ID cannot be null');
        }
        Id tenderId;
        Schema.SObjectType objType = recordId.getSObjectType();
        // Dynamically check the object type instead of relying on hardcoded 'a01'/'a02' prefixes
        if (objType == Tender__c.sObjectType) {
            tenderId = recordId;
        } 
        else if (objType == Project__c.sObjectType) {
            // Safely query the project to get the Tender ID
            List<Project__c> projects = [
                SELECT Id, Tender__c 
                FROM Project__c 
                WHERE Id = :recordId 
                WITH USER_MODE 
                LIMIT 1
            ];

            if (!projects.isEmpty()) {
                tenderId = projects[0].Tender__c;
            }
        }
        else if (objType == Opportunity.sObjectType) {
            List<Opportunity> opp = [
                SELECT Id,
                    RecordType.DeveloperName,
                    Tender__c
                FROM Opportunity
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!opp.isEmpty() &&
                (opp[0].RecordType.DeveloperName == 'Project_Opportunity' ||
                opp[0].RecordType.DeveloperName == 'Tender_Opportunity')) {
                tenderId = opp[0].Tender__c;
            }
        }
        // Return the documents if we successfully resolved a tenderId
        if (tenderId != null) {
            return [
                SELECT Id, Name, Name__c, Type__c, Download_URL__c, Download_URL_Text__c
                FROM Tender_Docoment_Details__c
                WHERE Tender__c = :tenderId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];
        } else {
            // Fixed typo: removed the double 'throw new' and unreachable 'return;'
            throw new AuraHandledException('Associated Tender ID is null or could not be found.');
        }
    }
}