/*

Owner - Ayantika
CLASS: TenderNewTenderNotificationQueueable

Handles push notifications for newly created Tenders.
Takes the Tender IDs, document details, Product Name, and chunk size as input.
Fetches the related Tender records and gets their Department and Owner.
Normalizes the Tender Department using TenderDepartmentUtilForNotification.
Finds active HOD and CRM Head users based on their assigned departments.
Creates department-wise recipient lists for HOD and CRM Head users.
Finds the configured Custom Notification Type New_Tender_Alert.
Sends a notification to the HOD/CRM Head of the Tender's department.
Sends a separate notification to the Tender Owner if the Owner is not already included in the department recipients, avoiding duplicate notifications.
Uses the Tender record as the target record of the notification.
If notification processing fails, the error is handled so that the document insertion process is not stopped.
After the notification attempt, it queues TenderDocumentInsertQueueable to insert the Tender documents.
Overall, this class sends new Tender notifications to the relevant department HOD/CRM Head and Tender Owner, then starts the document insertion process.

*/
public class TenderNewTenderNotificationQueueable implements Queueable {
    
    private static final String NOTIFICATION_TYPE_DEV_NAME = 'New_Tender_Alert';
    private static final String TITLE = 'New Tender Alert';
    private static final String BODY_DEPT_ROLE  = 'A new tender relevant to your department has been identified.';
    private static final String BODY_OWNER_ROLE = 'A new tender relevant to your department has been identified. Please review.';
    
    private static final Set<String> HOD_PROFILES      = new Set<String>{ 'Utkarsh HOD' };
        private static final Set<String> CRM_HEAD_PROFILES = new Set<String>{ 'CRM Head' };
            
            private Set<Id> tenderIds;
    private List<Tender_Docoment_Details__c> docDetailsToInsert;
    private String productName;
    private Integer chunkSize;
    
    // Single active constructor - takes the tender Ids to notify about,
    // plus the document rows (and their chunking info) that should be
    // inserted AFTER the notification attempt finishes. docDetailsToInsert,
    // productName, and chunkSize can be null/blank/0 for callers that have
    // no documents to insert (e.g. TenderNotificationHandler's trigger path).
    public TenderNewTenderNotificationQueueable(
        Set<Id> tenderIds,
        List<Tender_Docoment_Details__c> docDetailsToInsert,
        String productName,
        Integer chunkSize
    ) {
        this.tenderIds = tenderIds;
        this.docDetailsToInsert = docDetailsToInsert;
        this.productName = productName;
        this.chunkSize = chunkSize;
    }
    
