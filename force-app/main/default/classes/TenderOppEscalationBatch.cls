global class TenderOppEscalationBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('===== TenderOppEscalationBatch START =====');

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   OwnerId,
                   StageName,
                   Department_Name__c,
                   LastModifiedDate,
                   RecordType.DeveloperName,
                   TenderEsc15Sent__c,
                   TenderEsc21Sent__c,
                   TenderEsc30Sent__c
            FROM   Opportunity
            WHERE  RecordType.DeveloperName = 'Tender_Opportunity'
            AND    StageName IN ('Nurture', 'Negotiation')
            AND    (
                       TenderEsc15Sent__c = FALSE
                    OR TenderEsc21Sent__c = FALSE
                    OR TenderEsc30Sent__c = FALSE
                   )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {

        System.debug('===== TenderOppEscalationBatch EXECUTE =====');
        System.debug('Batch scope size: ' + scope.size());

        // 1. Collect unique department names and owner Ids
        Set<String> deptNames = new Set<String>();
        Set<Id>     ownerIds  = new Set<Id>();

        for (Opportunity opp : scope) {
            if (opp.Department_Name__c != null) {
                deptNames.add(opp.Department_Name__c);
            }
            ownerIds.add(opp.OwnerId);
        }

        System.debug('Unique Departments: ' + deptNames);
        System.debug('Unique Owner Ids: ' + ownerIds);

        // 2. Build role-name to emails map (single SOQL)
        Set<String> roleNamesNeeded = new Set<String>();
        for (String dept : deptNames) {
            roleNamesNeeded.add(dept + ' CRM User');
            roleNamesNeeded.add(dept + ' HOD');
        }
        roleNamesNeeded.add('Utkarsh CRM Head');
        roleNamesNeeded.add('Utkarsh ED');

        System.debug('Role names to query: ' + roleNamesNeeded);

        Map<String, List<String>> roleEmailMap = new Map<String, List<String>>();

        for (User u : [
            SELECT Id, Email, UserRole.Name
            FROM   User
            WHERE  UserRole.Name IN :roleNamesNeeded
            AND    IsActive = TRUE
            AND    Email != NULL
        ]) {
            String rn = u.UserRole.Name;
            if (!roleEmailMap.containsKey(rn)) {
                roleEmailMap.put(rn, new List<String>());
            }
            roleEmailMap.get(rn).add(u.Email);
            System.debug('Role [' + rn + '] added email: ' + u.Email);
        }

        // 3. Fetch opportunity owners in bulk
        Map<Id, String> ownerEmailMap = new Map<Id, String>();

        for (User u : [
            SELECT Id, Email
            FROM   User
            WHERE  Id IN :ownerIds
            AND    IsActive = TRUE
            AND    Email != NULL
        ]) {
            ownerEmailMap.put(u.Id, u.Email);
            System.debug('Owner [' + u.Id + '] email: ' + u.Email);
        }

        // 4. Build email list and escalation tracker
        List<Messaging.SingleEmailMessage> pendingEmails      = new List<Messaging.SingleEmailMessage>();
        List<PendingEscalation>            pendingEscalations = new List<PendingEscalation>();

        Date today = Date.today();

        for (Opportunity opp : scope) {

            System.debug('--- Processing Opp: ' + opp.Name + ' | Dept: ' + opp.Department_Name__c + ' | Stage: ' + opp.StageName);

            Date lastModDate       = opp.LastModifiedDate.date();
            Long daysSinceModified = lastModDate.daysBetween(today);

            System.debug('LastModifiedDate: ' + lastModDate + ' | Days Since Modified: ' + daysSinceModified);
            System.debug('15Sent=' + opp.TenderEsc15Sent__c + ' | 21Sent=' + opp.TenderEsc21Sent__c + ' | 30Sent=' + opp.TenderEsc30Sent__c);

            if (daysSinceModified >= 15 && !opp.TenderEsc15Sent__c) {
                System.debug('Queuing 15-day escalation for: ' + opp.Name);
                buildAndQueueEmail(opp, 15, daysSinceModified, ownerEmailMap, roleEmailMap, pendingEmails, pendingEscalations);
            }

            if (daysSinceModified >= 21 && !opp.TenderEsc21Sent__c) {
                System.debug('Queuing 21-day escalation for: ' + opp.Name);
                buildAndQueueEmail(opp, 21, daysSinceModified, ownerEmailMap, roleEmailMap, pendingEmails, pendingEscalations);
            }

            if (daysSinceModified >= 30 && !opp.TenderEsc30Sent__c) {
                System.debug('Queuing 30-day escalation for: ' + opp.Name);
                buildAndQueueEmail(opp, 30, daysSinceModified, ownerEmailMap, roleEmailMap, pendingEmails, pendingEscalations);
            }
        }

        // 5. Send emails in bulk
        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();

        if (!pendingEmails.isEmpty()) {

            System.debug('Sending ' + pendingEmails.size() + ' email(s) in bulk...');

            Messaging.SendEmailResult[] results = Messaging.sendEmail(pendingEmails);

            for (Integer i = 0; i < results.size(); i++) {

                PendingEscalation pe = pendingEscalations[i];

                if (results[i].isSuccess()) {

                    System.debug('Email sent OK | Opp: ' + pe.opp.Name + ' | Tier: ' + pe.tier);

                    Opportunity oppRec = oppsToUpdate.containsKey(pe.opp.Id)
                        ? oppsToUpdate.get(pe.opp.Id)
                        : new Opportunity(Id = pe.opp.Id);

                    if      (pe.tier == 15) { oppRec.TenderEsc15Sent__c = true; }
                    else if (pe.tier == 21) { oppRec.TenderEsc21Sent__c = true; }
                    else if (pe.tier == 30) { oppRec.TenderEsc30Sent__c = true; }

                    oppsToUpdate.put(pe.opp.Id, oppRec);

                } else {
                    for (Messaging.SendEmailError err : results[i].getErrors()) {
                        System.debug('Email FAILED | Opp: ' + pe.opp.Name + ' | Tier: ' + pe.tier + ' | Error: ' + err.getMessage());
                    }
                }
            }

        } else {
            System.debug('No emails to send this run.');
        }

        // 6. Bulk DML update
        if (!oppsToUpdate.isEmpty()) {
            System.debug('Updating ' + oppsToUpdate.size() + ' Opportunity record(s)...');
            update oppsToUpdate.values();
        } else {
            System.debug('No Opportunity records to update.');
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('===== TenderOppEscalationBatch FINISH =====');
    }

    private static void buildAndQueueEmail(
        Opportunity                         opp,
        Integer                             tier,
        Long                                daysSinceModified,
        Map<Id, String>                     ownerEmailMap,
        Map<String, List<String>>           roleEmailMap,
        List<Messaging.SingleEmailMessage>  pendingEmails,
        List<PendingEscalation>             pendingEscalations
    ) {
        List<String> recipients = new List<String>();
        String       dept       = opp.Department_Name__c;

        if (tier == 15) {
            if (ownerEmailMap.containsKey(opp.OwnerId)) {
                recipients.add(ownerEmailMap.get(opp.OwnerId));
            }
            addFromRoleMap(dept + ' CRM User', roleEmailMap, recipients);

        } else if (tier == 21) {
            addFromRoleMap(dept + ' HOD', roleEmailMap, recipients);
            addFromRoleMap('Utkarsh CRM Head', roleEmailMap, recipients);

        } else if (tier == 30) {
            addFromRoleMap('Utkarsh ED', roleEmailMap, recipients);
        }

        System.debug('Tier ' + tier + ' recipients for [' + opp.Name + ']: ' + recipients);

        if (recipients.isEmpty()) {
            System.debug('No recipients found for Tier ' + tier + ' | Opp: ' + opp.Name + '. Skipping.');
            return;
        }

        Set<String>  uniqueRecipients = new Set<String>(recipients);
        List<String> finalRecipients  = new List<String>(uniqueRecipients);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(finalRecipients);
        mail.setSaveAsActivity(false);

        mail.setSubject('Tender Opportunity Escalation - ' + tier + ' Days No Activity - ' + opp.Name);

        String body =
            'Dear Team,\n\n' +
            'The following Tender Opportunity has had no activity for ' + daysSinceModified + ' days.\n\n' +
            'Opportunity Name     : ' + opp.Name + '\n' +
            'Department           : ' + (dept != null ? dept : 'N/A') + '\n' +
            'Stage                : ' + opp.StageName + '\n' +
            'Days Since Modified  : ' + daysSinceModified + '\n\n' +
            'Please take immediate action.\n\n' +
            'This is an automated escalation email (Tier ' + tier + ' - ' + tier + '+ days threshold).';

        mail.setPlainTextBody(body);

        pendingEmails.add(mail);
        pendingEscalations.add(new PendingEscalation(opp, tier));
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
            System.debug('No active users found for role: ' + roleName);
        }
    }

    private class PendingEscalation {
        Opportunity opp;
        Integer     tier;

        PendingEscalation(Opportunity opp, Integer tier) {
            this.opp  = opp;
            this.tier = tier;
        }
    }
}