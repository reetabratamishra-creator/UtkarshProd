/*trigger UserTenderShareTrigger on User (after insert, after update) {

    // Kill switch (same Custom Metadata used by the Tender trigger)
    Tender_Trigger_Controll__mdt setting =
        Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');

    if (setting != null && !setting.Is_Active__c) {
        return;
    }

    try {
        if (Trigger.isInsert) {
            UserTenderShareTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            UserTenderShareTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } catch (Exception ex) {
        // Never block the user save because of sharing problems
        System.debug(LoggingLevel.ERROR,
            'UserTenderShareTrigger failed: ' + ex.getMessage()
            + '\n' + ex.getStackTraceString());
    }
}*/
trigger UserTenderShareTrigger on User (after insert, after update) {
    UserTenderShareTriggerHandler.run(
        Trigger.isInsert,
        Trigger.isUpdate,
        Trigger.new,
        Trigger.oldMap
    );
}