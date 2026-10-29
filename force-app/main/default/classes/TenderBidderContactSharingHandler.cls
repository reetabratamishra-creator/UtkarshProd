/*
================================================================================
CLASS: TenderBidderContactSharingHandler
--------------------------------------------------------------------------------
VISIBILITY:
[System Administrator + Utkarsh Admin => edit
Utkarsh HOD ( department wise ) + CRM Head => edit
Utkarsh Tender => view]

KILL-SWITCH:
Controlled via Tender_Trigger_Controll__mdt.Is_Bidder_Contact_Share_Active__c
(a NEW field on the existing metadata type, independent of the other three
share triggers, so each can be toggled separately).

FIX NOTE:
Switched from querying User.Profile.Name directly to querying User.ProfileId
and resolving names via a separate Profile query. Salesforce blocks the
User -> Profile relationship traversal when the running/triggering context
includes a Community/Experience Cloud (portal-licensed) user, even inside
a system-context trigger. This threw:
"System.QueryException: No such relation 'Profile' on entity 'User'"
whenever a portal-licensed user (e.g. "Utkarsh Tender" persona) triggered
this handler.
================================================================================
*/
/*public with sharing class TenderBidderContactSharingHandler {

    public static void shareContacts(List<Bidders_Contact_Details__c> contacts) {

        if (contacts == null || contacts.isEmpty()) return;

        // Collect parent Bidder Ids - Department lives two levels up, via Bidders__c -> Tender__c.
        Set<Id> bidderIds = new Set<Id>();
        for (Bidders_Contact_Details__c c : contacts) {
            if (c.Bidders__c != null) {
                bidderIds.add(c.Bidders__c);
            }
        }
        if (bidderIds.isEmpty()) return;

        // Bulk fetch parent Bidders with their Tender's Department, in one relationship query.
        Map<Id, Bidders__c> bidderById = new Map<Id, Bidders__c>(
            [SELECT Id, Tender__r.Department_Name__c FROM Bidders__c WHERE Id IN :bidderIds]
        );

        Map<String, String> deptMap = getDeptNormalizationMap();

        // Group this batch's contacts by their grandparent tender's normalized department.
        Map<String, List<Id>> deptToContactIds = new Map<String, List<Id>>();
        for (Bidders_Contact_Details__c c : contacts) {
            Bidders__c parentBidder = bidderById.get(c.Bidders__c);
            if (parentBidder == null || parentBidder.Tender__r == null
                || parentBidder.Tender__r.Department_Name__c == null) continue;

            String dept = normalizeDept(parentBidder.Tender__r.Department_Name__c, deptMap);
            if (!deptToContactIds.containsKey(dept)) {
                deptToContactIds.put(dept, new List<Id>());
            }
            deptToContactIds.get(dept).add(c.Id);
        }
        if (deptToContactIds.isEmpty()) return;

        // Users with a Department set. NOTE: Profile.Name removed from this query -
        // that relationship is not queryable when a portal-licensed user is in the
        // triggering context. We fetch ProfileId here and resolve names separately below.
        List<User> users = [
            SELECT Id, Departments__c, ProfileId, Tender_Access_User__c
            FROM User
            WHERE IsActive = TRUE
            AND Departments__c != NULL
        ];

        // Resolve Profile names in a separate query - Profile is a top-level object
        // and is not subject to the same User->Profile relationship restriction.
        Set<Id> profileIds = new Set<Id>();
        for (User usr : users) {
            if (usr.ProfileId != null) {
                profileIds.add(usr.ProfileId);
            }
        }
        Map<Id, Profile> profileById = new Map<Id, Profile>(
            [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]
        );

        // Group users by department, excluding Admin profiles (already full access).
        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
        for (User usr : users) {
            String profileName = getProfileName(usr, profileById);

            if (profileName == 'System Administrator' ||
                profileName == 'Utkarsh Admin') {
                continue;
            }
            for (String d : usr.Departments__c.split(';')) {
                String dept = d.trim();
                if (!deptUsersMap.containsKey(dept)) {
                    deptUsersMap.put(dept, new List<User>());
                }
                deptUsersMap.get(dept).add(usr);
            }
        }

        // Build share records - no old-share cleanup needed, this only ever runs on insert.
        List<Bidders_Contact_Details__Share> shareRecords = new List<Bidders_Contact_Details__Share>();
        Set<String> uniqueKeys = new Set<String>();

        for (String dept : deptToContactIds.keySet()) {
            if (!deptUsersMap.containsKey(dept)) continue;

            for (Id contactId : deptToContactIds.get(dept)) {
                for (User usr : deptUsersMap.get(dept)) {

                    String profileName = getProfileName(usr, profileById);
                    String accessLevel = resolveAccessLevel(usr, profileName);
                    if (accessLevel == null) continue;

                    String key = contactId + '-' + usr.Id;
                    if (uniqueKeys.contains(key)) continue;
                    uniqueKeys.add(key);

                    shareRecords.add(createShare(contactId, usr.Id, accessLevel));
                }
            }
        }

        if (!shareRecords.isEmpty()) {
            Database.insert(shareRecords, false);
        }
    }

    // Same access-level rule as Tender__c / Document / Bidder sharing, kept in sync intentionally.
    private static String resolveAccessLevel(User usr, String profileName) {
        if (profileName == 'Utkarsh HOD' || profileName == 'CRM Head') {
            return 'Edit';
        }
        if (profileName == 'Utkarsh Tender') {
            return 'Read';
        }
        if (usr.Tender_Access_User__c == true) {
            return 'Read';
        }
        return null;
    }

    // Small helper to safely resolve a User's Profile Name from the pre-built map.
    private static String getProfileName(User usr, Map<Id, Profile> profileById) {
        if (usr.ProfileId == null || !profileById.containsKey(usr.ProfileId)) {
            return null;
        }
        return profileById.get(usr.ProfileId).Name;
    }

    private static String normalizeDept(String rawDept, Map<String, String> deptMap) {
        String key = rawDept.trim().toUpperCase();
        return deptMap.containsKey(key) ? deptMap.get(key) : rawDept.trim();
    }

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

    private static Bidders_Contact_Details__Share createShare(Id recordId, Id userId, String accessLevel) {
        Bidders_Contact_Details__Share share = new Bidders_Contact_Details__Share();
        share.ParentId = recordId;
        share.UserOrGroupId = userId;
        share.AccessLevel = accessLevel;
        share.RowCause = Schema.Bidders_Contact_Details__Share.RowCause.Manual;
        return share;
    }
}*/
/*
================================================================================
CLASS: TenderBidderContactSharingHandler
--------------------------------------------------------------------------------
VISIBILITY:
[System Administrator + Utkarsh Admin => edit
Utkarsh HOD ( department wise ) + CRM Head => edit
Utkarsh Tender => view]

KILL-SWITCH:
Controlled via Tender_Trigger_Controll__mdt.Is_Bidder_Contact_Share_Active__c
(a NEW field on the existing metadata type, independent of the other three
share triggers, so each can be toggled separately).

FIX NOTE:
This class now runs its User/Profile lookup logic inside a Queueable
(execute()) instead of synchronously inside the after-insert trigger.

Reason: Salesforce blocks querying most fields on the User object
(including Profile.Name AND ProfileId) when the triggering transaction
was started by a Community/Experience Cloud (portal-licensed) user -
e.g. the "Utkarsh Tender" persona clicking "Fetch Contact Details".
This is a hard platform restriction, NOT a sharing/CRUD/FLS issue, so
"with sharing" vs "without sharing" makes no difference here.

Running this logic in a Queueable moves it into a fresh, decoupled
system-context transaction where these User field restrictions do not
apply, so the Profile lookups work correctly.
================================================================================
*/
public with sharing class TenderBidderContactSharingHandler implements Queueable {

    private List<Id> contactIds;

    public TenderBidderContactSharingHandler(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    // Called from the trigger. Just enqueues the async job - all the real
    // work now happens in execute() below, in a clean async context.
    public static void shareContacts(List<Bidders_Contact_Details__c> contacts) {
        if (contacts == null || contacts.isEmpty()) return;

        List<Id> ids = new List<Id>();
        for (Bidders_Contact_Details__c c : contacts) {
            ids.add(c.Id);
        }
        System.enqueueJob(new TenderBidderContactSharingHandler(ids));
    }

    public void execute(QueueableContext qc) {
        if (contactIds == null || contactIds.isEmpty()) return;

        // Re-query the contacts fresh inside the async context.
        List<Bidders_Contact_Details__c> contacts = [
            SELECT Id, Bidders__c FROM Bidders_Contact_Details__c
            WHERE Id IN :contactIds
        ];
        if (contacts.isEmpty()) return;

        // Collect parent Bidder Ids - Department lives two levels up, via Bidders__c -> Tender__c.
        Set<Id> bidderIds = new Set<Id>();
        for (Bidders_Contact_Details__c c : contacts) {
            if (c.Bidders__c != null) {
                bidderIds.add(c.Bidders__c);
            }
        }
        if (bidderIds.isEmpty()) return;

        // Bulk fetch parent Bidders with their Tender's Department, in one relationship query.
        Map<Id, Bidders__c> bidderById = new Map<Id, Bidders__c>(
            [SELECT Id, Tender__r.Department_Name__c FROM Bidders__c WHERE Id IN :bidderIds]
        );

        Map<String, String> deptMap = getDeptNormalizationMap();

        // Group this batch's contacts by their grandparent tender's normalized department.
        Map<String, List<Id>> deptToContactIds = new Map<String, List<Id>>();
        for (Bidders_Contact_Details__c c : contacts) {
            Bidders__c parentBidder = bidderById.get(c.Bidders__c);
            if (parentBidder == null || parentBidder.Tender__r == null
                || parentBidder.Tender__r.Department_Name__c == null) continue;

            String dept = normalizeDept(parentBidder.Tender__r.Department_Name__c, deptMap);
            if (!deptToContactIds.containsKey(dept)) {
                deptToContactIds.put(dept, new List<Id>());
            }
            deptToContactIds.get(dept).add(c.Id);
        }
        if (deptToContactIds.isEmpty()) return;

        // Safe to query ProfileId / Profile here - this runs in an async
        // system context, not the restricted portal-user transaction.
        List<User> users = [
            SELECT Id, Departments__c, ProfileId, Tender_Access_User__c
            FROM User
            WHERE IsActive = TRUE
            AND Departments__c != NULL
        ];

        Set<Id> profileIds = new Set<Id>();
        for (User usr : users) {
            if (usr.ProfileId != null) profileIds.add(usr.ProfileId);
        }
        Map<Id, Profile> profileById = new Map<Id, Profile>(
            [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]
        );

        // Group users by department, excluding Admin profiles (already full access).
        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
        for (User usr : users) {
            String profileName = getProfileName(usr, profileById);
            if (profileName == 'System Administrator' || profileName == 'Utkarsh Admin') {
                continue;
            }
            for (String d : usr.Departments__c.split(';')) {
                String dept = d.trim();
                if (!deptUsersMap.containsKey(dept)) {
                    deptUsersMap.put(dept, new List<User>());
                }
                deptUsersMap.get(dept).add(usr);
            }
        }

        // Build share records - no old-share cleanup needed, this only ever runs on insert.
        List<Bidders_Contact_Details__Share> shareRecords = new List<Bidders_Contact_Details__Share>();
        Set<String> uniqueKeys = new Set<String>();

        for (String dept : deptToContactIds.keySet()) {
            if (!deptUsersMap.containsKey(dept)) continue;

            for (Id contactId : deptToContactIds.get(dept)) {
                for (User usr : deptUsersMap.get(dept)) {

                    String profileName = getProfileName(usr, profileById);
                    String accessLevel = resolveAccessLevel(usr, profileName);
                    if (accessLevel == null) continue;

                    String key = contactId + '-' + usr.Id;
                    if (uniqueKeys.contains(key)) continue;
                    uniqueKeys.add(key);

                    shareRecords.add(createShare(contactId, usr.Id, accessLevel));
                }
            }
        }

        if (!shareRecords.isEmpty()) {
            Database.insert(shareRecords, false);
        }
    }

    // Same access-level rule as Tender__c / Document / Bidder sharing, kept in sync intentionally.
    private static String resolveAccessLevel(User usr, String profileName) {
        if (profileName == 'Utkarsh HOD' || profileName == 'CRM Head') {
            return 'Edit';
        }
        if (profileName == 'Utkarsh Tender') {
            return 'Read';
        }
        if (usr.Tender_Access_User__c == true) {
            return 'Read';
        }
        return null;
    }

    // Small helper to safely resolve a User's Profile Name from the pre-built map.
    private static String getProfileName(User usr, Map<Id, Profile> profileById) {
        if (usr.ProfileId == null || !profileById.containsKey(usr.ProfileId)) {
            return null;
        }
        return profileById.get(usr.ProfileId).Name;
    }

    private static String normalizeDept(String rawDept, Map<String, String> deptMap) {
        String key = rawDept.trim().toUpperCase();
        return deptMap.containsKey(key) ? deptMap.get(key) : rawDept.trim();
    }

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

    private static Bidders_Contact_Details__Share createShare(Id recordId, Id userId, String accessLevel) {
        Bidders_Contact_Details__Share share = new Bidders_Contact_Details__Share();
        share.ParentId = recordId;
        share.UserOrGroupId = userId;
        share.AccessLevel = accessLevel;
        share.RowCause = Schema.Bidders_Contact_Details__Share.RowCause.Manual;
        return share;
    }
}