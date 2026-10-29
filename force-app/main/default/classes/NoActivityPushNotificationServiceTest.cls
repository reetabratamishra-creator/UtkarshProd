/**
 * @description   Test class for no-activity custom push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class NoActivityPushNotificationServiceTest {
  @IsTest
  static void testLeadNoActivityPushNotification() {
    NoActivityPushNotificationService.clearTestState();

    Lead leadRecord = createProspectingLead('No Activity Lead');
    NoActivityPushNotificationService.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = [
      SELECT
        Id,
        Name,
        OwnerId,
        Last_Prospecting_Activity__c,
        Prospecting_No_Activity_Push_24_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    Test.startTest();
    NoActivityPushNotificationService.processLeads(new List<Lead>{ leadRecord });
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      leadRecord.OwnerId,
      CrmPushNotificationService.testSentRequests[0].recipientId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(leadRecord.Name)
    );

    leadRecord = [
      SELECT Prospecting_No_Activity_Push_24_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(true, leadRecord.Prospecting_No_Activity_Push_24_Sent__c);
  }

  @IsTest
  static void testActiveOpportunityNoActivityPushNotification() {
    NoActivityPushNotificationService.clearTestState();
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();

    Opportunity opportunityRecord = createOpportunity(
      'Active No Activity Opp',
      'Nurture',
      null
    );
    EscalationMatrixOpportunityHelper.setTestLastActivityDate(
      opportunityRecord.Id,
      Date.today().addDays(-4)
    );

    opportunityRecord = [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Active_No_Activity_Push_72_Sent__c,
        Project_Tender_No_Activity_Push_90d_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    NoActivityPushNotificationService.processOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains('72 hours')
    );

    opportunityRecord = [
      SELECT Active_No_Activity_Push_72_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(true, opportunityRecord.Active_No_Activity_Push_72_Sent__c);
  }

  @IsTest
  static void testProjectOpportunityNoActivityPushNotification() {
    NoActivityPushNotificationService.clearTestState();
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();

    Id projectRecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Project_Opportunity'
      LIMIT 1
    ]
    .Id;

    Opportunity opportunityRecord = createOpportunity(
      'Project No Activity Opp',
      'Prospect',
      projectRecordTypeId
    );
    EscalationMatrixOpportunityHelper.setTestLastActivityDate(
      opportunityRecord.Id,
      Date.today().addDays(-91)
    );

    opportunityRecord = [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Active_No_Activity_Push_72_Sent__c,
        Project_Tender_No_Activity_Push_90d_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    NoActivityPushNotificationService.processOpportunities(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains('3 months')
    );

    opportunityRecord = [
      SELECT Project_Tender_No_Activity_Push_90d_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
    System.assertEquals(
      true,
      opportunityRecord.Project_Tender_No_Activity_Push_90d_Sent__c
    );
  }

  @IsTest
  static void testOpportunityBatchExecute() {
    NoActivityPushNotificationService.clearTestState();
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();

    Opportunity opportunityRecord = createOpportunity(
      'Batch Execute Opp',
      'Nurture',
      null
    );
    EscalationMatrixOpportunityHelper.setTestLastActivityDate(
      opportunityRecord.Id,
      Date.today().addDays(-4)
    );

    opportunityRecord = [
      SELECT
        Id,
        Name,
        OwnerId,
        StageName,
        CreatedDate,
        Budget_Confirmed__c,
        RecordType.DeveloperName,
        Active_No_Activity_Push_72_Sent__c,
        Project_Tender_No_Activity_Push_90d_Sent__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    new NoActivityOpportunityPushBatch()
      .execute(null, new List<Opportunity>{ opportunityRecord });
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
  }

  @IsTest
  static void testLeadBatchExecute() {
    NoActivityPushNotificationService.clearTestState();

    Lead leadRecord = createProspectingLead('Batch Execute Lead');
    NoActivityPushNotificationService.setTestLastProspectingActivity(
      leadRecord.Id,
      System.now().addHours(-25)
    );

    leadRecord = [
      SELECT
        Id,
        Name,
        OwnerId,
        Last_Prospecting_Activity__c,
        Prospecting_No_Activity_Push_24_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];

    Test.startTest();
    new NoActivityLeadPushBatch().execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
  }

  @IsTest
  static void testBatchAndScheduler() {
    Test.startTest();
    System.assertNotEquals(null, new NoActivityLeadPushBatch().start(null));
    System.assertNotEquals(null, new NoActivityOpportunityPushBatch().start(null));
    new NoActivityPushNotificationScheduler().execute(null);
    Test.stopTest();
  }

  @IsTest
  static void testHelperMethods() {
    Opportunity activeOpportunity = new Opportunity(
      StageName = 'Nurture',
      Budget_Confirmed__c = false,
      RecordType = new RecordType(DeveloperName = 'Master_Opportunity')
    );
    Opportunity tenderOpportunity = new Opportunity(
      RecordType = new RecordType(DeveloperName = 'Tender_Opportunity')
    );

    System.assertEquals(
      true,
      NoActivityPushNotificationService.isActiveOpportunity(activeOpportunity)
    );
    System.assertEquals(
      true,
      NoActivityPushNotificationService.isProjectOrTenderOpportunity(
        tenderOpportunity
      )
    );
  }

  private static Lead createProspectingLead(String lastName) {
    Lead leadRecord = new Lead(
      LastName = lastName,
      Company = 'No Activity Test Co',
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospecting',
      Department_Name__c = 'Enquiry',
      Email = lastName.replace(' ', '').toLowerCase() + '@example.com',
      Phone = '9876543210',
      Last_Prospecting_Activity__c = System.now().addHours(-25)
    );
    insert leadRecord;
    return [
      SELECT Id, Name, OwnerId
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
  }

  private static Opportunity createOpportunity(
    String name,
    String stageName,
    Id recordTypeId
  ) {
    Account accountRecord = new Account(Name = name + ' Account');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountRecord.Id,
      StageName = stageName,
      CloseDate = Date.today().addDays(30),
      Budget_Confirmed__c = false
    );

    if (recordTypeId != null) {
      opportunityRecord.RecordTypeId = recordTypeId;
    }

    insert opportunityRecord;
    return [
      SELECT Id, Name, OwnerId
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
  }
}