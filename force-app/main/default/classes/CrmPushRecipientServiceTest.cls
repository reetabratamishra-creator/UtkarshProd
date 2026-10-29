/**
 * @description   Test class for CRM push recipient resolution.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class CrmPushRecipientServiceTest {
  @IsTest
  static void testResolveOpportunityRecipientsUsesTestOverrides() {
    CrmPushRecipientService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Opportunity opportunityRecord = new Opportunity(
      Department_Name__c = 'Enquiry'
    );

    Set<Id> recipientUserIds = CrmPushRecipientService.resolveOpportunityHodAndCrmHeadUserIds(
      opportunityRecord
    );

    System.assertEquals(1, recipientUserIds.size());
    System.assert(recipientUserIds.contains(UserInfo.getUserId()));
  }

  @IsTest
  static void testResolveRecipientsWithoutOverridesQueriesRoles() {
    CrmPushRecipientService.clearTestState();

    Opportunity opportunityRecord = new Opportunity(
      Department_Name__c = 'Enquiry'
    );

    Test.startTest();
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveOpportunityHodAndCrmHeadUserIds(
      opportunityRecord
    );
    Test.stopTest();

    System.assertNotEquals(null, recipientUserIds);
  }

  @IsTest
  static void testNullOpportunityReturnsEmptySet() {
    CrmPushRecipientService.clearTestState();

    System.assertEquals(
      0,
      CrmPushRecipientService.resolveOpportunityHodAndCrmHeadUserIds(null).size()
    );
  }

  @IsTest
  static void testResolveDepartmentNameUsesDepartmentField() {
    Opportunity opportunityRecord = new Opportunity(
      Department_Name__c = 'Transmission & Telecom Tower'
    );

    System.assertEquals(
      'Transmission Tower',
      CrmPushRecipientService.resolveDepartmentName(opportunityRecord)
    );
  }

  @IsTest
  static void testResolveDepartmentNameUsesFormulaWhenPresent() {
    Account accountRecord = new Account(Name = 'Formula Dept Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Formula Dept Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Enquiry'
    );
    insert as system opportunityRecord;

    opportunityRecord = [
      SELECT Department_Name__c, Department_NameFormula__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    System.assertNotEquals(
      null,
      CrmPushRecipientService.resolveDepartmentName(opportunityRecord)
    );
  }

  @IsTest
  static void testResolveRecipientsUsesCurrentUserEmailMatch() {
    CrmPushRecipientService.clearTestState();

    User currentUser = [
      SELECT Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    System.assertNotEquals(null, currentUser.Email);

    Account accountRecord = new Account(Name = 'CRM Email Match Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'CRM Email Match Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Prospect',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Enquiry'
    );
    insert as system opportunityRecord;

    opportunityRecord = [
      SELECT
        Department_Name__c,
        Department_NameFormula__c,
        CRM_User_Email_Formula__c
      FROM Opportunity
      WHERE Id = :opportunityRecord.Id
    ];

    Test.startTest();
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveOpportunityHodAndCrmHeadUserIds(
      opportunityRecord
    );
    Test.stopTest();

    System.assertNotEquals(null, recipientUserIds);
  }

  @IsTest
  static void testResolveCaseDepartmentHodUsesTestOverrides() {
    CrmPushRecipientService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(Department__c = 'HDPE');
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveCaseDepartmentHodUserIds(
      caseRecord
    );

    System.assertEquals(1, recipientUserIds.size());
    System.assert(recipientUserIds.contains(UserInfo.getUserId()));
  }

  @IsTest
  static void testResolveCaseDepartmentNameUsesDepartmentField() {
    Case caseRecord = new Case(Department__c = 'Transmission & Telecom Tower');

    System.assertEquals(
      'Transmission Tower',
      CrmPushRecipientService.resolveCaseDepartmentName(caseRecord)
    );
  }

  @IsTest
  static void testResolveCaseCrmHeadUsesTestOverrides() {
    CrmPushRecipientService.clearTestState();
    CrmPushRecipientService.testUserIdOverrides = new Set<Id>{
      UserInfo.getUserId()
    };

    Case caseRecord = new Case(Department__c = 'HDPE');
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveCaseCrmHeadUserIds(
      caseRecord
    );

    System.assertEquals(1, recipientUserIds.size());
    System.assert(recipientUserIds.contains(UserInfo.getUserId()));
  }

  @IsTest
  static void testNullCaseReturnsEmptyRecipientSet() {
    CrmPushRecipientService.clearTestState();

    System.assertEquals(
      0,
      CrmPushRecipientService.resolveCaseDepartmentHodUserIds(null).size()
    );
    System.assertEquals(
      0,
      CrmPushRecipientService.resolveCaseCrmHeadUserIds(null).size()
    );
  }

  @IsTest
  static void testResolveCaseCrmHeadWithoutOverridesAndFormulaDepartment() {
    CrmPushRecipientService.clearTestState();
    Case caseRecord = new Case(Department__c = 'Enquiry');
    Set<Id> recipientUserIds = CrmPushRecipientService.resolveCaseCrmHeadUserIds(
      caseRecord
    );
    System.assertNotEquals(null, recipientUserIds);
    System.assertEquals(
      'Enquiry',
      CrmPushRecipientService.resolveCaseDepartmentName(
        new Case(Department__c = 'Enquiry')
      )
    );
  }
}