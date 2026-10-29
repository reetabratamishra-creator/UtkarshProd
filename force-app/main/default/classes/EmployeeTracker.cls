public class EmployeeTracker {

    private static final Set<String> FORCE_TRACKER_BLOCKED_ROLES = new Set<String>{
        'Enquiry CRM User',
        'Steel Pipes Tender User'
    };
    
    public class TaskRowDTO {
        @AuraEnabled public Id taskId;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public Datetime timeLabel;
        @AuraEnabled public String description;
        @AuraEnabled public String client;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String address;
        
        // Punch specific fields
        @AuraEnabled public String type; // 'TASK' | 'PUNCH' | 'TRACK'
        @AuraEnabled public String punchType; // WFO/WFH/Market Visit
        @AuraEnabled public String action; // IN/OUT
        @AuraEnabled public String transportType;
        @AuraEnabled public String vehicleType;
        @AuraEnabled public Decimal odometer;
        @AuraEnabled public String selfieUrl;
        @AuraEnabled public String odometerUrl;

        // Task (visit) specific fields
        @AuraEnabled public Boolean isCheckout;
        @AuraEnabled public String visitCategory;
        @AuraEnabled public String visitType;
        @AuraEnabled public String reasonForVisit;
        @AuraEnabled public String visitOutcome;
        @AuraEnabled public String mom;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String checkInTime;
        @AuraEnabled public String checkOutTime;
        @AuraEnabled public String visitDuration;
        @AuraEnabled public String nodeDistance;
    }

    public class EmployeeDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String phone;
        @AuraEnabled public Decimal batteryPercentage;
        @AuraEnabled public String currentStatus;
        @AuraEnabled public Boolean gpsStatus;
        @AuraEnabled public String lastKnownAddress;
        @AuraEnabled public Datetime lastPunchTime;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String initials;
        @AuraEnabled public List<WFHRequestDTO> pendingRequests;
    }

    public class UserDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Username;
        @AuraEnabled public String ProfileName;
    }

    public class WFHRequestDTO {
        @AuraEnabled public Id requestId;
        @AuraEnabled public Date requestDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String status;
        @AuraEnabled public String requestType;
    }

    private static Set<Id> getSubordinateUserIds(Id currentUserId) {
        Set<Id> subordinateUserIds = new Set<Id>();

        // Utkarsh HOD / CRM Head: department based visibility (same rules as FieldForceDashboardController)
        List<Profile> currentProfiles = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String currentProfileName = currentProfiles.isEmpty() ? '' : currentProfiles[0].Name;
        if (currentProfileName == FieldForceDashboardController.HOD_PROFILE_NAME
                || currentProfileName == FieldForceDashboardController.CRM_HEAD_PROFILE_NAME) {
            subordinateUserIds.addAll(FieldForceDashboardController.getDepartmentUserIds(
                currentUserId,
                currentProfileName == FieldForceDashboardController.CRM_HEAD_PROFILE_NAME
            ));
        } else {
            // 1. Standard Manager check
            for (User u : [SELECT Id FROM User WHERE ManagerId = :currentUserId AND IsActive = true]) {
                subordinateUserIds.add(u.Id);
            }
        }

        // Role based matching replaced by department based matching for Utkarsh HOD / CRM Head profiles
        // // 2. HOD / CRM Head role prefix check
        // try {
        //     User currentUser = [SELECT Id, UserRole.Name FROM User WHERE Id = :currentUserId LIMIT 1];
        //     String currentRoleName = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        //     String deptPrefix = '';
        //     if (String.isNotBlank(currentRoleName)) {
        //         if (currentRoleName.endsWith(' HOD')) {
        //             deptPrefix = currentRoleName.substringBefore(' HOD').trim();
        //         } else if (currentRoleName.endsWith(' CRM Head')) {
        //             deptPrefix = currentRoleName.substringBefore(' CRM Head').trim();
        //         }
        //     }
        //
        //     if (String.isNotBlank(deptPrefix)) {
        //         String likePattern = deptPrefix + '%';
        //         for (User u : [
        //             SELECT Id FROM User
        //             WHERE IsActive = true
        //             AND UserRole.Name LIKE :likePattern
        //         ]) {
        //             subordinateUserIds.add(u.Id);
        //         }
        //     }
        // } catch (Exception e) {
        //     System.debug('Failed to query current user role or role-aligned subordinates: ' + e.getMessage());
        // }

        // // 3. Custom Manager Assignment metadata check
        // try {
        //     for (Manager_Assignment__mdt ma : [
        //         SELECT Target_User_Id__c
        //         FROM Manager_Assignment__mdt
        //         WHERE Manager_User_Id__c = :String.valueOf(currentUserId)
        //     ]) {
        //         if (String.isNotBlank(ma.Target_User_Id__c)) {
        //             subordinateUserIds.add((Id)ma.Target_User_Id__c);
        //         }
        //     }
        // } catch (Exception e) {
        //     System.debug('Manager_Assignment__mdt query failed: ' + e.getMessage());
        // }

        return subordinateUserIds;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canAccessForceTracker() {
        return !FORCE_TRACKER_BLOCKED_ROLES.contains(currentUserRoleName());
    }

    private static String currentUserRoleName() {
        User currentUser = [
            SELECT UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.UserRole != null ? currentUser.UserRole.Name : '';
    }

    @AuraEnabled
    public static List<EmployeeDTO> getEmployees() {
        List<EmployeeDTO> results = new List<EmployeeDTO>();
        if (!canAccessForceTracker()) {
            return results;
        }
        Id currentUserId = UserInfo.getUserId();

        Boolean canViewAll = FieldForceDashboardController.canViewAllFieldForceUsers();

        Set<Id> allowedUserIds = new Set<Id>();
        if (!canViewAll) {
            allowedUserIds = getSubordinateUserIds(currentUserId);
            // Allow manager to see themselves as well
            allowedUserIds.add(currentUserId);
        }

        // Employee list comes from User (same list as FieldForceDashboardController.getAvailableSalespeople);
        // live punch data is taken from the user's User_Punch_State__c record when one exists
        List<User> users;
        if (canViewAll) {
            users = [
                SELECT Id, Name, Phone,
                       (SELECT Battery_Percentage__c, Current_Status__c,
                               Last_Punch_Time__c, Latitude__c, Longitude__c
                        FROM Punch_State__r
                        LIMIT 1)
                FROM User
                WHERE IsActive = true
                ORDER BY Name ASC
                LIMIT 2000
            ];
        } else {
            users = [
                SELECT Id, Name, Phone,
                       (SELECT Battery_Percentage__c, Current_Status__c,
                               Last_Punch_Time__c, Latitude__c, Longitude__c
                        FROM Punch_State__r
                        LIMIT 1)
                FROM User
                WHERE Id IN :allowedUserIds
                AND IsActive = true
                ORDER BY Name ASC
            ];
        }

        Set<Id> punchUserIds = new Set<Id>();
        for (User u : users) {
            punchUserIds.add(u.Id);
        }

        Map<Id, List<WFHRequestDTO>> pendingByUser = new Map<Id, List<WFHRequestDTO>>();
        if (!punchUserIds.isEmpty()) {
            for (Punch_Record__c pr : [
                SELECT Id, User__c, WFH_Request_Date__c, WFH_Request_Start_Time__c, WFH_Request_End_Time__c,
                       WFH_Approval_Status__c, Is_WFH_Request__c, Is_WFO_Request__c
                FROM Punch_Record__c
                WHERE User__c IN :punchUserIds
                AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
                AND WFH_Approval_Status__c = 'Pending'
                AND WFH_Request_Date__c >= TODAY
            ]) {
                WFHRequestDTO req = new WFHRequestDTO();
                req.requestId = pr.Id;
                req.requestDate = pr.WFH_Request_Date__c;
                req.startTime = String.valueOf(pr.WFH_Request_Start_Time__c);
                req.endTime = String.valueOf(pr.WFH_Request_End_Time__c);
                req.status = pr.WFH_Approval_Status__c;
                req.requestType = pr.Is_WFH_Request__c ? 'WFH' : 'WFO';
                if (!pendingByUser.containsKey(pr.User__c)) {
                    pendingByUser.put(pr.User__c, new List<WFHRequestDTO>());
                }
                pendingByUser.get(pr.User__c).add(req);
            }
        }

        for(User u : users) {
            // Users who have never punched have no User_Punch_State__c record
            User_Punch_State__c ups = u.Punch_State__r.isEmpty() ? null : u.Punch_State__r[0];

            EmployeeDTO dto = new EmployeeDTO();
            dto.Id = u.Id;
            dto.employeeName = u.Name;
            dto.phone = u.Phone != null ? u.Phone : 'N/A';
            if (ups != null) {
                dto.batteryPercentage = ups.Battery_Percentage__c;
                dto.currentStatus = ups.Current_Status__c;
                dto.lastPunchTime = ups.Last_Punch_Time__c;
                dto.latitude = ups.Latitude__c;
                dto.longitude = ups.Longitude__c;
                dto.gpsStatus = (ups.Latitude__c != null && ups.Longitude__c != null);
            } else {
                dto.gpsStatus = false;
            }
            dto.lastKnownAddress = 'Location Captured';

            // Build Initials
            String init = 'U';
            if (String.isNotBlank(u.Name)) {
                List<String> parts = u.Name.split(' ');
                init = parts[0].substring(0, 1);
                if (parts.size() > 1) {
                    init += parts[parts.size() - 1].substring(0, 1);
                }
            }
            dto.initials = init.toUpperCase();
            dto.pendingRequests = pendingByUser.containsKey(u.Id)
                ? pendingByUser.get(u.Id)
                : new List<WFHRequestDTO>();

            results.add(dto);
        }

        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isAdminUser() {
        return FieldForceDashboardController.isCurrentUserAdmin();
    }

    @AuraEnabled(cacheable=true)
    public static List<UserDTO> getAllUsers() {
        List<UserDTO> results = new List<UserDTO>();
        for (User u : [SELECT Id, Name, Username, Profile.Name FROM User WHERE IsActive = true LIMIT 1000]) {
            UserDTO dto = new UserDTO();
            dto.Id = u.Id;
            dto.Name = u.Name;
            dto.Username = u.Username;
            dto.ProfileName = u.Profile.Name;
            results.add(dto);
        }
        return results;
    }

    @AuraEnabled
    public static Map<String, String> getManagerAssignments() {
        Map<String, String> mapping = new Map<String, String>();
        for (Manager_Assignment__mdt ma : [SELECT Target_User_Id__c, Manager_User_Id__c FROM Manager_Assignment__mdt]) {
            mapping.put(ma.Target_User_Id__c, ma.Manager_User_Id__c);
        }
        return mapping;
    }

    @AuraEnabled
    public static void saveManagerAssignment(String targetUserId, String managerUserId) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        // Use a unique name for the metadata record
        String recordName = 'User_' + targetUserId.substring(0, 15); 
        customMetadata.fullName = 'Manager_Assignment.' + recordName;
        customMetadata.label = 'Assignment for ' + targetUserId;

        Metadata.CustomMetadataValue targetUserField = new Metadata.CustomMetadataValue();
        targetUserField.field = 'Target_User_Id__c';
        targetUserField.value = targetUserId;
        customMetadata.values.add(targetUserField);

        Metadata.CustomMetadataValue managerUserField = new Metadata.CustomMetadataValue();
        managerUserField.field = 'Manager_User_Id__c';
        managerUserField.value = managerUserId;
        customMetadata.values.add(managerUserField);

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);

        if (!Test.isRunningTest()) {
            Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
    }

    @AuraEnabled
    public static void updateWFHStatus(Id requestId, String status, String remarks) {
        if (!FieldForceDashboardController.canCurrentUserApproveWfh()) {
            throw new AuraHandledException('Only HOD or Admin can approve or reject WFH/WFO requests.');
        }
        new WfhApprovalWriter().updateStatus(requestId, status, remarks);
    }

    private without sharing class WfhApprovalWriter {
        public void updateStatus(Id requestId, String status, String remarks) {
            Punch_Record__c pr = [
                SELECT Id, WFH_Approver__c
                FROM Punch_Record__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            pr.WFH_Approval_Status__c = status;
            pr.Approver_Remarks__c = remarks;
            if (pr.WFH_Approver__c == null) {
                pr.WFH_Approver__c = UserInfo.getUserId();
            }
            update pr;
        }
    }

    @AuraEnabled
    public static List<Account> getClients(){
        try {
            return [
                SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
                FROM Account
                WHERE Location__Latitude__s != null
                AND Location__Longitude__s != null
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TaskRowDTO> getRecentTasksForEmployees(List<Id> employeeIds, Integer perEmployeeLimit, String dateStr) {
        List<TaskRowDTO> result = new List<TaskRowDTO>();
        if (!canAccessForceTracker()) {
            return result;
        }
        if (employeeIds == null || employeeIds.isEmpty()) return result;
        if (perEmployeeLimit == null) perEmployeeLimit = 4;

        Date statusDate = Date.today();
        if (String.isNotBlank(dateStr)) {
            statusDate = Date.valueOf(dateStr);
        }
        Datetime startOfDay = Datetime.newInstance(statusDate, Time.newInstance(0, 0, 0, 0));
        Datetime endOfDay = Datetime.newInstance(statusDate, Time.newInstance(23, 59, 59, 999));

        // 1. Fetch Punch Records for the selected date FIRST (needed to scope Task Logs)
        List<Punch_Record__c> punches = [
            SELECT Id, User__c, Punch_Time__c, Action__c, Punch_Type__c, WFH_Activity__c,
                   Transportation_Type__c, Vehicle_Type__c, Odometer_Reading__c,
                   Latitude__c, Longitude__c, Address__c
            FROM Punch_Record__c
            WHERE User__c IN :employeeIds
              AND Punch_Time__c >= :startOfDay
              AND Punch_Time__c <= :endOfDay
              AND Is_WFH_Request__c != true
              AND Is_WFO_Request__c != true
            ORDER BY Punch_Time__c DESC
            LIMIT 200
        ];

        // 2. Collect today's punch IDs to scope Task Logs
        Set<Id> punchIdsForTaskFilter = new Set<Id>();
        for (Punch_Record__c p : punches) punchIdsForTaskFilter.add(p.Id);

        // 3. Fetch Task Logs scoped to today's punches (plus date-based fallback for orphaned logs)
        List<Task_Log__c> logs;
        if (!punchIdsForTaskFilter.isEmpty()) {
            logs = [
                SELECT Id, CreatedById, Description__c, CreatedDate,
                       Account__c, Lead__c, Opportunity__c, Account__r.Name, Lead__r.Name, Opportunity__r.Name, Client_Deatils__r.Name,
                       Latitude__c, Longitude__c, IsCheckout__c, Logged_At__c, Logged_Out_At__c,
                       Visit_Category__c, Visit_Type__c, Reason_for_Visit__c, Visit_outcome__c,
                       MOM__c, Next_Action__c, Address__c
                FROM Task_Log__c
                WHERE Punch_Record__c IN :punchIdsForTaskFilter
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            logs = [
                SELECT Id, CreatedById, Description__c, CreatedDate,
                       Account__c, Lead__c, Opportunity__c, Account__r.Name, Lead__r.Name, Opportunity__r.Name, Client_Deatils__r.Name,
                       Latitude__c, Longitude__c, IsCheckout__c, Logged_At__c, Logged_Out_At__c,
                       Visit_Category__c, Visit_Type__c, Reason_for_Visit__c, Visit_outcome__c,
                       MOM__c, Next_Action__c, Address__c
                FROM Task_Log__c
                WHERE CreatedById IN :employeeIds
                  AND CreatedDate >= :startOfDay
                  AND CreatedDate <= :endOfDay
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        Map<Id, String> selfieMap = new Map<Id, String>();
        Map<Id, String> odometerMap = new Map<Id, String>();

        if (!punchIdsForTaskFilter.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId, FirstPublishLocationId, Title
                FROM ContentVersion
                WHERE FirstPublishLocationId IN :punchIdsForTaskFilter
                AND IsLatest = true
            ]) {
                String url = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                if (cv.Title != null && cv.Title.toLowerCase().contains('selfie')) {
                    selfieMap.put(cv.FirstPublishLocationId, url);
                } else if (cv.Title != null && cv.Title.toLowerCase().contains('odometer')) {
                    odometerMap.put(cv.FirstPublishLocationId, url);
                }
            }
        }

        // 5. Map Logs to DTO
        for (Task_Log__c t : logs) {
            TaskRowDTO row = new TaskRowDTO();
            row.taskId      = t.Id;
            row.employeeId  = t.CreatedById;
            row.description = t.Description__c;
            // Resolve client name
            if (t.Client_Deatils__r != null)   row.client = t.Client_Deatils__r.Name;
            else if (t.Account__r != null)      row.client = t.Account__r.Name;
            else if (t.Lead__r != null)         row.client = t.Lead__r.Name;
            else if (t.Opportunity__r != null)  row.client = t.Opportunity__r.Name;
            else                                row.client = '';
            row.timeLabel      = t.Logged_At__c != null ? t.Logged_At__c : t.CreatedDate;
            row.latitude       = t.Latitude__c;
            row.longitude      = t.Longitude__c;
            row.address        = t.Address__c;
            row.isCheckout     = t.IsCheckout__c;
            row.visitCategory  = t.Visit_Category__c;
            row.visitType      = t.Visit_Type__c;
            row.reasonForVisit = t.Reason_for_Visit__c;
            row.visitOutcome   = t.Visit_outcome__c;
            row.mom            = t.MOM__c;
            row.nextAction     = t.Next_Action__c;
            Datetime checkInAt = t.Logged_At__c != null ? t.Logged_At__c : t.CreatedDate;
            row.checkInTime    = checkInAt != null ? checkInAt.format('hh:mm a') : null;
            row.checkOutTime   = (t.IsCheckout__c && t.Logged_Out_At__c != null)
                ? t.Logged_Out_At__c.format('hh:mm a')
                : (t.IsCheckout__c ? null : 'Active');
            if (checkInAt != null && t.Logged_Out_At__c != null) {
                Long durationMin = (t.Logged_Out_At__c.getTime() - checkInAt.getTime()) / (1000 * 60);
                if (durationMin < 0) durationMin = 0;
                if (durationMin < 60) {
                    row.visitDuration = durationMin + ' mins';
                } else {
                    Long hours = durationMin / 60;
                    Long mins = Math.mod(durationMin, 60);
                    row.visitDuration = hours + ' hr ' + mins + ' mins';
                }
            } else if (!t.IsCheckout__c) {
                row.visitDuration = 'In Progress';
            }
            if (t.Opportunity__c != null) {
                row.type = 'Opportunity';
            } else if (t.Lead__c != null) {
                row.type = 'Lead';
            } else if (t.Account__c != null) {
                row.type = 'Account';
            } else {
                row.type = 'TASK';
            }
            result.add(row);
        }

        // 6. Map Punches to DTO
        for (Punch_Record__c p : punches) {
            TaskRowDTO row = new TaskRowDTO();
            row.taskId      = p.Id;
            row.employeeId  = p.User__c;
            row.timeLabel   = p.Punch_Time__c;
            row.action      = p.Action__c;
            row.punchType   = p.Punch_Type__c;
            String pType = String.isNotBlank(p.Punch_Type__c) ? p.Punch_Type__c : 'Punch';
            String pAction = String.isNotBlank(p.Action__c) ? p.Action__c : '';
            row.description = pType + ' ' + pAction + (String.isNotBlank(p.WFH_Activity__c) ? ': ' + p.WFH_Activity__c : '');
            row.transportType = p.Transportation_Type__c;
            row.vehicleType   = p.Vehicle_Type__c;
            row.odometer      = p.Odometer_Reading__c;
            row.latitude    = p.Latitude__c;
            row.longitude   = p.Longitude__c;
            row.address     = p.Address__c;
            row.selfieUrl   = selfieMap.get(p.Id);
            row.odometerUrl = odometerMap.get(p.Id);
            row.type        = 'PUNCH';
            result.add(row);
        }

        // 7. Fetch Tracking Locations scoped to today's punch records
        List<Track_Location__c> tracks;
        if (!punchIdsForTaskFilter.isEmpty()) {
            tracks = [
                SELECT Id, Punch_Record__r.User__c, Latitude__c, Longitude__c, CreatedDate, Recorded_At__c
                FROM Track_Location__c
                WHERE Punch_Record__c IN :punchIdsForTaskFilter
                ORDER BY Recorded_At__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1000
            ];
        } else {
            tracks = [
                SELECT Id, Punch_Record__r.User__c, Latitude__c, Longitude__c, CreatedDate, Recorded_At__c
                FROM Track_Location__c
                WHERE Punch_Record__r.User__c IN :employeeIds
                  AND (
                        (Recorded_At__c != null AND Recorded_At__c >= :startOfDay AND Recorded_At__c <= :endOfDay)
                     OR (Recorded_At__c = null AND CreatedDate >= :startOfDay AND CreatedDate <= :endOfDay)
                  )
                ORDER BY Recorded_At__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1000
            ];
        }

        // 7. Map Tracking Locations to DTO
        for (Track_Location__c tl : tracks) {
            TaskRowDTO row = new TaskRowDTO();
            row.taskId      = tl.Id;
            row.employeeId  = tl.Punch_Record__r.User__c;
            row.timeLabel   = tl.Recorded_At__c != null ? tl.Recorded_At__c : tl.CreatedDate;
            row.description = 'Periodic Location Update';
            try {
                row.latitude    = tl.Latitude__c != null ? Decimal.valueOf(tl.Latitude__c) : null;
                row.longitude   = tl.Longitude__c != null ? Decimal.valueOf(tl.Longitude__c) : null;
            } catch (Exception e) {
                // ignore invalid decimals
            }
            row.type        = 'TRACK';
            result.add(row);
        }

        return result;
    }
}