/**
 * AccountCaseCreationControllerTest
 *
 * No hard coded Ids or org specific values: record Ids come from @TestSetup,
 * picklist values come from the field describe of the running org, and the
 * assignee's profile / locale settings are copied from the running user.
 *
 * If createCase() fails, read caseInsertIsNotBlockedByOrgConfig() first - it
 * reports the DML reason directly instead of a bare stack trace.
 */
@isTest
private class AccountCaseCreationControllerTest {

    private static final Integer CONTACT_COUNT = 3;

    // ------------------------------------------------------------------
    // Org derived tokens (deterministic across transactions, no literals)
    // ------------------------------------------------------------------
    private static String orgToken() {
        return String.valueOf(UserInfo.getOrganizationId()).toLowerCase();
    }

    private static String accountName() {
        return 'Case Intake Account ' + orgToken();
    }

    private static String secondAccountName() {
        return 'Case Intake Related Account ' + orgToken();
    }

    private static String assigneeUsername() {
        return 'case.intake.' + orgToken() + '@example.invalid';
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
    private static Map<String, AccountCaseCreationController.PicklistField> formFields;

    private static Map<String, AccountCaseCreationController.PicklistField> form() {
        if (formFields == null) {
            formFields = new Map<String, AccountCaseCreationController.PicklistField>();
            for (AccountCaseCreationController.PicklistField f :
                    AccountCaseCreationController.getFormPicklists()) {
                formFields.put(f.fieldApiName, f);
            }
        }
        return formFields;
    }

    @isTest
    static void validForBitsetMapsOntoControllingValues() {
        List<String> controlling = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            controlling.add('V' + i);
        }
        // 0x80 -> bit 0 of byte 0 -> index 0 ; 0x40 -> bit 1 of byte 1 -> index 9
        String encoded = EncodingUtil.base64Encode(EncodingUtil.convertFromHex('8040'));

        Test.startTest();
        List<String> valid   = AccountCaseCreationController.decodeValidFor(encoded, controlling);
        List<String> blank   = AccountCaseCreationController.decodeValidFor('   ', controlling);
        List<String> noCtrl  = AccountCaseCreationController.decodeValidFor(encoded, new List<String>());
        // Bitset longer than the controlling list - the index guard must stop the loop.
        List<String> clipped = AccountCaseCreationController.decodeValidFor(
            encoded, new List<String>{ 'V0' });
        Test.stopTest();

        System.assertEquals(new List<String>{ 'V0', 'V9' }, valid, 'Set bits map to their controlling values.');
        System.assertEquals(0, blank.size(), 'No bitset means independent.');
        System.assertEquals(0, noCtrl.size(), 'No controlling values means nothing to map onto.');
        System.assertEquals(new List<String>{ 'V0' }, clipped, 'Extra bits must be ignored, not thrown.');
    }

    /**
     * First value of a picklist that is actually valid for the controlling value,
     * read straight off the controller's own validFor output. Keeps dependent
     * picklist validation rules happy without hard coding a single value.
     */
    private static String firstValidValue(String apiName, String controllingValue) {
        AccountCaseCreationController.PicklistField field = form().get(apiName);
        if (field == null || field.options.isEmpty()) {
            return null;
        }
        for (AccountCaseCreationController.Option option : field.options) {
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
            new Account(Name = secondAccountName())
        };
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < CONTACT_COUNT; i++) {
            contacts.add(new Contact(
                AccountId = accounts[0].Id,
                FirstName = 'Intake',
                LastName  = 'Contact ' + i + ' ' + orgToken(),
                Phone     = '900000000' + i,
                Email     = 'intake' + i + '.' + orgToken() + '@example.invalid'
            ));
        }
        insert contacts;

