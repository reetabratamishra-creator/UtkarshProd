/**
 * @description   HttpCalloutMock that routes GET template lookups and POST email sends.
 * @author        Anshita Chanda
 * @date          2026-08-14
 */
@IsTest
public class BWM_EmailRouteCalloutMock implements HttpCalloutMock {
  private final String templateResponseBody;
  private final String sendResponseBody;
  private final Integer sendStatusCode;

  public BWM_EmailRouteCalloutMock(
    String templateResponseBody,
    String sendResponseBody,
    Integer sendStatusCode
  ) {
    this.templateResponseBody = templateResponseBody;
    this.sendResponseBody = sendResponseBody;
    this.sendStatusCode = sendStatusCode;
  }

  public HttpResponse respond(HttpRequest request) {
    HttpResponse response = new HttpResponse();

    if ('GET'.equalsIgnoreCase(request.getMethod())) {
      response.setStatusCode(200);
      response.setBody(templateResponseBody);
      response.setStatus('OK');
      return response;
    }

    response.setStatusCode(sendStatusCode);
    response.setBody(sendResponseBody);
    response.setStatus(
      sendStatusCode >= 200 && sendStatusCode < 300 ? 'OK' : 'Error'
    );
    return response;
  }
}