global class TaskDepartmentUpdateBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, WhoId, WhatId, Department__c
            FROM Task
            WHERE (WhoId != NULL
               OR WhatId != NULL)
               AND status != 'Completed'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Task> scope) {

        Set<Id> leadIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();

        for (Task t : scope) {

            if (t.WhoId != null &&
                t.WhoId.getSObjectType() == Lead.SObjectType) {
                leadIds.add(t.WhoId);
            }

            if (t.WhatId != null &&
                t.WhatId.getSObjectType() == Opportunity.SObjectType) {
                oppIds.add(t.WhatId);
            }
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>();

        if (!leadIds.isEmpty()) {
            leadMap = new Map<Id, Lead>([
                SELECT Id, Department_NameFormula__c
                FROM Lead
                WHERE Id IN :leadIds
            ]);
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();

        if (!oppIds.isEmpty()) {
            oppMap = new Map<Id, Opportunity>([
                SELECT Id, Department_NameFormula__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ]);
        }

        List<Task> tasksToUpdate = new List<Task>();

        for (Task t : scope) {

            String department;

            // Priority: Lead
            if (t.WhoId != null &&
                t.WhoId.getSObjectType() == Lead.SObjectType &&
                leadMap.containsKey(t.WhoId)) {

                department = leadMap.get(t.WhoId).Department_NameFormula__c;
            }
            // Else Opportunity
            else if (t.WhatId != null &&
                     t.WhatId.getSObjectType() == Opportunity.SObjectType &&
                     oppMap.containsKey(t.WhatId)) {

                department = oppMap.get(t.WhatId).Department_NameFormula__c;
            }

            if (department != null &&
                department != t.Department__c) {

                t.Department__c = department;
                tasksToUpdate.add(t);
            }
        }

        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Task Department Update Batch Completed.');
    }
}