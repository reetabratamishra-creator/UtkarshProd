/**
 * @description   Main Opportunity trigger that routes to messaging and email handlers
 *                among other Opportunity logic.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
trigger OpportunityTrigger on Opportunity (
    before update,
    after insert,
    after update
) {

    try {

        // BEFORE UPDATE
        if (Trigger.isBefore && Trigger.isUpdate) {
            for (Opportunity opp : Trigger.new) {
                if (opp.isFirstUpdate__c) {
                    opp.isFirstUpdate__c = true;
                }
            }
            ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(Trigger.new,Trigger.oldMap);
        }

        // AFTER INSERT
        if (Trigger.isAfter && Trigger.isInsert) {

            BWM_EmailOpportunityTriggerHandler.handleAfterInsert(
                Trigger.new
            );

            BWM_OpportunityMessagingTriggerHandler.handleAfterInsert(
                Trigger.new
            );
        }

        // AFTER UPDATE
        if (Trigger.isAfter && Trigger.isUpdate) {

            BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
                Trigger.new,
                Trigger.oldMap
            );

            BWM_OpportunityMessagingTriggerHandler.handleAfterUpdate(
                Trigger.new,
                Trigger.oldMap
            );
            
            //For creating notes records //Nasir - 19/07/2026
            OpportunityNotesTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }

    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'OpportunityTrigger failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }

    try {
        if (Trigger.isAfter && Trigger.isInsert) {
            OpportunityAssignmentEmailHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isAfter && Trigger.isUpdate) {
            OpportunityAssignmentEmailHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
            
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'OpportunityAssignmentEmailTrigger failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }

    try {
        if (Trigger.isAfter && Trigger.isUpdate) {
            OpportunityWonPushNotificationHandler.handleAfterUpdate(
                Trigger.new,
                Trigger.oldMap
            );
        }
    } catch (Exception ex) {
        System.debug(
            LoggingLevel.ERROR,
            'OpportunityWonPushNotificationTrigger failed: ' + ex.getMessage() +
            '\nStack Trace: ' + ex.getStackTraceString()
        );
    }
}