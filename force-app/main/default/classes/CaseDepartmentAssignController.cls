/**
 * Controller for the caseDepartmentAssign LWC (Case Quick Action).
 *
 * Flow: Department__c picklist (minus "Enquiry") -> active users whose
 * User.Department carries that department -> assign the Case to the chosen
 * user, then fire a custom notification and an email to that user.
 *
 * All SOQL uses WITH SYSTEM_MODE and DML uses AccessLevel.SYSTEM_MODE,
 * so this class REQUIRES API version 61.0 or higher.
 */
public without sharing class CaseDepartmentAssignController {

    /** Department that must never appear in the picklist. */
    @TestVisible private static final String EXCLUDED_DEPARTMENT = 'Enquiry';

    /** Custom Notification Type developer name. Change if a separate type exists for assignment. */
    @TestVisible private static final String NOTIFICATION_TYPE = 'Case_Creation_Push_Notification';

    /** Verified org-wide address. If it is not found the running user's address is used. */
    @TestVisible private static final String ORG_WIDE_EMAIL = 'noreply@utkarshindialimited.in';

    /* ------------------------------------------------------------------ */
    /*  Wrappers                                                          */
    /* ------------------------------------------------------------------ */

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class AssignContext {
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String currentOwnerName;
        @AuraEnabled public String currentDepartment;
        @AuraEnabled public List<Option> departments = new List<Option>();
        /** Non-null means the screen cannot proceed; show this text instead. */
        @AuraEnabled public String blockReason;
    }

    public class AssignResult {
        @AuraEnabled public String ownerName;
        /** Owner change succeeded but a follow-up (notification / email) did not. */
        @AuraEnabled public List<String> warnings = new List<String>();
    }

    /* ------------------------------------------------------------------ */
    /*  Screen data                                                       */
    /* ------------------------------------------------------------------ */

    @AuraEnabled
    public static AssignContext getAssignContext(Id caseId) {
        try {
            AssignContext ctx = new AssignContext();

            if (caseId == null || caseId.getSObjectType() != Case.SObjectType) {
                ctx.blockReason = 'This action did not receive a Case id. Add it to a Case record page.';
                return ctx;
            }

            List<Case> cases = [
                SELECT Id, CaseNumber, Department__c, OwnerId, Owner.Name
                FROM Case
                WHERE Id = :caseId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (cases.isEmpty()) {
                ctx.blockReason = 'Case ' + caseId + ' was not found.';
                return ctx;
            }

            Case cs = cases[0];
            ctx.caseNumber        = cs.CaseNumber;
            ctx.currentOwnerName  = cs.Owner.Name;
            ctx.currentDepartment = cs.Department__c;
            ctx.departments       = departmentOptions();

            if (ctx.departments.isEmpty()) {
                ctx.blockReason = 'No assignable department is configured on the Case Department picklist.';
            }
            return ctx;

        } catch (Exception e) {
            throw auraError('Could not load the departments: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Option> getUsersByDepartment(String department) {
        try {
            List<Option> users = new List<Option>();
            if (String.isBlank(department) || isExcluded(department)) {
                return users;
            }

            // A user may carry several departments in one text field, so match on "contains".
            String searchTerm = '%' + department + '%';

            for (User u : [
                SELECT Id, Name
                FROM User
                WHERE IsActive = TRUE
                  AND Department LIKE :searchTerm
                WITH SYSTEM_MODE
                ORDER BY Name ASC
                LIMIT 500
            ]) {
                users.add(new Option(u.Name, u.Id));
            }
            return users;

        } catch (Exception e) {
            throw auraError('Could not load the users for ' + department + ': ' + e.getMessage());
        }
    }

    /* ------------------------------------------------------------------ */
    /*  Assignment                                                        */
    /* ------------------------------------------------------------------ */

    @AuraEnabled
    public static AssignResult assignCase(Id caseId, String department, Id newOwnerId) {
        try {
            if (caseId == null || caseId.getSObjectType() != Case.SObjectType) {
                throw auraError('This action did not receive a Case id.');
            }
            if (String.isBlank(department) || isExcluded(department) || !validDepartments().contains(department)) {
                throw auraError('"' + department + '" is not an assignable department.');
            }

            // Re-derive the allowed users on the server. Never trust the posted id.
            Boolean allowed = false;
            for (Option opt : getUsersByDepartment(department)) {
                if (opt.value == String.valueOf(newOwnerId)) {
                    allowed = true;
                    break;
                }
            }
            if (!allowed) {
                throw auraError('That user is not an active member of ' + department + '. Reopen the action and pick again.');
            }

            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Priority, Status, OwnerId
                FROM Case
                WHERE Id = :caseId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (cases.isEmpty()) {
                throw auraError('Case ' + caseId + ' was not found.');
            }
            Case cs = cases[0];

            Case toUpdate = new Case(
                Id            = caseId,
                OwnerId       = newOwnerId,
                Department__c = department      // remove this line if the department must stay untouched
            );
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);

            List<User> owners = [
                SELECT Id, Name, Email
                FROM User
                WHERE Id = :newOwnerId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            User newOwner = owners.isEmpty() ? null : owners[0];

            AssignResult result = new AssignResult();
            result.ownerName = newOwner == null ? '' : newOwner.Name;

            // The owner change is already committed. A failure below is reported, not thrown.
            String notifyError = sendNotification(cs, newOwnerId);
            if (notifyError != null) {
                result.warnings.add(notifyError);
            }
            String emailError = sendEmail(cs, newOwner, department);
            if (emailError != null) {
                result.warnings.add(emailError);
            }
            return result;

        } catch (AuraHandledException ahe) {
            throw ahe;                       // keep the real message, do not swallow it
        } catch (Exception e) {
            throw auraError('The assignment did not save: ' + e.getMessage());
        }
    }

    /* ------------------------------------------------------------------ */
    /*  Notification + email                                              */
    /* ------------------------------------------------------------------ */

    /** @return null on success, otherwise a message safe to show the user. */
    private static String sendNotification(Case cs, Id recipientId) {
        try {
            List<CustomNotificationType> types = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (types.isEmpty()) {
                return 'Push notification skipped: notification type "' + NOTIFICATION_TYPE + '" was not found.';
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(types[0].Id);
            notification.setTargetId(cs.Id);
            notification.setTitle('Case ' + cs.CaseNumber + ' assigned to you');
            notification.setBody(
                truncate(String.isBlank(cs.Subject) ? 'No subject' : cs.Subject, 700)
            );
            notification.send(new Set<String>{ String.valueOf(recipientId) });
            return null;

        } catch (Exception e) {
            return 'Push notification failed: ' + e.getMessage();
        }
    }

    /** @return null on success, otherwise a message safe to show the user. */
    private static String sendEmail(Case cs, User newOwner, String department) {
        try {
            if (newOwner == null || String.isBlank(newOwner.Email)) {
                return 'Email skipped: the selected user has no email address.';
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ newOwner.Email });
            mail.setSubject('Case ' + cs.CaseNumber + ' has been assigned to you');
            mail.setSaveAsActivity(false);
            mail.setPlainTextBody(buildEmailBody(cs, newOwner, department));

            List<OrgWideEmailAddress> owea = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = :ORG_WIDE_EMAIL
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }

            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);

            if (!results.isEmpty() && !results[0].isSuccess()) {
                return 'Email failed: ' + results[0].getErrors()[0].getMessage();
            }
            return null;

        } catch (Exception e) {
            return 'Email failed: ' + e.getMessage();
        }
    }

    private static String buildEmailBody(Case cs, User newOwner, String department) {
        String link;
        try {
            link = URL.getOrgDomainUrl().toExternalForm() + '/' + cs.Id;
        } catch (Exception e) {
            link = String.valueOf(cs.Id);
        }

        return 'Hi ' + newOwner.Name + ',\n\n'
            + 'Case ' + cs.CaseNumber + ' is now assigned to you.\n\n'
            + 'Department : ' + department + '\n'
            + 'Subject    : ' + (String.isBlank(cs.Subject) ? '-' : cs.Subject) + '\n'
            + 'Priority   : ' + (String.isBlank(cs.Priority) ? '-' : cs.Priority) + '\n'
            + 'Status     : ' + (String.isBlank(cs.Status) ? '-' : cs.Status) + '\n\n'
            + 'Open the case: ' + link + '\n';
    }

    /* ------------------------------------------------------------------ */
    /*  Helpers                                                           */
    /* ------------------------------------------------------------------ */

    /**
     * Picklist values come from field describe rather than the UI API, so
     * record-type filtering cannot blank the list.
     */
    private static List<Option> departmentOptions() {
        List<Option> options = new List<Option>();
        for (Schema.PicklistEntry entry : Case.Department__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !isExcluded(entry.getValue())) {
                options.add(new Option(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    private static Set<String> validDepartments() {
        Set<String> values = new Set<String>();
        for (Option o : departmentOptions()) {
            values.add(o.value);
        }
        return values;
    }

    private static Boolean isExcluded(String department) {
        return department != null && department.trim().equalsIgnoreCase(EXCLUDED_DEPARTMENT);
    }

    private static String truncate(String value, Integer maxLength) {
        return (value != null && value.length() > maxLength) ? value.substring(0, maxLength) : value;
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}