/**
 * Controller for the caseOwnerReassign LWC (Case Quick Action).
 *
 * Escalation rules (Internal_Ticket_Matrix__c.Name = Case.Module__c):
 *   - Owner = L1__c  -> options are L2__c and L3__c of that matrix row
 *   - Owner = L2__c  -> options are L1__c and L3__c of that matrix row
 *   - Owner = L3__c  -> options are every unique L1__c / L2__c across ALL matrix rows
 *   - Owner = anyone else (manual reassign / queue) -> L1, L2, L3 of that matrix row
 *
 * All SOQL uses WITH SYSTEM_MODE and DML uses AccessLevel.SYSTEM_MODE,
 * so this class REQUIRES API version 61.0 or higher.
 */
public without sharing class CaseOwnerReassignController {

    @TestVisible private static final String LVL_L1    = 'L1';
    @TestVisible private static final String LVL_L2    = 'L2';
    @TestVisible private static final String LVL_L3    = 'L3';
    @TestVisible private static final String LVL_OTHER = 'OTHER';

    /* ------------------------------------------------------------------ */
    /*  Wrappers                                                          */
    /* ------------------------------------------------------------------ */

    public class OwnerOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String level;

        public OwnerOption(Id userId, String userName, String level) {
            this.value = String.valueOf(userId);
            this.level = level;
            this.label = userName;
        }

        public Integer compareTo(Object other) {
            return this.label.compareTo(((OwnerOption) other).label);
        }
    }

    public class ReassignContext {
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String moduleName;
        @AuraEnabled public String currentOwnerId;
        @AuraEnabled public String currentOwnerName;
        @AuraEnabled public String currentLevel;
        @AuraEnabled public List<OwnerOption> options = new List<OwnerOption>();
        /** Non-null means the screen cannot offer a reassignment; show this text instead. */
        @AuraEnabled public String blockReason;
    }

    /* ------------------------------------------------------------------ */
    /*  Entry points                                                      */
    /* ------------------------------------------------------------------ */

    @AuraEnabled
    public static ReassignContext getReassignContext(Id caseId) {
        try {
            return buildContext(caseId);
        } catch (Exception e) {
            throw auraError('Could not load the escalation options: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String reassignOwner(Id caseId, Id newOwnerId) {
        try {
            // Re-derive the allowed set on the server. Never trust the value posted by the client.
            ReassignContext ctx = buildContext(caseId);

            if (String.isNotBlank(ctx.blockReason)) {
                throw auraError(ctx.blockReason);
            }

            Boolean allowed = false;
            for (OwnerOption opt : ctx.options) {
                if (opt.value == String.valueOf(newOwnerId)) {
                    allowed = true;
                    break;
                }
            }
            if (!allowed) {
                throw auraError('That user is not a valid escalation target for this Case. Reopen the action and pick again.');
            }

            Database.update(new Case(Id = caseId, OwnerId = newOwnerId), AccessLevel.SYSTEM_MODE);

            List<User> newOwner = [
                SELECT Id, Name
                FROM User
                WHERE Id = :newOwnerId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return newOwner.isEmpty() ? '' : newOwner[0].Name;

        } catch (AuraHandledException ahe) {
            throw ahe;                       // keep the real message, do not swallow it
        } catch (Exception e) {
            throw auraError('The owner change did not save: ' + e.getMessage());
        }
    }

    /* ------------------------------------------------------------------ */
    /*  Core logic                                                        */
    /* ------------------------------------------------------------------ */

    @TestVisible
    private static ReassignContext buildContext(Id caseId) {
        ReassignContext ctx = new ReassignContext();

        List<Case> cases = [
            SELECT Id, CaseNumber, Module__c, OwnerId, Owner.Name
            FROM Case
            WHERE Id = :caseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            ctx.blockReason = 'This Case record no longer exists.';
            return ctx;
        }

        Case cs = cases[0];
        ctx.caseNumber       = cs.CaseNumber;
        ctx.moduleName       = cs.Module__c;
        ctx.currentOwnerId   = cs.OwnerId;
        ctx.currentOwnerName = cs.Owner.Name;
        ctx.currentLevel     = LVL_OTHER;

        if (String.isBlank(cs.Module__c)) {
            ctx.blockReason = 'Set the Module on this Case first. The escalation matrix is resolved from it.';
            return ctx;
        }

        List<Internal_Ticket_Matrix__c> matrixList = [
            SELECT Id, Name,
                   L1__c, L1__r.Name,
                   L2__c, L2__r.Name,
                   L3__c, L3__r.Name
            FROM Internal_Ticket_Matrix__c
            WHERE Name = :cs.Module__c
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (matrixList.isEmpty()) {
            ctx.blockReason = 'No Internal Ticket Matrix record matches the module "' + cs.Module__c + '".';
            return ctx;
        }

        Internal_Ticket_Matrix__c mtx = matrixList[0];
        Id ownerId = cs.OwnerId;

        if (ownerId == mtx.L1__c) {
            ctx.currentLevel = LVL_L1;
        } else if (ownerId == mtx.L2__c) {
            ctx.currentLevel = LVL_L2;
        } else if (ownerId == mtx.L3__c) {
            ctx.currentLevel = LVL_L3;
        }

        Map<Id, OwnerOption> optionsByUser = new Map<Id, OwnerOption>();

        if (ctx.currentLevel == LVL_L3) {
            // Owner sits at the top of this module's ladder -> offer every L1 / L2 in the org.
            for (Internal_Ticket_Matrix__c row : [
                SELECT Name, L1__c, L1__r.Name, L2__c, L2__r.Name
                FROM Internal_Ticket_Matrix__c
                WHERE (L1__c != NULL OR L2__c != NULL)
                WITH SYSTEM_MODE
                ORDER BY Name ASC
            ]) {
                addOption(optionsByUser, row.L1__c, row.L1__r?.Name, LVL_L1, ownerId);
                addOption(optionsByUser, row.L2__c, row.L2__r?.Name, LVL_L2, ownerId);
            }
        } else if (ctx.currentLevel == LVL_L1) {
            addOption(optionsByUser, mtx.L2__c, mtx.L2__r?.Name, LVL_L2, ownerId);
            addOption(optionsByUser, mtx.L3__c, mtx.L3__r?.Name, LVL_L3, ownerId);
        } else if (ctx.currentLevel == LVL_L2) {
            addOption(optionsByUser, mtx.L1__c, mtx.L1__r?.Name, LVL_L1, ownerId);
            addOption(optionsByUser, mtx.L3__c, mtx.L3__r?.Name, LVL_L3, ownerId);
        } else {
            // Owner is a queue or a user outside this module's matrix -> offer the whole ladder.
            addOption(optionsByUser, mtx.L1__c, mtx.L1__r?.Name, LVL_L1, ownerId);
            addOption(optionsByUser, mtx.L2__c, mtx.L2__r?.Name, LVL_L2, ownerId);
            addOption(optionsByUser, mtx.L3__c, mtx.L3__r?.Name, LVL_L3, ownerId);
        }

        ctx.options = optionsByUser.values();
        ctx.options.sort();

        if (ctx.options.isEmpty()) {
            ctx.blockReason = 'The Internal Ticket Matrix for "' + cs.Module__c
                + '" has no other escalation user configured.';
        }
        return ctx;
    }

    /** Adds a user to the option map, skipping blanks, the current owner and duplicates. */
    private static void addOption(Map<Id, OwnerOption> acc, Id userId, String userName, String level, Id currentOwnerId) {
        if (userId == null || userId == currentOwnerId || acc.containsKey(userId)) {
            return;
        }
        acc.put(userId, new OwnerOption(userId, String.isBlank(userName) ? 'Unknown User' : userName, level));
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}