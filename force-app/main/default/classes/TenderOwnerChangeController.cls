/**
 * TenderOwnerChangeController
 * ----------------------------------------------------------------------
 * Powers the "Change Owner" quick action LWC on Tender__c.
 *
 * Behaviour:
 *  - Department is READ from the Tender record only (never selectable by
 *    the user in this flow) and is shown disabled in the UI.
 *  - Owner options are the active, Tender-access-flagged Users whose
 *    Department field contains that department value.
 *  - Saving updates OwnerId on the Tender__c record and cascades the new
 *    Owner to the same four related child objects used elsewhere in the
 *    Tender process.
 * ----------------------------------------------------------------------
 */
public with sharing class TenderOwnerChangeController {

    //============================================================
    // Wrapper Classes
    //============================================================

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

    public class TenderOwnerInfo {
        @AuraEnabled public Id tenderId;
        @AuraEnabled public String department;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;

        public TenderOwnerInfo(Tender__c t) {
            tenderId   = t.Id;
            department = t.Department_Name__c;
            ownerId    = t.OwnerId;
            ownerName  = t.Owner != null ? t.Owner.Name : null;
        }
    }

    //============================================================
    // Get Tender + Current Owner + Department Users (single round trip)
    //============================================================

    // Returns the Tender's current Department/Owner AND the list of
    // eligible owners for that department in one call, so the LWC does
    // not need a second server trip before it can render the picker.
    @AuraEnabled(cacheable=true)
    public static TenderOwnerInfo getTenderOwnerDetails(Id tenderId) {

        if (tenderId == null) {
            throw new AuraHandledException('Tender Id is required.');
        }

        List<Tender__c> tenders = [
            SELECT Id,
                   Department_Name__c,
                   OwnerId,
                   Owner.Name
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (tenders.isEmpty()) {
            throw new AuraHandledException('Tender record not found.');
        }

        Tender__c tender = tenders[0];

        if (String.isBlank(tender.Department_Name__c)) {
            throw new AuraHandledException(
                'This Tender does not have a Department set, so an owner cannot be chosen by department. ' +
                'Please set the Department first.'
            );
        }

        return new TenderOwnerInfo(tender);
    }

    //============================================================
    // Get Users For Department
    //============================================================

    // Returns active users flagged as Tender Users whose Department
    // field matches the given department (handles multiple department
    // values separated by common delimiters, same convention used
    // elsewhere in the Tender process).
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getDepartmentUsers(String department) {

        List<UserOption> options = new List<UserOption>();

        if (String.isBlank(department)) {
            return options;
        }

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

            String normalizedDepartments = u.Department.toLowerCase();
            normalizedDepartments = normalizedDepartments.replace(';', ',');
            normalizedDepartments = normalizedDepartments.replace('/', ',');
            normalizedDepartments = normalizedDepartments.replace('\\', ',');
            normalizedDepartments = normalizedDepartments.replace('|', ',');
            normalizedDepartments = normalizedDepartments.replace(':', ',');
            normalizedDepartments = normalizedDepartments.replace('\n', ',');
            normalizedDepartments = normalizedDepartments.replace('\r', ',');

            for (String dept : normalizedDepartments.split(',')) {
                if (dept != null && dept.trim().equalsIgnoreCase(selectedDepartment)) {
                    options.add(new UserOption(u));
                    break;
                }
            }
        }

        return options;
    }

    //============================================================
    // Save - Update Owner Only (Department is untouched)
    //============================================================

    @AuraEnabled
    public static void updateOwner(Id tenderId, Id ownerId) {

        if (tenderId == null) {
            throw new AuraHandledException('Tender Id is missing.');
        }

        if (ownerId == null) {
            throw new AuraHandledException('Please select an Owner.');
        }

        List<Tender__c> tenders = [
            SELECT Id, OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (tenders.isEmpty()) {
            throw new AuraHandledException('Tender record not found.');
        }

        Tender__c tender = tenders[0];

        // if (tender.OwnerId == ownerId) {
        //     // Nothing to do - avoid an unnecessary DML/cascade pass.
        //     return;
        // }

        tender.OwnerId = ownerId;

        Database.SaveResult sr = Database.update(tender,new Database.DMLOptions(),AccessLevel.SYSTEM_MODE);

if (!sr.isSuccess()) {
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
    private static void reassignRelatedRecordOwners(Id tenderId, Id newOwnerId) {

        List<String> errors = new List<String>();

        reassignBidders(tenderId, newOwnerId, errors);
        reassignBidderContactDetails(tenderId, newOwnerId, errors);
        reassignTenderAiSummaryJson(tenderId, newOwnerId, errors);
        reassignTenderDocomentDetails(tenderId, newOwnerId, errors);

        if (!errors.isEmpty()) {
            throw new AuraHandledException(
                'Owner was updated on the Tender, but some related records ' +
                'could not be reassigned: ' + String.join(errors, ' | ')
            );
        }
    }

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