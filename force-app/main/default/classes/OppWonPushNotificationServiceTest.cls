/**
 * @description   Test class for Opportunity Closed Won custom push notifications.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class OppWonPushNotificationServiceTest {
  @IsTest
  static void testClosedWonSendsPushToHodAndCrmHead() {
    OpportunityWonPushNotificationService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Opportunity opportunityRecord = createOpportunity('Closed Won Opp', 'Nurture');
    Opportunity oldRecord = opportunityRecord.clone(true, true, true, true);
    opportunityRecord.StageName = BWM_EmailConstants.STAGE_CLOSED_WON;

    Test.startTest();
    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
    System.assertEquals(
      opportunityRecord.Id,
      CrmPushNotificationService.testSentRequests[0].targetId
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(
        opportunityRecord.Name
      )
    );
    System.assert(
      CrmPushNotificationService.testSentRequests[0].body.contains(
        'marked WON'
      )
    );
  }

  @IsTest
  static void testAlreadyClosedWonDoesNotResend() {
    OpportunityWonPushNotificationService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Opportunity opportunityRecord = createOpportunity(
      'Already Won Opp',
      BWM_EmailConstants.STAGE_CLOSED_WON
    );
    Opportunity oldRecord = opportunityRecord.clone(true, true, true, true);

    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldRecord }
    );

    System.assertEquals(
      0,
      CrmPushNotificationService.testSentRequests == null
        ? 0
        : CrmPushNotificationService.testSentRequests.size()
    );
  }

  @IsTest
  static void testHandlerDelegatesToService() {
    OpportunityWonPushNotificationService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Opportunity opportunityRecord = createOpportunity('Handler Won Opp', 'Negotiation');
    Opportunity oldRecord = opportunityRecord.clone(true, true, true, true);
    opportunityRecord.StageName = BWM_EmailConstants.STAGE_CLOSED_WON;

    Test.startTest();
    OpportunityWonPushNotificationHandler.handleAfterUpdate(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldRecord }
    );
    Test.stopTest();

    System.assertEquals(1, CrmPushNotificationService.testSentRequests.size());
  }

  @IsTest
  static void testHelperMethods() {
    Opportunity opportunityRecord = new Opportunity(
      StageName = BWM_EmailConstants.STAGE_CLOSED_WON,
      Department_Name__c = 'Enquiry'
    );
    Opportunity oldRecord = new Opportunity(
      StageName = 'Negotiation'
    );

    System.assertEquals(
      true,
      OpportunityWonPushNotificationService.isNewlyClosedWon(
        opportunityRecord,
        oldRecord
      )
    );
    System.assertEquals(
      'Enquiry',
      CrmPushRecipientService.resolveDepartmentName(opportunityRecord)
    );

    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      null,
      null
    );
    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      new List<Opportunity>{ opportunityRecord },
      null
    );
    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );

    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{ UserInfo.getUserId() };
    OpportunityWonPushNotificationService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{ UserInfo.getUserId() };
    Opportunity liveRecord = createOpportunity('Live Won Cov', 'Negotiation');
    Opportunity previous = liveRecord.clone(true, true, true, true);
    liveRecord.StageName = BWM_EmailConstants.STAGE_CLOSED_WON;
    OpportunityWonPushNotificationService.sendForNewlyClosedWonOpportunities(
      new List<Opportunity>{ liveRecord },
      new Map<Id, Opportunity>{ liveRecord.Id => previous }
    );
    System.assert(
      CrmPushNotificationService.testSentRequests != null &&
        !CrmPushNotificationService.testSentRequests.isEmpty()
    );
  }

  private static Opportunity createOpportunity(String name, String stageName) {
    Account accountRecord = new Account(Name = name + ' Account');
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = name,
      AccountId = accountRecord.Id,
      StageName = stageName,
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Enquiry'
    );
    insert as system opportunityRecord;

    return [
      SELECT
        Id,
        Name,
        StageName,
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];
  }
}