    // Sends the "new tender" notification to the relevant HOD / CRM Head /
    // Owner users for each tender, and then - regardless of how the
    // notification attempt went (success, partial failure, or no
    // recipients found) - enqueues the document insert job in the
    // finally block. This guarantees the order the business requires:
    // tender created -> notification attempted -> document insert queued.
    public void execute(QueueableContext qc) {
        
        try {
            
            List<Tender__c> tenders = [
                SELECT Id, Department_Name__c, OwnerId
                FROM Tender__c
                WHERE Id IN :tenderIds
            ];
            
            // Only run the notification logic if there are tenders to notify
            // about. Previously this used an early "return", which meant
            // document insert never got queued if this list was empty -
            // now we just skip the block below and let the finally block
            // still queue the document insert.
            if (!tenders.isEmpty()) {
                
                // Map each tender to its normalized department (used to find
                // the right HOD / CRM Head recipients below).
                Map<Id, String> tenderDeptMap = new Map<Id, String>();
                for (Tender__c t : tenders) {
                    if (String.isNotBlank(t.Department_Name__c)) {
                        tenderDeptMap.put(t.Id, TenderDepartmentUtilForNotification.normalizeDept(t.Department_Name__c));
                    }
                }
                
                // Query active HOD / CRM Head users who have at least one
                // department assigned. If this query fails for any reason,
                // we log it and just continue with an empty roleUsers list -
                // this must never block the document insert that follows.
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
                                 '[TenderNewTenderNotificationQueueable] Failed to query HOD/CRM Head users: '
                                 + userQueryEx.getMessage());
                }
                
                // Build department -> recipient-user-Id-set maps, split by
                // role (HOD vs CRM Head), so each tender's department can be
                // looked up directly below. Set<Id> is NOT auto-compatible
                // with Set<String>.addAll(), so recipient Ids are collected
                // directly as Set<String> here.
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
                
                // Look up the CustomNotificationType record needed to send
                // notifications. If it's missing/misconfigured, we no longer
                // "return" out of the whole method - we just skip sending
                // notifications (notifType stays null) and still let the
                // finally block queue the document insert below.
                CustomNotificationType notifType;
                try {
                    notifType = [
                        SELECT Id FROM CustomNotificationType
                        WHERE DeveloperName = :NOTIFICATION_TYPE_DEV_NAME
                        LIMIT 1
                    ];
                } catch (Exception typeEx) {
                    System.debug(LoggingLevel.ERROR,
                                 '[TenderNewTenderNotificationQueueable] CustomNotificationType "'
                                 + NOTIFICATION_TYPE_DEV_NAME + '" not found/configured: ' + typeEx.getMessage());
                    notifType = null;
                }
                
                // Only attempt to send notifications if the CustomNotificationType
                // was found successfully.
                if (notifType != null) {
                    for (Tender__c t : tenders) {
                        
                        String dept = tenderDeptMap.get(t.Id);
                        
                        // Recipients who get notified because they are the
                        // HOD/CRM Head of this tender's department.
                        Set<String> deptRoleRecipients = new Set<String>();
                        if (dept != null) {
                            if (hodByDept.containsKey(dept)) {
                                deptRoleRecipients.addAll(hodByDept.get(dept));
                            }
                            if (crmHeadByDept.containsKey(dept)) {
                                deptRoleRecipients.addAll(crmHeadByDept.get(dept));
                            }
                        }
                        
                        // The tender's Owner also gets notified, but only if
                        // they aren't already covered by the department-role
                        // recipients above (avoids sending a duplicate
                        // notification to the same user with a different body).
                        Set<String> ownerRecipients = new Set<String>();
                        if (t.OwnerId != null) {
                            ownerRecipients.add(t.OwnerId);
                        }
                        ownerRecipients.removeAll(deptRoleRecipients);
                        
                        if (!deptRoleRecipients.isEmpty()) {
                            sendNotification(notifType.Id, t.Id, BODY_DEPT_ROLE, deptRoleRecipients);
                        }
                        if (!ownerRecipients.isEmpty()) {
                            sendNotification(notifType.Id, t.Id, BODY_OWNER_ROLE, ownerRecipients);
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            // Any unexpected failure in the notification logic above is
            // logged, but must never prevent the document insert queued
            // in the finally block below.
            System.debug(LoggingLevel.ERROR,
                         '[TenderNewTenderNotificationQueueable] Unexpected failure: '
                         + e.getMessage() + '\n' + e.getStackTraceString());
        } finally {
            // This ALWAYS runs after the notification logic above, no matter
            // how that block exited (success, exception, no tenders found,
            // or CustomNotificationType missing). This guarantees the
            // required order: tender created -> notification attempted ->
            // document insert queued.
            if (
                docDetailsToInsert != null &&
                !docDetailsToInsert.isEmpty() &&
                !Test.isRunningTest()
            ) {
                System.enqueueJob(
                    new TenderDocumentInsertQueueable(
                        docDetailsToInsert, 0, chunkSize, productName
                    )
                );
            }
        }
    }
    
    // Sends one Custom Notification to a set of recipient user Ids, targeting
    // the given Tender__c record. Wrapped in try/catch so a failure sending
    // to one tender never blocks notifications for the rest of the batch.
    private void sendNotification(Id notifTypeId, Id targetTenderId, String body, Set<String> recipientIds) {
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(TITLE);
            notification.setBody(body);
            notification.setNotificationTypeId(notifTypeId);
            notification.setTargetId(targetTenderId);
            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                         '[TenderNewTenderNotificationQueueable] Send failed for Tender '
                         + targetTenderId + ': ' + e.getMessage());
        }
    }
}