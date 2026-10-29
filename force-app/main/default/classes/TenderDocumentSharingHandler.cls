/*
================================================================================
CLASS: TenderDocumentSharingHandler
--------------------------------------------------------------------------------
[System Administrator + Utkarsh Admin => edit
Utkarsh HOD ( department wise ) + CRM Head => edit
Utkarsh Tender => view]

KILL-SWITCH:
Controlled via Tender_Trigger_Controll__mdt.Is_Document_Share_Active__c
(a NEW field on the existing metadata type, kept separate from
Tender_Share_Trigger's Is_Active__c so this can be toggled independently).
================================================================================
*/
public with sharing class TenderDocumentSharingHandler {

    public static void shareDocuments(List<Tender_Docoment_Details__c> docs) {

        if (docs == null || docs.isEmpty()) return;

        // Collect parent Tender Ids - Department/Owner live on the parent, not the document.
        Set<Id> tenderIds = new Set<Id>();
        for (Tender_Docoment_Details__c d : docs) {
            if (d.Tender__c != null) {
                tenderIds.add(d.Tender__c);
            }
        }
        if (tenderIds.isEmpty()) return;

        // Bulk fetch parent Tenders for their Department (drives WHO gets access).
        Map<Id, Tender__c> tenderById = new Map<Id, Tender__c>(
            [SELECT Id, Department_Name__c FROM Tender__c WHERE Id IN :tenderIds]
        );

        Map<String, String> deptMap = getDeptNormalizationMap();

        // Group this batch's documents by their parent tender's normalized department.
        Map<String, List<Id>> deptToDocIds = new Map<String, List<Id>>();
        for (Tender_Docoment_Details__c d : docs) {
            Tender__c parent = tenderById.get(d.Tender__c);
            if (parent == null || parent.Department_Name__c == null) continue;

            String dept = normalizeDept(parent.Department_Name__c, deptMap);
            if (!deptToDocIds.containsKey(dept)) {
                deptToDocIds.put(dept, new List<Id>());
            }
            deptToDocIds.get(dept).add(d.Id);
        }
        if (deptToDocIds.isEmpty()) return;

        // Users with a Department set, excluding Admin profiles (already full access).
        List<User> users = [
            SELECT Id, Departments__c, Profile.Name, Tender_Access_User__c
            FROM User
            WHERE IsActive = TRUE
            AND Departments__c != NULL
        ];

        Map<String, List<User>> deptUsersMap = new Map<String, List<User>>();
        for (User usr : users) {
            if (usr.Profile.Name == 'System Administrator' ||
                usr.Profile.Name == 'Utkarsh Admin') {
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
        List<Tender_Docoment_Details__Share> shareRecords = new List<Tender_Docoment_Details__Share>();
        Set<String> uniqueKeys = new Set<String>();

        for (String dept : deptToDocIds.keySet()) {
            if (!deptUsersMap.containsKey(dept)) continue;

            for (Id docId : deptToDocIds.get(dept)) {
                for (User usr : deptUsersMap.get(dept)) {

                    String accessLevel = resolveAccessLevel(usr);
                    if (accessLevel == null) continue;

                    String key = docId + '-' + usr.Id;
                    if (uniqueKeys.contains(key)) continue;
                    uniqueKeys.add(key);

                    shareRecords.add(createShare(docId, usr.Id, accessLevel));
                }
            }
        }

        if (!shareRecords.isEmpty()) {
            Database.insert(shareRecords, false);
        }
    }

    // Same access-level rule as Tender__c sharing, kept in sync intentionally.
    private static String resolveAccessLevel(User usr) {
        if (usr.Profile.Name == 'Utkarsh HOD' || usr.Profile.Name == 'CRM Head') {
            return 'Edit';
        }
        if (usr.Profile.Name == 'Utkarsh Tender') {
            return 'Read';
        }
        if (usr.Tender_Access_User__c == true) {
            return 'Read';
        }
        return null;
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

    private static Tender_Docoment_Details__Share createShare(Id recordId, Id userId, String accessLevel) {
        Tender_Docoment_Details__Share share = new Tender_Docoment_Details__Share();
        share.ParentId = recordId;
        share.UserOrGroupId = userId;
        share.AccessLevel = accessLevel;
        share.RowCause = Schema.Tender_Docoment_Details__Share.RowCause.Manual;
        return share;
    }
}