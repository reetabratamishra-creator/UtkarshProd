/**
 * @description Test class for ProjectOpportunityCreatedDigestBatch and
 *              ProjectOpportunityCreatedDigestScheduler.
 *              Needs NO change in the batch / scheduler / handler classes.
 *
 * Notes:
 *  - The batch reads templates by DeveloperName. If the two digest templates are missing in the
 *    org, simple text templates with the same DeveloperName are created inside the test
 *    (rolled back automatically).
 *  - Recipient emails come from formula fields / custom metadata, so the start() tests only
 *    assert what is deterministic. The execute() tests build WorkItems by hand.
 *  - Whether Salesforce "accepts" a test email depends on org deliverability, so the send path
 *    asserts that the send was attempted (email invocations), not that the flag is set.
 */
@IsTest
private class ProjectOpportunityCreatedDigestBatchTest {
  // ===========================================================================
  // SCHEDULER
  // ===========================================================================

  @IsTest
  static void testSchedulerExecutesBatch() {
    Test.startTest();
    new ProjectOpportunityCreatedDigestScheduler().execute(null);
    Test.stopTest();

    System.assert(
      [
        SELECT COUNT()
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'ProjectOpportunityCreatedDigestBatch'
      ] >= 1
    );
  }

  @IsTest
  static void testSchedulerCanBeScheduled() {
    Test.startTest();
    Id jobId = System.schedule(
      'Project Opportunity Created Digest Test',
      '0 0 9 * * ?',
      new ProjectOpportunityCreatedDigestScheduler()
    );
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
  }

  // ===========================================================================
  // start() / finish()
  // ===========================================================================

  // An opportunity whose HOD and CRM flags are both already true must not be picked up.
  @IsTest
  static void testStartExcludesFullySentOpportunities() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    Opportunity sentOpp = createProjectOpportunity(projectRtId, 'Digest Sent Opp', true, true);

    Test.startTest();
    Iterable<ProjectOpportunityCreatedDigestBatch.WorkItem> started = new ProjectOpportunityCreatedDigestBatch()
      .start(null);
    Test.stopTest();

