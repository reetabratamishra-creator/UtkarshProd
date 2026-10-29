trigger TenderBidderShareTrigger on Bidders__c (after insert) {
    // Independent toggle - new field on the same mdt type used by the other share triggers.
    Tender_Trigger_Controll__mdt setting =
        Tender_Trigger_Controll__mdt.getInstance('Tender_Share_Trigger');

    // Push notification: Tender User, Dept HOD, CRM Head — "Possible Bidders Identified"
    if (setting != null && setting.Push_Notification_For_Bidder__c) {
        TenderBidderNotificationHandler.notifyNewBidders(Trigger.new);
    }
    
    if (setting != null && setting.Is_Bidder_Share_Active__c) {
        TenderBidderSharingHandler.shareBidders(Trigger.new);
    }
}