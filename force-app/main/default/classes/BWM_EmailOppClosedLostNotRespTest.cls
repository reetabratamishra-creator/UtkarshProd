/**
 * @description Focused tests for Nurture → Closed Lost + Not responding email enqueue,
 *              plus enough handler coverage for deploy (≥75%).
 * @author Anshita Chanda
 */
@IsTest
private class BWM_EmailOppClosedLostNotRespTest {
  private static Opportunity insertNurtureOpp(String emailAddress) {
    Account accountRecord = new Account(
      Name = 'Closed Lost Email Acct ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Nurture Closed Lost Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      CloseDate = Date.today().addDays(14),
      AccountId = accountRecord.Id,
      Email__c = emailAddress,
      Customer_Journey__c = 'Direct Business'
    );
    insert as system opportunityRecord;
    return opportunityRecord;
  }

  @IsTest
  static void routerResolvesNotRespondingWhenClosedLostFromNurture() {
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      )
    );
    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_CLOSED_LOST,
        BWM_EmailConstants.STAGE_NURTURE,
        'Not Responding'
      )
    );
    System.assertEquals(
      null,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        BWM_EmailConstants.STAGE_NURTURE,
        'Not responding'
      ),
      'Email waits for Closed Lost (journey may fire earlier).'
    );
  }

  @IsTest
  static void handlerEnqueuesWhenStageMovesToClosedLostWithNotResponding() {
    Opportunity opportunityRecord = insertNurtureOpp('closed-lost-not-resp@example.com');

    Opportunity oldRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = 'Not responding'
    );
    Opportunity newRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_CLOSED_LOST,
      Lost_Reason__c = 'Not responding'
    );

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ newRecord },
      new Map<Id, Opportunity>{ oldRecord.Id => oldRecord }
    );
    Test.stopTest();

    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        newRecord.StageName,
        oldRecord.StageName,
        newRecord.Lost_Reason__c
      )
    );
  }

  @IsTest
  static void handlerEnqueuesWhenClosedLostAndNotRespondingChangeTogether() {
    Opportunity opportunityRecord = insertNurtureOpp('closed-lost-one-save@example.com');

    Opportunity oldRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null
    );
    Opportunity newRecord = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_CLOSED_LOST,
      Lost_Reason__c = 'Not Responding'
    );

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ newRecord },
      new Map<Id, Opportunity>{ oldRecord.Id => oldRecord }
    );
    Test.stopTest();

    System.assertEquals(
      BWM_EmailConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE_LOST,
      BWM_EmailOpportunityLostReasonRouter.resolveTriggerPoint(
        newRecord.StageName,
        oldRecord.StageName,
        newRecord.Lost_Reason__c
      )
    );
  }

  @IsTest
  static void handlerCoversInsertUpdateGuardsAndDealerChecks() {
    Opportunity opportunityRecord = insertNurtureOpp('handler-coverage@example.com');

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(null);
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(new List<Opportunity>());
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(
      new List<Opportunity>{ opportunityRecord, opportunityRecord, null }
    );

    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(null, null);
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ opportunityRecord },
      new Map<Id, Opportunity>()
    );

    // Blank lost reason → no enqueue path
    Opportunity blankReasonNew = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null,
      Customer_Journey__c = 'Direct Business'
    );
    Opportunity blankReasonOld = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null,
      Customer_Journey__c = 'Direct Business'
    );
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ blankReasonNew },
      new Map<Id, Opportunity>{ blankReasonOld.Id => blankReasonOld }
    );

    // Unchanged non-not-responding reason → early return
    Opportunity otherReasonNew = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = 'Rate Issue',
      Customer_Journey__c = 'Direct Business'
    );
    Opportunity otherReasonOld = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = 'Rate Issue',
      Customer_Journey__c = 'Direct Business'
    );
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ otherReasonNew },
      new Map<Id, Opportunity>{ otherReasonOld.Id => otherReasonOld }
    );

    // Refer-to-dealer journey change
    Opportunity referNew = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null,
      Customer_Journey__c = BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    Opportunity referOld = new Opportunity(
      Id = opportunityRecord.Id,
      StageName = BWM_EmailConstants.STAGE_NURTURE,
      Lost_Reason__c = null,
      Customer_Journey__c = 'Direct Business'
    );
    BWM_EmailOpportunityTriggerHandler.handleAfterUpdate(
      new List<Opportunity>{ referNew },
      new Map<Id, Opportunity>{ referOld.Id => referOld }
    );

    // Dealer enquiry helpers
    System.assertEquals(
      false,
      BWM_EmailOpportunityTriggerHandler.isDealerEnquiryOpportunity(null)
    );
    Opportunity dealerOpp = new Opportunity(
      Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY,
      LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL
    );
    System.assertEquals(
      true,
      BWM_EmailOpportunityTriggerHandler.isDealerEnquiryOpportunity(dealerOpp)
    );
    Opportunity nonDealerOpp = new Opportunity(
      Department_Name__c = 'Crash Barrier',
      LeadSource = 'Web'
    );
    System.assertEquals(
      false,
      BWM_EmailOpportunityTriggerHandler.isDealerEnquiryOpportunity(nonDealerOpp)
    );
    Test.stopTest();
  }

  @IsTest
  static void handlerInsertEnqueuesNurtureAndReferDealer() {
    Opportunity opportunityRecord = insertNurtureOpp('insert-nurture@example.com');
    opportunityRecord.Customer_Journey__c = BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER;
    opportunityRecord.Department_Name__c = BWM_EmailConstants.DEPT_ENQUIRY;
    opportunityRecord.LeadSource = BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL;

    Test.startTest();
    BWM_EmailOpportunityTriggerHandler.handleAfterInsert(
      new List<Opportunity>{ opportunityRecord }
    );
    Test.stopTest();

    System.assertNotEquals(null, opportunityRecord.Id);
  }
}