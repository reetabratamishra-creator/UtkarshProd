/**
 * @description   Tests dealer monthly opportunity-list PDF attachment builder.
 * @author        Anshita Chanda
 * @date          2026-08-18
 */
@IsTest
private class BWM_DealerMonthlyAttachTest {
  @IsTest
  static void buildOpenOpportunityListPdf_NullAndValidAccount() {
    Account dealerAccount = new Account(Name = 'Monthly PDF Dealer', Phone = '9000018101');
    insert dealerAccount;

    Test.startTest();
    Messaging.EmailFileAttachment missing =
      BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(null);
    Messaging.EmailFileAttachment attachment =
      BWM_EmailDealerMonthlyAttachmentService.buildOpenOpportunityListPdf(
        dealerAccount.Id
      );
    Test.stopTest();

    System.assertEquals(null, missing);
    System.assertNotEquals(null, attachment);
    System.assertEquals('Dealer_Open_Opportunities.pdf', attachment.getFileName());
    System.assertNotEquals(null, attachment.getBody());
  }

  @IsTest
  static void dealerMonthlyListCtrl_WithAndWithoutAccount() {
    Account dealerAccount = new Account(Name = 'Monthly List Dealer', Phone = '9000018102');
    insert dealerAccount;
    Opportunity opportunityRecord = new Opportunity(
      Name = 'Monthly List Opp',
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(20),
      AccountId = dealerAccount.Id,
      Phone__c = '9000018103',
      Email__c = 'monthly.list@example.com',
      Amount = 1500
    );
    try {
      opportunityRecord.DealerAccount__c = dealerAccount.Id;
      insert opportunityRecord;
    } catch (DmlException ex) {
      opportunityRecord.DealerAccount__c = null;
      insert opportunityRecord;
    }

    Test.setCurrentPage(Page.BWM_DealerMonthlyOpportunityList);
    ApexPages.currentPage().getParameters().put('accountId', String.valueOf(dealerAccount.Id));
    BWM_DealerMonthlyListCtrl withAccount = new BWM_DealerMonthlyListCtrl();
    ApexPages.currentPage().getParameters().remove('accountId');
    BWM_DealerMonthlyListCtrl withoutAccount = new BWM_DealerMonthlyListCtrl();

    System.assertNotEquals(null, withAccount.rows);
    System.assertEquals('Dealer', withoutAccount.dealerName);
  }
}