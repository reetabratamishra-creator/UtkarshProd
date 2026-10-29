/**
 * @description Gives the Case creator a share when the owner differs from the creator.
 *
 *              Two record types, two rules:
 *
 *              - "Case" (complaints): Edit access, kept for the life of the record.
 *              - "Internal_Ticket": Read access, kept only until the ticket is closed.
 *                An internal ticket is owned by its L1 handler, so without this the person
 *                who raised it loses sight of it the moment it is created.
 *
 *              The after-update path does two jobs. The platform deletes manual shares
 *              whenever a record's owner changes, so an owner change has to re-create the
 *              share or the creator silently loses access on the first escalation. And the
 *              open-to-closed transition removes the internal-ticket share.
 *
 * @author Anshita Chanda
 * Modified by Deepanjan Dey
 */
/*
public without sharing class CaseCreatorShareHandler {

    private static final String CASE_RECORD_TYPE_DEV_NAME    = 'Case';
    private static final String TICKET_RECORD_TYPE_DEV_NAME  = 'Internal_Ticket';

    private static final Map<String, String> ACCESS_BY_RECORD_TYPE = new Map<String, String>{
        CASE_RECORD_TYPE_DEV_NAME   => 'Edit',
        TICKET_RECORD_TYPE_DEV_NAME => 'Read'
    };

    private static final Set<String> ENDS_ON_CLOSE = new Set<String>{
        TICKET_RECORD_TYPE_DEV_NAME
    };

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------
    public static void handleAfterInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        createCreatorShares(newCases, null);
    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        // Closure first: a save that both closes the ticket and changes its owner should
        // end up with no share, not a re-created one.
        removeSharesOnClose(newCases, oldCasesById);
        createCreatorShares(newCases, oldCasesById);
    }

    // ------------------------------------------------------------------
    // Sharing
    // ------------------------------------------------------------------
    private static void createCreatorShares(List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        List<CaseShare> sharesToInsert = new List<CaseShare>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            String accessLevel = ACCESS_BY_RECORD_TYPE.get(devName);
            if (accessLevel == null) {
                continue;
            }

            // On insert there is nothing to compare against, so every case qualifies.
            // On update only an owner change matters: the platform has just deleted the
            // manual share, so it has to be put back.
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Boolean ownerChanged = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
            if (!ownerChanged) {
                continue;
            }

            // A closed ticket does not get its share re-created on reassignment.
            if (ENDS_ON_CLOSE.contains(devName) && caseRecord.IsClosed == true) {
                continue;
            }

            // Sharing a record with its own owner is rejected by the platform.
            if (caseRecord.CreatedById == caseRecord.OwnerId) {
                continue;
            }

            sharesToInsert.add(
                new CaseShare(
                    CaseId          = caseRecord.Id,
                    UserOrGroupId   = caseRecord.CreatedById,
                    CaseAccessLevel = accessLevel,
                    RowCause        = 'Manual'
                )
            );
        }

        if (sharesToInsert.isEmpty()) {
            return;
        }

        // allOrNone = false: one refused share must not take the others, or the save,
        // down with it. Failures are logged rather than discarded, because a silent
        // miss looks identical to "I cannot see my case" with no way to diagnose it.
        for (Database.SaveResult sr : Database.insert(sharesToInsert, false)) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    // INVALID_ACCESS_LEVEL is expected when the org-wide default already
                    // grants this much - the share is redundant, not broken.
                    if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
                        continue;
                    }
                    System.debug(LoggingLevel.ERROR,
                        'Creator share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
                }
            }
        }
    }


    private static void removeSharesOnClose(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        Set<Id> closedCaseIds = new Set<Id>();
        Set<Id> creatorIds = new Set<Id>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName == null || !ENDS_ON_CLOSE.contains(devName)) {
                continue;
            }
            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null) {
                continue;
            }
            // The transition, not the state - a later save on a closed ticket has
            // nothing left to clean up.
            if (caseRecord.IsClosed != true || previous.IsClosed == true) {
                continue;
            }
            closedCaseIds.add(caseRecord.Id);
            creatorIds.add(caseRecord.CreatedById);
        }
        if (closedCaseIds.isEmpty()) {
            return;
        }

        List<CaseShare> shares = [
            SELECT Id
            FROM CaseShare
            WHERE CaseId IN :closedCaseIds
              AND UserOrGroupId IN :creatorIds
              AND RowCause = 'Manual'
        ];
        if (shares.isEmpty()) {
            return;
        }

        // The ticket is closed either way: a leftover share is a visibility issue,
        // not a reason to roll the close back.
        for (Database.DeleteResult dr : Database.delete(shares, false)) {
            if (!dr.isSuccess()) {
                for (Database.Error err : dr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Could not end creator share on close: ' + err.getMessage());
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Helper
    // ------------------------------------------------------------------
    private static Map<Id, String> recordTypeDeveloperNames() {
        Map<Id, String> byId = new Map<Id, String>();
        Map<String, Schema.RecordTypeInfo> infos =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

        for (String devName : ACCESS_BY_RECORD_TYPE.keySet()) {
            Schema.RecordTypeInfo info = infos.get(devName);
            if (info != null) {
                byId.put(info.getRecordTypeId(), devName);
            }
        }
        return byId;
    }
}
*/
/* Update Assignment */
/*
public without sharing class CaseCreatorShareHandler {

    private static final String CASE_RECORD_TYPE_DEV_NAME    = 'Case';
    private static final String TICKET_RECORD_TYPE_DEV_NAME  = 'Internal_Ticket';

    private static final Map<String, String> ACCESS_BY_RECORD_TYPE = new Map<String, String>{
        CASE_RECORD_TYPE_DEV_NAME   => 'Edit',
        TICKET_RECORD_TYPE_DEV_NAME => 'Read'
    };

    private static final Set<String> ENDS_ON_CLOSE = new Set<String>{
        TICKET_RECORD_TYPE_DEV_NAME
    };

    private static final Set<String> ADMIN_PROFILES = new Set<String>{
        'System Administrator'
    };
        
    private static final Set<String> RESOLVED_LOCK_EXEMPT_PROFILES = new Set<String>{
        'System Administrator',
        'Utkarsh Admin'
    };
                    
    private static final String RESOLVED_STATUS_VALUE = 'Resolved';

    private static final Set<String> DEPARTMENT_EDIT_PROFILES = new Set<String>{
        'Utkarsh HOD', 'CRM Head'
    };

    private static final Map<String, String> DEPARTMENT_NORMALIZATION_MAP = new Map<String, String>{
        'HIGH MAST & POLYGONAL'             => 'High_Mast_Department',
        'CRASH BARRIER'                     => 'Crash_Barrier_Department',
        'HDPE'                               => 'HDPE_Pipe_Department',
        'STEEL TUBULAR POLES'               => 'Steel_Tubular_Pole_Department',
        'POLYMER'                            => 'PVC',
        'TRANSMISSION & TELECOM TOWER'      => 'Transmission_Tower_Department',
        'PRE ENGINEERING BUILDING'          => 'PEB',
        'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
        'SOLAR STRUCTURE'                   => 'Solar_Structure_Department',
        'STEEL PIPES'                        => 'Steel_Pipes_Department'
    };

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------
    public static void handleAfterInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        logTicketBatch('handleAfterInsert', newCases, null);
        createCreatorShares(newCases, null);
        shareCasesByDepartment(newCases);
    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        logTicketBatch('handleAfterUpdate', newCases, oldCasesById);
        removeSharesOnClose(newCases, oldCasesById);
        createCreatorShares(newCases, oldCasesById);
        shareCasesByDepartment(casesNeedingDepartmentShareRebuild(newCases, oldCasesById));
    }

    private static void logTicketBatch(String context, List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        for (Case c : newCases) {
            String devName = devNameByRecordTypeId.get(c.RecordTypeId);
            if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(c.Id);
            Boolean ownerChanged = (previous == null) || (c.OwnerId != previous.OwnerId);
            Boolean wasClosed    = (previous != null) && previous.IsClosed == true;

            System.debug(LoggingLevel.INFO,
                '[TICKET_TRACK] ' + context
                + ' | CaseId=' + c.Id
                + ' | CaseNumber=' + c.CaseNumber
                + ' | OwnerId=' + c.OwnerId
                + ' | CreatedById=' + c.CreatedById
                + ' | IsClosed=' + c.IsClosed
                + ' | wasClosedBefore=' + wasClosed
                + ' | ownerChanged=' + ownerChanged
                + (previous != null ? ' | previousOwnerId=' + previous.OwnerId : ' | previousOwnerId=N/A(new)')
            );
        }
    }

    private static List<Case> casesNeedingDepartmentShareRebuild(List<Case> newCases, Map<Id, Case> oldCasesById) {
        List<Case> result = new List<Case>();
        for (Case caseRecord : newCases) {
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Boolean departmentChanged = (previous == null) || (caseRecord.Department__c != previous.Department__c);
            Boolean ownerChanged      = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
            if (departmentChanged || ownerChanged) {
                result.add(caseRecord);
            }
        }
        return result;
    }

    // ------------------------------------------------------------------
    // Sharing
    // ------------------------------------------------------------------
    private static void createCreatorShares(List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        List<CaseShare> sharesToInsert = new List<CaseShare>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            String accessLevel = ACCESS_BY_RECORD_TYPE.get(devName);

            Boolean isTicket = (devName == TICKET_RECORD_TYPE_DEV_NAME);

            if (accessLevel == null) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (no access level configured) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Boolean ownerChanged = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
            if (!ownerChanged) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (owner unchanged) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (ENDS_ON_CLOSE.contains(devName) && caseRecord.IsClosed == true) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (ticket closed) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (caseRecord.CreatedById == caseRecord.OwnerId) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (creator == owner) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (isTicket) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] createCreatorShares: WILL SHARE CaseId=' + caseRecord.Id
                    + ' | CreatedById=' + caseRecord.CreatedById
                    + ' | AccessLevel=' + accessLevel);
            }

            sharesToInsert.add(
                new CaseShare(
                    CaseId          = caseRecord.Id,
                    UserOrGroupId   = caseRecord.CreatedById,
                    CaseAccessLevel = accessLevel,
                    RowCause        = 'Manual'
                )
            );
        }

        if (sharesToInsert.isEmpty()) {
            return;
        }

        for (Database.SaveResult sr : Database.insert(sharesToInsert, false)) {
            if (sr.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] createCreatorShares: SUCCESS CaseShareId=' + sr.getId());
            } else {
                for (Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
                        System.debug(LoggingLevel.INFO,
                            '[TICKET_TRACK] createCreatorShares: redundant share (OWD already covers it)');
                        continue;
                    }
                    System.debug(LoggingLevel.ERROR,
                        'Creator share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
                }
            }
        }
    }

    private static void removeSharesOnClose(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        Set<Id> closedCaseIds = new Set<Id>();
        Set<Id> creatorIds = new Set<Id>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName == null || !ENDS_ON_CLOSE.contains(devName)) {
                continue;
            }
            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null) {
                continue;
            }
            if (caseRecord.IsClosed != true || previous.IsClosed == true) {
                continue;
            }
            System.debug(LoggingLevel.INFO,
                '[TICKET_TRACK] removeSharesOnClose: ticket just closed, will drop creator share CaseId=' + caseRecord.Id
                + ' | CreatedById=' + caseRecord.CreatedById);
            closedCaseIds.add(caseRecord.Id);
            creatorIds.add(caseRecord.CreatedById);
        }
        if (closedCaseIds.isEmpty()) {
            return;
        }

        List<CaseShare> shares = [
            SELECT Id, CaseId, UserOrGroupId
            FROM CaseShare
            WHERE CaseId IN :closedCaseIds
              AND UserOrGroupId IN :creatorIds
              AND RowCause = 'Manual'
        ];

        System.debug(LoggingLevel.INFO,
            '[TICKET_TRACK] removeSharesOnClose: found ' + shares.size() + ' share(s) to delete for closed tickets');

        if (shares.isEmpty()) {
            return;
        }

        for (Database.DeleteResult dr : Database.delete(shares, false)) {
            if (dr.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] removeSharesOnClose: deleted CaseShareId=' + dr.getId());
            } else {
                for (Database.Error err : dr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Could not end creator share on close: ' + err.getMessage());
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Department-based sharing for the "Case" record type
    // ------------------------------------------------------------------
    private static List<Case> casesWithDepartmentChange(List<Case> newCases, Map<Id, Case> oldCasesById) {
        List<Case> changed = new List<Case>();
        for (Case caseRecord : newCases) {
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            if (previous == null || caseRecord.Department__c != previous.Department__c) {
                changed.add(caseRecord);
            }
        }
        return changed;
    }

    private static void shareCasesByDepartment(List<Case> cases) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();

        Map<Id, Case> eligibleCases = new Map<Id, Case>();
        Map<Id, String> caseDeptMap = new Map<Id, String>();

        for (Case caseRecord : cases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName == TICKET_RECORD_TYPE_DEV_NAME) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] shareCasesByDepartment: SKIP (Internal_Ticket, department sharing N/A) CaseId=' + caseRecord.Id);
            }
            if (devName != CASE_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            eligibleCases.put(caseRecord.Id, caseRecord);
            if (String.isNotBlank(caseRecord.Department__c)) {
                caseDeptMap.put(caseRecord.Id, normalizeDept(caseRecord.Department__c));
            }
        }

        if (eligibleCases.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT Id, Departments__c, Profile.Name
            FROM User
            WHERE IsActive = TRUE
              AND Departments__c != NULL
              AND Profile.Name IN :DEPARTMENT_EDIT_PROFILES
        ];

        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
        for (User usr : users) {
            if (ADMIN_PROFILES.contains(usr.Profile.Name)) {
                continue;
            }
            for (String rawDept : usr.Departments__c.split(';')) {
                String dept = rawDept.trim();
                if (String.isBlank(dept)) {
                    continue;
                }
                if (!deptUsersMap.containsKey(dept)) {
                    deptUsersMap.put(dept, new List<User>());
                }
                deptUsersMap.get(dept).add(usr);
            }
        }

        List<CaseShare> existingShares = [
            SELECT Id, CaseId, UserOrGroupId
            FROM CaseShare
            WHERE CaseId IN :eligibleCases.keySet()
              AND RowCause = 'Manual'
        ];

        List<CaseShare> sharesToDelete = new List<CaseShare>();
        for (CaseShare cs : existingShares) {
            Case owningCase = eligibleCases.get(cs.CaseId);
            if (owningCase != null && cs.UserOrGroupId != owningCase.CreatedById) {
                sharesToDelete.add(cs);
            }
        }
        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }

        List<CaseShare> newShares = new List<CaseShare>();
        Set<String> uniqueKeys = new Set<String>();

        for (Id caseId : caseDeptMap.keySet()) {
            String dept = caseDeptMap.get(caseId);
            if (!deptUsersMap.containsKey(dept)) {
                continue;
            }
            Case caseRecord = eligibleCases.get(caseId);

            for (User usr : deptUsersMap.get(dept)) {
                if (usr.Id == caseRecord.OwnerId || usr.Id == caseRecord.CreatedById) {
                    continue;
                }

                String key = caseId + '-' + usr.Id;
                if (uniqueKeys.contains(key)) {
                    continue;
                }
                uniqueKeys.add(key);

                newShares.add(
                    new CaseShare(
                        CaseId          = caseId,
                        UserOrGroupId   = usr.Id,
                        CaseAccessLevel = 'Edit',
                        RowCause        = 'Manual'
                    )
                );
            }
        }

        if (newShares.isEmpty()) {
            return;
        }

        for (Database.SaveResult sr : Database.insert(newShares, false)) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
                        continue;
                    }
                    System.debug(LoggingLevel.ERROR,
                        'Department case share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
                }
            }
        }
    }

    private static String normalizeDept(String rawDept) {
        String key = rawDept.trim().toUpperCase();
        return DEPARTMENT_NORMALIZATION_MAP.containsKey(key)
            ? DEPARTMENT_NORMALIZATION_MAP.get(key)
            : rawDept.trim();
    }

    // ------------------------------------------------------------------
    // Helper
    // ------------------------------------------------------------------
    private static Map<Id, String> recordTypeDeveloperNames() {
        Map<Id, String> byId = new Map<Id, String>();
        Map<String, Schema.RecordTypeInfo> infos =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

        for (String devName : ACCESS_BY_RECORD_TYPE.keySet()) {
            Schema.RecordTypeInfo info = infos.get(devName);
            if (info != null) {
                byId.put(info.getRecordTypeId(), devName);
            }
        }
        return byId;
    }
    public static void handleBeforeUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        restrictTicketEditToOwner(newCases, oldCasesById);
        restrictEditWhenResolved(newCases, oldCasesById);
    }

    private static void restrictTicketEditToOwner(List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }
        
        Id runningUserId = UserInfo.getUserId();
        String runningProfileName = [SELECT Profile.Name FROM User WHERE Id = :runningUserId WITH SYSTEM_MODE].Profile.Name;
        System.debug('runningProfileName: ' + runningProfileName);
        
        // Admins bypass the restriction
        if (ADMIN_PROFILES.contains(runningProfileName)) {
            return;
        }
        
        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Id ownerAtEditTime = (previous != null) ? previous.OwnerId : caseRecord.OwnerId;
            
            if (runningUserId != ownerAtEditTime) {
                caseRecord.addError('Only the Ticket Owner can edit this ticket.');
            }
        }
    }
    
    private static void restrictEditWhenResolved(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }
        
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }
        
        Id runningUserId = UserInfo.getUserId();
        String runningProfileName = [SELECT Profile.Name FROM User WHERE Id = :runningUserId WITH SYSTEM_MODE].Profile.Name;
        
        if (RESOLVED_LOCK_EXEMPT_PROFILES.contains(runningProfileName)) {
            return;
        }
        
        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName != CASE_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            
            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null || previous.Status != RESOLVED_STATUS_VALUE) {
                continue;
            }
            
            if (hasLockedFieldChange(caseRecord, previous)) {
                caseRecord.addError(
                    'This case is Resolved and can no longer be edited. ' +
                    'Contact with Admin if changes are required.'
                );
            }
        }
    }

    private static Boolean hasLockedFieldChange(Case newRec, Case oldRec) {
        Map<String, Object> newFields = newRec.getPopulatedFieldsAsMap();
        Map<String, Object> oldFields = oldRec.getPopulatedFieldsAsMap();
        
        Set<String> allFieldNames = new Set<String>();
        allFieldNames.addAll(newFields.keySet());
        allFieldNames.addAll(oldFields.keySet());
        
        for (String fieldName : allFieldNames) {
            if (valuesDiffer(newFields.get(fieldName), oldFields.get(fieldName))) {
                return true;
            }
        }
        return false;
    }
    
    private static Boolean valuesDiffer(Object newVal, Object oldVal) {
        if (newVal == null && oldVal == null) {
            return false;
        }
        if (newVal == null || oldVal == null) {
            return true;
        }
        return !newVal.equals(oldVal);
    }
}
*/
// public without sharing class CaseCreatorShareHandler {

