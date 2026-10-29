/**
 * @description Sends emails to the Tender's Contact (Tender User) when
 *              participation request / HOD decision fields change on Tender__c.
 * @author Rani Mate
 * @date 2026-08-14
 *
 * ASSUMPTIONS (verify / adjust to match your org's actual picklist values):
 *  - Tender_User_Choice__c holds the user's *request type* and stays set to
 *    whichever request is currently pending review:
 *      'Direct Participation'            -> user requested to participate
 *      'Direct Participation Rejection'  -> user requested to withdraw/reject
 *  - HOD_Choice__c holds the HOD's decision on whatever request is pending:
 *      'Approved' / 'Rejected'
 *  - Recipient (Tender User) = Contact__c (Lookup(Contact))
 *  - Remarks merge field is sourced from HOD_Comments__c
 *  - "New Tender Alert" fires unconditionally on insert. If it should only
 *    fire for certain stages/departments, add that filter in
 *    shouldSendNewTenderAlert().
 */
public without sharing class TenderStatusEmailHandler {

    // ===== Tender_User_Choice__c values =====
    public static final String CHOICE_DIRECT_PARTICIPATION = 'Direct Participation';
    public static final String CHOICE_DIRECT_PARTICIPATION_REJECTION = 'Direct Participation Rejection';

    // ===== HOD_Choice__c values =====
    public static final String HOD_APPROVED = 'Approved';
    public static final String HOD_REJECTED = 'Rejected';

    // ===== Templates (DeveloperName) =====
    public static final String TEMPLATE_NEW_TENDER_ALERT =
        'New_Tender_Alert_A_new_tender_relevant_1786621926967';
    public static final String TEMPLATE_PARTICIPATION_SUBMITTED =
        'TendeDirect_Participation_approval_submission_1786622243328';
    public static final String TEMPLATE_REJECTION_REQUEST_SUBMITTED =
        'Tender_Direct_Participation_Rejection_1786622679452';
    public static final String TEMPLATE_PARTICIPATION_ACCEPTED =
        'Direct_Participation_Accepted_1786628138227';
    public static final String TEMPLATE_REJECTION_REQUEST_APPROVED =
        'Direct_Participation_Rejection_request_approved_1786624395212';
    public static final String TEMPLATE_PARTICIPATION_REQUEST_REJECTED =
        'Direct_Participation_request_rejected_1786624627244';
    public static final String TEMPLATE_REJECTION_REQUEST_REJECTED =
        'Direct_Participation_Rejection_request_rejected_1786624972141';

    public static final String ORG_WIDE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

    // ===== ADDED: Department CRM Head templates (DeveloperName) =====
    // These mirror 3 of the same transitions above but notify the CRM Head instead of the Tender User.
    public static final String TEMPLATE_CRM_HEAD_NEW_TENDER_ALERT =
        'New_Tender_Alert_A_new_tender_relevant_to_your_department_has_b_1786778850618';
    public static final String TEMPLATE_CRM_HEAD_PARTICIPATION_ACCEPTED =
        'Direct_Participation_Accepted_1786623262023';
    public static final String TEMPLATE_CRM_HEAD_REJECTION_REQUEST_APPROVED =
        'Direct_Participation_Rejection_accepted_CRM_Head_1786779740569';
    public static final String TEMPLATE_CRM_HEAD_L1_BIDDER_DECLARED =
        'L1_Bidder_Declared_CRM_Dept_Head_1786779877847';

    // ADDED ASSUMPTION: L1 Bidder Declared is tracked on Tender__c via
    // Tender_Stage__c (Status). Adjust the value/field if it's tracked differently.
    public static final String STAGE_L1_BIDDER_DECLARED = 'L1 Bidder Declared';

    // ===== ADDED: Department HOD templates (DeveloperName) =====
    public static final String TEMPLATE_HOD_NEW_TENDER_ALERT =
        'New_Tender_Alert_A_new_tender_relevant_to_your_department_1786625246055';
    public static final String TEMPLATE_HOD_PARTICIPATION_AWAITING =
        'Tender_Direct_Participation_Awaiting_Approval_1786625465484';
    public static final String TEMPLATE_HOD_REJECTION_AWAITING =
        'Tender_Direct_Participation_Rejection_Awaiting_Approval_1786625682691';
    public static final String TEMPLATE_HOD_L1_BIDDER_DECLARED =
        'L1_Bidder_Declared_1786625858550';

    @TestVisible
    private static Id testTemplateIdOverride;

    public static void handleAfterInsert(List<Tender__c> newRecords) {
        processRecords(newRecords, null);
    }

    public static void handleAfterUpdate(
        List<Tender__c> newRecords,
        Map<Id, Tender__c> oldRecordsById
    ) {
        processRecords(newRecords, oldRecordsById);
    }

    @TestVisible
    private static void processRecords(
        List<Tender__c> newRecords,
        Map<Id, Tender__c> oldRecordsById
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Map<String, List<Tender__c>> tendersByTemplate = new Map<String, List<Tender__c>>();

        for (Tender__c t : newRecords) {
            Tender__c oldT = oldRecordsById == null ? null : oldRecordsById.get(t.Id);

            String templateName = getTemplateForChange(t, oldT, oldRecordsById == null);
            if (templateName == null) {
                continue;
            }

            if (!tendersByTemplate.containsKey(templateName)) {
                tendersByTemplate.put(templateName, new List<Tender__c>());
            }
            tendersByTemplate.get(templateName).add(t);
        }

        for (String templateName : tendersByTemplate.keySet()) {
            sendEmails(tendersByTemplate.get(templateName), templateName);
        }

        // ADDED: parallel notification to the Department CRM Head for the
        // same 3 transitions (new tender / participation accepted / rejection accepted).
        // Reuses the same tendersByTemplate grouping - existing branch above is untouched.
        for (String templateName : tendersByTemplate.keySet()) {
            String crmHeadTemplate = getCrmHeadTemplateFor(templateName);
            if (crmHeadTemplate != null) {
                sendCrmHeadEmails(tendersByTemplate.get(templateName), crmHeadTemplate);
            }
        }

        // ADDED: L1 Bidder Declared is CRM-Head-only (no Tender User template
        // for it), so it's detected and dispatched separately from the
        // tendersByTemplate grouping above.
        List<Tender__c> l1BidderDeclaredTenders = new List<Tender__c>();
        for (Tender__c t : newRecords) {
            Tender__c oldT = oldRecordsById == null ? null : oldRecordsById.get(t.Id);
            if (qualifiesAsL1BidderDeclared(t, oldT)) {
                l1BidderDeclaredTenders.add(t);
            }
        }
        if (!l1BidderDeclaredTenders.isEmpty()) {
            sendCrmHeadEmails(l1BidderDeclaredTenders, TEMPLATE_CRM_HEAD_L1_BIDDER_DECLARED);
        }

        // ADDED: parallel notification to the Department HOD.
        dispatchHodEmails(newRecords, oldRecordsById);
    }

    // ADDED
    @TestVisible
    private static void dispatchHodEmails(
        List<Tender__c> newRecords,
        Map<Id, Tender__c> oldRecordsById
    ) {
        Boolean isInsert = oldRecordsById == null;
        List<Tender__c> newTenderAlerts = new List<Tender__c>();
        List<Tender__c> participationAwaiting = new List<Tender__c>();
        List<Tender__c> rejectionAwaiting = new List<Tender__c>();
        List<Tender__c> l1BidderDeclared = new List<Tender__c>();

        for (Tender__c t : newRecords) {
            Tender__c oldT = isInsert ? null : oldRecordsById.get(t.Id);

            if (isInsert && shouldSendNewTenderAlert(t)) {
                newTenderAlerts.add(t);
            }
            if (qualifiesForHodParticipationAwaiting(t, oldT)) {
                participationAwaiting.add(t);
            }
            if (qualifiesForHodRejectionAwaiting(t, oldT)) {
                rejectionAwaiting.add(t);
            }
            if (qualifiesAsL1BidderDeclared(t, oldT)) {
                l1BidderDeclared.add(t);
            }
        }

        if (!newTenderAlerts.isEmpty()) {
            sendHodEmails(newTenderAlerts, TEMPLATE_HOD_NEW_TENDER_ALERT);
        }
        if (!participationAwaiting.isEmpty()) {
            sendHodEmails(participationAwaiting, TEMPLATE_HOD_PARTICIPATION_AWAITING);
        }
        if (!rejectionAwaiting.isEmpty()) {
            sendHodEmails(rejectionAwaiting, TEMPLATE_HOD_REJECTION_AWAITING);
        }
        if (!l1BidderDeclared.isEmpty()) {
            sendHodEmails(l1BidderDeclared, TEMPLATE_HOD_L1_BIDDER_DECLARED);
        }
    }

    // ADDED
    @TestVisible
    private static Boolean qualifiesForHodParticipationAwaiting(Tender__c t, Tender__c oldT) {
        if (t == null || oldT == null) {
            return false;
        }
        return t.Tender_User_Choice__c == CHOICE_DIRECT_PARTICIPATION
            && t.Tender_User_Choice__c != oldT.Tender_User_Choice__c;
    }

    // ADDED
    @TestVisible
    private static Boolean qualifiesForHodRejectionAwaiting(Tender__c t, Tender__c oldT) {
        if (t == null || oldT == null) {
            return false;
        }
        return t.Tender_User_Choice__c == CHOICE_DIRECT_PARTICIPATION_REJECTION
            && t.Tender_User_Choice__c != oldT.Tender_User_Choice__c;
    }

    // ADDED
    @TestVisible
    private static Boolean qualifiesAsL1BidderDeclared(Tender__c t, Tender__c oldT) {
        if (t == null || oldT == null) {
            return false;
        }
        return t.Tender_Stage__c == STAGE_L1_BIDDER_DECLARED
            && oldT.Tender_Stage__c != STAGE_L1_BIDDER_DECLARED;
    }

    // ADDED
    @TestVisible
    private static String getCrmHeadTemplateFor(String userTemplateDeveloperName) {
        if (userTemplateDeveloperName == TEMPLATE_NEW_TENDER_ALERT) {
            return TEMPLATE_CRM_HEAD_NEW_TENDER_ALERT;
        }
        if (userTemplateDeveloperName == TEMPLATE_PARTICIPATION_ACCEPTED) {
            return TEMPLATE_CRM_HEAD_PARTICIPATION_ACCEPTED;
        }
        if (userTemplateDeveloperName == TEMPLATE_REJECTION_REQUEST_APPROVED) {
            return TEMPLATE_CRM_HEAD_REJECTION_REQUEST_APPROVED;
        }
        return null; // no CRM Head email for this transition (e.g. submission/rejected templates)
    }

    @TestVisible
    private static String getTemplateForChange(Tender__c t, Tender__c oldT, Boolean isInsert) {
        if (t == null || t.Contact__c == null) {
            return null;
        }

        // 1) New Tender Alert - on insert only
        if (isInsert) {
            return shouldSendNewTenderAlert(t) ? TEMPLATE_NEW_TENDER_ALERT : null;
        }

        if (oldT == null) {
            return null;
        }

        String newUserChoice = t.Tender_User_Choice__c;
        String oldUserChoice = oldT.Tender_User_Choice__c;
        String newHodChoice  = t.HOD_Choice__c;
        String oldHodChoice  = oldT.HOD_Choice__c;

        // 2) User just submitted a new request (Tender_User_Choice__c changed)
        if (newUserChoice != oldUserChoice) {
            if (newUserChoice == CHOICE_DIRECT_PARTICIPATION) {
                return TEMPLATE_PARTICIPATION_SUBMITTED;
            }
            if (newUserChoice == CHOICE_DIRECT_PARTICIPATION_REJECTION) {
                return TEMPLATE_REJECTION_REQUEST_SUBMITTED;
            }
        }

        // 3) HOD just made a decision (HOD_Choice__c changed) -
        //    which request it applies to comes from the *current* Tender_User_Choice__c
        if (newHodChoice != oldHodChoice) {
            if (newUserChoice == CHOICE_DIRECT_PARTICIPATION) {
                if (newHodChoice == HOD_APPROVED) {
                    return TEMPLATE_PARTICIPATION_ACCEPTED;
                }
                if (newHodChoice == HOD_REJECTED) {
                    return TEMPLATE_PARTICIPATION_REQUEST_REJECTED;
                }
            }
            if (newUserChoice == CHOICE_DIRECT_PARTICIPATION_REJECTION) {
                if (newHodChoice == HOD_APPROVED) {
                    return TEMPLATE_REJECTION_REQUEST_APPROVED;
                }
                if (newHodChoice == HOD_REJECTED) {
                    return TEMPLATE_REJECTION_REQUEST_REJECTED;
                }
            }
        }

        return null;
    }

    /**
     * Gate for the "New Tender Alert" email on insert.
     * Currently unconditional - add stage/department filters here if needed,
     * e.g.: return t.Tender_Stage__c == 'New';
     */
    private static Boolean shouldSendNewTenderAlert(Tender__c t) {
        return true;
    }

    private static void sendEmails(List<Tender__c> tenders, String templateDeveloperName) {
        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) {
            System.debug('Template not found: ' + templateDeveloperName);
            return;
        }

        Id oweaId = getOrgWideEmailAddressId();

        Set<Id> tenderIds = new Set<Id>();
        for (Tender__c t : tenders) {
            tenderIds.add(t.Id);
        }

        List<Tender__c> tendersWithDetails = [
            SELECT Id, Contact__c, Contact__r.Email
            FROM Tender__c
            WHERE Id IN :tenderIds
            AND Contact__r.Email != null
        ];

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (Tender__c t : tendersWithDetails) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setTemplateId(templateId);
            mail.setTargetObjectId(t.Contact__c);   // Tender User (Contact)
            mail.setWhatId(t.Id);                   // Tender record - drives merge fields
            mail.setSaveAsActivity(false);
            mail.setTreatTargetObjectAsRecipient(true);

            if (oweaId != null) {
                mail.setOrgWideEmailAddressId(oweaId);
            }
            messages.add(mail);
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages);
            } catch (Exception e) {
                System.debug('Error sending Tender emails: ' + e.getMessage());
            }
        }
    }

    // ADDED: sends to the Department CRM Head resolved via custom metadata,
    // since the CRM Head isn't a Salesforce Contact/Lead/User (setTargetObjectId
    // isn't usable here - the recipient is derived from Department_Name__c).
    private static void sendCrmHeadEmails(List<Tender__c> tenders, String templateDeveloperName) {
        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) {
            System.debug('CRM Head template not found: ' + templateDeveloperName);
            return;
        }

        Id oweaId = getOrgWideEmailAddressId();

        Set<Id> tenderIds = new Set<Id>();
        for (Tender__c t : tenders) {
            tenderIds.add(t.Id);
        }

        List<Tender__c> tendersWithDetails = [
            SELECT Id, CRM_User_Email_Formula__c
            FROM Tender__c
            WHERE Id IN :tenderIds
        ];

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (Tender__c t : tendersWithDetails) {
            String crmHeadEmail = t.CRM_User_Email_Formula__c;
            if (String.isBlank(crmHeadEmail)) {
                System.debug(
                    'CRM Head email not resolved for Tender ' + t.Id
                );
                continue;
            }

            Messaging.SingleEmailMessage mail = buildFormulaRecipientMessage(
                templateId,
                t.Id,
                crmHeadEmail.trim(),
                oweaId
            );
            if (mail != null) {
                messages.add(mail);
            }
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages);
            } catch (Exception e) {
                System.debug('Error sending Tender CRM Head emails: ' + e.getMessage());
            }
        }
    }

    // ADDED: sends to the Department HOD resolved via HOD_User_Email_Formula__c.
    private static void sendHodEmails(List<Tender__c> tenders, String templateDeveloperName) {
        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) {
            System.debug('HOD template not found: ' + templateDeveloperName);
            return;
        }

        Id oweaId = getOrgWideEmailAddressId();

        Set<Id> tenderIds = new Set<Id>();
        for (Tender__c t : tenders) {
            tenderIds.add(t.Id);
        }

        List<Tender__c> tendersWithDetails = [
            SELECT Id, HOD_User_Email_Formula__c
            FROM Tender__c
            WHERE Id IN :tenderIds
        ];

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (Tender__c t : tendersWithDetails) {
            String hodEmail = t.HOD_User_Email_Formula__c;
            if (String.isBlank(hodEmail)) {
                System.debug('HOD email not resolved for Tender ' + t.Id);
                continue;
            }

            Messaging.SingleEmailMessage mail = buildFormulaRecipientMessage(
                templateId,
                t.Id,
                hodEmail.trim(),
                oweaId
            );
            if (mail != null) {
                messages.add(mail);
            }
        }

        if (!messages.isEmpty()) {
            try {
                Messaging.sendEmail(messages);
            } catch (Exception e) {
                System.debug('Error sending Tender HOD emails: ' + e.getMessage());
            }
        }
    }

    // ADDED
    private static Messaging.SingleEmailMessage buildFormulaRecipientMessage(
        Id templateId,
        Id tenderId,
        String recipientEmail,
        Id oweaId
    ) {
        if (templateId == null || tenderId == null || String.isBlank(recipientEmail)) {
            return null;
        }

        Messaging.SingleEmailMessage mail;
        try {
            mail = Messaging.renderStoredEmailTemplate(templateId, null, tenderId);
        } catch (Exception e) {
            System.debug('Formula recipient template render failed: ' + e.getMessage());
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