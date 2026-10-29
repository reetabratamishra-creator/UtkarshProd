public with sharing class TenderOwnerValidationHandler {

    /*
     * Validates Tender Owner changes.
     *
     * Rule:
     * The new Owner must satisfy BOTH conditions:
     *
     * 1. Owner's Departments__c multi-select picklist must contain
     *    the normalized Department_Name__c of the Tender.
     *
     * 2. Owner's Tender_Access_User__c checkbox must be TRUE.
     *
     * If either condition fails:
     *     "Department mismatched"
     *
     * All SOQL queries are executed in SYSTEM MODE.
     */
    public static void validateOwnerChange(
        List<Tender__c> newTenders,
        Map<Id, Tender__c> oldTenderMap
    ) {

        if (
            newTenders == null ||
            newTenders.isEmpty() ||
            oldTenderMap == null ||
            oldTenderMap.isEmpty()
        ) {
            return;
        }

        // ---------------------------------------------------------
        // 1. Collect new Owner Ids only for records where Owner changed
        // ---------------------------------------------------------
        Set<Id> ownerIds = new Set<Id>();

        for (Tender__c tender : newTenders) {

            Tender__c oldTender = oldTenderMap.get(tender.Id);

            if (oldTender == null) {
                continue;
            }

            // Owner has not changed
            if (tender.OwnerId == oldTender.OwnerId) {
                continue;
            }

            // Owner is required for this validation
            if (tender.OwnerId != null) {
                ownerIds.add(tender.OwnerId);
            }
        }

        if (ownerIds.isEmpty()) {
            return;
        }

        // ---------------------------------------------------------
        // 2. Query new Owners in SYSTEM MODE
        // ---------------------------------------------------------
        Map<Id, User> ownerMap = new Map<Id, User>();

        for (User usr : [
            SELECT Id,
                   Departments__c,
                   Tender_Access_User__c
            FROM User
            WHERE Id IN :ownerIds
            WITH SYSTEM_MODE
        ]) {
            ownerMap.put(usr.Id, usr);
        }

        // ---------------------------------------------------------
        // 3. Get Tender Department mapping
        // ---------------------------------------------------------
        Map<String, String> departmentMap = getDepartmentMapping();

        // ---------------------------------------------------------
        // 4. Validate each Tender
        // ---------------------------------------------------------
        for (Tender__c tender : newTenders) {

            Tender__c oldTender = oldTenderMap.get(tender.Id);

            if (oldTender == null) {
                continue;
            }

            // Validate only when Owner changes
            if (tender.OwnerId == oldTender.OwnerId) {
                continue;
            }

            // -----------------------------------------------------
            // Tender Department must be populated
            // -----------------------------------------------------
            if (String.isBlank(tender.Department_Name__c)) {
                tender.addError('Department mismatched');
                continue;
            }

            // -----------------------------------------------------
            // Normalize Tender Department
            // -----------------------------------------------------
            String tenderDepartment = normalizeDepartment(
                tender.Department_Name__c,
                departmentMap
            );

            // -----------------------------------------------------
            // Get new Owner
            // -----------------------------------------------------
            User newOwner = ownerMap.get(tender.OwnerId);

            // Owner is not a User / cannot be found
            if (newOwner == null) {
                tender.addError('Department mismatched');
                continue;
            }

            // -----------------------------------------------------
            // CONDITION 1:
            // Owner must have Tender_Access_User__c = TRUE
            // -----------------------------------------------------
            if (newOwner.Tender_Access_User__c != true) {
                tender.addError('Department mismatched');
                continue;
            }

            // -----------------------------------------------------
            // Owner Department__c must be populated
            // -----------------------------------------------------
            if (String.isBlank(newOwner.Departments__c)) {
                tender.addError('Please select same department tender user');
                continue;
            }

            // -----------------------------------------------------
            // Convert Owner multi-select picklist into Set
            // -----------------------------------------------------
            Set<String> ownerDepartments = getDepartmentSet(
                newOwner.Departments__c
            );

            // -----------------------------------------------------
            // CONDITION 2:
            // Owner must have Tender's mapped department
            // -----------------------------------------------------
            if (!ownerDepartments.contains(tenderDepartment)) {
                tender.addError('Department mismatched');
            }
        }
    }


    /**
     * Normalizes Tender Department_Name__c into the corresponding
     * standardized department value.
     */
    private static String normalizeDepartment(
        String rawDepartment,
        Map<String, String> departmentMap
    ) {

        if (String.isBlank(rawDepartment)) {
            return null;
        }

        String departmentKey = rawDepartment.trim().toUpperCase();

        if (departmentMap.containsKey(departmentKey)) {
            return departmentMap.get(departmentKey);
        }

        // If there is no mapping, use the original value.
        return rawDepartment.trim();
    }


    /**
     * Converts a multi-select picklist into a Set.
     *
     * Example:
     *
     * High_Mast_Department;Crash_Barrier_Department
     *
     * becomes:
     *
     * {
     *     High_Mast_Department,
     *     Crash_Barrier_Department
     * }
     */
    private static Set<String> getDepartmentSet(
        String departmentValues
    ) {

        Set<String> departments = new Set<String>();

        if (String.isBlank(departmentValues)) {
            return departments;
        }

        for (String department : departmentValues.split(';')) {

            if (!String.isBlank(department)) {
                departments.add(department.trim());
            }
        }

        return departments;
    }


    /**
     * Tender Department → User Department mapping.
     */
    private static Map<String, String> getDepartmentMapping() {

        return new Map<String, String>{

            'HIGH MAST & POLYGONAL' =>
                'High_Mast_Department',

            'CRASH BARRIER' =>
                'Crash_Barrier_Department',

            'HDPE' =>
                'HDPE_Pipe_Department',

            'STEEL TUBULAR POLES' =>
                'Steel_Tubular_Pole_Department',

            'POLYMER' =>
                'PVC',

            'TRANSMISSION & TELECOM TOWER' =>
                'Transmission_Tower_Department',

            'PRE ENGINEERING BUILDING' =>
                'PEB',

            'SOLAR STRUCTURE' =>
                'Solar_Structure_Department',

            'RAILWAY ELECTRIFICATION STRUCTURE' =>
                'Core_Department',

            'STEEL PIPES' =>
                'Steel_Pipes_Department'
        };
    }
}