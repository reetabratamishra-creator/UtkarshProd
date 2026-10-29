/**
 * @description   Test class for CampaignStatsService Bluewave stats API scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class CampaignStatsServiceTest {
  private class CampaignStatsMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      System.assert(
        request.getEndpoint().contains('/api/v1/journey/campaign-stats'),
        'Expected campaign-stats endpoint'
      );
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(200);
      response.setBody(
        '{"journeyName":"hm_bro_july26","journeyCampaignName":"Journey_7/8/2026 2:11:01 PM","productName":"RCSMESSAGE","components":[{"indexNo":2,"statistics":{"DELIVERED":7,"FAILED":2,"NON_RCS_NO":18,"READ":6}}]}'
      );
      return response;
    }
  }

  private class CampaignStatsErrorMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(404);
      response.setBody('{"code":"404","message":"Campaign not found."}');
      return response;
    }
  }

  private class WhatsAppCampaignStatsMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setStatusCode(200);
      response.setBody(
        '{"journeyName":"prospect_enq_dept","journeyCampaignName":"Journey_8/3/2026 7:02:14 PM","productName":"WHATSAPP","components":[{"indexNo":1,"statistics":{"totalCount":3,"sentCount":0,"deliveredCount":1,"sendingCount":0,"readCount":2,"submittedCount":0,"failedCount":0,"repliedCount":0}}]}'
      );
      return response;
    }
  }

  @IsTest
  static void getCampaignOptionsReturnsSelectedCampaigns() {
    Campaign campaignRecord = new Campaign(
      Name = 'Journey_7/8/2026 2:11:01 PM',
      IsActive = true
    );
    insert campaignRecord;

    Test.startTest();
    List<CampaignStatsService.CampaignOption> options = CampaignStatsService.getCampaignOptions(
      new List<Id>{ campaignRecord.Id }
    );
    Test.stopTest();

    System.assertEquals(1, options.size());
    System.assertEquals(campaignRecord.Name, options[0].name);
  }

  @IsTest
  static void fetchAndSaveCreatesCampaignReport() {
    Campaign campaignRecord = new Campaign(
      Name = 'Journey_7/8/2026 2:11:01 PM',
      IsActive = true
    );
    insert campaignRecord;
    Test.setMock(HttpCalloutMock.class, new CampaignStatsMock());

    Test.startTest();
    CampaignStatsService.FetchResult result = CampaignStatsService.fetchAndSave(
      campaignRecord.Id,
      campaignRecord.Name,
      'RCS'
    );
    Test.stopTest();

    System.assertEquals('hm_bro_july26', result.journeyName);
    System.assertEquals(1, result.components.size());
    System.assertEquals(7, result.components[0].delivered);
    System.assertEquals(1, result.reportIds.size());

    Integration_Log__c logRecord = [
      SELECT
        Campaign__c,
        Integration_Name__c,
        Endpoint__c,
        Http_Method__c,
        Request_Payload__c,
        Response_Payload__c,
        Response_Http_Status__c,
        Status__c,
        Product_Name__c,
        Campaign_Name__c
      FROM Integration_Log__c
      WHERE Id = :result.integrationLogId
    ];
    System.assertEquals(campaignRecord.Id, logRecord.Campaign__c);
    System.assertEquals('Campaign Stats', logRecord.Integration_Name__c);
    System.assertEquals('Success', logRecord.Status__c);
    System.assertEquals(200, logRecord.Response_Http_Status__c);
    System.assert(String.isNotBlank(logRecord.Request_Payload__c));
    System.assert(String.isNotBlank(logRecord.Response_Payload__c));

    Campaign_Report__c report = [
      SELECT
        Campaign__c,
        Journey_Name__c,
        Journey_Campaign_Name__c,
        Product_Name__c,
        Index_No__c,
        Delivered__c,
        Failed__c,
        Non_RCS_No__c,
        Read__c,
        Raw_Response__c
      FROM Campaign_Report__c
      WHERE Id = :result.reportIds[0]
    ];
    System.assertEquals(campaignRecord.Id, report.Campaign__c);
    System.assertEquals('hm_bro_july26', report.Journey_Name__c);
    System.assertEquals(2, report.Index_No__c);
    System.assertEquals(7, report.Delivered__c);
    System.assertEquals(2, report.Failed__c);
    System.assertEquals(18, report.Non_RCS_No__c);
    System.assertEquals(6, report.Read__c);
    System.assert(String.isNotBlank(report.Raw_Response__c));
  }

  @IsTest
  static void fetchAndSaveParsesWhatsAppStatistics() {
    Campaign campaignRecord = new Campaign(
      Name = 'Journey_8/3/2026 7:02:14 PM',
      IsActive = true
    );
    insert campaignRecord;
    Test.setMock(HttpCalloutMock.class, new WhatsAppCampaignStatsMock());

    Test.startTest();
    CampaignStatsService.FetchResult result = CampaignStatsService.fetchAndSave(
      campaignRecord.Id,
      campaignRecord.Name,
      'WhatsApp'
    );
    Test.stopTest();

    System.assertEquals('prospect_enq_dept', result.journeyName);
    System.assertEquals(1, result.components.size());
    System.assertEquals(1, result.components[0].delivered);
    System.assertEquals(0, result.components[0].failed);
    System.assertEquals(2, result.components[0].readCount);

    Campaign_Report__c report = [
      SELECT Delivered__c, Failed__c, Read__c
      FROM Campaign_Report__c
      WHERE Id = :result.reportIds[0]
    ];
    System.assertEquals(1, report.Delivered__c);
    System.assertEquals(0, report.Failed__c);
    System.assertEquals(2, report.Read__c);
  }

  @IsTest
  static void controllerDelegatesToService() {
    Campaign campaignRecord = new Campaign(
      Name = 'WhatsApp Journey Campaign',
      IsActive = true
    );
    insert campaignRecord;
    Test.setMock(HttpCalloutMock.class, new CampaignStatsMock());

    Test.startTest();
    List<CampaignStatsService.CampaignOption> options = CampaignStatsController.getCampaignOptions(
      new List<Id>{ campaignRecord.Id }
    );
    CampaignStatsService.FetchResult result = CampaignStatsController.fetchCampaignStats(
      campaignRecord.Id,
      campaignRecord.Name,
      'WhatsApp'
    );
    Test.stopTest();

    System.assertEquals(1, options.size());
    System.assertEquals(1, result.reportIds.size());
  }

  @IsTest
  static void fetchAndSaveSurfacesApiError() {
    Campaign campaignRecord = new Campaign(
      Name = 'Missing Campaign',
      IsActive = true
    );
    insert campaignRecord;
    Test.setMock(HttpCalloutMock.class, new CampaignStatsErrorMock());

    Boolean threw = false;
    Test.startTest();
    try {
      CampaignStatsService.fetchAndSave(
        campaignRecord.Id,
        campaignRecord.Name,
        'RCS'
      );
    } catch (Exception ex) {
      threw = true;
      System.assert(
        ex instanceof AuraHandledException,
        'Expected AuraHandledException, got ' + ex.getTypeName()
      );
    }
    Test.stopTest();
    System.assert(threw, 'Expected AuraHandledException');
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Campaign_Report__c]
    );
    List<Integration_Log__c> logs = [
      SELECT Status__c, Response_Http_Status__c, Error_Message__c
      FROM Integration_Log__c
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals('Failed', logs[0].Status__c);
    System.assertEquals(404, logs[0].Response_Http_Status__c);
  }

  @IsTest
  static void listBridgeRedirectsWithSelectedCampaigns() {
    Campaign campaignRecord = new Campaign(
      Name = 'Bridge Campaign',
      IsActive = true
    );
    insert campaignRecord;

    ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
      [SELECT Id, Name FROM Campaign WHERE Id = :campaignRecord.Id]
    );
    setController.setSelected(
      [SELECT Id, Name FROM Campaign WHERE Id = :campaignRecord.Id]
    );
    CampaignStatsListBridgeController controller = new CampaignStatsListBridgeController(
      setController
    );

    Test.startTest();
    PageReference target = controller.redirectToLwc();
    Test.stopTest();

    System.assertNotEquals(null, target);
    System.assert(
      target.getUrl().contains('c__campaignStatsReport'),
      'Expected LWC redirect URL'
    );
    System.assertEquals(
      String.valueOf(campaignRecord.Id),
      target.getParameters().get('c__recordIds')
    );
  }

  @IsTest
  static void listBridgeRequiresSelection() {
    ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
      new List<Campaign>()
    );
    CampaignStatsListBridgeController controller = new CampaignStatsListBridgeController(
      setController
    );

    Test.startTest();
    PageReference target = controller.redirectToLwc();
    Test.stopTest();

    System.assertEquals(null, target);
    System.assert(String.isNotBlank(controller.errorMessage));
  }

  @IsTest
  static void getCampaignOptionsHandlesEmptyAndControllerDelegation() {
    System.assertEquals(
      0,
      CampaignStatsService.getCampaignOptions(null).size()
    );
    System.assertEquals(
      0,
      CampaignStatsService.getCampaignOptions(new List<Id>()).size()
    );

    Campaign campaignRecord = new Campaign(
      Name = 'Controller Campaign',
      IsActive = true
    );
    insert campaignRecord;
    Test.setMock(HttpCalloutMock.class, new CampaignStatsMock());

    Test.startTest();
    List<CampaignStatsService.CampaignOption> options =
      CampaignStatsController.getCampaignOptions(new List<Id>{ campaignRecord.Id });
    CampaignStatsService.FetchResult result = CampaignStatsController.fetchCampaignStats(
      campaignRecord.Id,
      campaignRecord.Name,
      'RCS'
    );
    Test.stopTest();

    System.assertEquals(1, options.size());
    System.assertEquals(1, result.reportIds.size());
  }

  @IsTest
  static void fetchAndSaveValidatesRequiredInputs() {
    Boolean missingCampaign = false;
    Boolean missingName = false;
    Boolean missingProduct = false;
    try {
      CampaignStatsService.fetchAndSave(null, 'Name', 'RCS');
    } catch (Exception ex) {
      missingCampaign = ex instanceof AuraHandledException;
    }
    Campaign campaignRecord = new Campaign(Name = 'Required Fields', IsActive = true);
    insert campaignRecord;
    try {
      CampaignStatsService.fetchAndSave(campaignRecord.Id, '  ', 'RCS');
    } catch (Exception ex) {
      missingName = ex instanceof AuraHandledException;
    }
    try {
      CampaignStatsService.fetchAndSave(campaignRecord.Id, campaignRecord.Name, '');
    } catch (Exception ex) {
      missingProduct = ex instanceof AuraHandledException;
    }
    System.assert(missingCampaign);
    System.assert(missingName);
    System.assert(missingProduct);
  }

  @IsTest
  static void persistResponseCoversEmptyAndInvalidPayloads() {
    Campaign campaignRecord = new Campaign(Name = 'Persist Campaign', IsActive = true);
    insert campaignRecord;

    Boolean invalidJson = false;
    try {
      CampaignStatsService.persistResponse(campaignRecord.Id, '{');
    } catch (Exception ex) {
      invalidJson = ex instanceof AuraHandledException;
    }
    System.assert(invalidJson);

    Boolean apiError = false;
    try {
      CampaignStatsService.persistResponse(
        campaignRecord.Id,
        '{"code":"404","message":"missing"}'
      );
    } catch (Exception ex) {
      apiError = ex instanceof AuraHandledException;
    }
    System.assert(apiError);

    CampaignStatsService.FetchResult emptyResult = CampaignStatsService.persistResponse(
      campaignRecord.Id,
      '{"journeyName":"j1","journeyCampaignName":"c1","productName":"RCS","components":[]}'
    );
    System.assertEquals(1, emptyResult.reportIds.size());
    System.assertEquals(
      null,
      CampaignStatsService.getStatisticValue(null, new List<String>{ 'DELIVERED' })
    );
    System.assertEquals(
      9,
      CampaignStatsService.getStatisticValue(
        new Map<String, Object>{ 'delivered' => 9 },
        new List<String>{ 'DELIVERED' }
      )
    );
  }

  @IsTest
  static void normalizeProductNameRejectsInvalid() {
    Boolean threw = false;
    try {
      CampaignStatsService.normalizeProductName('SMS');
    } catch (AuraHandledException ex) {
      threw = true;
    }
    System.assert(threw);
    System.assertEquals('WhatsApp', CampaignStatsService.normalizeProductName('WA'));
    System.assertEquals('RCS', CampaignStatsService.normalizeProductName('RCSMessage'));
  }
}