public without sharing class TenderSharingHandler {

    public static void shareTenders(List<Tender__c> tenders) {

        if (tenders == null || tenders.isEmpty()) return;

        // Collect Tender Ids
        Set<Id> tenderIds = new Set<Id>();
        for (Tender__c t : tenders) {
            if (t.Id != null && t.Department_Name__c != null) {
                tenderIds.add(t.Id);
            }
            System.debug('tender id '+t.Id);
        }
        

        if (tenderIds.isEmpty()) return;

        //  Department normalization map
        Map<String, String> deptMap = getDeptNormalizationMap();

        // Collect normalized departments from tenders
        Map<Id, String> tenderDeptMap = new Map<Id, String>();
        Set<String> allDepartments = new Set<String>();

        for (Tender__c t : tenders) {
            if (t.Department_Name__c == null) continue;

            String normalizedDept = normalizeDept(t.Department_Name__c, deptMap);
            tenderDeptMap.put(t.Id, normalizedDept);
            allDepartments.add(normalizedDept);
        }
        
        System.debug('Tender Dept Map'+tenderDeptMap);

        // Get relevant users only (filtering early)
        List<User> users = [
            SELECT Id,Name, Departments__c, Profile.Name,
                   Tender_Access_User__c
            FROM User
            WHERE IsActive = TRUE
            AND Departments__c != NULL
            WITH SYSTEM_MODE
        ];
        
        System.debug('users fetched'+users);
        for(User us: users)
        {
            System.debug(us.Name);
        }

        // Build Department → Users Map
        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();

        for (User usr : users) {
            
            

            // Skip Admins (they already have full access)
            if (usr.Profile.Name == 'System Administrator' ||
                usr.Profile.Name == 'Utkarsh Admin') {
                continue;
            }

            Set<String> userDepts = new Set<String>();
            for (String d : usr.Departments__c.split(';')) {
                userDepts.add(d.trim());
            }

            for (String dept : userDepts) {
                if (!deptUsersMap.containsKey(dept)) {
                    deptUsersMap.put(dept, new List<User>());
                }
                deptUsersMap.get(dept).add(usr);
            }
        }
        System.debug('concerned users'+deptUsersMap);

        // Remove old manual shares (important)
        List<Tender__Share> oldShares = [
            SELECT Id
            FROM Tender__Share
            WHERE ParentId IN :tenderIds
            AND RowCause = 'Manual'
            WITH SYSTEM_MODE
        ];

        if (!oldShares.isEmpty()) {
            delete oldShares;
        }

        // Prepare new share records
        List<Tender__Share> shareRecords = new List<Tender__Share>();
        Set<String> uniqueKeys = new Set<String>(); // prevent duplicates

        for (Id tenderId : tenderDeptMap.keySet()) {

            String dept = tenderDeptMap.get(tenderId);

            if (!deptUsersMap.containsKey(dept)) continue;

            for (User usr : deptUsersMap.get(dept)) {
               
    

                String accessLevel;

                // CRM Head & HOD → Edit
                if (usr.Profile.Name == 'Utkarsh HOD' ||
                    usr.Profile.Name == 'CRM Head') {
                    accessLevel = 'Edit';
                }

                // Utkarsh Tender → Read
                else if (usr.Profile.Name == 'Utkarsh Tender') {
                    accessLevel = 'Read';
                }

                // Checkbox users → Read
                else if (usr.Tender_Access_User__c == true) {
                    accessLevel = 'Read';
                }

                else {
                    continue;
                }

                // Prevent duplicate shares
                String key = tenderId + '-' + usr.Id;
                if (uniqueKeys.contains(key)) continue;
                uniqueKeys.add(key);
                System.debug('for user '+usr.Name+'acces level set to '+accessLevel);
                shareRecords.add(createShare(tenderId, usr.Id, accessLevel));
                
            }
        }
        System.debug('In the end final share records'+shareRecords);

        // Insert shares
       if (!shareRecords.isEmpty()) {
    Database.SaveResult[] results = Database.insert(shareRecords,false);

    for (Database.SaveResult result : results) {
        if (!result.isSuccess()) {
            for (Database.Error error : result.getErrors()) {
                System.debug('TENDER SHARE INSERT ERROR: ' + error.getMessage());
            }
        }
    }
}
    }

    // Helper: Normalize Department
    private static String normalizeDept(String rawDept, Map<String, String> deptMap) {
        String key = rawDept.trim().toUpperCase();
        return deptMap.containsKey(key) ? deptMap.get(key) : rawDept.trim();
    }

    // Helper: Department Mapping
    private static Map<String, String> getDeptNormalizationMap() {
        return new Map<String, String>{
            'HIGH MAST & POLYGONAL' => 'High_Mast_Department',
            'CRASH BARRIER' => 'Crash_Barrier_Department',
            'HDPE' => 'HDPE_Pipe_Department',
            'STEEL TUBULAR POLES' => 'Steel_Tubular_Pole_Department',
            'POLYMER' => 'PVC',
            'TRANSMISSION & TELECOM TOWER' => 'Transmission_Tower_Department',
            'PRE ENGINEERING BUILDING' => 'PEB',
            'SOLAR STRUCTURE' => 'Solar_Structure_Department',
            'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
            'STEEL PIPES' => 'Steel_Pipes_Department'
        };
    }

    // Helper: Create Share Record
    private static Tender__Share createShare(Id recordId, Id userId, String accessLevel) {
        Tender__Share share = new Tender__Share();
        share.ParentId = recordId;
        share.UserOrGroupId = userId;
        share.AccessLevel = accessLevel;
        share.RowCause = Schema.Tender__Share.RowCause.Manual;
        return share;
    }

    // ---------------- ayantika (getTenderDeptNames) -----------------
    // Returns the raw Tender department names for the given normalized (user) departments.
    // Example: 'Crash_Barrier_Department' -> 'CRASH BARRIER'
    public static Set<String> getTenderDeptNames(Set<String> normalizedDepts) {
        Set<String> result = new Set<String>();

        if (normalizedDepts == null || normalizedDepts.isEmpty()) {
            return result;
        }

        Map<String, String> deptMap = getDeptNormalizationMap();
        for (String rawName : deptMap.keySet()) {
            if (normalizedDepts.contains(deptMap.get(rawName))) {
                result.add(rawName);
            }
        }

        // Also match tenders whose department is already stored in normalized form
        result.addAll(normalizedDepts);
        return result;
    }
}