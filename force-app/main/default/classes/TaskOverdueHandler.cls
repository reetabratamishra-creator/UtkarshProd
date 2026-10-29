public class TaskOverdueHandler {

    public static void handleOverdueTasks(
        List<Task> newTasks,
        Map<Id, Task> oldMap
    ) {
        System.debug('===== TaskOverdueHandler START =====');

        Date today = Date.today();

        Set<Id> overdueOppIds  = new Set<Id>();
        Set<Id> overdueLeadIds = new Set<Id>();

        for (Task t : newTasks) {

            Boolean isOverdueNow = (
                t.Status != 'Completed'
                && t.ActivityDate != null
                && t.ActivityDate < today
            );

            if (!isOverdueNow) {
                System.debug('Task not overdue, skipping: ' + t.Subject);
                continue;
            }

            if (oldMap != null) {
                Task old = oldMap.get(t.Id);
                Boolean wasAlreadyOverdue = (
                    old.ActivityDate != null
                    && old.ActivityDate < today
                    && old.Status != 'Completed'
                );
                if (wasAlreadyOverdue) {
                    System.debug('Task was already overdue before, skipping: ' + t.Subject);
                    continue;
                }
            }

            System.debug('Newly overdue task found: ' + t.Subject);

            if (t.WhatId != null) {
                String prefix = String.valueOf(t.WhatId).substring(0, 3);
                if (prefix == '006') overdueOppIds.add(t.WhatId);
            }
            if (t.WhoId != null) {
                String prefix = String.valueOf(t.WhoId).substring(0, 3);
                if (prefix == '00Q') overdueLeadIds.add(t.WhoId);
            }
        }

        if (overdueOppIds.isEmpty() && overdueLeadIds.isEmpty()) {
            System.debug('No newly overdue tasks linked to Opp or Lead. Exiting.');
            return;
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        if (!overdueOppIds.isEmpty()) {
            for (Opportunity o : [
                SELECT Id, OwnerId, Department_Name__c,
                       FirstOverdueTaskDate__c,
                       OppOverdueEsc36Sent__c,
                       OppOverdueEsc96Sent__c
                FROM Opportunity
                WHERE Id IN :overdueOppIds
            ]) {
                oppMap.put(o.Id, o);
            }
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!overdueLeadIds.isEmpty()) {
            for (Lead l : [
                SELECT Id, OwnerId, Department_Name__c,
                       FirstOverdueTaskDate__c,
                       LeadOverdueEsc36Sent__c,
                       LeadOverdueEsc96Sent__c
                FROM Lead
                WHERE Id IN :overdueLeadIds
            ]) {
                leadMap.put(l.Id, l);
            }
        }

        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity o : oppMap.values()) ownerIds.add(o.OwnerId);
        for (Lead l      : leadMap.values())  ownerIds.add(l.OwnerId);

        Map<Id, String> ownerEmailMap = new Map<Id, String>();
        for (User u : [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = TRUE
            AND Email != NULL
        ]) {
            ownerEmailMap.put(u.Id, u.Email);
            System.debug('Owner email fetched: ' + u.Email);
        }

        List<Messaging.SingleEmailMessage> emails        = new List<Messaging.SingleEmailMessage>();
        List<Opportunity>                  oppsToUpdate  = new List<Opportunity>();
        List<Lead>                         leadsToUpdate = new List<Lead>();

        for (Task t : newTasks) {

            Boolean isOverdueNow = (
                t.Status != 'Completed'
                && t.ActivityDate != null
                && t.ActivityDate < today
            );
            if (!isOverdueNow) continue;

            Id     ownerId    = null;

            if (t.WhatId != null && oppMap.containsKey(t.WhatId)) {
                Opportunity o = oppMap.get(t.WhatId);
                ownerId = o.OwnerId;

                if (o.FirstOverdueTaskDate__c == null) {
                    o.FirstOverdueTaskDate__c  = Datetime.now();
                    o.OppOverdueEsc36Sent__c   = false;
                    o.OppOverdueEsc96Sent__c   = false;
                    oppsToUpdate.add(o);
                    System.debug('Stamped FirstOverdueTaskDate on Opp: ' + o.Id);
                }

            } else if (t.WhoId != null && leadMap.containsKey(t.WhoId)) {
                Lead l = leadMap.get(t.WhoId);
                ownerId = l.OwnerId;

                if (l.FirstOverdueTaskDate__c == null) {
                    l.FirstOverdueTaskDate__c   = Datetime.now();
                    l.LeadOverdueEsc36Sent__c   = false;
                    l.LeadOverdueEsc96Sent__c   = false;
                    leadsToUpdate.add(l);
                    System.debug('Stamped FirstOverdueTaskDate on Lead: ' + l.Id);
                }
            }

            if (ownerId != null && ownerEmailMap.containsKey(ownerId)) {
                String ownerEmail = ownerEmailMap.get(ownerId);

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ ownerEmail });
                mail.setSaveAsActivity(false);
                mail.setSubject('Overdue Task Alert - ' + t.Subject);

                String body =
                    'Dear Team,\n\n' +
                    'The following task is now overdue.\n\n' +
                    'Task Subject : ' + t.Subject + '\n' +
                    'Due Date     : ' + t.ActivityDate + '\n' +
                    'Status       : ' + t.Status + '\n\n' +
                    'Please action this task immediately.\n\n' +
                    'This is an automated overdue task alert.';

                mail.setPlainTextBody(body);
                emails.add(mail);
                System.debug('Queued immediate email to owner: ' + ownerEmail);
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
                System.debug('Sent ' + emails.size() + ' immediate overdue alert(s).');
            } catch (Exception ex) {
                String message = ex.getMessage() == null ? '' : ex.getMessage().toUpperCase();
                if (
                    message.contains('SINGLE_EMAIL_LIMIT_EXCEEDED') ||
                    message.contains('EMAIL LIMIT EXCEEDED')
                ) {
                    System.debug(
                        LoggingLevel.WARN,
                        'Task overdue immediate email skipped due to email limit: ' +
                        ex.getMessage()
                    );
                } else {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Task overdue immediate email failed: ' +
                        ex.getMessage() +
                        '\nStack Trace: ' +
                        ex.getStackTraceString()
                    );
                }
            }
        }

        try {
            if (!oppsToUpdate.isEmpty()) {
                Database.update(oppsToUpdate, false);
            }
            if (!leadsToUpdate.isEmpty()) {
                Database.update(leadsToUpdate, false);
            }
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'Task overdue stamp update failed: ' +
                ex.getMessage() +
                '\nStack Trace: ' +
                ex.getStackTraceString()
            );
        }

        System.debug('===== TaskOverdueHandler END =====');
    }
}