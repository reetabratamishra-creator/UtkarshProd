global with sharing class OpportunityActivityBatch
implements Database.Batchable<SObject>{

    /*
     * Wrapper class used after successful email
     */
    private class PendingEscalation{

        Opportunity opp;
        Integer escalationLevel;

        PendingEscalation(
            Opportunity opp,
            Integer escalationLevel
        ){
            this.opp = opp;
            this.escalationLevel = escalationLevel;
        }
    }

    global Database.QueryLocator start(
        Database.BatchableContext bc
    ){

        System.debug(
            LoggingLevel.INFO,
            '========== Opportunity Activity Batch Started =========='
        );

        return Database.getQueryLocator(

            [

                SELECT
                    Id,
                    Name,
                    OwnerId,
                    StageName,
                    Department_NameFormula__c,
                    Last_Open_Task_Activity__c,
                    Active_Task_Escalation_72_Sent__c,
                    Active_Task_Escalation_96_Sent__c,
                    Active_Task_Escalation_120_Sent__c

                FROM Opportunity

                WHERE StageName = 'Nurture'

                AND Last_Open_Task_Activity__c != NULL

                AND
                (
                    Active_Task_Escalation_72_Sent__c = FALSE
                    OR
                    Active_Task_Escalation_96_Sent__c = FALSE
                    OR
                    Active_Task_Escalation_120_Sent__c = FALSE
                )

            ]

        );

    }

    global void execute(
        Database.BatchableContext bc,
        List<Opportunity> scope
    ){

        System.debug(
            LoggingLevel.INFO,
            '========== Execute Started =========='
        );

        System.debug(
            LoggingLevel.INFO,
            'Scope Size : ' + scope.size()
        );

        if(scope.isEmpty()){

            System.debug(
                LoggingLevel.INFO,
                'No Opportunities Found.'
            );

            return;
        }

        /*
         * Email Queue
         */
        List<Messaging.SingleEmailMessage> emailMessages =
            new List<Messaging.SingleEmailMessage>();

        List<PendingEscalation> pendingEscalations =
            new List<PendingEscalation>();

        Map<Id,Opportunity> oppsToUpdate =
            new Map<Id,Opportunity>();

        /*
         * Collect Owners
         */
        Set<Id> ownerIds =
            new Set<Id>();

        Set<String> departments =
            new Set<String>();

        for(Opportunity opp : scope){

            ownerIds.add(
                opp.OwnerId
            );

            if(
                String.isNotBlank(
                    opp.Department_NameFormula__c
                )
            ){

                departments.add(
                    opp.Department_NameFormula__c
                );

            }

            System.debug(
                LoggingLevel.INFO,
                'Processing Opportunity : ' +
                opp.Name
            );

        }

        /*
         * Load Owners
         */
        Map<Id,User> ownerMap =
            OpportunityActivityUtility.getOwnersByIds(
                ownerIds
            );

        /*
         * Build Required Roles
         */
        Set<String> roleNames =
            OpportunityActivityUtility.buildRequiredRoles(
                departments
            );

        /*
         * Load Role Users
         */
        Map<String,List<User>> roleUsers =
            OpportunityActivityUtility.getUsersByRoles(
                roleNames
            );

        System.debug(
            LoggingLevel.INFO,
            'Owner Count : ' +
            ownerMap.size()
        );

        System.debug(
            LoggingLevel.INFO,
            'Role Count : ' +
            roleUsers.size()
        );

        /*
         * Begin Opportunity Processing
         */
        for(Opportunity opp : scope){

            Long hours =

                OpportunityActivityUtility.calculateHours(

                    opp.Last_Open_Task_Activity__c

                );

            System.debug(
                LoggingLevel.INFO,
                'Hours Since Last Open Task : ' +
                hours
            );

            Set<String> recipients =
                new Set<String>();

            User owner =
                ownerMap.get(
                    opp.OwnerId
                );

            if(
                owner != null &&
                String.isNotBlank(
                    owner.Email
                )
            ){

                recipients.add(
                    owner.Email
                );

            }

            String crmRole =
                OpportunityActivityUtility.getCRMUserRole(
                    opp.Department_NameFormula__c
                );

            String hodRole =
                OpportunityActivityUtility.getHODRole(
                    opp.Department_NameFormula__c
                );

            /*
             * Part 2 starts from here
             */
                        /*
             * -----------------------------
             * 120 Hour Escalation
             * -----------------------------
             */
            if(
                hours >= 120 &&
                !opp.Active_Task_Escalation_120_Sent__c
            ){

                System.debug(
                    LoggingLevel.INFO,
                    'Preparing 120 Hour Escalation'
                );

                recipients.clear();

                recipients.addAll(

                    OpportunityActivityUtility.getRoleEmails(

                        roleUsers,

                      OpportunityActivityConstants.ROLE_ED
                    )

                );

                Messaging.SingleEmailMessage mail =

                    OpportunityActivityEmailService.buildEmail(

                        opp,
                    
                        recipients,
                    
                        120,
                    
                        'Task'
                    
                    );

                if(mail != null){

                    emailMessages.add(
                        mail
                    );

                    pendingEscalations.add(

                        new PendingEscalation(

                            opp,

                            120

                        )

                    );

                    System.debug(
                        LoggingLevel.INFO,
                        '120 Hour Email Queued'
                    );

                }

            }

            /*
             * -----------------------------
             * 96 Hour Escalation
             * -----------------------------
             */
            else if(
                hours >= 96 &&
                !opp.Active_Task_Escalation_96_Sent__c
            ){

                System.debug(
                    LoggingLevel.INFO,
                    'Preparing 96 Hour Escalation'
                );

                recipients.clear();

                recipients.addAll(

                    OpportunityActivityUtility.getRoleEmails(

                        roleUsers,

                        hodRole

                    )

                );

                recipients.addAll(

                    OpportunityActivityUtility.getRoleEmails(

                        roleUsers,

                        OpportunityActivityConstants.ROLE_CRM_HEAD

                    )

                );

                Messaging.SingleEmailMessage mail =

                    OpportunityActivityEmailService.buildEmail(

                            opp,
                        
                            recipients,
                        
                            96,
                        
                            'Task'
                        
                        );

                if(mail != null){

                    emailMessages.add(
                        mail
                    );

                    pendingEscalations.add(

                        new PendingEscalation(

                            opp,

                            96

                        )

                    );

                    System.debug(
                        LoggingLevel.INFO,
                        '96 Hour Email Queued'
                    );

                }

            }

            /*
             * -----------------------------
             * 72 Hour Escalation
             * -----------------------------
             */
            else if(
                hours >= 72 &&
                !opp.Active_Task_Escalation_72_Sent__c
            ){

                System.debug(
                    LoggingLevel.INFO,
                    'Preparing 72 Hour Escalation'
                );

                recipients.addAll(

                    OpportunityActivityUtility.getRoleEmails(

                        roleUsers,

                        crmRole

                    )

                );

                Messaging.SingleEmailMessage mail =

                    OpportunityActivityEmailService.buildEmail(
                    
                        opp,
                    
                        recipients,
                    
                        72,
                    
                        'Task'
                    
                    );

                if(mail != null){

                    emailMessages.add(
                        mail
                    );

                    pendingEscalations.add(

                        new PendingEscalation(

                            opp,

                            72

                        )

                    );

                    System.debug(
                        LoggingLevel.INFO,
                        '72 Hour Email Queued'
                    );

                }

            }

        } // End Opportunity Loop
                /*
         * ----------------------------------------
         * Send Emails
         * ----------------------------------------
         */
        if(!emailMessages.isEmpty()){

            System.debug(
                LoggingLevel.INFO,
                'Total Emails To Send : ' +
                emailMessages.size()
            );

            Messaging.SendEmailResult[] results =

                Messaging.sendEmail(
                    emailMessages,
                    false
                );

            for(
                Integer i = 0;
                i < results.size();
                i++
            ){

                PendingEscalation pe =
                    pendingEscalations[i];

                if(
                    results[i].isSuccess()
                ){

                    System.debug(
                        LoggingLevel.INFO,
                        'Email Sent Successfully : ' +
                        pe.opp.Name +
                        ' | Level : ' +
                        pe.escalationLevel
                    );

                    Opportunity updateOpp;

                    if(
                        oppsToUpdate.containsKey(
                            pe.opp.Id
                        )
                    ){

                        updateOpp =
                            oppsToUpdate.get(
                                pe.opp.Id
                            );

                    }
                    else{

                        updateOpp =
                            new Opportunity(
                                Id = pe.opp.Id
                            );

                    }

                    if(
                        pe.escalationLevel == 72
                    ){

                        updateOpp.Active_Task_Escalation_72_Sent__c = true;

                    }
                    else if(
                        pe.escalationLevel == 96
                    ){

                        updateOpp.Active_Task_Escalation_96_Sent__c = true;

                    }
                    else if(
                        pe.escalationLevel == 120
                    ){

                        updateOpp.Active_Task_Escalation_120_Sent__c = true;

                    }

                    oppsToUpdate.put(
                        updateOpp.Id,
                        updateOpp
                    );

                }
                else{

                    for(
                        Messaging.SendEmailError err :
                        results[i].getErrors()
                    ){

                        System.debug(
                            LoggingLevel.ERROR,
                            'Email Failed : ' +
                            pe.opp.Name +
                            ' | Level : ' +
                            pe.escalationLevel +
                            ' | Error : ' +
                            err.getMessage()
                        );

                    }

                }

            }

        }
        else{

            System.debug(
                LoggingLevel.INFO,
                'No Emails To Send.'
            );

        }

        /*
         * ----------------------------------------
         * Update Opportunities
         * ----------------------------------------
         */

        if(
            !oppsToUpdate.isEmpty()
        ){

            System.debug(
                LoggingLevel.INFO,
                'Updating Opportunities : ' +
                oppsToUpdate.size()
            );

            Database.SaveResult[] saveResults =

                Database.update(

                    oppsToUpdate.values(),

                    false

                );

            for(
                Integer i = 0;
                i < saveResults.size();
                i++
            ){

                if(
                    saveResults[i].isSuccess()
                ){

                    System.debug(
                        LoggingLevel.INFO,
                        'Opportunity Updated : ' +
                        ((List<Opportunity>)oppsToUpdate.values())[i].Id
                    );

                }
                else{

                    for(
                        Database.Error err :
                        saveResults[i].getErrors()
                    ){

                        System.debug(
                            LoggingLevel.ERROR,
                            'Opportunity Update Failed : ' +
                            err.getMessage()
                        );

                    }

                }

            }

        }

        System.debug(
            LoggingLevel.INFO,
            '========== Execute Finished =========='
        );

    }

    global void finish(
        Database.BatchableContext bc
    ){

        System.debug(
            LoggingLevel.INFO,
            '========== Opportunity Activity Batch Finished =========='
        );

    }

}