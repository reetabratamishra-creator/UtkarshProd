public with sharing class ActivityJourneyGuardHandler {

    /**
     * Controls activity (call/event) creation against an Opportunity.
     * Creation is blocked only when the parent Opportunity has a
     * Customer_Journey__c value AND isFirstUpdate__c is false.
     *
     * Called from the before-insert triggers on Task and Event (unchanged).
     */
    public static void guardBeforeInsert(List<SObject> records) {
        Set<Id> oppIds = new Set<Id>();
        for (SObject rec : records) {
            Id whatId = (Id) rec.get('WhatId');
            if (whatId != null && whatId.getSObjectType() == Opportunity.SObjectType) {
                oppIds.add(whatId);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>([
            SELECT Id, isFirstUpdate__c, Customer_Journey__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);

        for (SObject rec : records) {
            Id whatId = (Id) rec.get('WhatId');
            if (whatId == null || !oppById.containsKey(whatId)) {
                continue;
            }
            Opportunity opp = oppById.get(whatId);

            Boolean journeySet  = String.isNotBlank(opp.Customer_Journey__c);
            Boolean firstUpdate = opp.isFirstUpdate__c == true;   // null-safe

            if (journeySet && !firstUpdate) {
                rec.addError('This Opportunity is locked. An activity can be created only '
                    + 'while the Opportunity is pending its first update.');
            }
        }
    }
}