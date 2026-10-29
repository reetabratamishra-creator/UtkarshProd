/**
 * @description Server-side controller for the targetManager Lightning Web Component.
 * Handles the retrieval of assignable entities (Users/Teams) and the transactional 
 * creation of Target__c and Target_Assignment__c records.
 */

public class TargetManagerController {

    /**
     * @description A wrapper class to normalize data between User and Group objects. 
     * This allows the LWC to handle a single, consistent data structure regardless 
     * of the assignment type selected.
     */
    public class EntityWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String SubText { get; set; }
    }
    
    // Wrappers to parse the incoming JSON payload containing periods and quantities
    public class AssignmentPayload {
        public String Id;
        public List<PeriodPayload> periods;
    }
    
    public class PeriodPayload {
        public String id;
        public String label;
        public Boolean isPast;
        public String inputValue;
        public String startDate; 
        public String endDate;
    }
    
    // NEW: Wrapper to hold aggregated punch data
    public class PunchResult {
        @AuraEnabled public String userId { get; set; }
        @AuraEnabled public Date punchDate { get; set; }
        @AuraEnabled public Integer count { get; set; }
    }
    
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    // NEW: Wrappers for pulling data back into the Edit Wizard
    public class EditPayload {
        @AuraEnabled public Target__c target;
        @AuraEnabled public List<AssignmentDetail> assignments;
    }

    public class AssignmentDetail {
        @AuraEnabled public String entityId;
        @AuraEnabled public String entityName;
        @AuraEnabled public String entitySubText;
        @AuraEnabled public List<Target_Period__c> periods;
    }
    
    // NEW WRAPPER: Sends both the targets and the user's permission level to the LWC
    public class TargetListWrapper {
        @AuraEnabled public Boolean isManager { get; set; }
        @AuraEnabled public List<Target__c> targets { get; set; }
    }
    
    // ==========================================
    // NEW: Dynamic Dashboard Wrappers
    // ==========================================
    public class EmployeeStat {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String initials;
        @AuraEnabled public Integer target;
        @AuraEnabled public Integer actual;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public String progressText;
        @AuraEnabled public String progressStyle;
    }
    public class TrendData {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
    }

    public class DashboardWrapper {
        @AuraEnabled public Decimal overallAchievement;
        @AuraEnabled public List<EmployeeStat> employees;
        @AuraEnabled public String currentCycle;
        @AuraEnabled public List<TrendData> trendLines;
    }

    // ==========================================
    // CRM Head department access
    // ==========================================
    private static final String CRM_HEAD_PROFILE_NAME = 'CRM Head';

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
     * Department values to match against User.Department for a CRM Head: each of the
     * CRM Head's Departments__c values plus that department's name
     * (e.g. 'Crash_Barrier_Department' and 'CRASH BARRIER').
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

    // ==========================================
    // NEW: Robust Group "Exploder" (Handles Roles & Nested Groups)
    // ==========================================
    private static Set<Id> getExpandedUserIdsForGroup(Id startingGroupId) {
        Set<Id> userIds = new Set<Id>();
        Set<Id> groupsToProcess = new Set<Id>{ startingGroupId };
        Set<Id> processedGroups = new Set<Id>();
        Set<Id> roleIds = new Set<Id>();
        
        // 1. Traverse all Public Groups and Nested Groups
        while (!groupsToProcess.isEmpty()) {
            Set<Id> currentGroups = new Set<Id>(groupsToProcess);
            groupsToProcess.clear();
            processedGroups.addAll(currentGroups);
            
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId IN :currentGroups LIMIT 2000]) {
                String memberId = gm.UserOrGroupId;
                if (memberId.startsWith('005')) {
                    userIds.add((Id)memberId); // It's a Direct User
                } else if (memberId.startsWith('00G')) {
                    if (!processedGroups.contains((Id)memberId)) {
                        groupsToProcess.add((Id)memberId); // It's a Group or Role, add to queue
                    }
                }
            }
        }
        
        // 2. Identify if any of the processed "Groups" are actually Roles
        if (!processedGroups.isEmpty()) {
            for (Group g : [SELECT Type, RelatedId FROM Group WHERE Id IN :processedGroups LIMIT 2000]) {
                // If it's a Role, grab the Role ID
                if ((g.Type == 'Role' || g.Type == 'RoleAndSubordinates' || g.Type == 'RoleAndSubordinatesInternal') && g.RelatedId != null) {
                    roleIds.add(g.RelatedId);
                }
            }
        }
        
        // 3. Fetch all Users assigned to those Roles
        if (!roleIds.isEmpty()) {
            for (User u : [SELECT Id FROM User WHERE UserRoleId IN :roleIds AND IsActive = true LIMIT 2000]) {
                userIds.add(u.Id);
            }
        }
        
        return userIds;
    }

    // ==========================================
    // UPDATED: Fetches all members of the selected Team(s) mapping them perfectly to the UI
    // ==========================================
    @AuraEnabled
    public static Map<String, List<EntityWrapper>> getTeamMembers(List<String> groupIds) {
        Map<String, List<EntityWrapper>> teamMap = new Map<String, List<EntityWrapper>>();
        
        for (String originalGroupId : groupIds) {
            // Use our new robust helper to find everyone in this group (including roles!)
            Set<Id> userIdsInThisGroup = getExpandedUserIdsForGroup((Id)originalGroupId);
            
            List<EntityWrapper> wrappers = new List<EntityWrapper>();
            if (!userIdsInThisGroup.isEmpty()) {
                for (User u : [SELECT Id, Name, Department FROM User WHERE Id IN :userIdsInThisGroup AND IsActive = true ORDER BY Name]) {
                    EntityWrapper wrap = new EntityWrapper();
                    wrap.Id = u.Id;
                    wrap.Name = u.Name;
                    wrap.SubText = String.isNotBlank(u.Department) ? u.Department : 'No Department';
                    wrappers.add(wrap);
                }
            }
            teamMap.put(originalGroupId, wrappers);
        }
        return teamMap;
    }

    // ==========================================
    // Fetches completed Task_Log__c counts (Metric: Number of task completed)
    // ==========================================
    @AuraEnabled
    public static List<PunchResult> getPunchData(List<String> entityIds, String assignType) {
        List<PunchResult> results = new List<PunchResult>();
        try {
            Set<Id> userIdsToQuery = new Set<Id>();
            
            if (assignType == 'Users') {
                for(String eId : entityIds) {
                    userIdsToQuery.add((Id)eId);
                }
            } else if (assignType == 'Team') {
                for (String gId : entityIds) {
                    userIdsToQuery.addAll(getExpandedUserIdsForGroup((Id)gId));
                }
            }

            if(!userIdsToQuery.isEmpty()) {
                // Count checked-out task logs per user/day (same definition as Field Force completed visits)
                for(AggregateResult ar : [
                    SELECT CreatedById, DAY_ONLY(Logged_At__c) pDate, COUNT(Id) c
                    FROM Task_Log__c
                    WHERE CreatedById IN :userIdsToQuery
                    AND IsCheckout__c = true
                    AND Is_schedule__c = false
                    AND Logged_At__c = LAST_N_DAYS:180
                    GROUP BY CreatedById, DAY_ONLY(Logged_At__c)
                ]) {
                    PunchResult pr = new PunchResult();
                    pr.userId = (String) ar.get('CreatedById');
                    pr.punchDate = (Date) ar.get('pDate');
                    pr.count = (Integer) ar.get('c');
                    results.add(pr);
                }
            }
        } catch(Exception e) {
            System.debug('Error fetching task achievement data: ' + e.getMessage());
        }
        return results;
    }

    /**
     * @description Retrieves a list of active Users or Public Groups based on the assignment type.
     * @param assignType A string indicating the type of assignment ('Users' or 'Team').
     * @return List<EntityWrapper> A standardized list of assignable entities.
     */
    @AuraEnabled(cacheable=true)
    public static List<EntityWrapper> getAvailableEntities(String assignType) {
        List<EntityWrapper> entities = new List<EntityWrapper>();
        
        if (assignType == 'Users') {
            // Fetch active users and use their Profile Name as the subtext
            /*for (User u : [SELECT Id, Name, Department FROM User WHERE IsActive = true ORDER BY Name LIMIT 100]) {
                EntityWrapper wrap = new EntityWrapper();
                wrap.Id = u.Id;
                wrap.Name = u.Name;
                wrap.SubText = String.isNotBlank(u.Department) ? u.Department : 'No Department'; 
                entities.add(wrap);
            }*/

            // Get the current user's Department, Departments and Profile
            User currentUser = [
                SELECT Department, Departments__c, Profile.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            // Profiles that can see all active users
            Set<String> unrestrictedProfiles = new Set<String>{
                'System Administrator',
                'Utkarsh Admin',
                'Utkarsh HR'
            };

            // CRM Head department access comes from Departments__c, not Department
            Boolean isCrmHead = currentUser.Profile.Name == CRM_HEAD_PROFILE_NAME;

            // If the user has no Department and is not an unrestricted profile,
            // return no users
            if (!unrestrictedProfiles.contains(currentUser.Profile.Name)
                && !isCrmHead
                && String.isBlank(currentUser.Department)) {
                return entities;
            }

            List<User> users;

            if (unrestrictedProfiles.contains(currentUser.Profile.Name)) {
                // These profiles can see all active users
                users = [
                    SELECT Id, Name, Department
                    FROM User
                    WHERE IsActive = true
                    ORDER BY Name
                    LIMIT 100
                ];
            } else if (isCrmHead) {
                // CRM Head can see themselves and active users
                // belonging to any of their departments
                Id currentUserId = UserInfo.getUserId();
                Set<String> crmHeadDeptNames = getCrmHeadDepartmentNames(currentUser.Departments__c);
                users = [
                    SELECT Id, Name, Department
                    FROM User
                    WHERE IsActive = true
                    AND (Department IN :crmHeadDeptNames OR Id = :currentUserId)
                    ORDER BY Name
                    LIMIT 100
                ];
            } else {
                // Other users can only see active users
                // belonging to their own department
                users = [
                    SELECT Id, Name, Department
                    FROM User
                    WHERE IsActive = true
                    AND Department = :currentUser.Department
                    ORDER BY Name
                    LIMIT 100
                ];
            }

            for (User u : users) {
                EntityWrapper wrap = new EntityWrapper();
                wrap.Id = u.Id;
                wrap.Name = u.Name;
                wrap.SubText = String.isNotBlank(u.Department)
                    ? u.Department
                    : 'No Department';
                entities.add(wrap);
            }
        } else if (assignType == 'Team') {
            // Fetch Regular Public Groups
            for (Group g : [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Regular' ORDER BY Name LIMIT 100]) {
                EntityWrapper wrap = new EntityWrapper();
                wrap.Id = g.Id;
                wrap.Name = g.Name;
                wrap.SubText = 'Public Group'; 
                entities.add(wrap);
            }
        }
        return entities;
    }
    
    @AuraEnabled
    public static EditPayload getFullTargetDetails(String targetId) {
        EditPayload payload = new EditPayload();
        
        payload.target = [SELECT Id, Name, Target_Module__c, Frequency__c, Metric__c, Assign_To_Type__c, Status__c FROM Target__c WHERE Id = :targetId LIMIT 1];
        
        List<Target_Assignment__c> assignments = [
            SELECT Id, User__c, User__r.Name, User__r.Department, Assigned_Group_ID__c,
                   (SELECT Id, Name, Target_Quantity__c,Start_Date__c, End_Date__c FROM Target_Periods__r)
            FROM Target_Assignment__c
            WHERE Target__c = :targetId
        ];
        
        // Collect Group Names if Assigned to Teams
        Set<Id> groupIds = new Set<Id>();
        for(Target_Assignment__c ta : assignments) {
            if(String.isNotBlank(ta.Assigned_Group_ID__c)) groupIds.add((Id)ta.Assigned_Group_ID__c);
        }
        Map<Id, Group> groupMap = new Map<Id, Group>();
        if(!groupIds.isEmpty()) {
            groupMap = new Map<Id, Group>([SELECT Id, Name FROM Group WHERE Id IN :groupIds]);
        }
        
        // Map everything to the custom wrapper
        List<AssignmentDetail> details = new List<AssignmentDetail>();
        for(Target_Assignment__c ta : assignments) {
            AssignmentDetail ad = new AssignmentDetail();
            if(payload.target.Assign_To_Type__c == 'Users') {
                ad.entityId = ta.User__c;
                ad.entityName = ta.User__r.Name;
                ad.entitySubText = String.isNotBlank(ta.User__r.Department) ? ta.User__r.Department : 'No Department';
            } else {
                ad.entityId = ta.Assigned_Group_ID__c;
                Group g = groupMap.get((Id)ta.Assigned_Group_ID__c);
                ad.entityName = g != null ? g.Name : 'Unknown Group';
                ad.entitySubText = 'Public Group';
            }
            ad.periods = ta.Target_Periods__r;
            details.add(ad);
        }
        payload.assignments = details;
        return payload;
    }

    /**
     * @description Transactionally saves the Target__c parent record and its related 
     * Target_Assignment__c child records. If an error occurs, it rolls back all changes.
     * @param targetRecord The Target__c record containing the configuration details.
     * @param selectedIds A list of User or Group IDs to be assigned to the target.
     * @param assignType A string indicating if the IDs belong to Users or Teams.
     * @return String Returns 'Success' if the transaction commits without errors.
     * @throws AuraHandledException if any DML operation fails.
     */
    @AuraEnabled
    public static String saveTargetData(Target__c targetRecord, String assignmentsJSON, String assignType) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<AssignmentPayload> selectedAssignments = (List<AssignmentPayload>) JSON.deserialize(assignmentsJSON, List<AssignmentPayload>.class);
            
            // 1. Upsert Parent Record & Clean up children if editing
            if(targetRecord.Id != null) {
                update targetRecord;
                // Delete existing assignments (Master-Detail cascades and deletes periods too)
                delete [SELECT Id FROM Target_Assignment__c WHERE Target__c = :targetRecord.Id];
            } else {
                insert targetRecord;
            }

            // 2. Insert new Assignments
            List<Target_Assignment__c> assignmentsToInsert = new List<Target_Assignment__c>();
            for (AssignmentPayload payload : selectedAssignments) {
                Target_Assignment__c assignment = new Target_Assignment__c();
                assignment.Target__c = targetRecord.Id;
                
                if (assignType == 'Users') {
                    assignment.User__c = payload.Id;
                } else if (assignType == 'Team') {
                    assignment.Assigned_Group_ID__c = payload.Id;
                }
                assignmentsToInsert.add(assignment);
            }
            insert assignmentsToInsert;

            // 3. Insert new Periods
            List<Target_Period__c> periodsToInsert = new List<Target_Period__c>();
            for (Integer i = 0; i < selectedAssignments.size(); i++) {
                AssignmentPayload payload = selectedAssignments[i];
                Target_Assignment__c savedAssignment = assignmentsToInsert[i]; 
                
                if (payload.periods != null) {
                    for (PeriodPayload period : payload.periods) {
                        if (!period.isPast && String.isNotBlank(period.inputValue)) {
                            try {
                                Target_Period__c tp = new Target_Period__c();
                                tp.Target_Assignment__c = savedAssignment.Id;
                                tp.Name = period.label;
                                tp.Target_Quantity__c = Integer.valueOf(period.inputValue);
                                if (String.isNotBlank(period.startDate)) tp.Start_Date__c = Date.valueOf(period.startDate);
                                if (String.isNotBlank(period.endDate)) tp.End_Date__c = Date.valueOf(period.endDate);
                                periodsToInsert.add(tp);
                            } catch (TypeException te) {
                                System.debug('Invalid number format skipped: ' + period.inputValue);
                            }
                        }
                    }
                }
            }
            
            if (!periodsToInsert.isEmpty()) {
                insert periodsToInsert;
            }
            
            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error saving target: ' + e.getMessage());
        }
    }
    
    // NEW: Highly reusable dynamic picklist fetcher
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getDynamicPicklists(String objectApiName, List<String> fieldApiNames) {
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();

        try {
            // 1. Find the Object dynamically
            SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                return picklistMap; // Return empty if object doesn't exist
            }

            // 2. Get a map of all fields on that object
            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

            // 3. Loop through the requested fields and extract their active picklist values
            for (String fieldName : fieldApiNames) {
                Schema.SObjectField field = fieldMap.get(fieldName);
                
                if (field != null) {
                    List<PicklistOption> options = new List<PicklistOption>();
                    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
                        if (entry.isActive()) {
                            options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                        }
                    }
                    picklistMap.put(fieldName, options);
                }
            }
        } catch (Exception e) {
            System.debug('Error dynamically fetching picklists: ' + e.getMessage());
            throw new AuraHandledException('Error fetching picklists: ' + e.getMessage());
        }

        return picklistMap;
    }
    
    /*@AuraEnabled(cacheable=true)
    public static TargetListWrapper getExistingTargets() {
        TargetListWrapper result = new TargetListWrapper();
        Id currentUserId = UserInfo.getUserId();
        
        // Check if the current user has the Manager checkbox checked
        User currentUser = [SELECT Target_Manager__c FROM User WHERE Id = :currentUserId LIMIT 1];
        result.isManager = currentUser.Target_Manager__c;
        
        // Base Query
        String query = 'SELECT Id, Name, Target_Module__c, Assign_To_Type__c, Status__c, ' +
                       'CreatedBy.Name, CreatedDate, Frequency__c, Metric__c, ' +
                       '(SELECT User__c, User__r.Name FROM Target_Assignments__r) ' +
                       'FROM Target__c ';
        
        // ROLE-BASED FILTERING: If not a manager, only show targets they are assigned to
        if (!result.isManager) {
            query += 'WHERE Id IN (SELECT Target__c FROM Target_Assignment__c WHERE User__c = :currentUserId) ';
        }
        
        query += 'ORDER BY CreatedDate DESC';
        
        result.targets = Database.query(query);
        return result;
    }*/
    @AuraEnabled(cacheable=true)
    public static TargetListWrapper getExistingTargets() {
        TargetListWrapper result = new TargetListWrapper();
        Id currentUserId = UserInfo.getUserId();

        // Get current user's manager status, department(s) and profile
        User currentUser = [
            SELECT Target_Manager__c, Department, Departments__c, Profile.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        // CRM Head: themselves + active users belonging to any of their departments
        // (declared at method level so the dynamic query below can bind it)
        Set<Id> crmHeadUserIds = new Set<Id>{ currentUserId };

        // HOD: active users from the HOD's department
        Set<Id> departmentUserIds = new Set<Id>();

        // Target_Manager__c controls whether the Targets tab is visible
        result.isManager = currentUser.Target_Manager__c;

        String query =
            'SELECT Id, Name, Target_Module__c, Assign_To_Type__c, Status__c, ' +
            'CreatedBy.Name, CreatedDate, Frequency__c, Metric__c, ' +
            '(SELECT User__c, User__r.Name FROM Target_Assignments__r) ' +
            'FROM Target__c ';

        // ---------------------------------------------------------
        // 1. Admin / HR → See ALL targets
        // ---------------------------------------------------------
        if (currentUser.Profile.Name == 'System Administrator' ||
            currentUser.Profile.Name == 'Utkarsh Admin' ||
            currentUser.Profile.Name == 'Utkarsh HR') {

            // No WHERE clause
            // All targets are returned.

        // ---------------------------------------------------------
        // 2. HOD → See targets assigned to users in their department
        // ---------------------------------------------------------
        } else if (currentUser.Profile.Name == 'Utkarsh HOD') {

            if (String.isNotBlank(currentUser.Department)) {

                // First get active users from the HOD's department
                for (User u : [
                    SELECT Id
                    FROM User
                    WHERE IsActive = true
                    AND Department = :currentUser.Department
                ]) {
                    departmentUserIds.add(u.Id);
                }

                // Then find targets assigned to those users
                if (!departmentUserIds.isEmpty()) {

                    query +=
                        'WHERE Id IN (' +
                            'SELECT Target__c ' +
                            'FROM Target_Assignment__c ' +
                            'WHERE User__c IN :departmentUserIds' +
                        ') ';

                } else {
                    // No users in department → no targets
                    query += 'WHERE Id = null ';
                }

            } else {
                // HOD without a department → no targets
                query += 'WHERE Id = null ';
            }

        // ---------------------------------------------------------
        // CRM Head → See own targets + targets assigned to users
        // in any of their departments (from Departments__c)
        // ---------------------------------------------------------
        } else if (currentUser.Profile.Name == CRM_HEAD_PROFILE_NAME) {

            Set<String> crmHeadDeptNames = getCrmHeadDepartmentNames(currentUser.Departments__c);
            if (!crmHeadDeptNames.isEmpty()) {
                for (User u : [
                    SELECT Id
                    FROM User
                    WHERE IsActive = true
                    AND Department IN :crmHeadDeptNames
                ]) {
                    crmHeadUserIds.add(u.Id);
                }
            }

            query +=
                'WHERE Id IN (' +
                    'SELECT Target__c ' +
                    'FROM Target_Assignment__c ' +
                    'WHERE User__c IN :crmHeadUserIds' +
                ') ';

        // ---------------------------------------------------------
        // 3. All other profiles → See only their own targets
        // ---------------------------------------------------------
        } else {

            query +=
                'WHERE Id IN (' +
                    'SELECT Target__c ' +
                    'FROM Target_Assignment__c ' +
                    'WHERE User__c = :currentUserId' +
                ') ';
        }

        // Most recently created targets first
        query += 'ORDER BY CreatedDate DESC';

        result.targets = Database.query(query);

        return result;
    }
    
    // ==========================================
    // NEW: CALCULATES THE DASHBOARD DYNAMICALLY
    // ==========================================
  @AuraEnabled
    public static DashboardWrapper getDashboardStats(String targetId, String startDateStr, String endDateStr) {
        DashboardWrapper dw = new DashboardWrapper();
        dw.employees = new List<EmployeeStat>();
        dw.overallAchievement = 0;
        
        Id currentUserId = UserInfo.getUserId();
        Boolean isManager = false;
        List<User> currentUser = [SELECT Target_Manager__c FROM User WHERE Id = :currentUserId LIMIT 1];
        if (!currentUser.isEmpty()) {
            isManager = currentUser[0].Target_Manager__c;
        }

        Target__c t = [SELECT Id, Name, Assign_To_Type__c, Frequency__c, Metric__c, Target_Module__c FROM Target__c WHERE Id = :targetId LIMIT 1];

        // Safe Date Parsing
        Date cycleStart = Date.valueOf(startDateStr.substring(0, 10));
        Date cycleEnd = Date.valueOf(endDateStr.substring(0, 10));

        // Timezone Safe DateTime Boundaries
        DateTime dtStart = DateTime.newInstance(cycleStart.year(), cycleStart.month(), cycleStart.day(), 0, 0, 0);
        DateTime dtEnd = DateTime.newInstance(cycleEnd.year(), cycleEnd.month(), cycleEnd.day(), 23, 59, 59);
        dw.currentCycle = dtStart.format('dd-MMM-yyyy') + ' to ' + dtEnd.format('dd-MMM-yyyy');

        // Fetch Assignments FIRST
        List<Target_Assignment__c> assignments = [
            SELECT Id, User__c, Assigned_Group_ID__c FROM Target_Assignment__c WHERE Target__c = :targetId
        ];

        // Fetch Period data completely separately (Handles 0, Nulls, or Missing Periods)
        Map<Id, Integer> assignmentTargetMap = new Map<Id, Integer>();
        for (Target_Period__c tp : [SELECT Target_Assignment__c, Target_Quantity__c FROM Target_Period__c 
                                    WHERE Target_Assignment__r.Target__c = :targetId 
                                    AND Start_Date__c = :cycleStart AND End_Date__c = :cycleEnd]) {
            // Guarantee Target is never Null
            Integer q = (tp.Target_Quantity__c != null && tp.Target_Quantity__c > 0) ? (Integer)tp.Target_Quantity__c : 10;
            assignmentTargetMap.put(tp.Target_Assignment__c, q);
        }

        Map<Id, Integer> userTargetMap = new Map<Id, Integer>();
        for (Target_Assignment__c ta : assignments) {
            // Default to 10 if there is no record saved for this cycle yet
            Integer quantity = assignmentTargetMap.containsKey(ta.Id) ? assignmentTargetMap.get(ta.Id) : 10;

            if (t.Assign_To_Type__c == 'Users' && ta.User__c != null) {
                userTargetMap.put(ta.User__c, quantity);
            } else if (t.Assign_To_Type__c == 'Team' && ta.Assigned_Group_ID__c != null) {
                Set<Id> groupUsers = getExpandedUserIdsForGroup(ta.Assigned_Group_ID__c);
                for (Id uId : groupUsers) {
                    userTargetMap.put(uId, quantity); 
                }
            }
        }

        // Apply Manager Security Role Filtering
        if (!isManager) {
            if (userTargetMap.containsKey(currentUserId)) {
                Integer myTarget = userTargetMap.get(currentUserId);
                userTargetMap.clear();
                userTargetMap.put(currentUserId, myTarget);
            } else {
                userTargetMap.clear(); 
            }
        }

        if (userTargetMap.isEmpty()) return dw;

        // Achieved = completed Task_Log__c (checked out) for Metric "Number of task completed"
        Map<Id, Integer> userActualMap = getCompletedTaskCountsByUser(userTargetMap.keySet(), dtStart, dtEnd);

        // Build Final Statistics List
        Map<Id, User> userDetails = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :userTargetMap.keySet()]);
        Integer totalTarget = 0; Integer totalActual = 0;

        for (Id uId : userTargetMap.keySet()) {
            User u = userDetails.get(uId);
            if (u == null) continue;

            EmployeeStat stat = new EmployeeStat();
            stat.id = u.Id;
            stat.name = u.Name;
            
            String initials = '';
            if (String.isNotBlank(u.Name)) {
                List<String> nameParts = u.Name.split(' ');
                if (nameParts.size() > 0) initials += nameParts[0].substring(0,1);
                if (nameParts.size() > 1) initials += nameParts[nameParts.size()-1].substring(0,1);
            }
            stat.initials = initials.toUpperCase();
            
            stat.target = userTargetMap.get(uId);
            stat.actual = userActualMap.containsKey(uId) ? userActualMap.get(uId) : 0;
            
            totalTarget += stat.target;
            totalActual += stat.actual;
            
            stat.percentage = stat.target > 0 ? ((Decimal)stat.actual / stat.target * 100).setScale(1) : 0;
            stat.progressText = stat.actual + '/' + stat.target;
            
            Decimal barWidth = stat.percentage > 100 ? 100 : stat.percentage;
            stat.progressStyle = 'width: ' + barWidth + '%;';
            
            dw.employees.add(stat);
        }
        
        // ==========================================
        // TREND LINE: completed tasks day by day
        // ==========================================
        dw.trendLines = new List<TrendData>();
        Map<Date, Integer> dateToTasks = new Map<Date, Integer>();
        
        for (AggregateResult ar : [
            SELECT DAY_ONLY(Logged_At__c) pDate, COUNT(Id) c
            FROM Task_Log__c
            WHERE CreatedById IN :userTargetMap.keySet()
            AND IsCheckout__c = true
            AND Is_schedule__c = false
            AND Logged_At__c >= :dtStart
            AND Logged_At__c <= :dtEnd
            GROUP BY DAY_ONLY(Logged_At__c)
        ]) {
            dateToTasks.put((Date)ar.get('pDate'), (Integer)ar.get('c'));
        }

        // Generate a smooth line by plotting every single day in the cycle
        Integer daysBetween = cycleStart.daysBetween(cycleEnd);
        for(Integer i = 0; i <= daysBetween; i++) {
            Date d = cycleStart.addDays(i);
            TrendData td = new TrendData();
            DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
            
            // Format label based on Frequency (Mon, Tue for Weekly. Jun 01, Jun 02 for Monthly)
            if (t.Frequency__c == 'Weekly') {
                td.label = dt.format('EEE'); 
            } else {
                td.label = dt.format('MMM dd'); 
            }
            
            td.value = dateToTasks.containsKey(d) ? dateToTasks.get(d) : 0;
            dw.trendLines.add(td);
        }

        dw.overallAchievement = totalTarget > 0 ? ((Decimal)totalActual / totalTarget * 100).setScale(2) : 0;
        return dw;
    }

    /**
     * @description Counts completed Task_Log__c records (checked out, non-schedule) per user in a datetime range.
     * Aligns with FieldForceDashboardController completed-visit logic and Metric "Number of task completed".
     */
    private static Map<Id, Integer> getCompletedTaskCountsByUser(Set<Id> userIds, DateTime dtStart, DateTime dtEnd) {
        Map<Id, Integer> userActualMap = new Map<Id, Integer>();
        if (userIds == null || userIds.isEmpty()) {
            return userActualMap;
        }
        for (AggregateResult ar : [
            SELECT CreatedById, COUNT(Id) c
            FROM Task_Log__c
            WHERE CreatedById IN :userIds
            AND IsCheckout__c = true
            AND Is_schedule__c = false
            AND Logged_At__c >= :dtStart
            AND Logged_At__c <= :dtEnd
            GROUP BY CreatedById
        ]) {
            userActualMap.put((Id)ar.get('CreatedById'), (Integer)ar.get('c'));
        }
        return userActualMap;
    }
}