public with sharing class POQueueableProcessor implements Queueable, Database.AllowsCallouts {

    public class FileJob {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id contentDocumentId;
    }

    private List<FileJob> jobs;
    private Integer currentIndex;

    public POQueueableProcessor(List<FileJob> jobs, Integer currentIndex) {
        this.jobs = jobs;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext context) {
        if (currentIndex >= jobs.size()) {
            return; // all done
        }

        FileJob job = jobs[currentIndex];

        try {
            // Mark as Processing
            PO_Line_Items__c rec = new PO_Line_Items__c(
                Id = job.recordId,
                Status__c = 'Processing'
            );
            update rec;

            // Get latest ContentVersion for this file
            ContentVersion cv = [
                SELECT Id, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :job.contentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];

            // Call your Prompt Template — adjust this to match how you invoke it
            String jsonResponse = PromptTemplateService.runExtraction(cv.Id);

            // Parse and save
            POResponseParser.parseAndSave(job.recordId, jsonResponse);

        } catch (Exception e) {
            PO_Line_Items__c failRec = new PO_Line_Items__c(
                Id = job.recordId,
                Status__c = 'Failed',
                Error_Message__c = e.getMessage()
            );
            update failRec;
        }

        // Chain to next file
        if (currentIndex + 1 < jobs.size()) {
            System.enqueueJob(new POQueueableProcessor(jobs, currentIndex + 1));
        }
    }
}