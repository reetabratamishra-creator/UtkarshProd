public with sharing class DealerOpportunityController {

    // Account uses the "Dealer" record type; the Opportunity we insert uses "Dealer_Opportunity".
    private static final String OPPORTUNITY_RT_DEVELOPER_NAME = 'Dealer_Opportunity';
    private static final String ACCOUNT_RT_DEVELOPER_NAME     = 'Dealer';

    // ---------------------------------------------------------------------
    // Wrappers
    // ---------------------------------------------------------------------
    public class DealerOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        public DealerOption(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    public class DealerDetails {
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
    }

    // ---------------------------------------------------------------------
    // Opportunity "Dealer_Opportunity" record type id — used client-side to
    // drive the record-type-aware Industry__c picklist.
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static Id getOpportunityRecordTypeId() {
        Schema.RecordTypeInfo rt = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get(OPPORTUNITY_RT_DEVELOPER_NAME);
        return rt == null ? null : rt.getRecordTypeId();
    }

    // ---------------------------------------------------------------------
    // 1. Dealer accounts (Account record type = Dealer), filtered by the
    //    running user's Department.
    //    - User has a Department  -> only dealers whose
    //      Department_Name_MultiSelect__c INCLUDES that value
    //    - User has no Department -> all Dealer accounts
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<DealerOption> getDealerAccounts() {
        User u = [
            SELECT Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        String dept = u.Department;

        List<Account> accounts;
        if (String.isBlank(dept)) {
            accounts = [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = :ACCOUNT_RT_DEVELOPER_NAME
                WITH SYSTEM_MODE
                ORDER BY Name
                LIMIT 5000
            ];
        } else {
            accounts = [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = :ACCOUNT_RT_DEVELOPER_NAME
                AND Department_Name_MultiSelect__c INCLUDES (:dept)
                WITH SYSTEM_MODE
                ORDER BY Name
                LIMIT 5000
            ];
        }

        List<DealerOption> options = new List<DealerOption>();
        for (Account a : accounts) {
            options.add(new DealerOption(a.Id, a.Name));
        }
        return options;
    }

    // ---------------------------------------------------------------------
    // 2. Details of the chosen dealer — pre-fills Phone__c / Email__c on the
    //    Opportunity and previews the Contact that becomes the Contact Role.
    // ---------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static DealerDetails getDealerDetails(Id accountId) {
        Account a = [
            SELECT Id, Phone, Email__c
            FROM Account
            WHERE Id = :accountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        DealerDetails d = new DealerDetails();
        d.phone = a.Phone;
        d.email = a.Email__c;

        // The dealer is expected to have exactly one Contact. LIMIT 2 lets us
        // detect (and, if you want, reject) the multi-contact case.
        List<Contact> contacts = [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY CreatedDate
            LIMIT 2
        ];
        if (!contacts.isEmpty()) {
            d.contactId   = contacts[0].Id;
            d.contactName = contacts[0].Name;
        }
        return d;
    }

    // ---------------------------------------------------------------------
    // 3. Create the Dealer_Opportunity + its Contact Role
    // ---------------------------------------------------------------------
    @AuraEnabled
    public static Id createDealerOpportunity(
        Id accountId,
        Date closeDate,
        Decimal amount,
        String industry,
        String opportunityName
    ) {
        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get(OPPORTUNITY_RT_DEVELOPER_NAME);
        if (rtInfo == null) {
            throw new AuraHandledException(
                'Opportunity record type "' + OPPORTUNITY_RT_DEVELOPER_NAME + '" was not found.'
            );
        }

        Account acc = [
            SELECT Id, Name, Phone, Email__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        // Running user's Department drives both the Name prefix and Department_Name__c.
        User runningUser = [
            SELECT Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        String deptPrefix = String.isBlank(runningUser.Department)
            ? ''
            : runningUser.Department + ' - ';

        Opportunity opp = new Opportunity();
        opp.RecordTypeId = rtInfo.getRecordTypeId();

        // Name = <User Department> - <Account Name>
        opp.Name = String.isBlank(opportunityName)
            ? deptPrefix + acc.Name
            : opportunityName;

        // User-entered / dealer-mapped
        opp.AccountId   = accountId;   // standard lookup
        opp.DealerAccount__c   = accountId;   // custom lookup, same Account
        opp.CloseDate   = closeDate;
        opp.Amount      = amount;
        opp.Industry__c = industry;

        // Copied from the tagged Dealer Account
        opp.Phone__c = acc.Phone;
        opp.Email__c = acc.Email__c;

        // Hard-coded business defaults
        opp.Opportunity_Source__c = 'Offline Marketing';
        opp.Customer_Category__c  = 'Dealer';
        opp.StageName             = 'Negotiation';
        opp.Customer_Journey__c   = 'Refer to Dealer';

        // Stamped from the running user
        opp.Department_Name__c = runningUser.Department;

        System.debug('Opportunity Department: ' + opp.Department_Name__c);
        System.debug('User Department: ' + runningUser.Department);
        
        insert opp;

        // Tag the dealer's single Contact as the Opportunity Contact Role
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE AccountId = :accountId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate
            LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            insert new OpportunityContactRole(
                OpportunityId = opp.Id,
                ContactId     = contacts[0].Id,
                IsPrimary     = true
            );
        }

        return opp.Id;
    }
}