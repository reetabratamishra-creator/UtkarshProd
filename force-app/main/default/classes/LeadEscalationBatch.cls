global class LeadEscalationBatch
implements Database.Batchable<SObject>{

    global Database.QueryLocator start(
        Database.BatchableContext bc
    ){

        System.debug('===== LeadEscalationBatch START Method =====');

        return Database.getQueryLocator([

            SELECT Id,
                   Name,
                   OwnerId,
                   Owner.Email,
                   Status,
                   CreatedDate,
                   Department_NameFormula__c,
                   Escalation_24_Sent__c,
                   Escalation_48_Sent__c,
                   Escalation_72_Sent__c

            FROM Lead

            WHERE Status = 'Prospect'
        ]);
    }

    global void execute(
        Database.BatchableContext bc,
        List<Lead> scope
    ){

        System.debug('===== EXECUTE STARTED =====');
        System.debug('Total Leads Received : ' + scope.size());

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

            System.debug('----------------------------------');
            System.debug('Processing Lead : ' + ld.Name);
            System.debug('Lead Id : ' + ld.Id);

            String dept =
                LeadEscalationEmailService.getRoleDepartmentName(
                    ld.Department_NameFormula__c
                );

            System.debug('Department : ' + dept);

            Long hoursDiff =
                (System.now().getTime()
                 - ld.CreatedDate.getTime())
                /
                (1000 * 60 * 60);

            System.debug('Hours Difference : ' + hoursDiff);

            Boolean changed = false;

            if(hoursDiff >= 24 &&
               !ld.Escalation_24_Sent__c){

                System.debug('24 Hour Escalation Triggered');

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

                ld.Escalation_24_Sent__c = true;

                changed = true;
            }

            if(hoursDiff >= 48 &&
               !ld.Escalation_48_Sent__c){

                System.debug('48 Hour Escalation Triggered');

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

                ld.Escalation_48_Sent__c = true;

                changed = true;
            }

            if(hoursDiff >= 72 &&
               !ld.Escalation_72_Sent__c){

                System.debug('72 Hour Escalation Triggered');

                leads72.add(ld);

                ld.Escalation_72_Sent__c = true;

                changed = true;
            }

            if(changed){

                System.debug('Lead Added For Update : ' + ld.Id);

                leadsToUpdate.add(ld);
            }
        }

        System.debug('24 Hour Departments : ' + dept24Map.keySet());
        System.debug('48 Hour Departments : ' + dept48Map.keySet());
        System.debug('72 Hour Leads Count : ' + leads72.size());

        roleNames.add('Utkarsh CRM Head');
        roleNames.add('Utkarsh ED');

        System.debug('Roles To Fetch : ' + roleNames);

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
                'User Found : ' +
                usr.Name +
                ' | Role : ' +
                usr.UserRole.Name +
                ' | Email : ' +
                usr.Email
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

        System.debug('Role Email Map : ' + roleEmails);

        List<Messaging.SingleEmailMessage>
            emailMessages =
            new List<Messaging.SingleEmailMessage>();

        // 24 HOURS

        for(String dept : dept24Map.keySet()){

            Set<String> recipients =
                new Set<String>();

            for(Lead ld :
                dept24Map.get(dept)){

                if(ld.Owner.Email != null){

                    recipients.add(
                        ld.Owner.Email
                    );
                }
            }

            String roleName =
                dept + ' CRM User';

            if(roleEmails.containsKey(roleName)){
                recipients.addAll(
                    roleEmails.get(roleName)
                );
            }

            System.debug(
                '24 Hour Email Recipients For '
                + dept + ' : '
                + recipients
            );

            Messaging.SingleEmailMessage mail =
                LeadEscalationEmailService.buildEmail(
                    dept24Map.get(dept),
                    recipients,
                    24,
                    dept
                );

            if(mail != null){
                emailMessages.add(mail);
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
                '48 Hour Email Recipients For '
                + dept + ' : '
                + recipients
            );

            Messaging.SingleEmailMessage mail =
                LeadEscalationEmailService.buildEmail(
                    dept48Map.get(dept),
                    recipients,
                    48,
                    dept
                );

            if(mail != null){
                emailMessages.add(mail);
            }
        }

        // 72 HOURS

        if(!leads72.isEmpty()){

            Set<String> recipients =
                new Set<String>();

            if(roleEmails.containsKey(
                'Utkarsh ED'
            )){
                recipients.addAll(
                    roleEmails.get(
                        'Utkarsh ED'
                    )
                );
            }

            System.debug(
                '72 Hour Email Recipients : '
                + recipients
            );

            Messaging.SingleEmailMessage mail =
                LeadEscalationEmailService.buildEmail(
                    leads72,
                    recipients,
                    72,
                    'All Departments'
                );

            if(mail != null){
                emailMessages.add(mail);
            }
        }

        System.debug(
            'Total Emails To Send : '
            + emailMessages.size()
        );

        if(!emailMessages.isEmpty()){

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(
                    emailMessages
                );

            System.debug(
                'Email Send Result : '
                + results
            );
        }

        System.debug(
            'Total Leads To Update : '
            + leadsToUpdate.size()
        );

        if(!leadsToUpdate.isEmpty()){

            Database.SaveResult[] saveResults =
                Database.update(
                    leadsToUpdate,
                    false
                );

            System.debug(
                'Update Results : '
                + saveResults
            );
        }

        System.debug('===== EXECUTE COMPLETED =====');
    }

    global void finish(
        Database.BatchableContext bc
    ){
        System.debug(
            '===== LeadEscalationBatch FINISH Method ====='
        );
    }
}