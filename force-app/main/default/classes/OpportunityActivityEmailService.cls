public inherited sharing class OpportunityActivityEmailService {
    /**
     * -------------------------------------------------------------------------
     * Builds a single escalation email.
     * -------------------------------------------------------------------------
     */
    public static Messaging.SingleEmailMessage buildEmail(

        Opportunity opp,

        Set<String> recipients,

        Integer escalationLevel,

        String activityType

    ){

        OpportunityActivityUtility.log(
            'Preparing Email For Opportunity : ' +
            opp.Name
        );

        if(

            opp == null ||

            recipients == null ||

            recipients.isEmpty()

        ){

            OpportunityActivityUtility.logError(
                'Email Not Created. Opportunity or Recipients Missing.'
            );

            return null;
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(
            new List<String>(recipients)
        );

        mail.setSubject(

            OpportunityActivityConstants.EMAIL_SUBJECT_PREFIX +

            escalationLevel +

            ' Hours'

        );

        String body = '';

        body += 'Opportunity Activity Escalation';
        body += '\n\n';

        body += 'Opportunity Name : '
            + opp.Name;

        body += '\nOpportunity Id : '
            + opp.Id;

        body += '\nStage : '
            + opp.StageName;

        body += '\nDepartment : '
            + opp.Department_NameFormula__c;

        body += '\nActivity Type : '
            + activityType;

        body += '\nLast Open Activity : '
            + String.valueOf(
                opp.Last_Open_Activity__c
            );

        body += '\nEscalation Level : '
            + escalationLevel
            + ' Hours';

        body +=
            '\n\nThis Opportunity contains an Open '
            + activityType
            + ' that has remained unattended for more than '
            + escalationLevel
            + ' hours.';

        body +=
            '\n\nPlease review and take the necessary action.';

        mail.setPlainTextBody(
            body
        );

        OpportunityActivityUtility.logSuccess(
            'Email Prepared Successfully For Opportunity : '
            + opp.Name
        );

        return mail;
    }

}