public without sharing class bidderAwardController {

    // ==========================================
    // WRAPPER CLASS FOR PAYLOAD
    // ==========================================
    public class AwardRequestWrapper {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public Boolean isExistingAccount { get; set; }
        @AuraEnabled public Id selectedAccountId { get; set; }
        @AuraEnabled public String newAccountName { get; set; }
        @AuraEnabled public String newAccountPhone { get; set; }
        @AuraEnabled public String newAccountEmail { get; set; }

        @AuraEnabled public String contactMode { get; set; } // 'bidder', 'existing', 'manual'
        @AuraEnabled public Id selectedContactId { get; set; }
        @AuraEnabled public String contactFirstName { get; set; }
        @AuraEnabled public String contactLastName { get; set; }
        @AuraEnabled public String contactPhone { get; set; }
        @AuraEnabled public String contactEmail { get; set; }

        @AuraEnabled public Id selectedAddressBookId { get; set; }
        @AuraEnabled public Map<String, Object> newAddressData { get; set; }

        @AuraEnabled public List<Product_Category__c> productCategories { get; set; }
    }

    // ==========================================
    // SAVE & AWARD METHOD
    // ==========================================
    @AuraEnabled
    public static void saveAndAwardOpportunity(AwardRequestWrapper req) {
        if (req == null || req.opportunityId == null) {
            throw new AuraHandledException('Invalid request data.');
        }

        // Establish database savepoint for atomic rollback
        Savepoint sp = Database.setSavepoint();

        try {
            // STEP 0: Validate Opportunity & Amount FIRST before any DML
            Opportunity awardedOpp = [
                SELECT Id, Parent_Opportunity__c, OwnerId, Department_NameFormula__c, Amount
                FROM Opportunity
                WHERE Id = :req.opportunityId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (awardedOpp.Amount == null || awardedOpp.Amount < 1) {
                throw new AuraHandledException('Please put in the Expected Deal Value before awarding the Opportunity!');
            }

            // STEP 1: Resolve Account
            Id finalAccountId = req.selectedAccountId;
            if (!req.isExistingAccount) {
                Account acc = new Account(
                    Name = req.newAccountName,
                    Phone = req.newAccountPhone,
                    Email__c = req.newAccountEmail
                );
                insert as system acc;
                finalAccountId = acc.Id;
            }

            // STEP 2: Resolve Contact
            Id finalContactId;
            if (req.contactMode == 'existing') {
                finalContactId = req.selectedContactId;
            } else if (req.contactMode == 'bidder') {
                Bidders_Contact_Details__c bidderDetails = getBidderContactDetails(req.opportunityId);
                if (bidderDetails != null) {
                    Contact con = new Contact(
                        LastName = bidderDetails.Name,
                        Phone = bidderDetails.Contact_Number__c,
                        Email = bidderDetails.Email__c,
                        AccountId = finalAccountId
                    );
                    insert as system con;
                    finalContactId = con.Id;
                }
            } else if (req.contactMode == 'manual') {
                Contact con = new Contact(
                    FirstName = req.contactFirstName,
                    LastName = req.contactLastName,
                    Phone = req.contactPhone,
                    Email = req.contactEmail,
                    AccountId = finalAccountId
                );
                insert as system con;
                finalContactId = con.Id;
            }

            // STEP 3: Link Account to Opportunity
            Opportunity oppToUpdate = new Opportunity(
                Id = req.opportunityId,
                AccountId = finalAccountId
            );
            update as system oppToUpdate;

            // STEP 4: Create Opportunity Contact Role (OCR)
            if (finalContactId != null) {
                List<OpportunityContactRole> existingRoles = [
                    SELECT Id FROM OpportunityContactRole 
                    WHERE OpportunityId = :req.opportunityId AND ContactId = :finalContactId
                    LIMIT 1
                ];
                if (existingRoles.isEmpty()) {
                    OpportunityContactRole ocr = new OpportunityContactRole(
                        OpportunityId = req.opportunityId,
                        ContactId = finalContactId,
                        IsPrimary = true
                    );
                    insert as system ocr;
                }
            }

            // STEP 5: Process Existing / External Address Book Logic
            AddressBookProcessor.processFromLWC(
                null,
                finalAccountId,
                finalContactId,
                req.opportunityId,
                req.selectedAddressBookId
            );

            // STEP 6: Create New Address Book & Junction if needed
            if (req.selectedAddressBookId == null && req.newAddressData != null && !req.newAddressData.isEmpty()) {
                createAddressBookAndJunction(finalAccountId, req.opportunityId, req.newAddressData);
            }

            // STEP 7: Insert Product Categories
            if (req.productCategories != null && !req.productCategories.isEmpty()) {
                for (Product_Category__c pc : req.productCategories) {
                    pc.Opportunity__c = req.opportunityId;
                }
                insert as system req.productCategories;
            }

            // STEP 8: Finalize Award (Status, Sibling Opps, Notifications, Tasks)
            finalizeAwardInternal(awardedOpp);

        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'saveAndAwardOpportunity failed: ' + ex.getTypeName() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            AuraHandledException ahe = new AuraHandledException(ex.getMessage());
            ahe.setMessage(ex.getMessage());
            throw ahe;
        }
    }

    // Helper refactored from existing finalizeOpportunityAward logic
    private static void finalizeAwardInternal(Opportunity awardedOpp) {
        Id masterRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
                                      .get('Master_Opportunity').getRecordTypeId();

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        Set<Id> oppListIds = new Set<Id>();

        awardedOpp.RecordTypeId = masterRecordTypeId;
        awardedOpp.Opportunity_Source__c = 'TENDER';
        oppsToUpdate.add(awardedOpp);
        oppListIds.add(awardedOpp.Id);

        if (awardedOpp.Parent_Opportunity__c != null) {
            List<Opportunity> relatedOpps = [
                SELECT Id, StageName
                FROM Opportunity
                WHERE Id = :awardedOpp.Parent_Opportunity__c
                   OR (Parent_Opportunity__c = :awardedOpp.Parent_Opportunity__c AND Id != :awardedOpp.Id)
                WITH SYSTEM_MODE
            ];

            for (Opportunity opp : relatedOpps) {
                opp.Stage_Lost_From__c = opp.StageName;
                opp.StageName = 'Closed Lost';
                opp.Lost_Reason__c = 'Tender lost';
                oppsToUpdate.add(opp);
                oppListIds.add(opp.Id);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            Database.update(oppsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        handleRelatedTasks(oppListIds, awardedOpp.Id, awardedOpp.OwnerId);
        sendAwardNotification(awardedOpp);
    }

    @AuraEnabled(cacheable=true)
    public static String getBidderName(Id opportunityId) {
        Opportunity opp = [
            SELECT Bidder__r.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];
        return opp.Bidder__r != null ? opp.Bidder__r.Name : null;
    }
    
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

    @AuraEnabled
    public static List<Account> findDuplicateAccounts(String companyName, String phone, String email) {
        Account candidate = new Account(
            Name = companyName,
            Phone = phone,
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
            Boolean nameFuzzy = String.isNotBlank(companyName) && a.Name != null
                && companyName.toLowerCase().contains(a.Name.toLowerCase().left(4));
            if (phoneMatch || emailMatch || nameFuzzy) {
                matches.add(a);
            }
        }
        return matches;
    }

    @AuraEnabled
    public static List<Contact> getAccountContacts(Id accountId) {
        return [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE AccountId = :accountId
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Bidders_Contact_Details__c getBidderContactDetails(Id opportunityId) {
        Opportunity opp = [SELECT Bidder__c FROM Opportunity WHERE Id = :opportunityId WITH USER_MODE LIMIT 1];
        if (opp.Bidder__c != null) {
            List<Bidders_Contact_Details__c> details = [
                SELECT Name, Contact_Number__c, Email__c, Bidders__r.Name
                FROM Bidders_Contact_Details__c
                WHERE Bidders__c = :opp.Bidder__c
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!details.isEmpty()) {
                return details[0];
            }
        }
        return null;
    }

    private static void sendAwardNotification(Opportunity awardedOpp) {
        Set<String> recipientIds = new Set<String>();
        if (awardedOpp.OwnerId != null) {
            recipientIds.add(awardedOpp.OwnerId);
        }

        if (String.isNotBlank(awardedOpp.Department_NameFormula__c)) {
            String deptPattern = '%' + String.escapeSingleQuotes(awardedOpp.Department_NameFormula__c) + '%';
            List<User> matchingUsers = [
                SELECT Id
                FROM User
                WHERE Profile.Name IN ('CRM Head', 'Utkarsh HOD')
                  AND Department LIKE :deptPattern
                  AND IsActive = true
                WITH SYSTEM_MODE
            ];
            for (User u : matchingUsers) {
                recipientIds.add(u.Id);
            }
        } else {
            throw new AuraHandledException('Cannot send notifications. Department name is blank in the awarded opportunity.');
        }

        if (recipientIds.isEmpty()) {
            return;
        }

        try {
            CustomNotificationType notificationType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'L1_Bidder_Notification' 
                LIMIT 1
            ];

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('L1 Bidder Declared');
            notification.setBody('L1 Bidder declared. Opportunity is ready for confirmation.');
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(awardedOpp.Id);
            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug('Failed to send Custom Notification: ' + e.getMessage());
        }
    }

    public static void handleRelatedTasks(Set<Id> allAffectedOppIds, Id awardedOppId, Id ownerId) {
        if (allAffectedOppIds.isEmpty() || awardedOppId == null || ownerId == null) {
            return;
        }

        List<Task> tasksToClose = [
            SELECT Id, Status 
            FROM Task 
            WHERE WhatId IN :allAffectedOppIds 
              AND IsClosed = false 
            WITH SYSTEM_MODE
        ];
        for (Task t : tasksToClose) {
            t.Status = 'Completed';
        }
        if (!tasksToClose.isEmpty()) {
            Database.update(tasksToClose, AccessLevel.SYSTEM_MODE);
        }

        Task newFollowUpTask = new Task(
            Subject = 'Call Customer - New Opportunity Created',
            TaskSubtype = 'Call',
            OwnerId = ownerId,
            WhatId = awardedOppId,
            Status = 'Nurture'
        );

        Datetime nowTime = Datetime.now();
        if (nowTime.hour() < 14) {
            newFollowUpTask.Description = 'An opportunity has been created , make sure to call at 5PM';
            newFollowUpTask.Follow_Up_Date_Time__c = Datetime.newInstance(nowTime.date(), Time.newInstance(17, 0, 0, 0));
        } else {
            newFollowUpTask.Description = 'An opportunity has been created , make sure to call at 10AM tomorrow';
            newFollowUpTask.Follow_Up_Date_Time__c = Datetime.newInstance(nowTime.date().addDays(1), Time.newInstance(10, 0, 0, 0));
        }

        Database.insert(newFollowUpTask, AccessLevel.SYSTEM_MODE);
    }

    public static Id createAddressBookAndJunction(Id accountId, Id opportunityId, Map<String, Object> addressData) {
        if (addressData == null || addressData.isEmpty()) {
            return null;
        }

        Address_Book__c ab = new Address_Book__c();
        ab.Account__c = accountId;
        if (addressData.containsKey('Street__c'))  ab.Street__c  = (String) addressData.get('Street__c');
        if (addressData.containsKey('City__c'))    ab.City__c    = (String) addressData.get('City__c');
        if (addressData.containsKey('State__c'))   ab.State__c   = (String) addressData.get('State__c');
        if (addressData.containsKey('Country__c')) ab.Country__c = (String) addressData.get('Country__c');
        if (addressData.containsKey('PIN__c'))     ab.PIN__c     = (String) addressData.get('PIN__c');
        if (addressData.containsKey('Zone__c'))    ab.Zone__c    = (String) addressData.get('Zone__c');
        if (addressData.containsKey('Primary_Address__c')) {
            ab.Primary_Address__c = (Boolean) addressData.get('Primary_Address__c');
        }
        insert as system ab;

        Opportunity_Address_Junc__c junc = new Opportunity_Address_Junc__c(
            Opportunity__c = opportunityId,
            Address_Book__c = ab.Id
        );
        insert as system junc;

        return ab.Id;
    }

    @AuraEnabled(cacheable=true)
    public static String getOpportunityDepartment(Id opportunityId) {
        Opportunity opp = [
            SELECT Department_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];
        return opp.Department_Name__c;
    }
}