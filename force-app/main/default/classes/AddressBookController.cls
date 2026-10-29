public with sharing class AddressBookController {

    @AuraEnabled(cacheable=true)
    public static List<Address_Book__c> getAddressBooks(Id recordId) {

        
        List<Opportunity_Address_Junc__c> junctions = [
            SELECT Id,
                   Address_Book__c,
                   Address_Book__r.Id,
                   Address_Book__r.Name,
                   Address_Book__r.Account__c,
                   Address_Book__r.Country__c,
                   Address_Book__r.State__c,
                   Address_Book__r.City__c,
                   Address_Book__r.Street__c,
                   Address_Book__r.PIN__c,
                   Address_Book__r.Zone__c
            FROM Opportunity_Address_Junc__c
            WHERE Opportunity__c = :recordId
            AND Address_Book__c != null
        ];

       
        Set<Id> addressBookIds = new Set<Id>();
        for (Opportunity_Address_Junc__c junc : junctions) {
            addressBookIds.add(junc.Address_Book__c);
        }

        if (addressBookIds.isEmpty()) {
            return new List<Address_Book__c>();
        }

        
        return [
            SELECT Id, Name, Account__c, Country__c, State__c, City__c,
                   Street__c, PIN__c, Zone__c
            FROM Address_Book__c
            WHERE Id IN :addressBookIds
            ORDER BY Name
        ];
    }
}