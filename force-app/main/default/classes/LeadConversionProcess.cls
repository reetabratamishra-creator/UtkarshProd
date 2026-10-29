public class LeadConversionProcess {

    public class Input {
        @InvocableVariable(required=true)
        public Id leadId;

        // Optional Account Id
        @InvocableVariable
        public Id accId;
        
        @InvocableVariable
    	public Id contactId;
        
    }

    public class Output {
        @InvocableVariable public Id accountId;
        @InvocableVariable public Id contactId;
        @InvocableVariable public Id opportunityId;
        @InvocableVariable public String status;
    }

    @InvocableMethod(label='Convert Lead')
    public static List<Output> convertLead(List<Input> inputs) {

        List<Output> results = new List<Output>();
        
        if(inputs == null || inputs.isEmpty()){
            return results;
        }

        // Extract Lead Ids
        Set<Id> leadIds = new Set<Id>();
        for (Input inp : inputs) {
            if (inp.leadId != null) {
                leadIds.add(inp.leadId);
            }
        }

        // Get converted status
        LeadStatus convertStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];

        // Get Record Types
        Map<String, Schema.RecordTypeInfo> accRTs =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        Id accountRecordTypeId = accRTs.containsKey('End_Customer')
            ? accRTs.get('End_Customer').getRecordTypeId()
            : null;

        Map<String, Schema.RecordTypeInfo> oppRTs =
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();

        Id opportunityRecordTypeId = oppRTs.containsKey('Master_Opportunity')
            ? oppRTs.get('Master_Opportunity').getRecordTypeId()
            : null;

        // Get Leads
        Map<Id, Lead> leadMap = new Map<Id, Lead>(
            [
                SELECT Id, Department_Name__c, Zone__c, Country__c, City__c, PIN__c, State__c,Street__c,  Company, Name, Customer_Category__c, Email, Phone, LeadSource, Tentative_Closure_Date__c
                FROM Lead
                WHERE Id IN :leadIds
            ]
        );
        
        List<Database.LeadConvert> conversions = new List<Database.LeadConvert>();
        
        for(Input inp : inputs){

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(inp.leadId);
            lc.setConvertedStatus(convertStatus.MasterLabel);
            lc.setDoNotCreateOpportunity(false);

            if(inp.accId != null){
                lc.setAccountId(inp.accId);
            }
            
            if (inp.contactId != null) {
                lc.setContactId(inp.contactId);
            }

            conversions.add(lc);
        }
        List<Database.LeadConvertResult> convertResults = Database.convertLead(conversions, false);

        Set<Id> accountIdsToQuery = new Set<Id>();
        for(Database.LeadConvertResult lcr : convertResults){
            if(lcr.isSuccess() && lcr.getAccountId() != null){
                accountIdsToQuery.add(lcr.getAccountId());
            }
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>();

        if(!accountIdsToQuery.isEmpty()){
            accountMap = new Map<Id, Account>(
                [
                    SELECT Id,
                           Name,
                           RecordTypeId,
                           Email__c,
                           Phone,
                           AccountSource,
                           City__c,
                           Country__c,
                           State__c,
                           PIN__c,
                           Street__c,
                    	   Zone__c
                    FROM Account
                    WHERE Id IN :accountIdsToQuery
                ]
            );
        }

        // Bulk update lists
        List<Account> accountsToUpdate = new List<Account>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        List<Contact> contactToUpdate = new List<Contact>();
              
        Integer idx = 0;

        for (Input inp : inputs) {

            Output out = new Output();

            try {

                Database.LeadConvertResult lcr = convertResults[idx];       

                if (lcr.isSuccess()) {

                    out.accountId = lcr.getAccountId();
                    out.contactId = lcr.getContactId();
                    out.opportunityId = lcr.getOpportunityId();
                    

                    Lead ld = leadMap.get(inp.leadId);

                    // Build Opportunity Name
                    String oppName = '';
                    Account accExisting = accountMap.get(out.accountId);

                    if (ld != null) {

                        String dept =
                            ld.Department_Name__c != null
                            ? ld.Department_Name__c
                            : '';
						
                        String accName = accExisting.Name;

                        /*String custName =
                            ld.Name != null
                            ? ld.Name
                            : '';*/

                        oppName =
                            dept + ' - ' +
                            accName; /*+ ' - ' +
                            custName;*/
                    }

                    // =========================================
                    // Update Account Record Type
                    // ONLY when new account is created
                    // =========================================
                    if (
                        inp.accId == null &&
                        out.accountId != null &&
                        accountRecordTypeId != null && accExisting != null
                    ) {
                        
                        Account acc = new Account(
                        	Id = out.accountId,
                        	RecordTypeId = accountRecordTypeId
                        );
                        // populate email from lead if not present
                        if(String.isEmpty(accExisting.Email__c)){ acc.Email__c = ld.Email;}
                        // populate phone from lead if not present
                        if(String.isEmpty(accExisting.Phone)){acc.Phone = ld.Phone;}
                        // populate source from lead if not present
                        if(String.isEmpty(accExisting.AccountSource)){acc.AccountSource = ld.LeadSource;}
                        accountsToUpdate.add(acc);
                    }

                    // Opportunity update
                    if (out.opportunityId != null) {

                        Opportunity opp = new Opportunity(
                            Id = out.opportunityId,
                            Name = oppName,
                            Lead__c = inp.leadId,
                            Email__c = leadMap.get(inp.leadId).Email,
                            Phone__c = leadMap.get(inp.leadId).Phone,
                            closeDate = leadMap.get(inp.leadId).Tentative_Closure_Date__c,
                            isFirstUpdate__c = True
                        );

                        if (opportunityRecordTypeId != null) {
                            opp.RecordTypeId = opportunityRecordTypeId;
                        }

                        
                        oppsToUpdate.add(opp);
                    }
                    
                    if(out.contactId != null){
                        Contact con = new Contact(
                        	Id = out.contactId,
                            Zone__c = accExisting.Zone__c,
                            Country__c = accExisting.Country__c,
                            State__c = accExisting.State__c,
                            PIN__c = accExisting.PIN__c,
                            Street__c = accExisting.Street__c,
                            City__c = accExisting.City__c
                        );
                        
                        contactToUpdate.add(con);
                    }

                    out.status = 'Success';

                } else {

                    String errMsg = '';

                    for (Database.Error err : lcr.getErrors()) {
                        errMsg += err.getMessage() + ' | ';
                    }

                    out.status = 'Failed: ' + errMsg;
                }

            } catch (Exception e) {

                out.status = 'Error: ' + e.getMessage();
            }

            results.add(out);
        }

        // Bulk Update Accounts
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        // Bulk Update Opportunities
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
        
        if (!contactToUpdate.isEmpty()) {
            update contactToUpdate;
        }
        
        return results;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product_Category__c> getExistingLeadProducts(Id leadId, String department) {
        if (leadId == null || String.isBlank(department)) {
            return new List<Product_Category__c>();
        }
        return [
            SELECT Id, Product_Category__c, UOM__c, Quantity__c, Department_Name__c, Lead__c
            FROM Product_Category__c
            WHERE Lead__c = :leadId
            AND Department_Name__c = :department
            ORDER BY CreatedDate ASC
        ];
    }
}