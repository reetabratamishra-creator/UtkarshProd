public with sharing class OpportunityActiveTaskTriggerHandler {

    public static void updateOpportunityActivity(

        List<Task> newTasks,

        Map<Id,Task> oldMap

    ){

        System.debug(
            LoggingLevel.INFO,
            '=== Handler Started ==='
        );

        Set<Id> opportunityIds =
            new Set<Id>();

        for(Task t : newTasks){

            System.debug(
                LoggingLevel.INFO,
                'Processing Task : ' + t.Id
            );

            /*
             * Opportunity Tasks Only
             */
            if(
                t.WhatId == null
            ){
                continue;
            }

            String idPrefix =
                String.valueOf(
                    t.WhatId
                ).substring(0,3);

            /*
             * Opportunity Prefix = 006
             */
            if(idPrefix != '006'){
                continue;
            }

            /*
             * Open Activities Only
             */
            if(
                t.Status == 'Open'
            ){

                opportunityIds.add(
                    t.WhatId
                );

                System.debug(
                    LoggingLevel.INFO,
                    'Open Task Found for Opportunity : '
                    + t.WhatId
                );
            }
        }

        System.debug(
            LoggingLevel.INFO,
            'Opportunity Count To Update : '
            + opportunityIds.size()
        );

        if(
            opportunityIds.isEmpty()
        ){
            return;
        }

        List<Opportunity> oppsToUpdate =
            new List<Opportunity>();

        for(Id oppId : opportunityIds){

            Opportunity opp =
                new Opportunity();

            opp.Id = oppId;

            opp.Last_Open_Task_Activity__c =
                System.now();

            oppsToUpdate.add(
                opp
            );
        }

        System.debug(
            LoggingLevel.INFO,
            'Updating Opportunities : '
            + oppsToUpdate.size()
        );

        Database.SaveResult[] results =

            Database.update(
                oppsToUpdate,
                false
            );

        for(Integer i = 0;
            i < results.size();
            i++){

            if(
                results[i].isSuccess()
            ){

                System.debug(
                    LoggingLevel.INFO,
                    'Opportunity Updated : '
                    + oppsToUpdate[i].Id
                );
            }
            else{

                for(
                    Database.Error err :
                    results[i].getErrors()
                ){

                    System.debug(
                        LoggingLevel.ERROR,
                        'Opportunity Update Failed : '
                        + oppsToUpdate[i].Id
                        + ' | '
                        + err.getMessage()
                    );
                }
            }
        }

        System.debug(
            LoggingLevel.INFO,
            '=== Handler Finished ==='
        );
    }
}