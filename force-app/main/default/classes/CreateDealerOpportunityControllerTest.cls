/**
 * @description   Tests for CreateDealerOpportunityController record-type, dealer
 *                lookup, and opportunity create paths.
 * @author        Anshita Chanda
 * @date          2026-08-18
 */
@IsTest
private class CreateDealerOpportunityControllerTest {
  @IsTest
  static void testGettersAndRequiredDealerValidation() {
    Account dealerAccount = insertDealerAccount('Create Dealer Acc');
    dealerAccount.Phone = null;
    dealerAccount.Email__c = null;
    BWM_TestDml.updateSys(dealerAccount);
    BWM_TestDml.insertSys(new Contact(
      LastName = 'Create Dealer Contact',
      AccountId = dealerAccount.Id,
      Phone = '9000017101',
      Email = 'create.dealer@example.com'
    ));

    Test.startTest();
    Id recordTypeId = CreateDealerOpportunityController.getOpportunityRecordTypeId();
    List<CreateDealerOpportunityController.DealerAccountOption> dealers =
      CreateDealerOpportunityController.getDealerAccounts();
    CreateDealerOpportunityController.DealerDetails details =
      CreateDealerOpportunityController.getDealerDetails(dealerAccount.Id);
    Boolean required = false;
    try {
      CreateDealerOpportunityController.getDealerDetails(null);
    } catch (Exception ex) {
      required = true;
    }
    Test.stopTest();

    System.assertNotEquals(null, recordTypeId);
    System.assertNotEquals(null, dealers);
    System.assertEquals(true, required);
    System.assert(String.isNotBlank(details.phone), details.phone);
    System.assert(
      details.email != null && details.email.contains('create.dealer'),
      details.email
    );
    System.assertNotEquals(null, details.contactId);
  }

  @IsTest
  static void testCreateDealerOpportunity_ValidationErrors() {
    Boolean missingDealer = false;
    Boolean missingCloseDate = false;
    Test.startTest();
    try {
      CreateDealerOpportunityController.createDealerOpportunity(
        null,
        Date.today().addDays(10),
        1000,
        null,
        'Opp'
      );
    } catch (Exception ex) {
      missingDealer = true;
    }
    try {
      CreateDealerOpportunityController.createDealerOpportunity(
        UserInfo.getUserId(),
        null,
        1000,
        null,
        'Opp'
      );
    } catch (Exception ex) {
      missingCloseDate = true;
    }
    Test.stopTest();
    System.assertEquals(true, missingDealer);
    System.assertEquals(true, missingCloseDate);
  }

  @IsTest
  static void testCreateDealerOpportunity_HappyPathWithContact() {
    Account dealerAccount = insertDealerAccount('Create Dealer Happy');
    BWM_TestDml.insertSys(new Contact(
      LastName = 'Happy Dealer Contact',
      AccountId = dealerAccount.Id,
      Phone = '9000017102',
      Email = 'happy.dealer@example.com'
    ));

    Test.startTest();
    Id namedId = CreateDealerOpportunityController.createDealerOpportunity(
      dealerAccount.Id,
      Date.today().addDays(21),
      2500,
      null,
      'Named Dealer Opp'
    );
    Id defaultNameId = CreateDealerOpportunityController.createDealerOpportunity(
      dealerAccount.Id,
      Date.today().addDays(30),
      null,
      null,
      '  '
    );
    Test.stopTest();

    System.assertNotEquals(null, namedId);
    System.assertNotEquals(null, defaultNameId);
    Opportunity namedOpportunity = [
      SELECT Name, DealerAccount__c, Phone__c, Email__c
      FROM Opportunity
      WHERE Id = :namedId
    ];
    System.assert(
      namedOpportunity.Name != null && namedOpportunity.Name.startsWith('Named Dealer Opp'),
      namedOpportunity.Name
    );
    System.assertEquals(dealerAccount.Id, namedOpportunity.DealerAccount__c);
    Integer roleCount = [
      SELECT COUNT()
      FROM OpportunityContactRole
      WHERE OpportunityId = :namedId AND IsPrimary = TRUE
    ];
    System.assertEquals(1, roleCount);
  }

  private static Account insertDealerAccount(String name) {
    Account accountRecord = new Account(
      Name = name,
      Phone = '9000017199',
      Email__c = 'create.dealer.acc@example.com'
    );
    Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    for (String developerName : new List<String>{ 'Dealer', 'Dealer_Account' }) {
      if (
        recordTypes.containsKey(developerName) &&
        recordTypes.get(developerName).isAvailable()
      ) {
        accountRecord.RecordTypeId = recordTypes.get(developerName).getRecordTypeId();
        break;
      }
    }
    BWM_TestDml.insertSys(accountRecord);
    return accountRecord;
  }
}