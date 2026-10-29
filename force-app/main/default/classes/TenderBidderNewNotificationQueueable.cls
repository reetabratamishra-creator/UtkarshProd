public class TenderBidderNewNotificationQueueable implements Queueable {
    
    @TestVisible private static Id testNotifTypeIdOverride = null;
    private static final String NOTIFICATION_TYPE_DEV_NAME = 'Possible_Bidders_Identified';
    private static final String TITLE = 'Possible Bidders Identified';
    private static final String BODY  = 'Possible Bidders identified & bidder opportunities created.';
    
    private static final Set<String> HOD_PROFILES      = new Set<String>{ 'Utkarsh HOD' };
        private static final Set<String> CRM_HEAD_PROFILES = new Set<String>{ 'CRM Head' };
            
            private Set<Id> bidderIds;
    
    public TenderBidderNewNotificationQueueable(Set<Id> bidderIds) {
        this.bidderIds = bidderIds;
    }
    
    public void execute(QueueableContext qc) {
        
        try {
            
            List<Bidders__c> bidders = [
                SELECT Id, Tender__c
                FROM Bidders__c
                WHERE Id IN :bidderIds
            ];
            if (bidders.isEmpty()) {
                return;
            }
            
            Set<Id> tenderIds = new Set<Id>();
            for (Bidders__c b : bidders) {
                if (b.Tender__c != null) {
                    tenderIds.add(b.Tender__c);
                }
            }
            if (tenderIds.isEmpty()) {
                return;
            }
            
            Map<Id, Tender__c> tenderById = new Map<Id, Tender__c>(
                [SELECT Id, Department_Name__c, OwnerId FROM Tender__c WHERE Id IN :tenderIds]
            );
            
            List<User> roleUsers = new List<User>();
            try {
                roleUsers = [
                    SELECT Id, Departments__c, Profile.Name
                    FROM User
                    WHERE IsActive = TRUE
                    AND Departments__c != NULL
                    AND Profile.Name IN ('Utkarsh HOD', 'CRM Head')
                    WITH SYSTEM_MODE
                ];
            } catch (Exception userQueryEx) {
                System.debug(LoggingLevel.ERROR,
                             '[TenderBidderNewNotificationQueueable] Failed to query HOD/CRM Head users: '
                             + userQueryEx.getMessage());
            }
            
            Map<String, Set<String>> hodByDept = new Map<String, Set<String>>();
            Map<String, Set<String>> crmHeadByDept = new Map<String, Set<String>>();
            
            for (User usr : roleUsers) {
                if (String.isBlank(usr.Departments__c)) {
                    continue;
                }
                for (String d : usr.Departments__c.split(';')) {
                    String dept = d.trim();
                    if (String.isBlank(dept)) {
                        continue;
                    }
                    if (HOD_PROFILES.contains(usr.Profile.Name)) {
                        if (!hodByDept.containsKey(dept)) {
                            hodByDept.put(dept, new Set<String>());
                        }
                        hodByDept.get(dept).add(usr.Id);
                    } else if (CRM_HEAD_PROFILES.contains(usr.Profile.Name)) {
                        if (!crmHeadByDept.containsKey(dept)) {
                            crmHeadByDept.put(dept, new Set<String>());
                        }
                        crmHeadByDept.get(dept).add(usr.Id);
                    }
                }
            }
            
            CustomNotificationType notifType;
            try {
                notifType = [
                    SELECT Id FROM CustomNotificationType
                    WHERE DeveloperName = :NOTIFICATION_TYPE_DEV_NAME
                    LIMIT 1
                ];
            } catch (Exception typeEx) {
                System.debug(LoggingLevel.ERROR,
                             '[TenderBidderNewNotificationQueueable] CustomNotificationType "'
                             + NOTIFICATION_TYPE_DEV_NAME + '" not found/configured: ' + typeEx.getMessage());
                return;
            }
            // Resolve the CustomNotificationType Id. In test context, allow a
            // TestVisible override so unit tests can exercise the recipient
            // building + sendNotification logic below without depending on a
            // CustomNotificationType record existing in the test org (custom
            // notification types are metadata that may not be deployed/seeded
            // in every test context).
            Id notifTypeId;
            if (Test.isRunningTest() && testNotifTypeIdOverride != null) {
                notifTypeId = testNotifTypeIdOverride;
            } else {
                try {
                     notifType = [
                        SELECT Id FROM CustomNotificationType
                        WHERE DeveloperName = :NOTIFICATION_TYPE_DEV_NAME
                        LIMIT 1
                    ];
                    notifTypeId = notifType.Id;
                } catch (Exception typeEx) {
                    System.debug(LoggingLevel.ERROR,
                                 '[TenderBidderNewNotificationQueueable] CustomNotificationType "'
                                 + NOTIFICATION_TYPE_DEV_NAME + '" not found/configured: ' + typeEx.getMessage());
                    return;
                }
            }
            
            
            for (Bidders__c b : bidders) {
                
                Tender__c parent = tenderById.get(b.Tender__c);
                if (parent == null) {
                    continue;
                }
                
                String dept = String.isNotBlank(parent.Department_Name__c)
                    ? TenderDepartmentUtilForNotification.normalizeDept(parent.Department_Name__c)
                    : null;
                
                // Same body for Tender User, Dept HOD, and CRM Head - combine into one recipient set.
                Set<String> recipients = new Set<String>();
                
                if (dept != null) {
                    if (hodByDept.containsKey(dept)) {
                        recipients.addAll(hodByDept.get(dept));
                    }
                    if (crmHeadByDept.containsKey(dept)) {
                        recipients.addAll(crmHeadByDept.get(dept));
                    }
                }
                if (parent.OwnerId != null) {
                    recipients.add(parent.OwnerId);
                }
                
                if (!recipients.isEmpty()) {
                    sendNotification(notifType.Id, b.Id, recipients);
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                         '[TenderBidderNewNotificationQueueable] Unexpected failure: '
                         + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    private void sendNotification(Id notifTypeId, Id targetBidderId, Set<String> recipientIds) {
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(TITLE);
            notification.setBody(BODY);
            notification.setNotificationTypeId(notifTypeId);
            notification.setTargetId(targetBidderId);
            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                         '[TenderBidderNewNotificationQueueable] Send failed for Bidder '
                         + targetBidderId + ': ' + e.getMessage());
        }
    }
}