/**
 * @description Sends Expense Report submission reminder emails.
 *              1. 16th of the month → Employee (current month)
 *              2. 1st of the month  → Employee (previous month - Final Reminder)
 *              3. 7th of the month  → Employee HOD (previous month not submitted)
 * @author Rani Mate
 * @date 2026-08-14
 */
public without sharing class ExpenseSubmissionReminderBatch 
    implements Database.Batchable<SObject>, Schedulable {

    public static final String TEMPLATE_16TH =
        'Employee_16th_of_the_Month_1786613298036';
    public static final String TEMPLATE_1ST =
        'Employee_1st_Day_of_the_Next_Month_1786633448103';

    // ADDED: HOD reminder on the 7th for the previous month
    public static final String TEMPLATE_HOD_7TH =
        'HOD_7th_day_of_the_next_month_1786633804629';

    public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

    @TestVisible
    private static Date testTodayOverride;

    // ========== Schedulable ==========
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ExpenseSubmissionReminderBatch(), 50);
    }

    // ========== Batch Start ==========
    public Database.QueryLocator start(Database.BatchableContext bc) {

        // We target active Users who are employees
        return Database.getQueryLocator([
            SELECT Id, Email, FirstName, LastName, IsActive
            FROM User
            WHERE IsActive = true
            AND Email != null
            AND UserType = 'Standard'
            
        ]);
    }

    // ========== Batch Execute ==========
    public void execute(Database.BatchableContext bc, List<User> scope) {

        Date today = getRunDate();
        Integer day = today.day();
        Integer month = today.month();
        Integer year = today.year();

        // ADDED: 7th of the month → HOD reminder for previous month non-submission
        if (day == 7) {
            sendHodNonSubmissionReminders(scope, today);
            return;
        }

        String templateName = null;
        Date monthStart;
        Date monthEnd;

        // ===== 16th of the Month → Current Month Reminder =====
        if (day == 16) {
            templateName = TEMPLATE_16TH;
            monthStart = Date.newInstance(year, month, 1);
            monthEnd   = monthStart.addMonths(1).addDays(-1);
        }
        // ===== 1st of the Month → Previous Month Final Reminder =====
        else if (day == 1) {
            templateName = TEMPLATE_1ST;
            Date previousMonth = today.addMonths(-1);
            monthStart = Date.newInstance(previousMonth.year(), previousMonth.month(), 1);
            monthEnd   = monthStart.addMonths(1).addDays(-1);
        } else {
            // Not 1st or 16th → do nothing
            return;
        }

        Id templateId = resolveTemplateId(templateName);
        if (templateId == null) {
            System.debug('Template not found: ' + templateName);
            return;
        }

        // Find employees who ALREADY submitted expense in that month
        Set<Id> usersWhoSubmitted = new Set<Id>();

        for (Expense__c exp : [
            SELECT Employee__c
            FROM Expense__c
            WHERE Employee__c IN :scope
            AND Submitted_Date__c >= :monthStart
            AND Submitted_Date__c <= :monthEnd
            AND Status__c IN ('Submitted', 'Approved', 'Pending Approval')  // adjust statuses as needed
        ]) {
            usersWhoSubmitted.add(exp.Employee__c);
        }

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (User u : scope) {
            // Skip if already submitted
            if (usersWhoSubmitted.contains(u.Id)) {
                continue;
            }

            Messaging.SingleEmailMessage mail = buildMessage(templateId, u.Id, u.Email);
            if (mail != null) {
                messages.add(mail);
            }
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages);
                System.debug('Sent ' + messages.size() + ' expense reminder emails');
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}

    @TestVisible
    private static Date getRunDate() {
        if (Test.isRunningTest() && testTodayOverride != null) {
            return testTodayOverride;
        }
        return Date.today();
    }

    // ADDED
    @TestVisible
    private static void sendHodNonSubmissionReminders(List<User> scope, Date today) {
        Date previousMonth = today.addMonths(-1);
        Date monthStart = Date.newInstance(previousMonth.year(), previousMonth.month(), 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);
        // FIXED: compute the actual missing-month label in Apex (e.g. "July 2026")
        // instead of relying on a template merge field that has no reliable source.
        String monthLabel = getMonthName(previousMonth.month()) + ' ' + previousMonth.year();

        Set<Id> userIds = new Set<Id>();
        for (User u : scope) {
            userIds.add(u.Id);
        }

        Set<Id> usersWhoSubmitted = new Set<Id>();
        for (Expense__c exp : [
            SELECT Employee__c
            FROM Expense__c
            WHERE Employee__c IN :userIds
            AND Submitted_Date__c >= :monthStart
            AND Submitted_Date__c <= :monthEnd
            AND Status__c IN ('Submitted', 'Approved', 'Approved', 'Pending Approval')
        ]) {
            usersWhoSubmitted.add(exp.Employee__c);
        }

        Set<Id> usersWithoutSubmission = new Set<Id>();
        for (Id userId : userIds) {
            if (!usersWhoSubmitted.contains(userId)) {
                usersWithoutSubmission.add(userId);
            }
        }

        if (usersWithoutSubmission.isEmpty()) {
            return;
        }

        // FIXED: keep employee Name available for the merge, alongside HOD email.
        Map<Id, Expense__c> latestExpenseByEmployee = new Map<Id, Expense__c>();
        for (Expense__c exp : [
            SELECT Id, Employee__c, Employee__r.Name, HOD_User_Email_Formula__c
            FROM Expense__c
            WHERE Employee__c IN :usersWithoutSubmission
            ORDER BY CreatedDate DESC
        ]) {
            if (!latestExpenseByEmployee.containsKey(exp.Employee__c)) {
                latestExpenseByEmployee.put(exp.Employee__c, exp);
            }
        }

        // FIXED: fall back to the User record itself for employees with zero
        // Expense__c records, so they are no longer silently skipped.
        Map<Id, User> usersById = new Map<Id, User>();
        for (User u : scope) {
            usersById.put(u.Id, u);
        }

        Id oweaId = getOrgWideEmailAddressId();
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (Id employeeId : usersWithoutSubmission) {
            Expense__c contextExpense = latestExpenseByEmployee.get(employeeId);

            String hodEmail = contextExpense == null ? null : contextExpense.HOD_User_Email_Formula__c;
            String employeeName = contextExpense != null && contextExpense.Employee__r != null
                ? contextExpense.Employee__r.Name
                : (usersById.containsKey(employeeId) ? usersById.get(employeeId).Name : null);

            if (String.isBlank(hodEmail)) {
                // NOTE: with no Expense__c record (or no HOD email formula resolved),
                // there is currently no other field carrying the HOD's email address.
                // This case is logged distinctly so it can be followed up manually
                // until a fallback HOD-email source (e.g. on the User record) is agreed.
                System.debug(
                    'Skipping HOD reminder - HOD email not resolved for employee ' +
                    employeeId + ' (name: ' + employeeName + ')'
                );
                continue;
            }

            Messaging.SingleEmailMessage mail = buildHodReminderMessage(
                contextExpense == null ? null : contextExpense.Id,
                hodEmail.trim(),
                employeeName,
                monthLabel,
                oweaId
            );
            if (mail != null) {
                messages.add(mail);
            }
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages);
                System.debug('Sent ' + messages.size() + ' HOD expense reminder emails');
            } catch (Exception e) {
                System.debug('Error sending HOD reminder emails: ' + e.getMessage());
            }
        }
    }

    // ADDED
    // FIXED: builds the subject/body directly instead of using
    // Messaging.renderStoredEmailTemplate, since the HOD name and the missing
    // month cannot be reliably resolved as merge fields off the Expense record.
    private static Messaging.SingleEmailMessage buildHodReminderMessage(
        Id expenseId,
        String hodEmail,
        String employeeName,
        String monthLabel,
        Id oweaId
    ) {
        if (String.isBlank(hodEmail)) {
            return null;
        }

        String safeEmployeeName = String.isBlank(employeeName) ? 'the employee' : employeeName;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ hodEmail });
        mail.setSubject('Expense Report Not Submitted – ' + safeEmployeeName);
        mail.setHtmlBody(
            'Dear HOD,<br/><br/>' +
            'The below employee has not submitted their expense report for the previous month.<br/><br/>' +
            'Employee Name: ' + safeEmployeeName + '<br/>' +
            'Month: ' + monthLabel + '<br/><br/>' +
            'Kindly follow up for timely submission.<br/><br/>' +
            'Regards,<br/>Team CRM'
        );
        mail.setSaveAsActivity(false);
        mail.setTreatTargetObjectAsRecipient(false);
        if (expenseId != null) {
            mail.setWhatId(expenseId);
        }

        if (oweaId != null) {
            mail.setOrgWideEmailAddressId(oweaId);
        }
        return mail;
    }

    // ADDED
    private static String getMonthName(Integer monthNumber) {
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
            return '';
        }
        return monthNames[monthNumber - 1];
    }

    // ========== Helper Methods ==========
    private static Messaging.SingleEmailMessage buildMessage(
        Id templateId,
        Id userId,
        String email
    ) {
        if (templateId == null || userId == null || String.isBlank(email)) {
            return null;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTemplateId(templateId);
        mail.setTargetObjectId(userId);
        mail.setSaveAsActivity(false);
        mail.setTreatTargetObjectAsRecipient(true);
        applyOrgWideSender(mail);

        return mail;
    }

    private static Id resolveTemplateId(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_SENDER_EMAIL
            LIMIT 1
        ];
        return owea.isEmpty() ? null : owea[0].Id;
    }

    private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
        Id oweaId = getOrgWideEmailAddressId();
        if (oweaId != null) {
            message.setOrgWideEmailAddressId(oweaId);
        }
    }
}