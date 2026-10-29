global class WeeklyOpenCaseReminderBatch
implements Database.Batchable<SObject>,
           Database.Stateful,
           Schedulable {

    private Map<String, List<Case>> departmentCaseMap =
        new Map<String, List<Case>>();

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug(LoggingLevel.INFO,
            'WeeklyOpenCaseReminderBatch Started');

        return Database.getQueryLocator([
            SELECT Id,
                   CaseNumber,
                   Subject,
                   Status,
                   Department__c,
                   Owner.Name,
                   CreatedDate
            FROM Case
            WHERE Status IN ('Open', 'In Progress')
            AND Department__c != NULL
        ]);
    }

    global void execute(
        Database.BatchableContext bc,
        List<Case> scope
    ) {

        System.debug(LoggingLevel.INFO,
            'Processing Scope Size: ' + scope.size());

        for(Case c : scope) {

            if(!departmentCaseMap.containsKey(c.Department__c)) {

                departmentCaseMap.put(
                    c.Department__c,
                    new List<Case>()
                );

                System.debug(LoggingLevel.INFO,
                    'New Department Found: ' +
                    c.Department__c);
            }

            departmentCaseMap.get(c.Department__c).add(c);
        }

        System.debug(LoggingLevel.INFO,
            'Departments Collected So Far: ' +
            departmentCaseMap.keySet());
    }

    global void finish(Database.BatchableContext bc) {

        System.debug(LoggingLevel.INFO,
            'Finish Method Started');

        if(departmentCaseMap.isEmpty()) {

            System.debug(LoggingLevel.WARN,
                'No Cases Found. Batch Finished.');

            return;
        }

        System.debug(LoggingLevel.INFO,
            'Total Departments Found: ' +
            departmentCaseMap.size());

        Set<String> roleNames = new Set<String>();

        for(String department : departmentCaseMap.keySet()) {
            roleNames.add(department + ' HOD');
        }

        System.debug(LoggingLevel.INFO,
            'Roles To Search: ' + roleNames);

        Map<String, User> roleUserMap = new Map<String, User>();

        for(User usr : [
            SELECT Id,
                   Name,
                   Email,
                   UserRole.Name
            FROM User
            WHERE IsActive = TRUE
            AND UserRole.Name IN :roleNames
        ]) {

            roleUserMap.put(
                usr.UserRole.Name,
                usr
            );

            System.debug(LoggingLevel.INFO,
                'Found HOD User: ' +
                usr.Name +
                ' | Role: ' +
                usr.UserRole.Name);
        }

        System.debug(LoggingLevel.INFO,
            'Total Matching HOD Users Found: ' +
            roleUserMap.size());

        Id orgWideEmailId;

        List<OrgWideEmailAddress> owea = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            WHERE Address =
                'indiateam+utkarshuat@halsaglobal.io'
            LIMIT 1
        ];

        if(!owea.isEmpty()) {

            orgWideEmailId = owea[0].Id;

            System.debug(LoggingLevel.INFO,
                'Org Wide Email Found: ' +
                owea[0].Address);
        }
        else {

            System.debug(LoggingLevel.WARN,
                'Org Wide Email Address Not Found');
        }

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        for(String department : departmentCaseMap.keySet()) {

            String roleName =
                department + ' HOD';

            System.debug(LoggingLevel.INFO,
                'Processing Department: ' +
                department);

            if(!roleUserMap.containsKey(roleName)) {

                System.debug(LoggingLevel.WARN,
                    'No Active User Found For Role: ' +
                    roleName);

                continue;
            }

            User hodUser =
                roleUserMap.get(roleName);

            System.debug(LoggingLevel.INFO,
                'Email Recipient: ' +
                hodUser.Name +
                ' (' +
                hodUser.Email +
                ')');

            System.debug(LoggingLevel.INFO,
                'Total Cases For Department ' +
                department +
                ': ' +
                departmentCaseMap.get(department).size());

            String htmlBody = '';

            htmlBody += '<html><body>';

            htmlBody +=
                '<p>Hello,</p>';

            htmlBody +=
                '<p>Please find below the list of active cases for <b>'
                + department +
                '</b>.</p>';

            htmlBody +=
                '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse;">';

            htmlBody +=
                '<tr style="background-color:#f2f2f2;">' +
                '<th>Case Number</th>' +
                '<th>Subject</th>' +
                '<th>Owner</th>' +
                '<th>Status</th>' +
                '<th>Department</th>' +
                '</tr>';

            for(Case c : departmentCaseMap.get(department)) {

                htmlBody +=
                    '<tr>' +
                    '<td>' + c.CaseNumber + '</td>' +
                    '<td>' + c.Subject + '</td>' +
                    '<td>' + c.Owner.Name + '</td>' +
                    '<td>' + c.Status + '</td>' +
                    '<td>' + c.Department__c + '</td>' +
                    '</tr>';
            }

            htmlBody += '</table>';

            htmlBody +=
                '<br/><b>Total Active Cases : '
                + departmentCaseMap.get(department).size()
                + '</b>';

            htmlBody +=
                '<br/><br/>Kindly review and take necessary action.';

            htmlBody +=
                '<br/><br/>Regards,<br/>Support Team';

            htmlBody +=
                '</body></html>';

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(
                new List<String>{
                    hodUser.Email
                }
            );

            mail.setSubject(
                'Weekly Reminder for Active Cases'
            );

            mail.setHtmlBody(
                htmlBody
            );

            if(orgWideEmailId != null) {

                mail.setOrgWideEmailAddressId(
                    orgWideEmailId
                );
            }

            emails.add(mail);

            System.debug(LoggingLevel.INFO,
                'Email Prepared For Department: ' +
                department);
        }

        System.debug(LoggingLevel.INFO,
            'Total Emails Prepared: ' +
            emails.size());

        if(!emails.isEmpty()) {

            try {

                Messaging.SendEmailResult[] results =
                    Messaging.sendEmail(emails);

                for(Integer i = 0; i < results.size(); i++) {

                    if(results[i].isSuccess()) {

                        System.debug(LoggingLevel.INFO,
                            'Email Sent Successfully. Index: '
                            + i);
                    }
                    else {

                        for(Messaging.SendEmailError err :
                            results[i].getErrors()) {

                            System.debug(LoggingLevel.ERROR,
                                'Email Send Error: ' +
                                err.getMessage());
                        }
                    }
                }
            }
            catch(Exception ex) {

                System.debug(LoggingLevel.ERROR,
                    'Exception Sending Email: ' +
                    ex.getMessage());
            }
        }

        System.debug(LoggingLevel.INFO,
            'WeeklyOpenCaseReminderBatch Finished');
    }

    global void execute(
        SchedulableContext sc
    ) {

        System.debug(LoggingLevel.INFO,
            'Scheduled Job Triggered');

        Database.executeBatch(
            new WeeklyOpenCaseReminderBatch(),
            200
        );
    }

    public static void scheduleJob() {

        String cronExp =
            '0 0 10 ? * WED';

        System.debug(LoggingLevel.INFO,
            'Scheduling Weekly Active Case Reminder. Cron: '
            + cronExp);

        System.schedule(
            'Weekly Active Case Reminder',
            cronExp,
            new WeeklyOpenCaseReminderBatch()
        );
    }
}