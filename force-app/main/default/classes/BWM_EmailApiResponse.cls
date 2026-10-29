public with sharing class BWM_EmailApiResponse {
  public Integer httpStatus;
  public String rawBody;
  public String message;
  public Boolean isSuccess = false;

  public static BWM_EmailApiResponse parse(HttpResponse response) {
    BWM_EmailApiResponse result = new BWM_EmailApiResponse();
    result.httpStatus = response.getStatusCode();
    result.rawBody = response.getBody();
    result.isSuccess = result.httpStatus >= 200 && result.httpStatus < 300;
    result.message = String.isBlank(result.rawBody)
      ? response.getStatus()
      : result.rawBody;
    return result;
  }
}