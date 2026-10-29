public with sharing class BWM_MessagingCallout {
  public static final String API_BASE_URL = 'https://portal.bluewavesmedia.in';

  public static HttpResponse send(String jsonBody) {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null) {
      throw new BWM_MessagingException('BWM messaging settings are not configured.');
    }

    String endpoint =
      BWM_MessagingConstants.NAMED_CREDENTIAL +
      settings.Endpoint_Path__c;

    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');

    if (String.isNotBlank(settings.API_Bearer_Token__c)) {
      request.setHeader(
        String.isNotBlank(settings.API_Key_Header__c)
          ? settings.API_Key_Header__c
          : 'Authorization',
        'Bearer ' + settings.API_Bearer_Token__c
      );
    }

    request.setTimeout(120000);
    request.setBody(jsonBody);

    return new Http().send(request);
  }

  public static String buildRequestCurl(String jsonBody) {
    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    String path = settings != null && String.isNotBlank(settings.Endpoint_Path__c)
      ? settings.Endpoint_Path__c
      : '/api/v1/send';
    String authHeader = settings != null &&
      String.isNotBlank(settings.API_Key_Header__c)
      ? settings.API_Key_Header__c
      : 'Authorization';
    String bearerToken = settings != null &&
      String.isNotBlank(settings.API_Bearer_Token__c)
      ? settings.API_Bearer_Token__c
      : '';
    String body = String.isBlank(jsonBody) ? '{}' : jsonBody;
    String escapedBody = body.replace('\'', '\\\'');

    return 'curl --location \'' +
      API_BASE_URL +
      path +
      '\' \\\n' +
      '--header \'Content-Type: application/json\' \\\n' +
      '--header \'' +
      authHeader +
      ': Bearer ' +
      bearerToken +
      '\' \\\n' +
      '--data \'' +
      escapedBody +
      '\'';
  }
}