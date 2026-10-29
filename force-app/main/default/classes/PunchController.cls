public class PunchController {

    public class PunchStateDTO {
        @AuraEnabled public Id employeeId;
        @AuraEnabled public Id userId;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String currentStatus;     // IN / OUT
        @AuraEnabled public Datetime lastPunchTime;
        @AuraEnabled public String lastAction;        // IN / OUT
        @AuraEnabled public Decimal lastLat;
        @AuraEnabled public Decimal lastLng;
        @AuraEnabled public Decimal lastBattery;
        @AuraEnabled public String status;
        @AuraEnabled public String lastOdometerUrl;
        @AuraEnabled public String lastPunchType;
        @AuraEnabled public Boolean isWFHApprovedForToday; 
        @AuraEnabled public Boolean isWFOApproved;
        @AuraEnabled public String wfhRequestStatusTomorrow;
        @AuraEnabled public Time wfhStartTime;
        @AuraEnabled public Time wfhEndTime;
        @AuraEnabled public Date requestedDate;
        @AuraEnabled public List<WFHRequestDetail> wfhRequests;
        @AuraEnabled public Boolean hasActiveCheckIn;
        @AuraEnabled public Boolean hasUnclosedWfhWfo;
        @AuraEnabled public String lastTransportType;
        @AuraEnabled public String lastVehicleType;
    }

    public class WFHRequestDetail {
        @AuraEnabled public Id requestId;
        @AuraEnabled public Date requestDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String status;
        @AuraEnabled public String type; // 'WFH' or 'WFO'
        @AuraEnabled public Id approverId;
        @AuraEnabled public String approverName;
        @AuraEnabled public String remarks;
        @AuraEnabled public String requestNote;
    }

    private static WFHRequestDetail toWfhRequestDetail(Punch_Record__c pr) {
        WFHRequestDetail detail = new WFHRequestDetail();
        detail.requestId = pr.Id;
        detail.approverId = pr.WFH_Approver__c;
        detail.approverName = pr.WFH_Approver__r != null ? pr.WFH_Approver__r.Name : null;
        detail.requestDate = pr.WFH_Request_Date__c;
        detail.startTime = formatRequestTime(pr.WFH_Request_Start_Time__c);
        detail.endTime = formatRequestTime(pr.WFH_Request_End_Time__c);
        detail.status = pr.WFH_Approval_Status__c;
        detail.type = pr.Is_WFH_Request__c ? 'WFH' : 'WFO';
        detail.remarks = pr.Approver_Remarks__c;
        detail.requestNote = pr.WFH_Activity__c;
        return detail;
    }

    private static String formatRequestTime(Time t) {
        if (t == null) {
            return '';
        }
        String formatted = String.valueOf(t);
        if (formatted.length() > 5) {
            formatted = formatted.substring(0, 5);
        }
        return formatted;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LEGACY: Employee__c-based methods (kept for backward compatibility)
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static PunchStateDTO getCurrentState(Id employeeId) {
        PunchStateDTO dto = new PunchStateDTO();
        dto.employeeId = employeeId;

        Employee__c emp = [
            SELECT Id, Name, Current_Status__c, Last_Punch_Time__c,
                   Latitude__c, Longitude__c, Battery_Percentage__c
            FROM Employee__c
            WHERE Id = :employeeId
        ];

        dto.employeeName  = emp.Name;
        dto.currentStatus = String.valueOf(emp.Current_Status__c);
        dto.lastPunchTime = emp.Last_Punch_Time__c;
        dto.lastLat       = emp.Latitude__c;
        dto.lastLng       = emp.Longitude__c;
        dto.lastBattery   = emp.Battery_Percentage__c;

        Punch_Record__c lastPunch = null;
        try {
            lastPunch = [
                SELECT Id, Action__c, Status__c, Punch_Time__c, Latitude__c, Longitude__c, Battery__c, Punch_Type__c
                FROM Punch_Record__c
                WHERE Employee__c = :employeeId
                ORDER BY Punch_Time__c DESC
                LIMIT 1
            ];
        } catch (Exception e) {
            // ignore if none
        }

        if (lastPunch != null) {
            dto.lastAction    = String.valueOf(lastPunch.Action__c);
            dto.lastPunchTime = lastPunch.Punch_Time__c;
            dto.lastLat       = lastPunch.Latitude__c;
            dto.lastLng       = lastPunch.Longitude__c;
            dto.lastBattery   = lastPunch.Battery__c;
            dto.currentStatus = String.valueOf(lastPunch.Status__c);
            dto.lastPunchType = (lastPunch.Action__c == 'OUT' || lastPunch.Punch_Type__c == 'Day In / Out') ? null : lastPunch.Punch_Type__c;
        }

        return dto;
    }

    @AuraEnabled
    public static PunchStateDTO punchNow(Id employeeId, Decimal latitude, Decimal longitude,
                                         Decimal battery, String odometerImageBase64, String fileName) {
        Employee__c emp = [
            SELECT Id, Current_Status__c
            FROM Employee__c
            WHERE Id = :employeeId
        ];

        Boolean isPunchingIn = emp.Current_Status__c != 'IN';

        Punch_Record__c p = new Punch_Record__c();
        p.Employee__c   = employeeId;
        p.Action__c     = isPunchingIn ? 'IN' : 'OUT';
        p.Status__c     = isPunchingIn ? 'IN' : 'OUT';
        p.Punch_Time__c = System.now();
        p.Latitude__c   = latitude;
        p.Longitude__c  = longitude;
        p.Battery__c    = battery;
        PunchRecordHodHandler.applyHod(p);
        insert p;

        if (odometerImageBase64 != null) {
            ContentVersion cv = new ContentVersion();
            //String base64Data = odometerImageBase64.contains(',') ? odometerImageBase64.split(',')[1] : odometerImageBase64;
            Integer commaIndex = odometerImageBase64.indexOf(',');
            String base64Data = commaIndex >= 0
                ? odometerImageBase64.substring(commaIndex + 1)
                : odometerImageBase64;
            cv.VersionData            = EncodingUtil.base64Decode(base64Data);
            cv.Title                  = fileName;
            cv.PathOnClient           = fileName;
            cv.FirstPublishLocationId = p.Id;
            insert cv;
        }

        emp.Current_Status__c     = isPunchingIn ? 'IN' : 'OUT';
        emp.Last_Punch_Time__c    = p.Punch_Time__c;
        emp.Latitude__c           = latitude;
        emp.Longitude__c          = longitude;
        emp.Battery_Percentage__c = battery;
        update emp;

        return getCurrentState(employeeId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW: User-based methods via intermediate User_Punch_State__c object
    // Identity is resolved from UserInfo.getUserId() — no param required
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the current punch state for the logged-in User.
     * Reads from User_Punch_State__c (one record per User) and the latest
     * Punch_Record__c for that User.
     */
    @AuraEnabled
    public static PunchStateDTO getCurrentStateForUser() {
        Id runningUserId = UserInfo.getUserId();
        PunchStateDTO dto = new PunchStateDTO();
        dto.userId = runningUserId;
        dto.employeeName = UserInfo.getName();

        // Try to find the state record for this user
        List<User_Punch_State__c> stateList = [
            SELECT Id, Current_Status__c, Last_Punch_Time__c,
                   Latitude__c, Longitude__c, Battery_Percentage__c
            FROM User_Punch_State__c
            WHERE User__c = :runningUserId
            LIMIT 1
        ];

        if (!stateList.isEmpty()) {
            User_Punch_State__c state = stateList[0];
            dto.currentStatus = String.isBlank(state.Current_Status__c) ? 'OUT' : state.Current_Status__c;
            dto.lastPunchTime = state.Last_Punch_Time__c;
            dto.lastLat       = state.Latitude__c;
            dto.lastLng       = state.Longitude__c;
            dto.lastBattery   = state.Battery_Percentage__c;
        } else {
            dto.currentStatus = 'OUT';
        }

        // Get the most recent punch record for this user
        List<Punch_Record__c> lastPunches = [
            SELECT Id, Action__c, Status__c, Punch_Time__c, Latitude__c, Longitude__c, Battery__c, Punch_Type__c,
                   Transportation_Type__c, Vehicle_Type__c
            FROM Punch_Record__c
            WHERE User__c = :runningUserId AND Is_WFH_Request__c = false AND Is_WFO_Request__c = false
            ORDER BY Punch_Time__c DESC, Id DESC
            LIMIT 1
        ];

        if (!lastPunches.isEmpty()) {
            Punch_Record__c lp = lastPunches[0];
            dto.lastAction    = String.valueOf(lp.Action__c);
            dto.lastPunchTime = lp.Punch_Time__c;
            dto.lastLat       = lp.Latitude__c;
            dto.lastLng       = lp.Longitude__c;
            dto.lastBattery   = lp.Battery__c;
            dto.currentStatus = String.valueOf(lp.Status__c);
            // Active mode only when latest punch is an open mode IN (not Day In / Out, not OUT)
            Boolean hasActiveMode = (lp.Action__c == 'IN' && lp.Punch_Type__c != 'Day In / Out');
            dto.lastPunchType = hasActiveMode ? lp.Punch_Type__c : null;
            dto.lastTransportType = hasActiveMode ? lp.Transportation_Type__c : null;
            dto.lastVehicleType = hasActiveMode ? lp.Vehicle_Type__c : null;

            // Fetch attached odometer image
            List<ContentDocumentLink> cdls = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :lp.Id 
                LIMIT 1
            ];
            
            if (!cdls.isEmpty()) {
                List<ContentVersion> cvs = [
                    SELECT Id 
                    FROM ContentVersion 
                    WHERE ContentDocumentId = :cdls[0].ContentDocumentId AND IsLatest = true 
                    LIMIT 1
                ];
                if (!cvs.isEmpty()) {
                    dto.lastOdometerUrl = '/sfc/servlet.shepherd/version/download/' + cvs[0].Id;
                }
            }
        }

        // --- WFH Approval Check ---
        /*Date todayVal = Date.today();

        // Check for approved WFH today
        List<Punch_Record__c> approvedToday = [
            SELECT Id, Is_WFH_Request__c, Is_WFO_Request__c, WFH_Request_Date__c, 
                WFH_Request_Start_Time__c, WFH_Request_End_Time__c, WFH_Approval_Status__c
            FROM Punch_Record__c 
            WHERE User__c = :runningUserId 
            AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
            AND WFH_Request_Date__c = :todayVal 
            AND WFH_Approval_Status__c = 'Approved'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!approvedToday.isEmpty()) {
            dto.isWFHApprovedForToday = approvedToday[0].Is_WFH_Request__c;
            dto.isWFOApproved = approvedToday[0].Is_WFO_Request__c;
            dto.requestedDate = approvedToday[0].WFH_Request_Date__c;
            dto.wfhStartTime = approvedToday[0].WFH_Request_Start_Time__c;
            dto.wfhEndTime = approvedToday[0].WFH_Request_End_Time__c;
            dto.wfhRequestStatusTomorrow = approvedToday[0].WFH_Approval_Status__c;
        } else {
            dto.isWFHApprovedForToday = false;
            dto.isWFOApproved = false;
            dto.wfhRequestStatusTomorrow = 'Rejected';
        }*/


        // --- WFH / WFO Approval Check ---
        Date todayVal = Date.today();

        List<Punch_Record__c> approvedToday = [
            SELECT Id,
                Is_WFH_Request__c,
                Is_WFO_Request__c,
                WFH_Request_Date__c,
                WFH_Request_Start_Time__c,
                WFH_Request_End_Time__c,
                WFH_Approval_Status__c
            FROM Punch_Record__c
            WHERE User__c = :runningUserId
            AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
            AND WFH_Request_Date__c = :todayVal
            AND WFH_Approval_Status__c = 'Approved'
            ORDER BY WFH_Request_Start_Time__c ASC
        ];

        dto.isWFHApprovedForToday = false;
        dto.isWFOApproved = false;

        for (Punch_Record__c req : approvedToday) {
            if (req.Is_WFH_Request__c) {
                dto.isWFHApprovedForToday = true;
            }

            if (req.Is_WFO_Request__c) {
                dto.isWFOApproved = true;
            }
        }


        // Fetch all WFH / WFO request applications
        List<WFHRequestDetail> wfhReqs = new List<WFHRequestDetail>();
        for (Punch_Record__c pr : [
            SELECT Id, WFH_Request_Date__c, WFH_Request_Start_Time__c, WFH_Request_End_Time__c,
                   WFH_Approval_Status__c, Is_WFH_Request__c, Is_WFO_Request__c,
                   WFH_Approver__c, WFH_Approver__r.Name, Approver_Remarks__c, WFH_Activity__c
            FROM Punch_Record__c
            WHERE User__c = :runningUserId
            AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
            ORDER BY WFH_Request_Date__c DESC, CreatedDate DESC
            LIMIT 50
        ]) {
            wfhReqs.add(toWfhRequestDetail(pr));
        }
        dto.wfhRequests = wfhReqs;

        // Check for request status tomorrow
        // List<Punch_Record__c> reqTomorrow = [
        //     SELECT WFH_Approval_Status__c 
        //     FROM Punch_Record__c 
        //     WHERE User__c = :runningUserId 
        //     AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
        //     AND WFH_Request_Date__c = :tomorrowVal 
        //     ORDER BY CreatedDate DESC 
        //     LIMIT 1
        // ];
        // if (!reqTomorrow.isEmpty()) {
        //     dto.wfhRequestStatusTomorrow = reqTomorrow[0].WFH_Approval_Status__c;
        // } else {
        //     dto.wfhRequestStatusTomorrow = 'Not Requested';
        // }

        // Check for ongoing check-in under the active punch (mode or day)
        Id activePunchId = null;
        List<User_Punch_State__c> punchStates = [
            SELECT Punch_In_Record__c
            FROM User_Punch_State__c
            WHERE User__c = :runningUserId
            LIMIT 1
        ];
        if (!punchStates.isEmpty() && punchStates[0].Punch_In_Record__c != null) {
            activePunchId = punchStates[0].Punch_In_Record__c;
        } else if (!lastPunches.isEmpty() && lastPunches[0].Action__c == 'IN') {
            activePunchId = lastPunches[0].Id;
        }

        List<Task_Log__c> activeVisits = new List<Task_Log__c>();
        if (activePunchId != null) {
            activeVisits = [
                SELECT Id 
                FROM Task_Log__c 
                WHERE Punch_Record__c = :activePunchId
                  AND IsCheckout__c = false
                  AND Is_schedule__c = false
                LIMIT 1
            ];
        }
        dto.hasActiveCheckIn = !activeVisits.isEmpty();

        dto.hasUnclosedWfhWfo = false;

        return dto;
    }

    /**
     * Gets WFH and WFO request applications for a specific user.
     */
    @AuraEnabled(cacheable=true)
    public static List<WFHRequestDetail> getWFHRequestsForUser(Id userId) {
        if (userId == null) {
            userId = UserInfo.getUserId();
        }
        List<WFHRequestDetail> wfhReqs = new List<WFHRequestDetail>();
        for (Punch_Record__c pr : [
            SELECT Id, WFH_Request_Date__c, WFH_Request_Start_Time__c, WFH_Request_End_Time__c,
                   WFH_Approval_Status__c, Is_WFH_Request__c, Is_WFO_Request__c,
                   WFH_Approver__c, WFH_Approver__r.Name, Approver_Remarks__c, WFH_Activity__c
            FROM Punch_Record__c
            WHERE User__c = :userId
            AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
            ORDER BY WFH_Request_Date__c DESC, CreatedDate DESC
            LIMIT 50
        ]) {
            wfhReqs.add(toWfhRequestDetail(pr));
        }
        return wfhReqs;
    }

    /**
     * Creates a Punch_Record__c linked to the running User,
     * then upserts the User_Punch_State__c record to reflect the new status.
     */
    @AuraEnabled
    public static PunchStateDTO punchNowAsUser(Decimal latitude, Decimal longitude,
                                               Decimal battery, String selfieImageBase64,
                                               String odometerImageBase64,
                                               String fileName, String punchType, 
                                               String wfhActivity, String transportType, 
                                               String vehicleType, Decimal odometerReading,
                                               Decimal extractedOdometer, String deviceOS,
                                               String deviceModel) {
        Id runningUserId = UserInfo.getUserId();

        // Determine current status from state record
        String currentStatus = 'OUT';
        Id stateRecordId = null;

        List<User_Punch_State__c> stateList = [
            SELECT Id, Current_Status__c
            FROM User_Punch_State__c
            WHERE User__c = :runningUserId
            LIMIT 1
        ];

        if (!stateList.isEmpty()) {
            currentStatus = String.isBlank(stateList[0].Current_Status__c)
                ? 'OUT'
                : stateList[0].Current_Status__c;
            stateRecordId = stateList[0].Id;
        }

        Boolean isPunchingIn = currentStatus != 'IN';
        String newStatus = isPunchingIn ? 'IN' : 'OUT';
        Datetime punchTime = System.now();
        Id activeCheckInId = null;

        // Create the Punch_Record__c reference for file uploads
        Punch_Record__c p = new Punch_Record__c();

        if (isPunchingIn) {
            // Day In only — mode of work is started separately via updatePunchTypeAndOdometer
            Punch_Record__c dayIn = new Punch_Record__c();
            dayIn.User__c = runningUserId;
            dayIn.Action__c = 'IN';
            dayIn.Status__c = 'IN';
            dayIn.Punch_Time__c = punchTime;
            dayIn.Punch_Type__c = 'Day In / Out';
            dayIn.Latitude__c = latitude;
            dayIn.Longitude__c = longitude;
            dayIn.Battery__c = battery;
            dayIn.Device_OS__c = deviceOS;
            dayIn.Device_Model__c = deviceModel;
            PunchRecordHodHandler.applyHod(dayIn);
            insert dayIn;
            
            p = dayIn;
            activeCheckInId = dayIn.Id;
        } else {
            // Day Out only — mode must already be ended (no active mode on Punch_In_Record)
            if (stateRecordId != null) {
                List<User_Punch_State__c> activeStates = [
                    SELECT Punch_In_Record__c, Punch_In_Record__r.Punch_Type__c
                    FROM User_Punch_State__c
                    WHERE Id = :stateRecordId
                    LIMIT 1
                ];
                if (!activeStates.isEmpty() && activeStates[0].Punch_In_Record__c != null
                    && activeStates[0].Punch_In_Record__r.Punch_Type__c != 'Day In / Out') {
                    throw new AuraHandledException('Please end your active mode of work before Day Out.');
                }

                Id dayPunchId = activeStates.isEmpty() ? null : activeStates[0].Punch_In_Record__c;
                if (dayPunchId != null) {
                    List<Task_Log__c> activeVisits = [
                        SELECT Id
                        FROM Task_Log__c
                        WHERE Punch_Record__c = :dayPunchId
                          AND IsCheckout__c = false
                          AND Is_schedule__c = false
                        LIMIT 1
                    ];
                    if (!activeVisits.isEmpty()) {
                        throw new AuraHandledException('You have an active visit check-in. Please check out of your active visit before Day Out.');
                    }
                }
            }

            Punch_Record__c dayOut = new Punch_Record__c();
            dayOut.User__c = runningUserId;
            dayOut.Action__c = 'OUT';
            dayOut.Status__c = 'OUT';
            dayOut.Punch_Time__c = punchTime;
            dayOut.Punch_Type__c = 'Day In / Out';
            dayOut.Latitude__c = latitude;
            dayOut.Longitude__c = longitude;
            dayOut.Battery__c = battery;
            dayOut.Device_OS__c = deviceOS;
            dayOut.Device_Model__c = deviceModel;

            List<Punch_Record__c> lastDayIns = [
                SELECT Id
                FROM Punch_Record__c 
                WHERE User__c = :runningUserId AND Is_WFH_Request__c = false AND Is_WFO_Request__c = false AND Action__c = 'IN' AND Punch_Type__c = 'Day In / Out'
                ORDER BY Punch_Time__c DESC, Id DESC
                LIMIT 1
            ];
            if (!lastDayIns.isEmpty()) {
                dayOut.Punch_Out_Of__c = lastDayIns[0].Id;
            }

            PunchRecordHodHandler.applyHod(dayOut);
            insert dayOut;
            p = dayOut;
        }

        // Attach selfie image to dayIn/dayOut record if provided
        if (String.isNotBlank(selfieImageBase64)) {
            ContentVersion cv = new ContentVersion();
            /*String base64Data = selfieImageBase64.contains(',')
                ? selfieImageBase64.split(',')[1]
                : selfieImageBase64;*/
            Integer commaIndex = selfieImageBase64.indexOf(',');
            String base64Data = commaIndex >= 0
                ? selfieImageBase64.substring(commaIndex + 1)
                : selfieImageBase64;
            cv.VersionData            = EncodingUtil.base64Decode(base64Data);
            cv.Title                  = 'selfie_capture.jpg';
            cv.PathOnClient           = 'selfie_capture.jpg';
            cv.FirstPublishLocationId = p.Id;
            insert cv;
        }

        // Upsert the User_Punch_State__c record (one per user)
        User_Punch_State__c stateRecord = new User_Punch_State__c();
        if (stateRecordId != null) {
            stateRecord.Id = stateRecordId;
        }
        stateRecord.User__c               = runningUserId;
        stateRecord.Current_Status__c     = newStatus;
        stateRecord.Last_Punch_Time__c    = punchTime;
        stateRecord.Latitude__c           = latitude;
        stateRecord.Longitude__c          = longitude;
        stateRecord.Battery_Percentage__c = battery;
        if (newStatus == 'IN') {
            stateRecord.Punch_In_Record__c = activeCheckInId;
        } else {
            stateRecord.Punch_In_Record__c = null;
        }
        upsert stateRecord;

        return getCurrentStateForUser();
    }

    /**
     * Submits a WFH request for a specific date and time range.
     */
    @AuraEnabled
    public static void submitWFHRequest(Date reqDate, String startTimeStr, String endTimeStr, String catagory, String requestNote, String deviceOS, String deviceModel) {
        Id runningUserId = UserInfo.getUserId();


        // Prevent overlapping requests only when an existing request is APPROVED.
        // Pending and Rejected requests do not block a new request.

        Boolean isWFH = catagory == 'WFH';
        Boolean isWFO = catagory == 'WFO';

        Time newStart = String.isNotBlank(startTimeStr)
            ? parseTime(startTimeStr)
            : null;

        Time newEnd = String.isNotBlank(endTimeStr)
            ? parseTime(endTimeStr)
            : null;

        if (newStart != null && newEnd != null) {

            List<Punch_Record__c> conflictingRequests;

            if (catagory == 'WFH') {
                conflictingRequests = [
                    SELECT Id,
                        WFH_Request_Start_Time__c,
                        WFH_Request_End_Time__c
                    FROM Punch_Record__c
                    WHERE User__c = :runningUserId
                    AND WFH_Request_Date__c = :reqDate
                    AND WFH_Approval_Status__c IN ('Approved', 'Pending')
                    AND Is_WFH_Request__c = true
                ];
            } else {
                conflictingRequests = [
                    SELECT Id,
                        WFH_Request_Start_Time__c,
                        WFH_Request_End_Time__c
                    FROM Punch_Record__c
                    WHERE User__c = :runningUserId
                    AND WFH_Request_Date__c = :reqDate
                    AND WFH_Approval_Status__c IN ('Approved', 'Pending')
                    AND Is_WFO_Request__c = true
                ];
            }

            for (Punch_Record__c existingReq : conflictingRequests) {

                Time existingStart = existingReq.WFH_Request_Start_Time__c;
                Time existingEnd = existingReq.WFH_Request_End_Time__c;

                if (existingStart == null || existingEnd == null) {
                    continue;
                }

                // Overlap condition:
                // New Start < Existing End
                // AND
                // New End > Existing Start
                if (newStart < existingEnd && newEnd > existingStart) {

                    String requestType = isWFH ? 'WFH' : 'WFO';

                    throw new AuraHandledException(
                        'You already have a ' + requestType +
                        ' request overlapping this time (' +
                        formatTime(existingStart) + ' - ' +
                        formatTime(existingEnd) + ').'
                    );
                }
            }
        }

        
        Punch_Record__c p = new Punch_Record__c();
        p.User__c = runningUserId;
        p.WFH_Activity__c = requestNote;
        // p.Is_WFH_Request__c = true;
        p.Punch_Type__c = catagory;
        if(catagory == 'WFH'){
            p.Is_WFH_Request__c = true;
        }else{
            p.Is_WFH_Request__c = false;
        }
        if(catagory == 'WFO'){
            p.Is_WFO_Request__c = true;
        }else{
            p.Is_WFO_Request__c = false;
        }
        p.WFH_Request_Date__c = reqDate;
        p.WFH_Approval_Status__c = 'Pending';
        p.Device_OS__c = deviceOS;
        p.Device_Model__c = deviceModel;
        
        // Set Approver from Custom Metadata
        List<Manager_Assignment__mdt> mapping = [
            SELECT Manager_User_Id__c 
            FROM Manager_Assignment__mdt 
            WHERE Target_User_Id__c = :runningUserId 
            LIMIT 1
        ];
        if (!mapping.isEmpty()) {
            p.WFH_Approver__c = (Id)mapping[0].Manager_User_Id__c;
        }

        if (String.isNotBlank(startTimeStr)) {
            p.WFH_Request_Start_Time__c = parseTime(startTimeStr);
        }
        if (String.isNotBlank(endTimeStr)) {
            p.WFH_Request_End_Time__c = parseTime(endTimeStr);
        }

        PunchRecordHodHandler.applyHod(p);
        insert p;
    }

    private static Time parseTime(String timeStr) {
        // Expected format: "HH:mm:ss.SSS" or "HH:mm"
        try {
            List<String> parts = timeStr.split(':');
            Integer h = Integer.valueOf(parts[0]);
            Integer m = Integer.valueOf(parts[1]);
            Integer s = 0;
            if (parts.size() > 2) {
                // If there's seconds, it might have milliseconds too
                String secPart = parts[2];
                if (secPart.contains('.')) {
                    s = Integer.valueOf(secPart.split('\\.')[0]);
                } else {
                    s = Integer.valueOf(secPart);
                }
            }
            return Time.newInstance(h, m, s, 0);
        } catch (Exception e) {
            return null;
        }
    }

    private static String formatTime(Time t) {
        if (t == null) {
            return '';
        }

        String formatted = String.valueOf(t);

        return formatted.length() >= 5
            ? formatted.substring(0, 5)
            : formatted;
    }

    /**
     * Saves periodic location updates for the logged-in user.
     * Updates the User_Punch_State__c and creates a Tracking record.
     */
    @AuraEnabled
    public static void savePeriodicLocation(Decimal latitude, Decimal longitude, Decimal battery) {
        Id runningUserId = UserInfo.getUserId();
        Datetime now = System.now();

        // 1. Update/Upsert User_Punch_State__c (Live location)
        List<User_Punch_State__c> stateList = [
            SELECT Id FROM User_Punch_State__c WHERE User__c = :runningUserId LIMIT 1
        ];
        
        User_Punch_State__c state = new User_Punch_State__c();
        if (!stateList.isEmpty()) {
            state.Id = stateList[0].Id;
        } else {
            state.User__c = runningUserId;
        }
        state.Latitude__c = latitude;
        state.Longitude__c = longitude;
        state.Battery_Percentage__c = battery;
        state.Last_Punch_Time__c = now; 
        upsert state;

        // 2. Create a history record in the new Track_Location__c object
        // Find the current "IN" Punch_Record__c to link the tracking
        List<Punch_Record__c> currentShift = [
            SELECT Id FROM Punch_Record__c 
            WHERE User__c = :runningUserId AND Action__c = 'IN' 
            ORDER BY Punch_Time__c DESC LIMIT 1
        ];

        if (!currentShift.isEmpty()) {
            Track_Location__c tl = new Track_Location__c();
            tl.Punch_Record__c = currentShift[0].Id;
            tl.Latitude__c = latitude != null ? String.valueOf(latitude) : null;
            tl.Longitude__c = longitude != null ? String.valueOf(longitude) : null;
            tl.Source__c = 'LWC';
            tl.Recorded_At__c = now;
            insert tl;
        }
    }

    @AuraEnabled
    public static String saveSelfieForAccount(Id accountId, String base64Photo, Decimal userLat, Decimal userLon) {
        try {
            // Save as ContentVersion
            ContentVersion cv = new ContentVersion();
            // String base64Data = base64Photo.contains(',') ? base64Photo.split(',')[1] : base64Photo;
            Integer commaIndex = base64Photo.indexOf(',');
            String base64Data = commaIndex >= 0
                ? base64Photo.substring(commaIndex + 1)
                : base64Photo;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.Title = 'Selfie_' + System.now().format('yyyyMMdd_HHmmss') + '.jpg';
            cv.PathOnClient = cv.Title;
            cv.FirstPublishLocationId = accountId;
            insert cv;

            // Update location on the record (assuming it's Employee__c based on usage)
            if (accountId.getSObjectType() == Employee__c.SObjectType) {
                Employee__c emp = new Employee__c(Id = accountId);
                emp.Latitude__c = userLat;
                emp.Longitude__c = userLon;
                emp.Last_Punch_Time__c = System.now();
                update emp;
            }

            return [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean checkLocationData(Id userId) {
        // Check if any location data has arrived in the last 10 minutes for this user
        DateTime tenMinsAgo = System.now().addMinutes(-10);
        
        // Find the latest punch-in record for this user
        List<Punch_Record__c> latestIn = [
            SELECT Id FROM Punch_Record__c 
            WHERE User__c = :userId AND Action__c = 'IN' 
            ORDER BY Punch_Time__c DESC LIMIT 1
        ];
        
        if (latestIn.isEmpty()) return false;
        
        // Check if there are any Track_Location__c records for this punch from the Logger
        Integer count = [
            SELECT COUNT() 
            FROM Track_Location__c 
            WHERE Punch_Record__c = :latestIn[0].Id 
            AND Source__c IN ('Logger', 'AppleApp')
            AND CreatedDate >= :tenMinsAgo
        ];
        
        return count > 0;
    }

    // Backward-compatible overload for Apex callers / tests
    public static PunchStateDTO updatePunchTypeAndOdometer(
        String punchType, 
        String transportType, 
        String vehicleType, 
        Decimal odometerReading, 
        Decimal extractedOdometer, 
        String odometerImageBase64, 
        String fileName
    ) {
        return updatePunchTypeAndOdometer(
            punchType, transportType, vehicleType, odometerReading, extractedOdometer,
            odometerImageBase64, fileName, null, null, null, null, null, null, null
        );
    }

    @AuraEnabled
    public static PunchStateDTO updatePunchTypeAndOdometer(
        String punchType, 
        String transportType, 
        String vehicleType, 
        Decimal odometerReading, 
        Decimal extractedOdometer, 
        String odometerImageBase64, 
        String fileName,
        Decimal noOfPhoneCalls,
        Decimal noOfEmails,
        Decimal noOfOffersSent,
        Decimal noOfMeetings,
        String openNotes,
        String deviceOS,
        String deviceModel
    ) {
        Id runningUserId = UserInfo.getUserId();

        // 1. Get the current active punch-in record for this user
        List<User_Punch_State__c> states = [
            SELECT Punch_In_Record__c
            FROM User_Punch_State__c
            WHERE User__c = :runningUserId
            LIMIT 1
        ];

        if (states.isEmpty() || states[0].Punch_In_Record__c == null) {
            throw new AuraHandledException('No active Day In check-in found to update.');
        }

        Id activePunchId = states[0].Punch_In_Record__c;

        List<Punch_Record__c> lastPunches = [
            SELECT Id, Punch_Type__c, Transportation_Type__c, Vehicle_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c,
                   Latitude__c, Longitude__c, Battery__c, Device_OS__c, Device_Model__c
            FROM Punch_Record__c
            WHERE Id = :activePunchId
            LIMIT 1
        ];

        if (lastPunches.isEmpty()) {
            throw new AuraHandledException('No active Day In check-in found to update.');
        }

        Punch_Record__c activePunch = lastPunches[0];
        Datetime now = System.now();

        // Block mode changes while a client visit is open
        List<Task_Log__c> openVisits = [
            SELECT Id
            FROM Task_Log__c
            WHERE Punch_Record__c = :activePunch.Id
              AND IsCheckout__c = false
              AND Is_schedule__c = false
            LIMIT 1
        ];
        if (!openVisits.isEmpty()) {
            throw new AuraHandledException('You have an active visit check-in. Please check out before changing mode of work.');
        }

        // Approvals when starting WFH / WFO mode
        if (String.isNotBlank(punchType)) {
            if (punchType == 'WFH') {
                List<Punch_Record__c> approvedReq = [
                    SELECT Id
                    FROM Punch_Record__c
                    WHERE User__c = :runningUserId
                    AND Is_WFH_Request__c = true
                    AND WFH_Request_Date__c = TODAY
                    AND WFH_Approval_Status__c = 'Approved'
                    LIMIT 1
                ];
                if (approvedReq.isEmpty()) {
                    throw new AuraHandledException('WFH is only allowed if a request for today has been approved by your manager.');
                }
            } else if (punchType == 'WFO') {
                List<Punch_Record__c> approvedReq = [
                    SELECT Id
                    FROM Punch_Record__c
                    WHERE User__c = :runningUserId
                    AND Is_WFO_Request__c = true
                    AND WFH_Request_Date__c = TODAY
                    AND WFH_Approval_Status__c = 'Approved'
                    LIMIT 1
                ];
                if (approvedReq.isEmpty()) {
                    throw new AuraHandledException('WFO is only allowed if a request for today has been approved by your manager.');
                }
            }
        }

        if (activePunch.Punch_Type__c == 'Market Visit' &&
            activePunch.Transportation_Type__c == 'Private Vehicle') {

            if (String.isBlank(odometerImageBase64)) {
                throw new AuraHandledException(
                    'Odometer image is required to end a Private Vehicle Market Visit.'
                );
            }

            if (extractedOdometer == null) {
                throw new AuraHandledException(
                    'Please capture a valid odometer image and wait for the reading to be extracted.'
                );
            }
        }

        // 2. Create the OUT record to close the previous mode
        if (activePunch.Punch_Type__c != 'Day In / Out') {
            Punch_Record__c oldOut = new Punch_Record__c();
            oldOut.User__c = runningUserId;
            oldOut.Action__c = 'OUT';
            oldOut.Status__c = 'IN'; // Remaining checked-in for the day shift
            oldOut.Punch_Time__c = now;
            oldOut.Punch_Type__c = activePunch.Punch_Type__c;
            oldOut.Punch_Out_Of__c = activePunch.Id;
            oldOut.Latitude__c = activePunch.Latitude__c;
            oldOut.Longitude__c = activePunch.Longitude__c;
            oldOut.Battery__c = activePunch.Battery__c;
            oldOut.Device_OS__c = activePunch.Device_OS__c;
            oldOut.Device_Model__c = activePunch.Device_Model__c;
            
            // If ending a Market Visit, the incoming odometer reading belongs to oldOut (the OUT record)
            if (activePunch.Punch_Type__c == 'Market Visit' && activePunch.Transportation_Type__c == 'Private Vehicle') {
                oldOut.Transportation_Type__c = activePunch.Transportation_Type__c;
                oldOut.Vehicle_Type__c = activePunch.Vehicle_Type__c;
                oldOut.Odometer_Reading__c = odometerReading;
                oldOut.Extracted_Odometer_Reading__c = extractedOdometer;
            } else {
                oldOut.Transportation_Type__c = activePunch.Transportation_Type__c;
                oldOut.Vehicle_Type__c = activePunch.Vehicle_Type__c;
                oldOut.Odometer_Reading__c = activePunch.Odometer_Reading__c;
                oldOut.Extracted_Odometer_Reading__c = activePunch.Extracted_Odometer_Reading__c;
            }

            // Day Activity Log when ending WFH / WFO
            if (activePunch.Punch_Type__c == 'WFH' || activePunch.Punch_Type__c == 'WFO') {
                oldOut.No_of_Phone_Calls__c = noOfPhoneCalls;
                oldOut.No_of_Emails__c = noOfEmails;
                oldOut.No_of_Offers_Sent__c = noOfOffersSent;
                oldOut.No_of_Meetings__c = noOfMeetings;
                oldOut.Open_Notes__c = openNotes;
            }
            
            PunchRecordHodHandler.applyHod(oldOut);
            insert oldOut;

            // Attach odometer image to oldOut if ending Market Visit
            if (String.isNotBlank(odometerImageBase64) && activePunch.Punch_Type__c == 'Market Visit' && activePunch.Transportation_Type__c == 'Private Vehicle') {
                ContentVersion cv = new ContentVersion();
                //String base64Data = odometerImageBase64.contains(',') ? odometerImageBase64.split(',')[1] : odometerImageBase64;
                Integer commaIndex = odometerImageBase64.indexOf(',');
                String base64Data = commaIndex >= 0
                    ? odometerImageBase64.substring(commaIndex + 1)
                    : odometerImageBase64;
                cv.VersionData            = EncodingUtil.base64Decode(base64Data);
                cv.Title                  = String.isNotBlank(fileName) ? fileName : 'odometer_end.jpg';
                cv.PathOnClient           = String.isNotBlank(fileName) ? fileName : 'odometer_end.jpg';
                cv.FirstPublishLocationId = oldOut.Id;
                insert cv;
            }
        }

        Id activeInId = null;

        if (String.isNotBlank(punchType)) {
            // 3. Create the IN record for the new mode
            Punch_Record__c newIn = new Punch_Record__c();
            newIn.User__c = runningUserId;
            newIn.Action__c = 'IN';
            newIn.Status__c = 'IN';
            newIn.Punch_Time__c = now;
            newIn.Punch_Type__c = punchType;
            newIn.Transportation_Type__c = String.isBlank(transportType) ? null : transportType;
            newIn.Vehicle_Type__c = String.isBlank(vehicleType) ? null : vehicleType;
            
            // If starting a new Market Visit, save the STARTING odometer details to newIn
            if (punchType == 'Market Visit' && transportType == 'Private Vehicle') {
                newIn.Odometer_Reading__c = odometerReading;
                newIn.Extracted_Odometer_Reading__c = extractedOdometer;
            }
            
            newIn.Latitude__c = activePunch.Latitude__c;
            newIn.Longitude__c = activePunch.Longitude__c;
            newIn.Battery__c = activePunch.Battery__c;
            newIn.Device_OS__c = deviceOS;
            newIn.Device_Model__c = deviceModel;
            PunchRecordHodHandler.applyHod(newIn);
            insert newIn;

            if (punchType == 'WFH' || punchType == 'WFO') {
                sendWfhWfoStartNotification(runningUserId, punchType);
            }

            activeInId = newIn.Id;

            // Attach odometer image to newIn if starting Market Visit
            if (String.isNotBlank(odometerImageBase64) && punchType == 'Market Visit' && transportType == 'Private Vehicle') {
                ContentVersion cv = new ContentVersion();
                //String base64Data = odometerImageBase64.contains(',') ? odometerImageBase64.split(',')[1] : odometerImageBase64;
                Integer commaIndex = odometerImageBase64.indexOf(',');
                String base64Data = commaIndex >= 0
                    ? odometerImageBase64.substring(commaIndex + 1)
                    : odometerImageBase64;
                cv.VersionData            = EncodingUtil.base64Decode(base64Data);
                cv.Title                  = String.isNotBlank(fileName) ? fileName : 'odometer_start.jpg';
                cv.PathOnClient           = String.isNotBlank(fileName) ? fileName : 'odometer_start.jpg';
                cv.FirstPublishLocationId = newIn.Id;
                insert cv;
            }
        } else {
            // If clearing active mode (no mode running), point to the original shift Day In punch
            List<Punch_Record__c> dayInList = [
                SELECT Id FROM Punch_Record__c
                WHERE User__c = :runningUserId AND Action__c = 'IN' AND Punch_Type__c = 'Day In / Out'
                ORDER BY Punch_Time__c DESC, Id DESC
                LIMIT 1
            ];
            if (!dayInList.isEmpty()) {
                activeInId = dayInList[0].Id;
            }
        }

        // 5. Update User_Punch_State__c to point to the active IN record
        List<User_Punch_State__c> stateList = [
            SELECT Id FROM User_Punch_State__c WHERE User__c = :runningUserId LIMIT 1
        ];
        if (!stateList.isEmpty()) {
            User_Punch_State__c state = stateList[0];
            state.Punch_In_Record__c = activeInId;
            update state;
        }

        return getCurrentStateForUser();
    }

    public static void sendWfhWfoStartNotification(Id userId, String punchType) {

        User currentUser = [
            SELECT Id, Name, Department
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        Set<String> recipientIds = new Set<String>();

        // Utkarsh HOD: same Department as the user
        for (User u : [
            SELECT Id
            FROM User
            WHERE Department = :currentUser.Department
            AND Profile.Name = 'Utkarsh HOD'
            AND IsActive = true
        ]) {
            recipientIds.add(u.Id);
        }

        // CRM Head: user's Department belongs to one of the CRM Head's Departments__c
        if (String.isNotBlank(currentUser.Department)) {
            String userDept = currentUser.Department.trim().toUpperCase();
            for (User u : [
                SELECT Id, Departments__c
                FROM User
                WHERE Profile.Name = 'CRM Head'
                AND IsActive = true
                AND Departments__c != null
            ]) {
                for (String deptName : getCrmHeadDepartmentNames(u.Departments__c)) {
                    if (deptName.toUpperCase() == userDept) {
                        recipientIds.add(u.Id);
                        break;
                    }
                }
            }
        }

        if (recipientIds.isEmpty()) {
            return;
        }

        CustomNotificationType notificationType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'WFH_WFO_Notification'
            LIMIT 1
        ];

        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();

        notification.setTitle(punchType + ' Started');
        notification.setBody(
            currentUser.Name + ' has started the day by marking ' + punchType + ' attendance.'
        );
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(userId);

        notification.send(recipientIds);
    }

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
     * Department values covered by a CRM Head: each of the CRM Head's Departments__c values
     * plus that department's name (e.g. 'Crash_Barrier_Department' and 'CRASH BARRIER').
     */
    private static Set<String> getCrmHeadDepartmentNames(String departmentsValue) {
        Set<String> deptNames = new Set<String>();
        if (String.isBlank(departmentsValue)) {
            return deptNames;
        }
        for (String rawDept : departmentsValue.split(';')) {
            if (String.isNotBlank(rawDept)) {
                deptNames.add(rawDept.trim());
            }
        }
        for (String deptName : DEPARTMENT_NORMALIZATION_MAP.keySet()) {
            if (deptNames.contains(DEPARTMENT_NORMALIZATION_MAP.get(deptName))) {
                deptNames.add(deptName);
            }
        }
        return deptNames;
    }
}