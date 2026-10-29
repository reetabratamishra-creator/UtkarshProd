/**
 * CaseCreationControllerTest
 *
 * Two org-specific things shape this class:
 *
 * 1. User DML cannot share a transaction with Account/Contact/Opportunity DML, so the
 *    test user is inserted inside System.runAs to dodge MIXED_DML_OPERATION.
 * 2. The before-save flow "Case : Update Department on Creation of Case Origin of Email"
 *    nulls OwnerId when Origin is Email, which fails the insert. pickOrigin() therefore
 *    avoids Email so these tests exercise the controller rather than that flow.
 */
@IsTest
private class CaseCreationControllerTest {

    private static final String DEPT             = 'Service';
    private static final String PRIMARY_LAST     = 'Das';
    private static final String NO_EMAIL_LAST    = 'Bose';
    private static final String OTHER_ACC_LAST   = 'Roy';

    // ------------------------------------------------------------------
    // Setup
    // ------------------------------------------------------------------
    @TestSetup
    static void setup() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Utkarsh Test Account'),
            new Account(Name = 'Unrelated Test Account')
        };
        insert accounts;

        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Ravi', LastName = 'Kumar', AccountId = accounts[0].Id,
                        Phone = '9830000000', Email = 'ravi.kumar@example.com'),
            new Contact(FirstName = 'Sunita', LastName = PRIMARY_LAST, AccountId = accounts[0].Id,
                        Phone = '9831111111', Email = 'sunita.das@example.com'),
            // No email - must be linked but never emailed.
            new Contact(FirstName = 'Anil', LastName = NO_EMAIL_LAST, AccountId = accounts[0].Id),
            // Sits under a different account but carries a contact role on the opportunity.
            new Contact(FirstName = 'Priya', LastName = OTHER_ACC_LAST, AccountId = accounts[1].Id,
                        Email = 'priya.roy@example.com')
        };
        insert contacts;

        Opportunity opp = new Opportunity(
            Name      = 'Highmast Supply',
            AccountId = accounts[0].Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        insert new List<OpportunityContactRole>{
            new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contacts[1].Id,
                                       Role = 'Decision Maker', IsPrimary = true),
            new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contacts[0].Id,
                                       Role = 'Influencer', IsPrimary = false),
            new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contacts[3].Id,
                                       Role = 'Technical Buyer', IsPrimary = false)
        };

        // Dynamically fetch a valid department so restricted picklist rules do not fail the insert
        String validDept = getValidDepartment();
        
        // User DML must not mix with the sObject DML above.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            insert new User(
                FirstName = 'Dept',
                LastName  = 'Owner',
                Alias     = 'downer',
                Email     = 'dept.owner@example.com',
                Username  = 'dept.owner' + DateTime.now().getTime() + '@casetest.example.com',
                ProfileId = p.Id,
                Department = 'Sales;' + validDept + ';Logistics',
                TimeZoneSidKey    = 'Asia/Kolkata',
                LocaleSidKey      = 'en_IN',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /** Restricted picklists differ per org, so pull a value that is guaranteed valid. */
    private static String firstPicklistValue(String fieldApiName) {
        for (Schema.PicklistEntry e : Schema.SObjectType.Case.fields.getMap()
                .get(fieldApiName).getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    /** Fetches an active Department value dynamically so tests survive picklist changes. */
    private static String getValidDepartment() {
        String val = firstPicklistValue('Department__c');
        return String.isNotBlank(val) ? val : DEPT;
    }

    /** Any active Origin except Email - see the class comment for why. */
    private static String pickOrigin() {
        String fallback;
        for (Schema.PicklistEntry e : Schema.SObjectType.Case.fields.getMap()
                .get('Origin').getDescribe().getPicklistValues()) {
            if (!e.isActive()) {
                continue;
            }
            if (fallback == null) {
                fallback = e.getValue();
            }
            if (!'Email'.equalsIgnoreCase(e.getValue())) {
                return e.getValue();
            }
        }
        return fallback;
    }

    /**
     * The "Case" record type has to exist for a case to be saved. Where that matters
     * the tests assert the explicit failure instead of the happy path, so the suite
     * still tells the truth in an org that has not been configured yet.
     */
    private static Boolean recordTypeExists() {
        return ![
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Case' AND DeveloperName = 'Case' AND IsActive = TRUE
        ].isEmpty();
    }

    private static Boolean createThrows(CaseCreationController.CaseRequest req) {
        try {
            CaseCreationController.createCase(req);
            return false;
        } catch (AuraHandledException e) {
            return true;
        }
    }

    private static Boolean fieldExists(String fieldApiName) {
        return Schema.SObjectType.Case.fields.getMap().containsKey(fieldApiName.toLowerCase());
    }

    private static Boolean templateExists() {
        return ![SELECT Id FROM EmailTemplate WHERE Name = 'Case Creation Template' LIMIT 1].isEmpty();
    }

    private static Account mainAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Utkarsh Test Account' LIMIT 1];
    }

    private static User assignee() {
        return [SELECT Id, Name FROM User WHERE Alias = 'downer' LIMIT 1];
    }

    private static CaseCreationController.CaseRequest buildRequest(List<Id> contactIds, Id assigneeId) {
        CaseCreationController.CaseRequest req = new CaseCreationController.CaseRequest();
        req.assignedToId = assigneeId;
        req.contactIds   = new List<String>();
        for (Id cid : contactIds) {
            req.contactIds.add(String.valueOf(cid));
        }
        req.department    = getValidDepartment();
        req.subDepartment = null;
        req.origin        = pickOrigin();
        req.caseType      = firstPicklistValue('Type');
        req.subCategory   = null;
        req.priority      = firstPicklistValue('Priority');
        req.subject       = 'Damaged consignment received';
        req.description   = 'Two poles arrived with dents.';
        req.comments      = 'Photos shared by the customer.';
        req.customerName  = 'Ravi Kumar';
        req.documentIds   = new List<String>();
        return req;
    }

    // ------------------------------------------------------------------
    // Picklists
    // ------------------------------------------------------------------
    @IsTest
    static void returnsEveryFormPicklist() {
        Test.startTest();
        List<CaseCreationController.PicklistField> fields = CaseCreationController.getFormPicklists();
        Test.stopTest();

        Map<String, CaseCreationController.PicklistField> byName =
            new Map<String, CaseCreationController.PicklistField>();
        for (CaseCreationController.PicklistField f : fields) {
            byName.put(f.fieldApiName, f);
        }

        System.assertEquals(6, fields.size(), 'Six picklists are requested by the form');
        System.assertEquals(false, byName.get('Origin').options.isEmpty(),
            'Origin values expected. Diagnostic: ' + byName.get('Origin').diagnostic);
        System.assertEquals(false, byName.get('Type').options.isEmpty(),
            'Type values expected. Diagnostic: ' + byName.get('Type').diagnostic);
        System.assertEquals(false, byName.get('Priority').options.isEmpty(),
            'Priority values expected. Diagnostic: ' + byName.get('Priority').diagnostic);
        System.assertNotEquals(null, byName.get('Sub_Department__c').options,
            'A missing or empty picklist returns an empty list, never null');
    }

    @IsTest
    static void reportsAReasonWhenAPicklistIsEmpty() {
        Test.startTest();
        List<CaseCreationController.PicklistField> fields = CaseCreationController.getFormPicklists();
        Test.stopTest();

        for (CaseCreationController.PicklistField f : fields) {
            if (f.options.isEmpty()) {
                System.assertNotEquals(null, f.diagnostic,
                    f.fieldApiName + ' came back empty without saying why');
            }
        }
    }

    // ------------------------------------------------------------------
    // Lookups
    // ------------------------------------------------------------------
    @IsTest
    static void returnsContactsForTheAccount() {
        Account a = mainAccount();

        Test.startTest();
        List<CaseCreationController.ContactOption> contacts =
            CaseCreationController.getContactsForAccount(a.Id);
        Test.stopTest();

        System.assertEquals(3, contacts.size(),
            'Three contacts sit under this account; the fourth belongs elsewhere');
        for (CaseCreationController.ContactOption o : contacts) {
            System.assertEquals(false, o.isPrimary, 'Nothing is primary outside opportunity mode');
        }
    }

    @IsTest
    static void returnsNoContactsForANullAccount() {
        Test.startTest();
        List<CaseCreationController.ContactOption> contacts =
            CaseCreationController.getContactsForAccount(null);
        Test.stopTest();

        System.assertEquals(true, contacts.isEmpty(), 'A null account returns an empty list, not an error');
    }

    @IsTest
    static void matchesUsersWhoseDepartmentContainsTheValue() {
        User expected = assignee();
        String validDept = getValidDepartment();

        Test.startTest();
        List<CaseCreationController.Option> users = CaseCreationController.getUsersByDepartment(validDept);
        List<CaseCreationController.Option> none  = CaseCreationController.getUsersByDepartment('');
        Test.stopTest();

        System.assertEquals(false, users.isEmpty(),
            'A user carrying the department should match on contains');
        System.assertEquals(true, none.isEmpty(), 'A blank department returns nothing');

        Boolean found = false;
        for (CaseCreationController.Option o : users) {
            if (o.value == String.valueOf(expected.Id)) {
                found = true;
                System.assertEquals(expected.Name, o.label,
                    'The label is the user name alone - no department suffix');
            }
        }
        System.assertEquals(true, found, 'The department user should be offered');
    }

    @IsTest
    static void hidesEnquiryFromTheDepartmentPicklist() {
        Test.startTest();
        List<CaseCreationController.PicklistField> fields = CaseCreationController.getFormPicklists();
        Test.stopTest();

        for (CaseCreationController.PicklistField f : fields) {
            if (f.fieldApiName != 'Department__c') {
                continue;
            }
            for (CaseCreationController.Option o : f.options) {
                System.assertNotEquals('Enquiry', o.value,
                    'Enquiry is reserved for automation and must not be offered on the form');
            }
        }
    }

    // ------------------------------------------------------------------
    // Opportunity context
    // ------------------------------------------------------------------
    @IsTest
    static void listsAccountContactsAndPreselectsThePrimaryRole() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Contact primary = [SELECT Id FROM Contact WHERE LastName = :PRIMARY_LAST LIMIT 1];

        Test.startTest();
        CaseCreationController.OpportunityContext context =
            CaseCreationController.getOpportunityContext(opp.Id);
        Test.stopTest();

        System.assertEquals(opp.AccountId, context.accountId, 'Context carries the opportunity account');
        System.assertEquals('Utkarsh Test Account', context.accountName, 'Account name is returned for display');
        System.assertEquals(1, context.preselectedIds.size(), 'Only the primary role is preselected');
        System.assertEquals(String.valueOf(primary.Id), context.preselectedIds[0],
            'The primary contact role is the preselected one');

        // Three account contacts plus the role holder from the other account.
        System.assertEquals(4, context.contacts.size(),
            'Contact roles pointing outside the account must be appended, not dropped');

        Boolean foundOutsider = false;
        Boolean primaryFlagged = false;
        for (CaseCreationController.ContactOption o : context.contacts) {
            if (o.name.endsWith(OTHER_ACC_LAST)) {
                foundOutsider = true;
                System.assertEquals('Technical Buyer', o.role, 'The role label travels with the contact');
            }
            if (o.value == String.valueOf(primary.Id)) {
                primaryFlagged = true;
                System.assertEquals(true, o.isPrimary, 'The primary contact must be flagged');
            }
        }
        System.assertEquals(true, foundOutsider, 'The out-of-account role holder should be listed');
        System.assertEquals(true, primaryFlagged, 'The primary contact should be in the list');
    }

    @IsTest
    static void returnsEmptyContextForANullOpportunity() {
        Test.startTest();
        CaseCreationController.OpportunityContext context =
            CaseCreationController.getOpportunityContext(null);
        Test.stopTest();

        System.assertEquals(true, context.contacts.isEmpty(), 'No opportunity means no contacts');
        System.assertEquals(true, context.preselectedIds.isEmpty(), 'Nothing to preselect');
    }

    // ------------------------------------------------------------------
    // Contact creation
    // ------------------------------------------------------------------
    @IsTest
    static void createsContactUnderTheSelectedAccount() {
        Account a = mainAccount();

        Test.startTest();
        CaseCreationController.ContactOption created = CaseCreationController.createContact(
            a.Id, null, 'Meera', 'Sen', '9832222222', 'meera.sen@example.com'
        );
        Test.stopTest();

        Contact c = [SELECT AccountId, Phone, Email FROM Contact WHERE Id = :created.value];
        System.assertEquals(a.Id, c.AccountId, 'The contact hangs off the selected account');
        System.assertEquals('9832222222', created.phone, 'Business phone is returned for the table');
        System.assertEquals('meera.sen@example.com', created.email, 'Email is returned for the table');
    }

    @IsTest
    static void createsContactUnderTheOpportunityAccount() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Test.startTest();
        CaseCreationController.ContactOption created = CaseCreationController.createContact(
            null, opp.Id, 'Arjun', 'Ghosh', null, null
        );
        Test.stopTest();

        Contact c = [SELECT AccountId FROM Contact WHERE Id = :created.value];
        System.assertEquals(opp.AccountId, c.AccountId,
            'In opportunity mode the account is resolved from the opportunity');
    }

    @IsTest
    static void rejectsAContactWithNoAccountAndNoOpportunity() {
        Boolean threw = false;
        Test.startTest();
        try {
            CaseCreationController.createContact(null, null, 'No', 'Parent', null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A contact needs somewhere to live');
    }

    @IsTest
    static void rejectsAContactWithoutALastName() {
        Account a = mainAccount();
        Boolean threw = false;

        Test.startTest();
        try {
            CaseCreationController.createContact(a.Id, null, 'Only', null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Last name is mandatory on Contact');
    }

    // ------------------------------------------------------------------
    // Case creation - account mode
    // ------------------------------------------------------------------
    @IsTest
    static void createsCaseAndLinksEverySelectedContact() {
        Account a = mainAccount();
        List<Contact> contacts = [
            SELECT Id FROM Contact WHERE AccountId = :a.Id ORDER BY LastName
        ];
        User owner = assignee();

        CaseCreationController.CaseRequest req = buildRequest(
            new List<Id>{ contacts[0].Id, contacts[1].Id, contacts[2].Id }, owner.Id
        );
        req.accountId = a.Id;

        if (!recordTypeExists()) {
            Test.startTest();
            System.assertEquals(true, createThrows(req),
                'Without the "Case" record type the save must fail loudly');
            Test.stopTest();
            return;
        }

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        Case created = [
            SELECT AccountId, ContactId, OwnerId, Status, Subject, Description, Priority, RecordTypeId
            FROM Case WHERE Id = :result.caseId
        ];
        System.assertEquals(CaseCreationController.caseRecordTypeId(), created.RecordTypeId,
            'Complaints must carry the "Case" record type');
        System.assertEquals(a.Id, created.AccountId, 'Account is stamped on the case');
        System.assertEquals(null, created.ContactId,
            'Contacts live on the junction; Case.ContactId stays empty');
        System.assertEquals(owner.Id, created.OwnerId, 'The selected assignee owns the case');
        

        List<Case_Contacts__c> links = [
            SELECT Contact__c FROM Case_Contacts__c WHERE Case__c = :result.caseId
        ];
        System.assertEquals(3, links.size(), 'One junction row per selected contact');
    }

    @IsTest
    static void defaultsOwnerToTheCreatorWhenNoAssigneeIsChosen() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ c.Id }, null);
        req.accountId = a.Id;

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        Case created = [SELECT OwnerId FROM Case WHERE Id = :result.caseId];
        System.assertEquals(UserInfo.getUserId(), created.OwnerId, 'Owner falls back to the creator');
        System.assertEquals(false, result.ownerChanged, 'Creator and owner are the same here');
    }

    @IsTest
    static void dropsDuplicateAndMalformedContactIds() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ c.Id }, null);
        req.accountId = a.Id;
        req.contactIds.add(String.valueOf(c.Id)); // duplicate
        req.contactIds.add('');                   // blank
        req.contactIds.add('   ');                // whitespace
        req.contactIds.add('not-an-id');          // junk

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(1, result.contactsLinked, 'Duplicates, blanks and junk are dropped');
        System.assertEquals(1, [
            SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId
        ], 'Only one junction row is written');
    }

    @IsTest
    static void savesTheCaseWhenNoContactsAreSelected() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        CaseCreationController.CaseRequest req = buildRequest(new List<Id>(), null);
        req.accountId = a.Id;

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(0, result.contactsLinked, 'Nothing to link');
        System.assertEquals(0, result.emailsSent, 'Nobody to email');
        System.assertNotEquals(null, result.caseId, 'The case is still created');
    }

    // ------------------------------------------------------------------
    // Case creation - opportunity mode
    // ------------------------------------------------------------------
    @IsTest
    static void resolvesTheAccountFromTheOpportunity() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Contact primary = [SELECT Id FROM Contact WHERE LastName = :PRIMARY_LAST LIMIT 1];

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ primary.Id }, null);
        req.opportunityId = opp.Id;   // no accountId at all

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        Case created = [SELECT AccountId FROM Case WHERE Id = :result.caseId];
        System.assertEquals(opp.AccountId, created.AccountId,
            'The account must be resolved server side, not sent by the browser');

        
    }

    // ------------------------------------------------------------------
    // Validation
    // ------------------------------------------------------------------
    @IsTest
    static void rejectsARequestWithNoSubject() {
        Account a = mainAccount();
        CaseCreationController.CaseRequest req = buildRequest(new List<Id>(), null);
        req.accountId = a.Id;
        req.subject = null;

        Boolean threw = false;
        Test.startTest();
        try {
            CaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Subject is mandatory');
    }

    @IsTest
    static void rejectsARequestWithNeitherAccountNorOpportunity() {
        CaseCreationController.CaseRequest req = buildRequest(new List<Id>(), null);

        Boolean threw = false;
        Test.startTest();
        try {
            CaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'The case needs something to hang off');
    }

    @IsTest
    static void rejectsANullRequest() {
        Boolean threw = false;
        Test.startTest();
        try {
            CaseCreationController.createCase(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A null request is rejected rather than NPEd');
    }

    @IsTest
    static void rejectsAMalformedAssignee() {
        Account a = mainAccount();
        CaseCreationController.CaseRequest req = buildRequest(new List<Id>(), null);
        req.accountId = a.Id;
        req.assignedToId = 'definitely-not-an-id';

        Boolean threw = false;
        Test.startTest();
        try {
            CaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A malformed assignee is caught before the insert');
    }

    // ------------------------------------------------------------------
    // Email
    // ------------------------------------------------------------------
    @IsTest
    static void emailsOnlyTheContactsThatHaveAnAddress() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        List<Contact> withEmail = [
            SELECT Id FROM Contact WHERE AccountId = :a.Id AND Email != NULL
        ];
        Contact withoutEmail = [SELECT Id FROM Contact WHERE LastName = :NO_EMAIL_LAST LIMIT 1];

        List<Id> selected = new List<Id>();
        for (Contact c : withEmail) {
            selected.add(c.Id);
        }
        selected.add(withoutEmail.Id);

        CaseCreationController.CaseRequest req = buildRequest(selected, null);
        req.accountId = a.Id;

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(3, result.contactsLinked, 'Every selected contact is linked');
        // The count is no longer shown to the user, but the send behaviour still matters.
        if (templateExists()) {
            System.assertEquals(withEmail.size(), result.emailsSent,
                'Only contacts with an email address are emailed');
        } else {
            System.assertEquals(0, result.emailsSent,
                'Without the template no mail goes out, and the case still saves');
        }
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------
    /** Mirrors what lightning-file-upload does: upload against the running user. */
    private static Id stageFile(String title) {
        ContentVersion cv = new ContentVersion(
            Title                  = title,
            PathOnClient           = title,
            VersionData            = Blob.valueOf('dummy file body'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    @IsTest
    static void movesStagedFilesOntoTheCase() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];
        User owner = assignee();

        Test.startTest();
        Id firstDoc  = stageFile('complaint-photo.txt');
        Id secondDoc = stageFile('site-video.txt');

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ c.Id }, owner.Id);
        req.accountId   = a.Id;
        req.documentIds = new List<String>{
            String.valueOf(firstDoc), String.valueOf(secondDoc), '', 'not-an-id'
        };
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(2, result.filesAttached, 'Blanks and junk ids are dropped');

        System.assertEquals(2, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'Both files are linked to the case');

        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :UserInfo.getUserId()
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'The staging link against the uploader is removed');

        for (ContentDocument doc : [
            SELECT OwnerId FROM ContentDocument WHERE Id IN :new List<Id>{ firstDoc, secondDoc }
        ]) {
            System.assertEquals(owner.Id, doc.OwnerId, 'Ownership moves to the case owner');
        }
    }

    @IsTest
    static void keepsFileOwnershipWhenTheCreatorOwnsTheCase() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];

        Test.startTest();
        Id docId = stageFile('note.txt');

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ c.Id }, null);
        req.accountId   = a.Id;
        req.documentIds = new List<String>{ String.valueOf(docId) };
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'The file is attached');
        System.assertEquals(UserInfo.getUserId(),
            [SELECT OwnerId FROM ContentDocument WHERE Id = :docId].OwnerId,
            'No handover is needed when the creator already owns the case');
    }

    @IsTest
    static void createsTheCaseWhenNoFilesAreStaged() {
        if (!recordTypeExists()) {
            return; // covered by createsCaseAndLinksEverySelectedContact
        }
        Account a = mainAccount();
        Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];

        CaseCreationController.CaseRequest req = buildRequest(new List<Id>{ c.Id }, null);
        req.accountId = a.Id;

        Test.startTest();
        CaseCreationController.CaseResult result = CaseCreationController.createCase(req);
        Test.stopTest();

        System.assertEquals(0, result.filesAttached, 'Nothing to attach is not an error');
        System.assertNotEquals(null, result.caseId, 'The case is still created');
    }

    @IsTest
    static void discardsAStagedFile() {
        Test.startTest();
        Id docId = stageFile('mistake.txt');
        CaseCreationController.discardFile(docId);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Removing a staged file deletes it, since it was really uploaded');
    }

    @IsTest
    static void ignoresADiscardWithNoDocument() {
        Test.startTest();
        CaseCreationController.discardFile(null);
        Test.stopTest();
        System.assert(true, 'A null document id is a no-op');
    }
}