public with sharing class BWM_EmailCallout {
  public static final String API_BASE_URL = 'https://api.infobip.com';

  public static HttpResponse send(String jsonBody) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    if (settings == null) {
      throw new BWM_EmailException('BWM email settings are not configured.');
    }

    String path = String.isBlank(settings.Endpoint_Path__c)
      ? '/email/4/messages'
      : settings.Endpoint_Path__c;

    HttpRequest request = new HttpRequest();
    request.setEndpoint(BWM_EmailConstants.NAMED_CREDENTIAL + path);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Accept', 'application/json');

    String headerName = String.isBlank(settings.API_Key_Header__c)
      ? 'Authorization'
      : settings.API_Key_Header__c;
    if (String.isNotBlank(settings.API_App_Key__c)) {
      request.setHeader(headerName, 'App ' + settings.API_App_Key__c);
    }

    request.setTimeout(120000);
    request.setBody(jsonBody);
    return new Http().send(request);
  }

  public static String buildRequestCurl(String jsonBody) {
    BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
    String path = settings != null && String.isNotBlank(settings.Endpoint_Path__c)
      ? settings.Endpoint_Path__c
      : '/email/4/messages';
    String headerName = settings != null &&
      String.isNotBlank(settings.API_Key_Header__c)
      ? settings.API_Key_Header__c
      : 'Authorization';
    String body = String.isBlank(jsonBody) ? '{}' : jsonBody;
    String escapedBody = body.replace('\'', '\\\'');

    return 'curl --location \'' +
      API_BASE_URL +
      path +
      '\' \\\n' +
      '--header \'Content-Type: application/json\' \\\n' +
      '--header \'' +
      headerName +
      ': App ***\' \\\n' +
      '--data \'' +
      escapedBody +
      '\'';
  }
}