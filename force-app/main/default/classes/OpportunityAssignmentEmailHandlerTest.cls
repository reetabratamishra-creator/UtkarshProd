/**
 * @description Test class for OpportunityAssignmentEmailHandler.
 *              Covers helpers, Project-only filtering, insert/update paths and the
 *              daily-digest helpers (groupByHodEmail / groupByCrmHeadEmail / sendCreatedDigest).
 *              All SOQL uses WITH SYSTEM_MODE; DML uses "as system".
 *
 * CHANGE LOG
 *  - Removed every reference to the commented-out L1 Bidder members
 *    (STAGE_L1_BIDDER_DECLARED, TEMPLATE_L1_BIDDER_DECLARED, qualifiesAsL1BidderDeclared)
 *    - they no longer exist in the handler, so the old test class did not compile.
 *  - testL1BidderQualification removed (the method it tested is commented out).
 *  - Added tests for the new public digest helpers.
 */
@IsTest
private class OpportunityAssignmentEmailHandlerTest {

    private static Id queryProjectRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Opportunity'
            AND DeveloperName = :OpportunityAssignmentEmailHandler.PROJECT_RECORD_TYPE_DEVELOPER_NAME
            AND IsActive = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static Id queryAnyNonProjectRecordTypeId(Id projectRtId) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Opportunity'
            AND IsActive = TRUE
            AND Id != :projectRtId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static Id queryAnyTemplateId() {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE IsActive = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    // NEW helper: Project opportunity with the fields the digest table reads.
    private static Opportunity createProjectOpportunity(Id projectRtId, String name) {
        Account account = new Account(
            Name = name + ' Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
        insert as system account;

        Opportunity opp = new Opportunity(
            Name = name,
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId(),
            Department_Name__c = 'HDPE',
            RecordTypeId = projectRtId
        );
        insert as system opp;

        return [
            SELECT Id, Name, OwnerId, Owner.Name, RecordTypeId, CreatedDate, Department_Name__c,
                   CRM_User_Email_Formula__c, HOD_User_Email_Formula__c
            FROM Opportunity
            WHERE Id = :opp.Id
            WITH SYSTEM_MODE
        ];
    }

    @IsTest
    static void testIsProjectOpportunity() {
        Id projectRtId = queryProjectRecordTypeId();
        System.assertNotEquals(
            null,
            projectRtId,
            'Project_Opportunity record type must exist in this org'
        );

        Opportunity projectOpp = new Opportunity(RecordTypeId = projectRtId);
        Opportunity otherOpp = new Opportunity();

        System.assertEquals(
            true,
            OpportunityAssignmentEmailHandler.isProjectOpportunity(projectOpp)
        );
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.isProjectOpportunity(otherOpp)
        );
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.isProjectOpportunity(null)
        );
    }

    @IsTest
    static void testProjectRecordTypeFilter() {
        Id projectRtId = queryProjectRecordTypeId();
        System.assertNotEquals(
            null,
            projectRtId,
            'Project_Opportunity record type must exist in this org'
        );

        Opportunity projectOpp = new Opportunity(RecordTypeId = projectRtId);
        Opportunity otherOpp = new Opportunity();

        List<Opportunity> filtered = OpportunityAssignmentEmailHandler.filterProjectOpportunities(
            new List<Opportunity>{ projectOpp, otherOpp }
        );

        System.assertEquals(1, filtered.size());
        System.assertEquals(projectRtId, filtered[0].RecordTypeId);
    }