//     private static final String CASE_RECORD_TYPE_DEV_NAME    = 'Case';
//     private static final String TICKET_RECORD_TYPE_DEV_NAME  = 'Internal_Ticket';

//     private static final Map<String, String> ACCESS_BY_RECORD_TYPE = new Map<String, String>{
//         CASE_RECORD_TYPE_DEV_NAME   => 'Edit',
//         TICKET_RECORD_TYPE_DEV_NAME => 'Read'
//     };

//     private static final Set<String> ENDS_ON_CLOSE = new Set<String>{
//         TICKET_RECORD_TYPE_DEV_NAME
//     };

//     private static final Set<String> ADMIN_PROFILES = new Set<String>{
//         'System Administrator'
//     };

//     private static final Set<String> RESOLVED_LOCK_EXEMPT_PROFILES = new Set<String>{
//         'System Administrator',
//         'Utkarsh Admin'
//     };

//     private static final String RESOLVED_STATUS_VALUE = 'Resolved';

//     private static final Set<String> DEPARTMENT_EDIT_PROFILES = new Set<String>{
//         'Utkarsh HOD', 'CRM Head'
//     };

//     private static final Map<String, String> DEPARTMENT_NORMALIZATION_MAP = new Map<String, String>{
//         'HIGH MAST & POLYGONAL'             => 'High_Mast_Department',
//         'CRASH BARRIER'                     => 'Crash_Barrier_Department',
//         'HDPE'                               => 'HDPE_Pipe_Department',
//         'STEEL TUBULAR POLES'               => 'Steel_Tubular_Pole_Department',
//         'POLYMER'                            => 'PVC',
//         'TRANSMISSION & TELECOM TOWER'      => 'Transmission_Tower_Department',
//         'PRE ENGINEERING BUILDING'          => 'PEB',
//         'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
//         'SOLAR STRUCTURE'                   => 'Solar_Structure_Department',
//         'STEEL PIPES'                        => 'Steel_Pipes_Department'
//     };

