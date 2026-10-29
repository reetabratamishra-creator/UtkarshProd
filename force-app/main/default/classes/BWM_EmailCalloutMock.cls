@IsTest
public class BWM_EmailCalloutMock implements HttpCalloutMock {
  private final String responseBody;
  private final Integer statusCode;

  public BWM_EmailCalloutMock(String responseBody) {
    this(responseBody, 200);
  }

  public BWM_EmailCalloutMock(String responseBody, Integer statusCode) {
    this.responseBody = responseBody;
    this.statusCode = statusCode;
  }

  public HttpResponse respond(HttpRequest request) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    response.setBody(responseBody);
    response.setStatus(statusCode >= 200 && statusCode < 300 ? 'OK' : 'Error');
    return response;
  }
}