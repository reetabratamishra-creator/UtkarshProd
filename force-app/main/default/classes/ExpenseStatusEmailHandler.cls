/**
 * @description Sends emails to Employee when Expense status changes
 * (Submitted / Approved by HOD / Rejected by HOD / Approved by HR / Rejected by HR /
 * Approved by ED / Rejected by ED)
 * @author Rani Mate
 * @date 2026-08-14
 */
public without sharing class ExpenseStatusEmailHandler {
    // ===== Status Values (Adjust these according to your org) =====
    // Approval by a stage is represented by the move to the next stage's pending status.
    public static final String STATUS_SUBMITTED = 'Pending HOD Approval';
    public static final String STATUS_APPROVED_BY_HOD = 'Pending HR Approval';
    public static final String STATUS_REJECTED_BY_HOD = 'Rejected by HOD';
    public static final String STATUS_APPROVED_BY_HR = 'Pending ED Approval';
    public static final String STATUS_REJECTED_BY_HR = 'Rejected by HR';
    public static final String STATUS_APPROVED_BY_ED = 'Approved by ED';
    public static final String STATUS_REJECTED_BY_ED = 'Rejected by ED';
    // ===== Templates =====
    public static final String TEMPLATE_SUBMITTED =
        'Expense_submitted_Your_expense_claim_has_been_submitte_1786634065001';
    public static final String TEMPLATE_APPROVED_HOD =
        'Expense_approved_by_HOD_Your_expense_claim_has_been_approved_1786634230389';
    public static final String TEMPLATE_REJECTED_HOD =
        'Expense_rejected_by_HOD_Your_expense_claim_has_been_rejected_by_y_1786634318658';
    public static final String TEMPLATE_APPROVED_HR =
        'Expense_approved_by_HR_Your_expense_claim_has_been_approve_1786634464645';
    public static final String TEMPLATE_REJECTED_HR =
        'Expense_rejected_by_HR_Your_expense_claim_has_been_rejected_1786636244825';
    public static final String TEMPLATE_APPROVED_ED =
        'Expense_approved_by_ED_Your_expense_claim_has_been_approved_1791441794563';
    public static final String TEMPLATE_REJECTED_ED =
        'Expense_rejected_by_ED_Your_expense_claim_has_been_rejected_1791441954052';
    // ===== ADDED: HOD / HR approver templates =====
    public static final String TEMPLATE_HOD_NEW_SUBMITTED =
        'New_expense_submitted_Expense_claim_submitted_by_Employee_1786636633300';
    public static final String TEMPLATE_HR_AWAITING_APPROVAL =
        'New_expense_approved_by_HOD_Awaiting_HR_approval_1786637047775';
    public static final String HR_PROFILE_NAME = 'Utkarsh HR';
    public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';
    @TestVisible
    private static Id testTemplateIdOverride;
    public static void handleAfterInsert(List<Expense__c> newRecords) {
        processRecords(newRecords, null);
    }
    public static void handleAfterUpdate(
        List<Expense__c> newRecords,
        Map<Id, Expense__c> oldRecordsById
    ) {
        processRecords(newRecords, oldRecordsById);
    }
    @TestVisible
    private static void processRecords(
        List<Expense__c> newRecords,
        Map<Id, Expense__c> oldRecordsById
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        Map<String, List<Expense__c>> expensesByTemplate = new Map<String, List<Expense__c>>();
        for (Expense__c exp : newRecords) {
            Expense__c oldExp = oldRecordsById == null ? null : oldRecordsById.get(exp.Id);
            String templateName = getTemplateForStatusChange(exp, oldExp);
            if (templateName == null) {
                continue;
            }
            if (!expensesByTemplate.containsKey(templateName)) {
                expensesByTemplate.put(templateName, new List<Expense__c>());
            }
            expensesByTemplate.get(templateName).add(exp);
        }
        for (String templateName : expensesByTemplate.keySet()) {
            sendEmails(expensesByTemplate.get(templateName), templateName);
        }
        // ADDED: parallel notifications to HOD / HR (employee emails above are untouched).
        sendHodAndHrEmails(newRecords, oldRecordsById);
    }
    @TestVisible
    private static String getTemplateForStatusChange(Expense__c exp, Expense__c oldExp) {
        if (exp == null || exp.Employee__c == null) {
            return null;
        }
        String newStatus = exp.Status__c;
        String oldStatus = oldExp == null ? null : oldExp.Status__c;
        // Only fire when Status actually changes
        if (newStatus == oldStatus) {
            return null;
        }
        if (newStatus == STATUS_SUBMITTED) {
            return TEMPLATE_SUBMITTED;
        }
        if (newStatus == STATUS_APPROVED_BY_HOD) {
            return TEMPLATE_APPROVED_HOD;
        }
        if (newStatus == STATUS_REJECTED_BY_HOD) {
            return TEMPLATE_REJECTED_HOD;
        }
        if (newStatus == STATUS_APPROVED_BY_HR) {
            return TEMPLATE_APPROVED_HR;
        }
        if (newStatus == STATUS_REJECTED_BY_HR) {
            return TEMPLATE_REJECTED_HR;
        }
        if (newStatus == STATUS_APPROVED_BY_ED) {
            return TEMPLATE_APPROVED_ED;
        }
        if (newStatus == STATUS_REJECTED_BY_ED) {
            return TEMPLATE_REJECTED_ED;
        }
        return null;
    }
    // ADDED
    @TestVisible
    private static void sendHodAndHrEmails(
        List<Expense__c> newRecords,
        Map<Id, Expense__c> oldRecordsById
    ) {
        List<Expense__c> submittedForHod = new List<Expense__c>();
        List<Expense__c> approvedByHodForHr = new List<Expense__c>();
        for (Expense__c exp : newRecords) {
            Expense__c oldExp = oldRecordsById == null ? null : oldRecordsById.get(exp.Id);
            if (qualifiesForHodSubmittedNotification(exp, oldExp)) {
                submittedForHod.add(exp);
            }
            if (qualifiesForHrAwaitingApprovalNotification(exp, oldExp)) {
                approvedByHodForHr.add(exp);
            }
        }
        if (!submittedForHod.isEmpty()) {
            sendFormulaRecipientEmails(
                submittedForHod,
                TEMPLATE_HOD_NEW_SUBMITTED,
                'HOD_User_Email_Formula__c'
            );
        }
        if (!approvedByHodForHr.isEmpty()) {
            sendHrAwaitingApprovalEmails(approvedByHodForHr);
        }
    }
    // ADDED
    @TestVisible
    private static Boolean qualifiesForHodSubmittedNotification(
        Expense__c exp,
        Expense__c oldExp
    ) {
        if (exp == null || exp.Employee__c == null) {
            return false;
        }
        String oldStatus = oldExp == null ? null : oldExp.Status__c;
        return exp.Status__c == STATUS_SUBMITTED && exp.Status__c != oldStatus;
    }
    // ADDED
    @TestVisible
    private static Boolean qualifiesForHrAwaitingApprovalNotification(
        Expense__c exp,
        Expense__c oldExp
    ) {
        if (exp == null || exp.Employee__c == null) {
            return false;
        }
        String oldStatus = oldExp == null ? null : oldExp.Status__c;
        return exp.Status__c == STATUS_APPROVED_BY_HOD && exp.Status__c != oldStatus;
    }
    // ADDED
    private static void sendFormulaRecipientEmails(
        List<Expense__c> expenses,
        String templateDeveloperName,
        String emailFieldApiName
    ) {
        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) {
            System.debug('Template not found: ' + templateDeveloperName);
            return;
        }
        Id oweaId = getOrgWideEmailAddressId();
        Set<Id> expenseIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            expenseIds.add(exp.Id);
        }
        String query =
            'SELECT Id, ' +
            emailFieldApiName +
            ' FROM Expense__c WHERE Id IN :expenseIds';
        List<Expense__c> expensesWithDetails = Database.query(query);
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Expense__c exp : expensesWithDetails) {
            String recipientEmail = (String) exp.get(emailFieldApiName);
            if (String.isBlank(recipientEmail)) {
                System.debug('Recipient email not resolved for Expense ' + exp.Id);
                continue;
            }
            Messaging.SingleEmailMessage mail = buildFormulaRecipientMessage(
                templateId,
                exp.Id,
                recipientEmail.trim(),
                oweaId
            );
            if (mail != null) {
                messages.add(mail);
            }
        }
        sendMessageBatch(messages, 'Expense HOD');
    }
    // ADDED
    private static void sendHrAwaitingApprovalEmails(List<Expense__c> expenses) {
        Id templateId = resolveTemplateId(TEMPLATE_HR_AWAITING_APPROVAL);
        if (templateId == null) {
            System.debug('HR template not found: ' + TEMPLATE_HR_AWAITING_APPROVAL);
            return;
        }
        List<String> hrEmails = resolveHrRecipientEmails();
        if (hrEmails.isEmpty()) {
            System.debug('No active HR recipients found for profile ' + HR_PROFILE_NAME);
            return;
        }
        Id oweaId = getOrgWideEmailAddressId();
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Expense__c exp : expenses) {
            for (String hrEmail : hrEmails) {
                Messaging.SingleEmailMessage mail = buildFormulaRecipientMessage(
                    templateId,
                    exp.Id,
                    hrEmail,
                    oweaId
                );
                if (mail != null) {
                    messages.add(mail);
                }
            }
        }
        sendMessageBatch(messages, 'Expense HR');
    }
    // ADDED
    private static List<String> resolveHrRecipientEmails() {
        List<String> emails = new List<String>();
        for (User hrUser : [
            SELECT Email
            FROM User
            WHERE IsActive = TRUE
            AND Email != NULL
            AND Profile.Name = :HR_PROFILE_NAME
        ]) {
            emails.add(hrUser.Email.trim());
        }
        return emails;
    }
    // ADDED
    private static Messaging.SingleEmailMessage buildFormulaRecipientMessage(
        Id templateId,
        Id expenseId,
        String recipientEmail,
        Id oweaId
    ) {
        if (templateId == null || expenseId == null || String.isBlank(recipientEmail)) {
            return null;
        }
        Messaging.SingleEmailMessage mail;
        try {
            mail = Messaging.renderStoredEmailTemplate(templateId, null, expenseId);
        } catch (Exception e) {
            System.debug('Template render failed: ' + e.getMessage());
            return null;
        }
        mail.setTargetObjectId(null);
        mail.setToAddresses(new List<String>{ recipientEmail });
        mail.setSaveAsActivity(false);
        mail.setTreatTargetObjectAsRecipient(false);
        if (oweaId != null) {
            mail.setOrgWideEmailAddressId(oweaId);
        }
        return mail;
    }
    private static void sendEmails(List<Expense__c> expenses, String templateDeveloperName) {
    Id templateId = resolveTemplateId(templateDeveloperName);
    if (templateId == null) {
        System.debug('Template not found: ' + templateDeveloperName);
        return;
    }
    Set<Id> expenseIds = new Set<Id>();
    for (Expense__c exp : expenses) {
        expenseIds.add(exp.Id);
    }
    List<Expense__c> expensesWithDetails = [
        SELECT Id, Employee__c, Employee__r.Email, Remark__c
        FROM Expense__c
        WHERE Id IN :expenseIds
        AND Employee__r.Email != null
    ];
    Id oweaId = getOrgWideEmailAddressId();
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    for (Expense__c exp : expensesWithDetails) {
        Messaging.SingleEmailMessage mail;
        try {
            mail = Messaging.renderStoredEmailTemplate(
                templateId,
                null, // whoId
                exp.Id // whatId = Expense
            );
        } catch (Exception e) {
            System.debug('Employee template render failed: ' + e.getMessage());
            continue;
        }
        mail.setToAddresses(new List<String>{ exp.Employee__r.Email });
        mail.setSaveAsActivity(false);
        mail.setTreatTargetObjectAsRecipient(false);
        if (oweaId != null) {
            mail.setOrgWideEmailAddressId(oweaId);
        }
        messages.add(mail);
    }
    sendMessageBatch(messages, 'Expense employee');
}
    // ADDED
    private static void sendMessageBatch(
        List<Messaging.SingleEmailMessage> messages,
        String contextLabel
    ) {
        if (messages.isEmpty()) {
            return;
        }
        try {
            Messaging.sendEmail(messages);
        } catch (Exception e) {
            System.debug('Error sending ' + contextLabel + ' emails: ' + e.getMessage());
        }
    }
    private static Id resolveTemplateId(String developerName) {
        if (Test.isRunningTest() && testTemplateIdOverride != null) {
            return testTemplateIdOverride;
        }
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
}