public without sharing class AddressBookProcessor {

    public class Input {

        @InvocableVariable(required=true)
        public Id leadId;

        @InvocableVariable(required=true)
        public Id accountId;

        @InvocableVariable(required=true)
        public Id contactId;

        @InvocableVariable(required=true)
        public Id opportunityId;

        // Null when a new Address Book should be created
        @InvocableVariable
        public Id selectedAddressBookId;
    }

    @InvocableMethod(label='Process Address Book')
    public static void process(List<Input> inputs) {
        
        System.debug('================ START =================');
        System.debug('Inputs Size : ' + inputs.size());
        System.debug(JSON.serializePretty(inputs));

        if(inputs == null || inputs.isEmpty()){
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        Set<Id> selectedAddressIds = new Set<Id>();      
        Set<Id> accountIds = new Set<Id>();

        for(Input i : inputs){
            if(i.leadId != null){
                leadIds.add(i.leadId);
            }
            if(i.selectedAddressBookId != null){
                selectedAddressIds.add(i.selectedAddressBookId);
            }
            if (i.accountId != null) {
                accountIds.add(i.accountId);
            }
        }

        Map<Id,Lead> leadMap = new Map<Id,Lead>([
            SELECT Id,
                   Street__c,
                   City__c,
                   State__c,
                   Country__c,
                   PIN__c,
                   Zone__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        Map<Id,Address_Book__c> selectedAddressMap = new Map<Id,Address_Book__c>();

        if(!selectedAddressIds.isEmpty()){
            selectedAddressMap = new Map<Id,Address_Book__c>([
                SELECT Id,
                       Name,
                       Street__c,
                       City__c,
                       State__c,
                       Country__c,
                       PIN__c,
                       Zone__c,
                       Type__c,
                       Primary_Address__c
                FROM Address_Book__c
                WHERE Id IN :selectedAddressIds
            ]);
        }
        
        Map<String, Address_Book__c> addressBookMap = new Map<String, Address_Book__c>();
        
        if (!accountIds.isEmpty()) {
            
            for (Address_Book__c ab : [
                SELECT Id,
                Account__c,
                Street__c,
                City__c,
                State__c,
                Country__c,
                PIN__c,
                Zone__c,
                Primary_Address__c,
                Type__c,
                Name
                FROM Address_Book__c
                WHERE Account__c IN :accountIds
            ]) {
                
                String key = buildKey(
                    ab.Account__c,
                    ab.Street__c,
                    ab.City__c,
                    ab.State__c,
                    ab.PIN__c,
                    ab.Country__c,
                    ab.Zone__c
                );
                
                addressBookMap.put(key, ab);
            }
        }
        
        System.debug('=========================');
        System.debug('Address Book Map Size : ' + addressBookMap.size());
        
        for(String key : addressBookMap.keySet()){
            System.debug('Map Key : ' + key);
        }
        
        System.debug('=========================');

        List<Address_Book__c> addressBooksToInsert = new List<Address_Book__c>();
        List<Input> createAddressInputs = new List<Input>();
        
        System.debug('Inputs Size = ' + inputs.size());
        
        for (Input i : inputs) {
            
            if (i.selectedAddressBookId != null) {
                continue;
            }
            
            Lead ld = leadMap.get(i.leadId);
            
            if(ld == null){
                continue;
            }
            
            String key = buildKey(
                i.accountId,
                ld.Street__c,
                ld.City__c,
                ld.State__c,
                ld.PIN__c,
                ld.Country__c,
                ld.Zone__c
            );
            
            System.debug('Lead Key = ' + key);
            System.debug('Map contains key = ' + addressBookMap.containsKey(key));
            
            System.debug('Checking Key : ' + key);
            System.debug('Contains? : ' + addressBookMap.containsKey(key));
            
            if(addressBookMap.containsKey(key)){
                System.debug('Matched Address Book = ' + addressBookMap.get(key).Id);
            }
            
            // Existing Address Book found
            if (addressBookMap.containsKey(key)) {
                i.selectedAddressBookId = addressBookMap.get(key).Id;
                selectedAddressMap.put(
                    i.selectedAddressBookId,
                    addressBookMap.get(key)
                );
                continue;
            }
            
            
            System.debug('Address Book Map Size = ' + addressBookMap.size());

            for(String k : addressBookMap.keySet()){
                System.debug('Existing Key = ' + k);
            }
            
            Address_Book__c ab = new Address_Book__c();
            
            ab.Account__c = i.accountId;
            ab.Street__c  = ld.Street__c;
            ab.City__c    = ld.City__c;
            ab.State__c   = ld.State__c;
            ab.Country__c = ld.Country__c;
            ab.PIN__c     = ld.PIN__c;
            ab.Zone__c    = ld.Zone__c;
            
            // Reserve this key immediately
            addressBookMap.put(key, ab);
            
            addressBooksToInsert.add(ab);
            createAddressInputs.add(i);
            
        }

        if (!addressBooksToInsert.isEmpty()) {
            
            insert addressBooksToInsert;
            
            Integer index = 0;
            
            for (Address_Book__c ab : addressBooksToInsert) {
                
                selectedAddressMap.put(ab.Id, ab);
                
                createAddressInputs[index].selectedAddressBookId = ab.Id;
                
                index++;
            }
        }

        List<Opportunity_Address_Junc__c > junctions = new List<Opportunity_Address_Junc__c >();
        List<Contact> contactsToUpdate = new List<Contact>();

        for(Input i : inputs){

            Address_Book__c ab = selectedAddressMap.get(i.selectedAddressBookId);

            if(ab == null){
                continue;
            }

            junctions.add(new Opportunity_Address_Junc__c (
                Opportunity__c = i.opportunityId,
                Address_Book__c = ab.Id
            ));

            if (i.contactId != null) {
                contactsToUpdate.add(new Contact(
                    Id = i.contactId,
                    Street__c = ab.Street__c,
                    City__c = ab.City__c,
                    State__c = ab.State__c,
                    Country__c = ab.Country__c,
                    PIN__c = ab.PIN__c,
                    Zone__c = ab.Zone__c
                ));
            } else {
                throw new AuraHandledException('Contact is missing in the bidder record!');
            }
        }

        if (!junctions.isEmpty()) {
            Database.insert(junctions, AccessLevel.SYSTEM_MODE);
        }
        
        if (!contactsToUpdate.isEmpty()) {
            Database.update(contactsToUpdate, AccessLevel.SYSTEM_MODE);
        }
    }
    
    private static String buildKey(
        Id accountId,
        String street,
        String city,
        String state,
        String pin,
        String country,
        String zone
    ) {
        
        return String.valueOf(accountId) + '|' +
            normalize(street) + '|' +
            normalize(city) + '|' +
            normalize(state) + '|' +
            normalize(pin) + '|' +
            normalize(country) + '|' +
            normalize(zone);
    }
    
    private static String normalize(String value){
        
        if(value == null){
            return '';
        }
        
        value = value.trim().toLowerCase();
        
        value = value.replaceAll('\\s+', ' ');
        
        return value;
    }
    
    // NEW: Bridge method so the LWC can use the exact same Flow logic
    @AuraEnabled
    public static void processFromLWC(Id leadId, Id accountId, Id contactId, Id opportunityId, Id selectedAddressBookId) {
        Input lwcInput = new Input();
        lwcInput.leadId = leadId;
        lwcInput.accountId = accountId;
        lwcInput.contactId = contactId;
        lwcInput.opportunityId = opportunityId;
        lwcInput.selectedAddressBookId = selectedAddressBookId;
        
        // Pass it into your existing Invocable logic!
        process(new List<Input>{ lwcInput });
    }
}