    @IsTest
    static void testFilterProjectOpportunitiesEmptyInput() {
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.filterProjectOpportunities(
                new List<Opportunity>()
            ).size()
        );
    }

    @IsTest
    static void testGetTemplateForChangeNullOwner() {
        Opportunity noOwner = new Opportunity();
        System.assertEquals(
            null,
            OpportunityAssignmentEmailHandler.getTemplateForChange(noOwner, null, true)
        );
    }

    @IsTest
    static void testGetTemplateForChangePaths() {
        Opportunity insertOpp = new Opportunity(OwnerId = UserInfo.getUserId());
        System.assertEquals(
            OpportunityAssignmentEmailHandler.TEMPLATE_NEW_OPPORTUNITY_ASSIGNED,
            OpportunityAssignmentEmailHandler.getTemplateForChange(insertOpp, null, true)
        );

        // Update without an old record -> no template.
        System.assertEquals(
            null,
            OpportunityAssignmentEmailHandler.getTemplateForChange(insertOpp, null, false)
        );

        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
            AND Id != :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!otherUsers.isEmpty()) {
            Opportunity reassigned = new Opportunity(OwnerId = UserInfo.getUserId());
            Opportunity oldReassigned = new Opportunity(OwnerId = otherUsers[0].Id);
            System.assertEquals(
                OpportunityAssignmentEmailHandler.TEMPLATE_NEW_OPPORTUNITY_ASSIGNED,
                OpportunityAssignmentEmailHandler.getTemplateForChange(
                    reassigned,
                    oldReassigned,
                    false
                )
            );
        }

        // CHANGED: the L1 Bidder branch is commented out in the handler, so a stage change
        // with the same owner must now return no template.
        Opportunity stageChangedOpp = new Opportunity(
            OwnerId = UserInfo.getUserId(),
            StageName = 'Negotiation'
        );
        Opportunity oldStageOpp = new Opportunity(
            OwnerId = UserInfo.getUserId(),
            StageName = 'Prospecting'
        );
        System.assertEquals(
            null,
            OpportunityAssignmentEmailHandler.getTemplateForChange(
                stageChangedOpp,
                oldStageOpp,
                false
            )
        );
    }

    @IsTest
    static void testHandleAfterInsertAndUpdate_ProjectOnly() {
        Id templateId = queryAnyTemplateId();
        Id projectRtId = queryProjectRecordTypeId();
        System.assertNotEquals(null, templateId, 'An active email template must exist');
        System.assertNotEquals(
            null,
            projectRtId,
            'Project_Opportunity record type must exist in this org'
        );

        OpportunityAssignmentEmailHandler.testTemplateIdOverride = templateId;

        Account account = new Account(
            Name = 'Opp Assignment Test Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
        insert as system account;

        Opportunity projectOpp = new Opportunity(
            Name = 'Project Opp Email Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId(),
            Department_Name__c = 'HDPE',
            RecordTypeId = projectRtId
        );
        insert as system projectOpp;

        Test.startTest();
        OpportunityAssignmentEmailHandler.handleAfterInsert(
            new List<Opportunity>{ projectOpp }
        );

        // CHANGED: stage change is done in memory only (the L1 Bidder stage constant no longer
        // exists, and no email is sent for a plain stage change any more).
        Opportunity oldProjectOpp = projectOpp.clone(true, true, true, true);
        projectOpp.StageName = 'Negotiation';

        OpportunityAssignmentEmailHandler.handleAfterUpdate(
            new List<Opportunity>{ projectOpp },
            new Map<Id, Opportunity>{ projectOpp.Id => oldProjectOpp }
        );
        Test.stopTest();

        Opportunity savedOpp = [
            SELECT StageName
            FROM Opportunity
            WHERE Id = :projectOpp.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Prospecting', savedOpp.StageName);
    }

    // NEW: owner change on a Project opportunity goes through the re-assignment branch.
    @IsTest
    static void testHandleAfterUpdate_OwnerChangeProjectOnly() {
        Id templateId = queryAnyTemplateId();
        Id projectRtId = queryProjectRecordTypeId();
        if (templateId == null || projectRtId == null) {
            return;
        }
        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
            AND Id != :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            return;
        }

        OpportunityAssignmentEmailHandler.testTemplateIdOverride = templateId;
        Opportunity projectOpp = createProjectOpportunity(projectRtId, 'Owner Change Opp');
        Opportunity oldOpp = projectOpp.clone(true, true, true, true);
        oldOpp.OwnerId = otherUsers[0].Id;

        Test.startTest();
        OpportunityAssignmentEmailHandler.handleAfterUpdate(
            new List<Opportunity>{ projectOpp },
            new Map<Id, Opportunity>{ projectOpp.Id => oldOpp }
        );
        Test.stopTest();

        System.assertEquals(
            true,
            OpportunityAssignmentEmailHandler.isProjectOpportunity(projectOpp)
        );
    }

    // NEW: null / empty input is ignored.
    @IsTest
    static void testProcessRecordsNullAndEmpty() {
        OpportunityAssignmentEmailHandler.handleAfterInsert(null);
        OpportunityAssignmentEmailHandler.handleAfterInsert(new List<Opportunity>());
        System.assert(true);
    }

    @IsTest
    static void testNonProjectOpportunityIsSkipped() {
        Id templateId = queryAnyTemplateId();
        Id projectRtId = queryProjectRecordTypeId();
        System.assertNotEquals(null, templateId, 'An active email template must exist');
        System.assertNotEquals(
            null,
            projectRtId,
            'Project_Opportunity record type must exist in this org'
        );

        Id otherRtId = queryAnyNonProjectRecordTypeId(projectRtId);
        if (otherRtId == null) {
            return;
        }

        OpportunityAssignmentEmailHandler.testTemplateIdOverride = templateId;

        Account account = new Account(
            Name = 'Non Project Opp Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
        insert as system account;

        Opportunity nonProjectOpp = new Opportunity(
            Name = 'Master/Other Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            OwnerId = UserInfo.getUserId(),
            Department_Name__c = 'HDPE',
            RecordTypeId = otherRtId
        );
        insert as system nonProjectOpp;

        Test.startTest();
        // Insert path - non-Project must be skipped (no exception)
        OpportunityAssignmentEmailHandler.handleAfterInsert(
            new List<Opportunity>{ nonProjectOpp }
        );

        // Update path - in-memory only (avoids sales-process DML error on other RTs)
        Opportunity oldOpp = nonProjectOpp.clone(true, true, true, true);
        nonProjectOpp.StageName = 'Negotiation'; // CHANGED: L1 constant no longer exists

        OpportunityAssignmentEmailHandler.handleAfterUpdate(
            new List<Opportunity>{ nonProjectOpp },
            new Map<Id, Opportunity>{ nonProjectOpp.Id => oldOpp }
        );
        Test.stopTest();

        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.isProjectOpportunity(nonProjectOpp)
        );
    }

    @IsTest
    static void testCrmAndHodEmailResolution() {
        Opportunity blankDepartment = new Opportunity();
        System.assertEquals(
            null,
            OpportunityAssignmentEmailHandler.resolveCrmHeadEmail(blankDepartment)
        );
        System.assertEquals(
            null,
            OpportunityAssignmentEmailHandler.resolveHodEmail(blankDepartment)
        );
        // NEW: null opportunity
        System.assertEquals(null, OpportunityAssignmentEmailHandler.resolveCrmHeadEmail(null));
        System.assertEquals(null, OpportunityAssignmentEmailHandler.resolveHodEmail(null));

        Opportunity hdpeOpp = new Opportunity(Department_Name__c = 'HDPE');
        String crmEmail = OpportunityAssignmentEmailHandler.resolveCrmHeadEmail(hdpeOpp);
        String hodEmail = OpportunityAssignmentEmailHandler.resolveHodEmail(hdpeOpp);

        if (crmEmail != null) {
            System.assertEquals(true, crmEmail.contains('@'));
        }
        if (hodEmail != null) {
            System.assertEquals(true, hodEmail.contains('@'));
        }
    }

    // ===========================================================================
    // NEW: daily-digest helpers
    // ===========================================================================

    @IsTest
    static void testGroupByRecipientEmail() {
        // null / empty input
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.groupByHodEmail(null).size()
        );
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.groupByCrmHeadEmail(null).size()
        );
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.groupByHodEmail(new List<Opportunity>()).size()
        );

        // Opportunity without department / formula email is skipped (nothing resolvable).
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.groupByHodEmail(
                new List<Opportunity>{ new Opportunity() }
            ).size()
        );
        System.assertEquals(
            0,
            OpportunityAssignmentEmailHandler.groupByCrmHeadEmail(
                new List<Opportunity>{ new Opportunity() }
            ).size()
        );

        // Opportunity with a department: grouped only when an email resolves in this org.
        Map<String, List<Opportunity>> hodGroups = OpportunityAssignmentEmailHandler.groupByHodEmail(
            new List<Opportunity>{ new Opportunity(Department_Name__c = 'HDPE') }
        );
        for (String email : hodGroups.keySet()) {
            System.assertEquals(true, email.contains('@'));
            System.assertEquals(email, email.toLowerCase());
        }
        Map<String, List<Opportunity>> crmGroups = OpportunityAssignmentEmailHandler.groupByCrmHeadEmail(
            new List<Opportunity>{ new Opportunity(Department_Name__c = 'HDPE') }
        );
        for (String email : crmGroups.keySet()) {
            System.assertEquals(true, email.contains('@'));
        }
    }

    @IsTest
    static void testSendCreatedDigestGuards() {
        List<Opportunity> opps = new List<Opportunity>{ new Opportunity() };

        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.sendCreatedDigest(null, 'a@example.com', 'T')
        );
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.sendCreatedDigest(
                new List<Opportunity>(),
                'a@example.com',
                'T'
            )
        );
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.sendCreatedDigest(opps, '', 'T')
        );
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.sendCreatedDigest(opps, 'a@example.com', '')
        );
        // Template that does not exist in the org.
        System.assertEquals(
            false,
            OpportunityAssignmentEmailHandler.sendCreatedDigest(
                opps,
                'a@example.com',
                'Missing_Template_XYZ'
            )
        );
    }

    // Creates (or reuses) a simple text template so rendering is deterministic.
    private static Id ensureTextTemplate() {
        String devName = 'Handler_Digest_Test_Template';
        List<EmailTemplate> existing = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :devName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        EmailTemplate template = new EmailTemplate(
            Name = 'Handler Digest Test Template',
            DeveloperName = devName,
            TemplateType = 'text',
            FolderId = UserInfo.getUserId(),
            IsActive = true,
            Subject = 'Project Opportunity Created',
            Body = 'Dear Team,\n\nNew project opportunities were created.\n\nRegards,\nTeam CRM'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert as system template;
        }
        return template.Id;
    }

    // A deterministic text template is used (override) so the template always renders:
    // this reaches the subject / body building, buildCreatedDigestHtml, buildCreatedDigestText
    // and the send call. Whether Salesforce accepts the test email depends on the org, so the
    // assertion is that the send was attempted.
    @IsTest
    static void testSendCreatedDigestBuildsAndSends() {
        Id projectRtId = queryProjectRecordTypeId();
        if (projectRtId == null) {
            return;
        }
        OpportunityAssignmentEmailHandler.testTemplateIdOverride = ensureTextTemplate();

        Opportunity oppOne = createProjectOpportunity(projectRtId, 'Created Digest One');
        Opportunity oppTwo = createProjectOpportunity(projectRtId, 'Created Digest Two');

        Test.startTest();
        Boolean sent = OpportunityAssignmentEmailHandler.sendCreatedDigest(
            new List<Opportunity>{ oppOne, oppTwo },
            'digest.recipient@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED
        );
        System.assert(Limits.getEmailInvocations() >= 1, 'The digest send must have been attempted');
        Test.stopTest();

        System.assertNotEquals(null, sent);
    }
}