//     // ------------------------------------------------------------------
//     // Entry points
//     // ------------------------------------------------------------------
//     public static void handleAfterInsert(List<Case> newCases) {
//         if (newCases == null || newCases.isEmpty()) {
//             return;
//         }
//         logTicketBatch('handleAfterInsert', newCases, null);
//         createCreatorShares(newCases, null);
//         shareCasesByDepartment(newCases);
//     }

//     public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         if (newCases == null || newCases.isEmpty()) {
//             return;
//         }
//         logTicketBatch('handleAfterUpdate', newCases, oldCasesById);
//         removeSharesOnClose(newCases, oldCasesById);
//         createCreatorShares(newCases, oldCasesById);
//         shareCasesByDepartment(casesNeedingDepartmentShareRebuild(newCases, oldCasesById));
//     }

//     private static void logTicketBatch(String context, List<Case> newCases, Map<Id, Case> oldCasesById) {
//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
//         for (Case c : newCases) {
//             String devName = devNameByRecordTypeId.get(c.RecordTypeId);
//             if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
//                 continue;
//             }
//             Case previous = (oldCasesById == null) ? null : oldCasesById.get(c.Id);
//             Boolean ownerChanged = (previous == null) || (c.OwnerId != previous.OwnerId);
//             Boolean wasClosed    = (previous != null) && previous.IsClosed == true;

