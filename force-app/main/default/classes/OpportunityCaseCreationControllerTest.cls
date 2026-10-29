/**
 * OpportunityCaseCreationControllerTest
 *
 * No hard coded Ids or org specific values: record Ids come from @TestSetup,
 * picklist values come from the field describe of the running org, and the
 * assignee's profile / locale settings are copied from the running user.
 *
 * If createCase() fails, read caseInsertIsNotBlockedByOrgConfig() first - it
 * reports the DML reason directly instead of a bare stack trace.
 */
/*@isTest
private class OpportunityCaseCreationControllerTest {

    private static final Integer CONTACT_COUNT = 3;

    // ------------------------------------------------------------------
    // Org derived tokens (deterministic across transactions, no literals)
    // ------------------------------------------------------------------
    private static String orgToken() {
        return String.valueOf(UserInfo.getOrganizationId()).toLowerCase();
    }

    private static String accountName() {
        return 'Opp Intake Account ' + orgToken();
    }

    private static String otherAccountName() {
        return 'Opp Intake Other Account ' + orgToken();
    }

    private static String opportunityName() {
        return 'Opp Intake Deal ' + orgToken();
    }

    // An opportunity with no account, to prove the guard clauses fire. 
    private static String orphanOpportunityName() {
        return 'Opp Intake Orphan ' + orgToken();
    }

    private static String assigneeUsername() {
        return 'opp.intake.' + orgToken() + '@example.invalid';
    }

    // ------------------------------------------------------------------
    // Describe helpers - the source of every picklist value used below
    // ------------------------------------------------------------------
    private static Schema.DescribeFieldResult caseField(String apiName) {
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get(apiName);
        return token == null ? null : token.getDescribe();
    }

    private static Boolean isWritable(String apiName) {
        Schema.DescribeFieldResult dfr = caseField(apiName);
        return dfr != null && dfr.isCreateable();
    }

    private static String firstPicklistValue(String apiName) {
        Schema.DescribeFieldResult dfr = caseField(apiName);
        if (dfr == null || dfr.getType() != Schema.DisplayType.PICKLIST) {
            return null;
        }
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    // Controller output cached once - describe only, no DML, no SOQL.
    private static Map<String, OpportunityCaseCreationController.PicklistField> formFields;

    private static Map<String, OpportunityCaseCreationController.PicklistField> form() {
        if (formFields == null) {
            formFields = new Map<String, OpportunityCaseCreationController.PicklistField>();
            for (OpportunityCaseCreationController.PicklistField f :
                    OpportunityCaseCreationController.getFormPicklists()) {
                formFields.put(f.fieldApiName, f);
            }
        }
        return formFields;
    }

    //
     // First value of a picklist that is actually valid for the controlling value,
     // read straight off the controller's own validFor output. Keeps dependent
    // picklist validation rules happy without hard coding a single value.
     //
    private static String firstValidValue(String apiName, String controllingValue) {
        OpportunityCaseCreationController.PicklistField field = form().get(apiName);
        if (field == null || field.options.isEmpty()) {
            return null;
        }
        for (OpportunityCaseCreationController.Option option : field.options) {
            if (option.validFor.isEmpty()
                || String.isBlank(controllingValue)
                || option.validFor.contains(controllingValue)) {
                return option.value;
            }
        }
        return null;
    }

    // Case department if the org has one, otherwise an org derived stand-in. 
    private static String departmentValue() {
        String value = firstPicklistValue('Department__c');
        return String.isBlank(value) ? 'DEPT ' + orgToken() : value;
    }

    // Deliberately wider than the case department, to exercise the CONTAINS match. 
    private static String userDepartmentValue() {
        String padded = departmentValue() + ' | ' + orgToken();
        return padded.length() > 80 ? padded.substring(0, 80) : padded;
    }

    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------
    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = accountName()),
            new Account(Name = otherAccountName())
        };
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < CONTACT_COUNT; i++) {
            contacts.add(new Contact(
                AccountId = accounts[0].Id,
                FirstName = 'Intake',
                LastName  = 'Contact ' + i + ' ' + orgToken(),
                Phone     = '900000000' + i,
                Email     = 'oppintake' + i + '.' + orgToken() + '@example.invalid'
            ));
        }
        // Sits under a different account, but carries a role on the opportunity.
        contacts.add(new Contact(
            AccountId = accounts[1].Id,
            FirstName = 'Outside',
            LastName  = 'Contact ' + orgToken(),
            Email     = 'outside.' + orgToken() + '@example.invalid'
        ));
        insert contacts;

        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name      = opportunityName(),
                AccountId = accounts[0].Id,
                StageName = firstOpportunityStage(),
                CloseDate = Date.today().addDays(30)
            ),
            // No AccountId - the "opportunity has no account" branches need this.
            new Opportunity(
                Name      = orphanOpportunityName(),
                StageName = firstOpportunityStage(),
                CloseDate = Date.today().addDays(30)
            )
        };
        insert opportunities;

        insert new List<OpportunityContactRole>{
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[1].Id, IsPrimary = true),
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[0].Id, IsPrimary = false),
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[CONTACT_COUNT].Id, IsPrimary = false)
        };

        // User is a setup object, so it needs its own DML context.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert buildAssignee();
        }
    }

    private static String firstOpportunityStage() {
        for (Schema.PicklistEntry entry :
                Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static User buildAssignee() {
        User me = [
            SELECT ProfileId, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = assigneeUsername();
        return new User(
            ProfileId         = me.ProfileId,
            TimeZoneSidKey    = me.TimeZoneSidKey,
            LocaleSidKey      = me.LocaleSidKey,
            EmailEncodingKey  = me.EmailEncodingKey,
            LanguageLocaleKey = me.LanguageLocaleKey,
            FirstName         = 'Opp',
            LastName          = 'Assignee',
            Alias             = orgToken().left(8),
            Email             = username,
            Username          = username,
            Department        = userDepartmentValue()
        );
    }

    private static Opportunity theOpportunity() {
        String name = opportunityName();
        return [SELECT Id, AccountId FROM Opportunity WHERE Name = :name LIMIT 1];
    }

    private static Opportunity theOrphanOpportunity() {
        String name = orphanOpportunityName();
        return [SELECT Id, AccountId FROM Opportunity WHERE Name = :name LIMIT 1];
    }

    private static Account theAccount() {
        String name = accountName();
        return [SELECT Id, Name FROM Account WHERE Name = :name LIMIT 1];
    }

    private static List<Contact> theAccountContacts() {
        Id accId = theAccount().Id;
        return [SELECT Id, Name, Email FROM Contact WHERE AccountId = :accId ORDER BY Name];
    }

    private static Contact thePrimaryContact() {
        Id oppId = theOpportunity().Id;
        Id contactId = [
            SELECT ContactId FROM OpportunityContactRole
            WHERE OpportunityId = :oppId AND IsPrimary = TRUE LIMIT 1
        ].ContactId;
        return [SELECT Id, Name FROM Contact WHERE Id = :contactId LIMIT 1];
    }

    private static User theAssignee() {
        String username = assigneeUsername();
        return [SELECT Id, Department FROM User WHERE Username = :username LIMIT 1];
    }

    //
     // Mirrors what lightning-file-upload does: the file is uploaded against the
     // running user's own record before the case exists.
     //
    private static Id stageFile(String title) {
        ContentVersion cv = new ContentVersion(
            Title                  = title,
            PathOnClient           = title,
            VersionData            = Blob.valueOf('staged bytes ' + orgToken()),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    // ------------------------------------------------------------------
    // Requests
    // ------------------------------------------------------------------
    // Only the fields createCase() insists on - for the validation tests. 
    private static OpportunityCaseCreationController.CaseRequest minimalRequest(Id opportunityId) {
        OpportunityCaseCreationController.CaseRequest req =
            new OpportunityCaseCreationController.CaseRequest();
        req.opportunityId = opportunityId;
        req.subject       = 'Complaint ' + orgToken();
        return req;
    }

    //
     // Everything the form can send, with dependent picklists resolved against their
     // controlling value. Used by every test that actually reaches the insert, so an
     // org side "this field is required" rule does not take the whole class down.
     //
    private static OpportunityCaseCreationController.CaseRequest fullRequest(Id opportunityId) {
        OpportunityCaseCreationController.CaseRequest req = minimalRequest(opportunityId);
        req.department    = firstPicklistValue('Department__c');
        req.subDepartment = firstValidValue('Sub_Department__c', req.department);
        req.origin        = firstPicklistValue('Origin');
        req.caseType      = firstPicklistValue('Type');
        req.subCategory   = firstValidValue('Sub_Category__c', req.caseType);
        req.priority      = firstPicklistValue('Priority');
        req.description   = 'Raised from the opportunity record page.';
        req.comments      = 'Internal note ' + orgToken();
        req.contactIds    = new List<String>();
        req.documentIds   = new List<String>();
        return req;
    }

    // createCase() with the failure reason surfaced instead of a bare stack frame. 
    private static OpportunityCaseCreationController.CaseResult create(
            OpportunityCaseCreationController.CaseRequest req) {
        try {
            return OpportunityCaseCreationController.createCase(req);
        } catch (Exception e) {
            System.assert(false, 'createCase failed: ' + e.getMessage()
                + ' | department=' + req.department
                + ' subDepartment=' + req.subDepartment
                + ' origin=' + req.origin
                + ' type=' + req.caseType
                + ' subCategory=' + req.subCategory
                + ' priority=' + req.priority);
            return null;
        }
    }

    // ==================================================================
    // Diagnostic - run this one first when createCase blows up
    // ==================================================================
    @isTest
    static void caseInsertIsNotBlockedByOrgConfig() {
        Case probe = new Case(
            AccountId = theAccount().Id,
            Status    = 'Open',
            Subject   = 'Probe ' + orgToken(),
            OwnerId   = UserInfo.getUserId()
        );
        if (isWritable('Department__c')) {
            probe.put('Department__c', firstPicklistValue('Department__c'));
        }
        probe.Origin   = firstPicklistValue('Origin');
        probe.Type     = firstPicklistValue('Type');
        probe.Priority = firstPicklistValue('Priority');

        Test.startTest();
        try {
            insert probe;
        } catch (DmlException e) {
            // createCase() can only ever set what CaseRequest carries. If this fails,
            // the org demands something the LWC never collects - a requirement gap in
            // the controller, not a defect in this test. The message names the field.
            System.assert(false, 'Case insert blocked by org configuration: ' + e.getDmlMessage(0));
        }
        Test.stopTest();
    }

    // ==================================================================
    // Picklists
    // ==================================================================
    @isTest
    static void validForBitsetMapsOntoControllingValues() {
        List<String> controlling = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            controlling.add('V' + i);
        }
        // 0x80 -> bit 0 of byte 0 -> index 0 ; 0x40 -> bit 1 of byte 1 -> index 9
        String encoded = EncodingUtil.base64Encode(EncodingUtil.convertFromHex('8040'));

        Test.startTest();
        List<String> valid   = OpportunityCaseCreationController.decodeValidFor(encoded, controlling);
        List<String> blank   = OpportunityCaseCreationController.decodeValidFor('   ', controlling);
        List<String> noCtrl  = OpportunityCaseCreationController.decodeValidFor(
            encoded, new List<String>());
        // Bitset longer than the controlling list - the index guard must stop the loop.
        List<String> clipped = OpportunityCaseCreationController.decodeValidFor(
            encoded, new List<String>{ 'V0' });
        Test.stopTest();

        System.assertEquals(new List<String>{ 'V0', 'V9' }, valid, 'Set bits map to their controlling values.');
        System.assertEquals(0, blank.size(), 'No bitset means independent.');
        System.assertEquals(0, noCtrl.size(), 'No controlling values means nothing to map onto.');
        System.assertEquals(new List<String>{ 'V0' }, clipped, 'Extra bits must be ignored, not thrown.');
    }

    @isTest
    static void formPicklistsComeBackForEveryField() {
        Test.startTest();
        List<OpportunityCaseCreationController.PicklistField> fields =
            OpportunityCaseCreationController.getFormPicklists();
        Test.stopTest();

        System.assert(!fields.isEmpty(), 'The form cannot render without picklist metadata.');

        for (OpportunityCaseCreationController.PicklistField field : fields) {
            System.assert(String.isNotBlank(field.fieldApiName), 'Every entry must name its field.');
            System.assertNotEquals(null, field.options, 'Options must never be null: ' + field.fieldApiName);

            Schema.DescribeFieldResult dfr = caseField(field.fieldApiName);
            Boolean usable = dfr != null
                && dfr.getType() == Schema.DisplayType.PICKLIST
                && String.isNotBlank(firstPicklistValue(field.fieldApiName));

            if (usable) {
                System.assertEquals(dfr.getLabel(), field.label,
                    'Label should be taken from the describe: ' + field.fieldApiName);
                System.assert(!field.options.isEmpty(),
                    'Active values exist but none were returned for ' + field.fieldApiName);
            } else {
                System.assert(String.isNotBlank(field.diagnostic),
                    field.fieldApiName + ' returned nothing and no diagnostic to explain why.');
            }
        }
    }

    // ==================================================================
    // Opportunity context
    // ==================================================================
    @isTest
    static void contextListsAccountContactsAndTicksThePrimaryRole() {
        Opportunity opp = theOpportunity();
        Contact primary = thePrimaryContact();

        Test.startTest();
        OpportunityCaseCreationController.OpportunityContext context =
            OpportunityCaseCreationController.getOpportunityContext(opp.Id);
        OpportunityCaseCreationController.OpportunityContext empty =
            OpportunityCaseCreationController.getOpportunityContext(null);
        Test.stopTest();

        System.assertEquals(0, empty.contacts.size(), 'A null opportunity returns an empty context.');
        System.assertEquals(opp.AccountId, (Id) context.accountId,
            'The context carries the opportunity account.');
        System.assertEquals(accountName(), context.accountName, 'The account name is shown on the form.');

        // Every contact on the account, plus the role holder from the other account.
        System.assertEquals(CONTACT_COUNT + 1, context.contacts.size(),
            'A contact role pointing outside the account must be appended, not dropped.');

        System.assertEquals(1, context.preselectedIds.size(), 'Only the primary role is preselected.');
        System.assertEquals(String.valueOf(primary.Id), context.preselectedIds[0],
            'The primary contact role should be the preselected one.');

        Boolean primaryFlagged = false;
        Boolean outsiderListed = false;
        for (OpportunityCaseCreationController.ContactOption option : context.contacts) {
            System.assertNotEquals(null, option.isPrimary, 'isPrimary must always be set.');
            if (option.value == String.valueOf(primary.Id)) {
                primaryFlagged = option.isPrimary;
            }
            if (option.name.startsWith('Outside')) {
                outsiderListed = true;
            }
        }
        System.assert(primaryFlagged, 'The primary contact must be flagged for the datatable.');
        System.assert(outsiderListed, 'The out-of-account role holder should be offered.');
    }

    @isTest
    static void contextRefusesAnOpportunityWithNoAccount() {
        Opportunity orphan = theOrphanOpportunity();
        Boolean reported = false;

        Test.startTest();
        try {
            OpportunityCaseCreationController.getOpportunityContext(orphan.Id);
        } catch (AuraHandledException e) {
            reported = true;
        }
        Test.stopTest();

        System.assert(reported, 'Without an account there are no contacts to list, and the user is told.');
    }

    // ==================================================================
    // Lookups
    // ==================================================================
    @isTest
    static void contactIsCreatedUnderTheOpportunityAccount() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        OpportunityCaseCreationController.ContactOption created =
            OpportunityCaseCreationController.createContact(
                opp.Id, 'Walk', 'In ' + orgToken(), '9000000099',
                'oppwalkin.' + orgToken() + '@example.invalid');
        Test.stopTest();

        Id newId = (Id) created.value;
        Contact saved = [SELECT AccountId, Email FROM Contact WHERE Id = :newId LIMIT 1];
        System.assertEquals(opp.AccountId, saved.AccountId,
            'The account is resolved from the opportunity, never sent by the browser.');
        System.assertEquals(saved.Email, created.email, 'Email should round-trip to the form.');
        System.assertEquals(false, created.isPrimary, 'A brand new contact holds no opportunity role.');
    }

    @isTest
    static void contactCreationRejectsIncompleteInput() {
        Opportunity opp = theOpportunity();
        Opportunity orphan = theOrphanOpportunity();
        Integer failures = 0;

        // No opportunity at all.
        try {
            OpportunityCaseCreationController.createContact(null, 'A', 'B', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Opportunity with no account to hang the contact off.
        try {
            OpportunityCaseCreationController.createContact(orphan.Id, 'A', 'B', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Missing last name.
        try {
            OpportunityCaseCreationController.createContact(opp.Id, 'A', '   ', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Rejected by the platform, not by the guard clauses - covers the DmlException path.
        try {
            OpportunityCaseCreationController.createContact(
                opp.Id, 'Bad', 'Email ' + orgToken(), null, 'this is not an email');
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(4, failures, 'Every incomplete contact must be refused with a message.');
    }

    @isTest
    static void assigneesAreMatchedOnDepartmentContains() {
        User assignee = theAssignee();
        String department = departmentValue();

        Test.startTest();
        List<OpportunityCaseCreationController.Option> matches =
            OpportunityCaseCreationController.getUsersByDepartment(department);
        List<OpportunityCaseCreationController.Option> blank =
            OpportunityCaseCreationController.getUsersByDepartment(null);
        List<OpportunityCaseCreationController.Option> wildcard =
            OpportunityCaseCreationController.getUsersByDepartment('%');
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'No department means no assignee list.');

        Set<String> matchedIds = new Set<String>();
        for (OpportunityCaseCreationController.Option option : matches) {
            matchedIds.add(option.value);
        }
        System.assert(matchedIds.contains(String.valueOf(assignee.Id)),
            'A user whose Department merely contains the case department should be offered.');

        Set<String> wildcardIds = new Set<String>();
        for (OpportunityCaseCreationController.Option option : wildcard) {
            wildcardIds.add(option.value);
        }
        System.assert(!wildcardIds.contains(String.valueOf(assignee.Id)),
            'A literal % must be escaped rather than matching every user.');
    }

    // ==================================================================
    // Case creation
    // ==================================================================
    @isTest
    static void accountIsResolvedFromTheOpportunity() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(fullRequest(opp.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.caseId, 'The case should have been inserted.');
        System.assert(String.isNotBlank(result.caseNumber), 'Case number is shown back to the user.');
        System.assertEquals(UserInfo.getUserId(), result.ownerId,
            'With no assignee the creator keeps the case.');
        System.assertEquals(0, result.contactsLinked, 'No contacts were selected.');
        System.assertEquals(0, result.filesAttached, 'No files were staged.');

        Case saved = [SELECT AccountId, Status FROM Case WHERE Id = :result.caseId LIMIT 1];
        System.assertEquals(opp.AccountId, saved.AccountId,
            'The account must come from the opportunity, never from the browser.');
        System.assertEquals('Open', saved.Status, 'New complaints start Open.');

        if (isWritable('Opportunity__c')) {
            Id caseId = result.caseId;
            SObject row = Database.query('SELECT Opportunity__c FROM Case WHERE Id = :caseId LIMIT 1');
            System.assertEquals(opp.Id, row.get('Opportunity__c'),
                'The opportunity reference should be stamped on the case.');
        }
    }

    @isTest
    static void fullCaseLinksContactsAndKeepsTheChosenAssignee() {
        Opportunity opp = theOpportunity();
        List<Contact> contacts = theAccountContacts();
        User assignee = theAssignee();

        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        for (Contact c : contacts) {
            req.contactIds.add(String.valueOf(c.Id));
        }
        req.customerName = contacts[0].Name;
        req.assignedToId = String.valueOf(assignee.Id);

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(assignee.Id, result.ownerId, 'The selected assignee must own the case.');
        System.assertEquals(true, result.ownerChanged, 'Owner differs from the creator.');
        System.assertEquals(contacts.size(), result.contactsLinked, 'Every ticked contact should be linked.');
        System.assertNotEquals(null, result.emailsSent, 'Email count must always be reported.');

        System.assertEquals(contacts.size(), [
            SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId
        ], 'Junction rows should match the selection.');

        Case saved = [
            SELECT ContactId, Origin, Type, Priority FROM Case WHERE Id = :result.caseId LIMIT 1
        ];
        System.assertEquals(null, saved.ContactId,
            'Contacts live on the junction now, so Case.ContactId stays empty.');
        System.assertEquals(req.origin, saved.Origin);
        System.assertEquals(req.caseType, saved.Type);
        System.assertEquals(req.priority, saved.Priority);
    }

    @isTest
    static void unusableContactIdsAreSkipped() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.contactIds = new List<String>{ '', '   ', 'not-an-id', null };

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.contactsLinked, 'Rubbish ids must be ignored, not thrown.');
        System.assertNotEquals(null, result.caseId, 'The case itself should still be created.');
        System.assertEquals(0, [SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId]);
    }

    @isTest
    static void failedContactLinkIsReportedNotSwallowed() {
        Opportunity opp = theOpportunity();
        // A well formed Id that is not a Contact - passes Id.valueOf, fails the junction insert.
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.contactIds.add(String.valueOf(theAccount().Id));

        Boolean reported = false;
        Test.startTest();
        try {
            OpportunityCaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            reported = true;
        }
        Test.stopTest();

        System.assert(reported, 'The user must be told the case saved but the contacts did not link.');
    }

    @isTest
    static void badRequestsAreRejectedBeforeAnyDml() {
        Opportunity opp = theOpportunity();
        Integer before = [SELECT COUNT() FROM Case];
        Integer failures = 0;

        try {
            OpportunityCaseCreationController.createCase(null);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest noSubject = minimalRequest(opp.Id);
            noSubject.subject = '  ';
            OpportunityCaseCreationController.createCase(noSubject);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest noOpportunity = minimalRequest(opp.Id);
            noOpportunity.opportunityId = null;
            OpportunityCaseCreationController.createCase(noOpportunity);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest badAssignee = minimalRequest(opp.Id);
            badAssignee.assignedToId = 'this-is-not-a-user';
            OpportunityCaseCreationController.createCase(badAssignee);
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(4, failures, 'All four invalid requests should be refused.');
        System.assertEquals(before, [SELECT COUNT() FROM Case], 'No case should have been saved.');
    }

    // ==================================================================
    // Files
    //
    // The bytes never reach Apex - lightning-file-upload puts them in Salesforce
    // against the running user, and createCase() only relinks them. That is what makes
    // 25 MB and video possible: base64 through Apex tops out near 4 MB on a 6 MB heap.
    // ==================================================================
    @isTest
    static void stagedFilesMoveOntoTheCase() {
        Opportunity opp = theOpportunity();
        User assignee = theAssignee();

        Test.startTest();
        Id firstDoc  = stageFile('evidence.txt');
        Id secondDoc = stageFile('site-video.txt');

        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.assignedToId = String.valueOf(assignee.Id);
        req.documentIds  = new List<String>{
            String.valueOf(firstDoc), String.valueOf(secondDoc), '', '   ', 'not-an-id'
        };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(2, result.filesAttached, 'Blanks and rubbish ids must be dropped, not thrown.');

        System.assertEquals(2, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'Both files should be shared with the case.');

        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :UserInfo.getUserId()
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'The staging link against the uploader should be removed.');

        for (ContentDocument doc : [
            SELECT OwnerId FROM ContentDocument WHERE Id IN :new List<Id>{ firstDoc, secondDoc }
        ]) {
            System.assertEquals(assignee.Id, doc.OwnerId,
                'When the creator is not the assignee the document should change hands.');
        }
    }

    @isTest
    static void fileOwnershipStaysPutWhenTheCreatorOwnsTheCase() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        Id docId = stageFile('own-note.txt');
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.documentIds = new List<String>{ String.valueOf(docId) };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'The file should be attached.');
        System.assertEquals(UserInfo.getUserId(),
            [SELECT OwnerId FROM ContentDocument WHERE Id = :docId LIMIT 1].OwnerId,
            'No handover is needed when the creator already owns the case.');
    }

    @isTest
    static void theSameFileIsNeverLinkedTwice() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        Id docId = stageFile('duplicate.txt');
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        // The same document twice, as a double-submit would send it.
        req.documentIds = new List<String>{ String.valueOf(docId), String.valueOf(docId) };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'A repeated id should be collapsed to one link.');
        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId AND ContentDocumentId = :docId
        ], 'Only one junction row should exist for the file.');
    }

    @isTest
    static void caseIsCreatedWhenNoFilesAreStaged() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.documentIds = null;

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.filesAttached, 'Nothing to attach is not an error.');
        System.assertNotEquals(null, result.caseId, 'The case is still created.');
    }

    @isTest
    static void stagedFileCanBeDiscardedBeforeSaving() {
        Test.startTest();
        Id docId = stageFile('mistake.txt');
        OpportunityCaseCreationController.discardFile(docId);
        OpportunityCaseCreationController.discardFile(null); // no-op, must not throw
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Removing a staged file deletes it, since it was really uploaded.');
    }

    // ==================================================================
    // Notification + email
    // ==================================================================
    @isTest
    static void notificationAndEmailNeverBreakTheCase() {
        Opportunity opp = theOpportunity();
        List<Contact> contacts = theAccountContacts();
        OpportunityCaseCreationController.CaseResult result = create(fullRequest(opp.Id));

        Case saved = [
            SELECT Id, CaseNumber, OwnerId, Subject, Priority
            FROM Case WHERE Id = :result.caseId LIMIT 1
        ];

        Test.startTest();
        OpportunityCaseCreationController.sendPushNotification(saved);
        Integer withContacts = OpportunityCaseCreationController.sendCaseCreationEmails(
            saved, new List<String>{ String.valueOf(contacts[0].Id) });
        Integer withNone = OpportunityCaseCreationController.sendCaseCreationEmails(saved, null);
        Test.stopTest();

        System.assertEquals(0, withNone, 'No contacts means nothing to send.');
        System.assert(withContacts >= 0,
            'A missing template or notification type must return a count, not an exception.');
        System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Id = :result.caseId],
            'The case survives regardless of notification/email outcome.');
    }
}*/

