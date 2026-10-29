public with sharing class CreateDealerOpportunityController {
    @AuraEnabled(cacheable=true)
    public static Id getOpportunityRecordTypeId() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get(BWM_EmailConstants.DEALER_OPPORTUNITY_RECORD_TYPE);
        return recordTypeInfo == null ? null : recordTypeInfo.getRecordTypeId();
    }

    @AuraEnabled(cacheable=true)
    public static List<DealerAccountOption> getDealerAccounts() {
        List<DealerAccountOption> options = new List<DealerAccountOption>();
        Id dealerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Dealer')
            .getRecordTypeId();

        for (Account accountRecord : [
            SELECT Id, Name
            FROM Account
            WHERE RecordTypeId = :dealerRecordTypeId
            ORDER BY Name
        ]) {
            options.add(new DealerAccountOption(accountRecord.Id, accountRecord.Name));
        }
        return options;
    }

    @AuraEnabled
    public static DealerDetails getDealerDetails(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Dealer account is required.');
        }

        Account accountRecord = [
            SELECT Id, Name, Phone, Email__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        DealerDetails details = new DealerDetails();
        details.phone = accountRecord.Phone;
        details.email = accountRecord.Email__c;

        List<Contact> contacts = [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            details.contactId = contacts[0].Id;
            details.contactName = contacts[0].Name;
            if (String.isBlank(details.email)) {
                details.email = contacts[0].Email;
            }
            if (String.isBlank(details.phone)) {
                details.phone = contacts[0].Phone;
            }
        }

        return details;
    }

    @AuraEnabled
    public static Id createDealerOpportunity(
        Id accountId,
        Date closeDate,
        Decimal amount,
        String industry,
        String opportunityName
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Dealer account is required.');
        }
        if (closeDate == null) {
            throw new AuraHandledException('Expected closure date is required.');
        }

        Id dealerOpportunityRecordTypeId = getOpportunityRecordTypeId();
        if (dealerOpportunityRecordTypeId == null) {
            throw new AuraHandledException('Dealer Opportunity record type is not configured.');
        }

        Account dealerAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        DealerDetails dealerDetails = getDealerDetails(accountId);

        Opportunity opportunityRecord = new Opportunity();
        opportunityRecord.RecordTypeId = dealerOpportunityRecordTypeId;
        opportunityRecord.DealerAccount__c = accountId;
        opportunityRecord.CloseDate = closeDate;
        opportunityRecord.Amount = amount;
        opportunityRecord.Industry__c = industry;
        opportunityRecord.StageName = BWM_EmailConstants.STAGE_NEGOTIATION;
        opportunityRecord.Customer_Journey__c =
            BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER;
        opportunityRecord.Name = String.isNotBlank(opportunityName)
            ? opportunityName.trim()
            : dealerAccount.Name + ' - Dealer Opportunity';
        if (String.isNotBlank(dealerDetails.phone)) {
            opportunityRecord.Phone__c = dealerDetails.phone;
        }
        if (String.isNotBlank(dealerDetails.email)) {
            opportunityRecord.Email__c = dealerDetails.email;
        }

        insert opportunityRecord;

        if (dealerDetails.contactId != null) {
            insert new OpportunityContactRole(
                OpportunityId = opportunityRecord.Id,
                ContactId = dealerDetails.contactId,
                IsPrimary = true,
                Role = 'Decision Maker'
            );
        }

        return opportunityRecord.Id;
    }

    public class DealerAccountOption {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;

        public DealerAccountOption(Id accountId, String accountName) {
            id = accountId;
            name = accountName;
        }
    }

    public class DealerDetails {
        @AuraEnabled
        public String phone;
        @AuraEnabled
        public String email;
        @AuraEnabled
        public Id contactId;
        @AuraEnabled
        public String contactName;
    }
}