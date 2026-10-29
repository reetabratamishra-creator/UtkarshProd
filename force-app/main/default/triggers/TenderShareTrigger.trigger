trigger TenderShareTrigger on Tender__c (before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isUpdate) {

        TenderOwnerValidationHandler.validateOwnerChange(
            Trigger.new,
            Trigger.oldMap
        );
    }

    // Check if trigger is enabled in Custom Metadata
    Tender_Trigger_Controll__mdt  setting = Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');
    // If metadata exists and trigger is disabled, exit
    if (setting != null && !setting.Is_Active__c) {
        return;
    }

    if (Trigger.isAfter) {

        // On Insert → share all records
        if (Trigger.isInsert) {
            TenderSharingHandler.shareTenders(Trigger.new);
        }

        // On Update → only process records where Department or Owner changed
        if (Trigger.isUpdate) {

            List<Tender__c> tendersToProcess = new List<Tender__c>();

            for (Tender__c newRec : Trigger.new) {
                Tender__c oldRec = Trigger.oldMap.get(newRec.Id);

                if (
                    newRec.Department_Name__c != oldRec.Department_Name__c ||
                    newRec.OwnerId != oldRec.OwnerId
                ) {
                    tendersToProcess.add(newRec);
                }
            }

            if (!tendersToProcess.isEmpty()) {
                TenderSharingHandler.shareTenders(tendersToProcess);
            }
        }
    }
    
   try {
        if (System.isBatch() || System.isFuture() || System.isQueueable()) {
            return;
        }

        if (Trigger.isAfter && Trigger.isInsert) {
            // Use ONE of these for insert alerts — not both (avoids duplicate New Tender emails)
            // Option A: existing notification handler
            //TenderNotificationHandler.notifyNewTenders(Trigger.new);
            
            
            // and other trigger work are not blocked by email SOQL.
            // Do not call TenderStatusEmailHandler.handleAfterInsert here.
            // Insert emails run in TenderNewTenderAlertEmailQueueable so sharing
            TenderNewTenderAlertEmailQueueable.enqueue(Trigger.newMap.keySet());
        }

        if (Trigger.isAfter && Trigger.isUpdate) {
            TenderStatusEmailHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'Tender email/notification failed: ' + ex.getMessage()
            + '\n' + ex.getStackTraceString()
        );
    }

        
}