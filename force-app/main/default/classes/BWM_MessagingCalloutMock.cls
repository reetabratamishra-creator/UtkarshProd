@IsTest
public class BWM_MessagingCalloutMock implements HttpCalloutMock {
  private final String whatsappResponseBody;
  private final String rcsResponseBody;
  private final String smsResponseBody;
  private Integer callCount = 0;

  public BWM_MessagingCalloutMock(
    String whatsappResponseBody,
    String rcsResponseBody
  ) {
    this(whatsappResponseBody, rcsResponseBody, null);
  }

  public BWM_MessagingCalloutMock(
    String whatsappResponseBody,
    String rcsResponseBody,
    String smsResponseBody
  ) {
    this.whatsappResponseBody = whatsappResponseBody;
    this.rcsResponseBody = rcsResponseBody;
    this.smsResponseBody = smsResponseBody;
  }

  public HTTPResponse respond(HTTPRequest request) {
    callCount++;
    HttpResponse response = new HttpResponse();
    response.setHeader('Content-Type', 'application/json');
    response.setStatusCode(200);

    if (callCount == 1) {
      response.setBody(whatsappResponseBody);
    } else if (callCount == 2) {
      response.setBody(rcsResponseBody);
    } else if (String.isNotBlank(smsResponseBody)) {
      response.setBody(smsResponseBody);
    } else {
      response.setBody(rcsResponseBody);
    }

    return response;
  }
}