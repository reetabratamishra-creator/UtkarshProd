/*
Owner - Ayantika
CLASS: TenderNotificationHandler

Handles the new Tender notification process.
Checks whether notification processing is currently skipped during integration.
Checks whether the new Tender list is empty or not.
Checks the Custom Metadata setting to confirm whether new Tender notifications are enabled.
Collects the Tender IDs where Department Name or Owner is available.
Sends the Tender IDs to TenderNewTenderNotificationQueueable for notification processing.
Uses Queueable Apex so the notification process runs asynchronously.
Handles and logs any exception/error that occurs while creating the notification job.
Overall, this class identifies new Tenders and starts the notification process for them.
*/
public class TenderNotificationHandler {
    
    public static Boolean skipNewTenderNotification = false;
    
    public static void notifyNewTenders(List<Tender__c> newTenders) {
        
        if (skipNewTenderNotification) {
            System.debug(
                '[TenderNotificationHandler] Notification skipped because integration processing is active.'
            );
            return;
        }
        
        if (newTenders == null || newTenders.isEmpty()) {
            return;
        }
        
        try {
            Tender_Trigger_Controll__mdt setting =
                Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');
            
            if (setting == null || setting.Push_Notification_For_New_Tender__c != true) {
                return;
            }
            
            Set<Id> tenderIds = new Set<Id>();
            
            for (Tender__c t : newTenders) {
                if (String.isNotBlank(t.Department_Name__c) || t.OwnerId != null) {
                    tenderIds.add(t.Id);
                }
            }
            
            if (tenderIds.isEmpty()) {
                return;
            }
            System.enqueueJob(
                new TenderNewTenderNotificationQueueable(
                    tenderIds,
                    null,  //null
                    null,   // productName
                    0       // chunkSize
                )
            );
            
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[TenderNotificationHandler] Failed to queue notifications: '
                + e.getMessage()
                + '\n'
                + e.getStackTraceString()
            );
        }
    }
}