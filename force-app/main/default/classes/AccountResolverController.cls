public with sharing class AccountResolverController {

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
            WITH SYSTEM_MODE
            ORDER BY Name ASC
            LIMIT 10
        ];
    }

    /**
     * Duplicate detection: exact Phone OR exact Email__c OR fuzzy Name.
     */
    @AuraEnabled
    public static List<Account> findDuplicateAccounts(String companyName, String phone, String email) {
        Account candidate = new Account(
            Name    = companyName,
            Phone   = phone,
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
            WITH SYSTEM_MODE
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
}