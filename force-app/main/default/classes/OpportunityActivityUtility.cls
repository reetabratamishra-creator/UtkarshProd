public inherited sharing class OpportunityActivityUtility {

    /**
     * ------------------------------------------------------------------------
     * Common Debug Logger
     * ------------------------------------------------------------------------
     */
    public static void log(String message){

        System.debug(
            LoggingLevel.INFO,
            OpportunityActivityConstants.LOG_PREFIX + message
        );
    }

    /**
     * ------------------------------------------------------------------------
     * Returns TRUE if the Id belongs to Opportunity
     * ------------------------------------------------------------------------
     */
    public static Boolean isOpportunityRecord(Id recordId){

        if(recordId == null){
            return false;
        }

        return String.valueOf(recordId)
            .startsWith(
                OpportunityActivityConstants.OPPORTUNITY_PREFIX
            );
    }

    /**
     * ------------------------------------------------------------------------
     * Calculates hours from supplied DateTime till now.
     * ------------------------------------------------------------------------
     */
    public static Long calculateHours(
        Datetime activityTime
    ){

        if(activityTime == null){
            return 0;
        }

        Long diffMillis =

            System.now().getTime()

            -

            activityTime.getTime();

        return diffMillis

            /

            (1000 * 60 * 60);
    }

    public static String getRoleDepartmentName(

        String department

    ){

        if(String.isBlank(department)){
            return '';
        }

        Map<String,String> departmentMap =
            new Map<String,String>{

                'Transmission & Telecom Tower'
                    => 'Transmission Tower'

            };

        return departmentMap.containsKey(
            department
        )

        ?

        departmentMap.get(
            department
        )

        :

        department;
    }
        /**
     * ------------------------------------------------------------------------
     * Returns CRM User Role Name
     * Example:
     * Railway  -> Railway CRM User
     * ------------------------------------------------------------------------
     */
    public static String getCRMUserRole(
        String department
    ){

        return getRoleDepartmentName(
            department
        ) +
        OpportunityActivityConstants.ROLE_CRM_USER;
    }


    /**
     * ------------------------------------------------------------------------
     * Returns Department HOD Role Name
     * Example:
     * Railway -> Railway HOD
     * ------------------------------------------------------------------------
     */
    public static String getHODRole(
        String department
    ){

        return getRoleDepartmentName(
            department
        ) +
        OpportunityActivityConstants.ROLE_HOD;
    }


    /**
     * ------------------------------------------------------------------------
     * Bulk fetch all active users by Role Names.
     *
     * Returns:
     * Map<Role Name, List<User>>
     * ------------------------------------------------------------------------
     */
    public static Map<String,List<User>> getUsersByRoles(

        Set<String> roleNames

    ){

        log('Fetching Users By Roles');

        Map<String,List<User>> roleUserMap =

            new Map<String,List<User>>();

        if(
            roleNames == null ||
            roleNames.isEmpty()
        ){

            log('No Role Names Supplied.');

            return roleUserMap;
        }

        List<User> users = [

            SELECT Id,
                   Name,
                   Email,
                   UserRole.Name

            FROM User

            WHERE IsActive = true

            AND UserRole.Name IN :roleNames
        ];

        log(
            'Active Users Found : ' +
            users.size()
        );

        for(User usr : users){

            if(
                !roleUserMap.containsKey(
                    usr.UserRole.Name
                )
            ){

                roleUserMap.put(

                    usr.UserRole.Name,

                    new List<User>()

                );
            }

            roleUserMap.get(

                usr.UserRole.Name

            ).add(

                usr

            );
        }

        return roleUserMap;
    }


    /**
     * ------------------------------------------------------------------------
     * Converts Users into Email Addresses.
     *
     * Duplicate emails are automatically removed.
     * ------------------------------------------------------------------------
     */
    public static Set<String> getEmailsFromUsers(

        List<User> users

    ){

        Set<String> emailSet =

            new Set<String>();

        if(
            users == null
        ){

            return emailSet;
        }

        for(User usr : users){

            if(
                String.isNotBlank(
                    usr.Email
                )
            ){

                emailSet.add(

                    usr.Email

                );
            }
        }

        return emailSet;
    }
          /**
            * ------------------------------------------------------------------------
            * Returns Owner Email
            * ------------------------------------------------------------------------
            */
            /**
        * ------------------------------------------------------------------------
        * Returns all Opportunity Owners in a single query.
        * ------------------------------------------------------------------------
        */
        public static Map<Id,User> getOwnersByIds(

            Set<Id> ownerIds

        ){

            log(
                'Fetching Opportunity Owners'
            );

            Map<Id,User> ownerMap =
                new Map<Id,User>();

            if(
                ownerIds == null ||
                ownerIds.isEmpty()
            ){

                return ownerMap;
            }

            ownerMap = new Map<Id,User>([

                SELECT Id,
                    Name,
                    Email

                FROM User

                WHERE Id IN :ownerIds

                AND IsActive = true

            ]);

            log(
                'Owners Found : ' +
                ownerMap.size()
            );

            return ownerMap;
        }

    /**
     * ------------------------------------------------------------------------
     * Adds email addresses into recipient Set.
     * Removes duplicates automatically.
     * ------------------------------------------------------------------------
     */
    public static void addEmailsToRecipientSet(

        Set<String> recipientSet,

        Set<String> emails

    ){

        if(
            recipientSet == null ||
            emails == null
        ){
            return;
        }

        recipientSet.addAll(
            emails
        );
    }


    /**
     * ------------------------------------------------------------------------
     * Builds all required role names for a Department.
     * This avoids creating role names repeatedly.
     * ------------------------------------------------------------------------
     */
    public static Set<String> buildRequiredRoles(

        Set<String> departments

    ){

        Set<String> roleNames =
            new Set<String>();

        if(
            departments == null ||
            departments.isEmpty()
        ){
            return roleNames;
        }

        for(String dept : departments){

            if(String.isBlank(dept)){
                continue;
            }

            String mappedDepartment =
                getRoleDepartmentName(dept);

            roleNames.add(
                mappedDepartment +
                OpportunityActivityConstants.ROLE_CRM_USER
            );

            roleNames.add(
                mappedDepartment +
                OpportunityActivityConstants.ROLE_HOD
            );
        }

        /*
         * Global Roles
         */

        roleNames.add(
            OpportunityActivityConstants.ROLE_CRM_HEAD
        );

        roleNames.add(
            OpportunityActivityConstants.ROLE_ED
        );

        log(
            'Total Roles Prepared : ' +
            roleNames.size()
        );

        return roleNames;
    }


    /**
     * ------------------------------------------------------------------------
     * Common method to check whether
     * Opportunity is eligible for escalation.
     * ------------------------------------------------------------------------
     */
    public static Boolean isEligibleForEscalation(

        Opportunity opp

    ){

        if(
            opp == null
        ){
            return false;
        }

        return

            opp.StageName ==

            OpportunityActivityConstants.STAGE_NURTURE

            &&

            opp.Last_Open_Activity__c != null;
    }


    /**
     * ------------------------------------------------------------------------
     * Common Success Logger
     * ------------------------------------------------------------------------
     */
    public static void logSuccess(
        String message
    ){

        System.debug(

            LoggingLevel.INFO,

            OpportunityActivityConstants.LOG_PREFIX +

            'SUCCESS : ' +

            message

        );
    }


    /**
     * ------------------------------------------------------------------------
     * Common Error Logger
     * ------------------------------------------------------------------------
     */
    public static void logError(
        String message
    ){

        System.debug(

            LoggingLevel.ERROR,

            OpportunityActivityConstants.LOG_PREFIX +

            'ERROR : ' +

            message

        );
    }
    public static Set<String> getRoleEmails(

    Map<String,List<User>> roleUsers,

    String roleName

){

    Set<String> emails =
        new Set<String>();

    if(
        roleUsers == null ||
        String.isBlank(roleName)
    ){
        return emails;
    }

    if(
        roleUsers.containsKey(roleName)
    ){

        emails.addAll(

            getEmailsFromUsers(

                roleUsers.get(roleName)

            )

        );

    }

    return emails;
}

}