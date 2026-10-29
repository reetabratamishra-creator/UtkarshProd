public with sharing class OpportunityNurtureEmailService {

    public static Messaging.SingleEmailMessage buildEmail(
        List<Opportunity> opportunities,
        Set<String> recipients,
        Integer escalationLevel,
        String department
    ){

        System.debug(
            LoggingLevel.INFO,
            'Building Email for Department : '
            + department +
            ', Escalation Level : '
            + escalationLevel
        );

        if(
            opportunities == null ||
            opportunities.isEmpty() ||
            recipients == null ||
            recipients.isEmpty()
        ){
            System.debug(
                LoggingLevel.WARN,
                'No Opportunities or Recipients Found'
            );

            return null;
        }

        String body =

            'Opportunity Nurture Escalation - '
            + escalationLevel +
            ' Hours\n\n';

        if(String.isNotBlank(department)){

            body +=
                'Department : '
                + department +
                '\n\n';
        }

        body +=
            'The following Opportunities have remained in Nurture stage without Quote creation.\n\n';

        for(Opportunity opp : opportunities){

            body +=

                'Opportunity Name : '
                + opp.Name +

                '\nOpportunity Id : '
                + opp.Id +

                '\nDepartment : '
                + opp.Department_NameFormula__c +

                '\nStage : '
                + opp.StageName +

                '\nCreated Date : '
                + String.valueOf(
                    opp.CreatedDate
                ) +

                '\n------------------------------------------\n';
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(
            new List<String>(recipients)
        );

        mail.setSubject(

            'Opportunity Escalation - Nurture Stage - '
            + escalationLevel +
            ' Hours'

        );

        mail.setPlainTextBody(
            body
        );

        System.debug(
            LoggingLevel.INFO,
            'Email Prepared Successfully'
        );

        return mail;
    }

    /**
     * Department Mapping
     * Opportunity Department Value
     * ->
     * Role Name Prefix
     */
    public static String getRoleDepartmentName(
        String department
    ){

        Map<String,String> departmentMap =
            new Map<String,String>{

                'Transmission & Telecom Tower'
                    => 'Transmission Tower'
            };

        return departmentMap.containsKey(
            department
        )
        ? departmentMap.get(
            department
        )
        : department;
    }
}