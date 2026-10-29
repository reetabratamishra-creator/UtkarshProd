public class OpportunityNegotiationBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, StageName, CloseDate
            FROM Opportunity
            WHERE StageName = 'Negotiation'
            AND CloseDate < :today
        ]);
    }
  
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        // Collect all unique owner IDs from this batch chunk
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : scope) {
            ownerIds.add(opp.OwnerId);
        }
      
        // Get Custom Notification Type — query once per execute chunk
        CustomNotificationType notifType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Opportunity_Negotiation_Alert'
            LIMIT 1
        ];
      
        // Build one Messaging.CustomNotification per Opportunity
        List<Messaging.CustomNotification> notifications = new List<Messaging.CustomNotification>();
      
        for (Opportunity opp : scope) {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notifType.Id);
            notification.setTargetId(opp.Id);
            notification.setTitle('Overdue Opportunity');
            notification.setBody(
                'Opportunity "' + opp.Name + '" has passed its closure Date ' +
                '(' + opp.CloseDate.format() + '). ' +
                'Kindly take action on this opportunity.'
            );
            notification.setSenderId(UserInfo.getUserId());
            notification.send(new Set<String>{ opp.OwnerId });
        }
    }
  
    public void finish(Database.BatchableContext bc) {
        System.debug('OpportunityNegotiationBatch completed successfully.');
    }

    // ================== ADD ONLY THIS METHOD ==================
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new OpportunityNegotiationBatch(), 200);
    }
}