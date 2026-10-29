/*public without sharing class UserTenderShareTriggerHandler {

    private static final Integer BATCH_SIZE = 50;

    // Prevents starting duplicate jobs for the same department in one transaction
    private static Set<String> alreadyQueuedDepts = new Set<String>();

    // New user with departments -> share existing tenders with them
    public static void handleAfterInsert(List<User> newUsers) {
        if (newUsers == null || newUsers.isEmpty()) return;

        Set<String> affectedDepts = new Set<String>();

        for (User u : newUsers) {
            if (u.IsActive && String.isNotBlank(u.Departments__c)) {
                affectedDepts.addAll(parseDepartments(u.Departments__c));
            }
        }

        startBatch(affectedDepts);
    }

    // Existing user changed -> recalculate sharing
    public static void handleAfterUpdate(List<User> newUsers, Map<Id, User> oldMap) {
        if (newUsers == null || newUsers.isEmpty() || oldMap == null) return;

        Set<String> affectedDepts = new Set<String>();

        for (User newUser : newUsers) {
            User oldUser = oldMap.get(newUser.Id);
            if (oldUser == null) continue;

            Boolean changed =
                newUser.Departments__c != oldUser.Departments__c ||
                newUser.IsActive != oldUser.IsActive ||
                newUser.ProfileId != oldUser.ProfileId ||
                newUser.Tender_Access_User__c != oldUser.Tender_Access_User__c;

            if (!changed) continue;

            // Old + new departments, so removed AND added departments are both covered
            affectedDepts.addAll(parseDepartments(oldUser.Departments__c));
            affectedDepts.addAll(parseDepartments(newUser.Departments__c));
        }

        startBatch(affectedDepts);
    }

    // Helper: split 'A;B;C' into a clean set
    private static Set<String> parseDepartments(String departments) {
        Set<String> result = new Set<String>();
        if (String.isBlank(departments)) return result;

        for (String d : departments.split(';')) {
            if (String.isNotBlank(d)) {
                result.add(d.trim());
            }
        }
        return result;
    }

    // Helper: start the background job (separate transaction => no MIXED_DML error)
    private static void startBatch(Set<String> departments) {
        if (departments == null || departments.isEmpty()) return;

        // Skip departments already queued in this transaction
        Set<String> toQueue = new Set<String>();
        for (String d : departments) {
            if (!alreadyQueuedDepts.contains(d)) {
                toQueue.add(d);
            }
        }
        if (toQueue.isEmpty()) return;

        // Batch cannot be started from future/batch context
        if (System.isFuture() || System.isBatch()) {
            System.debug(LoggingLevel.WARN,
                'Tender share batch not started: running in future/batch context. Departments: ' + toQueue);
            return;
        }

        try {
            Database.executeBatch(new UserDeptChangeTenderShareBatch(toQueue), BATCH_SIZE);
            alreadyQueuedDepts.addAll(toQueue);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'Could not start UserDeptChangeTenderShareBatch: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }
}*/
public without sharing class UserTenderShareTriggerHandler {

    private static final Integer BATCH_SIZE = 50;

    // Prevents starting duplicate jobs for the same department in one transaction
    private static Set<String> alreadyQueuedDepts = new Set<String>();

    // Test-only switches (Custom Metadata cannot be changed inside a test)
    @TestVisible private static Boolean testKillSwitchOn = false;
    @TestVisible private static Boolean testForceError = false;

    // Single entry point called by the trigger
    public static void run(Boolean isInsert, Boolean isUpdate,
                           List<User> newUsers, Map<Id, User> oldMap) {

        if (isDisabled()) return;

        try {
            if (Test.isRunningTest() && testForceError) {
                throw new IllegalArgumentException('Forced test failure');
            }

            if (isInsert) {
                handleAfterInsert(newUsers);
            } else if (isUpdate) {
                handleAfterUpdate(newUsers, oldMap);
            }
        } catch (Exception ex) {
            // Never block the user save because of sharing problems
            System.debug(LoggingLevel.ERROR,
                'UserTenderShareTrigger failed: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }

    // Kill switch (same Custom Metadata used by the Tender trigger)
    @TestVisible
    private static Boolean isDisabled() {
        if (Test.isRunningTest() && testKillSwitchOn) return true;

        Tender_Trigger_Controll__mdt setting =
            Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');

        return setting != null && !setting.Is_Active__c;
    }

    // New user with departments -> share existing tenders with them
    public static void handleAfterInsert(List<User> newUsers) {
        if (newUsers == null || newUsers.isEmpty()) return;

        Set<String> affectedDepts = new Set<String>();

        for (User u : newUsers) {
            if (u.IsActive && String.isNotBlank(u.Departments__c)) {
                affectedDepts.addAll(parseDepartments(u.Departments__c));
            }
        }

        startBatch(affectedDepts);
    }

    // Existing user changed -> recalculate sharing
    public static void handleAfterUpdate(List<User> newUsers, Map<Id, User> oldMap) {
        if (newUsers == null || newUsers.isEmpty() || oldMap == null) return;

        Set<String> affectedDepts = new Set<String>();

        for (User newUser : newUsers) {
            User oldUser = oldMap.get(newUser.Id);
            if (oldUser == null) continue;

            Boolean changed =
                newUser.Departments__c != oldUser.Departments__c ||
                newUser.IsActive != oldUser.IsActive ||
                newUser.ProfileId != oldUser.ProfileId ||
                newUser.Tender_Access_User__c != oldUser.Tender_Access_User__c;

            if (!changed) continue;

            // Old + new departments, so removed AND added departments are both covered
            affectedDepts.addAll(parseDepartments(oldUser.Departments__c));
            affectedDepts.addAll(parseDepartments(newUser.Departments__c));
        }

        startBatch(affectedDepts);
    }

    // Helper: split 'A;B;C' into a clean set
    private static Set<String> parseDepartments(String departments) {
        Set<String> result = new Set<String>();
        if (String.isBlank(departments)) return result;

        for (String d : departments.split(';')) {
            if (String.isNotBlank(d)) {
                result.add(d.trim());
            }
        }
        return result;
    }

    // Helper: start the background job (separate transaction => no MIXED_DML error)
    private static void startBatch(Set<String> departments) {
        if (departments == null || departments.isEmpty()) return;

        // Skip departments already queued in this transaction
        Set<String> toQueue = new Set<String>();
        for (String d : departments) {
            if (!alreadyQueuedDepts.contains(d)) {
                toQueue.add(d);
            }
        }
        if (toQueue.isEmpty()) return;

        // Batch cannot be started from future/batch context
        if (System.isFuture() || System.isBatch()) {
            System.debug(LoggingLevel.WARN,
                'Tender share batch not started: running in future/batch context. Departments: ' + toQueue);
            return;
        }

        try {
            Database.executeBatch(new UserDeptChangeTenderShareBatch(toQueue), BATCH_SIZE);
            alreadyQueuedDepts.addAll(toQueue);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'Could not start UserDeptChangeTenderShareBatch: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }
    @TestVisible
    private static void resetQueuedDepts() {
        alreadyQueuedDepts.clear();
    }
}