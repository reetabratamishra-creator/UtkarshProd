/**
 * @description   Test class covering brochure attachment and system-mode email send
 *                behavior.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_BrochureEmailSystemModeTest {
  private class PdfCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBodyAsBlob(Blob.valueOf('%PDF-test-content%'));
      return response;
    }
  }

  @IsTest
  static void buildsDepartmentAttachmentFromConfiguredPublicUrl() {
    Test.setMock(HttpCalloutMock.class, new PdfCalloutMock());
    BWM_EmailBrochureAttachmentService.setBrochureMapForTest(
      new Map<String, BWM_Email_Department_Brochure__mdt>{
        'Steel Pipes' => new BWM_Email_Department_Brochure__mdt(
          Content_File_Title__c = 'Steel_Tubes_and_Pipes',
          File_Name__c = 'Steel_Tubes_and_Pipes.pdf',
          Public_Download_Url__c = 'https://example.test/Steel_Tubes_and_Pipes.pdf'
        )
      }
    );

    BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
      Brochure_Attachment_Mode__c = BWM_EmailConstants.BROCHURE_ATTACH_DEPARTMENT
    );

    List<Messaging.EmailFileAttachment> attachments = BWM_EmailBrochureAttachmentService.buildAttachments(
      null,
      mapping,
      new Lead(Department_Name__c = 'Steel Pipes')
    );

    System.assertEquals(1, attachments.size());
    System.assertEquals('Steel_Tubes_and_Pipes.pdf', attachments[0].getFileName());
    System.assert(attachments[0].getBody().size() > 0);
    BWM_EmailBrochureAttachmentService.clearCache();
  }
}