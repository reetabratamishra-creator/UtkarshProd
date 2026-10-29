public with sharing class LeadEscalationEmailService {

    public static Messaging.SingleEmailMessage buildEmail(
        List<Lead> leads,
        Set<String> recipients,
        Integer escalationLevel,
        String department
    ){

        if(leads == null || leads.isEmpty() ||
           recipients == null || recipients.isEmpty()){

            return null;
        }
        
        recipients.add('ramyasri.a@coservesolutions.com');

System.debug('Test Email Added');
System.debug('Recipients: ' + recipients);

        String body =
            'Lead Escalation - ' +
            escalationLevel +
            ' Hours\n\n';

        if(String.isNotBlank(department)){
            body +=
                'Department : ' +
                department +
                '\n\n';
        }

        for(Lead ld : leads){

            body +=
                'Lead Name : ' +
                ld.Name +
                '\n';

            body +=
                'Status : ' +
                ld.Status +
                '\n';

            body +=
                'Created Date : ' +
                String.valueOf(
                    ld.CreatedDate
                ) +
                '\n';

            body +=
                '---------------------------------\n';
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(
            new List<String>(recipients)
        );

        mail.setSubject(
            'Lead Escalation - ' +
            escalationLevel +
            ' Hours'
        );

        mail.setPlainTextBody(
            body
        );

        return mail;
    }

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