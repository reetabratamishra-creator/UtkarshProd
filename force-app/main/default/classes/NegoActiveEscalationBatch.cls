global class NegoActiveEscalationBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('===== Negotiation Active Batch Started =====');

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   StageName,
                   OwnerId,
                   Department_Name__c,
                   CreatedDate,
                   EscalationNeg7Sent__c,
                   EscalationNeg14Sent__c,
                   EscalationNeg21Sent__c
            FROM Opportunity
            WHERE StageName = 'Negotiation'
            AND (
                EscalationNeg7Sent__c = FALSE
                OR EscalationNeg14Sent__c = FALSE
                OR EscalationNeg21Sent__c = FALSE
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {

        System.debug('===== Execute Started =====');
        System.debug('Total Opportunities In Scope: ' + scope.size());

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : scope) {
            oppIds.add(opp.Id);
        }

  
        Map<Id, Date> lastActivityByOppId = new Map<Id, Date>();

        Set<Id> overdueOpenTaskOppIds = new Set<Id>();

        for (Task t : [
            SELECT Id, WhatId, ActivityDate, Status
            FROM Task
            WHERE WhatId IN :oppIds
            AND ActivityDate != NULL
        ]) {
            if (!lastActivityByOppId.containsKey(t.WhatId)
                || t.ActivityDate > lastActivityByOppId.get(t.WhatId)) {
                lastActivityByOppId.put(t.WhatId, t.ActivityDate);
            }

            if (t.Status != 'Completed' && t.ActivityDate < Date.today()) {
                overdueOpenTaskOppIds.add(t.WhatId);
            }
        }

        for (Event e : [
            SELECT Id, WhatId, ActivityDate
            FROM Event
            WHERE WhatId IN :oppIds
            AND ActivityDate != NULL
        ]) {
            if (!lastActivityByOppId.containsKey(e.WhatId)
                || e.ActivityDate > lastActivityByOppId.get(e.WhatId)) {
                lastActivityByOppId.put(e.WhatId, e.ActivityDate);
            }
        }

   
        List<Messaging.SingleEmailMessage> pendingEmails = new List<Messaging.SingleEmailMessage>();
        List<PendingEscalation> pendingEscalations = new List<PendingEscalation>();

        for (Opportunity opp : scope) {

            System.debug('--------------------------------');
            System.debug('Processing Opportunity: ' + opp.Name);

            Date lastActivityDate = lastActivityByOppId.containsKey(opp.Id)
                ? lastActivityByOppId.get(opp.Id)
                : opp.CreatedDate.date();

            Boolean hasOverdueTask = overdueOpenTaskOppIds.contains(opp.Id);

            Long daysSinceActivity = lastActivityDate.daysBetween(Date.today());

            System.debug('Last Activity Date: ' + lastActivityDate);
            System.debug('Days Since Activity: ' + daysSinceActivity);
            System.debug('Has Overdue Open Task: ' + hasOverdueTask);

            if (daysSinceActivity >= 7 && !opp.EscalationNeg7Sent__c) {
                System.debug('7 Day No-Activity Escalation Queued');
                queueEscalationEmail(
                    opp, 7, hasOverdueTask, daysSinceActivity,
                    pendingEmails, pendingEscalations
                );
            }

            if (daysSinceActivity >= 14 && !opp.EscalationNeg14Sent__c) {
                System.debug('14 Day No-Activity Escalation Queued');
                queueEscalationEmail(
                    opp, 14, hasOverdueTask, daysSinceActivity,
                    pendingEmails, pendingEscalations
                );
            }

            if (daysSinceActivity >= 21 && !opp.EscalationNeg21Sent__c) {
                System.debug('21 Day No-Activity Escalation Queued');
                queueEscalationEmail(
                    opp, 21, hasOverdueTask, daysSinceActivity,
                    pendingEmails, pendingEscalations
                );
            }
        }

        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();

        if (!pendingEmails.isEmpty()) {

            System.debug('Sending Bulk Email Batch. Total Messages: ' + pendingEmails.size());

            Messaging.SendEmailResult[] results = Messaging.sendEmail(pendingEmails);

            for (Integer i = 0; i < results.size(); i++) {

                PendingEscalation pe = pendingEscalations[i];

                if (results[i].isSuccess()) {
                    System.debug(
                        'Email Sent Successfully - Opp: ' + pe.opp.Name +
                        ' Tier: ' + pe.tier
                    );

                    Opportunity oppToUpdate = oppsToUpdate.containsKey(pe.opp.Id)
                        ? oppsToUpdate.get(pe.opp.Id)
                        : pe.opp;

                    if (pe.tier == 7) {
                        oppToUpdate.EscalationNeg7Sent__c = true;
                    } else if (pe.tier == 14) {
                        oppToUpdate.EscalationNeg14Sent__c = true;
                    } else if (pe.tier == 21) {
                        oppToUpdate.EscalationNeg21Sent__c = true;
                    }

                    oppsToUpdate.put(pe.opp.Id, oppToUpdate);

                } else {
                    for (Messaging.SendEmailError err : results[i].getErrors()) {
                        System.debug(
                            'Email Error - Opp: ' + pe.opp.Name +
                            ' Tier: ' + pe.tier + ' - ' + err.getMessage()
                        );
                    }
                }
            }
        } else {
            System.debug('No Emails To Send This Run');
        }

        if (!oppsToUpdate.isEmpty()) {
            System.debug('Updating Opportunities Count: ' + oppsToUpdate.size());
            update oppsToUpdate.values();
        } else {
            System.debug('No Opportunities To Update');
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('===== Negotiation Active Batch Finished =====');
    }

   
    private static void queueEscalationEmail(
        Opportunity opp,
        Integer tier,
        Boolean hasOverdueTask,
        Long daysSinceActivity,
        List<Messaging.SingleEmailMessage> pendingEmails,
        List<PendingEscalation> pendingEscalations
    ) {

        List<String> recipientEmails = new List<String>();

        if (tier == 7) {

            User ownerUser = [
                SELECT Id, Name, Email
                FROM User
                WHERE Id = :opp.OwnerId
                LIMIT 1
            ];

            if (ownerUser.Email != null) {
                recipientEmails.add(ownerUser.Email);
            }

            String roleName = opp.Department_Name__c + ' CRM User';
            addUsersByRole(roleName, recipientEmails);

        } else if (tier == 14) {

            String deptHodRole = opp.Department_Name__c + ' HOD';
            addUsersByRole(deptHodRole, recipientEmails);
            addUsersByRole('Utkarsh CRM Head', recipientEmails);

        } else if (tier == 21) {

            addUsersByRole('Utkarsh ED', recipientEmails);
        }

        System.debug('Tier ' + tier + ' Recipient List For ' + opp.Name + ': ' + recipientEmails);

        if (recipientEmails.isEmpty()) {
            System.debug('No Recipients Found For Tier ' + tier + '. Email Not Queued. Will retry next run.');
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(recipientEmails);

        mail.setSubject(
            'Negotiation Stage Escalation (No Activity) - ' + tier + ' Days - ' + opp.Name
        );

        String body =
            'Opportunity Name: ' + opp.Name +
            '\nDepartment: ' + opp.Department_Name__c +
            '\nDays Since Last Activity: ' + daysSinceActivity +
            '\n\nThis Opportunity has had no Task/Event activity logged for ' +
            tier + ' or more days while in Negotiation stage.';

        if (hasOverdueTask) {
            body += '\n\nNote: There is also an open Task on this Opportunity whose due date has already passed.';
        }

        mail.setPlainTextBody(body);

        pendingEmails.add(mail);
        pendingEscalations.add(new PendingEscalation(opp, tier));
    }

    private static void addUsersByRole(String roleName, List<String> recipientEmails) {

        List<User> roleUsers = [
            SELECT Id, Name, Email
            FROM User
            WHERE UserRole.Name = :roleName
            AND IsActive = true
        ];

        System.debug('Role "' + roleName + '" Users Found: ' + roleUsers.size());

        for (User u : roleUsers) {
            if (u.Email != null) {
                recipientEmails.add(u.Email);
            }
        }
    }


    private class PendingEscalation {
        Opportunity opp;
        Integer tier;

        PendingEscalation(Opportunity opp, Integer tier) {
            this.opp = opp;
            this.tier = tier;
        }
    }
}