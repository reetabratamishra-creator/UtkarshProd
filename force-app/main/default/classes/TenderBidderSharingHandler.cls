/*
================================================================================
CLASS: TenderBidderSharingHandler
--------------------------------------------------------------------------------
VISIBILITY:
[System Administrator + Utkarsh Admin => edit
Utkarsh HOD ( department wise ) + CRM Head => edit
Utkarsh Tender => view]

KILL-SWITCH:
Controlled via Tender_Trigger_Controll__mdt.Is_Bidder_Share_Active__c
(a NEW field on the existing metadata type, independent of
Tender_Share_Trigger's Is_Active__c and the document handler's
Is_Document_Share_Active__c, so each can be toggled separately).
================================================================================
*/
public with sharing class TenderBidderSharingHandler {

    public static void shareBidders(List<Bidders__c> bidders) {

        if (bidders == null || bidders.isEmpty()) return;

        // Collect parent Tender Ids - Department lives on the parent, not the bidder.
        Set<Id> tenderIds = new Set<Id>();
        for (Bidders__c b : bidders) {
            if (b.Tender__c != null) {
                tenderIds.add(b.Tender__c);
            }
        }
        if (tenderIds.isEmpty()) return;

        // Bulk fetch parent Tenders for their Department (drives WHO gets access).
        Map<Id, Tender__c> tenderById = new Map<Id, Tender__c>(
            [SELECT Id, Department_Name__c FROM Tender__c WHERE Id IN :tenderIds]
        );

        Map<String, String> deptMap = getDeptNormalizationMap();

        // Group this batch's bidders by their parent tender's normalized department.
        Map<String, List<Id>> deptToBidderIds = new Map<String, List<Id>>();
        for (Bidders__c b : bidders) {
            Tender__c parent = tenderById.get(b.Tender__c);
            if (parent == null || parent.Department_Name__c == null) continue;

            String dept = normalizeDept(parent.Department_Name__c, deptMap);
            if (!deptToBidderIds.containsKey(dept)) {
                deptToBidderIds.put(dept, new List<Id>());
            }
            deptToBidderIds.get(dept).add(b.Id);
        }
        if (deptToBidderIds.isEmpty()) return;

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
        List<Bidders__Share> shareRecords = new List<Bidders__Share>();
        Set<String> uniqueKeys = new Set<String>();

        for (String dept : deptToBidderIds.keySet()) {
            if (!deptUsersMap.containsKey(dept)) continue;

            for (Id bidderId : deptToBidderIds.get(dept)) {
                for (User usr : deptUsersMap.get(dept)) {

                    String accessLevel = resolveAccessLevel(usr);
                    if (accessLevel == null) continue;

                    String key = bidderId + '-' + usr.Id;
                    if (uniqueKeys.contains(key)) continue;
                    uniqueKeys.add(key);

                    shareRecords.add(createShare(bidderId, usr.Id, accessLevel));
                }
            }
        }

        if (!shareRecords.isEmpty()) {
            Database.insert(shareRecords, false);
        }
    }

    // Same access-level rule as Tender__c / Document sharing, kept in sync intentionally.
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

    private static Bidders__Share createShare(Id recordId, Id userId, String accessLevel) {
        Bidders__Share share = new Bidders__Share();
        share.ParentId = recordId;
        share.UserOrGroupId = userId;
        share.AccessLevel = accessLevel;
        share.RowCause = Schema.Bidders__Share.RowCause.Manual;
        return share;
    }
}