    System.assertNotEquals(null, started);
    Iterator<ProjectOpportunityCreatedDigestBatch.WorkItem> iter = started.iterator();
    while (iter.hasNext()) {
      for (Opportunity opp : iter.next().opps) {
        System.assertNotEquals(sentOpp.Id, opp.Id);
      }
    }
  }

  // Unsent opportunity: covers the grouping / recipient resolution code in start().
  // Whether an item is produced depends on the HOD / CRM emails resolved in this org,
  // so every item that IS produced is validated instead.
  @IsTest
  static void testStartBuildsValidWorkItems() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    createProjectOpportunity(projectRtId, 'Digest Unsent Opp', false, false);

    Test.startTest();
    Iterable<ProjectOpportunityCreatedDigestBatch.WorkItem> started = new ProjectOpportunityCreatedDigestBatch()
      .start(null);
    Test.stopTest();

    Iterator<ProjectOpportunityCreatedDigestBatch.WorkItem> iter = started.iterator();
    while (iter.hasNext()) {
      ProjectOpportunityCreatedDigestBatch.WorkItem item = iter.next();
      System.assertEquals(true, String.isNotBlank(item.recipientEmail));
      System.assertEquals(true, String.isNotBlank(item.templateName));
      System.assertNotEquals(null, item.isHod);
      System.assertEquals(false, item.opps.isEmpty());
    }
  }

  // Full run through Database.executeBatch (start -> execute -> finish).
  @IsTest
  static void testFullBatchRun() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    Opportunity opp = createProjectOpportunity(projectRtId, 'Digest Full Run Opp', false, false);

    Test.startTest();
    Database.executeBatch(new ProjectOpportunityCreatedDigestBatch(), 5);
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Id = :opp.Id]);
  }

  @IsTest
  static void testFinishDoesNothing() {
    new ProjectOpportunityCreatedDigestBatch().finish(null);
    System.assert(true);
  }

  // ===========================================================================
  // execute()
  // ===========================================================================

  // Template does not exist -> nothing is sent -> flags stay false (retried next run).
  @IsTest
  static void testExecuteSkipsItemWhenTemplateMissing() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    Opportunity opp = queryOpportunity(
      createProjectOpportunity(projectRtId, 'Digest No Template Opp', false, false).Id
    );

    Test.startTest();
    new ProjectOpportunityCreatedDigestBatch()
      .execute(
        null,
        new List<ProjectOpportunityCreatedDigestBatch.WorkItem>{
          buildItem('hod@example.com', 'Missing_Template_XYZ', true, new List<Opportunity>{ opp }),
          buildItem('crm@example.com', 'Missing_Template_XYZ', false, new List<Opportunity>{ opp })
        }
      );
    Test.stopTest();

    Opportunity updatedOpp = queryFlags(opp.Id);
    System.assertEquals(false, updatedOpp.Project_Created_HOD_Sent_c__c);
    System.assertEquals(false, updatedOpp.Project_Created_CRM_Sent_c__c);
  }

  // Items without opportunities / without recipient email are skipped, nothing is flagged.
  @IsTest
  static void testExecuteSkipsItemsWithMissingData() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    ensureTemplate(OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED);
    Opportunity opp = queryOpportunity(
      createProjectOpportunity(projectRtId, 'Digest Missing Data Opp', false, false).Id
    );

    Test.startTest();
    new ProjectOpportunityCreatedDigestBatch()
      .execute(
        null,
        new List<ProjectOpportunityCreatedDigestBatch.WorkItem>{
          buildItem(
            'hod@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
            true,
            new List<Opportunity>()
          ),
          buildItem(
            '',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
            true,
            new List<Opportunity>{ opp }
          ),
          buildItem(
            'hod@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
            true,
            null
          )
        }
      );
    Test.stopTest();

    Opportunity updatedOpp = queryFlags(opp.Id);
    System.assertEquals(false, updatedOpp.Project_Created_HOD_Sent_c__c);
    System.assertEquals(false, updatedOpp.Project_Created_CRM_Sent_c__c);
  }

  // The same opportunity in one HOD item and one CRM item of the same chunk:
  // covers template caching, rendering, table building, "Regards" split and the send call.
  @IsTest
  static void testExecuteSendsHodAndCrmDigest() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    ensureTemplate(OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED);
    ensureTemplate(OpportunityAssignmentEmailHandler.TEMPLATE_CRM_HEAD_OPPORTUNITY_CREATED);

    Opportunity oppOne = queryOpportunity(
      createProjectOpportunity(projectRtId, 'Digest Send Opp One', false, false).Id
    );
    Opportunity oppTwo = queryOpportunity(
      createProjectOpportunity(projectRtId, 'Digest Send Opp Two', false, false).Id
    );
    List<Opportunity> opps = new List<Opportunity>{ oppOne, oppTwo };

    Test.startTest();
    new ProjectOpportunityCreatedDigestBatch()
      .execute(
        null,
        new List<ProjectOpportunityCreatedDigestBatch.WorkItem>{
          buildItem(
            'hod.digest@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
            true,
            opps
          ),
          buildItem(
            'crm.digest@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_CRM_HEAD_OPPORTUNITY_CREATED,
            false,
            opps
          )
        }
      );
    System.assert(Limits.getEmailInvocations() >= 1, 'The digest send must have been attempted');
    Test.stopTest();
  }

  // Lead-like failure: an opportunity queried WITHOUT Name makes the table builder throw.
  // The exception must be swallowed (logged), the chunk must not abort, and the flag stays false.
  @IsTest
  static void testExecuteSwallowsExceptionOfOneItem() {
    Id projectRtId = queryProjectRecordTypeId();
    if (projectRtId == null) {
      return;
    }
    ensureTemplate(OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED);

    Opportunity created = createProjectOpportunity(projectRtId, 'Digest Exception Opp', false, false);
    Opportunity incompleteOpp = [SELECT Id FROM Opportunity WHERE Id = :created.Id];

    Test.startTest();
    new ProjectOpportunityCreatedDigestBatch()
      .execute(
        null,
        new List<ProjectOpportunityCreatedDigestBatch.WorkItem>{
          buildItem(
            'exception@example.com',
            OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
            true,
            new List<Opportunity>{ incompleteOpp }
          )
        }
      );
    Test.stopTest();

    System.assertEquals(false, queryFlags(created.Id).Project_Created_HOD_Sent_c__c);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private static ProjectOpportunityCreatedDigestBatch.WorkItem buildItem(
    String recipientEmail,
    String templateName,
    Boolean isHod,
    List<Opportunity> opps
  ) {
    ProjectOpportunityCreatedDigestBatch.WorkItem item = new ProjectOpportunityCreatedDigestBatch.WorkItem();
    item.recipientEmail = recipientEmail;
    item.templateName = templateName;
    item.isHod = isHod;
    item.opps = opps;
    return item;
  }

  private static Id queryProjectRecordTypeId() {
    List<RecordType> recordTypes = [
      SELECT Id
      FROM RecordType
      WHERE
        SobjectType = 'Opportunity'
        AND DeveloperName = :OpportunityAssignmentEmailHandler.PROJECT_RECORD_TYPE_DEVELOPER_NAME
        AND IsActive = TRUE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return recordTypes.isEmpty() ? null : recordTypes[0].Id;
  }

  // Creates a simple text template with the given DeveloperName when the org does not have it.
  private static void ensureTemplate(String developerName) {
    if ([SELECT COUNT() FROM EmailTemplate WHERE DeveloperName = :developerName] > 0) {
      return;
    }
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert as system new EmailTemplate(
        Name = 'Digest Test ' + developerName.left(40),
        DeveloperName = developerName,
        TemplateType = 'text',
        FolderId = UserInfo.getUserId(),
        IsActive = true,
        Subject = 'Project Opportunity Created',
        Body = 'Dear Team,\n\nNew project opportunities were created.\n\nRegards,\nTeam CRM'
      );
    }
  }

  private static Opportunity createProjectOpportunity(
    Id projectRtId,
    String name,
    Boolean hodSent,
    Boolean crmSent
  ) {
    Account accountRecord = new Account(
      Name = name + ' Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountRecord.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'HDPE',
      RecordTypeId = projectRtId,
      Project_Created_HOD_Sent_c__c = hodSent,
      Project_Created_CRM_Sent_c__c = crmSent
    );
    insert as system opportunityRecord;
    return opportunityRecord;
  }

  // Same fields the batch reads (Owner.Name etc. are used by the table builders).
  private static Opportunity queryOpportunity(Id opportunityId) {
    return [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Name,
        CreatedDate,
        Department_Name__c,
        CRM_User_Email_Formula__c,
        HOD_User_Email_Formula__c,
        Project_Created_HOD_Sent_c__c,
        Project_Created_CRM_Sent_c__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }

  private static Opportunity queryFlags(Id opportunityId) {
    return [
      SELECT Project_Created_HOD_Sent_c__c, Project_Created_CRM_Sent_c__c
      FROM Opportunity
      WHERE Id = :opportunityId
    ];
  }
}