//             System.debug(LoggingLevel.INFO,
//                 '[TICKET_TRACK] ' + context
//                 + ' | CaseId=' + c.Id
//                 + ' | CaseNumber=' + c.CaseNumber
//                 + ' | OwnerId=' + c.OwnerId
//                 + ' | CreatedById=' + c.CreatedById
//                 + ' | IsClosed=' + c.IsClosed
//                 + ' | wasClosedBefore=' + wasClosed
//                 + ' | ownerChanged=' + ownerChanged
//                 + (previous != null ? ' | previousOwnerId=' + previous.OwnerId : ' | previousOwnerId=N/A(new)')
//             );
//         }
//     }

//     private static List<Case> casesNeedingDepartmentShareRebuild(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         List<Case> result = new List<Case>();
//         for (Case caseRecord : newCases) {
//             Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
//             Boolean departmentChanged = (previous == null) || (caseRecord.Department__c != previous.Department__c);
//             Boolean ownerChanged      = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
//             if (departmentChanged || ownerChanged) {
//                 result.add(caseRecord);
//             }
//         }
//         return result;
//     }

//     // ------------------------------------------------------------------
//     // Sharing
//     // ------------------------------------------------------------------
//     private static void createCreatorShares(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
//         if (devNameByRecordTypeId.isEmpty()) {
//             return;
//         }

//         List<CaseShare> sharesToInsert = new List<CaseShare>();

//         for (Case caseRecord : newCases) {
//             String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
//             String accessLevel = ACCESS_BY_RECORD_TYPE.get(devName);

//             Boolean isTicket = (devName == TICKET_RECORD_TYPE_DEV_NAME);

//             if (accessLevel == null) {
//                 if (isTicket) {
//                     System.debug(LoggingLevel.INFO,
//                         '[TICKET_TRACK] createCreatorShares: SKIP (no access level configured) CaseId=' + caseRecord.Id);
//                 }
//                 continue;
//             }

//             Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
//             Boolean ownerChanged = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
//             if (!ownerChanged) {
//                 if (isTicket) {
//                     System.debug(LoggingLevel.INFO,
//                         '[TICKET_TRACK] createCreatorShares: SKIP (owner unchanged) CaseId=' + caseRecord.Id);
//                 }
//                 continue;
//             }

//             if (ENDS_ON_CLOSE.contains(devName) && caseRecord.IsClosed == true) {
//                 if (isTicket) {
//                     System.debug(LoggingLevel.INFO,
//                         '[TICKET_TRACK] createCreatorShares: SKIP (ticket closed) CaseId=' + caseRecord.Id);
//                 }
//                 continue;
//             }

//             if (caseRecord.CreatedById == caseRecord.OwnerId) {
//                 if (isTicket) {
//                     System.debug(LoggingLevel.INFO,
//                         '[TICKET_TRACK] createCreatorShares: SKIP (creator == owner) CaseId=' + caseRecord.Id);
//                 }
//                 continue;
//             }

//             if (isTicket) {
//                 System.debug(LoggingLevel.INFO,
//                     '[TICKET_TRACK] createCreatorShares: WILL SHARE CaseId=' + caseRecord.Id
//                     + ' | CreatedById=' + caseRecord.CreatedById
//                     + ' | AccessLevel=' + accessLevel);
//             }

//             sharesToInsert.add(
//                 new CaseShare(
//                     CaseId          = caseRecord.Id,
//                     UserOrGroupId   = caseRecord.CreatedById,
//                     CaseAccessLevel = accessLevel,
//                     RowCause        = 'Manual'
//                 )
//             );
//         }

//         if (sharesToInsert.isEmpty()) {
//             return;
//         }

//         for (Database.SaveResult sr : Database.insert(sharesToInsert, false, AccessLevel.SYSTEM_MODE)) {
//             if (sr.isSuccess()) {
//                 System.debug(LoggingLevel.INFO,
//                     '[TICKET_TRACK] createCreatorShares: SUCCESS CaseShareId=' + sr.getId());
//             } else {
//                 for (Database.Error err : sr.getErrors()) {
//                     if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
//                         System.debug(LoggingLevel.INFO,
//                             '[TICKET_TRACK] createCreatorShares: redundant share (OWD already covers it)');
//                         continue;
//                     }
//                     System.debug(LoggingLevel.ERROR,
//                         'Creator share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
//                 }
//             }
//         }
//     }

//     private static void removeSharesOnClose(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         if (oldCasesById == null) {
//             return;
//         }
//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
//         if (devNameByRecordTypeId.isEmpty()) {
//             return;
//         }

//         Set<Id> closedCaseIds = new Set<Id>();
//         Set<Id> creatorIds = new Set<Id>();

//         for (Case caseRecord : newCases) {
//             String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
//             if (devName == null || !ENDS_ON_CLOSE.contains(devName)) {
//                 continue;
//             }
//             Case previous = oldCasesById.get(caseRecord.Id);
//             if (previous == null) {
//                 continue;
//             }
//             if (caseRecord.IsClosed != true || previous.IsClosed == true) {
//                 continue;
//             }
//             System.debug(LoggingLevel.INFO,
//                 '[TICKET_TRACK] removeSharesOnClose: ticket just closed, will drop creator share CaseId=' + caseRecord.Id
//                 + ' | CreatedById=' + caseRecord.CreatedById);
//             closedCaseIds.add(caseRecord.Id);
//             creatorIds.add(caseRecord.CreatedById);
//         }
//         if (closedCaseIds.isEmpty()) {
//             return;
//         }

