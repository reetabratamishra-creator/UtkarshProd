/**
 * @description   Test class for CampaignEmailReportService email report scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class CampaignEmailReportServiceTest {
  private class EmailReportsMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(200);
      if (request.getEndpoint().contains('/email/4/logs')) {
        response.setBody('{"results":[]}');
        return response;
      }
      System.assert(
        request.getEndpoint().contains('/email/4/reports'),
        'Expected email reports endpoint'
      );
      response.setBody(
        '{"results":[{"bulkId":"bulk-1","messageId":"msg-1","to":"user@example.com","sender":"noreply@utkarshindialimited.in","sentAt":"2026-07-16T07:42:25.000+0000","doneAt":"2026-07-16T07:43:25.000+0000","messageCount":1,"campaignReferenceId":"camp-ref-1","attemptCount":1,"timeToFirstAttempt":3675,"price":{"pricePerMessage":0.11,"currency":"INR"},"status":{"name":"DELIVERED_TO_HANDSET","description":"Message delivered to handset"},"error":{"name":"NO_ERROR","description":"No Error"}}]}'
      );
      return response;
    }
  }

  private class EmailReportsErrorMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(401);
      response.setBody('{"description":"Unauthorized"}');
      return response;
    }
  }

  private class EmailLogsFallbackMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(200);
      if (request.getEndpoint().contains('/email/4/reports')) {
        response.setBody('{"results":[]}');
        return response;
      }
      response.setBody(
        '{"results":[{"bulkId":"bulk-2","messageId":"msg-2","destination":"user@example.com","sender":"noreply@utkarshindialimited.in","sentAt":"2026-07-16T07:42:25.000+0000","doneAt":"2026-07-16T07:43:25.000+0000","messageCount":1,"price":{"pricePerMessage":0.11,"currency":"INR"},"status":{"name":"DELIVERED_TO_HANDSET","description":"Message delivered to handset"},"error":{"name":"NO_ERROR","description":"No Error"}}]}'
      );
      return response;
    }
  }

  @IsTest
  static void fetchAndSaveCreatesEmailCampaignReport() {
    Test.setMock(HttpCalloutMock.class, new EmailReportsMock());

    Test.startTest();
    CampaignEmailReportService.FetchResult result = CampaignEmailReportService.fetchAndSave();
    Test.stopTest();

    System.assertEquals(1, result.rows.size());
    System.assertEquals('DELIVERED_TO_HANDSET', result.rows[0].status);
    System.assertEquals(0.11, result.rows[0].pricePerMessage);
    System.assertEquals('INR', result.rows[0].priceCurrency);
    System.assertEquals('NO_ERROR', result.rows[0].errorName);
    System.assertEquals(3675, result.rows[0].timeToFirstAttempt);
    System.assertEquals(1, result.summaryRows.size());
    System.assertEquals('user@example.com', result.summaryRows[0].recipient);
    System.assertEquals(1, result.summaryRows[0].delivered);
    System.assertEquals(0, result.summaryRows[0].failed);
    System.assertEquals(1, result.summaryRows[0].total);
    System.assertEquals(2, result.reportIds.size());

    Campaign_Report__c report = [
      SELECT
        Campaign__c,
        Report_Type__c,
        Product_Name__c,
        Email_Message_Id__c,
        Email_Recipient__c,
        Email_Status__c,
        Email_Price_Per_Message__c,
        Email_Price_Currency__c,
        Email_Error_Name__c,
        Email_Time_To_First_Attempt__c,
        Raw_Response__c
      FROM Campaign_Report__c
      WHERE Id = :result.reportIds[0]
    ];
    System.assertEquals(null, report.Campaign__c);
    System.assertEquals('Email', report.Report_Type__c);
    System.assertEquals('Email', report.Product_Name__c);
    System.assertEquals('msg-1', report.Email_Message_Id__c);
    System.assertEquals('user@example.com', report.Email_Recipient__c);
    System.assertEquals('DELIVERED_TO_HANDSET', report.Email_Status__c);
    System.assertEquals(0.11, report.Email_Price_Per_Message__c);
    System.assertEquals('INR', report.Email_Price_Currency__c);
    System.assertEquals('NO_ERROR', report.Email_Error_Name__c);
    System.assertEquals(3675, report.Email_Time_To_First_Attempt__c);
    System.assert(String.isNotBlank(report.Raw_Response__c));
  }

  @IsTest
  static void controllerDelegatesToService() {
    Test.setMock(HttpCalloutMock.class, new EmailReportsMock());

    Test.startTest();
    CampaignEmailReportService.FetchResult result =
      CampaignEmailReportController.fetchEmailCampaignReport(null);
    Test.stopTest();

    System.assertEquals(2, result.reportIds.size());
  }

  @IsTest
  static void filterRowsByCampaignSubjectMatchesEmailLogPayload() {
    insert new Email_Log__c(
      Trigger_Point__c = 'Email_Lead_Campaign_Manual',
      Campaign_Email_Subject__c = 'Welcome Subject',
      Status__c = 'Sent',
      To_Email__c = 'user@example.com',
      Response_Payload__c =
        '{"bulkId":"bulk-1","messages":[{"messageId":"msg-1","destination":"user@example.com"}]}'
    );

    CampaignEmailReportService.EmailReportRow matchedRow = new CampaignEmailReportService.EmailReportRow();
    matchedRow.messageId = 'msg-1';
    matchedRow.recipient = 'user@example.com';

    CampaignEmailReportService.EmailReportRow otherRow = new CampaignEmailReportService.EmailReportRow();
    otherRow.messageId = 'msg-2';
    otherRow.recipient = 'other@example.com';

    Test.startTest();
    List<CampaignEmailReportService.EmailReportRow> filteredRows = CampaignEmailReportService.filterRowsByCampaignSubject(
      new List<CampaignEmailReportService.EmailReportRow>{ matchedRow, otherRow },
      'Welcome Subject'
    );
    Test.stopTest();

    System.assertEquals(1, filteredRows.size());
    System.assertEquals('msg-1', filteredRows[0].messageId);
  }

  @IsTest
  static void filterRowsByCampaignSubjectDoesNotMatchSameRecipientOtherSubject() {
    insert new List<Email_Log__c>{
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'Subject A',
        Status__c = 'Sent',
        To_Email__c = 'user@example.com',
        Response_Payload__c =
          '{"bulkId":"bulk-a","messages":[{"messageId":"msg-a","destination":"user@example.com"}]}'
      ),
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'Subject B',
        Status__c = 'Sent',
        To_Email__c = 'user@example.com',
        Response_Payload__c =
          '{"bulkId":"bulk-b","messages":[{"messageId":"msg-b","destination":"user@example.com"}]}'
      )
    };

    CampaignEmailReportService.EmailReportRow subjectARow = new CampaignEmailReportService.EmailReportRow();
    subjectARow.messageId = 'msg-a';
    subjectARow.recipient = 'user@example.com';

    CampaignEmailReportService.EmailReportRow subjectBRow = new CampaignEmailReportService.EmailReportRow();
    subjectBRow.messageId = 'msg-b';
    subjectBRow.recipient = 'user@example.com';

    Test.startTest();
    List<CampaignEmailReportService.EmailReportRow> filteredRows = CampaignEmailReportService.filterRowsByCampaignSubject(
      new List<CampaignEmailReportService.EmailReportRow>{ subjectARow, subjectBRow },
      'Subject A'
    );
    Test.stopTest();

    System.assertEquals(1, filteredRows.size());
    System.assertEquals('msg-a', filteredRows[0].messageId);
  }

  @IsTest
  static void filterSafeTemplateIdsExcludesTemplatesWithConflictingSubjects() {
    insert new List<Email_Log__c>{
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'test',
        Template_Id__c = '205000000069951',
        Status__c = 'Sent',
        To_Email__c = 'one@example.com'
      ),
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'solar_promo_may_2026',
        Template_Id__c = '205000000069951',
        Status__c = 'Sent',
        To_Email__c = 'two@example.com'
      )
    };

    Set<String> safeTemplateIds = CampaignEmailReportService.filterSafeTemplateIds(
      'test',
      new Set<String>{ '205000000069951' },
      System.now().addHours(-1)
    );

    System.assertEquals(true, safeTemplateIds.isEmpty());
  }

  @IsTest
  static void filterRowsByCampaignSubjectIncludesLegacyTemplateSends() {
    insert new List<Email_Log__c>{
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'Welcome Subject',
        Template_Id__c = '205000000067199',
        Status__c = 'Sent',
        Response_Payload__c =
          '{"bulkId":"bulk-a","messages":[{"messageId":"msg-a","destination":"one@example.com"}]}'
      ),
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Template_Id__c = '205000000067199',
        Status__c = 'Sent',
        Response_Payload__c =
          '{"bulkId":"bulk-b","messages":[{"messageId":"msg-b","destination":"two@example.com"}]}'
      )
    };

    CampaignEmailReportService.EmailReportRow rowA = new CampaignEmailReportService.EmailReportRow();
    rowA.messageId = 'msg-a';
    rowA.recipient = 'one@example.com';

    CampaignEmailReportService.EmailReportRow rowB = new CampaignEmailReportService.EmailReportRow();
    rowB.messageId = 'msg-b';
    rowB.recipient = 'two@example.com';

    CampaignEmailReportService.EmailReportRow otherRow = new CampaignEmailReportService.EmailReportRow();
    otherRow.messageId = 'msg-other';
    otherRow.recipient = 'other@example.com';

    List<CampaignEmailReportService.EmailReportRow> filteredRows =
      CampaignEmailReportService.filterRowsByCampaignSubject(
        new List<CampaignEmailReportService.EmailReportRow>{ rowA, rowB, otherRow },
        'Welcome Subject'
      );

    Set<String> filteredIds = new Set<String>();
    for (CampaignEmailReportService.EmailReportRow row : filteredRows) {
      filteredIds.add(row.messageId);
    }
    System.assertEquals(true, filteredIds.contains('msg-a'));
    System.assertEquals(true, filteredIds.contains('msg-b'));
    System.assertEquals(false, filteredIds.contains('msg-other'));
  }

  @IsTest
  static void fetchAndSaveFiltersBySelectedSubject() {
    insert new Email_Log__c(
      Trigger_Point__c = 'Email_Lead_Campaign_Manual',
      Campaign_Email_Subject__c = 'Welcome Subject',
      Status__c = 'Sent',
      To_Email__c = 'user@example.com',
      Response_Payload__c =
        '{"bulkId":"bulk-1","messages":[{"messageId":"msg-1","destination":"user@example.com"}]}'
    );

    Test.setMock(HttpCalloutMock.class, new EmailReportsMock());

    Test.startTest();
    CampaignEmailReportService.FetchResult result = CampaignEmailReportService.fetchAndSave(
      'Welcome Subject'
    );
    Test.stopTest();

    System.assertEquals(1, result.rows.size());
    System.assertEquals(1, result.summaryRows.size());
    System.assertEquals('user@example.com', result.summaryRows[0].recipient);
  }

  @IsTest
  static void fetchAndSaveSurfacesApiError() {
    Test.setMock(HttpCalloutMock.class, new EmailReportsErrorMock());

    Boolean threw = false;
    Test.startTest();
    try {
      CampaignEmailReportService.fetchAndSave();
    } catch (Exception ex) {
      threw = true;
      System.assert(
        ex instanceof AuraHandledException,
        'Expected AuraHandledException'
      );
    }
    Test.stopTest();

    System.assert(threw, 'Expected AuraHandledException');
    System.assertEquals(0, [SELECT COUNT() FROM Campaign_Report__c]);
  }

  @IsTest
  static void fetchAndSaveUsesLogsWhenReportsEmpty() {
    Test.setMock(HttpCalloutMock.class, new EmailLogsFallbackMock());

    Test.startTest();
    CampaignEmailReportService.FetchResult result = CampaignEmailReportService.fetchAndSave();
    Test.stopTest();

    System.assertEquals(1, result.rows.size());
    System.assertEquals('user@example.com', result.rows[0].recipient);
    System.assertEquals(1, result.summaryRows.size());
    System.assertEquals('user@example.com', result.summaryRows[0].recipient);
    System.assertEquals(1, result.summaryRows[0].delivered);
    System.assertEquals(2, result.reportIds.size());

    Integration_Log__c logRecord = [
      SELECT Endpoint__c
      FROM Integration_Log__c
      WHERE Id = :result.integrationLogId
    ];
    System.assertEquals('/email/4/reports+/email/4/logs', logRecord.Endpoint__c);
  }

  @IsTest
  static void mergeResponseBodiesCombinesReportsAndLogs() {
    String reportsBody = '{"results":[{"messageId":"shared-id","to":"reports@example.com","sentAt":"2026-07-16T08:00:00.000+0000","attemptCount":2}]}';
    String logsBody = '{"results":[{"messageId":"shared-id","destination":"logs@example.com","sentAt":"2026-07-16T09:00:00.000+0000"},{"messageId":"logs-only","destination":"new@example.com","sentAt":"2026-07-16T10:00:00.000+0000"}]}';

    String mergedBody = CampaignEmailReportService.mergeResponseBodies(
      reportsBody,
      logsBody
    );
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mergedBody);
    List<Object> results = (List<Object>) payload.get('results');

    System.assertEquals(2, results.size());
    Map<String, Object> newest = (Map<String, Object>) results[0];
    System.assertEquals('logs-only', newest.get('messageId'));
  }

  private class ThrowingCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      throw new CalloutException('connection failed');
    }
  }

  @IsTest
  static void getCampaignEmailSubjectOptionsFromLogsReturnsDistinctSubjects() {
    insert new List<Email_Log__c>{
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'Welcome Subject',
        Status__c = 'Sent',
        To_Email__c = 'one@example.com'
      ),
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Campaign_Email_Subject__c = 'welcome subject',
        Status__c = 'Sent',
        To_Email__c = 'two@example.com'
      ),
      new Email_Log__c(
        Trigger_Point__c = 'Email_Lead_Campaign_Manual',
        Template_Name__c = 'Legacy Template',
        Status__c = 'Sent',
        To_Email__c = 'three@example.com'
      )
    };

    Test.startTest();
    List<CampaignEmailReportService.SubjectOption> options =
      CampaignEmailReportService.getCampaignEmailSubjectOptionsFromLogs();
    List<CampaignEmailReportService.SubjectOption> controllerOptions =
      CampaignEmailReportController.getCampaignEmailSubjectOptionsFromLogs();
    Test.stopTest();

    System.assert(options.size() >= 2, 'Expected subject options from Email Logs');
    System.assertEquals(options.size(), controllerOptions.size());
  }

  @IsTest
  static void getCampaignEmailSubjectOptionsFallsBackToLogs() {
    insert new Email_Log__c(
      Trigger_Point__c = 'Email_Lead_Campaign_Manual',
      Campaign_Email_Subject__c = 'Fallback Subject',
      Status__c = 'Sent',
      To_Email__c = 'user@example.com'
    );
    Test.setMock(HttpCalloutMock.class, new EmailReportsErrorMock());

    Test.startTest();
    List<CampaignEmailReportService.SubjectOption> options =
      CampaignEmailReportService.getCampaignEmailSubjectOptions();
    List<CampaignEmailReportService.SubjectOption> controllerOptions =
      CampaignEmailReportController.getCampaignEmailSubjectOptions();
    Test.stopTest();

    System.assert(!options.isEmpty(), 'Expected fallback subject options');
    System.assertEquals(options.size(), controllerOptions.size());
  }

  @IsTest
  static void fetchAndSaveSurfacesCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

    Boolean threw = false;
    Test.startTest();
    try {
      CampaignEmailReportService.fetchAndSave();
    } catch (Exception ex) {
      threw = true;
      System.assert(
        ex instanceof AuraHandledException,
        'Expected AuraHandledException for callout failure'
      );
    }
    Test.stopTest();

    System.assert(threw, 'Expected callout failure to surface');
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Failed']
    );
  }

  @IsTest
  static void helperMethodsCoverEmptyAndStatusBranches() {
    System.assertEquals(false, CampaignEmailReportService.hasResultRows(null));
    System.assertEquals(false, CampaignEmailReportService.hasResultRows('{'));
    System.assertEquals(false, CampaignEmailReportService.hasResultRows('{"results":[]}'));
    System.assertEquals(
      true,
      CampaignEmailReportService.hasResultRows('{"results":[{"messageId":"x"}]}')
    );
    System.assert(String.isNotBlank(CampaignEmailReportService.buildSentSinceParam(48)));

    String merged = CampaignEmailReportService.mergeResponseBodies(
      '{"results":[{"bulkId":"b1","to":"a@example.com","sentAt":"2026-07-16T08:00:00.000+0000"}]}',
      '{"results":[{"bulkId":"b1","destination":"a@example.com","sentAt":"2026-07-16T08:00:00.000+0000"},{"messageId":"m2","sentAt":"2026-07-16T09:00:00.000+0000"}]}'
    );
    System.assert(merged.contains('m2'));

    String emptyPersistBody = '{"results":[]}';
    CampaignEmailReportService.FetchResult emptyResult =
      CampaignEmailReportService.persistResponse(emptyPersistBody);
    System.assertEquals(0, emptyResult.rows.size());
    System.assert(!emptyResult.reportIds.isEmpty());

    CampaignEmailReportService.EmailReportRow opened = new CampaignEmailReportService.EmailReportRow();
    opened.recipient = 'open@example.com';
    opened.status = 'OPENED';
    CampaignEmailReportService.EmailReportRow failed = new CampaignEmailReportService.EmailReportRow();
    failed.recipient = 'fail@example.com';
    failed.status = 'UNDELIVERABLE';
    failed.errorName = 'HARD_BOUNCE';
    CampaignEmailReportService.EmailReportRow pending = new CampaignEmailReportService.EmailReportRow();
    pending.recipient = null;
    pending.status = 'PENDING';
    CampaignEmailReportService.EmailReportRow delivered = new CampaignEmailReportService.EmailReportRow();
    delivered.recipient = 'open@example.com';
    delivered.status = 'DELIVERED_TO_HANDSET';

    List<CampaignEmailReportService.EmailSummaryRow> summaries =
      CampaignEmailReportService.buildSummaryRows(
        new List<CampaignEmailReportService.EmailReportRow>{
          opened,
          failed,
          pending,
          delivered,
          null
        }
      );
    System.assert(summaries.size() >= 3);
    CampaignEmailReportService.EmailSummaryRow totals =
      CampaignEmailReportService.buildSummary(
        new List<CampaignEmailReportService.EmailReportRow>{ opened, failed, pending }
      );
    System.assert(totals.total >= 3);

    System.assertEquals(
      0,
      CampaignEmailReportService.filterRowsByCampaignSubject(null, 'x').size()
    );
    System.assertEquals(
      1,
      CampaignEmailReportService.filterRowsByCampaignSubject(
        new List<CampaignEmailReportService.EmailReportRow>{ opened },
        '  '
      )
        .size()
    );
    System.assertEquals(
      0,
      CampaignEmailReportService.filterRowsByCampaignSubject(
        new List<CampaignEmailReportService.EmailReportRow>{ opened },
        'Missing Subject'
      )
        .size()
    );
    System.assertEquals(
      0,
      CampaignEmailReportService.resolveTemplateIdsForSubject('').size()
    );
    System.assertEquals(
      0,
      CampaignEmailReportService.filterSafeTemplateIds(
        '',
        new Set<String>(),
        System.now()
      )
        .size()
    );

    CampaignEmailReportService.EmailReportRow parsed =
      CampaignEmailReportService.parseEmailReportRow(
        new Map<String, Object>{
          'messageId' => 'mid-1',
          'destination' => 'dest@example.com',
          'messageCount' => 2,
          'attemptCount' => 3L,
          'timeToFirstAttempt' => 1.5,
          'status' => new Map<String, Object>{
            'name' => 'CLICKED',
            'description' => 'Clicked'
          },
          'price' => new Map<String, Object>{
            'pricePerMessage' => 2,
            'currency' => 'INR'
          },
          'error' => new Map<String, Object>{
            'name' => 'OK',
            'description' => 'ok'
          }
        }
      );
    System.assertEquals('dest@example.com', parsed.recipient);
    System.assertEquals('CLICKED', parsed.status);
  }

  @IsTest
  static void listBridgeRedirectsToEmailReportLwc() {
    ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
      new List<Campaign>()
    );
    CampaignEmailReportListBridgeController controller = new CampaignEmailReportListBridgeController(
      setController
    );

    Test.startTest();
    PageReference target = controller.redirectToLwc();
    Test.stopTest();

    System.assertNotEquals(null, target);
    System.assert(
      target.getUrl().contains('c__campaignEmailReport'),
      'Expected email report LWC redirect URL'
    );
    System.assertEquals(
      null,
      target.getParameters().get('c__recordIds'),
      'Email report is not campaign-scoped'
    );
  }
}