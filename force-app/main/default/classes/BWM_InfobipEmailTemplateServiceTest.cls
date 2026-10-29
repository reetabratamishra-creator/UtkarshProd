/**
 * @description   Test class for BWM_InfobipEmailTemplateService template fetch
 *                scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_InfobipEmailTemplateServiceTest {
  @IsTest
  static void fetchTemplatesReturnsParsedResults() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"results":[{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","imagePreviewUrl":"/email/1/templates/205000000067199/preview.png","createdAt":"2026-07-14T09:49:49.543+0000","updatedAt":"2026-07-14T09:49:49.546+0000"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}',
        200
      )
    );

    Test.startTest();
    List<BWM_InfobipEmailTemplateService.TemplateOption> templates =
      BWM_InfobipEmailTemplateService.fetchTemplates();
    Test.stopTest();

    System.assertEquals(1, templates.size());
    System.assertEquals('205000000067199', templates[0].value);
    System.assertEquals('NABL_HIGH_MAST_2026', templates[0].label);
    System.assertEquals(
      '/email/1/templates/205000000067199/preview.png',
      templates[0].imagePreviewUrl
    );
  }

  @IsTest
  static void fetchTemplatesThrowsOnHttpError() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock('{"description":"Something went wrong."}', 500)
    );

    Boolean threw = false;
    Test.startTest();
    try {
      BWM_InfobipEmailTemplateService.fetchTemplates();
    } catch (BWM_EmailException ex) {
      threw = true;
      System.assert(ex.getMessage().contains('server error'));
    }
    Test.stopTest();

    System.assertEquals(true, threw, 'Expected server error response to throw.');
  }

  @IsTest
  static void fetchTemplateSubjectReturnsSubjectFromInfobip() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"Welcome to Utkarsh Steel"}',
        200
      )
    );

    Test.startTest();
    String subject = BWM_InfobipEmailTemplateService.fetchTemplateSubject(
      '205000000067199'
    );
    Test.stopTest();

    System.assertEquals('Welcome to Utkarsh Steel', subject);
  }

  @IsTest
  static void fetchTemplateSubjectReturnsNullWhenSubjectMissing() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026"}',
        200
      )
    );

    Test.startTest();
    String subject = BWM_InfobipEmailTemplateService.fetchTemplateSubject(
      '205000000067199'
    );
    Test.stopTest();

    System.assertEquals(null, subject);
  }

  @IsTest
  static void fetchTemplateSubjectIgnoresNoSubjectPlaceholder() {
    Test.setMock(
      HttpCalloutMock.class,
      new BWM_EmailCalloutMock(
        '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"No Subject"}',
        200
      )
    );

    Test.startTest();
    String subject = BWM_InfobipEmailTemplateService.fetchTemplateSubject(
      '205000000067199'
    );
    Test.stopTest();

    System.assertEquals(null, subject);
  }

  @IsTest
  static void fetchCampaignEmailSubjectOptionsReturnsDistinctTemplateSubjects() {
    Test.setMock(HttpCalloutMock.class, new TemplateListAndDetailMock());

    Test.startTest();
    List<BWM_InfobipEmailTemplateService.SubjectOption> options =
      BWM_InfobipEmailTemplateService.fetchCampaignEmailSubjectOptions();
    Test.stopTest();

    System.assertEquals(1, options.size());
    System.assertEquals('Welcome to Utkarsh Steel', options[0].value);
  }

  private class TemplateListAndDetailMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      if (request.getEndpoint().contains('/email/1/templates/')) {
        response.setBody(
          '{"id":205000000067199,"name":"NABL_HIGH_MAST_2026","subject":"Welcome to Utkarsh Steel"}'
        );
      } else {
        response.setBody(
          '{"results":[{"id":205000000067199,"name":"NABL_HIGH_MAST_2026"}],"paging":{"page":0,"size":20,"totalPages":1,"totalResults":1}}'
        );
      }
      return response;
    }
  }

  @IsTest
  static void resolveTemplateIdsForSubjectAndBlankId() {
    System.assertEquals(
      new Set<String>(),
      BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(null)
    );
    System.assertEquals(null, BWM_InfobipEmailTemplateService.fetchTemplateMetadata(null));
    Test.setMock(HttpCalloutMock.class, new TemplateListAndDetailMock());
    Test.startTest();
    Set<String> ids = BWM_InfobipEmailTemplateService.resolveTemplateIdsForSubject(
      'Welcome to Utkarsh Steel'
    );
    BWM_InfobipEmailTemplateService.TemplateMetadata metadata =
      BWM_InfobipEmailTemplateService.fetchTemplateMetadata('205000000067199');
    Test.stopTest();
    System.assertNotEquals(null, ids);
    System.assertNotEquals(null, metadata);
  }

}