//         List<CaseShare> shares = [
//             SELECT Id, CaseId, UserOrGroupId
//             FROM CaseShare
//             WHERE CaseId IN :closedCaseIds
//               AND UserOrGroupId IN :creatorIds
//               AND RowCause = 'Manual'
//             WITH SYSTEM_MODE
//         ];

//         System.debug(LoggingLevel.INFO,
//             '[TICKET_TRACK] removeSharesOnClose: found ' + shares.size() + ' share(s) to delete for closed tickets');

//         if (shares.isEmpty()) {
//             return;
//         }

//         for (Database.DeleteResult dr : Database.delete(shares, false, AccessLevel.SYSTEM_MODE)) {
//             if (dr.isSuccess()) {
//                 System.debug(LoggingLevel.INFO,
//                     '[TICKET_TRACK] removeSharesOnClose: deleted CaseShareId=' + dr.getId());
//             } else {
//                 for (Database.Error err : dr.getErrors()) {
//                     System.debug(LoggingLevel.ERROR,
//                         'Could not end creator share on close: ' + err.getMessage());
//                 }
//             }
//         }
//     }

//     // ------------------------------------------------------------------
//     // Department-based sharing for the "Case" record type
//     // ------------------------------------------------------------------
//     private static List<Case> casesWithDepartmentChange(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         List<Case> changed = new List<Case>();
//         for (Case caseRecord : newCases) {
//             Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
//             if (previous == null || caseRecord.Department__c != previous.Department__c) {
//                 changed.add(caseRecord);
//             }
//         }
//         return changed;
//     }

//     private static void shareCasesByDepartment(List<Case> cases) {
//         if (cases == null || cases.isEmpty()) {
//             return;
//         }

//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();

//         Map<Id, Case> eligibleCases = new Map<Id, Case>();
//         Map<Id, String> caseDeptMap = new Map<Id, String>();

//         for (Case caseRecord : cases) {
//             String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
//             if (devName == TICKET_RECORD_TYPE_DEV_NAME) {
//                 System.debug(LoggingLevel.INFO,
//                     '[TICKET_TRACK] shareCasesByDepartment: SKIP (Internal_Ticket, department sharing N/A) CaseId=' + caseRecord.Id);
//             }
//             if (devName != CASE_RECORD_TYPE_DEV_NAME) {
//                 continue;
//             }
//             eligibleCases.put(caseRecord.Id, caseRecord);
//             if (String.isNotBlank(caseRecord.Department__c)) {
//                 caseDeptMap.put(caseRecord.Id, normalizeDept(caseRecord.Department__c));
//             }
//         }

//         if (eligibleCases.isEmpty()) {
//             return;
//         }

//         List<User> users = [
//             SELECT Id, Departments__c, Profile.Name
//             FROM User
//             WHERE IsActive = TRUE
//               AND Departments__c != NULL
//               AND Profile.Name IN :DEPARTMENT_EDIT_PROFILES
//             WITH SYSTEM_MODE
//         ];

//         Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
//         for (User usr : users) {
//             if (ADMIN_PROFILES.contains(usr.Profile.Name)) {
//                 continue;
//             }
//             for (String rawDept : usr.Departments__c.split(';')) {
//                 String dept = rawDept.trim();
//                 if (String.isBlank(dept)) {
//                     continue;
//                 }
//                 if (!deptUsersMap.containsKey(dept)) {
//                     deptUsersMap.put(dept, new List<User>());
//                 }
//                 deptUsersMap.get(dept).add(usr);
//             }
//         }

//         List<CaseShare> existingShares = [
//             SELECT Id, CaseId, UserOrGroupId
//             FROM CaseShare
//             WHERE CaseId IN :eligibleCases.keySet()
//               AND RowCause = 'Manual'
//             WITH SYSTEM_MODE
//         ];

//         List<CaseShare> sharesToDelete = new List<CaseShare>();
//         for (CaseShare cs : existingShares) {
//             Case owningCase = eligibleCases.get(cs.CaseId);
//             if (owningCase != null && cs.UserOrGroupId != owningCase.CreatedById) {
//                 sharesToDelete.add(cs);
//             }
//         }
//         if (!sharesToDelete.isEmpty()) {
//             Database.delete(sharesToDelete, AccessLevel.SYSTEM_MODE);
//         }

//         List<CaseShare> newShares = new List<CaseShare>();
//         Set<String> uniqueKeys = new Set<String>();

//         for (Id caseId : caseDeptMap.keySet()) {
//             String dept = caseDeptMap.get(caseId);
//             if (!deptUsersMap.containsKey(dept)) {
//                 continue;
//             }
//             Case caseRecord = eligibleCases.get(caseId);

//             for (User usr : deptUsersMap.get(dept)) {
//                 if (usr.Id == caseRecord.OwnerId || usr.Id == caseRecord.CreatedById) {
//                     continue;
//                 }

//                 String key = caseId + '-' + usr.Id;
//                 if (uniqueKeys.contains(key)) {
//                     continue;
//                 }
//                 uniqueKeys.add(key);

//                 newShares.add(
//                     new CaseShare(
//                         CaseId          = caseId,
//                         UserOrGroupId   = usr.Id,
//                         CaseAccessLevel = 'Edit',
//                         RowCause        = 'Manual'
//                     )
//                 );
//             }
//         }

//         if (newShares.isEmpty()) {
//             return;
//         }

//         for (Database.SaveResult sr : Database.insert(newShares, false, AccessLevel.SYSTEM_MODE)) {
//             if (!sr.isSuccess()) {
//                 for (Database.Error err : sr.getErrors()) {
//                     if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
//                         continue;
//                     }
//                     System.debug(LoggingLevel.ERROR,
//                         'Department case share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
//                 }
//             }
//         }
//     }

//     private static String normalizeDept(String rawDept) {
//         String key = rawDept.trim().toUpperCase();
//         return DEPARTMENT_NORMALIZATION_MAP.containsKey(key)
//             ? DEPARTMENT_NORMALIZATION_MAP.get(key)
//             : rawDept.trim();
//     }

//     // ------------------------------------------------------------------
//     // Helper
//     // ------------------------------------------------------------------
//     private static Map<Id, String> recordTypeDeveloperNames() {
//         Map<Id, String> byId = new Map<Id, String>();
//         Map<String, Schema.RecordTypeInfo> infos =
//             Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

//         for (String devName : ACCESS_BY_RECORD_TYPE.keySet()) {
//             Schema.RecordTypeInfo info = infos.get(devName);
//             if (info != null) {
//                 byId.put(info.getRecordTypeId(), devName);
//             }
//         }
//         return byId;
//     }

//     public static void handleBeforeUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         if (newCases == null || newCases.isEmpty()) {
//             return;
//         }
//         restrictTicketEditToOwner(newCases, oldCasesById);
//         restrictEditWhenResolved(newCases, oldCasesById);
//     }

//     private static void restrictTicketEditToOwner(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
//         if (devNameByRecordTypeId.isEmpty()) {
//             return;
//         }

