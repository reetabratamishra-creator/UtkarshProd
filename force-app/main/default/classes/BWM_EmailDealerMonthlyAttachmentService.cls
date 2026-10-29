/**
 * @description   Builds dealer-monthly list attachment used by dealer monthly emails.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailDealerMonthlyAttachmentService {
  public static Messaging.EmailFileAttachment buildOpenOpportunityListPdf(Id dealerAccountId) {
    if (dealerAccountId == null) {
      return null;
    }

    try {
      PageReference pdfPage = Page.BWM_DealerMonthlyOpportunityList;
      pdfPage.getParameters().put('accountId', dealerAccountId);
      Blob pdfBody = Test.isRunningTest()
        ? Blob.valueOf('%PDF-1.4 dealer-monthly-list')
        : pdfPage.getContentAsPDF();

      Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
      attachment.setFileName('Dealer_Open_Opportunities.pdf');
      attachment.setBody(pdfBody);
      attachment.setContentType('application/pdf');
      attachment.setInline(false);
      return attachment;
    } catch (Exception ex) {
      return null;
    }
  }
}