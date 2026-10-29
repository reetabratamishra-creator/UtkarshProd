public with sharing class OpportunityActivityHandler {
    /**
     * Process Open Tasks
     */
    public static void processTasks(
        List<Task> tasks
    ){

        System.debug(
            LoggingLevel.INFO,
            '=== PROCESS TASKS START ==='
        );

        Set<Id> opportunityIds =
            new Set<Id>();

        for(Task t : tasks){

            System.debug(
                LoggingLevel.INFO,
                'Task Processing : ' +
                t.Id
            );

            if(t.WhatId == null){
                continue;
            }
                if(
                String.valueOf(t.WhatId).startsWith('006')
                ){
                opportunityIds.add(t.WhatId);

                System.debug(
                    LoggingLevel.INFO,
                    'Opportunity Added : ' + t.WhatId +
                    ' | Task Status : ' + t.Status
                );
                }

            // if(
            //     String.valueOf(
            //         t.WhatId
            //     ).startsWith('006')
            //     &&
            //     t.Status == 'Open'
            // ){

            //     opportunityIds.add(
            //         t.WhatId
            //     );

            //     System.debug(
            //         LoggingLevel.INFO,
            //         'Open Task Found For Opportunity : '
            //         + t.WhatId
            //     );
            // }
        }

        updateOpportunityActivity(
            opportunityIds
        );

        System.debug(
            LoggingLevel.INFO,
            '=== PROCESS TASKS END ==='
        );
    }

    /**
     * Process Events
     */
    public static void processEvents(
        List<Event> events
    ){

        System.debug(
            LoggingLevel.INFO,
            '=== PROCESS EVENTS START ==='
        );

        Set<Id> opportunityIds =
            new Set<Id>();

        for(Event ev : events){

            System.debug(
                LoggingLevel.INFO,
                'Event Processing : ' +
                ev.Id
            );

            if(ev.WhatId == null){
                continue;
            }

            /*
             * Opportunity Record
             */
            if(
                String.valueOf(
                    ev.WhatId
                ).startsWith('006')
            ){

                /*
                 * Future Event Only
                 */
                if(
                    ev.EndDateTime != null
                    &&
                    ev.EndDateTime > System.now()
                ){

                    opportunityIds.add(
                        ev.WhatId
                    );

                    System.debug(
                        LoggingLevel.INFO,
                        'Future Event Found For Opportunity : '
                        + ev.WhatId
                    );
                }
            }
        }

        updateOpportunityActivity(
            opportunityIds
        );

        System.debug(
            LoggingLevel.INFO,
            '=== PROCESS EVENTS END ==='
        );
    }

    /**
     * Update Last Activity Datetime
     */

     private static void updateOpportunityActivity(
    Set<Id> opportunityIds
){

    System.debug(
        LoggingLevel.INFO,
        '========== UPDATE OPPORTUNITY ACTIVITY START =========='
    );

    System.debug(
        LoggingLevel.INFO,
        'Opportunity Count : ' +
        opportunityIds.size()
    );

    if(opportunityIds.isEmpty()){
        return;
    }

    /*
     * Query only Nurture Opportunities
     */
    Map<Id, Opportunity> opportunityMap =
        new Map<Id, Opportunity>([

            SELECT Id,
                   StageName,
                   Last_Open_Task_Activity__c,
                   Active_Task_Escalation_72_Sent__c,
                   Active_Task_Escalation_96_Sent__c,
                   Active_Task_Escalation_120_Sent__c

            FROM Opportunity

            WHERE Id IN :opportunityIds

            AND StageName = 'Nurture'

        ]);

    System.debug(
        LoggingLevel.INFO,
        'Nurture Opportunities Found : ' +
        opportunityMap.size()
    );

    if(opportunityMap.isEmpty()){
        return;
    }

    /*
     * Find latest Open Task for every Opportunity
     */
    Map<Id, Datetime> latestOpenTaskMap =
        new Map<Id, Datetime>();

    for(Task t : [

        SELECT Id,
               WhatId,
               CreatedDate,
               Status

        FROM Task

        WHERE WhatId IN :opportunityMap.keySet()

        AND Status = 'Open'

        ORDER BY CreatedDate DESC

    ]){

        if(
            !latestOpenTaskMap.containsKey(
                t.WhatId
            )
        ){

            latestOpenTaskMap.put(

                t.WhatId,

                t.CreatedDate

            );

        }
    }

    System.debug(
        LoggingLevel.INFO,
        'Latest Open Tasks Found : ' +
        latestOpenTaskMap.size()
    );

    List<Opportunity> oppsToUpdate =
        new List<Opportunity>();

    for(Opportunity opp : opportunityMap.values()){

        Opportunity updateOpp =
            new Opportunity();

        updateOpp.Id = opp.Id;

        /*
         * Open Task Exists
         */
        if(
            latestOpenTaskMap.containsKey(
                opp.Id
            )
        ){

            updateOpp.Last_Open_Task_Activity__c =
                latestOpenTaskMap.get(
                    opp.Id
                );

            /*
             * Reset Escalation Flags
             */
            updateOpp.Active_Task_Escalation_72_Sent__c = false;
            updateOpp.Active_Task_Escalation_96_Sent__c = false;
            updateOpp.Active_Task_Escalation_120_Sent__c = false;

            System.debug(
                LoggingLevel.INFO,
                'Latest Open Task Stored : ' +
                updateOpp.Last_Open_Task_Activity__c
            );

        }
        else{

            /*
             * No Open Task Remaining
             */
            updateOpp.Last_Open_Task_Activity__c = null;

            updateOpp.Active_Task_Escalation_72_Sent__c = false;
            updateOpp.Active_Task_Escalation_96_Sent__c = false;
            updateOpp.Active_Task_Escalation_120_Sent__c = false;

            System.debug(
                LoggingLevel.INFO,
                'No Open Tasks Remaining For Opportunity : ' +
                opp.Id
            );
        }

        oppsToUpdate.add(
            updateOpp
        );
    }

    System.debug(
        LoggingLevel.INFO,
        'Updating Opportunities : ' +
        oppsToUpdate.size()
    );

    Database.SaveResult[] results =
        Database.update(
            oppsToUpdate,
            false
        );

    for(Integer i = 0;
        i < results.size();
        i++){

        if(results[i].isSuccess()){

            System.debug(
                LoggingLevel.INFO,
                'Opportunity Updated Successfully : ' +
                oppsToUpdate[i].Id
            );
        }
        else{

            for(Database.Error err :
                results[i].getErrors()){

                System.debug(
                    LoggingLevel.ERROR,
                    'Update Failed : ' +
                    oppsToUpdate[i].Id +
                    ' | ' +
                    err.getMessage()
                );
            }
        }
    }

    System.debug(
        LoggingLevel.INFO,
        '========== UPDATE OPPORTUNITY ACTIVITY END =========='
    );
}
    // private static void updateOpportunityActivity(
    //     Set<Id> opportunityIds
    // ){

    //     System.debug(
    //         LoggingLevel.INFO,
    //         'Opportunity Count : '
    //         + opportunityIds.size()
    //     );

    //     if(
    //         opportunityIds.isEmpty()
    //     ){
    //         return;
    //     }

    //     List<Opportunity> oppsToUpdate =
    //         new List<Opportunity>();

    //     for(Id oppId : opportunityIds){

    //         Opportunity opp =
    //             new Opportunity();

    //         opp.Id = oppId;

    //         opp.Last_Open_Task_Activity__c =
    //             System.now();

    //         oppsToUpdate.add(
    //             opp
    //         );
    //     }

    //     System.debug(
    //         LoggingLevel.INFO,
    //         'Updating Opportunities : '
    //         + oppsToUpdate.size()
    //     );

    //     Database.SaveResult[] results =

    //         Database.update(
    //             oppsToUpdate,
    //             false
    //         );

    //     for(Integer i = 0;
    //         i < results.size();
    //         i++){

    //         if(results[i].isSuccess()){

    //             System.debug(
    //                 LoggingLevel.INFO,
    //                 'Opportunity Updated : '
    //                 + oppsToUpdate[i].Id
    //             );
    //         }
    //         else{

    //             for(
    //                 Database.Error err :
    //                 results[i].getErrors()
    //             ){

    //                 System.debug(
    //                     LoggingLevel.ERROR,
    //                     'Update Failed : '
    //                     + oppsToUpdate[i].Id
    //                     + ' | '
    //                     + err.getMessage()
    //                 );
    //             }
    //         }
    //     }
    // }
}