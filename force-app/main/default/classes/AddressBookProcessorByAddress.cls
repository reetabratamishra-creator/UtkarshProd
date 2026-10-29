public without sharing class AddressBookProcessorByAddress {

    public class Input {

        @InvocableVariable(required=true)
        public Id accountId;

        @InvocableVariable
        public Id contactId;

        @InvocableVariable(required=true)
        public Id opportunityId;

        // Null when a new Address Book should be created
        @InvocableVariable
        public Id selectedAddressBookId;

        @InvocableVariable
        public String street;

        @InvocableVariable
        public String city;

        @InvocableVariable
        public String state;

        @InvocableVariable
        public String country;

        @InvocableVariable
        public String pin;

        @InvocableVariable
        public String zone;
    }

    @InvocableMethod(label='Process Address Book Opp')
    public static void process(List<Input> inputs) {

        System.debug('================ START =================');
        System.debug('Inputs Size : ' + inputs.size());
        System.debug(JSON.serializePretty(inputs));

        if (inputs == null || inputs.isEmpty()) {
            return;
        }

        Set<Id> selectedAddressIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();

        for (Input i : inputs) {

            if (i.selectedAddressBookId != null) {
                selectedAddressIds.add(i.selectedAddressBookId);
            }

            if (i.accountId != null) {
                accountIds.add(i.accountId);
            }
        }

        Map<Id, Address_Book__c> selectedAddressMap = new Map<Id, Address_Book__c>();

        if (!selectedAddressIds.isEmpty()) {

            selectedAddressMap = new Map<Id, Address_Book__c>([
                SELECT Id,
                       Name,
                       Account__c,
                       Street__c,
                       City__c,
                       State__c,
                       Country__c,
                       PIN__c,
                       Zone__c,
                       Type__c,
                       Primary_Address__c
                FROM Address_Book__c
                WHERE Id IN :selectedAddressIds WITH
                SYSTEM_MODE
            ]);
        }

        Map<String, Address_Book__c> addressBookMap = new Map<String, Address_Book__c>();
        Set<Id> accountsWithPrimary = new Set<Id>();

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
                WITH SYSTEM_MODE
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
                if (ab.Primary_Address__c == true && ab.Account__c != null) {
                    accountsWithPrimary.add(ab.Account__c);
                }
            }
        }

        System.debug('=========================');
        System.debug('Address Book Map Size : ' + addressBookMap.size());

        for (String key : addressBookMap.keySet()) {
            System.debug('Map Key : ' + key);
        }

        System.debug('=========================');

        List<Address_Book__c> addressBooksToInsert = new List<Address_Book__c>();
        List<Input> createAddressInputs = new List<Input>();

        for (Input i : inputs) {

            // User already selected an Address Book
            if (i.selectedAddressBookId != null) {
                continue;
            }
            
            
            // No address entered at all
            Boolean hasAddress =
                String.isNotBlank(i.street) ||
                String.isNotBlank(i.city) ||
                String.isNotBlank(i.state) ||
                String.isNotBlank(i.pin) ||
                String.isNotBlank(i.country) ||
                String.isNotBlank(i.zone);
            
            if (!hasAddress) {
                System.debug('Skipping because no address was provided.');
                continue;
            }

            String key = buildKey(
                i.accountId,
                i.street,
                i.city,
                i.state,
                i.pin,
                i.country,
                i.zone
            );

            System.debug('Input Key = ' + key);
            System.debug('Map contains key = ' + addressBookMap.containsKey(key));

            // Existing Address Book found
            if (addressBookMap.containsKey(key)) {

                i.selectedAddressBookId = addressBookMap.get(key).Id;

                selectedAddressMap.put(
                    i.selectedAddressBookId,
                    addressBookMap.get(key)
                );

                continue;
            }

            Address_Book__c ab = new Address_Book__c();

            ab.Account__c = i.accountId;
            ab.Street__c = i.street;
            ab.City__c = i.city;
            ab.State__c = i.state;
            ab.Country__c = i.country;
            ab.PIN__c = i.pin;
            ab.Zone__c = i.zone;
            if (i.accountId != null && !accountsWithPrimary.contains(i.accountId)) {
                ab.Primary_Address__c = true;
                accountsWithPrimary.add(i.accountId);
            }

            // Reserve the key to prevent duplicate inserts in same transaction
            addressBookMap.put(key, ab);

            addressBooksToInsert.add(ab);
            createAddressInputs.add(i);
        }

        if (!addressBooksToInsert.isEmpty()) {

            Database.insert(addressBooksToInsert, AccessLevel.SYSTEM_MODE);

            Integer index = 0;

            for (Address_Book__c ab : addressBooksToInsert) {

                selectedAddressMap.put(ab.Id, ab);

                createAddressInputs[index].selectedAddressBookId = ab.Id;

                index++;
            }
        }

        List<Opportunity_Address_Junc__c> junctions = new List<Opportunity_Address_Junc__c>();
        List<Contact> contactsToUpdate = new List<Contact>();
        List<Address_Book__c> addressBooksForAccountStamp = new List<Address_Book__c>();
        
        Set<Id> opportunityIds = new Set<Id>();

        for (Input i : inputs) {
            if (i.opportunityId != null) {
                opportunityIds.add(i.opportunityId);
            }
        }
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>();
        
        if (!opportunityIds.isEmpty()) {
            opportunityMap = new Map<Id, Opportunity>([
                SELECT Id, AccountId
                FROM Opportunity
                WHERE Id IN :opportunityIds WITH
                SYSTEM_MODE
            ]);
        }

        for (Input i : inputs) {
            
            Opportunity opp = opportunityMap.get(i.opportunityId);

            Address_Book__c ab = selectedAddressMap.get(i.selectedAddressBookId);

            if (ab == null) {
                continue;
            }

            opportunityIds.add(i.opportunityId);
            junctions.add(new Opportunity_Address_Junc__c(
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
            }

            addressBooksForAccountStamp.add(ab);
            
            System.debug('Opportunity Account : ' + (opp == null ? null : opp.AccountId));
            System.debug('Input Account       : ' + i.accountId);
            System.debug('AddressBook Account : ' + ab.Account__c);
            
        }

        if (!junctions.isEmpty()) {
            Database.insert(junctions, AccessLevel.SYSTEM_MODE);
        }

        if (!contactsToUpdate.isEmpty()) {
            Database.update(contactsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        stampAccountBillingFromAddressBooks(addressBooksForAccountStamp);
    }

    private static void stampAccountBillingFromAddressBooks(List<Address_Book__c> addressBooks) {
        if (addressBooks == null || addressBooks.isEmpty()) {
            return;
        }

        Map<Id, Address_Book__c> bookByAccount = new Map<Id, Address_Book__c>();
        for (Address_Book__c ab : addressBooks) {
            if (ab == null || ab.Account__c == null) {
                continue;
            }
            if (!bookByAccount.containsKey(ab.Account__c) || ab.Primary_Address__c == true) {
                bookByAccount.put(ab.Account__c, ab);
            }
        }
        if (bookByAccount.isEmpty()) {
            return;
        }

        Map<Id, Account> accounts = new Map<Id, Account>([
            SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Zone__c
            FROM Account
            WHERE Id IN :bookByAccount.keySet()
            WITH SYSTEM_MODE
        ]);

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accountId : bookByAccount.keySet()) {
            Account acc = accounts.get(accountId);
            Address_Book__c ab = bookByAccount.get(accountId);
            if (acc == null || ab == null) {
                continue;
            }
            Boolean changed = applyAddressBookToAccount(acc, ab);
            if (changed) {
                accountsToUpdate.add(acc);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(accountsToUpdate, false, AccessLevel.SYSTEM_MODE);
            List<Account> retryWithoutPicklists = new List<Account>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    continue;
                }
                Account failed = accountsToUpdate[i];
                Address_Book__c ab = bookByAccount.get(failed.Id);
                if (ab == null) {
                    continue;
                }
                Account retry = new Account(Id = failed.Id);
                if (String.isNotBlank(ab.Street__c)) {
                    retry.BillingStreet = ab.Street__c;
                }
                if (String.isNotBlank(ab.City__c)) {
                    retry.BillingCity = ab.City__c;
                }
                if (String.isNotBlank(ab.PIN__c)) {
                    retry.BillingPostalCode = ab.PIN__c;
                }
                if (String.isNotBlank(ab.Zone__c)) {
                    retry.Zone__c = ab.Zone__c;
                }
                retryWithoutPicklists.add(retry);
            }
            if (!retryWithoutPicklists.isEmpty()) {
                Database.update(retryWithoutPicklists, false, AccessLevel.SYSTEM_MODE);
            }
        }
    }

    private static Boolean applyAddressBookToAccount(Account acc, Address_Book__c ab) {
        Boolean changed = false;
        if (String.isBlank(acc.BillingStreet) && String.isNotBlank(ab.Street__c)) {
            acc.BillingStreet = ab.Street__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingCity) && String.isNotBlank(ab.City__c)) {
            acc.BillingCity = ab.City__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingState) && String.isNotBlank(ab.State__c)) {
            acc.BillingState = ab.State__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingPostalCode) && String.isNotBlank(ab.PIN__c)) {
            acc.BillingPostalCode = ab.PIN__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingCountry) && String.isNotBlank(ab.Country__c)) {
            acc.BillingCountry = ab.Country__c;
            changed = true;
        }
        if (String.isBlank(acc.Zone__c) && String.isNotBlank(ab.Zone__c)) {
            acc.Zone__c = ab.Zone__c;
            changed = true;
        }
        return changed;
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

    private static String normalize(String value) {

        if (value == null) {
            return '';
        }

        value = value.trim().toLowerCase();
        value = value.replaceAll('\\s+', ' ');

        return value;
    }
}