//         Id runningUserId = UserInfo.getUserId();
//         String runningProfileName = [SELECT Profile.Name FROM User WHERE Id = :runningUserId WITH SYSTEM_MODE].Profile.Name;
//         System.debug('runningProfileName: ' + runningProfileName);

//         if (ADMIN_PROFILES.contains(runningProfileName)) {
//             return;
//         }

//         for (Case caseRecord : newCases) {
//             String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
//             if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
//                 continue;
//             }

//             Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
//             Id ownerAtEditTime = (previous != null) ? previous.OwnerId : caseRecord.OwnerId;

//             if (runningUserId != ownerAtEditTime) {
//                 caseRecord.addError('Only the Ticket Owner can edit this ticket.');
//             }
//         }
//     }

//     private static void restrictEditWhenResolved(List<Case> newCases, Map<Id, Case> oldCasesById) {
//         if (oldCasesById == null) {
//             return;
//         }

//         Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
//         if (devNameByRecordTypeId.isEmpty()) {
//             return;
//         }

//         Id runningUserId = UserInfo.getUserId();
//         String runningProfileName = [SELECT Profile.Name FROM User WHERE Id = :runningUserId WITH SYSTEM_MODE].Profile.Name;

//         if (RESOLVED_LOCK_EXEMPT_PROFILES.contains(runningProfileName)) {
//             return;
//         }

//         for (Case caseRecord : newCases) {
//             String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
//             if (devName != CASE_RECORD_TYPE_DEV_NAME) {
//                 continue;
//             }

//             Case previous = oldCasesById.get(caseRecord.Id);
//             if (previous == null || previous.Status != RESOLVED_STATUS_VALUE) {
//                 continue;
//             }

//             if (hasLockedFieldChange(caseRecord, previous)) {
//                 caseRecord.addError(
//                     'This case is Resolved and can no longer be edited. ' +
//                     'Contact with Admin if changes are required.'
//                 );
//             }
//         }
//     }

//     private static Boolean hasLockedFieldChange(Case newRec, Case oldRec) {
//         Map<String, Object> newFields = newRec.getPopulatedFieldsAsMap();
//         Map<String, Object> oldFields = oldRec.getPopulatedFieldsAsMap();

//         Set<String> allFieldNames = new Set<String>();
//         allFieldNames.addAll(newFields.keySet());
//         allFieldNames.addAll(oldFields.keySet());

//         for (String fieldName : allFieldNames) {
//             if (valuesDiffer(newFields.get(fieldName), oldFields.get(fieldName))) {
//                 return true;
//             }
//         }
//         return false;
//     }

//     private static Boolean valuesDiffer(Object newVal, Object oldVal) {
//         if (newVal == null && oldVal == null) {
//             return false;
//         }
//         if (newVal == null || oldVal == null) {
//             return true;
//         }
//         return !newVal.equals(oldVal);
//     }
// }

