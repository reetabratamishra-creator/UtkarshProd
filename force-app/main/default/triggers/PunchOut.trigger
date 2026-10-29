trigger PunchOut on User_Punch_State__c (after update) {

    
    // metadata check for enable
    Trigger_Enable__mdt control = Trigger_Enable__mdt.getInstance('PunchOut_Trigger');
        if (control == null || !control.IsEnable__c) return;
    
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        List<User_Punch_State__c> outRecords = new List<User_Punch_State__c>();

        for (User_Punch_State__c rec : Trigger.new) {
            User_Punch_State__c oldRec = Trigger.oldMap.get(rec.Id);
            if (rec.Current_Status__c == 'Out' && oldRec.Current_Status__c != 'Out') {
                outRecords.add(rec);
            }
        }

        if (!outRecords.isEmpty()) {
            PunchOutHandler.calculateDistance(outRecords);
        }
    }
}