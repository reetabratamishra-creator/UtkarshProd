global class OverdueTaskEscalationBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('===== OverdueTaskEscalationBatch START =====');

        return Database.getQueryLocator([
            SELECT Id,
                   Subject,
                   Status,
                   ActivityDate,
                   WhatId,
                   WhoId
            FROM Task
            WHERE Status != 'Completed'
            AND ActivityDate != NULL
            AND ActivityDate < TODAY
            AND (
                WhatId != NULL
                OR WhoId != NULL
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Task> scope) {

        System.debug('===== OverdueTaskEscalationBatch EXECUTE =====');
        System.debug('Total overdue tasks in scope: ' + scope.size());

        Set<Id> oppIds  = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();

        for (Task t : scope) {
            if (t.WhatId != null) {
                String prefix = String.valueOf(t.WhatId).substring(0, 3);
                if (prefix == '006') oppIds.add(t.WhatId);
            }
            if (t.WhoId != null) {
                String prefix = String.valueOf(t.WhoId).substring(0, 3);
                if (prefix == '00Q') leadIds.add(t.WhoId);
            }
        }

        System.debug('Opp Ids found: ' + oppIds.size());
        System.debug('Lead Ids found: ' + leadIds.size());

        // Fetch Opps
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        if (!oppIds.isEmpty()) {
            for (Opportunity o : [
                SELECT Id, Name, OwnerId, Department_Name__c,
                       FirstOverdueTaskDate__c,
                       OppOverdueEsc36Sent__c,
                       OppOverdueEsc96Sent__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ]) {
                oppMap.put(o.Id, o);
            }
        }

        // Fetch Leads
        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            for (Lead l : [
                SELECT Id, Name, OwnerId, Department_Name__c,
                       FirstOverdueTaskDate__c,
                       LeadOverdueEsc36Sent__c,
                       LeadOverdueEsc96Sent__c
                FROM Lead
                WHERE Id IN :leadIds
            ]) {
                leadMap.put(l.Id, l);
            }
        }

        // Collect depts and owner Ids
        Set<String> deptNames = new Set<String>();
        Set<Id>     ownerIds  = new Set<Id>();

        for (Opportunity o : oppMap.values()) {
            ownerIds.add(o.OwnerId);
            if (o.Department_Name__c != null) deptNames.add(o.Department_Name__c);
        }
        for (Lead l : leadMap.values()) {
            ownerIds.add(l.OwnerId);
            if (l.Department_Name__c != null) deptNames.add(l.Department_Name__c);
        }

        // Build role names
        Set<String> roleNamesNeeded = new Set<String>();
        for (String dept : deptNames) {
            roleNamesNeeded.add(dept + ' HOD');
        }
        roleNamesNeeded.add('Utkarsh CRM Head');
        roleNamesNeeded.add('Utkarsh ED');

        System.debug('Roles needed: ' + roleNamesNeeded);

        // Single SOQL - role emails
        Map<String, List<String>> roleEmailMap = new Map<String, List<String>>();
        for (User u : [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE UserRole.Name IN :roleNamesNeeded
            AND IsActive = TRUE
            AND Email != NULL
        ]) {
            String rn = u.UserRole.Name;
            if (!roleEmailMap.containsKey(rn)) roleEmailMap.put(rn, new List<String>());
            roleEmailMap.get(rn).add(u.Email);
            System.debug('Role [' + rn + '] email: ' + u.Email);
        }

        // Single SOQL - owner emails
        Map<Id, String> ownerEmailMap = new Map<Id, String>();
        for (User u : [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = TRUE
            AND Email != NULL
        ]) {
            ownerEmailMap.put(u.Id, u.Email);
        }

        List<Messaging.SingleEmailMessage> pendingEmails = new List<Messaging.SingleEmailMessage>();
        Map<Id, Opportunity>               oppsToUpdate  = new Map<Id, Opportunity>();
        Map<Id, Lead>                      leadsToUpdate = new Map<Id, Lead>();

        Datetime now = Datetime.now();

        for (Task t : scope) {

            System.debug('--- Processing Task: ' + t.Subject + ' | Due: ' + t.ActivityDate);

            Boolean  isOpp           = false;
            Boolean  isLead          = false;
            Id       ownerId         = null;
            String   dept            = null;
            String   parentName      = null;
            Boolean  esc36Sent       = false;
            Boolean  esc96Sent       = false;
            Datetime firstOverdueDate = null;
            Id       parentId        = null;

            if (t.WhatId != null && oppMap.containsKey(t.WhatId)) {
                Opportunity o    = oppMap.get(t.WhatId);
                isOpp            = true;
                parentId         = o.Id;
                ownerId          = o.OwnerId;
                dept             = o.Department_Name__c;
                parentName       = o.Name;
                esc36Sent        = o.OppOverdueEsc36Sent__c;
                esc96Sent        = o.OppOverdueEsc96Sent__c;
                firstOverdueDate = o.FirstOverdueTaskDate__c;

            } else if (t.WhoId != null && leadMap.containsKey(t.WhoId)) {
                Lead l           = leadMap.get(t.WhoId);
                isLead           = true;
                parentId         = l.Id;
                ownerId          = l.OwnerId;
                dept             = l.Department_Name__c;
                parentName       = l.Name;
                esc36Sent        = l.LeadOverdueEsc36Sent__c;
                esc96Sent        = l.LeadOverdueEsc96Sent__c;
                firstOverdueDate = l.FirstOverdueTaskDate__c;

            } else {
                System.debug('Task not linked to Opp or Lead. Skipping.');
                continue;
            }

            Datetime overdueFrom = (firstOverdueDate != null)
                ? firstOverdueDate
                : Datetime.newInstance(
                    t.ActivityDate,
                    Time.newInstance(23, 59, 59, 0)
                );

            Long hoursOverdue = (now.getTime() - overdueFrom.getTime()) / 3600000;

            System.debug('Parent: ' + parentName + ' | Hours Overdue: ' + hoursOverdue + ' | 36Sent: ' + esc36Sent + ' | 96Sent: ' + esc96Sent);

            // Stamp FirstOverdueTaskDate if missing
            if (firstOverdueDate == null) {
                if (isOpp) {
                    Opportunity o = oppsToUpdate.containsKey(parentId)
                        ? oppsToUpdate.get(parentId)
                        : oppMap.get(parentId);
                    o.FirstOverdueTaskDate__c = overdueFrom;
                    oppsToUpdate.put(parentId, o);
                } else {
                    Lead l = leadsToUpdate.containsKey(parentId)
                        ? leadsToUpdate.get(parentId)
                        : leadMap.get(parentId);
                    l.FirstOverdueTaskDate__c = overdueFrom;
                    leadsToUpdate.put(parentId, l);
                }
            }

            // 1-hour - send to owner
            // Catches any tasks the trigger may have missed
            if (hoursOverdue >= 1 && !esc36Sent) {
                if (ownerId != null && ownerEmailMap.containsKey(ownerId)) {
                    String ownerEmail = ownerEmailMap.get(ownerId);
                    System.debug('Queuing 1hr owner alert for: ' + parentName);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{ ownerEmail });
                    mail.setSaveAsActivity(false);
                    mail.setSubject('Overdue Task Alert - ' + t.Subject);

                    String body =
                        'Dear Team,\n\n' +
                        'The following task is overdue and has not been actioned.\n\n' +
                        'Task Subject  : ' + t.Subject + '\n' +
                        'Linked To     : ' + parentName + '\n' +
                        'Due Date      : ' + t.ActivityDate + '\n' +
                        'Hours Overdue : ' + hoursOverdue + '\n\n' +
                        'Please take immediate action.\n\n' +
                        'This is an automated overdue task alert.';

                    mail.setPlainTextBody(body);
                    pendingEmails.add(mail);
                }
            }

            // 36-hour escalation - HOD
            if (hoursOverdue >= 36 && !esc36Sent) {

                System.debug('Queuing 36hr HOD escalation for: ' + parentName);

                List<String> recipients = new List<String>();
                if (dept != null) addFromRoleMap(dept + ' HOD', roleEmailMap, recipients);

                if (!recipients.isEmpty()) {
                    pendingEmails.add(buildEmail(
                        recipients,
                        '36hr Escalation - Overdue Task - ' + parentName,
                        t.Subject, parentName, hoursOverdue, 36
                    ));

                    if (isOpp) {
                        Opportunity o = oppsToUpdate.containsKey(parentId)
                            ? oppsToUpdate.get(parentId)
                            : oppMap.get(parentId);
                        o.OppOverdueEsc36Sent__c = true;
                        oppsToUpdate.put(parentId, o);
                    } else {
                        Lead l = leadsToUpdate.containsKey(parentId)
                            ? leadsToUpdate.get(parentId)
                            : leadMap.get(parentId);
                        l.LeadOverdueEsc36Sent__c = true;
                        leadsToUpdate.put(parentId, l);
                    }
                } else {
                    System.debug('No HOD found for dept: ' + dept);
                }
            }

            // 96-hour escalation - CRM Head + ED
            if (hoursOverdue >= 96 && !esc96Sent) {

                System.debug('Queuing 96hr CRM Head + ED escalation for: ' + parentName);

                List<String> recipients = new List<String>();
                addFromRoleMap('Utkarsh CRM Head', roleEmailMap, recipients);
                addFromRoleMap('Utkarsh ED',       roleEmailMap, recipients);

                if (!recipients.isEmpty()) {
                    pendingEmails.add(buildEmail(
                        recipients,
                        '96hr Senior Escalation - Overdue Task - ' + parentName,
                        t.Subject, parentName, hoursOverdue, 96
                    ));

                    if (isOpp) {
                        Opportunity o = oppsToUpdate.containsKey(parentId)
                            ? oppsToUpdate.get(parentId)
                            : oppMap.get(parentId);
                        o.OppOverdueEsc96Sent__c = true;
                        oppsToUpdate.put(parentId, o);
                    } else {
                        Lead l = leadsToUpdate.containsKey(parentId)
                            ? leadsToUpdate.get(parentId)
                            : leadMap.get(parentId);
                        l.LeadOverdueEsc96Sent__c = true;
                        leadsToUpdate.put(parentId, l);
                    }
                } else {
                    System.debug('No CRM Head/ED found.');
                }
            }
        }

        if (!pendingEmails.isEmpty()) {
            System.debug('Sending ' + pendingEmails.size() + ' email(s)...');
            Messaging.sendEmail(pendingEmails);
        } else {
            System.debug('No emails to send this run.');
        }

        if (!oppsToUpdate.isEmpty()) {
            System.debug('Updating ' + oppsToUpdate.size() + ' Opp(s)...');
            update oppsToUpdate.values();
        }
        if (!leadsToUpdate.isEmpty()) {
            System.debug('Updating ' + leadsToUpdate.size() + ' Lead(s)...');
            update leadsToUpdate.values();
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('===== OverdueTaskEscalationBatch FINISH =====');
    }

    private static Messaging.SingleEmailMessage buildEmail(
        List<String> recipients,
        String subject,
        String taskSubject,
        String parentName,
        Long hoursOverdue,
        Integer tier
    ) {
        Set<String>  unique = new Set<String>(recipients);
        List<String> finalR = new List<String>(unique);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(finalR);
        mail.setSaveAsActivity(false);
        mail.setSubject(subject);

        String body =
            'Dear Team,\n\n' +
            'The following overdue task requires escalation.\n\n' +
            'Task Subject  : ' + taskSubject + '\n' +
            'Linked To     : ' + parentName + '\n' +
            'Hours Overdue : ' + hoursOverdue + '\n\n' +
            'Please take immediate action.\n\n' +
            'Automated escalation alert (' + tier + 'hr threshold).';

        mail.setPlainTextBody(body);
        return mail;
    }

    private static void addFromRoleMap(
        String roleName,
        Map<String, List<String>> roleEmailMap,
        List<String> recipients
    ) {
        if (roleEmailMap.containsKey(roleName)) {
            recipients.addAll(roleEmailMap.get(roleName));
            System.debug('Added emails from role: ' + roleName);
        } else {
            System.debug('No users found for role: ' + roleName);
        }
    }
}