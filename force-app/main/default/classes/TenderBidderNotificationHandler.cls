public class TenderBidderNotificationHandler {

    @TestVisible private static Boolean bypassMetadataCheck = false;

    public static void notifyNewBidders(List<Bidders__c> newBidders) {
        if (newBidders == null || newBidders.isEmpty()) {
            return;
        }
        try {
            if (!bypassMetadataCheck) {
                Tender_Trigger_Controll__mdt setting =
                    Tender_Trigger_Controll__mdt.getInstance('Tender_Bidder_Share_Trigger');
                if (setting == null || setting.Push_Notification_For_Bidder__c != true) {
                    return; // switch off - do nothing
                }
            }
            Set<Id> bidderIds = new Set<Id>();
            for (Bidders__c b : newBidders) {
                if (b.Tender__c != null) {
                    bidderIds.add(b.Id);
                }
            }
            if (bidderIds.isEmpty()) {
                return;
            }
            System.enqueueJob(new TenderBidderNewNotificationQueueable(bidderIds));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[TenderBidderNotificationHandler] Failed to queue notifications: '
                + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}