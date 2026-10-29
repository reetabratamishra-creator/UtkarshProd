global class OpportunityNurtureBatch
implements Database.Batchable<SObject>{

    global Database.QueryLocator start(Database.BatchableContext bc){

        System.debug(LoggingLevel.INFO,'========== OPPORTUNITY NURTURE BATCH START ==========');

        return Database.getQueryLocator([

            SELECT Id,
                   Name,
                   OwnerId,
                   Owner.Email,
                   StageName,
                   CreatedDate,
                   Department_NameFormula__c,
                   Nurture_Escalation_48_Sent__c,
                   Nurture_Escalation_60_Sent__c,
                   Nurture_Escalation_72_Sent__c

            FROM Opportunity

            WHERE StageName = 'Nurture'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope){

        System.debug(LoggingLevel.INFO,'Scope Size : ' + scope.size());

        Set<Id> opportunityIds = new Set<Id>();

        for(Opportunity opp : scope){

            opportunityIds.add(
                opp.Id
            );
        }

        /*
         * Quote Check
         */
        Set<Id> opportunityWithQuotes =new Set<Id>();

        for(Quote qt : [

            SELECT Id, OpportunityId
            FROM Quote
            WHERE OpportunityId
            IN :opportunityIds

        ]){

            opportunityWithQuotes.add(
                qt.OpportunityId
            );
        }

        System.debug(LoggingLevel.INFO,'Opportunities Having Quotes : '+ opportunityWithQuotes.size());

        Map<String,List<Opportunity>>
            dept48Map =
                new Map<String,List<Opportunity>>();

        Map<String,List<Opportunity>>
            dept60Map =
                new Map<String,List<Opportunity>>();

        List<Opportunity>
            opp72List =
                new List<Opportunity>();

        List<Opportunity>
            oppsToUpdate =
                new List<Opportunity>();

        Set<String>
            roleNames =
                new Set<String>();

        for(Opportunity opp : scope){

            if(
                opportunityWithQuotes.contains(
                    opp.Id
                )
            ){

                System.debug(
                    LoggingLevel.INFO,
                    'Skipping Opportunity : '
                    + opp.Name +
                    ' - Quote Exists'
                );

                continue;
            }

            String department =

                OpportunityNurtureEmailService.getRoleDepartmentName(

                        opp.Department_NameFormula__c

                    );

            Long hoursDiff =

                (
                    System.now().getTime()
                    -
                    opp.CreatedDate.getTime()
                )

                /

                (1000 * 60 * 60);

            System.debug(
                LoggingLevel.INFO,
                'Opportunity : '
                + opp.Name +
                ' Hours Difference : '
                + hoursDiff
            );

            Boolean changed = false;

            /*
             * 48 HOURS
             */
            if(
                hoursDiff >= 48
                &&
                !opp.Nurture_Escalation_48_Sent__c
            ){

                if(
                    !dept48Map.containsKey(
                        department
                    )
                ){

                    dept48Map.put(
                        department,
                        new List<Opportunity>()
                    );
                }

                dept48Map.get(
                    department
                ).add(
                    opp
                );

                roleNames.add(
                    department +
                    ' CRM User'
                );

                opp.Nurture_Escalation_48_Sent__c =
                    true;

                changed = true;

                System.debug(
                    LoggingLevel.INFO,
                    '48 Hour Qualified : '
                    + opp.Name
                );
            }

            /*
             * 60 HOURS
             */
            if(
                hoursDiff >= 60
                &&
                !opp.Nurture_Escalation_60_Sent__c
            ){

                if(
                    !dept60Map.containsKey(
                        department
                    )
                ){

                    dept60Map.put(
                        department,
                        new List<Opportunity>()
                    );
                }

                dept60Map.get(
                    department
                ).add(
                    opp
                );

                roleNames.add(
                    department +
                    ' HOD'
                );

                opp.Nurture_Escalation_60_Sent__c =
                    true;

                changed = true;

                System.debug(
                    LoggingLevel.INFO,
                    '60 Hour Qualified : '
                    + opp.Name
                );
            }

            /*
             * 72 HOURS
             */
            if(
                hoursDiff >= 72
                &&
                !opp.Nurture_Escalation_72_Sent__c
            ){

                opp72List.add(
                    opp
                );

                opp.Nurture_Escalation_72_Sent__c =
                    true;

                changed = true;

                System.debug(
                    LoggingLevel.INFO,
                    '72 Hour Qualified : '
                    + opp.Name
                );
            }

            if(changed){

                oppsToUpdate.add(
                    opp
                );
            }
        }

        roleNames.add(
            'Utkarsh CRM Head'
        );

        roleNames.add(
            'Utkarsh ED'
        );

        Map<String,Set<String>>
            roleEmails =
                new Map<String,Set<String>>();

        for(User usr : [

            SELECT Id,
                   Email,
                   UserRole.Name

            FROM User

            WHERE IsActive = true

            AND UserRole.Name
            IN :roleNames

        ]){

            if(
                String.isBlank(
                    usr.Email
                )
            ){
                continue;
            }

            if(
                !roleEmails.containsKey(
                    usr.UserRole.Name
                )
            ){

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

        List<Messaging.SingleEmailMessage>
            emailMessages =
                new List<
                    Messaging.SingleEmailMessage
                >();

        /*
         * 48 HOURS
         */
        for(String dept :
            dept48Map.keySet()){

            Set<String>
                recipients =
                    new Set<String>();

            for(
                Opportunity opp :
                dept48Map.get(dept)
            ){

                if(
                    opp.Owner.Email != null
                ){

                    recipients.add(
                        opp.Owner.Email
                    );
                }
            }

            String crmRole =
                dept +
                ' CRM User';

            if(
                roleEmails.containsKey(
                    crmRole
                )
            ){

                recipients.addAll(

                    roleEmails.get(
                        crmRole
                    )

                );
            }

            Messaging.SingleEmailMessage mail =

                OpportunityNurtureEmailService.buildEmail(

                        dept48Map.get(
                            dept
                        ),

                        recipients,

                        48,

                        dept
                    );

            if(mail != null){

                emailMessages.add(
                    mail
                );
            }
        }

        /*
         * 60 HOURS
         */
        for(String dept :
            dept60Map.keySet()){

            Set<String>
                recipients =
                    new Set<String>();

            String hodRole =
                dept +
                ' HOD';

            if(
                roleEmails.containsKey(
                    hodRole
                )
            ){

                recipients.addAll(

                    roleEmails.get(
                        hodRole
                    )

                );
            }

            if(
                roleEmails.containsKey(
                    'Utkarsh CRM Head'
                )
            ){

                recipients.addAll(

                    roleEmails.get(
                        'Utkarsh CRM Head'
                    )

                );
            }

            Messaging.SingleEmailMessage mail =

                OpportunityNurtureEmailService.buildEmail(

                        dept60Map.get(
                            dept
                        ),

                        recipients,

                        60,

                        dept
                    );

            if(mail != null){

                emailMessages.add(
                    mail
                );
            }
        }

        /*
         * 72 HOURS
         */
        if(!opp72List.isEmpty()){

            Set<String>
                recipients =
                    new Set<String>();

            if(
                roleEmails.containsKey(
                    'Utkarsh ED'
                )
            ){

                recipients.addAll(

                    roleEmails.get(
                        'Utkarsh ED'
                    )

                );
            }

            Messaging.SingleEmailMessage mail =

                OpportunityNurtureEmailService.buildEmail(

                        opp72List,

                        recipients,

                        72,

                        'All Departments'
                    );

            if(mail != null){

                emailMessages.add(
                    mail
                );
            }
        }

        System.debug(
            LoggingLevel.INFO,
            'Total Emails Prepared : '
            + emailMessages.size()
        );

        if(!emailMessages.isEmpty()){

            Messaging.sendEmail(
                emailMessages
            );

            System.debug(
                LoggingLevel.INFO,
                'Emails Sent Successfully'
            );
        }

        if(!oppsToUpdate.isEmpty()){

            Database.SaveResult[] results =

                Database.update(
                    oppsToUpdate,
                    false
                );

            for(
                Database.SaveResult sr :
                results
            ){

                if(!sr.isSuccess()){

                    for(
                        Database.Error err :
                        sr.getErrors()
                    ){

                        System.debug(
                            LoggingLevel.ERROR,
                            err.getMessage()
                        );
                    }
                }
            }
        }

        System.debug(
            LoggingLevel.INFO,
            '========== OPPORTUNITY NURTURE BATCH END =========='
        );
    }

    global void finish(
        Database.BatchableContext bc
    ){

        System.debug(
            LoggingLevel.INFO,
            'Opportunity Nurture Batch Finished'
        );
    }
}