        // Indirect relationship, so relatedContacts() has something to walk.
        // Silently skipped if Contacts to Multiple Accounts is off in this org.
        try {
            SObject relation = Schema.getGlobalDescribe()
                .get('AccountContactRelation').newSObject();
            relation.put('AccountId', accounts[0].Id);
            relation.put('ContactId', contacts[0].Id);
            insert relation;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'AccountContactRelation not usable: ' + e.getMessage());
        }

        // User is a setup object, so it needs its own DML context.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert buildAssignee();
        }
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
            FirstName         = 'Case',
            LastName          = 'Assignee',
            Alias             = orgToken().left(8),
            Email             = username,
            Username          = username,
            Department        = userDepartmentValue()
        );
    }

    private static Account theAccount() {
        String name = accountName();
        return [SELECT Id, Name FROM Account WHERE Name = :name LIMIT 1];
    }

    private static Account theOtherAccount() {
        String name = secondAccountName();
        return [SELECT Id, Name FROM Account WHERE Name = :name LIMIT 1];
    }

    private static List<Contact> theContacts() {
        Id accId = theAccount().Id;
        return [SELECT Id, Name, Phone, Email FROM Contact WHERE AccountId = :accId ORDER BY Name];
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

    // ------------------------------------------------------------------
    // Requests
    // ------------------------------------------------------------------
    /** Only the fields createCase() insists on - for the validation tests. */
    private static AccountCaseCreationController.CaseRequest minimalRequest(Id accountId) {
        AccountCaseCreationController.CaseRequest req = new AccountCaseCreationController.CaseRequest();
        req.accountId = accountId;
        req.subject   = 'Complaint ' + orgToken();
        return req;
    }

    /**
     * Everything the form can send, with dependent picklists resolved against their
     * controlling value. Used by every test that actually reaches the insert, so an
     * org side "this field is required" rule does not take the whole class down.
     */
    private static AccountCaseCreationController.CaseRequest fullRequest(Id accountId) {
        AccountCaseCreationController.CaseRequest req = minimalRequest(accountId);
        req.department    = firstPicklistValue('Department__c');
        req.subDepartment = firstValidValue('Sub_Department__c', req.department);
        req.origin        = firstPicklistValue('Origin');
        req.caseType      = firstPicklistValue('Type');
        req.subCategory   = firstValidValue('Sub_Category__c', req.caseType);
        req.priority      = firstPicklistValue('Priority');
        req.description   = 'Raised from the account record page.';
        req.comments      = 'Internal note ' + orgToken();
        req.contactIds    = new List<String>();
        req.documentIds   = new List<String>();
        return req;
    }

    /** createCase() with the failure reason surfaced instead of a bare stack frame. */
    private static AccountCaseCreationController.CaseResult create(
            AccountCaseCreationController.CaseRequest req) {
        try {
            return AccountCaseCreationController.createCase(req);
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
        Account acc = theAccount();
        Case probe = new Case(
            AccountId = acc.Id,
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
    static void formPicklistsComeBackForEveryField() {
        Test.startTest();
        List<AccountCaseCreationController.PicklistField> fields =
            AccountCaseCreationController.getFormPicklists();
        Test.stopTest();

        System.assert(!fields.isEmpty(), 'The form cannot render without picklist metadata.');

        for (AccountCaseCreationController.PicklistField field : fields) {
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

    @isTest
    static void dependentPicklistsCarryTheirControllingValues() {
        Test.startTest();
        List<AccountCaseCreationController.PicklistField> fields =
            AccountCaseCreationController.getFormPicklists();
        Test.stopTest();

        for (AccountCaseCreationController.PicklistField field : fields) {
            Schema.DescribeFieldResult dfr = caseField(field.fieldApiName);
            if (dfr == null || field.options.isEmpty()) {
                continue;
            }
            for (AccountCaseCreationController.Option option : field.options) {
                System.assertNotEquals(null, option.validFor,
                    'validFor must be initialised even for independent picklists: ' + field.fieldApiName);
                if (!dfr.isDependentPicklist()) {
                    System.assert(option.validFor.isEmpty(),
                        field.fieldApiName + ' is independent, so validFor should stay empty.');
                }
            }
        }
    }

    // ==================================================================
    // Lookups
    // ==================================================================
    @isTest
    static void accountContactsAreReturnedWithoutDuplicates() {
        Account acc = theAccount();
        Map<Id, Contact> expected = new Map<Id, Contact>(theContacts());

        Test.startTest();
        List<AccountCaseCreationController.ContactOption> options =
            AccountCaseCreationController.getContactsForAccount(acc.Id);
        List<AccountCaseCreationController.ContactOption> empty =
            AccountCaseCreationController.getContactsForAccount(null);
        Test.stopTest();

        System.assertEquals(0, empty.size(), 'A null account must return an empty list, not an error.');

        Set<Id> returned = new Set<Id>();
        for (AccountCaseCreationController.ContactOption option : options) {
            returned.add((Id) option.value);
            System.assert(String.isNotBlank(option.name), 'Name is used by the form.');
            System.assert(option.label.contains(option.email),
                'The label should show the email when there is one.');
        }
        System.assert(returned.containsAll(expected.keySet()), 'Every related contact should be offered.');
        System.assertEquals(expected.size(), returned.size(),
            'A contact reachable both directly and through AccountContactRelation must appear once.');
    }

    @isTest
    static void contactCanBeAddedInline() {
        Account acc = theAccount();

        Test.startTest();
        AccountCaseCreationController.ContactOption created =
            AccountCaseCreationController.createContact(
                acc.Id, 'Walk', 'In ' + orgToken(), '9000000099',
                'walkin.' + orgToken() + '@example.invalid');
        Test.stopTest();

        System.assertNotEquals(null, created.value, 'The new contact should be returned to the form.');
        Id newId = (Id) created.value;
        Contact saved = [SELECT AccountId, Email FROM Contact WHERE Id = :newId LIMIT 1];
        System.assertEquals(acc.Id, saved.AccountId, 'The contact must sit under the launching account.');
        System.assertEquals(saved.Email, created.email, 'Email should round-trip to the form.');
    }

    @isTest
    static void contactCreationRejectsIncompleteInput() {
        Account acc = theAccount();
        Integer failures = 0;

        try {
            AccountCaseCreationController.createContact(null, 'A', 'B', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        try {
            AccountCaseCreationController.createContact(acc.Id, 'A', '   ', null, null);
        } catch (AuraHandledException e) {
            failures++;
        }
        // Rejected by the platform, not by the guard clauses - covers the DmlException path.
        try {
            AccountCaseCreationController.createContact(
                acc.Id, 'Bad', 'Email ' + orgToken(), null, 'this is not an email');
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(3, failures, 'Missing account, missing last name and a bad email must all fail.');
    }

    @isTest
    static void assigneesAreMatchedOnDepartmentContains() {
        User assignee = theAssignee();
        String department = departmentValue();

        Test.startTest();
        List<AccountCaseCreationController.Option> matches =
            AccountCaseCreationController.getUsersByDepartment(department);
        List<AccountCaseCreationController.Option> blank =
            AccountCaseCreationController.getUsersByDepartment(null);
        List<AccountCaseCreationController.Option> wildcard =
            AccountCaseCreationController.getUsersByDepartment('%');
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'No department means no assignee list.');

        Set<String> matchedIds = new Set<String>();
        for (AccountCaseCreationController.Option option : matches) {
            matchedIds.add(option.value);
        }
        System.assert(matchedIds.contains(String.valueOf(assignee.Id)),
            'A user whose Department merely contains the case department should be offered.');

        Set<String> wildcardIds = new Set<String>();
        for (AccountCaseCreationController.Option option : wildcard) {
            wildcardIds.add(option.value);
        }
        System.assert(!wildcardIds.contains(String.valueOf(assignee.Id)),
            'A literal % must be escaped rather than matching every user.');
    }

    // ==================================================================
    // Case creation
    // ==================================================================
    @isTest
    static void caseIsOwnedByTheCreatorWhenNobodyIsSelected() {
        Account acc = theAccount();

        Test.startTest();
        AccountCaseCreationController.CaseResult result = create(fullRequest(acc.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.caseId, 'The case should have been inserted.');
        System.assert(String.isNotBlank(result.caseNumber), 'Case number is shown back to the user.');
        System.assertEquals(UserInfo.getUserId(), result.ownerId,
            'With no assignee the creator keeps the case.');
        System.assertEquals(false, result.ownerChanged, 'Owner did not change.');
        System.assertEquals(0, result.contactsLinked, 'No contacts were selected.');
        System.assertEquals(0, result.filesAttached, 'No files were staged.');

        Case saved = [SELECT AccountId, Status FROM Case WHERE Id = :result.caseId LIMIT 1];
        System.assertEquals(acc.Id, saved.AccountId, 'The case belongs to the launching account.');
        //System.assertEquals('Open', saved.Status, 'New complaints start Open.');
    }

    @isTest
    static void fullCaseLinksContactsAndKeepsTheChosenAssignee() {
        Account acc = theAccount();
        List<Contact> contacts = theContacts();
        User assignee = theAssignee();

        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        for (Contact c : contacts) {
            req.contactIds.add(String.valueOf(c.Id));
        }
        req.customerName = contacts[0].Name;
        req.assignedToId = String.valueOf(assignee.Id);

        Test.startTest();
        AccountCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(assignee.Id, result.ownerId, 'The selected assignee must own the case.');
        System.assertEquals(true, result.ownerChanged, 'Owner differs from the creator.');
        System.assertEquals(contacts.size(), result.contactsLinked, 'Every ticked contact should be linked.');
        System.assertNotEquals(null, result.emailsSent, 'Email count must always be reported.');

        List<Case_Contacts__c> links = [
            SELECT Contact__c FROM Case_Contacts__c WHERE Case__c = :result.caseId
        ];
        System.assertEquals(contacts.size(), links.size(), 'Junction rows should match the selection.');

        Case saved = [
            SELECT ContactId, Origin, Type, Priority, Description
            FROM Case WHERE Id = :result.caseId LIMIT 1
        ];
        System.assertEquals(null, saved.ContactId,
            'Contacts live on the junction now, so Case.ContactId stays empty.');
        System.assertEquals(req.origin, saved.Origin);
        System.assertEquals(req.caseType, saved.Type);
        System.assertEquals(req.priority, saved.Priority);

        if (String.isNotBlank(req.department) && isWritable('Department__c')) {
            Id caseId = result.caseId;
            SObject row = Database.query('SELECT Department__c FROM Case WHERE Id = :caseId LIMIT 1');
            System.assertEquals(req.department, String.valueOf(row.get('Department__c')),
                'The department the user picked should be stored.');
        }
    }

    @isTest
    static void unusableContactIdsAreSkipped() {
        Account acc = theAccount();
        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        req.contactIds = new List<String>{ '', '   ', 'not-an-id', null };

        Test.startTest();
        AccountCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.contactsLinked, 'Rubbish ids must be ignored, not thrown.');
        System.assertNotEquals(null, result.caseId, 'The case itself should still be created.');
        System.assertEquals(0, [SELECT COUNT() FROM Case_Contacts__c WHERE Case__c = :result.caseId]);
    }

    @isTest
    static void failedContactLinkIsReportedNotSwallowed() {
        Account acc = theAccount();
        // A well formed Id that is not a Contact - passes Id.valueOf, fails the junction insert.
        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        req.contactIds.add(String.valueOf(theOtherAccount().Id));

        Boolean reported = false;
        Test.startTest();
        try {
            AccountCaseCreationController.createCase(req);
        } catch (AuraHandledException e) {
            reported = true;
        }
        Test.stopTest();

        System.assert(reported, 'The user must be told the case saved but the contacts did not link.');
    }

    @isTest
    static void badRequestsAreRejectedBeforeAnyDml() {
        Account acc = theAccount();
        Integer before = [SELECT COUNT() FROM Case];
        Integer failures = 0;

        try {
            AccountCaseCreationController.createCase(null);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            AccountCaseCreationController.CaseRequest noSubject = minimalRequest(acc.Id);
            noSubject.subject = '  ';
            AccountCaseCreationController.createCase(noSubject);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            AccountCaseCreationController.CaseRequest noAccount = minimalRequest(acc.Id);
            noAccount.accountId = null;
            AccountCaseCreationController.createCase(noAccount);
        } catch (AuraHandledException e) {
            failures++;
        }

        try {
            AccountCaseCreationController.CaseRequest badAssignee = minimalRequest(acc.Id);
            badAssignee.assignedToId = 'this-is-not-a-user';
            AccountCaseCreationController.createCase(badAssignee);
        } catch (AuraHandledException e) {
            failures++;
        }

        System.assertEquals(4, failures, 'All four invalid requests should be refused.');
        System.assertEquals(before, [SELECT COUNT() FROM Case], 'No case should have been saved.');
    }

    // ==================================================================
    // Files
    //
    // The bytes never reach Apex now - lightning-file-upload puts them in Salesforce
    // against the running user, and createCase() only relinks them. That is what makes
    // 25 MB and video possible: base64 through Apex tops out near 4 MB on a 6 MB heap.
    // ==================================================================
    @isTest
    static void stagedFilesMoveOntoTheCase() {
        Account acc = theAccount();
        User assignee = theAssignee();

        Test.startTest();
        Id firstDoc  = stageFile('evidence.txt');
        Id secondDoc = stageFile('site-video.txt');

        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        req.assignedToId = String.valueOf(assignee.Id);
        req.documentIds  = new List<String>{
            String.valueOf(firstDoc), String.valueOf(secondDoc), '', '   ', 'not-an-id'
        };
        AccountCaseCreationController.CaseResult result = create(req);
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
        Account acc = theAccount();

        Test.startTest();
        Id docId = stageFile('own-note.txt');
        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        req.documentIds = new List<String>{ String.valueOf(docId) };
        AccountCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'The file should be attached.');
        System.assertEquals(UserInfo.getUserId(),
            [SELECT OwnerId FROM ContentDocument WHERE Id = :docId LIMIT 1].OwnerId,
            'No handover is needed when the creator already owns the case.');
    }

    @isTest
    static void theSameFileIsNeverLinkedTwice() {
        Account acc = theAccount();

        Test.startTest();
        Id docId = stageFile('duplicate.txt');
        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        // The same document twice, as a double-submit would send it.
        req.documentIds = new List<String>{ String.valueOf(docId), String.valueOf(docId) };
        AccountCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(1, result.filesAttached, 'A repeated id should be collapsed to one link.');
        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId AND ContentDocumentId = :docId
        ], 'Only one junction row should exist for the file.');
    }

    @isTest
    static void caseIsCreatedWhenNoFilesAreStaged() {
        Account acc = theAccount();
        AccountCaseCreationController.CaseRequest req = fullRequest(acc.Id);
        req.documentIds = null;

        Test.startTest();
        AccountCaseCreationController.CaseResult result = create(req);
        Test.stopTest();

        System.assertEquals(0, result.filesAttached, 'Nothing to attach is not an error.');
        System.assertNotEquals(null, result.caseId, 'The case is still created.');
    }

    @isTest
    static void stagedFileCanBeDiscardedBeforeSaving() {
        Test.startTest();
        Id docId = stageFile('mistake.txt');
        AccountCaseCreationController.discardFile(docId);
        AccountCaseCreationController.discardFile(null); // no-op, must not throw
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Removing a staged file deletes it, since it was really uploaded.');
    }

    // ==================================================================
    // Notification + email
    // ==================================================================
    @isTest
    static void notificationAndEmailNeverBreakTheCase() {
        Account acc = theAccount();
        List<Contact> contacts = theContacts();
        AccountCaseCreationController.CaseResult result = create(fullRequest(acc.Id));

        Case saved = [
            SELECT Id, CaseNumber, OwnerId, Subject, Priority
            FROM Case WHERE Id = :result.caseId LIMIT 1
        ];

        Test.startTest();
        AccountCaseCreationController.sendPushNotification(saved);
        Integer withContacts = AccountCaseCreationController.sendCaseCreationEmails(
            saved, new List<String>{ String.valueOf(contacts[0].Id) });
        Integer withNone = AccountCaseCreationController.sendCaseCreationEmails(saved, null);
        Test.stopTest();

        System.assertEquals(0, withNone, 'No contacts means nothing to send.');
        System.assert(withContacts >= 0,
            'A missing template or notification type must return a count, not an exception.');
        System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Id = :result.caseId],
            'The case survives regardless of notification/email outcome.');
    }
}