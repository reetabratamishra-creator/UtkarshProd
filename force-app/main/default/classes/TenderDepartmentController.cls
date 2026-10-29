/*
 public with sharing class TenderDepartmentController {

    //============================================================
    // Wrapper Classes
    //============================================================

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class UserOption {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
        @AuraEnabled public String department;
        @AuraEnabled public String profileName;

        public UserOption(User u) {
            value = u.Id;
            label = u.Name;
            department = u.Department;
            profileName = u.Profile.Name;
        }
    }

    public class TenderInfo {
        @AuraEnabled public String department;
        @AuraEnabled public Id ownerId;

        public TenderInfo(String dept, Id owner) {
            department = dept;
            ownerId = owner;
        }
    }

    //============================================================
    // Get Tender Details
    //============================================================

    @AuraEnabled(cacheable=true)
    public static TenderInfo getTenderDetails(Id tenderId) {

        if(tenderId == null){
            throw new AuraHandledException('Tender Id is required.');
        }

        Tender__c tender = [
            SELECT Id,
                   Department_Name__c,
                   OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
            LIMIT 1
        ];

        return new TenderInfo(
            tender.Department_Name__c,
            tender.OwnerId
        );
    }

    //============================================================
    // Department Picklist
    //============================================================

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getDepartments(){

        List<PicklistOption> options = new List<PicklistOption>();

        Schema.DescribeFieldResult fieldDescribe =
            Tender__c.Department_Name__c.getDescribe();

        for(Schema.PicklistEntry pe :
            fieldDescribe.getPicklistValues()){

            options.add(
                new PicklistOption(
                    pe.getLabel(),
                    pe.getValue()
                )
            );
        }

        return options;
    }

    //============================================================
    // Get Users
    //============================================================

@AuraEnabled(cacheable=true)
public static List<UserOption> getDepartmentUsers(String department) {

    List<UserOption> options = new List<UserOption>();

    if (String.isBlank(department)) {
        return options;
    }

    // Normalize selected department
    String selectedDepartment = department.trim().toLowerCase();

    List<User> users = [
        SELECT Id,
               Name,
               Department,
               Profile.Name
        FROM User
        WHERE IsActive = true
        AND Profile.Name = 'Utkarsh Tender'
        ORDER BY Name
    ];

    for (User u : users) {

        if (String.isBlank(u.Department)) {
            continue;
        }

        // Normalize all possible separators to comma
        String normalizedDepartments = u.Department.toLowerCase();

        normalizedDepartments = normalizedDepartments.replace(';', ',');
        normalizedDepartments = normalizedDepartments.replace('/', ',');
        normalizedDepartments = normalizedDepartments.replace('\\', ',');
        normalizedDepartments = normalizedDepartments.replace('|', ',');
        
        normalizedDepartments = normalizedDepartments.replace(':', ',');
        
        normalizedDepartments = normalizedDepartments.replace('\n', ',');
        normalizedDepartments = normalizedDepartments.replace('\r', ',');

        List<String> deptList = normalizedDepartments.split(',');

        for (String dept : deptList) {

            if (dept != null &&
                dept.trim().equalsIgnoreCase(selectedDepartment)) {

                options.add(new UserOption(u));
                break;
            }
        }
    }

    return options;
}

    //============================================================
    // Save
    //============================================================

    @AuraEnabled
    public static void updateDepartmentAndOwner(

        Id tenderId,
        String department,
        Id ownerId

    ){

        if(tenderId == null){
            throw new AuraHandledException(
                'Tender Id is missing.'
            );
        }

        if(String.isBlank(department)){
            throw new AuraHandledException(
                'Please select Department.'
            );
        }

        if(ownerId == null){
            throw new AuraHandledException(
                'Please select Owner.'
            );
        }

        //============================================================
// CRUD / FLS CHECKS
//============================================================

if (!Schema.sObjectType.Tender__c.isUpdateable()) {

    throw new AuraHandledException(
        'You do not have permission to update this Tender.'
    );

}

if (!Schema.sObjectType.Tender__c.fields.Department_Name__c.isUpdateable()) {

    throw new AuraHandledException(
        'You do not have permission to update the Department.'
    );

}

if (!Schema.sObjectType.Tender__c.fields.OwnerId.isUpdateable()) {

    throw new AuraHandledException(
        'You do not have permission to change the Owner.'
    );

}

        Tender__c tender = [

            SELECT Id,
                   Department_Name__c,
                   OwnerId

            FROM Tender__c

            WHERE Id=:tenderId

            LIMIT 1

        ];

        tender.Department_Name__c = department;
        tender.OwnerId = ownerId;

        Database.SaveResult sr =
            Database.update(tender,false);

        if(!sr.isSuccess()){

    Database.Error err = sr.getErrors()[0];

    if (err.getStatusCode() == StatusCode.INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY ||
        err.getStatusCode() == StatusCode.INSUFFICIENT_ACCESS_OR_READONLY) {

        throw new AuraHandledException(
            'You do not have permission to change the Department or Owner.'
        );
    }

    throw new AuraHandledException(err.getMessage());
}

        }
    

    }
*/
public with sharing class TenderDepartmentController {

    //============================================================
    // Wrapper Classes
    //============================================================

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class UserOption {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
        @AuraEnabled public String department;

        public UserOption(User u) {
            value = u.Id;
            label = u.Name;
            department = u.Department;
        }
    }

    public class TenderInfo {
        @AuraEnabled public String department;
        @AuraEnabled public Id ownerId;

        public TenderInfo(String dept, Id owner) {
            department = dept;
            ownerId = owner;
        }
    }

    //============================================================
    // Get Tender Details
    //============================================================

    // Fetches the current Department and Owner of a Tender record.
    @AuraEnabled(cacheable=true)
    public static TenderInfo getTenderDetails(Id tenderId) {

        if(tenderId == null){
            throw new AuraHandledException('Tender Id is required.');
        }

        Tender__c tender = [
            SELECT Id,
                   Department_Name__c,
                   OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return new TenderInfo(
            tender.Department_Name__c,
            tender.OwnerId
        );
    }

    //============================================================
    // Department Picklist
    //============================================================

    // Returns all picklist values defined on Tender__c.Department_Name__c,
    // excluding the "Enquiry" value.
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getDepartments(){

        List<PicklistOption> options = new List<PicklistOption>();

        Schema.DescribeFieldResult fieldDescribe =
            Tender__c.Department_Name__c.getDescribe();

        for(Schema.PicklistEntry pe :
            fieldDescribe.getPicklistValues()){

            if (pe.getValue().equalsIgnoreCase('Enquiry')) {
                continue;
            }

            options.add(
                new PicklistOption(
                    pe.getLabel(),
                    pe.getValue()
                )
            );
        }

        return options;
    }

    //============================================================
    // Get Users
    //============================================================

    // Returns active users flagged as Tender Users whose Department
    // field matches the selected department (handles multiple
    // department values separated by common delimiters).
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getDepartmentUsers(String department) {

        List<UserOption> options = new List<UserOption>();

        if (String.isBlank(department)) {
            return options;
        }

        // Normalize selected department
        String selectedDepartment = department.trim().toLowerCase();

     List<User> users = [
    SELECT Id,
           Name,
           Department,
           Profile.Name
    FROM User
    WHERE IsActive = true
    AND Tender_Access_User__c = true
    AND Profile.Name IN ('Utkarsh Sales', 'Utkarsh Tender')
    WITH SYSTEM_MODE
    ORDER BY Name
];

        for (User u : users) {

            if (String.isBlank(u.Department)) {
                continue;
            }

            // Normalize all possible separators to comma
            String normalizedDepartments = u.Department.toLowerCase();

            normalizedDepartments = normalizedDepartments.replace(';', ',');
            normalizedDepartments = normalizedDepartments.replace('/', ',');
            normalizedDepartments = normalizedDepartments.replace('\\', ',');
            normalizedDepartments = normalizedDepartments.replace('|', ',');
            normalizedDepartments = normalizedDepartments.replace(':', ',');
            normalizedDepartments = normalizedDepartments.replace('\n', ',');
            normalizedDepartments = normalizedDepartments.replace('\r', ',');

            List<String> deptList = normalizedDepartments.split(',');

            for (String dept : deptList) {

                if (dept != null &&
                    dept.trim().equalsIgnoreCase(selectedDepartment)) {

                    options.add(new UserOption(u));
                    break;
                }
            }
        }

        return options;
    }

    //============================================================
    // Save
    //============================================================

    // Updates the Tender's Department and Owner, then cascades the
    // new Owner to related Bidders, Bidders Contact Details,
    // Tender Ai Summary Json, and Tender Docoment Details records.
    //
    // NOTE: This method intentionally runs its DML in SYSTEM_MODE so
    // that users without direct Edit access on Tender__c (and its
    // related child objects) can still perform this action through
    // this controlled, validated entry point. Do NOT grant object/field
    // edit permissions to these users elsewhere as a substitute - the
    // access is deliberately scoped to only what this method does.
    @AuraEnabled
    public static void updateDepartmentAndOwner(
        Id tenderId,
        String department,
        Id ownerId
    ){

         if(tenderId == null){
        AuraHandledException ex = new AuraHandledException('Tender Id is missing.');
        ex.setMessage('Tender Id is missing.');
        throw ex;
    }

       if(String.isBlank(department)){
        AuraHandledException ex = new AuraHandledException('Please select Department.');
        ex.setMessage('Please select Department.');
        throw ex;
    }

          if(ownerId == null){
        AuraHandledException ex = new AuraHandledException('Please select Owner.');
        ex.setMessage('Please select Owner.');
        throw ex;
    }

        Tender__c tender = [
            SELECT Id,
                   Department_Name__c,
                   OwnerId
            FROM Tender__c
            WHERE Id=:tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        tender.Department_Name__c = department;
        tender.OwnerId = ownerId;

        Database.SaveResult sr = Database.update(
            tender,
            new Database.DMLOptions(),
            AccessLevel.SYSTEM_MODE
        );

        if(!sr.isSuccess()){

            Database.Error err = sr.getErrors()[0];
            AuraHandledException ex = new AuraHandledException(err.getMessage());
        ex.setMessage(err.getMessage());  
        throw ex;
        }

        // Tender updated successfully - cascade the owner change
        // to related child records.
        reassignRelatedRecordOwners(tenderId, ownerId);
    }

    //============================================================
    // Cascade Owner Change To Related Records
    //============================================================

    // Reassigns the Owner on all child records linked to this Tender.
    // Tender save already succeeded; any child-record failures are
    // collected and reported together instead of stopping the process.
    // Runs in SYSTEM_MODE for the same reason as updateDepartmentAndOwner.
    private static void reassignRelatedRecordOwners(Id tenderId, Id newOwnerId) {

        List<String> errors = new List<String>();

        reassignBidders(tenderId, newOwnerId, errors);
        reassignBidderContactDetails(tenderId, newOwnerId, errors);
        reassignTenderAiSummaryJson(tenderId, newOwnerId, errors);
        reassignTenderDocomentDetails(tenderId, newOwnerId, errors);

      if (!errors.isEmpty()) {
    String msg = 'Tender owner was updated, but some related records ' +
                 'could not be reassigned: ' + String.join(errors, ' | ');
    AuraHandledException ex = new AuraHandledException(msg);
    ex.setMessage(msg);
    throw ex;
}
    }

    // Reassigns Owner on all Bidders__c records linked to this Tender.
    private static void reassignBidders(Id tenderId, Id newOwnerId, List<String> errors) {

        List<Bidders__c> bidders = [
            SELECT Id, OwnerId
            FROM Bidders__c
            WHERE Tender__c = :tenderId
            WITH SYSTEM_MODE
        ];

        if (bidders.isEmpty()) {
            return;
        }

        for (Bidders__c b : bidders) {
            b.OwnerId = newOwnerId;
        }

        List<Database.SaveResult> results = Database.update(
            bidders,
            new Database.DMLOptions(),
            AccessLevel.SYSTEM_MODE
        );
        collectErrors(results, 'Bidders', errors);
    }

    // Reassigns Owner on all Bidders_Contact_Details__c records linked to this Tender.
    private static void reassignBidderContactDetails(Id tenderId, Id newOwnerId, List<String> errors) {

        List<Bidders_Contact_Details__c> contacts = [
            SELECT Id, OwnerId
            FROM Bidders_Contact_Details__c
            WHERE Tender__c = :tenderId
            WITH SYSTEM_MODE
        ];

        if (contacts.isEmpty()) {
            return;
        }

        for (Bidders_Contact_Details__c c : contacts) {
            c.OwnerId = newOwnerId;
        }

        List<Database.SaveResult> results = Database.update(
            contacts,
            new Database.DMLOptions(),
            AccessLevel.SYSTEM_MODE
        );
        collectErrors(results, 'Bidders Contact Details', errors);
    }

    // Reassigns Owner on all Tender_Ai_Summary_Json__c records linked to this Tender.
    private static void reassignTenderAiSummaryJson(Id tenderId, Id newOwnerId, List<String> errors) {

        List<Tender_Ai_Summary_Json__c> summaries = [
            SELECT Id, OwnerId
            FROM Tender_Ai_Summary_Json__c
            WHERE Tender__c = :tenderId
            WITH SYSTEM_MODE
        ];

        if (summaries.isEmpty()) {
            return;
        }

        for (Tender_Ai_Summary_Json__c s : summaries) {
            s.OwnerId = newOwnerId;
        }

        List<Database.SaveResult> results = Database.update(
            summaries,
            new Database.DMLOptions(),
            AccessLevel.SYSTEM_MODE
        );
        collectErrors(results, 'Tender Ai Summary Json', errors);
    }

    // Reassigns Owner on all Tender_Docoment_Details__c records linked to this Tender.
    private static void reassignTenderDocomentDetails(Id tenderId, Id newOwnerId, List<String> errors) {

        List<Tender_Docoment_Details__c> docs = [
            SELECT Id, OwnerId
            FROM Tender_Docoment_Details__c
            WHERE Tender__c = :tenderId
            WITH SYSTEM_MODE
        ];

        if (docs.isEmpty()) {
            return;
        }

        for (Tender_Docoment_Details__c d : docs) {
            d.OwnerId = newOwnerId;
        }

        List<Database.SaveResult> results = Database.update(
            docs,
            new Database.DMLOptions(),
            AccessLevel.SYSTEM_MODE
        );
        collectErrors(results, 'Tender Docoment Details', errors);
    }

    // Collects error messages from a DML result list, prefixed with a label
    // identifying which object the errors came from.
    private static void collectErrors(
        List<Database.SaveResult> results,
        String label,
        List<String> errors
    ) {
        for (Database.SaveResult r : results) {
            if (!r.isSuccess()) {
                for (Database.Error e : r.getErrors()) {
                    errors.add(label + ': ' + e.getMessage());
                }
            }
        }
    }
}