global class LeadEscalation24Batch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('===== Batch Started =====');

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Status,
                   OwnerId,
                   Department_Name__c,
                   Prospect_Stage_Entry_Date__c,
                   Escalation_24_Sent__c
            FROM Lead
            WHERE Status = 'Prospect'
            AND Prospect_Stage_Entry_Date__c != NULL
            AND Escalation_24_Sent__c = FALSE
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Lead> scope) {

        System.debug('===== Execute Started =====');
        System.debug('Total Leads In Scope: ' + scope.size());

        List<Lead> leadsToUpdate = new List<Lead>();

        for(Lead ld : scope) {

            System.debug('--------------------------------');
            System.debug('Processing Lead: ' + ld.Name);
            System.debug('Lead Id: ' + ld.Id);
            System.debug('Department: ' + ld.Department_Name__c);
            System.debug('Prospect Entry Date: ' + ld.Prospect_Stage_Entry_Date__c);

            Long hoursDiff =
                (System.now().getTime() -
                 ld.Prospect_Stage_Entry_Date__c.getTime())
                 /(1000*60*60);

            System.debug('Hours Difference: ' + hoursDiff);

            if(hoursDiff >= 24) {

                System.debug('24 Hour Escalation Triggered');

                sendEscalationEmail(ld);

                ld.Escalation_24_Sent__c = true;
                leadsToUpdate.add(ld);

                System.debug('Escalation_24_Sent__c marked TRUE');
            }
            else {

                System.debug('Lead has not completed 24 Hours');
            }
        }

        if(!leadsToUpdate.isEmpty()) {

            System.debug('Updating Leads Count: ' + leadsToUpdate.size());

            update leadsToUpdate;

            System.debug('Lead Update Completed');
        }
        else {

            System.debug('No Leads To Update');
        }
    }

    global void finish(Database.BatchableContext bc) {

        System.debug('===== Batch Finished =====');
    }

    private static void sendEscalationEmail(Lead ld) {

        System.debug('===== Email Method Started =====');

        List<String> recipientEmails = new List<String>();
        
        
        recipientEmails.add('ramyasri.a@coservesolutions.com');
System.debug('Test Email Added');

        // Lead Owner
        User ownerUser = [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :ld.OwnerId
            LIMIT 1
        ];

        System.debug('Lead Owner Name: ' + ownerUser.Name);
        System.debug('Lead Owner Email: ' + ownerUser.Email);

        if(ownerUser.Email != null) {

            recipientEmails.add(ownerUser.Email);

            System.debug('Owner Email Added');
        }

        // Department CRM Users
        String roleName = ld.Department_Name__c + ' CRM User';

        System.debug('Department Name: ' + ld.Department_Name__c);
        System.debug('Generated Role Name: ' + roleName);

        List<User> crmUsers = [
            SELECT Id, Name, Email
            FROM User
            WHERE UserRole.Name = :roleName
            AND IsActive = true
        ];

        System.debug('CRM Users Found: ' + crmUsers.size());

        for(User u : crmUsers) {

            System.debug(
                'CRM User -> Name: ' + u.Name +
                ', Email: ' + u.Email
            );

            if(u.Email != null) {

                recipientEmails.add(u.Email);

                System.debug('CRM User Email Added');
            }
        }

        System.debug('Final Recipient Count: ' + recipientEmails.size());
        System.debug('Final Recipient List: ' + recipientEmails);

        if(recipientEmails.isEmpty()) {

            System.debug('No Recipients Found. Email Not Sent.');
            return;
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(recipientEmails);

        mail.setSubject(
            'Lead Escalation - Prospect Stage More Than 24 Hours'
        );

        mail.setPlainTextBody(
            'Lead Name: ' + ld.Name +
            '\nDepartment: ' + ld.Department_Name__c +
            '\n\nThis Lead has remained in Prospect stage for more than 24 hours.'
        );

        System.debug('Sending Email Now...');

       Messaging.SendEmailResult[] results =
Messaging.sendEmail(
new Messaging.SingleEmailMessage[] { mail }
);

for(Messaging.SendEmailResult r : results){

if(r.isSuccess()){
    System.debug('Email Sent Successfully');
}
else{
    for(Messaging.SendEmailError err : r.getErrors()){
        System.debug('Email Error: ' + err.getMessage());
    }
}

}

System.debug('===== Email Method Finished =====');
    }
}