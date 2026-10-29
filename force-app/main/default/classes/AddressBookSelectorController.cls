public without sharing class AddressBookSelectorController {

    @AuraEnabled(cacheable=true)
    public static List<Address_Book__c> getAddressBooks(Id accountId){

        if(accountId == null){
            return new List<Address_Book__c>();
        }

        return [
            SELECT
                Account__c,City__c,Country__c,CreatedById,CreatedDate,Id,IsDeleted,LastModifiedById,
            	LastModifiedDate,Name,Opportunity__c,PIN__c,
            	Primary_Address__c,State__c,Street__c,SystemModstamp,Type__c,Zone__c 
            FROM Address_Book__c
            WHERE Account__c = :accountId
            WITH SYSTEM_MODE
            ORDER BY Name
            
        ];
    }
}