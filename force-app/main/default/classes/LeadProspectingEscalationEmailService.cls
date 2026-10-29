public with sharing class LeadProspectingEscalationEmailService {

    public static Messaging.SingleEmailMessage buildEmail(
        List<Lead> leads,
        Set<String> recipients,
        Integer escalationLevel,
        String department
    ){

        if(
            leads == null ||
            leads.isEmpty() ||
            recipients == null ||
            recipients.isEmpty()
        ){
            return null;
        }
        String body =

            'Lead Prospecting Escalation - '
            + escalationLevel +
            ' Hours\n\n';

        if(String.isNotBlank(department)){

            body +=
                'Department : '
                + department +
                '\n\n';
        }

        body +=
            'The following leads have had no activity in Prospecting stage for more than '
            + escalationLevel +
            ' hours.\n\n';

        for(Lead ld : leads){

            body +=

                'Lead Name : '
                + ld.Name +

                '\nStatus : '
                + ld.Status +

                '\nDepartment : '
                + ld.Department_NameFormula__c +

                '\nLast Prospecting Activity : '
                + String.valueOf(
                    ld.Last_Prospecting_Activity__c
                ) +

                '\n---------------------------------\n';
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(
            new List<String>(recipients)
        );

        mail.setSubject(

            'Prospecting Escalation - '
            + escalationLevel +
            ' Hours'

        );

        mail.setPlainTextBody(
            body
        );

        return mail;
    }

    /**
     * Department Mapping
     * Lead Department Value
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