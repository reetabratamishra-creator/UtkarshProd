/**
 * @description Test class for TenderStatusEmailHandler HOD notification criteria.
 */
@IsTest
private class TenderStatusEmailHandlerTest {
  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE IsActive = TRUE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  @IsTest
  static void testHodQualificationMethods() {
    Tender__c oldTender = new Tender__c(
      Tender_User_Choice__c = null,
      Tender_Stage__c = 'Open'
    );
    Tender__c participationSubmitted = new Tender__c(
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION
    );
    Tender__c rejectionSubmitted = new Tender__c(
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION_REJECTION
    );
    Tender__c l1Declared = new Tender__c(
      Tender_Stage__c = TenderStatusEmailHandler.STAGE_L1_BIDDER_DECLARED
    );

    System.assertEquals(
      true,
      TenderStatusEmailHandler.qualifiesForHodParticipationAwaiting(
        participationSubmitted,
        oldTender
      )
    );
    System.assertEquals(
      true,
      TenderStatusEmailHandler.qualifiesForHodRejectionAwaiting(
        rejectionSubmitted,
        oldTender
      )
    );
    System.assertEquals(
      true,
      TenderStatusEmailHandler.qualifiesAsL1BidderDeclared(l1Declared, oldTender)
    );
  }

  @IsTest
  static void testGetTemplateForChangePaths() {
    Tender__c insertTender = new Tender__c(Contact__c = UserInfo.getUserId());
    System.assertEquals(
      TenderStatusEmailHandler.TEMPLATE_NEW_TENDER_ALERT,
      TenderStatusEmailHandler.getTemplateForChange(insertTender, null, true)
    );

    Tender__c oldTender = new Tender__c(
      Contact__c = UserInfo.getUserId(),
      Tender_User_Choice__c = null,
      HOD_Choice__c = null
    );
    Tender__c participationSubmitted = new Tender__c(
      Contact__c = UserInfo.getUserId(),
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION,
      HOD_Choice__c = null
    );
    System.assertEquals(
      TenderStatusEmailHandler.TEMPLATE_PARTICIPATION_SUBMITTED,
      TenderStatusEmailHandler.getTemplateForChange(
        participationSubmitted,
        oldTender,
        false
      )
    );

    Tender__c rejectionSubmitted = new Tender__c(
      Contact__c = UserInfo.getUserId(),
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION_REJECTION,
      HOD_Choice__c = null
    );
    System.assertEquals(
      TenderStatusEmailHandler.TEMPLATE_REJECTION_REQUEST_SUBMITTED,
      TenderStatusEmailHandler.getTemplateForChange(
        rejectionSubmitted,
        oldTender,
        false
      )
    );

    Tender__c hodApprovedParticipation = new Tender__c(
      Contact__c = UserInfo.getUserId(),
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION,
      HOD_Choice__c = TenderStatusEmailHandler.HOD_APPROVED
    );
    Tender__c oldHodPending = new Tender__c(
      Contact__c = UserInfo.getUserId(),
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION,
      HOD_Choice__c = null
    );
    System.assertEquals(
      TenderStatusEmailHandler.TEMPLATE_PARTICIPATION_ACCEPTED,
      TenderStatusEmailHandler.getTemplateForChange(
        hodApprovedParticipation,
        oldHodPending,
        false
      )
    );
  }

  @IsTest
  static void testHandleAfterInsertNewTenderAlertPath() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = new Contact(
      LastName = 'Tender User',
      Email = 'tender.user@test.example'
    );
    insert contact;

    Tender__c tender = new Tender__c(Contact__c = contact.Id);

    Test.startTest();
    insert tender;
    Test.stopTest();

    System.assertNotEquals(null, tender.Id);
  }

  @IsTest
  static void testDispatchHodEmailsOnUpdatePaths() {
    Id templateId = queryAnyTemplateId();
    System.assertNotEquals(null, templateId, 'An active email template must exist');
    TenderStatusEmailHandler.testTemplateIdOverride = templateId;

    Contact contact = new Contact(
      LastName = 'Dispatch Hod Tender User',
      Email = 'dispatch.hod@test.example'
    );
    insert contact;

    Tender__c tender = new Tender__c(
      Contact__c = contact.Id,
      Department_Name__c = 'HDPE',
      Tender_User_Choice__c = null,
      Tender_Stage__c = 'Open'
    );
    insert tender;

    Tender__c oldTender = new Tender__c(
      Id = tender.Id,
      Contact__c = contact.Id,
      Department_Name__c = 'HDPE',
      Tender_User_Choice__c = null,
      Tender_Stage__c = 'Open'
    );
    Tender__c participationSubmitted = new Tender__c(
      Id = tender.Id,
      Contact__c = contact.Id,
      Department_Name__c = 'HDPE',
      Tender_User_Choice__c = TenderStatusEmailHandler.CHOICE_DIRECT_PARTICIPATION,
      Tender_Stage__c = 'Open'
    );

    Test.startTest();
    TenderStatusEmailHandler.dispatchHodEmails(
      new List<Tender__c>{ participationSubmitted },
      new Map<Id, Tender__c>{ tender.Id => oldTender }
    );
    Test.stopTest();

    System.assertNotEquals(null, tender.Id);
  }

  @IsTest
  static void testCrmHeadTemplateMapping() {
    System.assertEquals(
      TenderStatusEmailHandler.TEMPLATE_CRM_HEAD_NEW_TENDER_ALERT,
      TenderStatusEmailHandler.getCrmHeadTemplateFor(
        TenderStatusEmailHandler.TEMPLATE_NEW_TENDER_ALERT
      )
    );
    System.assertEquals(null, TenderStatusEmailHandler.getCrmHeadTemplateFor('Unknown_Template'));
  }
}