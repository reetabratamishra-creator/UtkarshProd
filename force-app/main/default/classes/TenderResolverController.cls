public without sharing class TenderResolverController {

    public class TenderSetupPayload {
        @AuraEnabled public Id tenderId { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        
        @AuraEnabled public Id addressBookId { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String pincode { get; set; }
        
        @AuraEnabled public Boolean includeContact { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String contactFirstName { get; set; }
        @AuraEnabled public String contactLastName { get; set; }
        @AuraEnabled public String contactEmail { get; set; }
        @AuraEnabled public String contactPhone { get; set; }
    }

    /** Type and search on Account Name. */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchKey) {
        if (String.isBlank(searchKey) || searchKey.trim().length() < 2) {
            return new List<Account>();
        }
        String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
        return [
            SELECT Id, Name, Phone, Email__c, BillingCity
            FROM Account
            WHERE Name LIKE :key
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 10
        ];
    }

    /** Duplicate detection: exact Phone OR exact Email__c OR fuzzy Name. */
    @AuraEnabled
    public static List<Account> findDuplicateAccounts(String companyName, String phone, String email) {
        Account candidate = new Account(
            Name     = companyName,
            Phone    = phone,
            Email__c = email
        );

        List<Datacloud.FindDuplicatesResult> fdResults =
            Datacloud.FindDuplicates.findDuplicates(new List<Account>{ candidate });

        Set<Id> candidateIds = new Set<Id>();
        for (Datacloud.FindDuplicatesResult fdr : fdResults) {
            for (Datacloud.DuplicateResult dr : fdr.getDuplicateResults()) {
                for (Datacloud.MatchResult mr : dr.getMatchResults()) {
                    for (Datacloud.MatchRecord rec : mr.getMatchRecords()) {
                        candidateIds.add(rec.getRecord().Id);
                    }
                }
            }
        }

        if (candidateIds.isEmpty()) {
            return new List<Account>();
        }

        Map<Id, Account> candidates = new Map<Id, Account>([
            SELECT Id, Name, Phone, Email__c
            FROM Account
            WHERE Id IN :candidateIds
            WITH USER_MODE
        ]);

        List<Account> matches = new List<Account>();
        for (Account a : candidates.values()) {
            Boolean phoneMatch = String.isNotBlank(phone) && phone == a.Phone;
            Boolean emailMatch = String.isNotBlank(email) && email == a.Email__c;
            Boolean nameFuzzy  = String.isNotBlank(companyName) && a.Name != null
                && companyName.toLowerCase().contains(a.Name.toLowerCase().left(4));
            if (phoneMatch || emailMatch || nameFuzzy) {
                matches.add(a);
            }
        }
        return matches;
    }

    /** Fetch existing contacts for the selected account */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getAccountContacts(Id accountId) {
        if (accountId == null) {
            return new List<Contact>();
        }
        return [
            SELECT Id, Name, Email, Phone 
            FROM Contact 
            WHERE AccountId = :accountId 
            WITH USER_MODE 
            ORDER BY Name ASC
        ];
    }

    

    @AuraEnabled
    public static void processTenderSetup(TenderSetupPayload payload) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            // 1. Handle Account
            Id finalAccountId = payload.accountId;
            if (finalAccountId == null) {
                Account newAcc = new Account(
                    Name = payload.accountName,
                    AccountSource = 'TENDER'
                );
                Database.insert(newAcc, AccessLevel.SYSTEM_MODE);
                finalAccountId = newAcc.Id;
            }

            // 2. Handle Contact (if requested)
            Id finalContactId = payload.contactId;
            if (payload.includeContact && finalContactId == null) {
                Contact newCon = new Contact(
                    AccountId = finalAccountId,
                    FirstName = payload.contactFirstName,
                    LastName = payload.contactLastName,
                    Email = payload.contactEmail,
                    Phone = payload.contactPhone
                );
                Database.insert(newCon, AccessLevel.SYSTEM_MODE);
                finalContactId = newCon.Id;
            }

            // 3. Update Tender Record (Link Account & Contact)
            Tender__c tenderToUpdate = new Tender__c(Id = payload.tenderId);
            tenderToUpdate.Authority__c = finalAccountId;
            if (payload.includeContact) {
                tenderToUpdate.Contact__c = finalContactId;
            }
            Database.update(tenderToUpdate, AccessLevel.SYSTEM_MODE);

            // 4. Handle Address Book & Junction
            Id finalAddressBookId = payload.addressBookId;
            
            // If no address book was selected but address fields were filled, create a new Address Book
            if (finalAddressBookId == null && (String.isNotBlank(payload.city) || String.isNotBlank(payload.street))) {
                Address_Book__c newAb = new Address_Book__c(
                    Account__c = finalAccountId,
                    Street__c = payload.street,
                    City__c = payload.city,
                    State__c = payload.state,
                    Country__c = payload.country,
                    PIN__c = payload.pincode
                );
                Database.insert(newAb, AccessLevel.SYSTEM_MODE);
                finalAddressBookId = newAb.Id;
            }

            // If we have an address book (either picked or newly created), link it to the Tender
            if (finalAddressBookId != null) {

                // --- NEW LOGIC: Disassociate any existing Address Books from this Tender ---
                List<Tender_Addressbook_Junc__c> existingJunctions = [
                    SELECT Id 
                    FROM Tender_Addressbook_Junc__c 
                    WHERE Tender__c = :payload.tenderId
                ];
                
                if (!existingJunctions.isEmpty()) {
                    Database.delete(existingJunctions, AccessLevel.SYSTEM_MODE);
                }

                Tender_Addressbook_Junc__c junction = new Tender_Addressbook_Junc__c(
                    Tender__c = payload.tenderId,
                    Address_Book__c = finalAddressBookId
                );
                Database.insert(junction, AccessLevel.SYSTEM_MODE);
            }

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }
}