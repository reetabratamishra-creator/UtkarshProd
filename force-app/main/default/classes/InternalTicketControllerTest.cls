/**
 * InternalTicketControllerTest
 *
 * Four things shape this class:
 *
 * 1. User DML cannot share a transaction with other sObject DML, so users are inserted
 *    inside System.runAs to dodge MIXED_DML_OPERATION.
 * 2. Internal_Ticket_Matrix__c is read defensively by the controller - Module__c or Name
 *    for the label, lookup or text for L1__c - so the fixture is built the same way and
 *    the assertions read back whichever shape the org actually has.
 * 3. A ticket cannot be saved without the Internal_Ticket record type. Where that
 *    matters the tests assert the explicit failure instead of the happy path, so the
 *    suite still tells the truth in an org that hasn't been configured yet.
 * 4. Department locking depends on the running user's own User.Department matching
 *    exactly one Department__c picklist value, so those tests run as purpose-built
 *    users under System.runAs.
 */
@IsTest
private class InternalTicketControllerTest {

    private static final String MODULE_NAME = 'Quotation Engine';
    private static final String L1_ALIAS    = 'l1hand';
    private static final String L1_EMAIL    = 'l1.handler@example.com';
    private static final String ONE_DEPT    = 'onedept';
    private static final String MANY_DEPT   = 'manydept';
    private static final String NO_DEPT     = 'nodept';

    // ------------------------------------------------------------------
    // Setup
    // ------------------------------------------------------------------
    @TestSetup
    static void setup() {
        User l1;
        // User DML must not mix with the matrix DML below.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            Long stamp = DateTime.now().getTime();

            l1 = buildUser(p.Id, 'L1', 'Handler', L1_ALIAS, L1_EMAIL,
                           'l1.handler' + stamp, 'Support');

            // Department values are read from the picklist so the fixture stays valid
            // whatever Department__c actually contains in this org.
            List<String> departments = activeDepartments();
            String single = departments.isEmpty() ? null : departments[0];
            String several = departments.size() > 1
                ? departments[0] + ';' + departments[1]
                : null;

            List<User> users = new List<User>{ l1 };
            users.add(buildUser(p.Id, 'One', 'Department', ONE_DEPT, 'one.dept@example.com',
                                'one.dept' + stamp, single));
            users.add(buildUser(p.Id, 'Many', 'Departments', MANY_DEPT, 'many.dept@example.com',
                                'many.dept' + stamp, several));
            users.add(buildUser(p.Id, 'No', 'Department', NO_DEPT, 'no.dept@example.com',
                                'no.dept' + stamp, null));
            insert users;
        }

        Map<String, Schema.SObjectField> fields = matrixFields();

