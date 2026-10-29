trigger AccountOwnerTrigger on Account (before insert) {
    // Retrieve System Admin user
    /*User adminUser = [
        SELECT Id 
        FROM User 
        WHERE Profile.Name = 'System Administrator' 
        AND IsActive = true 
        LIMIT 1
    ];
    for (Account acc : Trigger.new) {
        acc.OwnerId = adminUser.Id;
    }*/
    
     Default_Owner__mdt config = Default_Owner__mdt.getInstance('Account_Owner');
    
    if (config != null && String.isNotBlank(config.Account_Owners__c)) {
        
        String ownerName = config.Account_Owners__c;
        
        List<User> users = [
            SELECT Id 
            FROM User 
            WHERE Name = :ownerName 
            AND IsActive = true 
            LIMIT 1
        ];
        
        if (!users.isEmpty()) {
            Id ownerId = users[0].Id;
            for (Account acc : Trigger.new) {
                acc.OwnerId = ownerId;
            }
        }
    }
    
 
}