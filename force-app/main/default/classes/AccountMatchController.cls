public with sharing class AccountMatchController {

    /**
     * Exact-match duplicate check. Any of Phone / Email__c / Name matching
     * flags the record as a potential duplicate (OR).
     * Switch String.join(conditions, ' OR ') to ' AND ' if you need all three to match.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getMatchingAccounts(String accountName, String phone, String email) {
        List<String> conditions = new List<String>();
        if (String.isNotBlank(phone))       { conditions.add('Phone = :phone'); }
        if (String.isNotBlank(email))       { conditions.add('Email__c = :email'); }
        if (String.isNotBlank(accountName)) { conditions.add('Name = :accountName'); }

        if (conditions.isEmpty()) {
            return new List<Account>();
        }

        String soql =
            'SELECT Id, Name, Phone, Email__c, BillingCity, Owner.Name ' +
            'FROM Account ' +
            'WHERE ' + String.join(conditions, ' OR ') + ' ' +
            'WITH USER_MODE ' +
            'ORDER BY Name ASC ' +
            'LIMIT 50';

        return Database.query(soql);
    }

    /** Type-ahead search on Account Name. */
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
}