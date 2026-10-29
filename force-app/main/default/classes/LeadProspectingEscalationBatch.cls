global class LeadProspectingEscalationBatch

implements Database.Batchable<SObject>{
 
    global Database.QueryLocator start(

        Database.BatchableContext bc

    ){
 
        System.debug('=== LeadProspectingEscalationBatch START ===');
 
        return Database.getQueryLocator([
 
            SELECT Id,

                   Name,

                   OwnerId,

                   Owner.Email,

                   Status,

                   Department_NameFormula__c,

                   Last_Prospecting_Activity__c,

                   Prospecting_Escalation_24_Sent__c,

                   Prospecting_Escalation_48_Sent__c,

                   Prospecting_Escalation_72_Sent__c
 
            FROM Lead
 
            WHERE Status = 'Prospecting'

            AND Last_Prospecting_Activity__c != NULL
 
        ]);

    }
 
    global void execute(

        Database.BatchableContext bc,

        List<Lead> scope

    ){
 
        System.debug('=== EXECUTE START ===');

        System.debug('Scope Size: ' + scope.size());
 
        Map<String,List<Lead>> dept24Map =

            new Map<String,List<Lead>>();
 
        Map<String,List<Lead>> dept48Map =

            new Map<String,List<Lead>>();
 
        List<Lead> leads72 =

            new List<Lead>();
 
        List<Lead> leadsToUpdate =

            new List<Lead>();
 
        Set<String> roleNames =

            new Set<String>();
 
        for(Lead ld : scope){
 
            String dept =

                LeadProspectingEscalationEmailService.getRoleDepartmentName(

                    ld.Department_NameFormula__c

                );
 
            Long hoursDiff =
 
                (System.now().getTime()

                 -

                 ld.Last_Prospecting_Activity__c.getTime())
 
                / (1000 * 60 * 60);
 
            System.debug(

                'Lead: ' + ld.Name +

                ' | Dept: ' + dept +

                ' | HoursDiff: ' + hoursDiff

            );
 
            Boolean changed = false;
 
            // 24 HOURS

            if(

                hoursDiff >= 24
&&

                !ld.Prospecting_Escalation_24_Sent__c

            ){
 
                System.debug(

                    '24 Hour Escalation Triggered for Lead: ' +

                    ld.Name

                );
 
                if(!dept24Map.containsKey(dept)){

                    dept24Map.put(

                        dept,

                        new List<Lead>()

                    );

                }
 
                dept24Map.get(dept).add(ld);
 
                roleNames.add(

                    dept + ' CRM User'

                );
 
                ld.Prospecting_Escalation_24_Sent__c = true;
 
                changed = true;

            }
 
            // 48 HOURS

            if(

                hoursDiff >= 48
&&

                !ld.Prospecting_Escalation_48_Sent__c

            ){
 
                System.debug(

                    '48 Hour Escalation Triggered for Lead: ' +

                    ld.Name

                );
 
                if(!dept48Map.containsKey(dept)){

                    dept48Map.put(

                        dept,

                        new List<Lead>()

                    );

                }
 
                dept48Map.get(dept).add(ld);
 
                roleNames.add(

                    dept + ' HOD'

                );
 
                ld.Prospecting_Escalation_48_Sent__c = true;
 
                changed = true;

            }
 
            // 72 HOURS

            if(

                hoursDiff >= 72
&&

                !ld.Prospecting_Escalation_72_Sent__c

            ){
 
                System.debug(

                    '72 Hour Escalation Triggered for Lead: ' +

                    ld.Name

                );
 
                leads72.add(ld);
 
                ld.Prospecting_Escalation_72_Sent__c = true;
 
                changed = true;

            }
 
            if(changed){

                leadsToUpdate.add(ld);

            }

        }
 
        System.debug('24 Hour Departments: ' + dept24Map.keySet());

        System.debug('48 Hour Departments: ' + dept48Map.keySet());

        System.debug('72 Hour Lead Count: ' + leads72.size());
 
        roleNames.add('Utkarsh CRM Head');

        roleNames.add('Utkarsh ED');
 
        System.debug('Role Names To Query: ' + roleNames);
 
        Map<String,Set<String>> roleEmails =

            new Map<String,Set<String>>();
 
        for(User usr : [
 
            SELECT Id,

                   Email,

                   UserRole.Name
 
            FROM User
 
            WHERE IsActive = true

            AND UserRole.Name IN :roleNames
 
        ]){
 
            System.debug(

                'User Found: ' +

                usr.Email +

                ' | Role: ' +

                usr.UserRole.Name

            );
 
            if(String.isBlank(usr.Email)){

                continue;

            }
 
            if(!roleEmails.containsKey(

                usr.UserRole.Name

            )){

                roleEmails.put(

                    usr.UserRole.Name,

                    new Set<String>()

                );

            }
 
            roleEmails.get(

                usr.UserRole.Name

            ).add(

                usr.Email

            );

        }
 
        System.debug('Role Email Map: ' + roleEmails);
 
        List<Messaging.SingleEmailMessage>

            emailMessages =

            new List<Messaging.SingleEmailMessage>();
 
        // 24 HOURS

        for(String dept : dept24Map.keySet()){
 
            // Set<String> recipients =

            //     new Set<String>();
 
                Set<String> recipients =
                    new Set<String>();

            for(Lead ld : dept24Map.get(dept)){
 
                if(ld.Owner.Email != null){

                    recipients.add(ld.Owner.Email);

                }

            }
 
            String crmRole =

                dept + ' CRM User';
 
            if(roleEmails.containsKey(crmRole)){

                recipients.addAll(

                    roleEmails.get(crmRole)

                );

            }
 
            System.debug(

                '24 Hour Email Recipients (' +

                dept +

                '): ' +

                recipients

            );
 
            Messaging.SingleEmailMessage mail =

                LeadProspectingEscalationEmailService.buildEmail(

                    dept24Map.get(dept),

                    recipients,

                    24,

                    dept

                );
 
            if(mail != null){

                emailMessages.add(mail);
 
                System.debug(

                    '24 Hour Email Added for Department: ' +

                    dept

                );

            }

        }
 
        // 48 HOURS

        for(String dept : dept48Map.keySet()){
 
            Set<String> recipients =

                new Set<String>();
 
            String hodRole =

                dept + ' HOD';
 
            if(roleEmails.containsKey(hodRole)){

                recipients.addAll(

                    roleEmails.get(hodRole)

                );

            }
 
            if(roleEmails.containsKey(

                'Utkarsh CRM Head'

            )){

                recipients.addAll(

                    roleEmails.get(

                        'Utkarsh CRM Head'

                    )

                );

            }
 
            System.debug(

                '48 Hour Email Recipients (' +

                dept +

                '): ' +

                recipients

            );
 
            Messaging.SingleEmailMessage mail =

                LeadProspectingEscalationEmailService.buildEmail(

                    dept48Map.get(dept),

                    recipients,

                    48,

                    dept

                );
 
            if(mail != null){

                emailMessages.add(mail);
 
                System.debug(

                    '48 Hour Email Added for Department: ' +

                    dept

                );

            }

        }
 
        // 72 HOURS

        if(!leads72.isEmpty()){
 
            Set<String> recipients =

                new Set<String>();
 
            if(roleEmails.containsKey('Utkarsh ED')){

                recipients.addAll(

                    roleEmails.get('Utkarsh ED')

                );

            }
 
            System.debug(

                '72 Hour Email Recipients: ' +

                recipients

            );
 
            Messaging.SingleEmailMessage mail =

                LeadProspectingEscalationEmailService.buildEmail(

                    leads72,

                    recipients,

                    72,

                    'All Departments'

                );
 
            if(mail != null){

                emailMessages.add(mail);
 
                System.debug(

                    '72 Hour Email Added'

                );

            }

        }
 
        System.debug(

            'Total Emails To Send: ' +

            emailMessages.size()

        );
 
        if(!emailMessages.isEmpty()){
 
            Messaging.sendEmail(emailMessages);
 
            System.debug(

                'Emails Sent Successfully'

            );

        }
 
        System.debug(

            'Leads To Update Count: ' +

            leadsToUpdate.size()

        );
 
        if(!leadsToUpdate.isEmpty()){
 
            Database.SaveResult[] results =

                Database.update(

                    leadsToUpdate,

                    false

                );
 
            for(Integer i = 0;

                i < results.size();

                i++){
 
                if(results[i].isSuccess()){
 
                    System.debug(

                        'Lead Updated: ' +

                        leadsToUpdate[i].Id

                    );
 
                }else{
 
                    for(Database.Error err :

                        results[i].getErrors()){
 
                        System.debug(

                            'Update Error for Lead ' +

                            leadsToUpdate[i].Id +

                            ': ' +

                            err.getMessage()

                        );

                    }

                }

            }

        }
 
        System.debug('=== EXECUTE END ===');

    }
 
    global void finish(

        Database.BatchableContext bc

    ){
 
        System.debug(

            '=== LeadProspectingEscalationBatch FINISHED ==='

        );

    }

}