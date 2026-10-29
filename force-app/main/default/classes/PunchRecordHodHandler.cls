public without sharing class PunchRecordHodHandler {

    private static final List<String> ROLE_SUFFIXES = new List<String>{
        ' Commercial User',
        ' Tender User',
        ' Sales User',
        ' CRM Head',
        ' CRM User',
        ' User'
    };

    public static void applyHod(Punch_Record__c punch) {
        if (punch == null) {
            return;
        }
        populateHod(new List<Punch_Record__c>{ punch });
    }

    public static void populateHod(List<Punch_Record__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Set<Id> userIds = new Set<Id>();
        for (Punch_Record__c punch : records) {
            if (punch.HOD__c != null) {
                continue;
            }
            if (punch.User__c != null) {
                userIds.add(punch.User__c);
            } else {
                userIds.add(UserInfo.getUserId());
            }
        }
        if (userIds.isEmpty()) {
            return;
        }

        Map<Id, User> userById = new Map<Id, User>([
            SELECT Id, ManagerId, UserRole.Name
            FROM User
            WHERE Id IN :userIds
        ]);

        Set<String> hodRoleNames = new Set<String>();
        Map<Id, String> userIdToHodRole = new Map<Id, String>();
        for (User usr : userById.values()) {
            String roleName = usr.UserRole != null ? usr.UserRole.Name : null;
            if (String.isBlank(roleName)) {
                continue;
            }
            if (roleName.endsWith(' HOD')) {
                userIdToHodRole.put(usr.Id, roleName);
                continue;
            }
            String hodRole = hodRoleNameFromUserRole(roleName);
            if (String.isNotBlank(hodRole)) {
                userIdToHodRole.put(usr.Id, hodRole);
                hodRoleNames.add(hodRole);
            }
        }

        Map<String, Id> hodUserByRoleName = new Map<String, Id>();
        if (!hodRoleNames.isEmpty()) {
            for (User hodUser : [
                SELECT Id, UserRole.Name
                FROM User
                WHERE IsActive = true
                  AND UserRole.Name IN :hodRoleNames
                ORDER BY Name
            ]) {
                if (!hodUserByRoleName.containsKey(hodUser.UserRole.Name)) {
                    hodUserByRoleName.put(hodUser.UserRole.Name, hodUser.Id);
                }
            }
        }

        for (Punch_Record__c punch : records) {
            if (punch.HOD__c != null) {
                continue;
            }
            Id sourceUserId = punch.User__c != null ? punch.User__c : UserInfo.getUserId();
            User sourceUser = userById.get(sourceUserId);
            if (sourceUser == null) {
                continue;
            }

            String roleName = sourceUser.UserRole != null ? sourceUser.UserRole.Name : null;
            if (String.isNotBlank(roleName) && roleName.endsWith(' HOD')) {
                punch.HOD__c = sourceUser.Id;
                continue;
            }

            String hodRole = userIdToHodRole.get(sourceUser.Id);
            if (String.isNotBlank(hodRole) && hodUserByRoleName.containsKey(hodRole)) {
                punch.HOD__c = hodUserByRoleName.get(hodRole);
                continue;
            }

            if (sourceUser.ManagerId != null) {
                punch.HOD__c = sourceUser.ManagerId;
            }
        }
    }

    @TestVisible
    private static String hodRoleNameFromUserRole(String roleName) {
        if (String.isBlank(roleName)) {
            return null;
        }
        if (roleName.endsWith(' HOD')) {
            return roleName;
        }
        for (String suffix : ROLE_SUFFIXES) {
            if (roleName.endsWith(suffix)) {
                return roleName.substring(0, roleName.length() - suffix.length()).trim() + ' HOD';
            }
        }
        return roleName.trim() + ' HOD';
    }
}