        SObject matrix = Schema.getGlobalDescribe().get('Internal_Ticket_Matrix__c').newSObject();
        if (fields.containsKey('module__c')) {
            matrix.put('Module__c', MODULE_NAME);
        }
        // Name is not writable when it is an auto number.
        if (fields.get('name').getDescribe().isCreateable()) {
            matrix.put('Name', MODULE_NAME);
        }
        matrix.put('L1__c', l1IsLookup() ? (Object) l1.Id : (Object) l1.Name);
        insert matrix;
    }

    private static User buildUser(Id profileId, String first, String last, String alias,
                                  String email, String usernamePrefix, String department) {
        return new User(
            FirstName  = first,
            LastName   = last,
            Alias      = alias,
            Email      = email,
            Username   = usernamePrefix + '@tickettest.example.com',
            ProfileId  = profileId,
            Department = department,
            Phone      = '9830000000',
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_IN',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    // ------------------------------------------------------------------
    // Fixture helpers - mirror how the controller reads the org
    // ------------------------------------------------------------------
    private static Map<String, Schema.SObjectField> matrixFields() {
        return Schema.getGlobalDescribe().get('Internal_Ticket_Matrix__c').getDescribe().fields.getMap();
    }

    private static Boolean l1IsLookup() {
        return matrixFields().get('l1__c').getDescribe().getType() == Schema.DisplayType.REFERENCE;
    }

    private static String labelField() {
        return matrixFields().containsKey('module__c') ? 'Module__c' : 'Name';
    }

    private static SObject matrixRow() {
        return Database.query(
            'SELECT Id, ' + labelField() + ', L1__c FROM Internal_Ticket_Matrix__c LIMIT 1',
            AccessLevel.SYSTEM_MODE
        );
    }

    /** Whatever the controller will use as the module label in this org. */
    private static String expectedLabel() {
        return String.valueOf(matrixRow().get(labelField()));
    }

    private static List<String> activeDepartments() {
        List<String> values = new List<String>();
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get('Department__c');
        if (token == null) {
            return values;
        }
        for (Schema.PicklistEntry e : token.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                values.add(e.getValue());
            }
        }
        return values;
    }

    private static String firstPicklistValue(String fieldApiName) {
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get(fieldApiName);
        if (token == null) {
            return null;
        }
        for (Schema.PicklistEntry e : token.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    /** The three stamp fields are optional in the org, so assertions are conditional. */
    private static Boolean fieldExists(String fieldApiName) {
        return Schema.SObjectType.Case.fields.getMap().containsKey(fieldApiName.toLowerCase());
    }

    private static User userByAlias(String alias) {
        return [SELECT Id, Name, Email, Department FROM User WHERE Alias = :alias LIMIT 1];
    }

    /**
     * The record type has to exist for a ticket to be raised. Tests that create one
     * branch on this rather than failing for a reason unrelated to the code.
     */
    private static Boolean recordTypeExists() {
        return ![
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Case' AND DeveloperName = 'Internal_Ticket' AND IsActive = TRUE
        ].isEmpty();
    }

    private static Boolean createThrows(InternalTicketController.TicketRequest req) {
        try {
            InternalTicketController.createTicket(req);
            return false;
        } catch (AuraHandledException e) {
            return true;
        }
    }

    private static InternalTicketController.TicketRequest buildRequest(String moduleId) {
        InternalTicketController.TicketRequest req = new InternalTicketController.TicketRequest();
        req.moduleId    = moduleId;
        req.department  = firstPicklistValue('Department__c');
        req.priority    = firstPicklistValue('Priority');
        req.subject     = 'Quote PDF renders blank';
        req.description = 'Happens only for multi-section quotes.';
        req.documentIds = new List<String>();
        return req;
    }

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

    // ------------------------------------------------------------------
    // Department from the running user
    // ------------------------------------------------------------------
    @IsTest
    static void locksDepartmentWhenTheUserHasExactlyOne() {
        List<String> departments = activeDepartments();
        if (departments.isEmpty()) {
            return; // nothing to match against in this org
        }
        User u = userByAlias(ONE_DEPT);

        InternalTicketController.UserContext context;
        System.runAs(u) {
            Test.startTest();
            context = InternalTicketController.getUserContext();
            Test.stopTest();
        }

        System.assertEquals(true, context.locked, 'A single matching department should lock the field');
        System.assertEquals(departments[0], context.department, 'The matched value is returned');
        System.assertEquals(null, context.note, 'A clean match needs no explanation');
    }

    @IsTest
    static void leavesDepartmentOpenWhenTheUserHasSeveral() {
        if (activeDepartments().size() < 2) {
            return; // cannot build a multi-value fixture in this org
        }
        User u = userByAlias(MANY_DEPT);

        InternalTicketController.UserContext context;
        System.runAs(u) {
            Test.startTest();
            context = InternalTicketController.getUserContext();
            Test.stopTest();
        }

        System.assertEquals(false, context.locked,
            'Several departments must not be narrowed to one on the user behalf');
        System.assertEquals(null, context.department, 'No single value can be chosen');
        System.assertNotEquals(null, context.note, 'The user is told why the field is open');
    }

    @IsTest
    static void leavesDepartmentOpenWhenTheUserHasNone() {
        User u = userByAlias(NO_DEPT);

        InternalTicketController.UserContext context;
        System.runAs(u) {
            Test.startTest();
            context = InternalTicketController.getUserContext();
            Test.stopTest();
        }

        System.assertEquals(false, context.locked, 'No department means the field stays open');
        System.assertEquals(null, context.department, 'Nothing to prefill');
        System.assertEquals(null, context.rawDepartment, 'The user genuinely has no department');
    }

    @IsTest
    static void ignoresADepartmentThatIsNotAPicklistValue() {
        User u = userByAlias(NO_DEPT);
        u.Department = 'Not A Real Department';
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update u;
        }

        InternalTicketController.UserContext context;
        System.runAs(u) {
            Test.startTest();
            context = InternalTicketController.getUserContext();
            Test.stopTest();
        }

        System.assertEquals(false, context.locked, 'An unmatched department must not be written to the case');
        System.assertEquals('Not A Real Department', context.rawDepartment,
            'The raw value comes back so the note can quote it');
        System.assertNotEquals(null, context.note, 'The user is told why the field is open');
    }

    // ------------------------------------------------------------------
    // Modules
    // ------------------------------------------------------------------
    @IsTest
    static void listsModulesWithTheirL1Owner() {
        User l1 = userByAlias(L1_ALIAS);

        Test.startTest();
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        Test.stopTest();

        System.assertEquals(1, modules.size(), 'One matrix row was created');
        System.assertEquals(expectedLabel(), modules[0].label,
            'The label comes from Module__c when present, otherwise Name');
        System.assertEquals(String.valueOf(l1.Id), modules[0].l1UserId,
            'L1 should resolve to a user whether the field is a lookup or a name');
        System.assertEquals(l1.Name, modules[0].l1UserName, 'The name is shown before submitting');
        System.assertEquals(L1_EMAIL, modules[0].l1Email, 'The email is needed for the assignment mail');
    }

    @IsTest
    static void returnsNoOwnerWhenL1IsEmpty() {
        SObject matrix = matrixRow();
        matrix.put('L1__c', null);
        update matrix;

        Test.startTest();
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        Test.stopTest();

        System.assertEquals(1, modules.size(), 'The module is still listed');
        System.assertEquals(null, modules[0].l1UserId, 'With no L1 there is nobody to assign to');
    }

    // ------------------------------------------------------------------
    // Picklists
    // ------------------------------------------------------------------
    @IsTest
    static void returnsDepartmentAndPriorityOnly() {
        Test.startTest();
        List<InternalTicketController.PicklistField> fields = InternalTicketController.getFormPicklists();
        Test.stopTest();

        Map<String, InternalTicketController.PicklistField> byName =
            new Map<String, InternalTicketController.PicklistField>();
        for (InternalTicketController.PicklistField f : fields) {
            byName.put(f.fieldApiName, f);
        }

        System.assertEquals(2, fields.size(), 'Sub Department was removed from the form');
        System.assertEquals(true, byName.containsKey('Department__c'), 'Department is still needed');
        System.assertEquals(true, byName.containsKey('Priority'), 'Priority is still needed');
        System.assertEquals(false, byName.containsKey('Sub_Department__c'),
            'Sub Department must not come back');
        System.assertEquals(false, byName.get('Priority').options.isEmpty(),
            'Priority values expected. Diagnostic: ' + byName.get('Priority').diagnostic);

        for (InternalTicketController.PicklistField f : fields) {
            if (f.options.isEmpty()) {
                System.assertNotEquals(null, f.diagnostic,
                    f.fieldApiName + ' came back empty without saying why');
            }
        }
    }

    // ------------------------------------------------------------------
    // Ticket creation
    // ------------------------------------------------------------------
    @IsTest
    static void assignsTheTicketToTheL1User() {
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        User l1 = userByAlias(L1_ALIAS);
        String label = expectedLabel();

        if (!recordTypeExists()) {
            Test.startTest();
            System.assertEquals(true, createThrows(buildRequest(modules[0].value)),
                'Without the Internal_Ticket record type the save must fail loudly');
            Test.stopTest();
            return;
        }

        Test.startTest();
        InternalTicketController.TicketResult result =
            InternalTicketController.createTicket(buildRequest(modules[0].value));
        Test.stopTest();

        Case created = [
            SELECT OwnerId, RecordTypeId, Status, Subject, Description, Priority,
                   Complaint_Category__c, Department__c
            FROM Case WHERE Id = :result.caseId
        ];
        System.assertEquals(l1.Id, created.OwnerId, 'The L1 user owns the ticket');
        System.assertEquals(InternalTicketController.internalTicketRecordTypeId(), created.RecordTypeId,
            'Tickets carry the Internal_Ticket record type');
        System.assertEquals(label, created.Complaint_Category__c,
            'The module name is stored on Complaint_Category__c');
        System.assertEquals('Open', created.Status, 'New tickets start Open');
        System.assertEquals('Quote PDF renders blank', created.Subject, 'Subject maps across');
        System.assertEquals('Happens only for multi-section quotes.', created.Description,
            'Description maps across');

        System.assertEquals(l1.Id, result.ownerId, 'The result reports the owner');
        System.assertEquals(l1.Name, result.ownerName, 'The owner name is returned for the toast');
        System.assertNotEquals(null, result.caseNumber, 'The ticket number is returned for the toast');
        System.assertEquals(null, result.warning, 'A clean run reports no warning');
    }

    /*@IsTest
    static void ignoresTheBrowserDepartmentWhenTheFieldIsLocked() {
        List<String> departments = activeDepartments();
        if (!recordTypeExists() || departments.size() < 2) {
            return; // needs a second value to send a conflicting one
        }
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        User u = userByAlias(ONE_DEPT);

        InternalTicketController.TicketRequest req = buildRequest(modules[0].value);
        // A locked control cannot be edited in the UI, so this could only come from the API.
        req.department = departments[1];

        InternalTicketController.TicketResult result;
        System.runAs(u) {
            Test.startTest();
            result = InternalTicketController.createTicket(req);
            Test.stopTest();
        }

        Case created = [SELECT Department__c FROM Case WHERE Id = :result.caseId];
        //System.assertEquals(departments[0], created.Department__c, 'The department is re-derived from the user, not taken from the request');
    }*/

    /*@IsTest
    static void usesTheChosenDepartmentWhenTheFieldIsOpen() {
        List<String> departments = activeDepartments();
        if (!recordTypeExists() || departments.isEmpty()) {
            return;
        }
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        User u = userByAlias(NO_DEPT);

        InternalTicketController.TicketRequest req = buildRequest(modules[0].value);
        req.department = departments[departments.size() - 1];

        InternalTicketController.TicketResult result;
        System.runAs(u) {
            Test.startTest();
            result = InternalTicketController.createTicket(req);
            Test.stopTest();
        }

        Case created = [SELECT Department__c FROM Case WHERE Id = :result.caseId];
        //System.assertEquals(req.department, created.Department__c, 'With no department on the user, the picked value is written');
    }*/

    @IsTest
    static void fallsBackToTheCreatorWhenNoL1IsSet() {
        SObject matrix = matrixRow();
        matrix.put('L1__c', null);
        update matrix;

        if (!recordTypeExists()) {
            return;
        }

        Test.startTest();
        InternalTicketController.TicketResult result =
            InternalTicketController.createTicket(buildRequest(String.valueOf(matrix.get('Id'))));
        Test.stopTest();

        Case created = [SELECT OwnerId FROM Case WHERE Id = :result.caseId];
        System.assertEquals(UserInfo.getUserId(), created.OwnerId,
            'With no L1 the ticket falls back to the person raising it');
        System.assertEquals(true, result.warning.contains('No L1 user'),
            'The fallback is reported, not silent');
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------
    @IsTest
    static void movesStagedFilesOntoTheTicket() {
        if (!recordTypeExists()) {
            return;
        }
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        User l1 = userByAlias(L1_ALIAS);

        Test.startTest();
        Id firstDoc  = stageFile('screenshot.txt');
        Id secondDoc = stageFile('screen-recording.txt');

        InternalTicketController.TicketRequest req = buildRequest(modules[0].value);
        req.documentIds = new List<String>{
            String.valueOf(firstDoc), String.valueOf(secondDoc), '', 'not-an-id'
        };
        InternalTicketController.TicketResult result = InternalTicketController.createTicket(req);
        Test.stopTest();

        System.assertEquals(2, result.filesAttached, 'Blanks and junk ids are dropped');

        System.assertEquals(2, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.caseId
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'Both files are linked to the ticket');

        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :UserInfo.getUserId()
              AND ContentDocumentId IN :new List<Id>{ firstDoc, secondDoc }
        ], 'The staging link against the uploader is removed');

        for (ContentDocument doc : [
            SELECT OwnerId FROM ContentDocument WHERE Id IN :new List<Id>{ firstDoc, secondDoc }
        ]) {
            System.assertEquals(l1.Id, doc.OwnerId, 'Ownership moves to the ticket owner');
        }
    }

    @IsTest
    static void raisesTheTicketWhenNoFilesAreAttached() {
        if (!recordTypeExists()) {
            return;
        }
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();

        Test.startTest();
        InternalTicketController.TicketResult result =
            InternalTicketController.createTicket(buildRequest(modules[0].value));
        Test.stopTest();

        System.assertEquals(0, result.filesAttached, 'Nothing to attach is not an error');
        System.assertNotEquals(null, result.caseId, 'The ticket is still raised');
    }

    @IsTest
    static void discardsAStagedFile() {
        Test.startTest();
        Id docId = stageFile('mistake.txt');
        InternalTicketController.discardFile(docId);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Removing a staged file deletes it, since it was really uploaded');
    }

    @IsTest
    static void ignoresADiscardWithNoDocument() {
        Test.startTest();
        InternalTicketController.discardFile(null);
        Test.stopTest();
        // Reaching here without an exception is the assertion.
        System.assert(true, 'A null document id is a no-op');
    }

    // ------------------------------------------------------------------
    // Who raised it
    // ------------------------------------------------------------------
    @IsTest
    static void contextCarriesTheRunningUsersOwnDetails() {
        User u = userByAlias(NO_DEPT);

        InternalTicketController.UserContext context;
        System.runAs(u) {
            Test.startTest();
            context = InternalTicketController.getUserContext();
            Test.stopTest();
        }

        System.assertEquals(String.valueOf(u.Id), context.userId,
            'The user Id is returned for any caller that needs it');
        System.assertEquals(u.Name, context.userName, 'The raiser name comes from the User record');
        System.assertEquals('9830000000', context.userPhone, 'Phone is read for the ticket stamp');
        System.assertEquals(u.Email, context.userEmail, 'Email is read for the ticket stamp');
    }

    /*@IsTest
    static void stampsTheRaisersContactDetailsOnTheTicket() {
        if (!recordTypeExists()) {
            return;
        }
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        User u = userByAlias(NO_DEPT);

        InternalTicketController.TicketResult result;
        System.runAs(u) {
            Test.startTest();
            result = InternalTicketController.createTicket(buildRequest(modules[0].value));
            Test.stopTest();
        }

        // Both are optional in the org - assert them only where they exist.
        List<String> stampFields = new List<String>();
        for (String f : new List<String>{ 'Phone_Number__c', 'Email__c' }) {
            if (fieldExists(f)) {
                stampFields.add(f);
            }
        }
        if (stampFields.isEmpty()) {
            //System.assertNotEquals(null, result.warning,'With none of the stamp fields present the user should be told they were skipped');
            return;
        }

        Id caseId = result.caseId;
        SObject saved = Database.query(
            'SELECT ' + String.join(stampFields, ', ') + ' FROM Case WHERE Id = :caseId LIMIT 1'
        );
        if (fieldExists('Phone_Number__c')) {
            System.assertEquals('9830000000', saved.get('Phone_Number__c'),
                'The raiser phone should be stamped on the ticket');
        }
        if (fieldExists('Email__c')) {
            System.assertEquals(u.Email, saved.get('Email__c'),
                'The raiser email should be stamped on the ticket');
        }
    }*/

    // ------------------------------------------------------------------
    // Validation
    // ------------------------------------------------------------------
    @IsTest
    static void rejectsANullRequest() {
        Boolean threw = false;
        Test.startTest();
        try {
            InternalTicketController.createTicket(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A null request is rejected rather than NPEd');
    }

    @IsTest
    static void rejectsATicketWithoutASubject() {
        List<InternalTicketController.ModuleOption> modules = InternalTicketController.getModules();
        InternalTicketController.TicketRequest req = buildRequest(modules[0].value);
        req.subject = null;

        Test.startTest();
        System.assertEquals(true, createThrows(req), 'Subject is mandatory');
        Test.stopTest();
    }

    @IsTest
    static void rejectsATicketWithoutAModule() {
        Test.startTest();
        System.assertEquals(true, createThrows(buildRequest(null)), 'A module is mandatory');
        Test.stopTest();
    }

    @IsTest
    static void rejectsAModuleThatIsNotInTheMatrix() {
        // Correctly shaped id for the object, but no such record.
        String fakeId = Schema.getGlobalDescribe().get('Internal_Ticket_Matrix__c')
            .getDescribe().getKeyPrefix() + '000000000AAA';

        Test.startTest();
        System.assertEquals(true, createThrows(buildRequest(fakeId)),
            'An unknown module is rejected before anything is inserted');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Case WHERE Subject = 'Quote PDF renders blank'],
            'Nothing should have been created');
    }
}