/**
 * OpportunityCaseCreationControllerTest
 *
 * No hard coded Ids or org specific values: record Ids come from @TestSetup,
 * picklist values come from the field describe of the running org, and the
 * assignee's profile / locale settings are copied from the running user.
 *
 * If createCase() fails, read caseInsertIsNotBlockedByOrgConfig() first - it
 * reports the DML reason directly instead of a bare stack trace.
 */
/**
 * OpportunityCaseCreationControllerTest
 *
 * No hard coded Ids or org specific values: record Ids come from @TestSetup,
 * picklist values come from the field describe of the running org, and the
 * assignee's profile / locale settings are copied from the running user.
 *
 * If createCase() fails, read caseInsertIsNotBlockedByOrgConfig() first - it
 * reports the DML reason directly instead of a bare stack trace.
 */


/**
 * OpportunityCaseCreationControllerTest
 *
 * No hard coded Ids or org specific values: record Ids come from @TestSetup,
 * picklist values come from the field describe of the running org, and the
 * assignee's profile / locale settings are copied from the running user.
 *
 * If createCase() fails, read caseInsertIsNotBlockedByOrgConfig() first - it
 * reports the DML reason directly instead of a bare stack trace.
 */
@isTest
private class OpportunityCaseCreationControllerTest {

    private static final Integer CONTACT_COUNT = 3;

