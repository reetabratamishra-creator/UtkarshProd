trigger LeadTrigger on Lead (before insert, before update, after insert, after update) {

    try {

        // BEFORE INSERT / BEFORE UPDATE
        if (Trigger.isBefore) {
            LeadProspectingActivityHandler.updateProspectingActivityDate(
                Trigger.new,
                Trigger.oldMap
            );
        }

        // AFTER INSERT
        if (Trigger.isAfter && Trigger.isInsert) {

            BWM_EmailLeadTriggerHandler.handleAfterInsert(Trigger.new);

            BWM_LeadMessagingTriggerHandler.handleAfterInsert(Trigger.new);
            
            // IndiaMART Lead Keyword Matching & Department Assignment - 11/08/2026 - Ayantika
            try {
            // IndiaMART Lead Keyword Matching & Department Assignment - 11/08/2026 - Ayantika
            IndiaMartKeywordHandler.handleAfterSave(Trigger.new, null);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler failed: ' + ex.getMessage());
        }
        }
        
        if (Trigger.isAfter && Trigger.isUpdate){
            
            //For creating notes records //Nasir - 19/07/2026
            LeadNotesTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
            
            // IndiaMART Lead Keyword Matching & Department Assignment - 11/08/2026 - Ayantika
             try {
            IndiaMartKeywordHandler.handleAfterSave(Trigger.new, Trigger.oldMap);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler failed: ' + ex.getMessage());
        }
            
        }

    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'LeadTrigger failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }
}