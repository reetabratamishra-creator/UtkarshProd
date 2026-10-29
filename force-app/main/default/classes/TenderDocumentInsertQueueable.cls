/*
Owner - Ayantika
CLASS: TenderDocumentInsertQueueable


Handles the insertion of Tender_Docoment_Details__c records in a separate Queueable transaction.
Takes the complete document list, start index, chunk size, and Product Name as input.
Processes the documents in chunks based on the given chunk size.
Inserts the current document chunk using bulk DML.
If any document fails to insert, captures the error and creates an Integration Log.
Calls IntegrationLogger.flush() after processing the current chunk.
If more documents remain, it chains another TenderDocumentInsertQueueable job with the next starting index.
This ensures document insertion does not compete with the Tender upsert and Integration Log DML limits in the same transaction.
Overall, this class inserts Tender document records in separate transactions, chunk by chunk, while handling errors and continuing with the remaining documents.
*/
public class TenderDocumentInsertQueueable implements Queueable {
    private List<Tender_Docoment_Details__c> allRecords;
    private Integer startIndex;
    private Integer chunkSize;
    private String productName;
    
    public TenderDocumentInsertQueueable(
        List<Tender_Docoment_Details__c> allRecords,
        Integer startIndex,
        Integer chunkSize,
        String productName
    ) {
        this.allRecords = allRecords;
        this.startIndex = startIndex;
        this.chunkSize = chunkSize;
        this.productName = productName;
    }
    
    public void execute(QueueableContext ctx) {
        
        if (
            allRecords == null ||
            allRecords.isEmpty() ||
            startIndex >= allRecords.size()
        ) {
            return;
        }
        
        
        Integer endIdx = Math.min(
            startIndex + chunkSize,
            allRecords.size()
        );
        
        
        List<Tender_Docoment_Details__c> currentChunk =
            new List<Tender_Docoment_Details__c>();
        
        
        for (Integer i = startIndex; i < endIdx; i++) {
            currentChunk.add(allRecords[i]);
        }
        
        
        try {
            
            Database.SaveResult[] results =
                Database.insert(currentChunk, false);
            
            
            for (Database.SaveResult res : results) {
                
                if (!res.isSuccess()) {
                    
                    String errMsg = '';
                    
                    for (Database.Error err : res.getErrors()) {
                        
                        errMsg +=
                            err.getStatusCode()
                            + ': '
                            + err.getMessage()
                            + ' | Fields: '
                            + err.getFields()
                            + '; ';
                    }
                    
                    
                    IntegrationLogger.log(
                        'DocInsertChunkFailed',
                        productName,
                        'doc-insert-queueable',
                        null,
                        errMsg,
                        null,
                        false,
                        errMsg
                    );
                }
            }
            
            
            IntegrationLogger.flush();
            if (endIdx < allRecords.size() && !Test.isRunningTest()) {
                System.enqueueJob(
                    new TenderDocumentInsertQueueable(allRecords, endIdx, chunkSize, productName)
                );
            }
            
        } catch (Exception docEx) {
            
            IntegrationLogger.log(
                'DocInsertChunkFailed',
                productName,
                'doc-insert-queueable',
                null,
                docEx.getMessage(),
                null,
                false,
                docEx.getMessage()
            );
            
            IntegrationLogger.flush();
        }
        
    }
    
}