public without sharing class CaseCreatorShareHandler {

    private static final String CASE_RECORD_TYPE_DEV_NAME    = 'Case';
    private static final String TICKET_RECORD_TYPE_DEV_NAME  = 'Internal_Ticket';

    // CHANGED: 'Case' creator share is now Read (was Edit) so the creator
    // cannot edit a case after assigning it to someone else.
    private static final Map<String, String> ACCESS_BY_RECORD_TYPE = new Map<String, String>{
        CASE_RECORD_TYPE_DEV_NAME   => 'Read',
        TICKET_RECORD_TYPE_DEV_NAME => 'Read'
    };

    private static final Set<String> ENDS_ON_CLOSE = new Set<String>{
        TICKET_RECORD_TYPE_DEV_NAME
    };

    private static final Set<String> ADMIN_PROFILES = new Set<String>{
        'System Administrator'
    };

    private static final Set<String> RESOLVED_LOCK_EXEMPT_PROFILES = new Set<String>{
        'System Administrator',
        'Utkarsh Admin'
    };

    // NEW: profiles that can still edit a case they created but no longer own.
    private static final Set<String> CREATOR_LOCK_EXEMPT_PROFILES = new Set<String>{
        'System Administrator',
        'Utkarsh Admin'
    };

    // NEW: field API names (LOWER CASE) that may still change on a creator-locked case,
    // e.g. fields stamped by a Flow / workflow running as the creator. Empty by default.
    private static final Set<String> CREATOR_LOCK_IGNORED_FIELDS = new Set<String>();

    private static final String RESOLVED_STATUS_VALUE = 'Resolved';

    private static final Set<String> DEPARTMENT_EDIT_PROFILES = new Set<String>{
        'Utkarsh HOD', 'CRM Head'
    };

    private static final Map<String, String> DEPARTMENT_NORMALIZATION_MAP = new Map<String, String>{
        'HIGH MAST & POLYGONAL'             => 'High_Mast_Department',
        'CRASH BARRIER'                     => 'Crash_Barrier_Department',
        'HDPE'                               => 'HDPE_Pipe_Department',
        'STEEL TUBULAR POLES'               => 'Steel_Tubular_Pole_Department',
        'POLYMER'                            => 'PVC',
        'TRANSMISSION & TELECOM TOWER'      => 'Transmission_Tower_Department',
        'PRE ENGINEERING BUILDING'          => 'PEB',
        'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
        'SOLAR STRUCTURE'                   => 'Solar_Structure_Department',
        'STEEL PIPES'                        => 'Steel_Pipes_Department'
    };

    // NEW: cache so the running user's profile is queried once per transaction.
    private static String runningProfileNameCache;

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------
    public static void handleAfterInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        logTicketBatch('handleAfterInsert', newCases, null);
        createCreatorShares(newCases, null);
        shareCasesByDepartment(newCases);
    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        logTicketBatch('handleAfterUpdate', newCases, oldCasesById);
        removeSharesOnClose(newCases, oldCasesById);
        createCreatorShares(newCases, oldCasesById);
        shareCasesByDepartment(casesNeedingDepartmentShareRebuild(newCases, oldCasesById));
    }

    private static void logTicketBatch(String context, List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        for (Case c : newCases) {
            String devName = devNameByRecordTypeId.get(c.RecordTypeId);
            if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(c.Id);
            Boolean ownerChanged = (previous == null) || (c.OwnerId != previous.OwnerId);
            Boolean wasClosed    = (previous != null) && previous.IsClosed == true;

            System.debug(LoggingLevel.INFO,
                '[TICKET_TRACK] ' + context
                + ' | CaseId=' + c.Id
                + ' | CaseNumber=' + c.CaseNumber
                + ' | OwnerId=' + c.OwnerId
                + ' | CreatedById=' + c.CreatedById
                + ' | IsClosed=' + c.IsClosed
                + ' | wasClosedBefore=' + wasClosed
                + ' | ownerChanged=' + ownerChanged
                + (previous != null ? ' | previousOwnerId=' + previous.OwnerId : ' | previousOwnerId=N/A(new)')
            );
        }
    }

    private static List<Case> casesNeedingDepartmentShareRebuild(List<Case> newCases, Map<Id, Case> oldCasesById) {
        List<Case> result = new List<Case>();
        for (Case caseRecord : newCases) {
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
         
            
            
            
            
            
            
            
            
            Boolean departmentChanged = (previous == null) || (caseRecord.Department__c != previous.Department__c);
            Boolean ownerChanged      = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
            if (departmentChanged || ownerChanged) {
                result.add(caseRecord);
            }
        }
        return result;
    }

    // ------------------------------------------------------------------
    // Sharing
    // ------------------------------------------------------------------
    private static void createCreatorShares(List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        List<CaseShare> sharesToInsert = new List<CaseShare>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            String accessLevel = ACCESS_BY_RECORD_TYPE.get(devName);

            Boolean isTicket = (devName == TICKET_RECORD_TYPE_DEV_NAME);

            if (accessLevel == null) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (no access level configured) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Boolean ownerChanged = (previous == null) || (caseRecord.OwnerId != previous.OwnerId);
            if (!ownerChanged) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (owner unchanged) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (ENDS_ON_CLOSE.contains(devName) && caseRecord.IsClosed == true) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (ticket closed) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (caseRecord.CreatedById == caseRecord.OwnerId) {
                if (isTicket) {
                    System.debug(LoggingLevel.INFO,
                        '[TICKET_TRACK] createCreatorShares: SKIP (creator == owner) CaseId=' + caseRecord.Id);
                }
                continue;
            }

            if (isTicket) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] createCreatorShares: WILL SHARE CaseId=' + caseRecord.Id
                    + ' | CreatedById=' + caseRecord.CreatedById
                    + ' | AccessLevel=' + accessLevel);
            }

            sharesToInsert.add(
                new CaseShare(
                    CaseId          = caseRecord.Id,
                    UserOrGroupId   = caseRecord.CreatedById,
                    CaseAccessLevel = accessLevel,
                    RowCause        = 'Manual'
                )
            );
        }

        if (sharesToInsert.isEmpty()) {
            return;
        }

        for (Database.SaveResult sr : Database.insert(sharesToInsert, false, AccessLevel.SYSTEM_MODE)) {
            if (sr.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] createCreatorShares: SUCCESS CaseShareId=' + sr.getId());
            } else {
                for (Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
                        System.debug(LoggingLevel.INFO,
                            '[TICKET_TRACK] createCreatorShares: redundant share (OWD already covers it)');
                        continue;
                    }
                    System.debug(LoggingLevel.ERROR,
                        'Creator share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
                }
            }
        }
    }

    private static void removeSharesOnClose(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        Set<Id> closedCaseIds = new Set<Id>();
        Set<Id> creatorIds = new Set<Id>();

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName == null || !ENDS_ON_CLOSE.contains(devName)) {
                continue;
            }
            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null) {
                continue;
            }
            if (caseRecord.IsClosed != true || previous.IsClosed == true) {
                continue;
            }
            System.debug(LoggingLevel.INFO,
                '[TICKET_TRACK] removeSharesOnClose: ticket just closed, will drop creator share CaseId=' + caseRecord.Id
                + ' | CreatedById=' + caseRecord.CreatedById);
            closedCaseIds.add(caseRecord.Id);
            creatorIds.add(caseRecord.CreatedById);
        }
        if (closedCaseIds.isEmpty()) {
            return;
        }

        List<CaseShare> shares = [
            SELECT Id, CaseId, UserOrGroupId
            FROM CaseShare
            WHERE CaseId IN :closedCaseIds
              AND UserOrGroupId IN :creatorIds
              AND RowCause = 'Manual'
            WITH SYSTEM_MODE
        ];

        System.debug(LoggingLevel.INFO,
            '[TICKET_TRACK] removeSharesOnClose: found ' + shares.size() + ' share(s) to delete for closed tickets');

        if (shares.isEmpty()) {
            return;
        }

        for (Database.DeleteResult dr : Database.delete(shares, false, AccessLevel.SYSTEM_MODE)) {
            if (dr.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] removeSharesOnClose: deleted CaseShareId=' + dr.getId());
            } else {
                for (Database.Error err : dr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Could not end creator share on close: ' + err.getMessage());
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Department-based sharing for the "Case" record type
    // ------------------------------------------------------------------
    private static List<Case> casesWithDepartmentChange(List<Case> newCases, Map<Id, Case> oldCasesById) {
        List<Case> changed = new List<Case>();
        for (Case caseRecord : newCases) {
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            if (previous == null || caseRecord.Department__c != previous.Department__c) {
                changed.add(caseRecord);
            }
        }
        return changed;
    }

    private static void shareCasesByDepartment(List<Case> cases) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();

        Map<Id, Case> eligibleCases = new Map<Id, Case>();
        Map<Id, String> caseDeptMap = new Map<Id, String>();

        for (Case caseRecord : cases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName == TICKET_RECORD_TYPE_DEV_NAME) {
                System.debug(LoggingLevel.INFO,
                    '[TICKET_TRACK] shareCasesByDepartment: SKIP (Internal_Ticket, department sharing N/A) CaseId=' + caseRecord.Id);
            }
            if (devName != CASE_RECORD_TYPE_DEV_NAME) {
                continue;
            }
            eligibleCases.put(caseRecord.Id, caseRecord);
            if (String.isNotBlank(caseRecord.Department__c)) {
                caseDeptMap.put(caseRecord.Id, normalizeDept(caseRecord.Department__c));
            }
        }

        if (eligibleCases.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT Id, Departments__c, Profile.Name
            FROM User
            WHERE IsActive = TRUE
              AND Departments__c != NULL
              AND Profile.Name IN :DEPARTMENT_EDIT_PROFILES
            WITH SYSTEM_MODE
        ];

        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
        for (User usr : users) {
            if (ADMIN_PROFILES.contains(usr.Profile.Name)) {
                continue;
            }
            for (String rawDept : usr.Departments__c.split(';')) {
                String dept = rawDept.trim();
                if (String.isBlank(dept)) {
                    continue;
                }
                if (!deptUsersMap.containsKey(dept)) {
                    deptUsersMap.put(dept, new List<User>());
                }
                deptUsersMap.get(dept).add(usr);
            }
        }

        List<CaseShare> existingShares = [
            SELECT Id, CaseId, UserOrGroupId
            FROM CaseShare
            WHERE CaseId IN :eligibleCases.keySet()
              AND RowCause = 'Manual'
            WITH SYSTEM_MODE
        ];

        List<CaseShare> sharesToDelete = new List<CaseShare>();
        for (CaseShare cs : existingShares) {
            Case owningCase = eligibleCases.get(cs.CaseId);
            if (owningCase != null && cs.UserOrGroupId != owningCase.CreatedById) {
                sharesToDelete.add(cs);
            }
        }
        if (!sharesToDelete.isEmpty()) {
            Database.delete(sharesToDelete, AccessLevel.SYSTEM_MODE);
        }

        List<CaseShare> newShares = new List<CaseShare>();
        Set<String> uniqueKeys = new Set<String>();

        for (Id caseId : caseDeptMap.keySet()) {
            String dept = caseDeptMap.get(caseId);
            if (!deptUsersMap.containsKey(dept)) {
                continue;
            }
            Case caseRecord = eligibleCases.get(caseId);

            for (User usr : deptUsersMap.get(dept)) {
                if (usr.Id == caseRecord.OwnerId || usr.Id == caseRecord.CreatedById) {
                    continue;
                }

                String key = caseId + '-' + usr.Id;
                if (uniqueKeys.contains(key)) {
                    continue;
                }
                uniqueKeys.add(key);

                newShares.add(
                    new CaseShare(
                        CaseId          = caseId,
                        UserOrGroupId   = usr.Id,
                        CaseAccessLevel = 'Edit',
                        RowCause        = 'Manual'
                    )
                );
            }
        }

        if (newShares.isEmpty()) {
            return;
        }

        for (Database.SaveResult sr : Database.insert(newShares, false, AccessLevel.SYSTEM_MODE)) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.INVALID_ACCESS_LEVEL) {
                        continue;
                    }
                    System.debug(LoggingLevel.ERROR,
                        'Department case share failed: ' + err.getStatusCode() + ' ' + err.getMessage());
                }
            }
        }
    }

    private static String normalizeDept(String rawDept) {
        String key = rawDept.trim().toUpperCase();
        return DEPARTMENT_NORMALIZATION_MAP.containsKey(key)
            ? DEPARTMENT_NORMALIZATION_MAP.get(key)
            : rawDept.trim();
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    private static Map<Id, String> recordTypeDeveloperNames() {
        Map<Id, String> byId = new Map<Id, String>();
        Map<String, Schema.RecordTypeInfo> infos =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

        for (String devName : ACCESS_BY_RECORD_TYPE.keySet()) {
            Schema.RecordTypeInfo info = infos.get(devName);
            if (info != null) {
                byId.put(info.getRecordTypeId(), devName);
            }
        }
        return byId;
    }

    // NEW: one profile query per transaction instead of one per restriction method.
    private static String getRunningProfileName() {
        if (runningProfileNameCache == null) {
            Id runningUserId = UserInfo.getUserId();
            runningProfileNameCache = [
                SELECT Profile.Name
                FROM User
                WHERE Id = :runningUserId
                WITH SYSTEM_MODE
            ].Profile.Name;
        }
        return runningProfileNameCache;
    }

    // ------------------------------------------------------------------
    // Before update restrictions
    // ------------------------------------------------------------------
    public static void handleBeforeUpdate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
        restrictTicketEditToOwner(newCases, oldCasesById);
        restrictEditWhenResolved(newCases, oldCasesById);
        restrictCreatorEditAfterAssignment(newCases, oldCasesById); // NEW
    }

    private static void restrictTicketEditToOwner(List<Case> newCases, Map<Id, Case> oldCasesById) {
        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        Id runningUserId = UserInfo.getUserId();
        String runningProfileName = getRunningProfileName();
        System.debug('runningProfileName: ' + runningProfileName);

        if (ADMIN_PROFILES.contains(runningProfileName)) {
            return;
        }

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName != TICKET_RECORD_TYPE_DEV_NAME) {
                continue;
            }

            Case previous = (oldCasesById == null) ? null : oldCasesById.get(caseRecord.Id);
            Id ownerAtEditTime = (previous != null) ? previous.OwnerId : caseRecord.OwnerId;

            if (runningUserId != ownerAtEditTime) {
                caseRecord.addError('Only the Ticket Owner can edit this ticket.');
            }
        }
    }

    private static void restrictEditWhenResolved(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }

        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        String runningProfileName = getRunningProfileName();

        if (RESOLVED_LOCK_EXEMPT_PROFILES.contains(runningProfileName)) {
            return;
        }

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName != CASE_RECORD_TYPE_DEV_NAME) {
                continue;
            }

            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null || previous.Status != RESOLVED_STATUS_VALUE) {
                continue;
            }

            if (hasLockedFieldChange(caseRecord, previous)) {
                caseRecord.addError(
                    'This case is Resolved and can no longer be edited. ' +
                    'Contact with Admin if changes are required.'
                );
            }
        }
    }

    // NEW: creator of a "Case" record cannot edit it once it is owned by someone else.
    // The owner is read from the OLD record, so the creator can still reassign the case
    // to another user in their own edit; only edits made after that are blocked.
    private static void restrictCreatorEditAfterAssignment(List<Case> newCases, Map<Id, Case> oldCasesById) {
        if (oldCasesById == null) {
            return;
        }

        Map<Id, String> devNameByRecordTypeId = recordTypeDeveloperNames();
        if (devNameByRecordTypeId.isEmpty()) {
            return;
        }

        Id runningUserId = UserInfo.getUserId();

        if (CREATOR_LOCK_EXEMPT_PROFILES.contains(getRunningProfileName())) {
            return;
        }

        for (Case caseRecord : newCases) {
            String devName = devNameByRecordTypeId.get(caseRecord.RecordTypeId);
            if (devName != CASE_RECORD_TYPE_DEV_NAME) {
                continue;
            }

            Case previous = oldCasesById.get(caseRecord.Id);
            if (previous == null) {
                continue;
            }

            Boolean runningUserIsCreator = (previous.CreatedById == runningUserId);
            Boolean ownedBySomeoneElse   = (previous.OwnerId != runningUserId);
            if (!runningUserIsCreator || !ownedBySomeoneElse) {
                continue;
            }

            if (hasLockedFieldChange(caseRecord, previous, CREATOR_LOCK_IGNORED_FIELDS)) {
                caseRecord.addError(
                    'You created this case and assigned it to another owner, so you can no longer edit it. ' +
                    'Please contact the case owner or an Admin if changes are required.'
                );
            }
        }
    }

    private static Boolean hasLockedFieldChange(Case newRec, Case oldRec) {
        return hasLockedFieldChange(newRec, oldRec, new Set<String>());
    }

    // CHANGED: overload with an optional set of ignored fields (lower-case API names).
    private static Boolean hasLockedFieldChange(Case newRec, Case oldRec, Set<String> ignoredFieldsLowerCase) {
        Map<String, Object> newFields = newRec.getPopulatedFieldsAsMap();
        Map<String, Object> oldFields = oldRec.getPopulatedFieldsAsMap();

        Set<String> allFieldNames = new Set<String>();
        allFieldNames.addAll(newFields.keySet());
        allFieldNames.addAll(oldFields.keySet());

        for (String fieldName : allFieldNames) {
            if (ignoredFieldsLowerCase.contains(fieldName.toLowerCase())) {
                continue;
            }
            if (valuesDiffer(newFields.get(fieldName), oldFields.get(fieldName))) {
                return true;
            }
        }
        return false;
    }

    private static Boolean valuesDiffer(Object newVal, Object oldVal) {
        if (newVal == null && oldVal == null) {
            return false;
        }
        if (newVal == null || oldVal == null) {
            return true;
        }
        return !newVal.equals(oldVal);
    }
}