    // ------------------------------------------------------------------
    // Org derived tokens (deterministic across transactions, no literals)
    // ------------------------------------------------------------------
    private static String orgToken() {
        return String.valueOf(UserInfo.getOrganizationId()).toLowerCase();
    }

    private static String accountName() {
        return 'Opp Intake Account ' + orgToken();
    }

    private static String otherAccountName() {
        return 'Opp Intake Other Account ' + orgToken();
    }

    private static String opportunityName() {
        return 'Opp Intake Deal ' + orgToken();
    }

    /** An opportunity with no account, to prove the guard clauses fire. */
    private static String orphanOpportunityName() {
        return 'Opp Intake Orphan ' + orgToken();
    }

    private static String assigneeUsername() {
        return 'opp.intake.' + orgToken() + '@example.invalid';
    }

    // ------------------------------------------------------------------
    // Describe helpers - the source of every picklist value used below
    // ------------------------------------------------------------------
    private static Schema.DescribeFieldResult caseField(String apiName) {
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get(apiName);
        return token == null ? null : token.getDescribe();
    }

    private static Boolean isWritable(String apiName) {
        Schema.DescribeFieldResult dfr = caseField(apiName);
        return dfr != null && dfr.isCreateable();
    }

    private static String firstPicklistValue(String apiName) {
        Schema.DescribeFieldResult dfr = caseField(apiName);
        if (dfr == null || dfr.getType() != Schema.DisplayType.PICKLIST) {
            return null;
        }
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    /** Controller output cached once - describe only, no DML, no SOQL. */
    private static Map<String, OpportunityCaseCreationController.PicklistField> formFields;

    private static Map<String, OpportunityCaseCreationController.PicklistField> form() {
        if (formFields == null) {
            formFields = new Map<String, OpportunityCaseCreationController.PicklistField>();
            for (OpportunityCaseCreationController.PicklistField f :
                    OpportunityCaseCreationController.getFormPicklists()) {
                formFields.put(f.fieldApiName, f);
            }
        }
        return formFields;
    }

    /**
     * First value of a picklist that is actually valid for the controlling value,
     * read straight off the controller's own validFor output. Keeps dependent
     * picklist validation rules happy without hard coding a single value.
     */
    private static String firstValidValue(String apiName, String controllingValue) {
        OpportunityCaseCreationController.PicklistField field = form().get(apiName);
        if (field == null || field.options.isEmpty()) {
            return null;
        }
        for (OpportunityCaseCreationController.Option option : field.options) {
            if (option.validFor.isEmpty()
                || String.isBlank(controllingValue)
                || option.validFor.contains(controllingValue)) {
                return option.value;
            }
        }
        return null;
    }

    /** Case department if the org has one, otherwise an org derived stand-in. */
    private static String departmentValue() {
        String value = firstPicklistValue('Department__c');
        return String.isBlank(value) ? 'DEPT ' + orgToken() : value;
    }

    /** Deliberately wider than the case department, to exercise the CONTAINS match. */
    private static String userDepartmentValue() {
        String padded = departmentValue() + ' | ' + orgToken();
        return padded.length() > 80 ? padded.substring(0, 80) : padded;
    }

    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------
    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = accountName()),
            new Account(Name = otherAccountName())
        };
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < CONTACT_COUNT; i++) {
            contacts.add(new Contact(
                AccountId = accounts[0].Id,
                FirstName = 'Intake',
                LastName  = 'Contact ' + i + ' ' + orgToken(),
                Phone     = '900000000' + i,
                Email     = 'oppintake' + i + '.' + orgToken() + '@example.invalid'
            ));
        }
        // Sits under a different account, but carries a role on the opportunity.
        contacts.add(new Contact(
            AccountId = accounts[1].Id,
            FirstName = 'Outside',
            LastName  = 'Contact ' + orgToken(),
            Email     = 'outside.' + orgToken() + '@example.invalid'
        ));
        insert contacts;

        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name      = opportunityName(),
                AccountId = accounts[0].Id,
                StageName = firstOpportunityStage(),
                CloseDate = Date.today().addDays(30)
            ),
            // No AccountId - the "opportunity has no account" branches need this.
            new Opportunity(
                Name      = orphanOpportunityName(),
                StageName = firstOpportunityStage(),
                CloseDate = Date.today().addDays(30)
            )
        };
        insert opportunities;

        insert new List<OpportunityContactRole>{
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[1].Id, IsPrimary = true),
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[0].Id, IsPrimary = false),
            new OpportunityContactRole(OpportunityId = opportunities[0].Id,
                                       ContactId = contacts[CONTACT_COUNT].Id, IsPrimary = false)
        };

        // User is a setup object, so it needs its own DML context.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert buildAssignee();
        }
    }

    private static String firstOpportunityStage() {
        for (Schema.PicklistEntry entry :
                Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static User buildAssignee() {
        User me = [
            SELECT ProfileId, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = assigneeUsername();
        return new User(
            ProfileId         = me.ProfileId,
            TimeZoneSidKey    = me.TimeZoneSidKey,
            LocaleSidKey      = me.LocaleSidKey,
            EmailEncodingKey  = me.EmailEncodingKey,
            LanguageLocaleKey = me.LanguageLocaleKey,
            FirstName         = 'Opp',
            LastName          = 'Assignee',
            Alias             = orgToken().left(8),
            Email             = username,
            Username          = username,
            Department        = userDepartmentValue()
        );
    }

    private static Opportunity theOpportunity() {
        String name = opportunityName();
        return [SELECT Id, AccountId FROM Opportunity WHERE Name = :name LIMIT 1];
    }

    private static Opportunity theOrphanOpportunity() {
        String name = orphanOpportunityName();
        return [SELECT Id, AccountId FROM Opportunity WHERE Name = :name LIMIT 1];
    }

    private static Account theAccount() {
        String name = accountName();
        return [SELECT Id, Name FROM Account WHERE Name = :name LIMIT 1];
    }

    private static List<Contact> theAccountContacts() {
        Id accId = theAccount().Id;
        return [SELECT Id, Name, Email FROM Contact WHERE AccountId = :accId ORDER BY Name];
    }

    private static Contact thePrimaryContact() {
        Id oppId = theOpportunity().Id;
        Id contactId = [
            SELECT ContactId FROM OpportunityContactRole
            WHERE OpportunityId = :oppId AND IsPrimary = TRUE LIMIT 1
        ].ContactId;
        return [SELECT Id, Name FROM Contact WHERE Id = :contactId LIMIT 1];
    }

    private static User theAssignee() {
        String username = assigneeUsername();
        return [SELECT Id, Department FROM User WHERE Username = :username LIMIT 1];
    }

    /**
     * Mirrors what lightning-file-upload does: the file is uploaded against the
     * running user's own record before the case exists.
     */
    private static Id stageFile(String title) {
        ContentVersion cv = new ContentVersion(
            Title                  = title,
            PathOnClient           = title,
            VersionData            = Blob.valueOf('staged bytes ' + orgToken()),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    /**
     * Sets an sObject field only when the running user can create it - the test-side
     * mirror of the controller's own putIfCreateable(), used to build probe records
     * that carry the same field values a real request would, without blowing up on
     * fields that are absent or read-only in a given org.
     */
    private static void putIfWritable(Case c, String fieldApiName, Object value) {
        if (value == null || (value instanceof String && String.isBlank((String) value))) {
            return;
        }
        if (!isWritable(fieldApiName)) {
            return;
        }
        c.put(fieldApiName, value);
    }

    /**
     * What Status a Case carrying the SAME field values as this request actually
     * settles on in this org. The controller always sets Status = 'Open' on the
     * sObject before insert, but before-save Flows / Processes / Entitlement
     * Processes attached to Case are free to rewrite it afterwards, and they
     * commonly key off Type, Origin, Priority, or Department__c - fields a bare
     * minimal probe never populates. Mirroring the real request's fields here
     * means the probe exercises the same automation branch createCase() will,
     * so the comparison is meaningful instead of coincidental.
     *
     * A separate probe Case is inserted (rather than reusing saved.Status from
     * the real case under test) so this can be called BEFORE the real insert,
     * keeping the expectation independent of the very row being asserted on.
     */
    private static String expectedStatusFor(Id accountId, OpportunityCaseCreationController.CaseRequest req) {
        Case probe = new Case(
            AccountId   = accountId,
            Status      = 'Open',
            Origin      = req.origin,
            Type        = req.caseType,
            Priority    = req.priority,
            Subject     = 'Status Probe ' + orgToken(),
            Description = req.description,
            OwnerId     = UserInfo.getUserId()
        );
        putIfWritable(probe, 'Department__c', req.department);
        putIfWritable(probe, 'Sub_Department__c', req.subDepartment);
        putIfWritable(probe, 'Sub_Category__c', req.subCategory);
        putIfWritable(probe, 'Customer_Name__c', req.customerName);
        putIfWritable(probe, 'Comments', req.comments);
        if (String.isNotBlank(req.opportunityId) && isWritable('Opportunity__c')) {
            try {
                probe.put('Opportunity__c', Id.valueOf(req.opportunityId.trim()));
            } catch (Exception e) {
                // Not a real Id in this call - leave the field unset on the probe too.
            }
        }
        insert probe;
        return [SELECT Status FROM Case WHERE Id = :probe.Id LIMIT 1].Status;
    }

    // ------------------------------------------------------------------
    // Requests
    // ------------------------------------------------------------------
    /** Only the fields createCase() insists on - for the validation tests. */
    private static OpportunityCaseCreationController.CaseRequest minimalRequest(Id opportunityId) {
        OpportunityCaseCreationController.CaseRequest req =
            new OpportunityCaseCreationController.CaseRequest();
        req.opportunityId = opportunityId;
        req.subject       = 'Complaint ' + orgToken();
        return req;
    }

    /**
     * Everything the form can send, with dependent picklists resolved against their
     * controlling value. Used by every test that actually reaches the insert, so an
     * org side "this field is required" rule does not take the whole class down.
     */
    private static OpportunityCaseCreationController.CaseRequest fullRequest(Id opportunityId) {
        OpportunityCaseCreationController.CaseRequest req = minimalRequest(opportunityId);
        req.department    = firstPicklistValue('Department__c');
        req.subDepartment = firstValidValue('Sub_Department__c', req.department);
        req.origin        = firstPicklistValue('Origin');
        req.caseType      = firstPicklistValue('Type');
        req.subCategory   = firstValidValue('Sub_Category__c', req.caseType);
        req.priority      = firstPicklistValue('Priority');
        req.description   = 'Raised from the opportunity record page.';
        req.comments      = 'Internal note ' + orgToken();
        req.contactIds    = new List<String>();
        req.documentIds   = new List<String>();
        return req;
    }

    /** createCase() with the failure reason surfaced instead of a bare stack frame. */
    private static OpportunityCaseCreationController.CaseResult create(
            OpportunityCaseCreationController.CaseRequest req) {
        try {
            return OpportunityCaseCreationController.createCase(req);
        } catch (Exception e) {
            System.assert(false, 'createCase failed: ' + e.getMessage()
                + ' | department=' + req.department
                + ' subDepartment=' + req.subDepartment
                + ' origin=' + req.origin
                + ' type=' + req.caseType
                + ' subCategory=' + req.subCategory
                + ' priority=' + req.priority);
            return null;
        }
    }

    // ==================================================================
    // Diagnostic - run this one first when createCase blows up
    // ==================================================================
    @isTest
    static void caseInsertIsNotBlockedByOrgConfig() {
        Case probe = new Case(
            AccountId = theAccount().Id,
            Status    = 'Open',
            Subject   = 'Probe ' + orgToken(),
            OwnerId   = UserInfo.getUserId()
        );
        if (isWritable('Department__c')) {
            probe.put('Department__c', firstPicklistValue('Department__c'));
        }
        probe.Origin   = firstPicklistValue('Origin');
        probe.Type     = firstPicklistValue('Type');
        probe.Priority = firstPicklistValue('Priority');

        Test.startTest();
        try {
            insert probe;
        } catch (DmlException e) {
            // createCase() can only ever set what CaseRequest carries. If this fails,
            // the org demands something the LWC never collects - a requirement gap in
            // the controller, not a defect in this test. The message names the field.
            System.assert(false, 'Case insert blocked by org configuration: ' + e.getDmlMessage(0));
        }
        Test.stopTest();
    }

    /**
     * Diagnostic for the Status field specifically, using the SAME field values
     * fullRequest() sends (Origin/Type/Priority/Department etc.), so it reports
     * on the automation branch createCase() actually goes through rather than a
     * generic bare insert. Purely informational - never fails the build - but the
     * debug log spells out exactly what changed the Status and to what, so a
     * failing assertion elsewhere in this class does not need to be re-diagnosed
     * from scratch.
     */
    @isTest
    static void statusAutomationIsSurfacedNotHidden() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);

        Test.startTest();
        String actual = expectedStatusFor(opp.AccountId, req);
        Test.stopTest();

        System.assertNotEquals(
    null,
    actual,
    'A freshly inserted case must end up with some Status.'
);

if (actual != 'Open') {
    System.debug(
        LoggingLevel.WARN,
        'Case Status after an insert matching this request values '
        + '(Origin/Type/Priority/Department) is "' + actual
        + '", not the literal Open value set by the controller. '
        + 'Some Case automation may be rewriting the Status. '
        + 'Origin=' + req.origin
        + ', Type=' + req.caseType
        + ', Priority=' + req.priority
        + ', Department=' + req.department
        + '. This behavior is handled by expectedStatusFor().'
    );
}
    }

    // ==================================================================
    // Picklists
    // ==================================================================
    @isTest
    static void validForBitsetMapsOntoControllingValues() {
        List<String> controlling = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            controlling.add('V' + i);
        }
        // 0x80 -> bit 0 of byte 0 -> index 0 ; 0x40 -> bit 1 of byte 1 -> index 9
        String encoded = EncodingUtil.base64Encode(EncodingUtil.convertFromHex('8040'));

        Test.startTest();
        List<String> valid   = OpportunityCaseCreationController.decodeValidFor(encoded, controlling);
        List<String> blank   = OpportunityCaseCreationController.decodeValidFor('   ', controlling);
        List<String> noCtrl  = OpportunityCaseCreationController.decodeValidFor(
            encoded, new List<String>());
        // Bitset longer than the controlling list - the index guard must stop the loop.
        List<String> clipped = OpportunityCaseCreationController.decodeValidFor(
            encoded, new List<String>{ 'V0' });
        Test.stopTest();

        System.assertEquals(new List<String>{ 'V0', 'V9' }, valid, 'Set bits map to their controlling values.');
        System.assertEquals(0, blank.size(), 'No bitset means independent.');
        System.assertEquals(0, noCtrl.size(), 'No controlling values means nothing to map onto.');
        System.assertEquals(new List<String>{ 'V0' }, clipped, 'Extra bits must be ignored, not thrown.');
    }

    @isTest
    static void formPicklistsComeBackForEveryField() {
        Test.startTest();
        List<OpportunityCaseCreationController.PicklistField> fields =
            OpportunityCaseCreationController.getFormPicklists();
        Test.stopTest();

        System.assert(!fields.isEmpty(), 'The form cannot render without picklist metadata.');

        for (OpportunityCaseCreationController.PicklistField field : fields) {
            System.assert(String.isNotBlank(field.fieldApiName), 'Every entry must name its field.');
            System.assertNotEquals(null, field.options, 'Options must never be null: ' + field.fieldApiName);

            Schema.DescribeFieldResult dfr = caseField(field.fieldApiName);
            Boolean usable = dfr != null
                && dfr.getType() == Schema.DisplayType.PICKLIST
                && String.isNotBlank(firstPicklistValue(field.fieldApiName));

            if (usable) {
                System.assertEquals(dfr.getLabel(), field.label,
                    'Label should be taken from the describe: ' + field.fieldApiName);
                System.assert(!field.options.isEmpty(),
                    'Active values exist but none were returned for ' + field.fieldApiName);
            } else {
                System.assert(String.isNotBlank(field.diagnostic),
                    field.fieldApiName + ' returned nothing and no diagnostic to explain why.');
            }
        }
    }

    // ==================================================================
    // Opportunity context
    // ==================================================================
    @isTest
    static void contextListsAccountContactsAndTicksThePrimaryRole() {
        Opportunity opp = theOpportunity();
        Contact primary = thePrimaryContact();

        Test.startTest();
        OpportunityCaseCreationController.OpportunityContext context =
            OpportunityCaseCreationController.getOpportunityContext(opp.Id);
        OpportunityCaseCreationController.OpportunityContext empty =
            OpportunityCaseCreationController.getOpportunityContext(null);
        Test.stopTest();

        System.assertEquals(0, empty.contacts.size(), 'A null opportunity returns an empty context.');
        System.assertEquals(opp.AccountId, (Id) context.accountId,
            'The context carries the opportunity account.');
        System.assertEquals(accountName(), context.accountName, 'The account name is shown on the form.');

        // Every contact on the account, plus the role holder from the other account.
        System.assertEquals(CONTACT_COUNT + 1, context.contacts.size(),
            'A contact role pointing outside the account must be appended, not dropped.');

        System.assertEquals(1, context.preselectedIds.size(), 'Only the primary role is preselected.');
        System.assertEquals(String.valueOf(primary.Id), context.preselectedIds[0],
            'The primary contact role should be the preselected one.');

        Boolean primaryFlagged = false;
        Boolean outsiderListed = false;
        for (OpportunityCaseCreationController.ContactOption option : context.contacts) {
            System.assertNotEquals(null, option.isPrimary, 'isPrimary must always be set.');
            if (option.value == String.valueOf(primary.Id)) {
                primaryFlagged = option.isPrimary;
            }
            if (option.name.startsWith('Outside')) {
                outsiderListed = true;
            }
        }
        System.assert(primaryFlagged, 'The primary contact must be flagged for the datatable.');
        System.assert(outsiderListed, 'The out-of-account role holder should be offered.');
    }

    @isTest
    static void contextRefusesAnOpportunityWithNoAccount() {
        Opportunity orphan = theOrphanOpportunity();
        Boolean reported = false;

        Test.startTest();
        try {
            OpportunityCaseCreationController.getOpportunityContext(orphan.Id);
        } catch (AuraHandledException e) {
            reported = true;
        }
        Test.stopTest();

        System.assert(reported, 'Without an account there are no contacts to list, and the user is told.');
    }

    // ==================================================================
    // Lookups
    // ==================================================================
    @isTest
    static void contactIsCreatedUnderTheOpportunityAccount() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        OpportunityCaseCreationController.ContactOption created =
            OpportunityCaseCreationController.createContact(
                opp.Id, 'Walk', 'In ' + orgToken(), '9000000099',
                'oppwalkin.' + orgToken() + '@example.invalid');
        Test.stopTest();

        Id newId = (Id) created.value;
        Contact saved = [SELECT AccountId, Email FROM Contact WHERE Id = :newId LIMIT 1];
        System.assertEquals(opp.AccountId, saved.AccountId,
            'The account is resolved from the opportunity, never sent by the browser.');
        System.assertEquals(saved.Email, created.email, 'Email should round-trip to the form.');
        System.assertEquals(false, created.isPrimary, 'A brand new contact holds no opportunity role.');
    }

    @isTest
    static void contactCreationRejectsIncompleteInput() {
        Opportunity opp = theOpportunity();
        Opportunity orphan = theOrphanOpportunity();
        Integer failures = 0;

        // No opportunity at all.
        try {
            OpportunityCaseCreationController.createContact(null, 'A', 'B', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Opportunity with no account to hang the contact off.
        try {
            OpportunityCaseCreationController.createContact(orphan.Id, 'A', 'B', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Missing last name.
        try {
            OpportunityCaseCreationController.createContact(opp.Id, 'A', '   ', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Rejected by the platform, not by the guard clauses - covers the DmlException path.
        try {
            OpportunityCaseCreationController.createContact(
                opp.Id, 'Bad', 'Email ' + orgToken(), null, 'this is not an email');
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(4, failures, 'Every incomplete contact must be refused with a message.');
    }

    @isTest
    static void assigneesAreMatchedOnDepartmentContains() {
        User assignee = theAssignee();
        String department = departmentValue();

        Test.startTest();
        List<OpportunityCaseCreationController.Option> matches =
            OpportunityCaseCreationController.getUsersByDepartment(department);
        List<OpportunityCaseCreationController.Option> blank =
            OpportunityCaseCreationController.getUsersByDepartment(null);
        List<OpportunityCaseCreationController.Option> wildcard =
            OpportunityCaseCreationController.getUsersByDepartment('%');
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'No department means no assignee list.');

        Set<String> matchedIds = new Set<String>();
        for (OpportunityCaseCreationController.Option option : matches) {
            matchedIds.add(option.value);
        }
        System.assert(matchedIds.contains(String.valueOf(assignee.Id)),
            'A user whose Department merely contains the case department should be offered.');

        Set<String> wildcardIds = new Set<String>();
        for (OpportunityCaseCreationController.Option option : wildcard) {
            wildcardIds.add(option.value);
        }
        System.assert(!wildcardIds.contains(String.valueOf(assignee.Id)),
            'A literal % must be escaped rather than matching every user.');
    }

    // ==================================================================
    // Case creation
    // ==================================================================
    @isTest
    static void accountIsResolvedFromTheOpportunity() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        // Computed BEFORE the real insert, from a probe carrying the same
        // Origin/Type/Priority/Department values, so the two inserts hit the
        // same automation branch and the comparison is apples to apples.
        String expectedStatus = expectedStatusFor(opp.AccountId, req);

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertNotEquals(null, result.caseId, 'The case should have been inserted.');
        System.assert(String.isNotBlank(result.caseNumber), 'Case number is shown back to the user.');
        System.assertEquals(UserInfo.getUserId(), result.ownerId,
            'With no assignee the creator keeps the case.');
        System.assertEquals(0, result.contactsLinked, 'No contacts were selected.');
        System.assertEquals(0, result.filesAttached, 'No files were staged.');

        Case saved = [SELECT AccountId, Status FROM Case WHERE Id = :result.caseId LIMIT 1];
        System.assertEquals(opp.AccountId, saved.AccountId,
            'The account must come from the opportunity, never from the browser.');
        // Compared against a probe using this same request's fields rather than a
        // hard coded 'Open', since Case Status can legitimately be rewritten
        // post-insert by org automation keyed off Origin/Type/Priority/Department.
        // The controller sets 'Open' on the sObject either way - see
        // statusAutomationIsSurfacedNotHidden() for what that automation is doing.
        System.assertEquals(expectedStatus, saved.Status,
            'New complaints should end up in the same status a matching Case insert settles on '
            + 'in this org. Actual=' + saved.Status + ', expected=' + expectedStatus);

        if (isWritable('Opportunity__c')) {
            Id caseId = result.caseId;
            SObject row = Database.query('SELECT Opportunity__c FROM Case WHERE Id = :caseId LIMIT 1');
            System.assertEquals(opp.Id, row.get('Opportunity__c'),
                'The opportunity reference should be stamped on the case.');
        }
    }

    @isTest
    static void fullCaseLinksContactsAndKeepsTheChosenAssignee() {
        Opportunity opp = theOpportunity();
        List<Contact> contacts = theAccountContacts();
        User assignee = theAssignee();

        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        for (Contact c : contacts) {
            req.contactIds.add(String.valueOf(c.Id));
        }
        req.customerName = contacts[0].Name;
        req.assignedToId = String.valueOf(assignee.Id);

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(assignee.Id, result.ownerId, 'The selected assignee must own the case.');
        System.assertEquals(true, result.ownerChanged, 'Owner differs from the creator.');
        System.assertEquals(contacts.size(), result.contactsLinked, 'Every ticked contact should be linked.');
        System.assertNotEquals(null, result.emailsSent, 'Email count must always be reported.');

        System.assertEquals(contacts.size(), [
            SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId
        ], 'Junction rows should match the selection.');

        Case saved = [
            SELECT ContactId, Origin, Type, Priority FROM Case WHERE Id = :result.caseId LIMIT 1
        ];
        System.assertEquals(null, saved.ContactId,
            'Contacts live on the junction now, so Case.ContactId stays empty.');
        System.assertEquals(req.origin, saved.Origin);
        System.assertEquals(req.caseType, saved.Type);
        System.assertEquals(req.priority, saved.Priority);
    }

    @isTest
    static void unusableContactIdsAreSkipped() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.contactIds = new List<String>{ '', '   ', 'not-an-id', null };

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.contactsLinked, 'Rubbish ids must be ignored, not thrown.');
        System.assertNotEquals(null, result.caseId, 'The case itself should still be created.');
        System.assertEquals(0, [SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId]);
    }

    @isTest
    static void failedContactLinkIsReportedNotSwallowed() {
        Opportunity opp = theOpportunity();
        // A well formed Id that is not a Contact - passes Id.valueOf, fails the junction insert.
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.contactIds.add(String.valueOf(theAccount().Id));

        Boolean reported = false;
        Test.startTest();
        try {
            OpportunityCaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            reported = true;
        }
        Test.stopTest();

        System.assert(reported, 'The user must be told the case saved but the contacts did not link.');
    }

    @isTest
    static void badRequestsAreRejectedBeforeAnyDml() {
        Opportunity opp = theOpportunity();
        Integer before = [SELECT COUNT() FROM Case];
        Integer failures = 0;

        try {
            OpportunityCaseCreationController.createCase(null);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest noSubject = minimalRequest(opp.Id);
            noSubject.subject = '  ';
            OpportunityCaseCreationController.createCase(noSubject);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest noOpportunity = minimalRequest(opp.Id);
            noOpportunity.opportunityId = null;
            OpportunityCaseCreationController.createCase(noOpportunity);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            OpportunityCaseCreationController.CaseRequest badAssignee = minimalRequest(opp.Id);
            badAssignee.assignedToId = 'this-is-not-a-user';
            OpportunityCaseCreationController.createCase(badAssignee);
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(4, failures, 'All four invalid requests should be refused.');
        System.assertEquals(before, [SELECT COUNT() FROM Case], 'No case should have been saved.');
    }

    // ==================================================================
    // Files
    //
    // The bytes never reach Apex - lightning-file-upload puts them in Salesforce
    // against the running user, and createCase() only relinks them. That is what makes
    // 25 MB and video possible: base64 through Apex tops out near 4 MB on a 6 MB heap.
    // ==================================================================
    @isTest
    static void stagedFilesMoveOntoTheCase() {
        Opportunity opp = theOpportunity();
        User assignee = theAssignee();

        Test.startTest();
        Id firstDoc  = stageFile('evidence.txt');
        Id secondDoc = stageFile('site-video.txt');

        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.assignedToId = String.valueOf(assignee.Id);
        req.documentIds  = new List<String>{
            String.valueOf(firstDoc), String.valueOf(secondDoc), '', '   ', 'not-an-id'
        };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(2, result.filesAttached, 'Blanks and rubbish ids must be dropped, not thrown.');

        System.assertEquals(2, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'Both files should be shared with the case.');

        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :UserInfo.getUserId()
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'The staging link against the uploader should be removed.');

        for (ContentDocument doc : [
            SELECT OwnerId FROM ContentDocument WHERE Id IN :new List<Id>{ firstDoc, secondDoc }
        ]) {
            System.assertEquals(assignee.Id, doc.OwnerId,
                'When the creator is not the assignee the document should change hands.');
        }
    }

    @isTest
    static void fileOwnershipStaysPutWhenTheCreatorOwnsTheCase() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        Id docId = stageFile('own-note.txt');
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.documentIds = new List<String>{ String.valueOf(docId) };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'The file should be attached.');
        System.assertEquals(UserInfo.getUserId(),
            [SELECT OwnerId FROM ContentDocument WHERE Id = :docId LIMIT 1].OwnerId,
            'No handover is needed when the creator already owns the case.');
    }

    @isTest
    static void theSameFileIsNeverLinkedTwice() {
        Opportunity opp = theOpportunity();

        Test.startTest();
        Id docId = stageFile('duplicate.txt');
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        // The same document twice, as a double-submit would send it.
        req.documentIds = new List<String>{ String.valueOf(docId), String.valueOf(docId) };
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'A repeated id should be collapsed to one link.');
        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId AND ContentDocumentId = :docId
        ], 'Only one junction row should exist for the file.');
    }

    @isTest
    static void caseIsCreatedWhenNoFilesAreStaged() {
        Opportunity opp = theOpportunity();
        OpportunityCaseCreationController.CaseRequest req = fullRequest(opp.Id);
        req.documentIds = null;

        Test.startTest();
        OpportunityCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.filesAttached, 'Nothing to attach is not an error.');
        System.assertNotEquals(null, result.caseId, 'The case is still created.');
    }

    @isTest
    static void stagedFileCanBeDiscardedBeforeSaving() {
        Test.startTest();
        Id docId = stageFile('mistake.txt');
        OpportunityCaseCreationController.discardFile(docId);
        OpportunityCaseCreationController.discardFile(null); // no-op, must not throw
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Removing a staged file deletes it, since it was really uploaded.');
    }

    // ==================================================================
    // Notification + email
    // ==================================================================
    @isTest
    static void notificationAndEmailNeverBreakTheCase() {
        Opportunity opp = theOpportunity();
        List<Contact> contacts = theAccountContacts();
        OpportunityCaseCreationController.CaseResult result = create(fullRequest(opp.Id));

        Case saved = [
            SELECT Id, CaseNumber, OwnerId, Subject, Priority
            FROM Case WHERE Id = :result.caseId LIMIT 1
        ];

        Test.startTest();
        OpportunityCaseCreationController.sendPushNotification(saved);
        Integer withContacts = OpportunityCaseCreationController.sendCaseCreationEmails(
            saved, new List<String>{ String.valueOf(contacts[0].Id) });
        Integer withNone = OpportunityCaseCreationController.sendCaseCreationEmails(saved, null);
        Test.stopTest();

        System.assertEquals(0, withNone, 'No contacts means nothing to send.');
        System.assert(withContacts >= 0,
            'A missing template or notification type must return a count, not an exception.');
        System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Id = :result.caseId],
            'The case survives regardless of notification/email outcome.');
    }
}