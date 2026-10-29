public with sharing class POLineItemController {

    @AuraEnabled
    public static List<Id> createLineItemsAndStartProcessing(Id opportunityId, List<Id> contentDocumentIds) {
        try {
            List<PO_Line_Items__c> newRecords = new List<PO_Line_Items__c>();
            Map<Id, PO_Line_Items__c> docIdToRecord = new Map<Id, PO_Line_Items__c>();

            for (Id docId : contentDocumentIds) {
                PO_Line_Items__c rec = new PO_Line_Items__c(
                    Opportunity__c = opportunityId,
                    Status__c = 'Queued'
                );
                newRecords.add(rec);
                docIdToRecord.put(docId, rec);
            }

            insert newRecords;

            // Link files to records via ContentDocumentLink
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            Integer i = 0;
            List<Id> docIdList = new List<Id>(docIdToRecord.keySet());
            for (Id docId : docIdList) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = newRecords[i].Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
                i++;
            }
            insert links;

            // Build ordered list of record Ids + their ContentDocumentId for queueable chain
            List<POQueueableProcessor.FileJob> jobs = new List<POQueueableProcessor.FileJob>();
            i = 0;
            for (Id docId : docIdList) {
                POQueueableProcessor.FileJob job = new POQueueableProcessor.FileJob();
                job.recordId = newRecords[i].Id;
                job.contentDocumentId = docId;
                jobs.add(job);
                i++;
            }

            // Start the chain
            System.enqueueJob(new POQueueableProcessor(jobs, 0));

            List<Id> resultIds = new List<Id>();
            for (PO_Line_Items__c r : newRecords) {
                resultIds.add(r.Id);
            }
            return resultIds;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating records: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PO_Line_Items__c> getLineItemStatuses(List<Id> recordIds) {
        return [
            SELECT Id, Name, Status__c, PO_Number__c, Approval_Status__c ,Manual_Review_Completed__c ,Error_Message__c
            FROM PO_Line_Items__c
            WHERE Id IN :recordIds
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<PO_Line_Items__c> getExistingLineItems(Id opportunityId) {
        return [
            SELECT Id, Name, Status__c, PO_Number__c, PO_Date__c,Amount__c,Manual_Review_Completed__c,Approval_Status__c, CreatedDate
            FROM PO_Line_Items__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
        ];
    }
}