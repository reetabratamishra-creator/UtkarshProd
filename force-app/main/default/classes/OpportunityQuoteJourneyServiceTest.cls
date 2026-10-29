/**
 * @description   Test class for OpportunityQuoteJourneyService — validation scenarios
 *                for Send Quote to Customer.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class OpportunityQuoteJourneyServiceTest {
  private static final String SUCCESS_BODY =
    '{"code":"200","message":"WhatsApp message accepted."}';

  @TestSetup
  static void setupCommonData() {
    Account accountRecord = new Account(Name = 'Quote Journey Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    insert as system accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Quote Journey Contact ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      Phone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      MobilePhone = (String.valueOf(Math.abs(Crypto.getRandomInteger())) + '9123456789').right(10),
      Email = 'quote.journey+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com'
    );
    insert as system contactRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Quote Journey Opp ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      AccountId = accountRecord.Id,
      StageName = 'Nurture',
      CloseDate = Date.today().addDays(30),
      Department_Name__c = 'Crash Barrier',
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    insert as system opportunityRecord;

    insert as system new OpportunityContactRole(
      OpportunityId = opportunityRecord.Id,
      ContactId = contactRecord.Id,
      IsPrimary = true,
      Role = 'Decision Maker'
    );
  }

  @IsTest
  static void testSendQuoteToCustomer_NullId_ThrowsError() {
    Boolean threw = false;

    Test.startTest();
    try {
      OpportunityQuoteJourneyService.sendQuoteToCustomer(null);
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendQuoteToCustomer_NoSyncedQuote_ThrowsError() {
    Opportunity opportunityRecord = [
      SELECT Id, SyncedQuoteId
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    System.assertEquals(null, opportunityRecord.SyncedQuoteId);

    Boolean threw = false;
    Test.startTest();
    try {
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendQuoteToCustomer_OpportunityNotFound_ThrowsError() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    Boolean threw = false;

    Test.startTest();
    try {
      OpportunityQuoteJourneyService.sendQuoteToCustomer(accountRecord.Id);
    } catch (Exception ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendQuoteToCustomer_HappyPathWithMock() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    Quote quoteRecord = new Quote(
      Name = 'Quote Journey Quote ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      OpportunityId = opportunityRecord.Id
    );
    insert as system quoteRecord;

    ContentVersion finalQuoteVersion = new ContentVersion(
      Title = 'Quote Journey Final Quote',
      PathOnClient = 'Quote Journey Final Quote.pdf',
      VersionData = Blob.valueOf('final quote pdf'),
      FirstPublishLocationId = opportunityRecord.Id
    );
    insert as system finalQuoteVersion;
    finalQuoteVersion = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :finalQuoteVersion.Id
    ];

    update as system new Opportunity(
      Id = opportunityRecord.Id,
      SyncedQuoteId = quoteRecord.Id,
      Quotation_Date__c = Date.today(),
      Quote_Number__c = 'QJ-1001',
      Final_Quote_Document_ID__c = String.valueOf(
        finalQuoteVersion.ContentDocumentId
      )
    );

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    Test.stopTest();

    System.assertEquals(1, result.sentCount);
  }

  @IsTest
  static void testSendQuoteToCustomer_InvalidMobileFallsBackToPhone() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock(SUCCESS_BODY, SUCCESS_BODY)
    );

    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    Quote quoteRecord = new Quote(
      Name = 'Quote Bad Mobile ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      OpportunityId = opportunityRecord.Id
    );
    insert as system quoteRecord;

    ContentVersion finalQuoteVersion = new ContentVersion(
      Title = 'Quote Journey Bad Mobile Quote',
      PathOnClient = 'Quote Journey Bad Mobile Quote.pdf',
      VersionData = Blob.valueOf('final quote pdf'),
      FirstPublishLocationId = opportunityRecord.Id
    );
    insert as system finalQuoteVersion;
    finalQuoteVersion = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :finalQuoteVersion.Id
    ];

    Contact contactRecord = [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE 'Quote Journey Contact%'
      LIMIT 1
    ];
    contactRecord.MobilePhone = '123456';
    contactRecord.Phone = '7980828320';
    update as system contactRecord;

    update as system new Opportunity(
      Id = opportunityRecord.Id,
      SyncedQuoteId = quoteRecord.Id,
      Quotation_Date__c = Date.today(),
      Quote_Number__c = 'QJ-1003',
      Final_Quote_Document_ID__c = String.valueOf(
        finalQuoteVersion.ContentDocumentId
      )
    );

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    Test.stopTest();

    System.assertEquals(
      1,
      result.sentCount,
      'Should fall back to valid Phone when MobilePhone is invalid.'
    );
  }

  @IsTest
  static void testSendQuoteToCustomer_NoPrimaryPhone_ThrowsError() {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    Quote quoteRecord = new Quote(
      Name = 'Quote No Phone ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      OpportunityId = opportunityRecord.Id
    );
    insert as system quoteRecord;

    Contact contactRecord = [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE 'Quote Journey Contact%'
      LIMIT 1
    ];
    contactRecord.Phone = null;
    contactRecord.MobilePhone = null;
    update as system contactRecord;

    update as system new Opportunity(
      Id = opportunityRecord.Id,
      SyncedQuoteId = quoteRecord.Id,
      Quotation_Date__c = Date.today(),
      Quote_Number__c = 'QJ-1002'
    );

    Boolean threw = false;
    Test.startTest();
    try {
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw);
  }

  @IsTest
  static void testSendQuoteToCustomer_FailedApiResponse_SkipsSend() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_MessagingCalloutMock('INVALID_JSON_BODY', 'INVALID_JSON_BODY')
    );

    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    Quote quoteRecord = new Quote(
      Name = 'Quote Failed Api ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      OpportunityId = opportunityRecord.Id
    );
    insert as system quoteRecord;

    update as system new Opportunity(
      Id = opportunityRecord.Id,
      SyncedQuoteId = quoteRecord.Id,
      Quotation_Date__c = Date.today(),
      Quote_Number__c = 'QJ-1003'
    );

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
  }

  @IsTest
  static void testSendQuoteToCustomer_HandlesCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ThrowingPostCalloutMock());

    Opportunity opportunityRecord = prepareOpportunityWithSyncedQuote('QJ-1004');

    Test.startTest();
    DealerOpportunityWhatsAppService.SendWhatsAppResult result =
      OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityRecord.Id);
    Test.stopTest();

    System.assertEquals(0, result.sentCount);
    System.assertEquals(1, result.skippedCount);
    System.assertEquals(1, result.messages.size());
  }

  private static Opportunity prepareOpportunityWithSyncedQuote(String quoteNumber) {
    Opportunity opportunityRecord = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE 'Quote Journey Opp%'
      LIMIT 1
    ];
    Quote quoteRecord = new Quote(
      Name = 'Prepared Quote  ' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + quoteNumber,
      OpportunityId = opportunityRecord.Id
    );
    insert as system quoteRecord;

    update as system new Opportunity(
      Id = opportunityRecord.Id,
      SyncedQuoteId = quoteRecord.Id,
      Quotation_Date__c = Date.today(),
      Quote_Number__c = quoteNumber,
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER
    );
    return opportunityRecord;
  }

  private class ThrowingPostCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      throw new CalloutException('Simulated quote callout failure');
    }
  }
}