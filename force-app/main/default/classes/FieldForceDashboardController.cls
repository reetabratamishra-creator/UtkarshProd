public without sharing class FieldForceDashboardController {

    // ---------------- DTOs ----------------

    public class SalespersonOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String status;
    }

    public class DashboardData {
        @AuraEnabled public AttendanceSummary attendanceSummary;
        @AuraEnabled public List<TimelineItem> timeline;
        @AuraEnabled public List<MapMarker> mapMarkers;
        @AuraEnabled public List<TrackLocationDTO> trackLocations;
        @AuraEnabled public List<VisitNodeDTO> visitNodes;
        @AuraEnabled public List<PunchMarkerDTO> punchMarkers;
    }

    public class PunchMarkerDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String punchType;
        @AuraEnabled public String action;
        @AuraEnabled public String label;
        @AuraEnabled public String title;
        @AuraEnabled public Double latitude;
        @AuraEnabled public Double longitude;
        @AuraEnabled public String address;
        @AuraEnabled public String timeLabel;
        @AuraEnabled public String color;
    }

    public class TrackLocationDTO {
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Datetime createdDate;
    }

    public class VisitNodeDTO {
        @AuraEnabled public Integer nodeNumber;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String clientName;
        @AuraEnabled public String checkInTime;
        @AuraEnabled public String checkOutTime;
        @AuraEnabled public String visitDuration;
        @AuraEnabled public String visitCategory;
        @AuraEnabled public String visitType;
        @AuraEnabled public Boolean isActive;
    }

    public class DepartmentWFHRequestDTO {
        @AuraEnabled public Id requestId;
        @AuraEnabled public String userName;
        @AuraEnabled public Id userId;
        @AuraEnabled public Date requestDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String status;
        @AuraEnabled public String type; // 'WFH' or 'WFO'
        @AuraEnabled public Id approverId;
        @AuraEnabled public String approverName;
        @AuraEnabled public String remarks;
        @AuraEnabled public String requestNote;
        // Day Activity Log captured when the approved WFH/WFO session was ended
        @AuraEnabled public Boolean isCompleted = false;
        @AuraEnabled public Decimal noOfEmails;
        @AuraEnabled public Decimal noOfMeetings;
        @AuraEnabled public Decimal noOfOffersSent;
        @AuraEnabled public Decimal noOfPhoneCalls;
        @AuraEnabled public String openNotes;
    }

    public class AttendanceSummary {
        @AuraEnabled public String punchInTime;
        @AuraEnabled public String punchOutTime;
        @AuraEnabled public String totalHours;
        @AuraEnabled public String attendanceStatus; // IN, OUT, Absent, WFH, WFO, Market Visit
        @AuraEnabled public String inLocation;
        @AuraEnabled public String outLocation;
        @AuraEnabled public Decimal startingOdometer;
        @AuraEnabled public Decimal endingOdometer;
        @AuraEnabled public Decimal totalDistanceKm;
        @AuraEnabled public Decimal batteryLevel;
        @AuraEnabled public String gpsStatus;
        @AuraEnabled public Integer totalVisits;

        //@AuraEnabled public Decimal startingExtractedOdometer;
        //@AuraEnabled public Decimal endingExtractedOdometer;
        @AuraEnabled public Decimal odometerDistanceKm;
        @AuraEnabled public Decimal distanceDeviationKm;
        @AuraEnabled public Decimal distanceDeviationPercent;
    }

    public class TimelineItem implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String type; // PUNCH_IN, PUNCH_OUT, VISIT_CHECKIN, VISIT_CHECKOUT, TRACK_POINT
        @AuraEnabled public Datetime eventTime;
        @AuraEnabled public String timeLabel;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String address;
        @AuraEnabled public String badgeText;
        @AuraEnabled public String badgeClass;
        @AuraEnabled public List<Map<String, String>> files;
        
        // Visit specific
        @AuraEnabled public String clientName;
        @AuraEnabled public String visitType;
        @AuraEnabled public String visitOutcome;
        @AuraEnabled public String reasonForVisit;
        @AuraEnabled public String mom;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String followUpDate;
        @AuraEnabled public Boolean is100mOutside;
        @AuraEnabled public String justification;
        @AuraEnabled public String checkInTime;
        @AuraEnabled public String checkOutTime;
        @AuraEnabled public String visitDistance;
        @AuraEnabled public String nodeDistance;
        @AuraEnabled public String visitCategory;
        @AuraEnabled public Boolean isCheckout;
        @AuraEnabled public String action;
        @AuraEnabled public String status;
        @AuraEnabled public String punchTypeOfRecord;
        @AuraEnabled public String visitDuration;
        
        // Punch specific
        @AuraEnabled public String transportType;
        @AuraEnabled public String vehicleType;
        @AuraEnabled public Decimal odometer;

        private Integer getSortWeight() {
            if (this.type == 'PUNCH_IN') {
                if (this.punchTypeOfRecord == 'Day In / Out') {
                    return 1; // Day In
                }
                return 3; // Category Punch In
            }
            if (this.type == 'VISIT') {
                return 4; // Client Visit
            }
            if (this.type == 'PUNCH_OUT') {
                if (this.status == 'OUT') {
                    return 5; // Day Out
                }
                return 2; // Category Punch Out
            }
            return 6;
        }

        public Integer compareTo(Object compareTo) {
            TimelineItem compareToItem = (TimelineItem) compareTo;
            if (eventTime == null && compareToItem.eventTime == null) return 0;
            if (eventTime == null) return 1;
            if (compareToItem.eventTime == null) return -1;
            if (eventTime < compareToItem.eventTime) return -1;
            if (eventTime > compareToItem.eventTime) return 1;
            
            // Tie-breaker weight
            Integer w1 = this.getSortWeight();
            Integer w2 = compareToItem.getSortWeight();
            if (w1 < w2) return -1;
            if (w1 > w2) return 1;
            return 0;
        }
    }

    public class MapMarker {
        @AuraEnabled public MapLocation location;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String icon; 
    }

    public class MapLocation {
        @AuraEnabled public Double Latitude;
        @AuraEnabled public Double Longitude;
    }

    // ---------------- CONTROLLER METHODS ----------------

    /**
     * Retrieves the list of salespeople that the current user is allowed to view.
     * - Salesperson: Only themselves.
     * - Manager: Subordinates assigned via standard ManagerId or Manager_Assignment__mdt.
     * - Admin: All salespeople.
     */
    @AuraEnabled(cacheable=true)
    public static List<SalespersonOption> getAvailableSalespeople() {
        List<SalespersonOption> options = new List<SalespersonOption>();
        Id currentUserId = UserInfo.getUserId();

        // 1. Admin and HR can view all users. HR cannot approve WFH/WFO.
        Boolean canViewAll = canViewAllFieldForceUsers();

        // 2. Fetch subordinates if Manager or HOD
        Set<Id> subordinateUserIds = new Set<Id>();

        // Utkarsh HOD / CRM Head: department based visibility (self + users of their department(s))
        String currentProfileName = currentUserProfileName();
        if (currentProfileName == HOD_PROFILE_NAME || currentProfileName == CRM_HEAD_PROFILE_NAME) {
            subordinateUserIds.addAll(getDepartmentUserIds(currentUserId, currentProfileName == CRM_HEAD_PROFILE_NAME));
        } else {
            // standard Manager check
            for (User u : [SELECT Id FROM User WHERE ManagerId = :currentUserId AND IsActive = true]) {
                subordinateUserIds.add(u.Id);
            }
        }

        // Role based matching replaced by department based matching for Utkarsh HOD / CRM Head profiles
        // // HOD / CRM Head role prefix check
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

        // // Custom Manager Assignment metadata check
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

        Boolean isManager = !subordinateUserIds.isEmpty();

        // 3. Query User records
        List<User> users = new List<User>();
        if (canViewAll) {
            users = [
                SELECT Id, Name, Phone FROM User 
                WHERE IsActive = true 
                ORDER BY Name ASC 
                LIMIT 2000
            ];
        } else if (isManager) {
            // Show subordinates + current user (as a manager might track their own status too)
            subordinateUserIds.add(currentUserId);
            users = [
                SELECT Id, Name, Phone FROM User 
                WHERE Id IN :subordinateUserIds AND IsActive = true
                ORDER BY Name ASC
            ];
        } else {
            // Standard Salesperson: Only themselves
            users = [
                SELECT Id, Name, Phone FROM User 
                WHERE Id = :currentUserId
                LIMIT 1
            ];
        }

        for (User u : users) {
            SalespersonOption opt = new SalespersonOption();
            opt.id = u.Id;
            opt.name = u.Name;
            opt.phone = u.Phone != null ? u.Phone : '';
            opt.status = 'Active'; 
            options.add(opt);
        }

        return options;
    }

    public static final String HOD_PROFILE_NAME = 'Utkarsh HOD';
    public static final String CRM_HEAD_PROFILE_NAME = 'CRM Head';

    // Department name (User.Department, uppercased) -> User.Departments__c picklist value
    private static final Map<String, String> DEPARTMENT_NORMALIZATION_MAP = new Map<String, String>{
        'HIGH MAST & POLYGONAL'             => 'High_Mast_Department',
        'CRASH BARRIER'                     => 'Crash_Barrier_Department',
        'HDPE'                              => 'HDPE_Pipe_Department',
        'STEEL TUBULAR POLES'               => 'Steel_Tubular_Pole_Department',
        'POLYMER'                           => 'PVC',
        'TRANSMISSION & TELECOM TOWER'      => 'Transmission_Tower_Department',
        'PRE ENGINEERING BUILDING'          => 'PEB',
        'SOLAR STRUCTURE'                   => 'Solar_Structure_Department',
        'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
        'STEEL PIPES'                       => 'Steel_Pipes_Department'
    };

    /**
     * Users visible to an Utkarsh HOD / CRM Head (current user is added by the caller).
     * - Utkarsh HOD: active users whose Department equals the HOD's Department.
     * - CRM Head: active users whose Department is one of the CRM Head's Departments__c values
     *   or that department's name (e.g. 'Crash Barrier' for 'Crash_Barrier_Department').
     */
    public static Set<Id> getDepartmentUserIds(Id currentUserId, Boolean isCrmHead) {
        Set<Id> userIds = new Set<Id>();
        try {
            User currentUser = [SELECT Id, Department, Departments__c FROM User WHERE Id = :currentUserId LIMIT 1];

            if (!isCrmHead) {
                if (String.isBlank(currentUser.Department)) {
                    return userIds;
                }
                for (User u : [
                    SELECT Id FROM User
                    WHERE IsActive = true
                    AND Department = :currentUser.Department
                ]) {
                    userIds.add(u.Id);
                }
                return userIds;
            }

            if (String.isBlank(currentUser.Departments__c)) {
                return userIds;
            }
            Set<String> crmHeadDepts = new Set<String>();
            for (String rawDept : currentUser.Departments__c.split(';')) {
                if (String.isNotBlank(rawDept)) {
                    crmHeadDepts.add(rawDept.trim());
                }
            }
            if (crmHeadDepts.isEmpty()) {
                return userIds;
            }

            // Department names that map to the CRM Head's Departments__c values
            Set<String> deptNames = new Set<String>(crmHeadDepts);
            for (String deptName : DEPARTMENT_NORMALIZATION_MAP.keySet()) {
                if (crmHeadDepts.contains(DEPARTMENT_NORMALIZATION_MAP.get(deptName))) {
                    deptNames.add(deptName);
                }
            }

            for (User u : [
                SELECT Id FROM User
                WHERE IsActive = true
                AND Department IN :deptNames
            ]) {
                userIds.add(u.Id);
            }
        } catch (Exception e) {
            System.debug('Failed to query department aligned users: ' + e.getMessage());
        }
        return userIds;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        String profileName = currentUserProfileName();
        return profileName == 'System Administrator' || profileName == 'Utkarsh Admin';
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserHr() {
        return currentUserProfileName() == 'Utkarsh HR';
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canViewAllFieldForceUsers() {
        String profileName = currentUserProfileName();
        return profileName == 'System Administrator'
            || profileName == 'Utkarsh Admin'
            || profileName == 'Utkarsh HR';
    }

    private static String currentUserProfileName() {
        List<Profile> pList = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        return pList.isEmpty() ? '' : pList[0].Name;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserHod() {
        User currentUser = [
            SELECT Profile.Name, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String profileName = currentUser.Profile != null ? currentUser.Profile.Name : '';
        if (profileName == 'Utkarsh HOD' || profileName == 'CRM Head' || profileName == 'Utkarsh CRM Head') {
            return true;
        }
        String roleName = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        if (String.isBlank(roleName)) {
            return false;
        }
        return roleName == 'CRM Head'
            || roleName.endsWith(' HOD')
            || roleName.endsWith(' CRM Head');
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canCurrentUserApproveWfh() {
        if (isCurrentUserAdmin()) {
            return true;
        }
        User currentUser = [
            SELECT Profile.Name, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String profileName = currentUser.Profile != null ? currentUser.Profile.Name : '';
        if (profileName == 'Utkarsh HOD') {
            return true;
        }
        String roleName = currentUser.UserRole != null ? currentUser.UserRole.Name : '';
        return String.isNotBlank(roleName) && roleName.endsWith(' HOD');
    }

    /**
     * Retrieves WFH and WFO request applications for all provided team users in the department.
     */
    @AuraEnabled
    public static List<DepartmentWFHRequestDTO> getTeamWFHRequests(List<Id> userIds) {
        List<DepartmentWFHRequestDTO> results = new List<DepartmentWFHRequestDTO>();
        if (userIds == null || userIds.isEmpty()) {
            return results;
        }

        for (Punch_Record__c pr : [
            SELECT Id, WFH_Request_Date__c, WFH_Request_Start_Time__c, WFH_Request_End_Time__c,
                   WFH_Approval_Status__c, Is_WFH_Request__c, Is_WFO_Request__c, User__c, User__r.Name,
                   WFH_Approver__c, WFH_Approver__r.Name, Approver_Remarks__c, WFH_Activity__c
            FROM Punch_Record__c
            WHERE User__c IN :userIds
            AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
            ORDER BY WFH_Request_Date__c DESC, CreatedDate DESC
            LIMIT 500
        ]) {
            DepartmentWFHRequestDTO dto = new DepartmentWFHRequestDTO();
            dto.requestId = pr.Id;
            dto.approverId = pr.WFH_Approver__c;
            dto.approverName = pr.WFH_Approver__r != null ? pr.WFH_Approver__r.Name : null;
            dto.userName = pr.User__r.Name;
            dto.userId = pr.User__c;
            dto.requestDate = pr.WFH_Request_Date__c;
            dto.startTime = pr.WFH_Request_Start_Time__c != null ? String.valueOf(pr.WFH_Request_Start_Time__c) : '';
            if (String.isNotBlank(dto.startTime) && dto.startTime.length() > 5) {
                dto.startTime = dto.startTime.substring(0, 5);
            }
            dto.endTime = pr.WFH_Request_End_Time__c != null ? String.valueOf(pr.WFH_Request_End_Time__c) : '';
            if (String.isNotBlank(dto.endTime) && dto.endTime.length() > 5) {
                dto.endTime = dto.endTime.substring(0, 5);
            }
            dto.status = pr.WFH_Approval_Status__c;
            dto.type = pr.Is_WFH_Request__c ? 'WFH' : 'WFO';
            dto.remarks = pr.Approver_Remarks__c;
            dto.requestNote = pr.WFH_Activity__c;
            results.add(dto);
        }

        attachCompletedSessionActivity(results);
        return results;
    }

    /**
     * For approved WFH/WFO requests, finds the matching session OUT punch(es) (same user, same type,
     * on the request date) and attaches the Day Activity Log captured when the session was ended.
     */
    private static void attachCompletedSessionActivity(List<DepartmentWFHRequestDTO> requests) {
        Set<Id> userIds = new Set<Id>();
        Date minDate;
        Date maxDate;
        for (DepartmentWFHRequestDTO dto : requests) {
            if (dto.status != 'Approved' || dto.requestDate == null) {
                continue;
            }
            userIds.add(dto.userId);
            if (minDate == null || dto.requestDate < minDate) minDate = dto.requestDate;
            if (maxDate == null || dto.requestDate > maxDate) maxDate = dto.requestDate;
        }
        if (userIds.isEmpty()) {
            return;
        }

        Datetime rangeStart = Datetime.newInstance(minDate, Time.newInstance(0, 0, 0, 0));
        Datetime rangeEnd = Datetime.newInstance(maxDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        // Key: userId|type|date -> OUT punches for that session day
        Map<String, List<Punch_Record__c>> outsByKey = new Map<String, List<Punch_Record__c>>();
        for (Punch_Record__c outRec : [
            SELECT Id, User__c, Punch_Type__c, Punch_Time__c,
                   No_of_Emails__c, No_of_Meetings__c, No_of_Offers_Sent__c, No_of_Phone_Calls__c, Open_Notes__c
            FROM Punch_Record__c
            WHERE User__c IN :userIds
              AND Action__c = 'OUT'
              AND Punch_Type__c IN ('WFH', 'WFO')
              AND Is_WFH_Request__c = false
              AND Is_WFO_Request__c = false
              AND Punch_Time__c >= :rangeStart
              AND Punch_Time__c < :rangeEnd
            ORDER BY Punch_Time__c ASC
        ]) {
            String key = outRec.User__c + '|' + outRec.Punch_Type__c + '|' + String.valueOf(outRec.Punch_Time__c.date());
            if (!outsByKey.containsKey(key)) {
                outsByKey.put(key, new List<Punch_Record__c>());
            }
            outsByKey.get(key).add(outRec);
        }

        for (DepartmentWFHRequestDTO dto : requests) {
            if (dto.status != 'Approved' || dto.requestDate == null) {
                continue;
            }
            List<Punch_Record__c> outs = outsByKey.get(dto.userId + '|' + dto.type + '|' + String.valueOf(dto.requestDate));
            if (outs == null || outs.isEmpty()) {
                continue;
            }
            dto.isCompleted = true;
            // If the user ran more than one session that day, roll the counts up and join the notes
            List<String> notes = new List<String>();
            for (Punch_Record__c outRec : outs) {
                dto.noOfEmails = addNullable(dto.noOfEmails, outRec.No_of_Emails__c);
                dto.noOfMeetings = addNullable(dto.noOfMeetings, outRec.No_of_Meetings__c);
                dto.noOfOffersSent = addNullable(dto.noOfOffersSent, outRec.No_of_Offers_Sent__c);
                dto.noOfPhoneCalls = addNullable(dto.noOfPhoneCalls, outRec.No_of_Phone_Calls__c);
                if (String.isNotBlank(outRec.Open_Notes__c)) {
                    notes.add(outRec.Open_Notes__c.trim());
                }
            }
            dto.openNotes = notes.isEmpty() ? null : String.join(notes, '\n\n');
        }
    }

    private static Decimal addNullable(Decimal total, Decimal value) {
        if (value == null) return total;
        return total == null ? value : total + value;
    }

    /**
     * Gets daily status data (Attendance, Timeline, Map coordinates) for a salesperson and date.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDailyDashboardData(String employeeId, Date statusDate) {
        if (String.isBlank(employeeId) || statusDate == null) {
            return null;
        }

        Id userId;
        try {
            userId = (Id) employeeId;
        } catch (Exception e) {
            return null;
        }

        // DateTime filters
        Datetime startOfDay = Datetime.newInstance(statusDate, Time.newInstance(0, 0, 0, 0));
        Datetime endOfDay = Datetime.newInstance(statusDate, Time.newInstance(23, 59, 59, 999));

        // Find the first "Day In" shift punch on this statusDate
        List<Punch_Record__c> todaysShiftStarts = [
            SELECT Punch_Time__c
            FROM Punch_Record__c
            WHERE User__c = :userId
              AND Action__c = 'IN'
              AND Punch_Type__c = 'Day In / Out'
              AND Punch_Time__c >= :startOfDay
              AND Punch_Time__c <= :endOfDay
            ORDER BY Punch_Time__c ASC
            LIMIT 1
        ];

        Datetime effectiveStart = startOfDay;
        Boolean hasDayInToday = !todaysShiftStarts.isEmpty();
        if (hasDayInToday) {
            effectiveStart = todaysShiftStarts[0].Punch_Time__c;
        } else {
            effectiveStart = startOfDay;
        }

        // 2. Fetch data directly using User ID
        List<Punch_Record__c> punches = [
            SELECT Id, Action__c, Status__c, Punch_Time__c, Latitude__c, Longitude__c, Address__c, Battery__c, Punch_Type__c,
                   Transportation_Type__c, Vehicle_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c, Odometer_Distance__c,
                   WFH_Activity__c, WFH_Approval_Status__c, Device_Model__c, Device_OS__c
            FROM Punch_Record__c
            WHERE User__c = :userId
              AND Punch_Time__c >= :effectiveStart
              AND Punch_Time__c <= :endOfDay
              AND Is_WFH_Request__c = false
              AND Is_WFO_Request__c = false
            ORDER BY Punch_Time__c ASC
        ];

        // Fetch prior check-in (limit to last 7 days to keep query volume small)
        List<Punch_Record__c> priorPunches = [
            SELECT Id, Action__c, Status__c, Punch_Time__c, Latitude__c, Longitude__c, Address__c, Battery__c, Punch_Type__c,
                   Transportation_Type__c, Vehicle_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c, Odometer_Distance__c,
                   WFH_Activity__c, WFH_Approval_Status__c, Device_Model__c, Device_OS__c
            FROM Punch_Record__c
            WHERE User__c = :userId
              AND Punch_Time__c < :startOfDay
              AND Punch_Time__c >= :startOfDay.addDays(-7)
              AND Is_WFH_Request__c = false AND Is_WFO_Request__c = false
            ORDER BY Punch_Time__c DESC
            LIMIT 1
        ];

        List<Punch_Record__c> allPunchesForSummary = new List<Punch_Record__c>();
        if (hasDayInToday) {
            if (!priorPunches.isEmpty() && priorPunches[0].Action__c == 'IN') {
                allPunchesForSummary.add(priorPunches[0]);
            }
            allPunchesForSummary.addAll(punches);
        } else if (!punches.isEmpty()) {
            allPunchesForSummary.addAll(punches);
        }

        List<Task_Log__c> logs = [
            SELECT Id, Name, Description__c, Reason_for_Visit__c, Visit_Type__c, Visit_outcome__c, Visit_Status__c,
                   IsCheckout__c, Logged_At__c, Logged_Out_At__c, Latitude__c, Longitude__c, Checked_Out_Latitude__c, Checked_Out_Longitude__c,
                   MOM__c, Next_Action__c, Next_Follow_Up_Date__c, Account__r.Name, Lead__r.Name, Opportunity__r.Name,
                   Customer_Type__c, is100mOutside__c, Justification__c, Battery__c, GPS_On__c, Address__c, Client_Deatils__r.Name,
                   Visit_Category__c
            FROM Task_Log__c
            WHERE CreatedById = :userId
              AND Logged_At__c >= :effectiveStart
              AND Logged_At__c <= :endOfDay
            ORDER BY Logged_At__c ASC
        ];

        Set<Id> punchIds = new Set<Id>();
        for (Punch_Record__c p : punches) {
            punchIds.add(p.Id);
        }

        List<Track_Location__c> tracks = new List<Track_Location__c>();
        if (!punchIds.isEmpty()) {
            tracks = [
                SELECT Id, Latitude__c, Longitude__c, Source__c, CreatedDate, Recorded_At__c, Punch_Record__c
                FROM Track_Location__c
                WHERE Punch_Record__c IN :punchIds
                ORDER BY Recorded_At__c ASC NULLS LAST, CreatedDate ASC
            ];
        } else {
            tracks = [
                SELECT Id, Latitude__c, Longitude__c, Source__c, CreatedDate, Recorded_At__c, Punch_Record__c
                FROM Track_Location__c
                WHERE Punch_Record__r.User__c = :userId
                  AND (
                        (Recorded_At__c != null AND Recorded_At__c >= :effectiveStart AND Recorded_At__c <= :endOfDay)
                     OR (Recorded_At__c = null AND CreatedDate >= :effectiveStart AND CreatedDate <= :endOfDay)
                  )
                ORDER BY Recorded_At__c ASC NULLS LAST, CreatedDate ASC
            ];
        }

        // 3. Collect Files/Attachments
        Set<Id> parentIds = new Set<Id>();
        for (Punch_Record__c p : punches) parentIds.add(p.Id);
        for (Task_Log__c l : logs) parentIds.add(l.Id);

        Map<Id, List<Map<String, String>>> fileMap = new Map<Id, List<Map<String, String>>>();
        if (!parentIds.isEmpty()) {
            // FirstPublishLocationId queries
            for (ContentVersion cv : [
                SELECT Id, FirstPublishLocationId, Title, FileExtension, FileType
                FROM ContentVersion
                WHERE FirstPublishLocationId IN :parentIds AND IsLatest = true
            ]) {
                if (!fileMap.containsKey(cv.FirstPublishLocationId)) {
                    fileMap.put(cv.FirstPublishLocationId, new List<Map<String, String>>());
                }
                Map<String, String> fileInfo = new Map<String, String>();
                fileInfo.put('id', cv.Id);
                fileInfo.put('title', cv.Title);
                fileInfo.put('extension', cv.FileExtension);
                fileInfo.put('url', '/sfc/servlet.shepherd/version/download/' + cv.Id);
                fileMap.get(cv.FirstPublishLocationId).add(fileInfo);
            }

            // ContentDocumentLink queries
            Map<Id, Set<Id>> entityToDocIds = new Map<Id, Set<Id>>();
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId, ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :parentIds
            ]) {
                if (!entityToDocIds.containsKey(cdl.LinkedEntityId)) {
                    entityToDocIds.put(cdl.LinkedEntityId, new Set<Id>());
                }
                entityToDocIds.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            }

            if (!entityToDocIds.isEmpty()) {
                Set<Id> docIds = new Set<Id>();
                for (Set<Id> ids : entityToDocIds.values()) {
                    docIds.addAll(ids);
                }
                Map<Id, ContentVersion> docToVersionMap = new Map<Id, ContentVersion>();
                for (ContentVersion cv : [
                    SELECT ContentDocumentId, Id, Title, FileExtension, FileType
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds AND IsLatest = true
                ]) {
                    docToVersionMap.put(cv.ContentDocumentId, cv);
                }

                for (Id entityId : entityToDocIds.keySet()) {
                    if (!fileMap.containsKey(entityId)) {
                        fileMap.put(entityId, new List<Map<String, String>>());
                    }
                    for (Id dId : entityToDocIds.get(entityId)) {
                        if (docToVersionMap.containsKey(dId)) {
                            ContentVersion cv = docToVersionMap.get(dId);
                            Boolean exists = false;
                            for (Map<String, String> existing : fileMap.get(entityId)) {
                                if (existing.get('id') == cv.Id) {
                                    exists = true;
                                    break;
                                }
                            }
                            if (!exists) {
                                Map<String, String> fileInfo = new Map<String, String>();
                                fileInfo.put('id', cv.Id);
                                fileInfo.put('title', cv.Title);
                                fileInfo.put('extension', cv.FileExtension);
                                fileInfo.put('url', '/sfc/servlet.shepherd/version/download/' + cv.Id);
                                fileMap.get(entityId).add(fileInfo);
                            }
                        }
                    }
                }
            }
        }

        // 4. Construct Timeline Items
        List<TimelineItem> timelineList = new List<TimelineItem>();

        for (Punch_Record__c p : punches) {
            TimelineItem item = new TimelineItem();
            item.id = p.Id;
            item.type = (p.Action__c == 'IN') ? 'PUNCH_IN' : 'PUNCH_OUT';
            item.isCheckout = (p.Action__c == 'OUT');
            item.action = p.Action__c;
            item.status = p.Status__c;
            item.punchTypeOfRecord = p.Punch_Type__c;
            item.eventTime = p.Punch_Time__c;
            item.timeLabel = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : '';
            item.title = (p.Action__c == 'IN') 
                ? (p.Punch_Type__c == 'Day In / Out' ? 'Shift Day In' : 'Shift Punch In (' + p.Punch_Type__c + ')') 
                : (p.Punch_Type__c == 'Day In / Out' ? 'Shift Day Out' : 'Shift Punch Out (' + p.Punch_Type__c + ')');
            item.description = (p.Action__c == 'IN') 
                ? 'Started work shift ' + (p.Transportation_Type__c != null ? 'using ' + p.Transportation_Type__c : '') + (p.Odometer_Reading__c != null ? ' (Odometer: ' + p.Odometer_Reading__c + ')' : '')
                : 'Ended work shift' + (p.Odometer_Reading__c != null ? ' (Odometer: ' + p.Odometer_Reading__c + ')' : '');
            item.latitude = p.Latitude__c;
            item.longitude = p.Longitude__c;
            item.address = p.Address__c;
            item.badgeText = (p.Action__c == 'IN') ? 'IN' : 'OUT';
            item.badgeClass = (p.Action__c == 'IN') ? 'badge-in' : 'badge-out';
            item.files = fileMap.get(p.Id);
            item.transportType = p.Transportation_Type__c;
            item.vehicleType = p.Vehicle_Type__c;
            item.odometer = p.Odometer_Reading__c;
            timelineList.add(item);
        }

        for (Task_Log__c l : logs) {
            String clientName = '';
            if (l.Client_Deatils__r != null) clientName = l.Client_Deatils__r.Name;
            else if (l.Account__r != null) clientName = l.Account__r.Name;
            else if (l.Lead__r != null) clientName = l.Lead__r.Name;
            else if (l.Opportunity__r != null) clientName = l.Opportunity__r.Name;
            else clientName = 'Unknown Account';

            // Add single Combined Visit TimelineItem
            TimelineItem visitItem = new TimelineItem();
            visitItem.id = l.Id;
            visitItem.type = 'VISIT';
            visitItem.eventTime = l.Logged_At__c != null ? l.Logged_At__c : l.Logged_Out_At__c;
            visitItem.timeLabel = l.Logged_At__c != null ? l.Logged_At__c.format('hh:mm a') : (l.Logged_Out_At__c != null ? l.Logged_Out_At__c.format('hh:mm a') : '');
            visitItem.clientName = clientName;
            visitItem.title = (l.Visit_Category__c == 'WFH' ? 'WFH Visit @ ' : (l.Visit_Category__c == 'WFO' ? 'WFO Visit @ ' : 'Visit @ ')) + clientName;
            visitItem.description = 'Reason: ' + l.Reason_for_Visit__c + ' | Type: ' + l.Visit_Type__c + ' | Category: ' + l.Visit_Category__c;
            visitItem.visitCategory = l.Visit_Category__c;
            visitItem.latitude = l.Latitude__c;
            visitItem.longitude = l.Longitude__c;
            visitItem.address = l.Address__c;
            visitItem.badgeText = 'VISIT';
            visitItem.badgeClass = 'badge-visit';
            visitItem.visitType = l.Visit_Type__c;
            visitItem.reasonForVisit = l.Reason_for_Visit__c;
            visitItem.files = fileMap.get(l.Id);
            visitItem.isCheckout = l.IsCheckout__c;
            visitItem.action = 'VISIT';
            visitItem.status = 'VISIT';
            visitItem.punchTypeOfRecord = '';
            
            visitItem.checkInTime = l.Logged_At__c != null ? l.Logged_At__c.format('hh:mm a') : 'N/A';
            visitItem.checkOutTime = (l.IsCheckout__c && l.Logged_Out_At__c != null) ? l.Logged_Out_At__c.format('hh:mm a') : 'Active';
            
            // Calculate distance between check-in and check-out
            Decimal dist = calculateDistance(l.Latitude__c, l.Longitude__c, l.Checked_Out_Latitude__c, l.Checked_Out_Longitude__c);
            visitItem.visitDistance = dist.setScale(2) + ' km';

            // Duration calculation
            if (l.Logged_At__c != null && l.Logged_Out_At__c != null) {
                Long durationMs = l.Logged_Out_At__c.getTime() - l.Logged_At__c.getTime();
                Long durationMin = durationMs / (1000 * 60);
                if (durationMin < 60) {
                    visitItem.visitDuration = durationMin + ' mins';
                } else {
                    Long hours = durationMin / 60;
                    Long mins = Math.mod(durationMin, 60);
                    visitItem.visitDuration = hours + ' hr ' + mins + ' mins';
                }
            } else {
                visitItem.visitDuration = 'In Progress';
            }
            
            // Checkout details if completed
            if (l.IsCheckout__c) {
                visitItem.visitOutcome = l.Visit_outcome__c;
                visitItem.mom = l.MOM__c;
                visitItem.nextAction = l.Next_Action__c;
                visitItem.followUpDate = l.Next_Follow_Up_Date__c != null ? l.Next_Follow_Up_Date__c.format() : '';
                visitItem.is100mOutside = l.is100mOutside__c;
                visitItem.justification = l.Justification__c;
            }
            
            timelineList.add(visitItem);
        }

        // Sort chronologically
        timelineList.sort();

        // Actual traveled KM per timeline point: sum GPS breadcrumbs between events
        List<TravelPoint> trackPoints = travelPointsFromTracks(tracks);
        TimelineItem prevItem = null;
        Boolean isFirst = true;
        Decimal totalTimelineKm = 0;
        for (TimelineItem item : timelineList) {
            if (isFirst) {
                item.nodeDistance = 'Start';
                isFirst = false;
            } else if (item.latitude != null && item.longitude != null
                    && prevItem != null && prevItem.latitude != null && prevItem.longitude != null) {
                Decimal dist = sumActualTravelKm(
                    prevItem.latitude, prevItem.longitude, prevItem.eventTime,
                    item.latitude, item.longitude, item.eventTime,
                    trackPoints
                );
                item.nodeDistance = formatNodeKm(dist);
                if (dist != null) {
                    totalTimelineKm += dist;
                }
            } else {
                item.nodeDistance = '0 KM';
            }

            if (item.latitude != null && item.longitude != null) {
                prevItem = item;
            }
        }

        // 5. Construct Attendance Summary
        AttendanceSummary summary = new AttendanceSummary();
        summary.totalVisits = logs.size();
        summary.attendanceStatus = 'Absent';
        summary.gpsStatus = 'Offline';

        Decimal odometerDistance = 0;

        for (Punch_Record__c p : punches) {
            if (p.Odometer_Distance__c != null) {
                odometerDistance += p.Odometer_Distance__c;
            }
        }

        summary.odometerDistanceKm = odometerDistance.setScale(2);

        if (!allPunchesForSummary.isEmpty()) {
            // Find Punch In
            for (Punch_Record__c p : allPunchesForSummary) {
                if (p.Action__c == 'IN') {
                    summary.punchInTime = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : '';
                    summary.startingOdometer = p.Odometer_Reading__c;
                    //summary.startingExtractedOdometer = p.Extracted_Odometer_Reading__c;
                    summary.inLocation = p.Address__c;
                    if (p.Battery__c != null) {
                        summary.batteryLevel = p.Battery__c;
                    }
                    break;
                }
            }
            
            // Find Punch Out (last one that is a shift Day Out)
            for (Integer i = allPunchesForSummary.size() - 1; i >= 0; i--) {
                Punch_Record__c p = allPunchesForSummary[i];
                if (p.Action__c == 'OUT' && p.Punch_Type__c == 'Day In / Out') {
                    summary.punchOutTime = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : '';
                    summary.endingOdometer = p.Odometer_Reading__c;
                    //summary.endingExtractedOdometer = p.Extracted_Odometer_Reading__c;
                    summary.outLocation = p.Address__c;
                    if (p.Battery__c != null) {
                        summary.batteryLevel = p.Battery__c;
                    }
                    break;
                }
            }

            // Sum all punched-in intervals
            Datetime firstIn = null;
            Datetime lastOut = null;
            Long totalStayMs = 0;
            Datetime currentIn = null;

            for (Punch_Record__c p : allPunchesForSummary) {
                if (p.Action__c == 'IN') {
                    if (firstIn == null) {
                        firstIn = p.Punch_Time__c;
                    }
                    if (currentIn == null) {
                        currentIn = (p.Punch_Time__c < startOfDay) ? startOfDay : p.Punch_Time__c;
                    }
                } else if (p.Action__c == 'OUT') {
                    if (p.Punch_Type__c == 'Day In / Out') {
                        lastOut = p.Punch_Time__c;
                        if (currentIn != null) {
                            totalStayMs += (p.Punch_Time__c.getTime() - currentIn.getTime());
                            currentIn = null;
                        }
                    } else {
                        // Category OUT: add stay duration, but keep counting since shift is still running
                        if (currentIn != null) {
                            totalStayMs += (p.Punch_Time__c.getTime() - currentIn.getTime());
                        }
                        currentIn = p.Punch_Time__c; // Resume counting
                    }
                }
            }

            if (currentIn != null) {
                Datetime compareTime = (statusDate == Date.today() ? System.now() : endOfDay);
                if (compareTime > currentIn) {
                    totalStayMs += (compareTime.getTime() - currentIn.getTime());
                }
            }

            // Calculate total working hours
            Boolean isCurrentlyActive = false;
            for (Integer i = allPunchesForSummary.size() - 1; i >= 0; i--) {
                Punch_Record__c p = allPunchesForSummary[i];
                if (p.Punch_Type__c == 'Day In / Out') {
                    isCurrentlyActive = (p.Action__c == 'IN' && statusDate == Date.today());
                    break;
                }
            }

            if (firstIn != null) {
                Decimal stayHrs = Decimal.valueOf(totalStayMs) / (1000.0 * 60.0 * 60.0);
                summary.totalHours = stayHrs.setScale(2) + ' hrs' + (isCurrentlyActive ? ' (Active)' : '');
            } else {
                summary.totalHours = 'N/A';
            }

            // Attendance Status Logic based on first Punch in and last Punch out
            Datetime attCompareTime = (lastOut != null) ? lastOut : (statusDate == Date.today() ? System.now() : endOfDay);
            if (firstIn != null) {
                Long elapsedMs = attCompareTime.getTime() - firstIn.getTime();
                Decimal elapsedHrs = Decimal.valueOf(elapsedMs) / (1000.0 * 60.0 * 60.0);
                
                if (!isCurrentlyActive && elapsedHrs < 9.0) {
                    summary.attendanceStatus = 'Short Hours';
                } else if (!isCurrentlyActive) {
                    summary.attendanceStatus = 'Offline';
                } else {
                    Punch_Record__c latestPunch = allPunchesForSummary[allPunchesForSummary.size() - 1];
                    String activeMode = 'Present';
                    if (latestPunch.Action__c == 'IN' && latestPunch.Punch_Type__c != 'Day In / Out' && latestPunch.Punch_Type__c != null) {
                        activeMode = latestPunch.Punch_Type__c;
                    }
                    summary.attendanceStatus = activeMode;
                }
            } else {
                summary.attendanceStatus = 'Absent';
            }

            // Calculate Odometer diff
            if (summary.startingOdometer != null && summary.endingOdometer != null) {
                summary.totalDistanceKm = summary.endingOdometer - summary.startingOdometer;
            }

            // Calculate Extracted Odometer diff
            /*if (summary.startingExtractedOdometer != null && summary.endingExtractedOdometer != null) {
                summary.odometerDistanceKm = summary.endingExtractedOdometer - summary.startingExtractedOdometer;
            }*/
        }

        // Calculate GPS route distance using periodic track breadcrumbs (primary — most accurate)
        // Falls back to straight-line check-in distances if no tracks exist
        Decimal gpsDistance = 0;
        Decimal prevLat = null;
        Decimal prevLng = null;

        // Mark GPS as Active if any timeline item or track has coordinates
        for (TimelineItem item : timelineList) {
            if (item.latitude != null && item.longitude != null) {
                summary.gpsStatus = 'Active';
                break;
            }
        }

        if (!tracks.isEmpty()) {
            // Primary: use periodic track breadcrumbs for accurate travel distance
            for (Track_Location__c tl : tracks) {
                if (String.isBlank(tl.Latitude__c) || String.isBlank(tl.Longitude__c)) continue;
                Decimal tLat, tLng;
                try {
                    tLat = Decimal.valueOf(tl.Latitude__c);
                    tLng = Decimal.valueOf(tl.Longitude__c);
                } catch (Exception ex) { continue; }

                summary.gpsStatus = 'Active';
                if (prevLat != null && prevLng != null) {
                    Decimal segDist = calculateDistanceKm(prevLat, prevLng, tLat, tLng);
                    if (segDist < 0.03) continue; // skip jitter < 30m
                    gpsDistance += segDist;
                }
                prevLat = tLat;
                prevLng = tLng;
            }
        } else {
            // Fallback: straight-line distance between PUNCH/VISIT check-in points
            for (TimelineItem item : timelineList) {
                if (item.latitude != null && item.longitude != null) {
                    if (prevLat != null && prevLng != null) {
                        gpsDistance += calculateDistanceKm(prevLat, prevLng, item.latitude, item.longitude);
                    }
                    prevLat = item.latitude;
                    prevLng = item.longitude;
                }
            }
        }

        if (summary.totalDistanceKm == null || summary.totalDistanceKm <= 0) {
            if (totalTimelineKm > 0) {
                summary.totalDistanceKm = totalTimelineKm.setScale(2);
            } else {
                summary.totalDistanceKm = gpsDistance.setScale(2);
            }
        }

        // Calculate distance deviation
        if (summary.totalDistanceKm != null && summary.odometerDistanceKm != null) {
            summary.distanceDeviationKm =
                (summary.totalDistanceKm - summary.odometerDistanceKm).setScale(2);

            if (summary.odometerDistanceKm != 0) {
                summary.distanceDeviationPercent =
                    ((summary.distanceDeviationKm / summary.odometerDistanceKm) * 100).setScale(2);
            } else {
                summary.distanceDeviationPercent = 0;
            }
        }


        // 6. Generate Map Markers
        List<MapMarker> markers = new List<MapMarker>();
        Integer markerIndex = 1;
        for (TimelineItem item : timelineList) {
            if (item.latitude != null && item.longitude != null) {
                MapMarker marker = new MapMarker();
                marker.location = new MapLocation();
                marker.location.Latitude = (Double)item.latitude;
                marker.location.Longitude = (Double)item.longitude;
                marker.title = markerIndex + '. ' + item.title;
                marker.description = item.timeLabel + ' - ' + item.description;
                markers.add(marker);
                markerIndex++;
            }
        }

        List<TrackLocationDTO> trackLocationsList = new List<TrackLocationDTO>();
        for (Track_Location__c trackLoc : tracks) {
            if (String.isNotBlank(trackLoc.Latitude__c) && String.isNotBlank(trackLoc.Longitude__c)) {
                try {
                    TrackLocationDTO dto = new TrackLocationDTO();
                    dto.latitude = Decimal.valueOf(trackLoc.Latitude__c);
                    dto.longitude = Decimal.valueOf(trackLoc.Longitude__c);
                    dto.createdDate = trackLoc.Recorded_At__c != null ? trackLoc.Recorded_At__c : trackLoc.CreatedDate;
                    trackLocationsList.add(dto);
                } catch (Exception ex) {
                    // Ignore malformed coordinates
                }
            }
        }

        // 7. Build Visit Nodes for numbered map markers
        List<VisitNodeDTO> visitNodesList = new List<VisitNodeDTO>();
        Integer nodeNum = 1;
        for (Task_Log__c l : logs) {
            if (l.Latitude__c == null || l.Longitude__c == null) continue;
            String clientName = '';
            if (l.Client_Deatils__r != null) clientName = l.Client_Deatils__r.Name;
            else if (l.Account__r != null) clientName = l.Account__r.Name;
            else if (l.Lead__r != null) clientName = l.Lead__r.Name;
            else if (l.Opportunity__r != null) clientName = l.Opportunity__r.Name;
            else clientName = 'Visit';

            VisitNodeDTO vn = new VisitNodeDTO();
            vn.nodeNumber   = nodeNum++;
            vn.latitude     = l.Latitude__c;
            vn.longitude    = l.Longitude__c;
            vn.clientName   = clientName;
            vn.checkInTime  = l.Logged_At__c != null ? l.Logged_At__c.format('hh:mm a') : 'N/A';
            vn.checkOutTime = (l.IsCheckout__c && l.Logged_Out_At__c != null)
                              ? l.Logged_Out_At__c.format('hh:mm a') : 'Active';
            if (l.Logged_At__c != null && l.Logged_Out_At__c != null) {
                Long durationMin = (l.Logged_Out_At__c.getTime() - l.Logged_At__c.getTime()) / (1000 * 60);
                if (durationMin < 0) durationMin = 0;
                if (durationMin < 60) {
                    vn.visitDuration = durationMin + ' mins';
                } else {
                    Long hours = durationMin / 60;
                    Long mins = Math.mod(durationMin, 60);
                    vn.visitDuration = hours + ' hr ' + mins + ' mins';
                }
            } else if (!l.IsCheckout__c) {
                vn.visitDuration = 'In Progress';
            }
            vn.visitCategory = l.Visit_Category__c;
            vn.visitType     = l.Visit_Type__c;
            vn.isActive      = !l.IsCheckout__c;
            visitNodesList.add(vn);
        }

        // 8. Build Punch Markers for map (Day In -> DI, Day Out -> DO, Market Visit Start -> S, Market Visit End -> E)
        List<PunchMarkerDTO> punchMarkersList = new List<PunchMarkerDTO>();
        for (Punch_Record__c p : punches) {
            Double lat = null;
            Double lng = null;
            if (p.Latitude__c != null && p.Longitude__c != null) {
                lat = (Double)p.Latitude__c;
                lng = (Double)p.Longitude__c;
            } else if (!tracks.isEmpty()) {
                if (p.Action__c == 'IN') {
                    try {
                        lat = Double.valueOf(tracks[0].Latitude__c);
                        lng = Double.valueOf(tracks[0].Longitude__c);
                    } catch (Exception e) {}
                } else if (p.Action__c == 'OUT') {
                    try {
                        lat = Double.valueOf(tracks[tracks.size() - 1].Latitude__c);
                        lng = Double.valueOf(tracks[tracks.size() - 1].Longitude__c);
                    } catch (Exception e) {}
                }
            }

            if (lat == null || lng == null) {
                continue;
            }

            PunchMarkerDTO pm = new PunchMarkerDTO();
            pm.id = p.Id;
            pm.punchType = p.Punch_Type__c;
            pm.action = p.Action__c;
            pm.latitude = lat;
            pm.longitude = lng;
            pm.address = p.Address__c;
            pm.timeLabel = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : '';

            if (p.Punch_Type__c == 'Day In / Out') {
                if (p.Action__c == 'IN') {
                    pm.label = 'DI';
                    pm.title = 'Day In';
                    pm.color = '#10B981';
                } else if (p.Action__c == 'OUT') {
                    pm.label = 'DO';
                    pm.title = 'Day Out';
                    pm.color = '#EF4444';
                }
            } else if (p.Punch_Type__c == 'Market Visit') {
                if (p.Action__c == 'IN') {
                    pm.label = 'S';
                    pm.title = 'Market Visit Start';
                    pm.color = '#2563EB';
                } else if (p.Action__c == 'OUT') {
                    pm.label = 'E';
                    pm.title = 'Market Visit End';
                    pm.color = '#DC2626';
                }
            }

            if (pm.label != null) {
                punchMarkersList.add(pm);
            }
        }

        DashboardData data = new DashboardData();
        data.attendanceSummary = summary;
        data.timeline = timelineList;
        data.mapMarkers = markers;
        data.trackLocations = trackLocationsList;
        data.visitNodes = visitNodesList;
        data.punchMarkers = punchMarkersList;
        return data;
    }

    public class TravelPoint {
        public Decimal lat;
        public Decimal lng;
        public Datetime eventTime;
    }

    public static List<TravelPoint> travelPointsFromTracks(List<Track_Location__c> tracks) {
        List<TravelPoint> points = new List<TravelPoint>();
        if (tracks == null) {
            return points;
        }
        for (Track_Location__c tl : tracks) {
            if (String.isBlank(tl.Latitude__c) || String.isBlank(tl.Longitude__c)) {
                continue;
            }
            TravelPoint p = new TravelPoint();
            try {
                p.lat = Decimal.valueOf(tl.Latitude__c);
                p.lng = Decimal.valueOf(tl.Longitude__c);
            } catch (Exception e) {
                continue;
            }
            p.eventTime = tl.Recorded_At__c != null ? tl.Recorded_At__c : tl.CreatedDate;
            points.add(p);
        }
        return points;
    }

    public static Decimal sumActualTravelKm(
        Decimal startLat, Decimal startLng, Datetime startTime,
        Decimal endLat, Decimal endLng, Datetime endTime,
        List<TravelPoint> tracks
    ) {
        if (startLat == null || startLng == null || endLat == null || endLng == null) {
            return 0;
        }

        List<TravelPoint> path = new List<TravelPoint>();
        TravelPoint start = new TravelPoint();
        start.lat = startLat;
        start.lng = startLng;
        start.eventTime = startTime;
        path.add(start);

        if (tracks != null && startTime != null && endTime != null) {
            for (TravelPoint t : tracks) {
                if (t == null || t.eventTime == null || t.lat == null || t.lng == null) {
                    continue;
                }
                if (t.eventTime > startTime && t.eventTime <= endTime) {
                    path.add(t);
                }
            }
        }

        TravelPoint finish = new TravelPoint();
        finish.lat = endLat;
        finish.lng = endLng;
        finish.eventTime = endTime;
        path.add(finish);

        return sumPathKm(path);
    }

    public static String formatNodeKm(Decimal km) {
        if (km == null) {
            return '0 KM';
        }
        return km.setScale(1) + ' KM';
    }

    private static Decimal sumPathKm(List<TravelPoint> path) {
        Decimal total = 0;
        Decimal prevLat = null;
        Decimal prevLng = null;
        for (TravelPoint p : path) {
            if (p == null || p.lat == null || p.lng == null) {
                continue;
            }
            if (prevLat != null && prevLng != null) {
                Decimal seg = calculateDistanceKm(prevLat, prevLng, p.lat, p.lng);
                if (seg < 0.03) {
                    continue; // skip jitter < 30m
                }
                total += seg;
            }
            prevLat = p.lat;
            prevLng = p.lng;
        }
        return total;
    }

    private static Decimal calculateDistanceKm(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        Double dLat1 = (Double)lat1;
        Double dLon1 = (Double)lon1;
        Double dLat2 = (Double)lat2;
        Double dLon2 = (Double)lon2;

        Double rLat1 = dLat1 * Math.PI / 180;
        Double rLon1 = dLon1 * Math.PI / 180;
        Double rLat2 = dLat2 * Math.PI / 180;
        Double rLon2 = dLon2 * Math.PI / 180;

        Double dlat = rLat2 - rLat1;
        Double dlon = rLon2 - rLon1;

        Double a = Math.pow(Math.sin(dlat / 2), 2)
                 + Math.cos(rLat1) * Math.cos(rLat2)
                 * Math.pow(Math.sin(dlon / 2), 2);

        Double c = 2 * Math.asin(Math.min(1, Math.sqrt(a)));

        Double distance = 6371.0 * c; // Earth radius in km
        return (Decimal)distance;
    }

    public class UserSummaryData {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String userPhone;
        @AuraEnabled public String attendanceStatus;
        @AuraEnabled public String punchInTime;
        @AuraEnabled public String punchOutTime;
        @AuraEnabled public String totalHours;
        @AuraEnabled public Decimal distanceKm;
        @AuraEnabled public String batteryLevel;
        @AuraEnabled public String gpsStatus;
        @AuraEnabled public Integer visitsCount;
        @AuraEnabled public String lastAddress;
        @AuraEnabled public String lastActivityTime;
        @AuraEnabled public String activeSinceTime;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserSummaryData> getMultipleUsersDailySummary(List<Id> userIds, Date statusDate) {
        List<UserSummaryData> summaries = new List<UserSummaryData>();
        if (userIds == null || userIds.isEmpty() || statusDate == null) {
            return summaries;
        }

        Datetime startOfDay = Datetime.newInstance(statusDate, Time.newInstance(0, 0, 0, 0));
        Datetime endOfDay = Datetime.newInstance(statusDate, Time.newInstance(23, 59, 59, 999));

        // 1. Query punches for all target users
        Map<Id, List<Punch_Record__c>> userPunches = new Map<Id, List<Punch_Record__c>>();
        for (Id uid : userIds) {
            userPunches.put(uid, new List<Punch_Record__c>());
        }
        for (Punch_Record__c p : [
            SELECT Id, User__c, Action__c, Status__c, Punch_Time__c, Battery__c, Punch_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c, Odometer_Distance__c, Address__c, Latitude__c, Longitude__c
            FROM Punch_Record__c
            WHERE User__c IN :userIds
              AND Punch_Time__c >= :startOfDay
              AND Punch_Time__c <= :endOfDay
              AND Is_WFH_Request__c = false
              AND Is_WFO_Request__c = false
            ORDER BY Punch_Time__c ASC
        ]) {
            userPunches.get(p.User__c).add(p);
        }

        // Query the prior check-ins for the users (limit to last 7 days to keep query small)
        Map<Id, Punch_Record__c> priorPunchesMap = new Map<Id, Punch_Record__c>();
        Datetime limitDate = startOfDay.addDays(-7);
        for (Punch_Record__c p : [
            SELECT Id, User__c, Action__c, Status__c, Punch_Time__c, Battery__c, Punch_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c, Odometer_Distance__c, Address__c, Latitude__c, Longitude__c
            FROM Punch_Record__c
            WHERE User__c IN :userIds
              AND Punch_Time__c < :startOfDay
              AND Punch_Time__c >= :limitDate
              AND Is_WFH_Request__c = false AND Is_WFO_Request__c = false
              // ---------------------------------------------------------
              AND Punch_Type__c = 'Day In / Out'
            ORDER BY User__c, Punch_Time__c DESC
        ]) {
            if (!priorPunchesMap.containsKey(p.User__c)) {
                priorPunchesMap.put(p.User__c, p);
            }
        }

        // 2. Query visit logs for all target users
        Map<Id, Integer> userVisits = new Map<Id, Integer>();
        Map<Id, List<Task_Log__c>> userLogsMap = new Map<Id, List<Task_Log__c>>();
        for (Id uid : userIds) {
            userVisits.put(uid, 0);
            userLogsMap.put(uid, new List<Task_Log__c>());
        }
        for (Task_Log__c tl : [
            SELECT Id, CreatedById, Logged_At__c, Latitude__c, Longitude__c
            FROM Task_Log__c
            WHERE CreatedById IN :userIds
              AND Logged_At__c >= :startOfDay
              AND Logged_At__c <= :endOfDay
            ORDER BY Logged_At__c ASC
        ]) {
            userVisits.put(tl.CreatedById, userVisits.get(tl.CreatedById) + 1);
            userLogsMap.get(tl.CreatedById).add(tl);
        }

        // 3. Query track locations to calculate GPS fallback distances in bulk
        Map<Id, Decimal> gpsDistances = new Map<Id, Decimal>();
        Map<Id, String> lastGpsStatuses = new Map<Id, String>();
        Map<Id, List<Track_Location__c>> userTracksMap = new Map<Id, List<Track_Location__c>>();
        for (Id uid : userIds) {
            gpsDistances.put(uid, 0.0);
            lastGpsStatuses.put(uid, 'Offline');
            userTracksMap.put(uid, new List<Track_Location__c>());
        }

        Map<Id, Decimal> prevLats = new Map<Id, Decimal>();
        Map<Id, Decimal> prevLngs = new Map<Id, Decimal>();

        for (Track_Location__c t : [
            SELECT Latitude__c, Longitude__c, Source__c, Punch_Record__r.User__c, Recorded_At__c, CreatedDate
            FROM Track_Location__c
            WHERE Punch_Record__r.User__c IN :userIds
              AND (
                    (Recorded_At__c != null AND Recorded_At__c >= :startOfDay AND Recorded_At__c <= :endOfDay)
                 OR (Recorded_At__c = null AND CreatedDate >= :startOfDay AND CreatedDate <= :endOfDay)
              )
              AND Latitude__c != null 
              AND Longitude__c != null
            ORDER BY Punch_Record__r.User__c, Recorded_At__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            Id uid = t.Punch_Record__r.User__c;
            userTracksMap.get(uid).add(t);
            Decimal lat = null;
            Decimal lng = null;
            try {
                lat = Decimal.valueOf(t.Latitude__c);
                lng = Decimal.valueOf(t.Longitude__c);
            } catch (Exception ex) {}

            if (lat != null && lng != null) {
                lastGpsStatuses.put(uid, 'Active');

                if (prevLats.containsKey(uid) && prevLngs.containsKey(uid)) {
                    gpsDistances.put(uid, gpsDistances.get(uid) + calculateDistanceKm(prevLats.get(uid), prevLngs.get(uid), lat, lng));
                }
                prevLats.put(uid, lat);
                prevLngs.put(uid, lng);
            }
        }

        // 4. Query standard User details to compile summary records
        for (User u : [SELECT Id, Name, Phone FROM User WHERE Id IN :userIds ORDER BY Name ASC]) {
            UserSummaryData summary = new UserSummaryData();
            summary.userId = u.Id;
            summary.userName = u.Name;
            summary.userPhone = u.Phone != null ? u.Phone : '';

            List<Punch_Record__c> punches = userPunches.get(u.Id);
            List<Punch_Record__c> allPunchesForSummary = new List<Punch_Record__c>();
            if (priorPunchesMap.containsKey(u.Id) && priorPunchesMap.get(u.Id).Action__c == 'IN'
            // ---------------------------------------------------------
            && priorPunchesMap.get(u.Id).Punch_Type__c == 'Day In / Out'
            ) {
                allPunchesForSummary.add(priorPunchesMap.get(u.Id));
            }
            allPunchesForSummary.addAll(punches);

            summary.attendanceStatus = 'Absent';
            summary.punchInTime = 'N/A';
            summary.punchOutTime = 'N/A';
            summary.totalHours = '0.00 hrs';
            summary.distanceKm = 0.00;
            summary.batteryLevel = 'N/A';
            summary.gpsStatus = lastGpsStatuses.get(u.Id);
            summary.visitsCount = userVisits.get(u.Id);
            summary.lastAddress = '';
            summary.lastActivityTime = '';

            if (!allPunchesForSummary.isEmpty()) {
                Punch_Record__c latestPunchForMeta = allPunchesForSummary[allPunchesForSummary.size() - 1];
                if (latestPunchForMeta.Punch_Time__c != null) {
                    summary.lastActivityTime = latestPunchForMeta.Punch_Time__c.format('hh:mm a');
                }
                for (Integer i = allPunchesForSummary.size() - 1; i >= 0; i--) {
                    if (String.isNotBlank(allPunchesForSummary[i].Address__c)) {
                        summary.lastAddress = allPunchesForSummary[i].Address__c;
                        break;
                    }
                }
                Decimal startingOdo = null;
                Decimal endingOdo = null;
                
                // Find Punch In / Punch Out times for display
                /* for (Punch_Record__c p : allPunchesForSummary) {
                    if (p.Action__c == 'IN') {
                        if (summary.punchInTime == 'N/A') {
                            summary.punchInTime = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : 'N/A';
                            startingOdo = p.Odometer_Reading__c;
                        }
                        if (p.Battery__c != null) {
                            summary.batteryLevel = String.valueOf(p.Battery__c.intValue()) + '%';
                        }
                    } else if (p.Action__c == 'OUT') {
                        summary.punchOutTime = p.Punch_Time__c != null ? p.Punch_Time__c.format('hh:mm a') : 'N/A';
                        endingOdo = p.Odometer_Reading__c;
                        if (p.Battery__c != null) {
                            summary.batteryLevel = String.valueOf(p.Battery__c.intValue()) + '%';
                        }
                    }
                } */
                // ---------------------------------------------------------
                // Punch In / Punch Out display logic
                // Only DAY IN / OUT records from the selected date are used.
                // ---------------------------------------------------------

                Punch_Record__c firstDayIn = null;
                Punch_Record__c latestDayRecord = null;

                // Find the first DAY IN and latest DAY IN/OUT record
                for (Punch_Record__c p : punches) {

                    if (p.Punch_Type__c != 'Day In / Out') {
                        continue;
                    }

                    // First DAY IN of the selected day
                    if (p.Action__c == 'IN' && firstDayIn == null) {
                        firstDayIn = p;
                    }

                    // Latest DAY IN/OUT record for the selected day
                    if (latestDayRecord == null ||
                        p.Punch_Time__c > latestDayRecord.Punch_Time__c) {
                        latestDayRecord = p;
                    }
                }

                // Punch In = first DAY IN of selected date
                if (firstDayIn != null) {
                    summary.punchInTime = firstDayIn.Punch_Time__c != null
                        ? firstDayIn.Punch_Time__c.format('hh:mm a')
                        : 'N/A';

                    startingOdo = firstDayIn.Odometer_Reading__c;

                    if (firstDayIn.Battery__c != null) {
                        summary.batteryLevel = String.valueOf(firstDayIn.Battery__c.intValue()) + '%';
                    }
                }

                // Punch Out = latest record ONLY if the latest record is OUT
                // This prevents showing an old OUT when the user is currently punched in.
                if (latestDayRecord != null && latestDayRecord.Action__c == 'OUT') {

                    summary.punchOutTime = latestDayRecord.Punch_Time__c != null
                        ? latestDayRecord.Punch_Time__c.format('hh:mm a')
                        : 'N/A';

                    endingOdo = latestDayRecord.Odometer_Reading__c;

                    if (latestDayRecord.Battery__c != null) {
                        summary.batteryLevel = String.valueOf(latestDayRecord.Battery__c.intValue()) + '%';
                    }
                }

                // Sum all punched-in intervals
                /* Datetime firstIn = null;
                Datetime lastOut = null;
                Long totalStayMs = 0;
                Datetime currentIn = null;

                for (Punch_Record__c p : allPunchesForSummary) {
                    if (p.Action__c == 'IN') {
                        if (firstIn == null) {
                            firstIn = p.Punch_Time__c;
                        }
                        if (currentIn == null) {
                            currentIn = (p.Punch_Time__c < startOfDay) ? startOfDay : p.Punch_Time__c;
                        }
                    } else if (p.Action__c == 'OUT') {
                        lastOut = p.Punch_Time__c;
                        if (currentIn != null) {
                            totalStayMs += (p.Punch_Time__c.getTime() - currentIn.getTime());
                            currentIn = null;
                        }
                    }
                }

                if (currentIn != null) {
                    Datetime compareTime = (statusDate == Date.today() ? System.now() : endOfDay);
                    if (compareTime > currentIn) {
                        totalStayMs += (compareTime.getTime() - currentIn.getTime());
                    }
                }

                Boolean isCurrentlyActive = (!allPunchesForSummary.isEmpty() && allPunchesForSummary[allPunchesForSummary.size() - 1].Action__c == 'IN' && statusDate == Date.today());

                // Calculate total stay hours
                Decimal stayHrs = Decimal.valueOf(totalStayMs) / (1000.0 * 60.0 * 60.0);
                summary.totalHours = stayHrs.setScale(2) + ' hrs' + (isCurrentlyActive ? ' (Active)' : ''); */


                // ---------------------------------------------------------
                // Calculate total active hours for the selected date
                // Only Day In / Out punches are considered.
                // ---------------------------------------------------------
                Datetime firstIn = null;
                Datetime lastOut = null;
                Long totalStayMs = 0;
                Datetime currentIn = null;

                // Process the effective punch sequence
                for (Punch_Record__c p : allPunchesForSummary) {

                    // Only Day In / Out punches count towards Active Hours
                    if (p.Punch_Type__c != 'Day In / Out') {
                        continue;
                    }

                    if (p.Action__c == 'IN') {

                        if (firstIn == null) {
                            firstIn = p.Punch_Time__c;
                        }

                        if (currentIn == null) {
                            // If the IN happened before the selected day,
                            // start counting from midnight of the selected day.
                            currentIn = (p.Punch_Time__c < startOfDay)
                                ? startOfDay
                                : p.Punch_Time__c;
                        }

                    } else if (p.Action__c == 'OUT') {

                        lastOut = p.Punch_Time__c;

                        if (currentIn != null) {
                            totalStayMs +=
                                p.Punch_Time__c.getTime() - currentIn.getTime();

                            currentIn = null;
                        }
                    }
                }

                // If still logged in, count until now/end of selected day
                if (currentIn != null) {

                    Datetime compareTime =
                        (statusDate == Date.today())
                            ? System.now()
                            : endOfDay;

                    if (compareTime > currentIn) {
                        totalStayMs +=
                            compareTime.getTime() - currentIn.getTime();
                    }
                }

                // Determine whether the user is currently logged in
                Boolean isCurrentlyActive = false;

                for (Integer i = allPunchesForSummary.size() - 1; i >= 0; i--) {

                    Punch_Record__c p = allPunchesForSummary[i];

                    if (p.Punch_Type__c == 'Day In / Out') {
                        isCurrentlyActive =
                            p.Action__c == 'IN' &&
                            statusDate == Date.today();
                        break;
                    }
                }

                // Calculate total hours
                Decimal stayHrs =
                    Decimal.valueOf(totalStayMs) /
                    (1000.0 * 60.0 * 60.0);

                summary.totalHours =
                    stayHrs.setScale(2) + ' hrs' +
                    (isCurrentlyActive ? ' (Active)' : '');

                // Attendance Status Logic based on first Punch in and last Punch out
                /* Datetime attCompareTime = (lastOut != null) ? lastOut : (statusDate == Date.today() ? System.now() : endOfDay);
                if (firstIn != null) {
                    Long elapsedMs = attCompareTime.getTime() - firstIn.getTime();
                    Decimal elapsedHrs = Decimal.valueOf(elapsedMs) / (1000.0 * 60.0 * 60.0);
                    
                    if (!isCurrentlyActive && elapsedHrs < 9.0) {
                        summary.attendanceStatus = 'Short Hours';
                    } else if (!isCurrentlyActive) {
                        summary.attendanceStatus = 'Offline';
                    } else {
                        Punch_Record__c latestPunch = allPunchesForSummary[allPunchesForSummary.size() - 1];
                        String activeMode = 'Present';
                        if (latestPunch.Action__c == 'IN'
                                && latestPunch.Punch_Type__c != 'Day In / Out'
                                && latestPunch.Punch_Type__c != null) {
                            activeMode = latestPunch.Punch_Type__c;
                        }
                        summary.attendanceStatus = activeMode;
                        if (latestPunch.Action__c == 'IN' && latestPunch.Punch_Time__c != null
                                && latestPunch.Punch_Type__c != 'Day In / Out') {
                            summary.activeSinceTime = latestPunch.Punch_Time__c.format('hh:mm a');
                        } else {
                            summary.activeSinceTime = summary.punchInTime;
                        }
                    }
                } */

                // ---------------------------------------------------------
                // Attendance Status
                // Based only on Day In / Out punches and selected date
                // ---------------------------------------------------------

                if (firstIn != null || lastOut != null || isCurrentlyActive) {

                    if (isCurrentlyActive) {

                        // User is currently logged in through Day In / Out
                        summary.attendanceStatus = 'Active';

                        // Keep the active-since time logic
                        if (currentIn != null) {
                            summary.activeSinceTime = currentIn.format('hh:mm a');
                        } else {
                            summary.activeSinceTime = summary.punchInTime;
                        }

                    } else {

                        // Completed attendance for the selected date
                        Decimal loggedHours =
                            Decimal.valueOf(totalStayMs) /
                            (1000.0 * 60.0 * 60.0);

                        if (loggedHours < 9.0) {
                            summary.attendanceStatus = 'Short Hours';
                        } else {
                            summary.attendanceStatus = 'Offline';
                        }

                        summary.activeSinceTime = null;
                    }
                }

                // Build chronological event timeline points for user
                List<TravelPoint> userEvents = new List<TravelPoint>();
                for (Punch_Record__c p : punches) {
                    if (p.Latitude__c != null && p.Longitude__c != null && p.Punch_Time__c != null) {
                        TravelPoint tp = new TravelPoint();
                        tp.lat = p.Latitude__c;
                        tp.lng = p.Longitude__c;
                        tp.eventTime = p.Punch_Time__c;
                        userEvents.add(tp);
                    }
                }
                if (userLogsMap.containsKey(u.Id)) {
                    for (Task_Log__c tl : userLogsMap.get(u.Id)) {
                        if (tl.Latitude__c != null && tl.Longitude__c != null && tl.Logged_At__c != null) {
                            TravelPoint tp = new TravelPoint();
                            tp.lat = tl.Latitude__c;
                            tp.lng = tl.Longitude__c;
                            tp.eventTime = tl.Logged_At__c;
                            userEvents.add(tp);
                        }
                    }
                }
                // Sort userEvents chronologically
                for (Integer i = 0; i < userEvents.size(); i++) {
                    for (Integer j = i + 1; j < userEvents.size(); j++) {
                        if (userEvents[i].eventTime > userEvents[j].eventTime) {
                            TravelPoint temp = userEvents[i];
                            userEvents[i] = userEvents[j];
                            userEvents[j] = temp;
                        }
                    }
                }

                // Sum actual travel KM across events
                List<TravelPoint> trackPoints = travelPointsFromTracks(userTracksMap.get(u.Id));
                TravelPoint prevPoint = null;
                Boolean isFirstPoint = true;
                Decimal totalTimelineKm = 0;
                for (TravelPoint pt : userEvents) {
                    if (isFirstPoint) {
                        isFirstPoint = false;
                    } else if (prevPoint != null) {
                        Decimal dist = sumActualTravelKm(
                            prevPoint.lat, prevPoint.lng, prevPoint.eventTime,
                            pt.lat, pt.lng, pt.eventTime,
                            trackPoints
                        );
                        if (dist != null) {
                            totalTimelineKm += dist;
                        }
                    }
                    prevPoint = pt;
                }

                if (startingOdo != null && endingOdo != null) {
                    summary.distanceKm = (endingOdo - startingOdo).setScale(2);
                } else if (totalTimelineKm > 0) {
                    summary.distanceKm = totalTimelineKm.setScale(2);
                } else {
                    summary.distanceKm = gpsDistances.get(u.Id).setScale(2);
                }
            } else {
                summary.distanceKm = 0.00;
            }

            summaries.add(summary);
        }

        return summaries;
    }

    public static Decimal calculateDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
            return 0.00;
        }
        Double radius = 6371.0; // Earth radius in km
        Double dLat = Double.valueOf(lat2 - lat1) * Math.PI / 180.0;
        Double dLon = Double.valueOf(lon2 - lon1) * Math.PI / 180.0;
        Double rLat1 = Double.valueOf(lat1) * Math.PI / 180.0;
        Double rLat2 = Double.valueOf(lat2) * Math.PI / 180.0;
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(rLat1) * Math.cos(rLat2) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(radius * c).setScale(2);
    }

    public class AnalyticsUserRow {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Integer totalVisits;
        @AuraEnabled public Integer completedVisits;
        @AuraEnabled public Integer attendanceDays;
        @AuraEnabled public Decimal totalWorkingHours;
        @AuraEnabled public Decimal totalDistanceKm;
        @AuraEnabled public Decimal avgVisitsPerDay;
        @AuraEnabled public Integer punchInCount;
        @AuraEnabled public String outcomeBreakdownJson;
        @AuraEnabled public Integer presentDays;
        @AuraEnabled public Integer absentDays;
        @AuraEnabled public Integer shortHoursDays;
        @AuraEnabled public Integer wfhDays;
        @AuraEnabled public Integer wfoDays;
        @AuraEnabled public Decimal avgHoursPerDay;
    }

    @AuraEnabled(cacheable=true)
    public static List<AnalyticsUserRow> getAnalyticsSummary(List<Id> userIds, Date startDate, Date endDate) {
        List<AnalyticsUserRow> results = new List<AnalyticsUserRow>();
        if (userIds == null || userIds.isEmpty() || startDate == null || endDate == null) {
            return results;
        }

        Datetime startDt = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDt = Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 999));
        Integer rangeDays = startDate.daysBetween(endDate) + 1;

        Map<Id, Integer> totalVisitsMap = new Map<Id, Integer>();
        Map<Id, Integer> completedVisitsMap = new Map<Id, Integer>();
        Map<Id, Map<String, Integer>> outcomeMap = new Map<Id, Map<String, Integer>>();
        for (Id uid : userIds) {
            totalVisitsMap.put(uid, 0);
            completedVisitsMap.put(uid, 0);
            outcomeMap.put(uid, new Map<String, Integer>());
        }

        for (Task_Log__c tl : [
            SELECT CreatedById, IsCheckout__c, Visit_outcome__c
            FROM Task_Log__c
            WHERE CreatedById IN :userIds
              AND Logged_At__c >= :startDt
              AND Logged_At__c <= :endDt
        ]) {
            totalVisitsMap.put(tl.CreatedById, totalVisitsMap.get(tl.CreatedById) + 1);
            if (tl.IsCheckout__c) {
                completedVisitsMap.put(tl.CreatedById, completedVisitsMap.get(tl.CreatedById) + 1);
                String oc = String.isNotBlank(tl.Visit_outcome__c) ? tl.Visit_outcome__c : 'Unknown';
                Map<String, Integer> ocMap = outcomeMap.get(tl.CreatedById);
                ocMap.put(oc, (ocMap.containsKey(oc) ? ocMap.get(oc) : 0) + 1);
            }
        }

        Map<Id, Map<Date, List<Punch_Record__c>>> userDatePunches = new Map<Id, Map<Date, List<Punch_Record__c>>>();
        Map<Id, Integer> punchInCountMap = new Map<Id, Integer>();
        for (Id uid : userIds) {
            userDatePunches.put(uid, new Map<Date, List<Punch_Record__c>>());
            punchInCountMap.put(uid, 0);
        }

        for (Punch_Record__c p : [
            SELECT Id, User__c, Action__c, Punch_Time__c, Punch_Type__c
            FROM Punch_Record__c
            WHERE User__c IN :userIds
              AND Punch_Time__c >= :startDt
              AND Punch_Time__c <= :endDt
              AND Is_WFH_Request__c = false
              AND Is_WFO_Request__c = false
            ORDER BY Punch_Time__c ASC
        ]) {
            Map<Date, List<Punch_Record__c>> datePunches = userDatePunches.get(p.User__c);
            Date pDate = p.Punch_Time__c.date();
            if (!datePunches.containsKey(pDate)) {
                datePunches.put(pDate, new List<Punch_Record__c>());
            }
            datePunches.get(pDate).add(p);
            if (p.Action__c == 'IN') {
                punchInCountMap.put(p.User__c, punchInCountMap.get(p.User__c) + 1);
            }
        }

        Map<Id, Decimal> gpsDistMap = new Map<Id, Decimal>();
        Map<Id, Decimal> prevLatMap = new Map<Id, Decimal>();
        Map<Id, Decimal> prevLngMap = new Map<Id, Decimal>();
        for (Id uid : userIds) gpsDistMap.put(uid, 0.0);

        for (Track_Location__c t : [
            SELECT Latitude__c, Longitude__c, Punch_Record__r.User__c
            FROM Track_Location__c
            WHERE Punch_Record__r.User__c IN :userIds
              AND (
                    (Recorded_At__c != null AND Recorded_At__c >= :startDt AND Recorded_At__c <= :endDt)
                 OR (Recorded_At__c = null AND CreatedDate >= :startDt AND CreatedDate <= :endDt)
              )
              AND Latitude__c != null
              AND Longitude__c != null
            ORDER BY Punch_Record__r.User__c, Recorded_At__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            Id uid = t.Punch_Record__r.User__c;
            Decimal lat, lng;
            try {
                lat = Decimal.valueOf(t.Latitude__c);
                lng = Decimal.valueOf(t.Longitude__c);
            } catch (Exception ex) { continue; }

            if (prevLatMap.containsKey(uid)) {
                Decimal seg = calculateDistanceKm(prevLatMap.get(uid), prevLngMap.get(uid), lat, lng);
                if (seg >= 0.03) {
                    gpsDistMap.put(uid, gpsDistMap.get(uid) + seg);
                    prevLatMap.put(uid, lat);
                    prevLngMap.put(uid, lng);
                }
            } else {
                prevLatMap.put(uid, lat);
                prevLngMap.put(uid, lng);
            }
        }

        for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds ORDER BY Name ASC]) {
            AnalyticsUserRow row = new AnalyticsUserRow();
            row.userId = u.Id;
            row.userName = u.Name;
            row.totalVisits = totalVisitsMap.get(u.Id);
            row.completedVisits = completedVisitsMap.get(u.Id);
            row.punchInCount = punchInCountMap.get(u.Id);
            row.totalDistanceKm = gpsDistMap.get(u.Id).setScale(2);

            Map<String, Integer> ocMap = outcomeMap.get(u.Id);
            List<String> ocParts = new List<String>();
            for (String k : ocMap.keySet()) {
                ocParts.add('"' + k + '":' + ocMap.get(k));
            }
            row.outcomeBreakdownJson = '{' + String.join(ocParts, ',') + '}';

            Map<Date, List<Punch_Record__c>> datePunches = userDatePunches.get(u.Id);
            Integer presentDays = 0;
            Integer shortHoursDays = 0;
            Integer wfhDays = 0;
            Integer wfoDays = 0;
            Decimal totalHrsAccum = 0;

            for (Date d : datePunches.keySet()) {
                List<Punch_Record__c> dayPunches = datePunches.get(d);
                Datetime dayEnd = Datetime.newInstance(d, Time.newInstance(23, 59, 59, 999));
                Datetime firstIn = null;
                Datetime lastOut = null;
                Datetime curIn = null;
                Long dayMs = 0;
                Boolean hasWfh = false;
                Boolean hasWfo = false;

                for (Punch_Record__c p : dayPunches) {
                    if (p.Punch_Type__c == 'WFH') hasWfh = true;
                    if (p.Punch_Type__c == 'WFO') hasWfo = true;
                    if (p.Action__c == 'IN') {
                        if (firstIn == null) firstIn = p.Punch_Time__c;
                        if (curIn == null) curIn = p.Punch_Time__c;
                    } else if (p.Action__c == 'OUT' && curIn != null) {
                        lastOut = p.Punch_Time__c;
                        dayMs += (p.Punch_Time__c.getTime() - curIn.getTime());
                        curIn = null;
                    }
                }
                if (curIn != null) {
                    Datetime now = (d == Date.today()) ? System.now() : dayEnd;
                    if (now > curIn) dayMs += (now.getTime() - curIn.getTime());
                }
                if (firstIn != null) {
                    totalHrsAccum += Decimal.valueOf(dayMs) / 3600000.0;
                    if (hasWfh) wfhDays++;
                    else if (hasWfo) wfoDays++;
                    Datetime cmpTime = (lastOut != null) ? lastOut : ((d == Date.today()) ? System.now() : dayEnd);
                    Decimal elapsedHrs = Decimal.valueOf(cmpTime.getTime() - firstIn.getTime()) / 3600000.0;
                    if (elapsedHrs < 9.0 && lastOut != null) shortHoursDays++;
                    else presentDays++;
                }
            }

            row.attendanceDays = datePunches.size();
            row.presentDays = presentDays;
            row.shortHoursDays = shortHoursDays;
            row.wfhDays = wfhDays;
            row.wfoDays = wfoDays;
            row.absentDays = Math.max(0, rangeDays - datePunches.size());
            row.totalWorkingHours = totalHrsAccum.setScale(2);
            row.avgHoursPerDay = (datePunches.size() > 0) ? (totalHrsAccum / datePunches.size()).setScale(2) : 0;
            row.avgVisitsPerDay = (rangeDays > 0) ? (Decimal.valueOf(row.totalVisits) / rangeDays).setScale(2) : 0;
            results.add(row);
        }
        return results;
    }
}