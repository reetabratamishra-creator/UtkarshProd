public class AccountResolverController_Opp_Create {

    private static final String OPP_RT_DEALER = 'Dealer Opportunity';
    private static final String ACCOUNT_RT_DEALER = 'Dealer';

    /** Type and search on Account Name. Filters by Account RecordType only when the Opportunity record type is Dealer_Opportunity. */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchKey, String recordTypeName) {
        System.debug('[AccountResolver] searchAccounts — searchKey: ' + searchKey + ' | recordTypeName: ' + recordTypeName);

        if (String.isBlank(searchKey) || searchKey.trim().length() < 2) {
            System.debug('[AccountResolver] searchAccounts — searchKey too short, returning empty list');
            return new List<Account>();
        }
        String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';

        String query = 'SELECT Id, Name, Phone, Email__c, BillingCity ' +
                        'FROM Account ' +
                        'WHERE Name LIKE \'' + key + '\'';

        Boolean dealerFilterApplied = (recordTypeName == OPP_RT_DEALER);
        System.debug('[AccountResolver] searchAccounts — dealerFilterApplied: ' + dealerFilterApplied
            + ' (comparing "' + recordTypeName + '" == "' + OPP_RT_DEALER + '")');

        if (dealerFilterApplied) {
            String accountRt = ACCOUNT_RT_DEALER;
            query += ' AND RecordType.Name = :accountRt';
        }

        query += ' WITH USER_MODE ORDER BY Name ASC LIMIT 10';

        System.debug('[AccountResolver] searchAccounts — final query: ' + query);

        List<Account> results = Database.query(query);
        System.debug('[AccountResolver] searchAccounts — result count: ' + results.size());
        System.debug('[AccountResolver] searchAccounts — results: ' + results);

        return results;
    }

    /**
     * Duplicate detection: exact Phone OR exact Email__c OR fuzzy Name.
     * Filters by Account RecordType only when the Opportunity record type is Dealer_Opportunity.
     */
    @AuraEnabled
    public static List<Account> findDuplicateAccounts(String companyName, String phone, String email, String recordTypeName) {
        System.debug('[AccountResolver] findDuplicateAccounts — companyName: ' + companyName
            + ' | phone: ' + phone
            + ' | email: ' + email
            + ' | recordTypeName: ' + recordTypeName);

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

        System.debug('[AccountResolver] findDuplicateAccounts — candidateIds from FindDuplicates: ' + candidateIds);

        if (candidateIds.isEmpty()) {
            System.debug('[AccountResolver] findDuplicateAccounts — no candidateIds found, returning empty list');
            return new List<Account>();
        }

        String query = 'SELECT Id, Name, Phone, Email__c ' +
                        'FROM Account ' +
                        'WHERE Id IN :candidateIds';

        Boolean dealerFilterApplied = (recordTypeName == OPP_RT_DEALER);
        System.debug('[AccountResolver] findDuplicateAccounts — dealerFilterApplied: ' + dealerFilterApplied
            + ' (comparing "' + recordTypeName + '" == "' + OPP_RT_DEALER + '")');

        if (dealerFilterApplied) {
            String accountRt = ACCOUNT_RT_DEALER;
            query += ' AND RecordType.Name = :accountRt';
        }

        query += ' WITH USER_MODE';

        System.debug('[AccountResolver] findDuplicateAccounts — final query: ' + query);

        Map<Id, Account> candidates = new Map<Id, Account>((List<Account>) Database.query(query));
        System.debug('[AccountResolver] findDuplicateAccounts — candidates after RecordType filter: ' + candidates.size());

        List<Account> matches = new List<Account>();
        for (Account a : candidates.values()) {
            Boolean phoneMatch = String.isNotBlank(phone) && phone == a.Phone;
            Boolean emailMatch = String.isNotBlank(email) && email == a.Email__c;
            Boolean nameFuzzy  = String.isNotBlank(companyName) && a.Name != null
                && companyName.toLowerCase().contains(a.Name.toLowerCase().left(4));

            System.debug('[AccountResolver] findDuplicateAccounts — evaluating ' + a.Id + ' (' + a.Name + ')'
                + ' | phoneMatch: ' + phoneMatch
                + ' | emailMatch: ' + emailMatch
                + ' | nameFuzzy: ' + nameFuzzy);

            if (phoneMatch || emailMatch || nameFuzzy) {
                matches.add(a);
            }
        }

        System.debug('[AccountResolver] findDuplicateAccounts — final matches count: ' + matches.size());
        System.debug('[AccountResolver] findDuplicateAccounts — final matches: ' + matches);

        return matches;
    }
}