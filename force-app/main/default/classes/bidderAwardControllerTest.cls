@isTest
public class bidderAwardControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Test Account & Contact
        Account acc = new Account(
            Name = 'Test Company',
            Phone = '1234567890',
            Email__c = 'test@example.com',
            BillingCity = 'New York'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            AccountId = acc.Id,
            Email = 'test@example.com',
            Phone = '1234567890'
        );
        insert con;

        // 2. Create Bidder & Contact Details
        Bidders__c bidder = new Bidders__c(Name = 'Test Bidder');
        insert bidder;

        Bidders_Contact_Details__c bidderContact = new Bidders_Contact_Details__c(
            Name = 'Test Bidder Contact',
            Bidders__c = bidder.Id,
            Contact_Number__c = '9876543210',
            Email__c = 'bidder@example.com'
        );
        insert bidderContact;

        // Bidder without Contact Details (to cover null branch)
        Bidders__c emptyBidder = new Bidders__c(Name = 'Empty Bidder');
        insert emptyBidder;

        // 3. Resolve Opportunity Record Type safely
        Id recTypeId;
        Map<String, Schema.RecordTypeInfo> oppRecordTypes = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
        if (oppRecordTypes.containsKey('Project_Opportunity')) {
            recTypeId = oppRecordTypes.get('Project_Opportunity').getRecordTypeId();
        }

        // 4. Create Opportunities with Amount populated
        Opportunity parentOpp = new Opportunity(
            Name = 'Parent Opp',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Amount = 50000,
            Department_Name__c = 'Steel Pipes',
            RecordTypeId = recTypeId
        );
        insert parentOpp;

        Opportunity awardedOpp = new Opportunity(
            Name = 'Awarded Opp',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Parent_Opportunity__c = parentOpp.Id,
            Bidder__c = bidder.Id,
            Department_Name__c = 'Steel Pipes',
            Amount = 25000,
            RecordTypeId = recTypeId
        );
        insert awardedOpp;

        Opportunity siblingOpp = new Opportunity(
            Name = 'Sibling Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Parent_Opportunity__c = parentOpp.Id,
            Amount = 15000,
            RecordTypeId = recTypeId
        );
        insert siblingOpp;

        // Opportunity without Parent (to test solo award branch)
        Opportunity soloOpp = new Opportunity(
            Name = 'Solo Opp',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Department_Name__c = 'Steel Pipes',
            Amount = 10000,
            RecordTypeId = recTypeId
        );
        insert soloOpp;

        // Opportunity without Amount (to test Amount validation)
        Opportunity noAmountOpp = new Opportunity(
            Name = 'No Amount Opp',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Department_Name__c = 'Steel Pipes',
            RecordTypeId = recTypeId
        );
        insert noAmountOpp;

        // Opportunity with Bidder having no details
        Opportunity oppWithEmptyBidder = new Opportunity(
            Name = 'Empty Bidder Opp',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            Bidder__c = emptyBidder.Id,
            Amount = 10000,
            RecordTypeId = recTypeId
        );
        insert oppWithEmptyBidder;

        // 5. Create Open Tasks
        Task parentTask = new Task(
            Subject = 'Parent Task',
            WhatId = parentOpp.Id,
            Status = 'Open'
        );
        insert parentTask;
    }

    // =========================================================================
    // 1. SAVE & AWARD SCENARIOS
    // =========================================================================

    @isTest
    static void testSaveAndAward_NewAccount_ManualContact() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];
        Opportunity parentOpp = [SELECT Id FROM Opportunity WHERE Name = 'Parent Opp' LIMIT 1];

        bidderAwardController.AwardRequestWrapper req = new bidderAwardController.AwardRequestWrapper();
        req.opportunityId = opp.Id;
        req.isExistingAccount = false;
        req.newAccountName = 'Brand New Account Ltd';
        req.newAccountPhone = '1122334455';
        req.newAccountEmail = 'info@newaccount.com';

        req.contactMode = 'manual';
        req.contactFirstName = 'John';
        req.contactLastName = 'Doe';
        req.contactPhone = '9988776655';
        req.contactEmail = 'john.doe@newaccount.com';

        req.newAddressData = new Map<String, Object>{
            'Street__c' => '123 New St',
            'City__c' => 'Kolkata',
            'State__c' => 'West Bengal',
            'Country__c' => 'India',
            'PIN__c' => '700001',
            'Zone__c' => 'East',
            'Primary_Address__c' => true
        };

        Product_Category__c pc = new Product_Category__c(
            Department_Name__c = 'Steel Pipes',
            Product_Category__c = 'ERW Hollow Section Pipes',
            UOM__c = 'MT',
            Quantity__c = 10
        );
        req.productCategories = new List<Product_Category__c>{ pc };

        Test.startTest();
        bidderAwardController.saveAndAwardOpportunity(req);
        Test.stopTest();

        // 1. Verify New Account created and linked to Opp
        Opportunity updatedOpp = [SELECT Id, AccountId, Account.Name, RecordType.DeveloperName, Opportunity_Source__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, updatedOpp.AccountId, 'Account should be assigned to Opportunity.');
        System.assertEquals('Brand New Account Ltd', updatedOpp.Account.Name, 'Account name should match payload.');
        System.assertEquals('Master_Opportunity', updatedOpp.RecordType.DeveloperName, 'Record Type must be Master_Opportunity.');
        System.assertEquals('TENDER', updatedOpp.Opportunity_Source__c, 'Source should be TENDER.');

        // 2. Verify Manual Contact and OCR created
        Contact con = [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE Email = 'john.doe@newaccount.com' LIMIT 1];
        System.assertEquals('Doe', con.LastName, 'Contact LastName should match.');
        System.assertEquals(updatedOpp.AccountId, con.AccountId, 'Contact should belong to new Account.');

        List<OpportunityContactRole> ocrs = [SELECT Id, IsPrimary FROM OpportunityContactRole WHERE OpportunityId = :opp.Id AND ContactId = :con.Id];
        System.assertEquals(1, ocrs.size(), 'OCR should be created.');
        System.assertEquals(true, ocrs[0].IsPrimary, 'OCR should be Primary.');

        // 3. Verify Product Categories inserted
        List<Product_Category__c> insertedPcs = [SELECT Id, Opportunity__c, Quantity__c FROM Product_Category__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, insertedPcs.size(), 'Product Category should be inserted.');
        System.assertEquals(10, insertedPcs[0].Quantity__c);

        // 4. Verify Parent and Sibling Opps closed
        Opportunity updatedParent = [SELECT StageName, Lost_Reason__c FROM Opportunity WHERE Id = :parentOpp.Id];
        System.assertEquals('Closed Lost', updatedParent.StageName, 'Parent Opp should be Closed Lost.');
        System.assertEquals('Tender lost', updatedParent.Lost_Reason__c);

        // 5. Verify Tasks closed and new task created
        List<Task> closedTasks = [SELECT Id, Status FROM Task WHERE WhatId = :parentOpp.Id];
        System.assertEquals('Completed', closedTasks[0].Status, 'Parent tasks must be completed.');

        List<Task> newTasks = [SELECT Id, Status, Subject FROM Task WHERE WhatId = :opp.Id];
        System.assert(newTasks.size() > 0, 'Follow-up task should be created.');
        System.assertEquals('Nurture', newTasks[0].Status);
    }

    @isTest
    static void testSaveAndAward_ExistingAccount_BidderContact() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];

        bidderAwardController.AwardRequestWrapper req = new bidderAwardController.AwardRequestWrapper();
        req.opportunityId = opp.Id;
        req.isExistingAccount = true;
        req.selectedAccountId = acc.Id;
        req.contactMode = 'bidder';
        req.selectedAddressBookId = 'a00000000000000AAA'; // Dummy address book ID to skip new address creation
        req.productCategories = null; // Test null product category branch

        Test.startTest();
        bidderAwardController.saveAndAwardOpportunity(req);
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, AccountId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(acc.Id, updatedOpp.AccountId, 'Existing Account should be linked.');

        // Check that Contact was created from bidder contact details
        Contact bidderCon = [SELECT Id, LastName, AccountId FROM Contact WHERE Email = 'bidder@example.com' LIMIT 1];
        System.assertEquals('Test Bidder Contact', bidderCon.LastName);
        System.assertEquals(acc.Id, bidderCon.AccountId);
    }

    @isTest
    static void testSaveAndAward_ExistingContact_SoloOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        Opportunity soloOpp = [SELECT Id FROM Opportunity WHERE Name = 'Solo Opp' LIMIT 1];

        bidderAwardController.AwardRequestWrapper req = new bidderAwardController.AwardRequestWrapper();
        req.opportunityId = soloOpp.Id;
        req.isExistingAccount = true;
        req.selectedAccountId = acc.Id;
        req.contactMode = 'existing';
        req.selectedContactId = con.Id;
        req.newAddressData = null;
        req.productCategories = new List<Product_Category__c>();

        Test.startTest();
        bidderAwardController.saveAndAwardOpportunity(req);
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, AccountId, RecordType.DeveloperName FROM Opportunity WHERE Id = :soloOpp.Id];
        System.assertEquals(acc.Id, updatedOpp.AccountId);
        System.assertEquals('Master_Opportunity', updatedOpp.RecordType.DeveloperName);
    }

    @isTest
    static void testSaveAndAward_ExistingOCRBranch() {
        // Pre-create OCR to test the `if (existingRoles.isEmpty())` false branch
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        Opportunity soloOpp = [SELECT Id FROM Opportunity WHERE Name = 'Solo Opp' LIMIT 1];

        OpportunityContactRole existingOcr = new OpportunityContactRole(
            OpportunityId = soloOpp.Id,
            ContactId = con.Id,
            IsPrimary = false
        );
        insert existingOcr;

        bidderAwardController.AwardRequestWrapper req = new bidderAwardController.AwardRequestWrapper();
        req.opportunityId = soloOpp.Id;
        req.isExistingAccount = true;
        req.selectedAccountId = acc.Id;
        req.contactMode = 'existing';
        req.selectedContactId = con.Id;

        Test.startTest();
        bidderAwardController.saveAndAwardOpportunity(req);
        Test.stopTest();

        List<OpportunityContactRole> ocrs = [SELECT Id FROM OpportunityContactRole WHERE OpportunityId = :soloOpp.Id AND ContactId = :con.Id];
        System.assertEquals(1, ocrs.size(), 'Should not duplicate OCR if already existing.');
    }

    // =========================================================================
    // 2. VALIDATION & ROLLBACK TESTS
    // =========================================================================

    @isTest
    static void testSaveAndAward_ValidationFailures() {
        // 1. Test null request
        try {
            bidderAwardController.saveAndAwardOpportunity(null);
            System.assert(false, 'Should have thrown exception for null request.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 2. Test null opportunityId
        bidderAwardController.AwardRequestWrapper emptyReq = new bidderAwardController.AwardRequestWrapper();
        try {
            bidderAwardController.saveAndAwardOpportunity(emptyReq);
            System.assert(false, 'Should have thrown exception for missing opportunityId.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 3. Test Opportunity Amount is null
        Opportunity noAmountOpp = [SELECT Id FROM Opportunity WHERE Name = 'No Amount Opp' LIMIT 1];
        bidderAwardController.AwardRequestWrapper reqNoAmount = new bidderAwardController.AwardRequestWrapper();
        reqNoAmount.opportunityId = noAmountOpp.Id;
        try {
            bidderAwardController.saveAndAwardOpportunity(reqNoAmount);
            System.assert(false, 'Should have thrown exception for null Amount.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 4. Test Opportunity Amount < 1
        noAmountOpp.Amount = 0;
        update noAmountOpp;
        try {
            bidderAwardController.saveAndAwardOpportunity(reqNoAmount);
            System.assert(false, 'Should have thrown exception for 0 Amount.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testSaveAndAward_BlankDepartmentThrows() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Solo Opp' LIMIT 1];
        opp.Department_Name__c = null;
        update opp;

        bidderAwardController.AwardRequestWrapper req = new bidderAwardController.AwardRequestWrapper();
        req.opportunityId = opp.Id;
        req.isExistingAccount = false;
        req.newAccountName = 'Should Rollback Account';

        Test.startTest();
        try {
            bidderAwardController.saveAndAwardOpportunity(req);
            System.assert(false, 'Should have failed due to blank department in notification step.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        // Verify Savepoint Rollback: The account created in Step 1 should have been rolled back
        List<Account> rolledBackAccs = [SELECT Id FROM Account WHERE Name = 'Should Rollback Account'];
        System.assertEquals(0, rolledBackAccs.size(), 'Transaction should have rolled back completely.');
    }

    // =========================================================================
    // 3. HELPER METHODS TESTS
    // =========================================================================

    @isTest
    static void testGetBidderName() {
        Opportunity oppWithBidder = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];
        Opportunity oppWithoutBidder = [SELECT Id FROM Opportunity WHERE Name = 'Solo Opp' LIMIT 1];

        Test.startTest();
        String name1 = bidderAwardController.getBidderName(oppWithBidder.Id);
        String name2 = bidderAwardController.getBidderName(oppWithoutBidder.Id);
        Test.stopTest();

        System.assertEquals('Test Bidder', name1);
        System.assertEquals(null, name2);
    }

    @isTest
    static void testSearchAccounts() {
        Test.startTest();
        List<Account> resEmpty = bidderAwardController.searchAccounts('');
        List<Account> resShort = bidderAwardController.searchAccounts('A');
        List<Account> resValid = bidderAwardController.searchAccounts('Test');
        Test.stopTest();

        System.assertEquals(0, resEmpty.size());
        System.assertEquals(0, resShort.size());
        System.assert(resValid.size() > 0);
    }

    @isTest
    static void testFindDuplicateAccounts() {
        Test.startTest();
        List<Account> duplicates = bidderAwardController.findDuplicateAccounts('Test Company', '1234567890', 'test@example.com');
        Test.stopTest();

        System.assertNotEquals(null, duplicates);
    }

    @isTest
    static void testGetAccountContacts() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];

        Test.startTest();
        List<Contact> contacts = bidderAwardController.getAccountContacts(acc.Id);
        Test.stopTest();

        System.assertEquals(1, contacts.size());
        System.assertEquals('test@example.com', contacts[0].Email);
    }

    @isTest
    static void testGetBidderContactDetails() {
        Opportunity awardedOpp = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];
        Opportunity soloOpp = [SELECT Id FROM Opportunity WHERE Name = 'Solo Opp' LIMIT 1];
        Opportunity emptyBidderOpp = [SELECT Id FROM Opportunity WHERE Name = 'Empty Bidder Opp' LIMIT 1];

        Test.startTest();
        Bidders_Contact_Details__c details = bidderAwardController.getBidderContactDetails(awardedOpp.Id);
        Bidders_Contact_Details__c nullDetails1 = bidderAwardController.getBidderContactDetails(soloOpp.Id);
        Bidders_Contact_Details__c nullDetails2 = bidderAwardController.getBidderContactDetails(emptyBidderOpp.Id);
        Test.stopTest();

        System.assertNotEquals(null, details);
        System.assertEquals('bidder@example.com', details.Email__c);
        System.assertEquals(null, nullDetails1);
        System.assertEquals(null, nullDetails2);
    }

    @isTest
    static void testHandleRelatedTasks_Guards() {
        // Exercise early returns for defensive coverage
        Test.startTest();
        bidderAwardController.handleRelatedTasks(new Set<Id>(), null, null);
        bidderAwardController.handleRelatedTasks(new Set<Id>{UserInfo.getUserId()}, null, null);
        bidderAwardController.handleRelatedTasks(new Set<Id>{UserInfo.getUserId()}, UserInfo.getUserId(), null);
        Test.stopTest();
    }

    @isTest
    static void testCreateAddressBookAndJunction() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];

        Map<String, Object> addressData = new Map<String, Object>{
            'Street__c' => '456 Park St',
            'City__c' => 'Mumbai',
            'State__c' => 'Maharashtra',
            'Country__c' => 'India',
            'PIN__c' => '400001',
            'Zone__c' => 'West',
            'Primary_Address__c' => true
        };

        Test.startTest();
        Id nullId1 = bidderAwardController.createAddressBookAndJunction(acc.Id, opp.Id, null);
        Id nullId2 = bidderAwardController.createAddressBookAndJunction(acc.Id, opp.Id, new Map<String, Object>());
        Id abId = bidderAwardController.createAddressBookAndJunction(acc.Id, opp.Id, addressData);
        Test.stopTest();

        System.assertEquals(null, nullId1);
        System.assertEquals(null, nullId2);
        System.assertNotEquals(null, abId);

        List<Opportunity_Address_Junc__c> juncs = [SELECT Id FROM Opportunity_Address_Junc__c WHERE Address_Book__c = :abId];
        System.assertEquals(1, juncs.size());
    }

    @isTest
    static void testGetOpportunityDepartment() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Awarded Opp' LIMIT 1];

        Test.startTest();
        String dept = bidderAwardController.getOpportunityDepartment(opp.Id);
        Test.stopTest();

        System.assertEquals('Steel Pipes', dept);
    }

    @isTest
    static void testAwardRequestWrapperGettersSetters() {
        // Exercise all getters and setters in the wrapper class
        bidderAwardController.AwardRequestWrapper w = new bidderAwardController.AwardRequestWrapper();
        w.opportunityId = '006000000000000AAA';
        w.isExistingAccount = true;
        w.selectedAccountId = '001000000000000AAA';
        w.newAccountName = 'Name';
        w.newAccountPhone = '123';
        w.newAccountEmail = 'a@b.com';
        w.contactMode = 'manual';
        w.selectedContactId = '003000000000000AAA';
        w.contactFirstName = 'First';
        w.contactLastName = 'Last';
        w.contactPhone = '456';
        w.contactEmail = 'c@d.com';
        w.selectedAddressBookId = 'a00000000000000AAA';
        w.newAddressData = new Map<String, Object>();
        w.productCategories = new List<Product_Category__c>();

        System.assertEquals('006000000000000AAA', w.opportunityId);
        System.assertEquals(true, w.isExistingAccount);
        System.assertEquals('001000000000000AAA', w.selectedAccountId);
        System.assertEquals('Name', w.newAccountName);
        System.assertEquals('123', w.newAccountPhone);
        System.assertEquals('a@b.com', w.newAccountEmail);
        System.assertEquals('manual', w.contactMode);
        System.assertEquals('003000000000000AAA', w.selectedContactId);
        System.assertEquals('First', w.contactFirstName);
        System.assertEquals('Last', w.contactLastName);
        System.assertEquals('456', w.contactPhone);
        System.assertEquals('c@d.com', w.contactEmail);
        System.assertEquals('a00000000000000AAA', w.selectedAddressBookId);
        System.assertNotEquals(null, w.newAddressData);
        System.assertNotEquals(null, w.productCategories);
    }
}