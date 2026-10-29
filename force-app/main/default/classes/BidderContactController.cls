public with sharing class BidderContactController {

    @AuraEnabled(cacheable=true)
    public static List<Bidders_Contact_Details__c> getBidderContacts(Id tenderId) {

        return [
            SELECT Id,
                   Name,
                   Email__c
            FROM Bidders_Contact_Details__c
            WHERE Tender__c = :tenderId
            ORDER BY CreatedDate
        ];
    }
}