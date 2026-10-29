public with sharing class OpportunityTriggerHandler {

    // Recursion guard — records already put through the gated logic in this transaction.
    private static Set<Id> processedIds = new Set<Id>();

    /* =========================================================================
     *
     *  isFirstUpdate__c = TRUE  -> record was created (lead conversion or
     *                              otherwise) but no Customer Journey chosen yet.
     *                              All gated automation is suppressed.
     *  isFirstUpdate__c = FALSE -> a Customer Journey value has landed at least
     *                              once. Gated automation runs from now on.
     *
     *  Nothing outside this class updates the isFirstUpdate__c.
     * ========================================================================= */

    public static void beforeInsert(List<Opportunity> newList) {
        for (Opportunity o : newList) {
            if (String.isNotBlank(o.Customer_Journey__c)) {
                // Created already carrying a journey — gate opens immediately.
                o.isFirstUpdate__c = false;
            } else if (o.isFirstUpdate__c == null) {
                // Belt and braces: the field default handles this, but an sObject
                // constructed in Apex without the field would come through null.
                o.isFirstUpdate__c = true;
            }
        }
    }

    public static void beforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        for (Opportunity o : newList) {
            Opportunity oldOpp = oldMap.get(o.Id);
            if (oldOpp == null) {
                continue;
            }
            if (o.isFirstUpdate__c != true) {
                continue;   // gate already open, nothing to do
            }

            Boolean journeyJustSet =
                String.isNotBlank(o.Customer_Journey__c) &&
                o.Customer_Journey__c != oldOpp.Customer_Journey__c;

            if (journeyJustSet) {
                // Same transaction, no extra DML. Trigger.new in afterUpdate
                // will already read FALSE, so this very save is gated open.
                o.isFirstUpdate__c = false;
            }
        }
    }

    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {

        List<Opportunity> eligible = new List<Opportunity>();

        for (Opportunity o : newList) {

            // 1. Gate still sealed — Opportunity created but no journey chosen.
            //    This is the case for every update LeadConversionProcess fires.
            if (o.isFirstUpdate__c == true) {
                continue;
            }

            // 2. Already handled earlier in this transaction (guards against
            //    re-entry if the gated logic issues DML back on Opportunity).
            if (processedIds.contains(o.Id)) {
                continue;
            }

            eligible.add(o);
        }

        if (eligible.isEmpty()) {
            return;
        }

        for (Opportunity o : eligible) {
            processedIds.add(o.Id);
        }

        applyGatedFieldUpdates(eligible, oldMap);
    }

    /* =========================================================================
     *  Everything below only ever sees Opportunities whose gate is open.
     *  Replace the body with your actual field-update logic — the important
     *  part is that it is bulk-safe and issues at most one DML per object.
     * ========================================================================= */
    private static void applyGatedFieldUpdates(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity o : opps) {
            Opportunity oldOpp = oldMap.get(o.Id);

            // ---- EXAMPLE: react only when the journey actually moved ----
            Boolean journeyChanged = (o.Customer_Journey__c != oldOpp.Customer_Journey__c);
            if (!journeyChanged) {
                continue;
            }

            Opportunity upd = new Opportunity(Id = o.Id);
            // upd.Some_Field__c = ...;
            oppsToUpdate.add(upd);
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;   // processedIds already blocks the re-entry
        }
    }

    /* =========================================================================
     *  Reusable gate check for other Apex / invocable code that needs the same
     *  rule without duplicating it.
     * ========================================================================= */
    public static Boolean isGateOpen(Opportunity o) {
        return o != null && o.isFirstUpdate__c == false;
    }

    @TestVisible
    private static void resetGuard() {
        processedIds.clear();
    }
}