public with sharing class BWM_ApiResponse {
  public String code;
  public String message;
  public Integer httpStatus;
  public Boolean isSuccess = false;
  public String rawBody;

  public static BWM_ApiResponse parse(HttpResponse response, String expectedCode) {
    BWM_ApiResponse result = new BWM_ApiResponse();
    result.httpStatus = response.getStatusCode();
    result.rawBody = response.getBody();

    if (String.isBlank(result.rawBody)) {
      result.message = 'Empty response body.';
      return result;
    }

    try {
      Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
        result.rawBody
      );
      result.code = body.containsKey('code')
        ? String.valueOf(body.get('code'))
        : null;
      if (body.containsKey('message')) {
        result.message = String.valueOf(body.get('message'));
      } else if (body.containsKey('error')) {
        result.message = String.valueOf(body.get('error'));
      } else {
        result.message = result.rawBody;
      }
    } catch (Exception ex) {
      result.message = result.rawBody;
    }

    result.isSuccess =
      result.httpStatus >= 200 &&
      result.httpStatus < 300 &&
      result.code == expectedCode;
    return result;
  }

  public static BWM_ApiResponse parseWhatsAppDirect(
    HttpResponse response,
    String expectedCode
  ) {
    BWM_ApiResponse result = parse(response, expectedCode);
    if (result.isSuccess) {
      return result;
    }

    if (result.httpStatus < 200 || result.httpStatus >= 300) {
      return result;
    }

    if (String.isNotBlank(result.message)) {
      String normalizedMessage = result.message.toLowerCase();
      if (
        normalizedMessage.contains('accepted for processing') ||
        normalizedMessage.contains('enqueued successfully') ||
        normalizedMessage.contains('"success":true')
      ) {
        result.isSuccess = true;
        return result;
      }
    }

    if (String.isBlank(result.rawBody)) {
      return result;
    }

    try {
      Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
        result.rawBody
      );
      Object successValue = body.get('success');
      if (successValue == true) {
        result.isSuccess = true;
        return result;
      }

      Object statusCodeValue = body.get('statusCode');
      if (statusCodeValue != null) {
        Integer statusCode = Integer.valueOf(String.valueOf(statusCodeValue));
        result.isSuccess = statusCode >= 200 && statusCode < 300;
        return result;
      }

      result.isSuccess = true;
    } catch (Exception ex) {
      return result;
    }

    return result;
  }
}